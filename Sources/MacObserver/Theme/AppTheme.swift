import SwiftUI

enum Theme {
    enum Color {
        static let canvas = SwiftUI.Color(red: 8 / 255, green: 10 / 255, blue: 14 / 255)
        static let canvasRaised = SwiftUI.Color(red: 0.045, green: 0.050, blue: 0.068)
        static let canvasElevated = canvasRaised
        static let surfaceResting = SwiftUI.Color(red: 0.102, green: 0.112, blue: 0.145)
        static let surfaceElevated = SwiftUI.Color(red: 0.132, green: 0.144, blue: 0.184)
        static let surfaceFloating = SwiftUI.Color(red: 0.160, green: 0.172, blue: 0.216)
        static let surface = surfaceResting
        static let surfaceStrong = surfaceFloating
        static let text = SwiftUI.Color(red: 0.949, green: 0.953, blue: 0.969)
        static let secondary = SwiftUI.Color(red: 0.651, green: 0.659, blue: 0.690)
        static let tertiary = SwiftUI.Color(red: 0.439, green: 0.451, blue: 0.486)
        static let disabled = SwiftUI.Color(red: 0.306, green: 0.318, blue: 0.349)
        static let divider = SwiftUI.Color.white.opacity(0.07)
        static let hairline = SwiftUI.Color.white.opacity(0.06)
        static let track = SwiftUI.Color.white.opacity(0.08)
        static let accent = SwiftUI.Color(red: 0.545, green: 0.549, blue: 1.0)
        static let accentBright = SwiftUI.Color(red: 0.647, green: 0.651, blue: 1.0)
        static let accentMuted = SwiftUI.Color(red: 0.400, green: 0.404, blue: 0.722)
        static let success = SwiftUI.Color(red: 0.412, green: 0.773, blue: 0.549)
        static let warning = SwiftUI.Color(red: 0.886, green: 0.682, blue: 0.380)
        static let critical = SwiftUI.Color(red: 0.890, green: 0.427, blue: 0.451)
        static let unavailable = SwiftUI.Color(red: 0.404, green: 0.416, blue: 0.451)
        static let cpu = SwiftUI.Color(red: 0.47, green: 0.58, blue: 1.0)
        static let memory = SwiftUI.Color(red: 0.62, green: 0.48, blue: 0.98)
        static let gpu = SwiftUI.Color(red: 0.35, green: 0.82, blue: 0.52)
        static let disk = SwiftUI.Color(red: 0.96, green: 0.62, blue: 0.32)
        static let network = SwiftUI.Color(red: 0.32, green: 0.86, blue: 0.62)
        static let battery = SwiftUI.Color(red: 0.32, green: 0.84, blue: 0.55)
        static let storage = SwiftUI.Color(red: 0.42, green: 0.55, blue: 1.0)
    }

    enum Typography {
        static var display: Font { DesignMetricsStore.current.type.display }
        static var pageTitle: Font { DesignMetricsStore.current.type.pageTitle }
        static var heroTitle: Font { DesignMetricsStore.current.type.heroTitle }
        static var hero: Font { DesignMetricsStore.current.type.hero }
        static var largeMetric: Font { DesignMetricsStore.current.type.largeMetric }
        static var section: Font { DesignMetricsStore.current.type.section }
        static var body: Font { DesignMetricsStore.current.type.body }
        static var secondary: Font { DesignMetricsStore.current.type.secondary }
        static var metadata: Font { DesignMetricsStore.current.type.metadata }
        static var micro: Font { DesignMetricsStore.current.type.micro }
    }

    enum Space {
        private static var metrics: DesignMetrics { DesignMetricsStore.current }
        private static var spacing: SpacingScale { metrics.spacing }

        static var micro: CGFloat { spacing.xs * 0.8 }
        static var icon: CGFloat { spacing.xs }
        static var compact: CGFloat { spacing.sm }
        static var control: CGFloat { spacing.md }
        static var standard: CGFloat { spacing.md }
        static var component: CGFloat { spacing.lg }
        static var surface: CGFloat { spacing.lg }
        static var section: CGFloat { spacing.xl }
        static var large: CGFloat { spacing.xl }
        static var major: CGFloat { spacing.xxl }
        static var breath: CGFloat { spacing.xxxl }
        static var hero: CGFloat { spacing.xxxxl }
        static var contentX: CGFloat { metrics.horizontalInset }
        static var contentTop: CGFloat { metrics.topInset }
        static var contentBottom: CGFloat { metrics.bottomInset }
        static var scrollGutter: CGFloat { 0 }
        static var cardGap: CGFloat { spacing.lg }
        static let sidebarTop: CGFloat = 52
        static var sidebarWidth: CGFloat { metrics.sidebarWidth }
        static let itemHeight: CGFloat = 36
        static let search: CGFloat = 40
        static var pulseWidth: CGFloat { 240 * metrics.scale }
        static let pulseHeight: CGFloat = 36
        static var metricLabel: CGFloat { spacing.sm }
        static var metricViz: CGFloat { spacing.sm }
        static var metricMeta: CGFloat { spacing.sm }
        static var column: CGFloat { spacing.xl }
        static var xs: CGFloat { spacing.xs }
        static var sm: CGFloat { spacing.sm }
        static var md: CGFloat { spacing.md }
        static var lg: CGFloat { spacing.lg }
        static var xl: CGFloat { spacing.xl }
        static var screen: CGFloat { spacing.xl }
        static var clusterX: CGFloat { spacing.xl }
        static var clusterY: CGFloat { spacing.lg }
    }

    enum Radius {
        static let window: CGFloat = 22
        static let primary: CGFloat = 20
        static let secondary: CGFloat = 16
        static let control: CGFloat = 12
        static let compact: CGFloat = 9
        static let item: CGFloat = 10
        static let pill: CGFloat = 999
        static let palette: CGFloat = 18
    }

    enum Shadow {
        static func contactOpacity(_ level: SurfaceLevel) -> Double {
            switch level {
            case .recessed: 0
            case .resting: 0.42
            case .elevated: 0.55
            case .floating: 0.62
            }
        }

        static func ambientOpacity(_ level: SurfaceLevel) -> Double {
            switch level {
            case .recessed: 0
            case .resting: 0.28
            case .elevated: 0.38
            case .floating: 0.46
            }
        }

        static func contactRadius(_ level: SurfaceLevel) -> CGFloat {
            switch level {
            case .recessed: 0
            case .resting: 3
            case .elevated: 5
            case .floating: 7
            }
        }

        static func ambientRadius(_ level: SurfaceLevel) -> CGFloat {
            switch level {
            case .recessed: 0
            case .resting: 18
            case .elevated: 28
            case .floating: 40
            }
        }

        static func contactY(_ level: SurfaceLevel) -> CGFloat {
            switch level {
            case .recessed: 0
            case .resting: 2
            case .elevated: 3
            case .floating: 4
            }
        }

        static func ambientY(_ level: SurfaceLevel) -> CGFloat {
            switch level {
            case .recessed: 0
            case .resting: 8
            case .elevated: 12
            case .floating: 18
            }
        }

        static func highlight(_ level: SurfaceLevel) -> Double {
            switch level {
            case .recessed: 0.03
            case .resting: 0.06
            case .elevated: 0.09
            case .floating: 0.11
            }
        }

        static func opacity(_ level: SurfaceLevel) -> Double { ambientOpacity(level) }
        static func radius(_ level: SurfaceLevel) -> CGFloat { ambientRadius(level) }
        static func y(_ level: SurfaceLevel) -> CGFloat { ambientY(level) }
    }

    enum Motion {
        static let micro = 0.10
        static let hover = 0.16
        static let tooltip = 0.18
        static let state = 0.20
        static let crossfade = 0.22
        static let surface = 0.24
        static let navigation = 0.28
    }

    enum Sidebar {
        static var materialTint: SwiftUI.Color { SwiftUI.Color.white.opacity(0.07) }
        static let materialOpacity = 0.18
        static let edgeOpacity = 0.08
        static let islandShadow = 0.16
        static let islandShadowRadius: CGFloat = 28
        static let islandShadowY: CGFloat = 8
        static let selectedFill = 0.06
        static let hoverFill = 0.035
        static let focusOutline = 0.22
        static var itemSpacing: CGFloat { Theme.Space.control }
        static let iconSize: CGFloat = 18
        static let iconSlot: CGFloat = 18
    }

    enum Chart {
        static let stroke: CGFloat = 1.6
        static let sparkHeight: CGFloat = 36
        static let fillTop = Theme.Color.accent.opacity(0.14)
        static let fillMid = Theme.Color.accent.opacity(0.06)
        static let fillBottom = Theme.Color.accent.opacity(0.01)
    }
}

enum AppTheme {
    typealias Color = Theme.Color
    typealias Typography = Theme.Typography
    typealias Radius = Theme.Radius
    typealias Space = Theme.Space
}

enum SurfaceLevel {
    case recessed
    case resting
    case elevated
    case floating
}

struct GlassSurface<Content: View>: View {
    var level: SurfaceLevel = .resting
    var cornerRadius: CGFloat = Theme.Radius.primary
    var pressed: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background { fill }
            .overlay { sheen }
            .overlay { edge }
            .clipShape(shape)
            .modifier(SurfaceDepth(level: level, pressed: pressed))
            .offset(y: pressed ? 1 : 0)
            .brightness(pressed ? -0.04 : 0)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    @ViewBuilder
    private var fill: some View {
        switch level {
        case .recessed:
            shape.fill(Theme.Color.canvasRaised)
        case .resting:
            shape.fill(Theme.Color.surfaceResting)
        case .elevated:
            shape.fill(Theme.Color.surfaceElevated)
        case .floating:
            shape.fill(Theme.Color.surfaceFloating)
        }
    }

    private var sheen: some View {
        shape.fill(
            LinearGradient(
                colors: [
                    Color.white.opacity(pressed ? Theme.Shadow.highlight(level) * 0.35 : Theme.Shadow.highlight(level)),
                    Color.white.opacity(0)
                ],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.42)
            )
        )
        .allowsHitTesting(false)
    }

    private var edge: some View {
        shape.strokeBorder(
            LinearGradient(
                colors: [
                    Color.white.opacity(pressed ? 0.04 : Theme.Shadow.highlight(level) + 0.02),
                    Color.white.opacity(0.03),
                    Color.black.opacity(level == .recessed ? 0.38 : 0.22)
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            lineWidth: 1
        )
    }
}

private struct SurfaceDepth: ViewModifier {
    var level: SurfaceLevel
    var pressed: Bool

    func body(content: Content) -> some View {
        let contact = pressed ? 0.45 : 1
        let ambient = pressed ? 0.4 : 1
        content
            .shadow(
                color: Color.white.opacity(level == .recessed ? 0 : 0.05),
                radius: 0.6,
                x: 0,
                y: -0.6
            )
            .shadow(
                color: Color.black.opacity(Theme.Shadow.contactOpacity(level) * contact),
                radius: pressed ? Theme.Shadow.contactRadius(level) * 0.5 : Theme.Shadow.contactRadius(level),
                x: 0,
                y: pressed ? max(Theme.Shadow.contactY(level) - 1, 0.5) : Theme.Shadow.contactY(level)
            )
            .shadow(
                color: Color.black.opacity(Theme.Shadow.ambientOpacity(level) * ambient),
                radius: pressed ? Theme.Shadow.ambientRadius(level) * 0.55 : Theme.Shadow.ambientRadius(level),
                x: 0,
                y: pressed ? max(Theme.Shadow.ambientY(level) - 4, 2) : Theme.Shadow.ambientY(level)
            )
    }
}

struct InsetSurface<Content: View>: View {
    var radius: CGFloat = Theme.Radius.secondary
    @ViewBuilder var content: Content
    var body: some View { GlassSurface(level: .recessed, cornerRadius: radius) { content } }
}

struct FloatingSurface<Content: View>: View {
    var radius: CGFloat = Theme.Radius.palette
    @ViewBuilder var content: Content
    var body: some View { GlassSurface(level: .floating, cornerRadius: radius) { content } }
}

extension View {
    func glass(_ level: SurfaceLevel, radius: CGFloat = Theme.Radius.primary, pressed: Bool = false) -> some View {
        GlassSurface(level: level, cornerRadius: radius, pressed: pressed) { self }
    }

    func instrumentCanvas() -> some View {
        foregroundStyle(Theme.Color.text)
    }

    func instrumentScreen() -> some View {
        scrollClipDisabled()
            .scrollContentBackground(.hidden)
            .background(.clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    func instrumentContent() -> some View {
        modifier(InstrumentContentModifier())
    }

    func cardCell() -> some View {
        frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct InstrumentContentModifier: ViewModifier {
    @Environment(\.designMetrics) private var metrics

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, metrics.horizontalInset)
            .padding(.top, metrics.spacing.md)
            .padding(.bottom, metrics.bottomInset)
            .frame(maxWidth: metrics.contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
