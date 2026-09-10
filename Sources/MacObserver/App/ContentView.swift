import SwiftUI

struct ContentView: View {
    @Bindable var store: OverviewStore
    @State private var selectedProfile: Profile = .overview

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $selectedProfile)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .tint(.indigo)
    }

    @ViewBuilder
    private var detail: some View {
        switch selectedProfile {
        case .overview:
            OverviewView(store: store)
        default:
            PlaceholderView(profile: selectedProfile)
        }
    }
}
