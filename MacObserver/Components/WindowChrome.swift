import AppKit
import SwiftUI

enum ThemeWindowControl {
    static let close = Color(red: 1, green: 0.373, blue: 0.341)
    static let miniaturize = Color(red: 1, green: 0.741, blue: 0.180)
    static let zoom = Color(red: 0.157, green: 0.788, blue: 0.251)
    static let size: CGFloat = 12
    static let spacing: CGFloat = 8
}

struct WindowControls: View {
    @State private var hovering = false

    var body: some View {
        HStack(spacing: ThemeWindowControl.spacing) {
            WindowControlButton(
                fill: ThemeWindowControl.close,
                symbol: "xmark",
                hovering: hovering,
                help: "Close"
            ) {
                currentWindow()?.performClose(nil)
            }
            WindowControlButton(
                fill: ThemeWindowControl.miniaturize,
                symbol: "minus",
                hovering: hovering,
                help: "Minimize"
            ) {
                currentWindow()?.miniaturize(nil)
            }
            WindowControlButton(
                fill: ThemeWindowControl.zoom,
                symbol: "plus",
                hovering: hovering,
                help: "Zoom"
            ) {
                currentWindow()?.zoom(nil)
            }
        }
        .onHover { hovering = $0 }
        .background(NativeWindowButtonHider())
        .accessibilityElement(children: .contain)
        .fixedSize()
    }

    private func currentWindow() -> NSWindow? {
        NSApp.keyWindow ?? NSApp.windows.first { $0.isVisible }
    }
}

private struct WindowControlButton: View {
    let fill: Color
    let symbol: String
    let hovering: Bool
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(fill)
                Image(systemName: symbol)
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(.black.opacity(0.72))
                    .opacity(hovering ? 1 : 0)
            }
            .frame(width: ThemeWindowControl.size, height: ThemeWindowControl.size)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct NativeWindowButtonHider: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowButtonHidingView {
        WindowButtonHidingView()
    }

    func updateNSView(_ nsView: WindowButtonHidingView, context: Context) {
        nsView.hideButtons()
    }
}

private final class WindowButtonHidingView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        hideButtons()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        hideButtons()
    }

    func hideButtons() {
        window?.standardWindowButton(.closeButton)?.isHidden = true
        window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window?.standardWindowButton(.zoomButton)?.isHidden = true
    }
}
