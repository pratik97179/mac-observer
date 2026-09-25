import SwiftUI

struct ContentView: View {
    @Bindable var store: OverviewStore
    @State private var selectedProfile: Profile = .overview
    @State private var path = NavigationPath()
    @State private var showPalette = false
    @State private var selectedProcess: OverviewProcessRow?

    var body: some View {
        DesignMetricsReader {
            ZStack {
                Theme.Color.canvas
                    .ignoresSafeArea()
                AppBackground()

                VStack(spacing: 0) {
                    OverviewHeader(
                        selection: $selectedProfile,
                        onSearch: { showPalette = true }
                    )

                    ContentViewport {
                        NavigationStack(path: $path) {
                            detailRoot
                                .navigationDestination(for: MetricInspectTarget.self) { target in
                                    MetricInspectView(store: store, target: target)
                                }
                        }
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .toolbar(.hidden, for: .windowToolbar)
                        .toolbarBackground(.hidden, for: .windowToolbar)
                        .animation(nil, value: store.snapshot)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if selectedProfile == .overview {
                        OverviewFooter(onViewProcesses: { selectProfile(.processes) })
                    }
                }
                .ignoresSafeArea()

                if showPalette {
                    CommandPalette(
                        store: store,
                        selection: profileBinding,
                        path: $path,
                        selectedProcess: $selectedProcess,
                        isPresented: $showPalette
                    )
                }
            }
            .foregroundStyle(Theme.Color.text)
            .background(.clear)
            .containerBackground(.clear, for: .window)
            .ignoresSafeArea()
            .syncReduceMotion()
        }
        .animation(Motion.panel, value: showPalette)
        .onReceive(NotificationCenter.default.publisher(for: .macObserverOpenPalette)) { _ in
            showPalette = true
        }
        .onChange(of: selectedProfile) { _, _ in
            path = NavigationPath()
            selectedProcess = nil
            showPalette = false
        }
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

    private var profileBinding: Binding<Profile> {
        Binding(
            get: { selectedProfile },
            set: { selectProfile($0) }
        )
    }

    private func selectProfile(_ profile: Profile) {
        selectedProfile = profile
    }

    @ViewBuilder
    private var detailRoot: some View {
        Group {
            switch selectedProfile {
            case .overview:
                OverviewView(
                    store: store,
                    onOpenProfile: { selectProfile($0) }
                )
            case .performance, .network, .processes, .storage, .power:
                LiveProfileView(
                    store: store,
                    profile: selectedProfile,
                    onOpenProcess: { selectedProcess = $0 },
                    onOpenCapabilities: { selectProfile(.capabilities) }
                )
            case .capabilities:
                CapabilitiesView(store: store)
            case .events:
                EventsView(store: store)
            case .settings:
                SettingsView(store: store)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(Motion.detail)
    }
}

#Preview("Content") {
    ContentView(store: .layoutPreview())
        .frame(minWidth: 1_050, minHeight: 700)
}

#Preview("Overview") {
    DesignMetricsReader {
        OverviewView(store: .layoutPreview())
    }
    .frame(width: 1_280, height: 820)
}

#Preview("Design system") {
    DesignMetricsReader {
        DesignSystemPreview()
            .padding()
    }
    .frame(width: 900, height: 700)
}
