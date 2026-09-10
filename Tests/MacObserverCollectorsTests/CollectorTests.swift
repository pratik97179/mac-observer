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
