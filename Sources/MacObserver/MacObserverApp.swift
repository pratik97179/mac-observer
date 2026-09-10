import AppKit
import SwiftUI
import MacObserverDomain
import MacObserverCollectors

@main
struct MacObserverApp: App {
    @NSApplicationDelegateAdaptor(MacObserverAppDelegate.self) private var appDelegate
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

final class MacObserverAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
