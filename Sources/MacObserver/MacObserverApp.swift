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
                .frame(minWidth: 1_050, minHeight: 700)
                .preferredColorScheme(.dark)
                .task {
                    await store.run()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1_280, height: 820)
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
