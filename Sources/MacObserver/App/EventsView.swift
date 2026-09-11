import SwiftUI
import MacObserverDomain

enum HistoryWindow: String, CaseIterable, Identifiable {
    case lastHour = "1 hour"
    case lastDay = "24 hours"
    case lastWeek = "7 days"

    var id: Self { self }

    var duration: TimeInterval {
        switch self {
        case .lastHour: 60 * 60
        case .lastDay: 24 * 60 * 60
        case .lastWeek: 7 * 24 * 60 * 60
        }
    }

    var showsCalendarDate: Bool {
        self != .lastHour
    }
}

private enum EventListItem: Identifiable {
    case single(Event)
    case group([Event])

    var id: String {
        switch self {
        case .single(let event): event.id.uuidString
        case .group(let events): events.map(\.id.uuidString).joined(separator: ":")
        }
    }
}

struct EventsView: View {
    let store: OverviewStore
    @State private var domainFilter: TelemetryDomain?

    private var events: [Event] {
        guard let domainFilter else { return store.historyEvents }
        return store.historyEvents.filter { $0.domain == domainFilter }
    }

    private var items: [EventListItem] {
        Self.grouped(events)
    }

    private var domains: [TelemetryDomain] {
        Array(Set(store.historyEvents.map(\.domain))).sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.section) {
                VStack(alignment: .leading, spacing: Theme.Space.compact) {
                    Text("Events")
                        .font(Theme.Typography.pageTitle)
                    Text("History comes from the local SQLite store. Discrete changes only: memory pressure, thermal state, collector enablement, and generated explanations.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Color.secondary)
                        .frame(maxWidth: 720, alignment: .leading)
                }

                FilterBar {
                    TimeRangeSelector(window: windowBinding)
                    Picker("Domain", selection: $domainFilter) {
                        Text("All domains").tag(Optional<TelemetryDomain>.none)
                        ForEach(domains, id: \.self) { domain in
                            Text(domain.rawValue).tag(Optional(domain))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.Color.accent)
                }
                .padding(Theme.Space.standard)
                .glass(.recessed, radius: Theme.Radius.control)

                if items.isEmpty {
                    EmptyState(title: "No events", message: emptyCopy)
                        .padding(Theme.Space.standard)
                        .glass(.elevated, radius: Theme.Radius.secondary)
                        .transition(Motion.fadeUp)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(items) { item in
                            switch item {
                            case .single(let event):
                                EventRow(event: event, showsCalendarDate: store.eventWindow.showsCalendarDate)
                            case .group(let grouped):
                                EventGroup(events: grouped, showsCalendarDate: store.eventWindow.showsCalendarDate)
                            }
                        }
                    }
                    .padding(Theme.Space.standard)
                    .glass(.elevated, radius: Theme.Radius.secondary)
                    .transition(Motion.fadeUp)
                }
            }
            .frame(maxWidth: 1_080, alignment: .leading)
            .animation(Motion.panel, value: domainFilter)
            .instrumentContent()
        }
        .instrumentScreen()
        .task {
            await store.refreshHistory()
        }
    }

    private var windowBinding: Binding<HistoryWindow> {
        Binding(
            get: { store.eventWindow },
            set: { store.setEventWindow($0) }
        )
    }

    private var emptyCopy: String {
        if domainFilter != nil {
            return "No events in this domain for the selected range."
        }
        return "No stored events in this range. Disable a collector in Capabilities, or wait for a memory or thermal change."
    }

    fileprivate static func grouped(_ events: [Event]) -> [EventListItem] {
        let ordered = events.sorted { $0.time.wallTime > $1.time.wallTime }
        var items: [EventListItem] = []
        var index = 0
        while index < ordered.count {
            var bucket = [ordered[index]]
            var cursor = index + 1
            while cursor < ordered.count {
                let delta = abs(ordered[cursor].time.wallTime.timeIntervalSince(bucket[0].time.wallTime))
                if delta <= 3 {
                    bucket.append(ordered[cursor])
                    cursor += 1
                } else {
                    break
                }
            }
            if bucket.count >= 4 {
                items.append(.group(bucket))
            } else {
                items.append(contentsOf: bucket.map { .single($0) })
            }
            index = cursor
        }
        return items
    }
}
