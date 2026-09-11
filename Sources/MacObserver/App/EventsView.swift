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
    @State private var entityKeyFilter: String?

    private var events: [Event] {
        store.historyEvents.filter { event in
            if let domainFilter, event.domain != domainFilter { return false }
            if let entityKeyFilter, event.entity.identityKey != entityKeyFilter { return false }
            return true
        }
    }

    private var items: [EventListItem] {
        Self.grouped(events)
    }

    private var domains: [TelemetryDomain] {
        Array(Set(store.historyEvents.map(\.domain))).sorted { $0.rawValue < $1.rawValue }
    }

    private var entityOptions: [(key: String, title: String)] {
        var seen = Set<String>()
        var options: [(key: String, title: String)] = []
        for event in store.historyEvents {
            let key = event.entity.identityKey
            guard seen.insert(key).inserted else { continue }
            options.append((key, event.entity.displayTitle))
        }
        return options.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.section) {
                VStack(alignment: .leading, spacing: Theme.Space.compact) {
                    Text("Events")
                        .font(Theme.Typography.pageTitle)
                    Text("History comes from the local SQLite store. Discrete changes only: memory pressure, thermal state, collector enablement, generated explanations, internet checks you run, and local path changes.")
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
                    Picker("Entity", selection: $entityKeyFilter) {
                        Text("All entities").tag(Optional<String>.none)
                        ForEach(entityOptions, id: \.key) { option in
                            Text(option.title).tag(Optional(option.key))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.Color.accent)
                    .help("Filter by the entity that owns the event. Identity is the stored key, not the display name.")
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
            .animation(Motion.panel, value: entityKeyFilter)
            .instrumentContent()
        }
        .instrumentScreen()
        .onChange(of: store.historyEvents) { _, _ in
            if let entityKeyFilter, !entityOptions.contains(where: { $0.key == entityKeyFilter }) {
                self.entityKeyFilter = nil
            }
        }
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
        if entityKeyFilter != nil && domainFilter != nil {
            return "No events for this entity in this domain for the selected range."
        }
        if entityKeyFilter != nil {
            return "No events for this entity in the selected range."
        }
        if domainFilter != nil {
            return "No events in this domain for the selected range."
        }
        return "No stored events in this range. Disable a collector in Capabilities, wait for a memory or thermal change, or run an internet check after enabling it."
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
