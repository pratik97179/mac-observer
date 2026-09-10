import SwiftUI

@main
struct MacObserverApp: App {
    @State private var store = OverviewStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .frame(minWidth: 960, minHeight: 640)
                .task {
                    await store.run()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1_120, height: 740)
    }
}
