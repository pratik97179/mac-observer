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

struct EventsView: View {
    let store: OverviewStore
    @State private var domainFilter: TelemetryDomain?

    private var events: [Event] {
        guard let domainFilter else { return store.historyEvents }
        return store.historyEvents.filter { $0.domain == domainFilter }
    }

    private var domains: [TelemetryDomain] {
        Array(Set(store.historyEvents.map(\.domain))).sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                filters
                if events.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .padding(32)
            .frame(maxWidth: 1_080, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Events")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Events")
                .font(.system(size: 28, weight: .semibold))
            Text("History comes from the local SQLite store. Discrete changes only: memory pressure, thermal state, and collector enablement.")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 720, alignment: .leading)
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Range", selection: windowBinding) {
                ForEach(HistoryWindow.allCases) { window in
                    Text(window.rawValue).tag(window)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)

            Picker("Domain", selection: $domainFilter) {
                Text("All domains").tag(Optional<TelemetryDomain>.none)
                ForEach(domains, id: \.self) { domain in
                    Text(domain.rawValue).tag(Optional(domain))
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var windowBinding: Binding<HistoryWindow> {
        Binding(
            get: { store.eventWindow },
            set: { store.setEventWindow($0) }
        )
    }

    private var empty: some View {
        Text(emptyCopy)
            .font(.body)
            .foregroundStyle(.secondary)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var emptyCopy: String {
        if domainFilter != nil {
            return "No events in this domain for the selected range."
        }
        return "No stored events in this range. Disable a collector in Capabilities, or wait for a memory or thermal change."
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(events) { event in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(event.time.wallTime, format: timeFormat)
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: store.eventWindow.showsCalendarDate ? 148 : 88, alignment: .leading)
                        Text(event.summary)
                            .font(.body)
                        Spacer()
                    }
                    HStack(spacing: 10) {
                        Text(event.type.rawValue)
                        Text(event.domain.rawValue)
                        Text(event.source)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    if !event.metadata.isEmpty {
                        Text(event.metadata.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }.joined(separator: "  "))
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var timeFormat: Date.FormatStyle {
        if store.eventWindow.showsCalendarDate {
            return .dateTime.month(.abbreviated).day().hour().minute().second()
        }
        return .dateTime.hour().minute().second()
    }
}
