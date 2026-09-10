import Foundation

public struct TimeRange: Sendable, Hashable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

public struct MetricQuery: Sendable, Hashable {
    public var range: TimeRange
    public var entityKey: String?
    public var name: MetricName?
    public var domain: TelemetryDomain?
    public var bucketSeconds: TimeInterval?

    public init(
        range: TimeRange,
        entityKey: String? = nil,
        name: MetricName? = nil,
        domain: TelemetryDomain? = nil,
        bucketSeconds: TimeInterval? = nil
    ) {
        self.range = range
        self.entityKey = entityKey
        self.name = name
        self.domain = domain
        self.bucketSeconds = bucketSeconds
    }
}

public struct EventQuery: Sendable, Hashable {
    public var range: TimeRange
    public var entityKey: String?
    public var type: EventType?
    public var domain: TelemetryDomain?
    public var limit: Int?

    public init(
        range: TimeRange,
        entityKey: String? = nil,
        type: EventType? = nil,
        domain: TelemetryDomain? = nil,
        limit: Int? = nil
    ) {
        self.range = range
        self.entityKey = entityKey
        self.type = type
        self.domain = domain
        self.limit = limit
    }
}

public protocol TelemetryPersisting: Sendable {
    func insert(metrics: [Metric]) async throws
    func insert(events: [Event]) async throws
}

public struct RetentionPolicy: Sendable, Hashable {
    public var recentMetrics: TimeInterval
    public var events: TimeInterval

    public static let documented = RetentionPolicy(
        recentMetrics: 7 * 24 * 60 * 60,
        events: 30 * 24 * 60 * 60
    )

    public init(recentMetrics: TimeInterval, events: TimeInterval) {
        self.recentMetrics = recentMetrics
        self.events = events
    }
}
