import Foundation
import MacObserverCollectors
import MacObserverDomain

struct TimelineTrace: Identifiable {
    let id: String
    let name: String
    let points: [SamplePoint]
    let opacity: Double
    let unit: MacObserverDomain.Unit
}

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

    static func traces(from snapshot: LiveSnapshot) -> [TimelineTrace] {
        [
            TimelineTrace(
                id: "cpu",
                name: "CPU",
                points: snapshot.series(named: .cpuUtilizationRatio),
                opacity: 1,
                unit: .ratio
            ),
            TimelineTrace(
                id: "memory",
                name: "Memory",
                points: snapshot.series(named: .memoryUsedBytes),
                opacity: 0.85,
                unit: .bytes
            ),
            TimelineTrace(
                id: "network",
                name: "Network",
                points: summedRate(snapshot, names: [.networkRxBytesPerSecond, .networkTxBytesPerSecond]),
                opacity: 0.7,
                unit: .bytesPerSecond
            ),
            TimelineTrace(
                id: "disk",
                name: "Disk",
                points: summedRate(snapshot, names: [.storageReadBytesPerSecond, .storageWriteBytesPerSecond]),
                opacity: 0.55,
                unit: .bytesPerSecond
            )
        ].filter { $0.points.count >= 2 }
    }

    private static func summedRate(_ snapshot: LiveSnapshot, names: [MetricName]) -> [SamplePoint] {
        let tracks = names.map { snapshot.series(named: $0) }.filter { $0.count >= 2 }
        guard let count = tracks.map(\.count).min() else { return [] }
        return (0..<count).map { index in
            let sample = tracks[0][tracks[0].count - count + index]
            let sum = tracks.reduce(0.0) { partial, track in
                partial + track[track.count - count + index].value
            }
            return SamplePoint(time: sample.time, value: sum)
        }
    }
}
