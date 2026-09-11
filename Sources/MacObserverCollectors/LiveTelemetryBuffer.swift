import Foundation
import MacObserverDomain

public struct SamplePoint: Sendable, Hashable {
    public let time: Date
    public let value: Double

    public init(time: Date, value: Double) {
        self.time = time
        self.value = value
    }
}

public struct LiveSnapshot: Sendable, Equatable {
    public var metrics: [Metric]
    public var events: [Event]
    public var availability: [String: CapabilityAvailability]
    public var series: [String: [SamplePoint]]
    public var capturedAt: ObservationTime

    public init(
        metrics: [Metric],
        events: [Event],
        availability: [String: CapabilityAvailability],
        series: [String: [SamplePoint]] = [:],
        capturedAt: ObservationTime
    ) {
        self.metrics = metrics
        self.events = events
        self.availability = availability
        self.series = series
        self.capturedAt = capturedAt
    }

    public func hasSameTelemetry(as other: LiveSnapshot) -> Bool {
        metrics == other.metrics
            && events == other.events
            && availability == other.availability
            && series == other.series
    }

    public func metric(named name: MetricName, entity: Entity) -> Metric? {
        metrics.first { $0.name == name && $0.entity == entity }
    }

    public func series(named name: MetricName, entityKey: String? = nil) -> [SamplePoint] {
        if let entityKey {
            return series["\(name.rawValue)|\(entityKey)"] ?? []
        }
        let matching = series.filter { $0.key.hasPrefix(name.rawValue + "|") }
        if matching.count == 1 {
            return matching.values.first ?? []
        }
        return matching.values.max(by: { $0.count < $1.count }) ?? []
    }
}

public actor LiveTelemetryBuffer: TelemetrySink {
    private var metrics: [String: Metric] = [:]
    private var events: [Event] = []
    private var availability: [String: CapabilityAvailability] = [:]
    private var series: [String: [SamplePoint]] = [:]
    private let clock: any Clock
    private let eventLimit: Int
    private let seriesLimit: Int

    public init(clock: any Clock = SystemClock(), eventLimit: Int = 200, seriesLimit: Int = 90) {
        self.clock = clock
        self.eventLimit = eventLimit
        self.seriesLimit = seriesLimit
    }

    public func send(_ observation: TelemetryObservation) async {
        switch observation {
        case .metric(let metric):
            let key = Self.key(for: metric)
            metrics[key] = metric
            if let value = Self.numeric(metric) {
                var points = series[key] ?? []
                points.append(SamplePoint(time: metric.time.wallTime, value: value))
                if points.count > seriesLimit {
                    points.removeFirst(points.count - seriesLimit)
                }
                series[key] = points
            }
        case .event(let event):
            events.append(event)
            if events.count > eventLimit {
                events.removeFirst(events.count - eventLimit)
            }
        case .availability(let capabilityID, let state):
            availability[capabilityID] = state
        }
    }

    public func snapshot() -> LiveSnapshot {
        LiveSnapshot(
            metrics: Array(metrics.values),
            events: events,
            availability: availability,
            series: series,
            capturedAt: clock.observationTime
        )
    }

    private static func key(for metric: Metric) -> String {
        "\(metric.name.rawValue)|\(metric.entity.identityKey)"
    }

    private static func numeric(_ metric: Metric) -> Double? {
        switch metric.value {
        case .ratio(let value), .double(let value): value
        case .int(let value): Double(value)
        case .state: nil
        }
    }
}
