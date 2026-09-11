import SwiftUI

struct ContentView: View {
    @Bindable var store: OverviewStore
    @State private var selectedProfile: Profile = .overview
    @State private var path = NavigationPath()
    @State private var showPalette = false
    @State private var pulseFocus = false
    @State private var selectedProcess: OverviewProcessRow?

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                AppSidebar(selection: $selectedProfile, monitoringSince: store.startedAt) { profile in
                    withAnimation(Motion.panel) {
                        selectedProfile = profile
                        path = NavigationPath()
                        selectedProcess = nil
                    }
                }
                VStack(spacing: 0) {
                    AppToolbar(
                        onSearch: { showPalette = true },
                        onRefresh: { Task { await store.refreshNow() } }
                    )
                    NavigationStack(path: $path) {
                        detail
                            .navigationDestination(for: MetricInspectTarget.self) { target in
                                MetricInspectView(store: store, target: target)
                            }
                    }
                    .background(Theme.Color.canvas)
                    .animation(nil, value: store.snapshot)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .preferredColorScheme(.dark)
            .instrumentCanvas()

            if showPalette {
                CommandPalette(
                    store: store,
                    selection: $selectedProfile,
                    path: $path,
                    isPresented: $showPalette
                )
            }
        }
        .animation(Motion.panel, value: showPalette)
        .sheet(item: $selectedProcess) { process in
            ProcessDetailView(
                store: store,
                process: process,
                onInspect: { target in
                    selectedProcess = nil
                    path.append(target)
                }
            )
            .frame(minWidth: 520, minHeight: 420)
        }
    }

    @ViewBuilder
    private var detail: some View {
        Group {
            switch selectedProfile {
            case .overview:
                OverviewView(
                    store: store,
                    onPulseFocus: pulseFocus,
                    onSearch: { showPalette = true },
                    onOpenCapabilities: { selectedProfile = .capabilities },
                    onOpenProcess: { selectedProcess = $0 },
                    onOpenPerformance: { selectedProfile = .performance },
                    onRefresh: { Task { await store.refreshNow() } }
                )
            case .performance, .network, .processes, .storage, .power:
                LiveProfileView(
                    store: store,
                    profile: selectedProfile,
                    onOpenProcess: { selectedProcess = $0 },
                    onOpenCapabilities: { selectedProfile = .capabilities }
                )
            case .capabilities:
                CapabilitiesView(store: store)
            case .events:
                EventsView(store: store)
            case .settings:
                SettingsView(store: store)
            }
        }
        .transition(Motion.detail)
    }
}
