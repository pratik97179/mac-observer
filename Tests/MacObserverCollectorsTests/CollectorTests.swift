import Foundation
import Testing
import MacObserverDomain
@testable import MacObserverCollectors

struct CollectorContractTests {
    private let boot = BootSessionID("boot-1")
    private var system: Entity { .system(bootSession: boot) }

    @Test func fakeClockStampsMetricsAndBufferKeepsLatest() async throws {
        let clock = FakeClock()
        let collector = FakeCollector(
            clock: clock,
            initial: [.metric(cpu(ratio: 0.10, quality: .direct))]
        )
        let pipeline = CollectorPipeline(collectors: [collector], buffer: LiveTelemetryBuffer(clock: clock))

        try await pipeline.start()
        var snapshot = await pipeline.snapshot()
        #expect(snapshot.metric(named: .cpuUtilizationRatio, entity: system)?.time.wallTime == Date(timeIntervalSince1970: 0))
        #expect(snapshot.availability.isEmpty)

        clock.advance(seconds: 5)
        await collector.emit(.metric(cpu(ratio: 0.40, quality: .direct)))
        snapshot = await pipeline.snapshot()

        let latest = snapshot.metric(named: .cpuUtilizationRatio, entity: system)
        #expect(latest?.time.wallTime == Date(timeIntervalSince1970: 5))
        if case .ratio(let value) = latest?.value {
            #expect(value == 0.40)
        } else {
            Issue.record("expected the latest ratio")
        }
        #expect(snapshot.metrics.count == 1)

        await pipeline.stop()
        await collector.emit(.metric(cpu(ratio: 0.90, quality: .direct)))
        snapshot = await pipeline.snapshot()
        if case .ratio(let value) = snapshot.metric(named: .cpuUtilizationRatio, entity: system)?.value {
            #expect(value == 0.40)
        }
    }

    @Test func unavailableDoesNotInventAHealthyReading() async throws {
        let clock = FakeClock()
        let collector = FakeCollector(clock: clock)
        let buffer = LiveTelemetryBuffer(clock: clock)
        try await collector.start(sink: buffer)
        await collector.emit(.availability(capabilityID: collector.capability.id, .unavailable(reason: "source missing")))

        let snapshot = await buffer.snapshot()
        #expect(snapshot.metrics.isEmpty)
        #expect(snapshot.availability[collector.capability.id] == .unavailable(reason: "source missing"))
        await collector.stop()
    }

    @Test func processMetricsAreKeyedByInstanceNotPID() async throws {
        let clock = FakeClock()
        let buffer = LiveTelemetryBuffer(clock: clock)
        let collector = FakeCollector(clock: clock)
        try await collector.start(sink: buffer)

        let first = ProcessInstanceIdentity(pid: 442, startNanoseconds: 100, bootSession: boot)
        let reused = ProcessInstanceIdentity(pid: 442, startNanoseconds: 900, bootSession: boot)
        await collector.emit(.metric(cpu(ratio: 0.2, quality: .direct, entity: .processInstance(first))))
        await collector.emit(.metric(cpu(ratio: 0.8, quality: .direct, entity: .processInstance(reused))))

        let snapshot = await buffer.snapshot()
        #expect(snapshot.metrics.count == 2)
        await collector.stop()
    }

    @Test func disablingACollectorStopsFutureSamples() async throws {
        let clock = FakeClock()
        let collector = FakeCollector(
            clock: clock,
            initial: [.metric(cpu(ratio: 0.10, quality: .direct))]
        )
        let pipeline = CollectorPipeline(collectors: [collector], buffer: LiveTelemetryBuffer(clock: clock))
        try await pipeline.start()
        try await pipeline.setEnabled(collector.capability.id, enabled: false)
        await collector.emit(.metric(cpu(ratio: 0.90, quality: .direct)))

        let snapshot = await pipeline.snapshot()
        if case .ratio(let value) = snapshot.metric(named: .cpuUtilizationRatio, entity: system)?.value {
            #expect(value == 0.10)
        } else {
            Issue.record("expected the last sample from before disable")
        }
        #expect(snapshot.availability[collector.capability.id] == .unavailable(reason: "Disabled in Capabilities"))
        #expect(snapshot.events.contains { event in
            event.type == .capabilityAvailabilityChanged && event.metadata["enabled"] == "false"
        })
        await pipeline.stop()
    }

    @Test func liveBufferBoundsEventsAndKeepsNewest() async {
        let clock = FakeClock()
        let buffer = LiveTelemetryBuffer(clock: clock, eventLimit: 2)
        await buffer.send(.event(sampleEvent(clock: clock, summary: "one")))
        clock.advance(seconds: 1)
        await buffer.send(.event(sampleEvent(clock: clock, summary: "two")))
        clock.advance(seconds: 1)
        await buffer.send(.event(sampleEvent(clock: clock, summary: "three")))

        let snapshot = await buffer.snapshot()
        #expect(snapshot.events.map(\.summary) == ["two", "three"])
    }

    @Test func liveBufferKeepsAShortNumericSeries() async {
        let clock = FakeClock()
        let buffer = LiveTelemetryBuffer(clock: clock, seriesLimit: 3)
        let entity = Entity.system(bootSession: boot)
        for ratio in [0.1, 0.2, 0.3, 0.4] {
            clock.advance(seconds: 1)
            await buffer.send(.metric(cpu(ratio: ratio, quality: .direct, entity: entity)))
        }
        let snapshot = await buffer.snapshot()
        #expect(snapshot.series(named: .cpuUtilizationRatio, entityKey: entity.identityKey).map(\.value) == [0.2, 0.3, 0.4])
    }

    @Test func reenablingACollectorEmitsAnAvailabilityEvent() async throws {
        let clock = FakeClock()
        let collector = FakeCollector(clock: clock)
        let pipeline = CollectorPipeline(collectors: [collector], buffer: LiveTelemetryBuffer(clock: clock))
        try await pipeline.start()
        try await pipeline.setEnabled(collector.capability.id, enabled: false)
        try await pipeline.setEnabled(collector.capability.id, enabled: true)

        let snapshot = await pipeline.snapshot()
        #expect(snapshot.events.filter { $0.type == .capabilityAvailabilityChanged }.count == 2)
        #expect(snapshot.events.last?.metadata["enabled"] == "true")
        await pipeline.stop()
    }

    private func sampleEvent(clock: FakeClock, summary: String) -> Event {
        Event(
            time: clock.observationTime,
            domain: .memory,
            type: .memoryPressureChanged,
            entity: system,
            summary: summary,
            source: "test",
            quality: .direct,
            privacyClass: .operational
        )
    }

    private func cpu(
        ratio: Double,
        quality: ObservationQuality,
        entity: Entity? = nil
    ) -> Metric {
        Metric(
            time: ObservationTime(wallTime: Date(timeIntervalSince1970: 99)),
            domain: .cpu,
            name: .cpuUtilizationRatio,
            entity: entity ?? system,
            value: .ratio(ratio),
            unit: .ratio,
            source: "fake",
            quality: quality
        )
    }
}

struct SampleMathTests {
    @Test func cpuUtilizationIgnoresIdleTicks() {
        let previous: [UInt32] = [10, 10, 80, 0]
        let current: [UInt32] = [20, 20, 100, 0]
        #expect(SampleMath.cpuUtilizationRatio(previous: previous, current: current) == 0.5)
    }

    @Test func perSecondRequiresForwardTimeAndCounters() {
        #expect(SampleMath.perSecond(previous: 100, current: 200, elapsed: 2) == 50)
        #expect(SampleMath.perSecond(previous: 200, current: 100, elapsed: 2) == nil)
        #expect(SampleMath.perSecond(previous: 100, current: 200, elapsed: 0) == nil)
    }

    @Test func cpuTimeRatioUsesNanosecondsOverElapsedWall() {
        #expect(SampleMath.cpuTimeRatio(previousNanoseconds: 0, currentNanoseconds: 500_000_000, elapsedSeconds: 1) == 0.5)
        #expect(SampleMath.cpuTimeRatio(previousNanoseconds: 0, currentNanoseconds: 4_000_000_000, elapsedSeconds: 1) == 1)
        #expect(SampleMath.cpuTimeRatio(previousNanoseconds: 200, currentNanoseconds: 100, elapsedSeconds: 1) == nil)
    }
}

final class ScriptedProcessSource: ProcessResourceSource, @unchecked Sendable {
    private let lock = NSLock()
    private var current: [ProcessResourceSnapshot]

    init(_ current: [ProcessResourceSnapshot]) {
        self.current = current
    }

    func set(_ processes: [ProcessResourceSnapshot]) {
        lock.lock()
        current = processes
        lock.unlock()
    }

    func currentProcesses() -> [ProcessResourceSnapshot] {
        lock.lock()
        defer { lock.unlock() }
        return current
    }
}

struct ProcessCollectorTests {
    @Test func darwinSamplerDoesNotTrap() {
        _ = DarwinProcessSampler.sample()
    }

    @Test func processCollectorEmitsInstanceCPUFromTaskTimes() async throws {
        let clock = FakeClock()
        let first = ProcessResourceSnapshot(pid: 442, startSeconds: 1, startMicroseconds: 0, displayName: "demo", cpuNanoseconds: 0, residentBytes: 4_096)
        let second = ProcessResourceSnapshot(pid: 442, startSeconds: 1, startMicroseconds: 0, displayName: "demo", cpuNanoseconds: 500_000_000, residentBytes: 8_192)
        let source = ScriptedProcessSource([first])
        let collector = ProcessCollector(clock: clock, bootSession: BootSessionID("boot-1"), source: source, interval: .milliseconds(20))
        let buffer = LiveTelemetryBuffer(clock: clock)
        let entity = Entity.processInstance(
            ProcessInstanceIdentity(pid: 442, startNanoseconds: 1_000_000_000, bootSession: BootSessionID("boot-1"), attributes: ProcessAttributes(displayName: "demo"))
        )

        try await collector.start(sink: buffer)
        var snapshot = await buffer.snapshot()
        for _ in 0..<40 where snapshot.metrics.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
            snapshot = await buffer.snapshot()
        }
        #expect(!snapshot.metrics.isEmpty)

        clock.advance(seconds: 1)
        source.set([second])
        var ratio: Double?
        for _ in 0..<40 {
            try await Task.sleep(for: .milliseconds(10))
            snapshot = await buffer.snapshot()
            if case .ratio(let value) = snapshot.metric(named: .cpuUtilizationRatio, entity: entity)?.value, value > 0 {
                ratio = value
                break
            }
        }
        #expect(ratio == 0.5)
        await collector.stop()
    }
}

actor RecordingPersist: TelemetryPersisting {
    var metrics: [Metric] = []
    var events: [Event] = []

    func insert(metrics: [Metric]) async throws {
        self.metrics.append(contentsOf: metrics)
    }

    func insert(events: [Event]) async throws {
        self.events.append(contentsOf: events)
    }
}

struct PersistenceSinkTests {
    @Test func fanoutAndBatchPersistMetrics() async throws {
        let clock = FakeClock()
        let persist = RecordingPersist()
        let persisting = PersistingSink(persist: persist, batchSize: 2)
        let buffer = LiveTelemetryBuffer(clock: clock)
        let fanout = FanoutTelemetrySink([buffer, persisting])
        let collector = FakeCollector(clock: clock)
        try await collector.start(sink: fanout)

        await collector.emit(.metric(cpuMetric(ratio: 0.1, clock: clock)))
        await collector.emit(.metric(cpuMetric(ratio: 0.2, clock: clock)))
        #expect(await persist.metrics.count == 2)

        let snapshot = await buffer.snapshot()
        #expect(snapshot.metrics.count == 1)

        await collector.stop()
    }

    private func cpuMetric(ratio: Double, clock: FakeClock) -> Metric {
        Metric(
            time: clock.observationTime,
            domain: .cpu,
            name: .cpuUtilizationRatio,
            entity: .system(bootSession: BootSessionID("boot-1")),
            value: .ratio(ratio),
            unit: .ratio,
            source: "test",
            quality: .direct
        )
    }
}
