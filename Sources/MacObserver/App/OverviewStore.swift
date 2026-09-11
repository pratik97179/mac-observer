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
    let startedAt: Date
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
            await refreshHistory()
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
        await queryWindow(window) { range, bucket in
            if let store {
                return (try? await store.metrics(matching: MetricQuery(
                    range: range,
                    entityKey: target.entityKey,
                    name: target.metricName,
                    bucketSeconds: bucket
                ))) ?? []
            }
            return snapshot.metrics.filter {
                $0.name == target.metricName
                    && (target.entityKey == nil || $0.entity.identityKey == target.entityKey)
                    && $0.time.wallTime >= range.start
                    && $0.time.wallTime <= range.end
            }
        }
    }

    func relatedEvents(for target: MetricInspectTarget, window: HistoryWindow) async -> [Event] {
        await queryWindow(window) { range, _ in
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
    }

    private func queryWindow<T>(
        _ window: HistoryWindow,
        load: (TimeRange, TimeInterval) async -> [T]
    ) async -> [T] {
        let end = Date()
        let start = end.addingTimeInterval(-window.duration)
        await persisting?.flush()
        return await load(
            TimeRange(start: start, end: end),
            max(window.duration / 240, 2)
        )
    }

    func refreshNow() async {
        guard let pipeline else { return }
        let next = await pipeline.snapshot()
        applySnapshot(next)
        await refreshHistory()
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
}