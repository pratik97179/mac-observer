import SwiftUI
import AppKit

struct AppToolbar: View {
    var contextTitle: String = "Overview"
    let onSearch: () -> Void
    var onRefresh: () -> Void = {}
    @Environment(\.designMetrics) private var metrics

    var body: some View {
        HStack(spacing: Theme.Space.compact) {
            Text(contextTitle)
                .font(Theme.Typography.section)
                .foregroundStyle(AppTheme.text)
                .lineLimit(1)
                .layoutPriority(1)
            Spacer(minLength: Theme.Space.standard)
            Button(action: onSearch) {
                HStack(spacing: Theme.Space.compact) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                    if metrics.regime != .compact {
                        Text("Search…")
                            .font(Theme.Typography.secondary)
                        Spacer(minLength: 0)
                        Text("⌘K")
                            .font(Theme.Typography.micro)
                            .foregroundStyle(AppTheme.tertiary)
                    }
                }
                .foregroundStyle(AppTheme.secondary)
                .padding(.horizontal, Theme.Space.control)
                .frame(width: metrics.regime == .compact ? 34 : 220, height: 34)
                .glass(.recessed, radius: Theme.Radius.control)
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            }
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .keyboardShortcut("k", modifiers: .command)
            .focusEffectDisabled()
            .help("Search")
            .accessibilityLabel("Open command palette")

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.secondary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .glass(.recessed, radius: Theme.Radius.control)
            .help("Refresh")
        }
        .padding(.horizontal, metrics.horizontalInset)
        .padding(.top, metrics.topInset)
        .padding(.bottom, Theme.Space.standard)
        .background(.clear)
        .zIndex(1)
    }
}

struct CockpitCard<Content: View>: View {
    var radius: CGFloat = Theme.Radius.secondary
    var sizing: RegionSizing = .flexible
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Theme.Space.surface)
            .regionSizing(sizing)
            .glass(.elevated, radius: radius)
    }
}

struct WithinWindowMaterial: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .withinWindow
        view.state = .followsWindowActiveState
        view.isEmphasized = false
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.appearance = NSAppearance(named: .vibrantDark)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = .withinWindow
    }
}

struct WindowChromeClearer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        ChromeClearingView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class ChromeClearingView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        clearChrome()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        clearChrome()
    }

    override func layout() {
        super.layout()
        clearChrome()
    }

    private func clearChrome() {
        window?.isOpaque = false
        window?.backgroundColor = .clear
        var node: NSView? = self
        while let current = node {
            current.wantsLayer = true
            if let effect = current as? NSVisualEffectView, effect.blendingMode == .behindWindow {
                effect.blendingMode = .withinWindow
                effect.material = .underWindowBackground
            }
            if current.layer?.backgroundColor != nil {
                current.layer?.backgroundColor = NSColor.clear.cgColor
            }
            node = current.superview
        }
    }
}
