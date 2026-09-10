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

    public init(
        range: TimeRange,
        entityKey: String? = nil,
        name: MetricName? = nil,
        domain: TelemetryDomain? = nil
    ) {
        self.range = range
        self.entityKey = entityKey
        self.name = name
        self.domain = domain
    }
}

public struct EventQuery: Sendable, Hashable {
    public var range: TimeRange
    public var entityKey: String?
    public var type: EventType?
    public var domain: TelemetryDomain?

    public init(
        range: TimeRange,
        entityKey: String? = nil,
        type: EventType? = nil,
        domain: TelemetryDomain? = nil
    ) {
        self.range = range
        self.entityKey = entityKey
        self.type = type
        self.domain = domain
    }
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
