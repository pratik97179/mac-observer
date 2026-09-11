import Darwin
import Foundation

struct ProcessResourceSnapshot: Sendable, Equatable {
    var pid: Int32
    var startSeconds: UInt64
    var startMicroseconds: UInt64
    var displayName: String
    var cpuNanoseconds: UInt64
    var residentBytes: UInt64
}

protocol ProcessResourceSource: Sendable {
    func currentProcesses() -> [ProcessResourceSnapshot]
}

struct DarwinProcessResourceSource: ProcessResourceSource {
    func currentProcesses() -> [ProcessResourceSnapshot] {
        DarwinProcessSampler.sample()
    }
}

/// Process identity and resource use from `proc_pidinfo`.
///
/// `proc_pid_rusage` is not used. That API takes a flavor and a `void **` with
/// no buffer length. The kernel writes `rusage_info_current` (464 bytes on
/// macOS 26/27, flavor 6). A `rusage_info_v4` stack slot is 296 bytes, so a
/// V4 call still overflows and aborts via `__stack_chk_fail`.
///
/// `proc_pidinfo` copies at most the caller-supplied size, so SDK and kernel
/// can disagree without smashing the stack.
enum DarwinProcessSampler {
    static func sample() -> [ProcessResourceSnapshot] {
        let pids = listPIDs()
        var result: [ProcessResourceSnapshot] = []
        result.reserveCapacity(min(pids.count, 512))

        for pid in pids where pid > 0 {
            var bsd = proc_bsdinfo()
            let bsdSize = proc_pidinfo(
                pid,
                PROC_PIDTBSDINFO,
                0,
                &bsd,
                Int32(MemoryLayout<proc_bsdinfo>.size)
            )
            guard bsdSize > 0 else { continue }

            var task = proc_taskinfo()
            let taskSize = proc_pidinfo(
                pid,
                PROC_PIDTASKINFO,
                0,
                &task,
                Int32(MemoryLayout<proc_taskinfo>.size)
            )
            guard taskSize > 0 else { continue }

            result.append(
                ProcessResourceSnapshot(
                    pid: pid,
                    startSeconds: UInt64(bsd.pbi_start_tvsec),
                    startMicroseconds: UInt64(bsd.pbi_start_tvusec),
                    displayName: processName(from: bsd, pid: pid),
                    cpuNanoseconds: task.pti_total_user &+ task.pti_total_system,
                    residentBytes: UInt64(task.pti_resident_size)
                )
            )
        }

        return result
    }

    private static func listPIDs() -> [Int32] {
        var needed = proc_listallpids(nil, 0)
        guard needed > 0 else { return [] }

        var pids = [Int32](repeating: 0, count: (Int(needed) / MemoryLayout<Int32>.size) + 32)
        needed = pids.withUnsafeMutableBufferPointer { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count * MemoryLayout<Int32>.size))
        }
        guard needed > 0 else { return [] }
        return Array(pids.prefix(Int(needed) / MemoryLayout<Int32>.size))
    }

    private static func processName(from bsd: proc_bsdinfo, pid: Int32) -> String {
        let longName = cString(bsd.pbi_name)
        if !longName.isEmpty { return longName }
        let comm = cString(bsd.pbi_comm)
        if !comm.isEmpty { return comm }
        var name = [CChar](repeating: 0, count: Int(MAXCOMLEN) + 1)
        proc_name(pid, &name, UInt32(name.count))
        let end = name.firstIndex(of: 0) ?? name.endIndex
        return String(decoding: name[..<end].map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private static func cString<T>(_ tuple: T) -> String {
        withUnsafeBytes(of: tuple) { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            let end = bytes.firstIndex(of: 0) ?? bytes.endIndex
            return String(decoding: bytes[..<end], as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
