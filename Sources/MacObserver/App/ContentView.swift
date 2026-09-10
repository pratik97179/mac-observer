import SwiftUI

struct ContentView: View {
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
            OverviewView()
        default:
            PlaceholderView(profile: selectedProfile)
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 1_120, height: 740)
}
