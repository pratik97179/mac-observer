import AppKit
import SwiftUI

@MainActor
enum Motion {
    static var micro: Animation { timed(Theme.Motion.micro, easeOut: true) }
    static var hover: Animation { timed(Theme.Motion.hover, easeOut: true) }
    static var press: Animation { timed(Theme.Motion.micro, easeOut: true) }
    static var tooltip: Animation { timed(Theme.Motion.tooltip, easeOut: true) }
    static var state: Animation { timed(Theme.Motion.state, easeOut: false) }
    static var crossfade: Animation { timed(Theme.Motion.crossfade, easeOut: false) }
    static var panel: Animation { timed(Theme.Motion.surface, easeOut: false) }
    static var readout: Animation { timed(Theme.Motion.micro, easeOut: true) }
    static var navigation: Animation { timed(Theme.Motion.navigation, easeOut: false) }

    static var detail: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: .opacity.combined(with: .offset(x: 8)),
            removal: .opacity.combined(with: .offset(x: -6))
        )
    }

    static var fadeUp: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 6))
    }

    static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private static func timed(_ seconds: Double, easeOut: Bool) -> Animation {
        if reduceMotion { return .linear(duration: 0.001) }
        return easeOut ? .easeOut(duration: seconds) : .easeInOut(duration: seconds)
    }
}

extension View {
    func readoutTransition(_: some Equatable) -> some View {
        self
    }
}
