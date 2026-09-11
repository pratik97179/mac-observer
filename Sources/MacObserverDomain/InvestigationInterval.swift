import Foundation

public enum InvestigationInterval {
    public static func bucketSeconds(windowDuration: TimeInterval) -> TimeInterval {
        max(windowDuration / 240, 2)
    }

    public static func around(_ time: Date, bucketSeconds: TimeInterval, in range: TimeRange) -> TimeRange {
        let pad = max(bucketSeconds, 2)
        let start = max(range.start, time.addingTimeInterval(-pad))
        let end = min(range.end, time.addingTimeInterval(pad))
        if start <= end {
            return TimeRange(start: start, end: end)
        }
        return range
    }

    public static func range(for duration: TimeInterval, now: Date = Date()) -> TimeRange {
        TimeRange(start: now.addingTimeInterval(-duration), end: now)
    }
}
