import SwiftUI

struct OverviewView: View {
    let store: OverviewStore
    var onOpenProfile: (Profile) -> Void = { _ in }

    var body: some View {
        OverviewMain(store: store, onOpenProfile: onOpenProfile)
            .task {
                await store.refreshExplanation()
            }
    }
}
