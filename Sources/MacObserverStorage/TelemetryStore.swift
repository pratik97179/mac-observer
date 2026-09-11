import Foundation
import MacObserverDomain

public protocol TelemetryStore: TelemetryPersisting, Sendable {
    func insert(metrics: [Metric]) async throws
    func insert(events: [Event]) async throws
    func metrics(matching query: MetricQuery) async throws -> [Metric]
    func events(matching query: EventQuery) async throws -> [Event]
    func applyRetention(_ policy: RetentionPolicy, now: Date) async throws
    func deleteAll() async throws
    func deleteSource(_ source: String) async throws
}

public enum StoreError: Error, Equatable {
    case sqlite(String)
    case decodingFailed
}
