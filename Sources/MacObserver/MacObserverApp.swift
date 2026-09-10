import SwiftUI
import MacObserverDomain
import MacObserverCollectors

@main
struct MacObserverApp: App {
    private let telemetry = CollectorPipeline(collectors: [])

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 960, minHeight: 640)
                .task {
                    _ = await telemetry.snapshot()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1_120, height: 740)
    }
}
