import Foundation

public enum MetricDownsampler {
    public static func retainedMetrics(_ metrics: [Metric], policy: RetentionPolicy, now: Date) -> [Metric] {
        let recentCutoff = now.addingTimeInterval(-policy.recentMetrics)
        let longTermCutoff = now.addingTimeInterval(-policy.longTermMetrics)
        let recent = metrics.filter { $0.time.wallTime >= recentCutoff }
        let aging = metrics.filter { $0.time.wallTime < recentCutoff && $0.time.wallTime >= longTermCutoff }
        let alreadyRolled = aging.filter { $0.retentionClass == .longTerm }
        let rawAging = aging.filter { $0.retentionClass != .longTerm }
        return (recent + alreadyRolled + collapse(rawAging, bucketSeconds: policy.downsampleBucket))
            .sorted { $0.time.wallTime < $1.time.wallTime }
    }

    public static func collapse(_ metrics: [Metric], bucketSeconds: TimeInterval) -> [Metric] {
        guard bucketSeconds > 0 else { return metrics }
        var groups: [String: [Metric]] = [:]
        var order: [String] = []
        for metric in metrics.sorted(by: { $0.time.wallTime < $1.time.wallTime }) {
            let bucket = Int64((metric.time.wallTime.timeIntervalSince1970 / bucketSeconds).rounded(.down))
            let key = "\(metric.entity.identityKey)|\(metric.name.rawValue)|\(bucket)"
            if groups[key] == nil {
                order.append(key)
            }
            groups[key, default: []].append(metric)
        }
        return order.compactMap { groups[$0].flatMap { roll($0, bucketSeconds: bucketSeconds) } }
    }

    private static func roll(_ samples: [Metric], bucketSeconds: TimeInterval) -> Metric? {
        guard let last = samples.last else { return nil }
        let count = samples.count
        let numbers = samples.compactMap { numeric($0.value) }
        if numbers.count == samples.count, let minValue = numbers.min(), let maxValue = numbers.max() {
            let average = numbers.reduce(0, +) / Double(count)
            return Metric(
                time: last.time,
                domain: last.domain,
                name: last.name,
                entity: last.entity,
                value: boxed(average, like: last.value),
                unit: last.unit,
                dimensions: [
                    "downsample.min": string(minValue),
                    "downsample.max": string(maxValue),
                    "downsample.count": "\(count)"
                ],
                source: last.source,
                quality: .derived,
                retentionClass: .longTerm,
                derivation: Derivation(
                    sourceMetricIDs: samples.prefix(8).map(\.id),
                    method: "mean_\(Int(bucketSeconds))s"
                )
            )
        }
        return Metric(
            time: last.time,
            domain: last.domain,
            name: last.name,
            entity: last.entity,
            value: last.value,
            unit: last.unit,
            dimensions: ["downsample.count": "\(count)"],
            source: last.source,
            quality: .derived,
            retentionClass: .longTerm,
            derivation: Derivation(
                sourceMetricIDs: samples.prefix(8).map(\.id),
                method: "last_\(Int(bucketSeconds))s"
            )
        )
    }

    private static func numeric(_ value: MetricValue) -> Double? {
        switch value {
        case .ratio(let value), .double(let value): value
        case .int(let value): Double(value)
        case .state: nil
        }
    }

    private static func boxed(_ average: Double, like value: MetricValue) -> MetricValue {
        switch value {
        case .ratio: .ratio(average)
        case .double: .double(average)
        case .int: .int(Int64(average.rounded()))
        case .state(let state): .state(state)
        }
    }

    private static func string(_ value: Double) -> String {
        String(format: "%.6g", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
