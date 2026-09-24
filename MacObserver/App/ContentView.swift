import SwiftUI

struct ContentView: View {
    @Bindable var store: OverviewStore
    @State private var  selectedProfile: Profile = .overview
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
                    OverviewHeader(selection: $selectedProfile)

                    ContentViewport {
                        Group {
                            if selectedProfile == .overview {
                                OverviewView(
                                    store: store,
                                    onOpenProfile: { selectedProfile = $0 }
                                )
                            } else {
                                NavigationStack(path: $path) {
                                    detail
                                        .navigationDestination(for: MetricInspectTarget.self) { target in
                                            MetricInspectView(store: store, target: target)
                                        }
                                }
                                .scrollContentBackground(.hidden)
                                .background(.clear)
                                .toolbar(.hidden, for: .windowToolbar)
                                .toolbarBackground(.hidden, for: .windowToolbar)
                            }
                        }
                        .animation(nil, value: store.snapshot)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if selectedProfile == .overview {
                        OverviewFooter(onViewProcesses: { selectedProfile = .processes })
                    }
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
            .foregroundStyle(AppTheme.text)
            .background(.clear)
            .containerBackground(.clear, for: .window)
            .ignoresSafeArea()
            .background {
                Button("Search") { showPalette = true }
                    .keyboardShortcut("k", modifiers: .command)
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .accessibilityHidden(true)
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
                EmptyView()
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(Motion.detail)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(store: .layoutPreview())
            .frame(minWidth: 1_050, minHeight: 700)
            .preferredColorScheme(.dark)
    }
}
