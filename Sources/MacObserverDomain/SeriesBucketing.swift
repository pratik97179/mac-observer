import Foundation

public enum SeriesBucketing {
    public static func lastSample(in metrics: [Metric], bucketSeconds: TimeInterval) -> [Metric] {
        guard bucketSeconds > 0 else {
            return metrics.sorted { $0.time.wallTime < $1.time.wallTime }
        }
        var chosen: [String: Metric] = [:]
        var order: [String] = []
        for metric in metrics.sorted(by: { $0.time.wallTime < $1.time.wallTime }) {
            let bucket = Int64((metric.time.wallTime.timeIntervalSince1970 / bucketSeconds).rounded(.down))
            let key = "\(metric.entity.identityKey)|\(metric.name.rawValue)|\(bucket)"
            if chosen[key] == nil {
                order.append(key)
            }
            chosen[key] = metric
        }
        return order.compactMap { chosen[$0] }
    }
}
