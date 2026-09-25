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
        snapshot.series(named: .cpuUtilizationRatio).map(\.value)
    }
}
