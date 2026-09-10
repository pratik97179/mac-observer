import Foundation
import Darwin
import MacObserverDomain

struct CPULoadSample {
    var ticks: [UInt32]
}

enum MachHostSampler {
    static func cpuLoad() -> CPULoadSample? {
        var processorCount: natural_t = 0
        var infoArray: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let kr = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &infoArray,
            &infoCount
        )
        guard kr == KERN_SUCCESS, let infoArray, processorCount > 0 else { return nil }

        let cpuCount = Int(processorCount)
        let loadInfo = UnsafeMutableRawPointer(infoArray).assumingMemoryBound(to: processor_cpu_load_info.self)
        var totals = [UInt32](repeating: 0, count: Int(CPU_STATE_MAX))
        for cpu in 0..<cpuCount {
            let ticks = loadInfo[cpu].cpu_ticks
            totals[0] &+= ticks.0
            totals[1] &+= ticks.1
            totals[2] &+= ticks.2
            totals[3] &+= ticks.3
        }

        let byteCount = vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size)
        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: infoArray)), byteCount)
        return CPULoadSample(ticks: totals)
    }

    static func vmStats() -> vm_statistics64? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )
        let kr = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }
        return stats
    }

    static func swapUsedBytes() -> UInt64? {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let status = sysctlbyname("vm.swapusage", &usage, &size, nil, 0)
        guard status == 0 else { return nil }
        return usage.xsu_used
    }

    static func memoryPressureState() -> String? {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let status = sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0)
        guard status == 0 else { return nil }
        switch level {
        case 0, 1: return "normal"
        case 2: return "warning"
        case 3: return "urgent"
        default: return "critical"
        }
    }
}
