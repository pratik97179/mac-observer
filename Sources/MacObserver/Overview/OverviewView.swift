import SwiftUI
import MacObserverDomain
import MacObserverCollectors

struct OverviewView: View {
    let store: OverviewStore
    var onPulseFocus: Bool = false
    var onSearch: () -> Void = {}
    var onOpenCapabilities: () -> Void = {}
    var onOpenProcess: (OverviewProcessRow) -> Void = { _ in }
    var onOpenProfile: (Profile) -> Void = { _ in }
    var onRefresh: () -> Void = {}

    var body: some View {
        GeometryReader { proxy in
            OverviewCockpit(
                store: store,
                availableSize: proxy.size,
                onOpenProcess: onOpenProcess,
                onOpenProfile: onOpenProfile,
                onSearch: onSearch,
                onRefresh: onRefresh
            )
        }
        .instrumentScreen()
        .task {
            await store.refreshExplanation()
        }
    }
}
