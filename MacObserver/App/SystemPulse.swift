import Foundation
import MacObserverDomain

enum LiveSeries {
    static func values(for reading: OverviewReading, snapshot: LiveSnapshot) -> [Double] {
        points(for: reading, snapshot: snapshot).map(\.value)
    }

    static func points(for reading: OverviewReading, snapshot: LiveSnapshot) -> [SamplePoint] {
        if let inspect = reading.inspect {
            return snapshot.series(named: inspect.metricName, entityKey: inspect.entityKey)
        }
        switch reading.name {
        case "Network", "Receive":
            return snapshot.series(named: .networkRxBytesPerSecond)
        case "Transmit":
            return snapshot.series(named: .networkTxBytesPerSecond)
        case "Storage", "Read":
            return snapshot.series(named: .storageReadBytesPerSecond)
        case "Write":
            return snapshot.series(named: .storageWriteBytesPerSecond)
        default:
            return []
        }
    }
}

enum SystemPulse {
    static func series(from snapshot: LiveSnapshot) -> [Double] {
        snapshot.systemSeries(named: .cpuUtilizationRatio).map(\.value)
    }
}

extension LiveSnapshot {
    /// Identity key of the host (`.system`) entity, if any system metric has been sampled.
    var systemEntityKey: String? {
        metrics.first { metric in
            if case .system = metric.entity { return true }
            return false
        }?.entity.identityKey
    }

    /// The host-wide series for `name`. `series(named:)` without a key picks whichever
    /// entity has the longest history, which for CPU can be a single process.
    func systemSeries(named name: MetricName) -> [SamplePoint] {
        guard let key = systemEntityKey else { return [] }
        return series(named: name, entityKey: key)
    }

    /// Sum of the latest value across every entity that reports `name` (e.g. all interfaces).
    func latestTotal(named name: MetricName) -> Double {
        metrics.reduce(0.0) { total, metric in
            guard metric.name == name else { return total }
            switch metric.value {
            case .int(let value): return total + Double(value)
            case .double(let value), .ratio(let value): return total + value
            default: return total
            }
        }
    }
}
