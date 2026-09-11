import SwiftUI

struct ContentView: View {
    @Bindable var store: OverviewStore
    @State private var selectedProfile: Profile = .overview
    @State private var path = NavigationPath()
    @State private var showPalette = false
    @State private var pulseFocus = false
    @State private var selectedProcess: OverviewProcessRow?

    var body: some View {
        DesignMetricsReader {
            ZStack {
                AppBackground()
                WindowChromeClearer()
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)

                HStack(spacing: 0) {
                    AppSidebar(
                        selection: $selectedProfile,
                        monitoringSince: store.startedAt,
                        monitorState: SidebarMonitorState.from(snapshot: store.snapshot)
                    ) { profile in
                        withAnimation(Motion.panel) {
                            selectedProfile = profile
                            path = NavigationPath()
                            selectedProcess = nil
                            showPalette = false
                        }
                    }

                    ContentViewport {
                        VStack(spacing: 0) {
                            if selectedProfile != .overview {
                                AppToolbar(
                                    contextTitle: selectedProfile.rawValue,
                                    onSearch: { showPalette = true },
                                    onRefresh: { Task { await store.refreshNow() } }
                                )
                            }
                            NavigationStack(path: $path) {
                                detail
                                    .navigationDestination(for: MetricInspectTarget.self) { target in
                                        MetricInspectView(store: store, target: target)
                                    }
                            }
                            .scrollContentBackground(.hidden)
                            .background(.clear)
                            .toolbarBackground(.hidden, for: .windowToolbar)
                            .animation(nil, value: store.snapshot)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .ignoresSafeArea()

                if showPalette {
                    CommandPalette(
                        store: store,
                        selection: $selectedProfile,
                        path: $path,
                        selectedProcess: $selectedProcess,
                        isPresented: $showPalette
                    )
                }
            }
            .preferredColorScheme(.dark)
            .foregroundStyle(Theme.Color.text)
            .background(.clear)
            .containerBackground(.clear, for: .window)
            .ignoresSafeArea()
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
                    onOpenProfile: { selectedProfile = $0 },
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
