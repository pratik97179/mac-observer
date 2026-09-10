import Foundation
import Darwin
import MacObserverDomain

public actor CPUMemoryCollector: TelemetryCollector {
    public nonisolated let capability = CapabilityDescriptor(
        id: "standard.cpu_memory",
        title: "CPU and Memory",
        accessLevel: .standard,
        domains: [.cpu, .memory, .thermal],
        summary: "Host CPU load, VM statistics, swap, and thermal state from Mach and ProcessInfo."
    )

    private let clock: any Clock
    private let bootSession: BootSessionID
    private let loop = LoopingCollector()
    private var previousCPU: [UInt32]?
    private var previousPressure: String?
    private var previousThermal: String?

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
        let system = Entity.system(bootSession: bootSession)
        let source = capability.id

        if let sample = MachHostSampler.cpuLoad() {
            if let previous = previousCPU,
               let ratio = SampleMath.cpuUtilizationRatio(previous: previous, current: sample.ticks) {
                await sink.send(.metric(MetricFactory.make(
                    clock: clock,
                    domain: .cpu,
                    name: .cpuUtilizationRatio,
                    entity: system,
                    value: .ratio(ratio),
                    unit: .ratio,
                    source: source
                )))
            }
            previousCPU = sample.ticks
            await sink.send(.availability(capabilityID: capability.id, .available))
        } else {
            await sink.send(.availability(capabilityID: capability.id, .unavailable(reason: "host_processor_info failed")))
        }

        let pageSize = UInt64(sysconf(_SC_PAGESIZE))
        if let vm = MachHostSampler.vmStats() {
            let wired = UInt64(vm.wire_count) * pageSize
            let compressed = UInt64(vm.compressor_page_count) * pageSize
            let used = (UInt64(vm.internal_page_count) + UInt64(vm.wire_count) + UInt64(vm.compressor_page_count)) * pageSize
            await sink.send(.metric(MetricFactory.make(
                clock: clock, domain: .memory, name: .memoryUsedBytes, entity: system,
                value: .int(Int64(used)), unit: .bytes, source: source
            )))
            await sink.send(.metric(MetricFactory.make(
                clock: clock, domain: .memory, name: .memoryWiredBytes, entity: system,
                value: .int(Int64(wired)), unit: .bytes, source: source
            )))
            await sink.send(.metric(MetricFactory.make(
                clock: clock, domain: .memory, name: .memoryCompressedBytes, entity: system,
                value: .int(Int64(compressed)), unit: .bytes, source: source
            )))
            await sink.send(.metric(MetricFactory.make(
                clock: clock, domain: .memory, name: .memoryTotalBytes, entity: system,
                value: .int(Int64(ProcessInfo.processInfo.physicalMemory)), unit: .bytes, source: source
            )))
        }

        if let swap = MachHostSampler.swapUsedBytes() {
            await sink.send(.metric(MetricFactory.make(
                clock: clock, domain: .memory, name: .memorySwapUsedBytes, entity: system,
                value: .int(Int64(swap)), unit: .bytes, source: source
            )))
        }

        if let pressure = MachHostSampler.memoryPressureState() {
            await sink.send(.metric(MetricFactory.make(
                clock: clock, domain: .memory, name: .memoryPressureState, entity: system,
                value: .state(pressure), unit: .enumeration, source: source
            )))
            if let previousPressure, previousPressure != pressure {
                await sink.send(.event(EventFactory.make(
                    clock: clock,
                    domain: .memory,
                    type: .memoryPressureChanged,
                    entity: system,
                    summary: "Memory pressure changed from \(previousPressure) to \(pressure).",
                    source: source,
                    metadata: ["from": previousPressure, "to": pressure]
                )))
            }
            previousPressure = pressure
        }

        let thermal = ThermalNames.stateName(ProcessInfo.processInfo.thermalState)
        await sink.send(.metric(MetricFactory.make(
            clock: clock,
            domain: .thermal,
            name: .thermalState,
            entity: system,
            value: .state(thermal),
            unit: .enumeration,
            source: source
        )))
        if let previousThermal, previousThermal != thermal {
            await sink.send(.event(EventFactory.make(
                clock: clock,
                domain: .thermal,
                type: .thermalStateChanged,
                entity: system,
                summary: "Thermal state changed from \(previousThermal) to \(thermal).",
                source: source,
                metadata: ["from": previousThermal, "to": thermal]
            )))
        }
        previousThermal = thermal
    }
}
