import Foundation
import MacObserverDomain
import MacObserverCollectors
import MacObserverStorage

@MainActor
enum TelemetrySession {
    static func openStore() -> (path: String, store: SQLiteTelemetryStore, sink: PersistingSink)? {
        do {
            let path = try SQLiteTelemetryStore.applicationSupportPath()
            let store = try SQLiteTelemetryStore(path: path)
            let sink = PersistingSink(persist: store)
            return (path, store, sink)
        } catch {
            return nil
        }
    }

    static func makePipeline(
        sinks: [any TelemetrySink],
        enabled: Set<String>
    ) async throws -> (pipeline: CollectorPipeline, capabilities: [CapabilityDescriptor]) {
        let collectors = StandardCollectors.make()
        let capabilities = collectors.map(\.capability)
        let pipeline = CollectorPipeline(collectors: collectors, additionalSinks: sinks)
        try await pipeline.start(enabled: enabled)
        return (pipeline, capabilities)
    }
}

@MainActor
struct HistoryRepository {
    var store: SQLiteTelemetryStore?
    var persisting: PersistingSink?
    var previewEvents: [Event] = []
    var previewHistory: [Metric] = []
    var isLayoutPreview = false

    func events(
        window: HistoryWindow,
        live: [Event]
    ) async throws -> [Event] {
        let end = Date()
        let start = end.addingTimeInterval(-window.duration)
        if isLayoutPreview {
            return previewEvents
                .filter { $0.time.wallTime >= start && $0.time.wallTime <= end }
                .sorted { $0.time.wallTime > $1.time.wallTime }
        }
        if let store {
            await persisting?.flush()
            let rows = try await store.events(matching: EventQuery(
                range: TimeRange(start: start, end: end),
                limit: 500
            ))
            return Array(rows.reversed())
        }
        return live
            .filter { $0.time.wallTime >= start && $0.time.wallTime <= end }
            .reversed()
    }

    func metricSeries(
        for target: MetricInspectTarget,
        window: HistoryWindow,
        live: [Metric]
    ) async throws -> [Metric] {
        let span = InvestigationInterval.range(for: window.duration)
        let bucket = InvestigationInterval.bucketSeconds(windowDuration: window.duration)
        if isLayoutPreview {
            return previewHistory.filter {
                $0.name == target.metricName
                    && (target.entityKey == nil || $0.entity.identityKey == target.entityKey)
                    && $0.time.wallTime >= span.start
                    && $0.time.wallTime <= span.end
            }.sorted { $0.time.wallTime < $1.time.wallTime }
        }
        await persisting?.flush()
        if let store {
            return try await store.metrics(matching: MetricQuery(
                range: span,
                entityKey: target.entityKey,
                name: target.metricName,
                bucketSeconds: bucket
            ))
        }
        return live.filter {
            $0.name == target.metricName
                && (target.entityKey == nil || $0.entity.identityKey == target.entityKey)
                && $0.time.wallTime >= span.start
                && $0.time.wallTime <= span.end
        }
    }

    func relatedEvents(
        for target: MetricInspectTarget,
        range: TimeRange,
        live: [Event]
    ) async throws -> [Event] {
        if isLayoutPreview {
            return previewEvents.filter {
                $0.domain == target.domain
                    && $0.time.wallTime >= range.start
                    && $0.time.wallTime <= range.end
            }.sorted { $0.time.wallTime > $1.time.wallTime }
        }
        await persisting?.flush()
        if let store {
            return try await store.events(matching: EventQuery(
                range: range,
                domain: target.domain,
                limit: 20
            ))
        }
        return live.filter {
            $0.domain == target.domain
                && $0.time.wallTime >= range.start
                && $0.time.wallTime <= range.end
        }
    }
}

@MainActor
struct CapabilityController {
    private let preferences = CapabilityPreferences()
    private(set) var disabledIDs: Set<String> = []
    private(set) var capabilities: [CapabilityDescriptor] = []

    mutating func bootstrap(from capabilities: [CapabilityDescriptor]) {
        self.capabilities = capabilities
        let enabled = preferences.enabledIDs(from: capabilities)
        disabledIDs = Set(capabilities.map(\.id)).subtracting(enabled)
    }

    func isEnabled(_ id: String, isLayoutPreview: Bool) -> Bool {
        if isLayoutPreview {
            return !disabledIDs.contains(id)
        }
        if let capability = capabilities.first(where: { $0.id == id }) {
            return preferences.isEnabled(capability)
        }
        return !disabledIDs.contains(id)
    }

    mutating func setEnabled(_ id: String, enabled: Bool, isLayoutPreview: Bool) -> CapabilityDescriptor? {
        guard let capability = capabilities.first(where: { $0.id == id }) else { return nil }
        if enabled {
            disabledIDs.remove(id)
        } else {
            disabledIDs.insert(id)
        }
        if !isLayoutPreview {
            preferences.setEnabled(capability, enabled: enabled)
        }
        return capability
    }

    mutating func applyPreviewDefaults(_ capabilities: [CapabilityDescriptor]) {
        self.capabilities = capabilities
        disabledIDs = Set(capabilities.compactMap { $0.defaultEnabled ? nil : $0.id })
    }
}

@MainActor
enum ExplanationService {
    static func select(
        events: [Event],
        metrics: [Metric],
        now: Date = Date()
    ) -> Explanation? {
        ExplanationRules.select(events: events, metrics: metrics, now: now)
    }
}
