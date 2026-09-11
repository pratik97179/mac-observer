import SwiftUI
import MacObserverDomain

struct CommandPalette: View {
    let store: OverviewStore
    @Binding var selection: Profile
    @Binding var path: NavigationPath
    @Binding var selectedProcess: OverviewProcessRow?
    @Binding var isPresented: Bool
    @State private var query = ""
    @FocusState private var focused: Bool

    private var items: [PaletteItem] {
        PaletteCatalog.items(store: store, query: query)
    }

    var body: some View {
        ZStack {
            Theme.Color.canvas.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(alignment: .leading, spacing: 0) {
                TextField("Jump to a screen, process, metric, or setting", text: $query)
                    .textFieldStyle(.plain)
                    .font(Theme.Typography.body)
                    .padding(Theme.Space.standard)
                    .focused($focused)
                    .focusEffectDisabled()
                    .overlay {
                        if focused {
                            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                .strokeBorder(Theme.Color.accent.opacity(Theme.Sidebar.focusOutline), lineWidth: 1)
                        }
                    }

                Rectangle()
                    .fill(Theme.Color.divider)
                    .frame(height: 1)

                if items.isEmpty {
                    Text("No matches")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Color.secondary)
                        .padding(Theme.Space.standard)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(items) { item in
                                Button {
                                    run(item)
                                } label: {
                                    HStack(spacing: Theme.Space.control) {
                                        Image(systemName: item.symbol)
                                            .frame(width: 16)
                                            .foregroundStyle(Theme.Color.tertiary)
                                        Text(item.title)
                                            .foregroundStyle(Theme.Color.text)
                                        Spacer(minLength: Theme.Space.compact)
                                        Text(item.type)
                                            .foregroundStyle(Theme.Color.accentMuted)
                                        Text(item.secondary)
                                            .foregroundStyle(Theme.Color.tertiary)
                                            .lineLimit(1)
                                    }
                                    .font(Theme.Typography.body)
                                    .padding(.horizontal, Theme.Space.standard)
                                    .padding(.vertical, Theme.Space.control)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 320)
                }
            }
            .padding(Theme.Space.standard)
            .glass(.floating, radius: Theme.Radius.palette)
            .frame(width: 620)
            .padding(.top, Theme.Space.hero)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            focused = true
        }
        .onDisappear {
            focused = false
        }
        .onExitCommand {
            isPresented = false
        }
    }

    private func run(_ item: PaletteItem) {
        path = NavigationPath()
        switch item.kind {
        case .screen(let profile):
            selection = profile
        case .process(let process):
            selection = .processes
            selectedProcess = process
        case .metric(let target):
            selection = profile(for: target)
            path.append(target)
        case .settings:
            selection = .settings
        case .event:
            selection = .events
        }
        isPresented = false
    }

    private func profile(for target: MetricInspectTarget) -> Profile {
        switch target.domain {
        case .cpu, .memory, .thermal, .system: .performance
        case .network: .network
        case .storage: .storage
        case .power: .power
        case .process: .processes
        case .capability: .capabilities
        }
    }
}

struct PaletteItem: Identifiable {
    enum Kind {
        case screen(Profile)
        case process(OverviewProcessRow)
        case metric(MetricInspectTarget)
        case settings
        case event
    }

    let id: String
    let title: String
    let type: String
    let secondary: String
    let symbol: String
    let kind: Kind
}

@MainActor
enum PaletteCatalog {
    static func items(store: OverviewStore, query: String) -> [PaletteItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var items: [PaletteItem] = []

        for profile in Profile.views + Profile.system {
            items.append(PaletteItem(
                id: "screen-\(profile.rawValue)",
                title: profile.rawValue,
                type: "Screen",
                secondary: profile.placeholderSummary,
                symbol: profile.symbol,
                kind: .screen(profile)
            ))
        }

        let processes = OverviewModel.processRows(from: store.snapshot, limit: 12, pad: false)
        for process in processes where !process.name.isEmpty {
            items.append(PaletteItem(
                id: "process-\(process.id)",
                title: process.name,
                type: "Process",
                secondary: "CPU \(process.cpu)",
                symbol: "cpu",
                kind: .process(process)
            ))
        }

        let overview = OverviewModel.from(snapshot: store.snapshot)
        for reading in overview.readings {
            guard let inspect = reading.inspect else { continue }
            items.append(PaletteItem(
                id: "metric-\(inspect.id)",
                title: reading.name,
                type: "Metric",
                secondary: reading.value.isEmpty ? reading.detail : reading.value,
                symbol: reading.symbol,
                kind: .metric(inspect)
            ))
        }

        for event in store.historyEvents.prefix(8) {
            items.append(PaletteItem(
                id: "event-\(event.id.uuidString)",
                title: event.summary,
                type: "Event",
                secondary: event.domain.rawValue,
                symbol: "clock.arrow.circlepath",
                kind: .event
            ))
        }

        items.append(PaletteItem(
            id: "settings-history",
            title: "Delete local history",
            type: "Settings",
            secondary: "Remove stored metrics and events",
            symbol: "trash",
            kind: .settings
        ))
        items.append(PaletteItem(
            id: "settings-retention",
            title: "Retention",
            type: "Settings",
            secondary: "Local keep window",
            symbol: "clock",
            kind: .settings
        ))

        guard !needle.isEmpty else { return Array(items.prefix(18)) }
        return items.filter {
            $0.title.lowercased().contains(needle)
                || $0.type.lowercased().contains(needle)
                || $0.secondary.lowercased().contains(needle)
        }
    }
}
