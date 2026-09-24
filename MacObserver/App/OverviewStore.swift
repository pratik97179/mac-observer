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
    private let isLayoutPreview: Bool
    private var previewEvents: [Event] = []
    private var previewHistory: [Metric] = []

    static func makeForLaunch() -> OverviewStore {
        if CommandLine.arguments.contains("--layout-preview") {
            return layoutPreview()
        }
        return OverviewStore()
    }

    static func layoutPreview(now: Date = Date()) -> OverviewStore {
        OverviewStore(layoutPreview: LayoutPreviewData.make(now: now))
    }

    init() {
        isLayoutPreview = false
        startedAt = Date()
        snapshot = LiveSnapshot(
            metrics: [],
            events: [],
            availability: [:],
            capturedAt: ObservationTime(wallTime: Date())
        )
    }

    private init(layoutPreview payload: LayoutPreviewPayload) {
        isLayoutPreview = true
        startedAt = payload.startedAt
        snapshot = payload.snapshot
        capabilities = payload.capabilities
        previewEvents = payload.events
        previewHistory = payload.historyMetrics
        historyEvents = payload.events
            .filter { $0.time.wallTime >= Date().addingTimeInterval(-HistoryWindow.lastHour.duration) }
            .sorted { $0.time.wallTime > $1.time.wallTime }
        historyPath = "Layout preview"
        historyMessage = "Canned telemetry. Collectors are not running."
        disabledCapabilityIDs = Set(payload.capabilities.compactMap { $0.defaultEnabled ? nil : $0.id })
    }

    func isCapabilityEnabled(_ id: String) -> Bool {
        if isLayoutPreview {
            return !disabledCapabilityIDs.contains(id)
        }
        if let capability = capabilities.first(where: { $0.id == id }) {
            return preferences.isEnabled(capability)
        }
        return !disabledCapabilityIDs.contains(id)
    }

    func capabilityState(_ id: String) -> String {
        if !isCapabilityEnabled(id) {
            return "Off"
        }
        if id == ExternalDiagnosticsCollector.capabilityID, snapshot.availability[id] == .available {
            return "Ready. Run a check from Network or this screen."
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

    func setCapabilityEnabled(_ id: String, enabled: Bool, deleteHistory: Bool = false) {
        guard let capability = capabilities.first(where: { $0.id == id }) else { return }
        if enabled {
            disabledCapabilityIDs.remove(id)
        } else {
            disabledCapabilityIDs.insert(id)
        }
        if isLayoutPreview { return }
        preferences.setEnabled(capability, enabled: enabled)
        Task {
            try? await pipeline?.setEnabled(id, enabled: enabled)
            if !enabled, deleteHistory {
                await persisting?.flush()
                try? await store?.deleteSource(id)
            }
            if let pipeline {
                let next = await pipeline.snapshot()
                applySnapshot(next)
                await refreshHistory()
                await refreshExplanation()
            }
        }
    }

    func runExternalDiagnostic() async {
        guard !isLayoutPreview else { return }
        guard isCapabilityEnabled(ExternalDiagnosticsCollector.capabilityID) else { return }
        await pipeline?.runExternalDiagnostic()
        if let pipeline {
            applySnapshot(await pipeline.snapshot())
            await refreshHistory()
        }
    }

    func deleteLocalHistory() async {
        guard !isLayoutPreview else {
            historyMessage = "Layout preview has no local history file."
            return
        }
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
        if isLayoutPreview {
            historyEvents = previewEvents
                .filter { $0.time.wallTime >= start && $0.time.wallTime <= end }
                .sorted { $0.time.wallTime > $1.time.wallTime }
            return
        }
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
        if isLayoutPreview {
            return previewEvents.filter {
                $0.domain == target.domain
                    && $0.time.wallTime >= range.start
                    && $0.time.wallTime <= range.end
            }.sorted { $0.time.wallTime > $1.time.wallTime }
        }
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
        guard !isLayoutPreview else { return }
        guard let pipeline else { return }
        let next = await pipeline.snapshot()
        applySnapshot(next)
        await refreshHistory()
        await refreshExplanation()
    }

    func refreshExplanation() async {
        guard !isLayoutPreview else { return }
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
        guard !isLayoutPreview else { return }
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
        let enabled = preferences.enabledIDs(from: capabilities)
        disabledCapabilityIDs = Set(capabilities.map(\.id)).subtracting(enabled)

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