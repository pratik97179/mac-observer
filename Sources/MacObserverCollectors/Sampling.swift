import Foundation
import Darwin
import MacObserverDomain

enum SampleMath {
    static func cpuUtilizationRatio(previous: [UInt32], current: [UInt32]) -> Double? {
        guard previous.count == current.count, previous.count >= 4 else { return nil }
        var busy: UInt64 = 0
        var total: UInt64 = 0
        for index in current.indices {
            let delta = UInt64(current[index] &- previous[index])
            total += delta
            if index != Int(CPU_STATE_IDLE) {
                busy += delta
            }
        }
        guard total > 0 else { return nil }
        return min(1, Double(busy) / Double(total))
    }

    static func perSecond(previous: UInt64, current: UInt64, elapsed: TimeInterval) -> Double? {
        guard elapsed > 0, current >= previous else { return nil }
        return Double(current - previous) / elapsed
    }

    static func cpuTimeRatio(
        previousNanoseconds: UInt64,
        currentNanoseconds: UInt64,
        elapsedSeconds: TimeInterval
    ) -> Double? {
        guard elapsedSeconds > 0, currentNanoseconds >= previousNanoseconds else { return nil }
        let cpuSeconds = Double(currentNanoseconds - previousNanoseconds) / 1_000_000_000
        return min(1, max(0, cpuSeconds / elapsedSeconds))
    }
}

enum BootSession {
    static func current() -> BootSessionID {
        var boot = timeval()
        var size = MemoryLayout<timeval>.size
        let status = sysctlbyname("kern.boottime", &boot, &size, nil, 0)
        if status == 0 {
            return BootSessionID("\(boot.tv_sec).\(boot.tv_usec)")
        }
        return BootSessionID("unknown")
    }
}

enum MetricFactory {
    static func make(
        clock: any Clock,
        domain: TelemetryDomain,
        name: MetricName,
        entity: Entity,
        value: MetricValue,
        unit: MacObserverDomain.Unit,
        source: String,
        quality: ObservationQuality = .direct,
        dimensions: [String: String] = [:]
    ) -> Metric {
        Metric(
            time: clock.observationTime,
            domain: domain,
            name: name,
            entity: entity,
            value: value,
            unit: unit,
            dimensions: dimensions,
            source: source,
            quality: quality
        )
    }
}

enum ThermalNames {
    static func stateName(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }
}
