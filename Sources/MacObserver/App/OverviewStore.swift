import Foundation
import SwiftUI
import MacObserverDomain
import MacObserverCollectors
import MacObserverStorage

@MainActor
@Observable
final class OverviewStore {
    private var pipeline: CollectorPipeline?
    private var persisting: PersistingSink?
    private var store: SQLiteTelemetryStore?
    private let preferences = CapabilityPreferences()
    private(set) var snapshot: LiveSnapshot
    private(set) var capabilities: [CapabilityDescriptor] = []
    private(set) var historyPath: String?
    private(set) var historyMessage: String?
    private(set) var historyEvents: [Event] = []
    private(set) var eventWindow: HistoryWindow = .lastHour
    private(set) var explanation: Explanation?
    let startedAt: Date
    private var persistedExplanationIDs: Set<String> = []
    private var disabledCapabilityIDs: Set<String> = []

    init() {
        startedAt = Date()
        snapshot = LiveSnapshot(
            metrics: [],
            events: [],
            availability: [:],
            capturedAt: ObservationTime(wallTime: Date())
        )
    }

    func isCapabilityEnabled(_ id: String) -> Bool {
        !disabledCapabilityIDs.contains(id)
    }

    func capabilityState(_ id: String) -> String {
        if disabledCapabilityIDs.contains(id) {
            return "Off"
        }
        switch snapshot.availability[id] {
        case .available:
            return "Collecting"
        case .unavailable(let reason):
            return reason
        case .denied:
            return "Denied"
        case .stale(let asOf):
            return "Stale since \(asOf.formatted(date: .omitted, time: .shortened))"
        case .none:
            return "Starting"
        }
    }

    func setCapabilityEnabled(_ id: String, enabled: Bool) {
        preferences.setEnabled(id, enabled: enabled)
        if enabled {
            disabledCapabilityIDs.remove(id)
        } else {
            disabledCapabilityIDs.insert(id)
        }
        Task {
            try? await pipeline?.setEnabled(id, enabled: enabled)
            if let pipeline {
                let next = await pipeline.snapshot()
                applySnapshot(next)
                await refreshHistory()
                await refreshExplanation()
            }
        }
    }

    func deleteLocalHistory() async {
        guard store != nil else {
            historyMessage = "No local history file is open."
            return
        }
        await persisting?.flush()
        do {
            try await store?.deleteAll()
            historyMessage = "Local history deleted. Live sampling continues."
            explanation = nil
            persistedExplanationIDs = []
            await refreshHistory()
            await refreshExplanation()
        } catch {
            historyMessage = "Could not delete local history."
        }
    }

    func setEventWindow(_ window: HistoryWindow) {
        eventWindow = window
        Task { await refreshHistory() }
    }

    func refreshHistory() async {
        let end = Date()
        let start = end.addingTimeInterval(-eventWindow.duration)
        if let store {
            await persisting?.flush()
            do {
                let rows = try await store.events(matching: EventQuery(
                    range: TimeRange(start: start, end: end),
                    limit: 500
                ))
                historyEvents = Array(rows.reversed())
                return
            } catch {
                historyMessage = "Could not read local event history."
            }
        }
        historyEvents = snapshot.events
            .filter { $0.time.wallTime >= start && $0.time.wallTime <= end }
            .reversed()
    }

    func metricSeries(for target: MetricInspectTarget, window: HistoryWindow) async -> [Metric] {
        let span = InvestigationInterval.range(for: window.duration)
        let bucket = InvestigationInterval.bucketSeconds(windowDuration: window.duration)
        await persisting?.flush()
        if let store {
            return (try? await store.metrics(matching: MetricQuery(
                range: span,
                entityKey: target.entityKey,
                name: target.metricName,
                bucketSeconds: bucket
            ))) ?? []
        }
        return snapshot.metrics.filter {
            $0.name == target.metricName
                && (target.entityKey == nil || $0.entity.identityKey == target.entityKey)
                && $0.time.wallTime >= span.start
                && $0.time.wallTime <= span.end
        }
    }

    func relatedEvents(for target: MetricInspectTarget, window: HistoryWindow) async -> [Event] {
        await relatedEvents(for: target, range: InvestigationInterval.range(for: window.duration))
    }

    func relatedEvents(for target: MetricInspectTarget, range: TimeRange) async -> [Event] {
        await persisting?.flush()
        if let store {
            return (try? await store.events(matching: EventQuery(
                range: range,
                domain: target.domain,
                limit: 20
            ))) ?? []
        }
        return snapshot.events.filter {
            $0.domain == target.domain
                && $0.time.wallTime >= range.start
                && $0.time.wallTime <= range.end
        }
    }

    func refreshNow() async {
        guard let pipeline else { return }
        let next = await pipeline.snapshot()
        applySnapshot(next)
        await refreshHistory()
        await refreshExplanation()
    }

    func refreshExplanation() async {
        let now = Date()
        let eventRange = TimeRange(
            start: now.addingTimeInterval(-ExplanationRules.recentHorizon),
            end: now
        )
        let events = await events(in: eventRange)
        let triggerTime = events
            .filter(ExplanationRules.isSupportedTrigger)
            .map(\.time.wallTime)
            .max()
        let metricStart = min(
            now.addingTimeInterval(-ExplanationRules.lookback),
            triggerTime?.addingTimeInterval(-ExplanationRules.lookback) ?? now
        )
        let metrics = await metrics(in: TimeRange(start: metricStart, end: now))
        let next = ExplanationRules.select(events: events, metrics: metrics, now: now)
        explanation = next
        await persistExplanationIfNeeded(next, now: now)
    }

    func run() async {
        let extraSinks: [any TelemetrySink]
        if let path = try? SQLiteTelemetryStore.applicationSupportPath(),
           let store = try? SQLiteTelemetryStore(path: path) {
            try? await store.applyRetention(.documented, now: Date())
            let sink = PersistingSink(persist: store)
            persisting = sink
            self.store = store
            historyPath = path
            extraSinks = [sink]
        } else {
            extraSinks = []
        }

        let collectors = StandardCollectors.make()
        capabilities = collectors.map(\.capability)
        let knownIDs = capabilities.map(\.id)
        let enabled = preferences.enabledIDs(from: knownIDs)
        disabledCapabilityIDs = Set(knownIDs).subtracting(enabled)

        let pipeline = CollectorPipeline(
            collectors: collectors,
            additionalSinks: extraSinks
        )
        self.pipeline = pipeline
        try? await pipeline.start(enabled: enabled)

        var ticks = 0
        while !Task.isCancelled {
            let next = await pipeline.snapshot()
            applySnapshot(next)
            ticks += 1
            if ticks.isMultiple(of: 5) {
                await persisting?.flush()
                await refreshExplanation()
            }
            if ticks.isMultiple(of: 300) {
                try? await store?.applyRetention(.documented, now: Date())
            }
            try? await Task.sleep(for: .seconds(1))
        }

        await persisting?.flush()
        await pipeline.stop()
    }

    private func applySnapshot(_ next: LiveSnapshot) {
        guard !snapshot.hasSameTelemetry(as: next) else { return }
        snapshot = next
    }

    private func persistExplanationIfNeeded(_ explanation: Explanation?, now: Date) async {
        guard let explanation, !persistedExplanationIDs.contains(explanation.id) else { return }
        let alreadyStored = historyEvents.contains {
            $0.type == .explanationGenerated && $0.metadata["explanation_id"] == explanation.id
        }
        if alreadyStored {
            persistedExplanationIDs.insert(explanation.id)
            return
        }
        persistedExplanationIDs.insert(explanation.id)
        let matched = snapshot.metrics.first { $0.entity.identityKey == explanation.inspect.entityKey }
        let system = snapshot.metrics.first { metric in
            if case .system = metric.entity { return true }
            return false
        }
        let entity = matched?.entity ?? system?.entity ?? .system(bootSession: BootSessionID("unknown"))
        try? await store?.insert(events: [explanation.asEvent(now: now, entity: entity)])
        await refreshHistory()
    }

    private func events(in range: TimeRange) async -> [Event] {
        var rows: [Event] = []
        if let store {
            await persisting?.flush()
            rows = (try? await store.events(matching: EventQuery(range: range, limit: 200))) ?? []
        }
        let live = snapshot.events.filter {
            $0.time.wallTime >= range.start && $0.time.wallTime <= range.end
        }
        var seen = Set(rows.map(\.id))
        return rows + live.filter { seen.insert($0.id).inserted }
    }

    private func metrics(in range: TimeRange) async -> [Metric] {
        var rows: [Metric] = []
        if let store {
            await persisting?.flush()
            rows = (try? await store.metrics(matching: MetricQuery(range: range))) ?? []
        }
        let live = snapshot.metrics.filter {
            $0.time.wallTime >= range.start && $0.time.wallTime <= range.end
        }
        if rows.isEmpty {
            return live
        }
        var seen = Set(rows.map(\.id))
        return rows + live.filter { seen.insert($0.id).inserted }
    }
}