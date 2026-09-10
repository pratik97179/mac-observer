import SwiftUI
import MacObserverDomain

struct EventsView: View {
    let store: OverviewStore
    @State private var domainFilter: TelemetryDomain?

    private var events: [Event] {
        let all = store.snapshot.events.reversed()
        guard let domainFilter else { return Array(all) }
        return all.filter { $0.domain == domainFilter }
    }

    private var domains: [TelemetryDomain] {
        Array(Set(store.snapshot.events.map(\.domain))).sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                filter
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
            Text("Only discrete changes appear here: memory pressure, thermal state, and collector enablement. CPU and memory samples stay on the live profiles.")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 720, alignment: .leading)
        }
    }

    private var filter: some View {
        Picker("Domain", selection: $domainFilter) {
            Text("All domains").tag(Optional<TelemetryDomain>.none)
            ForEach(domains, id: \.self) { domain in
                Text(domain.rawValue).tag(Optional(domain))
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 520)
    }

    private var empty: some View {
        Text(domainFilter == nil
             ? "No events yet. Disable a collector in Capabilities, or wait for a memory or thermal change."
             : "No events in this domain.")
            .font(.body)
            .foregroundStyle(.secondary)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(events) { event in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(event.time.wallTime, format: .dateTime.hour().minute().second())
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 88, alignment: .leading)
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
}
