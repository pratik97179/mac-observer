import Foundation
import MacObserverDomain

public actor MemoryTelemetryStore: TelemetryStore {
    private var metrics: [Metric] = []
    private var events: [Event] = []

    public init() {}

    public func insert(metrics: [Metric]) async throws {
        self.metrics.append(contentsOf: metrics)
    }

    public func insert(events: [Event]) async throws {
        self.events.append(contentsOf: events)
    }

    public func metrics(matching query: MetricQuery) async throws -> [Metric] {
        let matched = self.metrics.filter { metric in
            metric.time.wallTime >= query.range.start
                && metric.time.wallTime <= query.range.end
                && (query.entityKey == nil || metric.entity.identityKey == query.entityKey)
                && (query.name == nil || metric.name == query.name)
                && (query.domain == nil || metric.domain == query.domain)
        }
        .sorted { $0.time.wallTime < $1.time.wallTime }
        if let bucket = query.bucketSeconds {
            return SeriesBucketing.lastSample(in: matched, bucketSeconds: bucket)
        }
        return matched
    }

    public func events(matching query: EventQuery) async throws -> [Event] {
        let matched = self.events.filter { event in
            event.time.wallTime >= query.range.start
                && event.time.wallTime <= query.range.end
                && (query.entityKey == nil || event.entity.identityKey == query.entityKey)
                && (query.type == nil || event.type == query.type)
                && (query.domain == nil || event.domain == query.domain)
        }
        .sorted { $0.time.wallTime < $1.time.wallTime }
        guard let limit = query.limit, matched.count > limit else { return matched }
        return Array(matched.suffix(limit))
    }

    public func applyRetention(_ policy: RetentionPolicy, now: Date) async throws {
        let metricCutoff = now.addingTimeInterval(-policy.recentMetrics)
        let eventCutoff = now.addingTimeInterval(-policy.events)
        metrics.removeAll { $0.time.wallTime < metricCutoff }
        events.removeAll { $0.time.wallTime < eventCutoff }
    }

    public func deleteAll() async throws {
        metrics.removeAll()
        events.removeAll()
    }
}
