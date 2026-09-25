import Foundation
import SwiftUI
import MacObserverDomain
import MacObserverCollectors
import MacObserverStorage

@MainActor
@Observable
final class OverviewStore {
    private var pipeline: CollectorPipeline?
    private var history = HistoryRepository()
    private var capabilitiesController = CapabilityController()
    private var refreshTask: Task<Void, Never>?
    private(set) var snapshot: LiveSnapshot
    private(set) var capabilities: [CapabilityDescriptor] = []
    private(set) var historyPath: String?
    private(set) var historyMessage: String?
    private(set) var runtimeError: String?
    private(set) var historyEvents: [Event] = []
    private(set) var eventWindow: HistoryWindow = .lastHour
    private(set) var explanation: Explanation?
    let startedAt: Date
    private var persistedExplanationIDs: Set<String> = []
    private let isLayoutPreview: Bool

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
        history.isLayoutPreview = true
        history.previewEvents = payload.events
        history.previewHistory = payload.historyMetrics
        capabilitiesController.applyPreviewDefaults(payload.capabilities)
        capabilities = capabilitiesController.capabilities
        historyEvents = payload.events
            .filter { $0.time.wallTime >= Date().addingTimeInterval(-HistoryWindow.lastHour.duration) }
            .sorted { $0.time.wallTime > $1.time.wallTime }
        historyPath = "Layout preview"
        historyMessage = "Canned telemetry. Collectors are not running."
    }

    func isCapabilityEnabled(_ id: String) -> Bool {
        capabilitiesController.isEnabled(id, isLayoutPreview: isLayoutPreview)
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
        guard capabilitiesController.setEnabled(id, enabled: enabled, isLayoutPreview: isLayoutPreview) != nil else {
            return
        }
        capabilities = capabilitiesController.capabilities
        if isLayoutPreview { return }
        scheduleRefresh {
            do {
                try await self.pipeline?.setEnabled(id, enabled: enabled)
                if !enabled, deleteHistory {
                    await self.history.persisting?.flush()
                    try await self.history.store?.deleteSource(id)
                }
                if let pipeline = self.pipeline {
                    self.applySnapshot(await pipeline.snapshot())
                    await self.refreshHistory()
                    await self.refreshExplanation()
                }
            } catch {
                self.runtimeError = "Could not update capability \(id)."
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
        guard history.store != nil else {
            historyMessage = "No local history file is open."
            return
        }
        await history.persisting?.flush()
        do {
            try await history.store?.deleteAll()
            historyMessage = "Local history deleted. Live sampling continues."
            explanation = nil
            persistedExplanationIDs = []
            runtimeError = nil
            await refreshHistory()
            await refreshExplanation()
        } catch {
            historyMessage = "Could not delete local history."
            runtimeError = historyMessage
        }
    }

    func setEventWindow(_ window: HistoryWindow) {
        eventWindow = window
        scheduleRefresh { await self.refreshHistory() }
    }

    func refreshHistory() async {
        do {
            historyEvents = try await history.events(window: eventWindow, live: snapshot.events)
            if historyMessage == "Could not read local event history." {
                historyMessage = nil
            }
        } catch {
            historyMessage = "Could not read local event history."
            runtimeError = historyMessage
            historyEvents = snapshot.events
                .filter {
                    let end = Date()
                    let start = end.addingTimeInterval(-eventWindow.duration)
                    return $0.time.wallTime >= start && $0.time.wallTime <= end
                }
                .reversed()
        }
    }

    func metricSeries(for target: MetricInspectTarget, window: HistoryWindow) async -> [Metric] {
        do {
            return try await history.metricSeries(for: target, window: window, live: snapshot.metrics)
        } catch {
            runtimeError = "Could not load metric history."
            return []
        }
    }

    func relatedEvents(for target: MetricInspectTarget, window: HistoryWindow) async -> [Event] {
        await relatedEvents(for: target, range: InvestigationInterval.range(for: window.duration))
    }

    func relatedEvents(for target: MetricInspectTarget, range: TimeRange) async -> [Event] {
        do {
            return try await history.relatedEvents(for: target, range: range, live: snapshot.events)
        } catch {
            runtimeError = "Could not load related events."
            return []
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
        let next = ExplanationService.select(events: events, metrics: metrics, now: now)
        explanation = next
        await persistExplanationIfNeeded(next, now: now)
    }

    func run() async {
        guard !isLayoutPreview else { return }

        if let opened = TelemetrySession.openStore() {
            do {
                try await opened.store.applyRetention(.documented, now: Date())
                history.persisting = opened.sink
                history.store = opened.store
                historyPath = opened.path
            } catch {
                runtimeError = "Could not prepare local history retention."
                history.persisting = opened.sink
                history.store = opened.store
                historyPath = opened.path
            }
        } else {
            historyMessage = "No local history file is open. Live readings are not being saved."
            runtimeError = historyMessage
        }

        let sinks: [any TelemetrySink] = history.persisting.map { [$0] } ?? []
        do {
            let collectors = StandardCollectors.make()
            let descriptors = collectors.map(\.capability)
            let enabled = CapabilityPreferences().enabledIDs(from: descriptors)
            let pipeline = CollectorPipeline(collectors: collectors, additionalSinks: sinks)
            try await pipeline.start(enabled: enabled)
            self.pipeline = pipeline
            capabilitiesController.bootstrap(from: descriptors)
            capabilities = capabilitiesController.capabilities
        } catch {
            runtimeError = "Could not start metric collectors."
            return
        }

        guard let pipeline else { return }
        var ticks = 0
        while !Task.isCancelled {
            let next = await pipeline.snapshot()
            applySnapshot(next)
            ticks += 1
            if ticks.isMultiple(of: 5) {
                await history.persisting?.flush()
                await refreshHistory()
                await refreshExplanation()
            }
            if ticks.isMultiple(of: 300) {
                do {
                    try await history.store?.applyRetention(.documented, now: Date())
                } catch {
                    runtimeError = "Could not apply history retention."
                }
            }
            try? await Task.sleep(for: .seconds(1))
        }

        await history.persisting?.flush()
        await pipeline.stop()
    }

    private func scheduleRefresh(_ work: @escaping @MainActor () async -> Void) {
        refreshTask?.cancel()
        refreshTask = Task { await work() }
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
        do {
            try await history.store?.insert(events: [explanation.asEvent(now: now, entity: entity)])
            await refreshHistory()
        } catch {
            runtimeError = "Could not persist explanation."
        }
    }

    private func events(in range: TimeRange) async -> [Event] {
        var rows: [Event] = []
        if let store = history.store {
            await history.persisting?.flush()
            do {
                rows = try await store.events(matching: EventQuery(range: range, limit: 200))
            } catch {
                runtimeError = "Could not read events for explanation."
            }
        }
        let live = snapshot.events.filter {
            $0.time.wallTime >= range.start && $0.time.wallTime <= range.end
        }
        var seen = Set(rows.map(\.id))
        return rows + live.filter { seen.insert($0.id).inserted }
    }

    private func metrics(in range: TimeRange) async -> [Metric] {
        var rows: [Metric] = []
        if let store = history.store {
            await history.persisting?.flush()
            do {
                rows = try await store.metrics(matching: MetricQuery(range: range))
            } catch {
                runtimeError = "Could not read metrics for explanation."
            }
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
