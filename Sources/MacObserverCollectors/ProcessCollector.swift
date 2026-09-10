import Foundation
import Darwin
import MacObserverDomain

public actor ProcessCollector: TelemetryCollector {
    public nonisolated let capability = CapabilityDescriptor(
        id: "standard.processes",
        title: "Processes",
        accessLevel: .standard,
        domains: [.process, .cpu, .memory],
        summary: "Process CPU and resident memory from libproc. Identity is PID plus start time plus boot."
    )

    private let clock: any Clock
    private let bootSession: BootSessionID
    private let loop = LoopingCollector()
    private var previousCPU: [Int32: (nanoseconds: UInt64, sampledAt: UInt64)] = [:]

    public init(clock: any Clock = SystemClock(), bootSession: BootSessionID) {
        self.clock = clock
        self.bootSession = bootSession
    }

    public func start(sink: any TelemetrySink) async throws {
        await loop.start {
            await self.publish(to: sink)
        }
    }

    public func stop() async {
        await loop.stop()
    }

    private func publish(to sink: any TelemetrySink) async {
        var pids = [Int32](repeating: 0, count: 4096)
        let bytes = pids.withUnsafeMutableBufferPointer { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count * MemoryLayout<Int32>.size))
        }
        guard bytes > 0 else {
            await sink.send(.availability(capabilityID: capability.id, .unavailable(reason: "proc_listallpids failed")))
            return
        }

        let count = Int(bytes) / MemoryLayout<Int32>.size
        let nowMono = clock.monotonicNanoseconds
        var ranked: [(identity: ProcessInstanceIdentity, cpu: Double, resident: UInt64)] = []
        ranked.reserveCapacity(min(count, 256))

        for pid in pids.prefix(count) where pid > 0 {
            var bsd = proc_bsdinfo()
            let bsdSize = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, Int32(MemoryLayout<proc_bsdinfo>.size))
            guard bsdSize > 0 else { continue }

            var usage = rusage_info_v4()
            let usageStatus = withUnsafeMutablePointer(to: &usage) { pointer -> Int32 in
                var buffer: rusage_info_t? = UnsafeMutableRawPointer(pointer)
                return proc_pid_rusage(pid, RUSAGE_INFO_V4, &buffer)
            }

            var task = proc_taskinfo()
            let taskSize = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &task, Int32(MemoryLayout<proc_taskinfo>.size))
            let resident = taskSize > 0 ? UInt64(task.pti_resident_size) : 0

            var name = [CChar](repeating: 0, count: Int(MAXCOMLEN) + 1)
            proc_name(pid, &name, UInt32(name.count))
            let display = name.prefix { $0 != 0 }.map { Character(UnicodeScalar(UInt8(bitPattern: $0))) }
            let displayName = String(display)

            let identity = ProcessInstanceIdentity(
                pid: pid,
                startNanoseconds: UInt64(bsd.pbi_start_tvsec) &* 1_000_000_000 &+ UInt64(bsd.pbi_start_tvusec) &* 1_000,
                bootSession: bootSession,
                attributes: ProcessAttributes(displayName: displayName.isEmpty ? nil : displayName)
            )

            var cpuRatio = 0.0
            if usageStatus == 0 {
                let cpuNanos = usage.ri_user_time &+ usage.ri_system_time
                if let previous = previousCPU[pid], nowMono > previous.sampledAt {
                    let elapsed = Double(nowMono - previous.sampledAt) / 1_000_000_000
                    if let rate = SampleMath.perSecond(previous: previous.nanoseconds, current: cpuNanos, elapsed: elapsed) {
                        cpuRatio = min(1, rate)
                    }
                }
                previousCPU[pid] = (cpuNanos, nowMono)
            }

            ranked.append((identity, cpuRatio, resident))
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
