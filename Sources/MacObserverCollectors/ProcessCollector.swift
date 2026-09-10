import Foundation
import MacObserverDomain

public actor ProcessCollector: TelemetryCollector {
    public nonisolated let capability = CapabilityDescriptor(
        id: "standard.processes",
        title: "Processes",
        accessLevel: .standard,
        domains: [.process, .cpu, .memory],
        summary: "Process CPU and resident memory from proc_pidinfo. Identity is PID plus start time plus boot."
    )

    private let clock: any Clock
    private let bootSession: BootSessionID
    private let source: any ProcessResourceSource
    private let interval: Duration
    private let loop = LoopingCollector()
    private var previousCPU: [Int32: (nanoseconds: UInt64, sampledAt: UInt64)] = [:]

    public init(clock: any Clock = SystemClock(), bootSession: BootSessionID) {
        self.init(clock: clock, bootSession: bootSession, source: DarwinProcessResourceSource())
    }

    init(
        clock: any Clock,
        bootSession: BootSessionID,
        source: any ProcessResourceSource,
        interval: Duration = .seconds(2)
    ) {
        self.clock = clock
        self.bootSession = bootSession
        self.source = source
        self.interval = interval
    }

    public func start(sink: any TelemetrySink) async throws {
        await loop.start(interval: interval) {
            await self.publish(to: sink)
        }
    }

    public func stop() async {
        await loop.stop()
    }

    private func publish(to sink: any TelemetrySink) async {
        let processes = source.currentProcesses()
        guard !processes.isEmpty else {
            await sink.send(.availability(capabilityID: capability.id, .unavailable(reason: "proc_listallpids returned no processes")))
            return
        }

        let nowMono = clock.monotonicNanoseconds
        var ranked: [(identity: ProcessInstanceIdentity, cpu: Double, resident: UInt64)] = []
        ranked.reserveCapacity(min(processes.count, 256))

        for process in processes {
            let identity = ProcessInstanceIdentity(
                pid: process.pid,
                startNanoseconds: process.startSeconds &* 1_000_000_000 &+ process.startMicroseconds &* 1_000,
                bootSession: bootSession,
                attributes: ProcessAttributes(displayName: process.displayName.isEmpty ? nil : process.displayName)
            )

            var cpuRatio = 0.0
            if let previous = previousCPU[process.pid], nowMono > previous.sampledAt {
                let elapsed = Double(nowMono - previous.sampledAt) / 1_000_000_000
                if let ratio = SampleMath.cpuTimeRatio(
                    previousNanoseconds: previous.nanoseconds,
                    currentNanoseconds: process.cpuNanoseconds,
                    elapsedSeconds: elapsed
                ) {
                    cpuRatio = ratio
                }
            }
            previousCPU[process.pid] = (process.cpuNanoseconds, nowMono)
            ranked.append((identity, cpuRatio, process.residentBytes))
        }

        ranked.sort { $0.cpu == $1.cpu ? $0.resident > $1.resident : $0.cpu > $1.cpu }

        for item in ranked.prefix(20) {
            let entity = Entity.processInstance(item.identity)
            await sink.send(.metric(MetricFactory.make(
                clock: clock,
                domain: .cpu,
                name: .cpuUtilizationRatio,
                entity: entity,
                value: .ratio(item.cpu),
                unit: .ratio,
                source: capability.id
            )))
            await sink.send(.metric(MetricFactory.make(
                clock: clock,
                domain: .memory,
                name: .processResidentBytes,
                entity: entity,
                value: .int(Int64(item.resident)),
                unit: .bytes,
                source: capability.id
            )))
        }

        await sink.send(.availability(capabilityID: capability.id, .available))
    }
}
