import AppKit
import SwiftUI
import MacObserverDomain

@main
struct MacObserverApp: App {
    @NSApplicationDelegateAdaptor(MacObserverAppDelegate.self) private var appDelegate
    @State private var store = OverviewStore.makeForLaunch()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .frame(minWidth: 1_050, minHeight: 700)
                .containerBackground(.clear, for: .window)
                .task {
                    await store.run()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1_280, height: 820)
        .commands {
            CommandMenu("Navigate") {
                Button("Search…") {
                    NotificationCenter.default.post(name: .macObserverOpenPalette, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let macObserverOpenPalette = Notification.Name("MacObserver.openPalette")
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
