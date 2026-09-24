import SwiftUI

enum Theme {
    enum Color {
        static let canvas = SwiftUI.Color(red: 0.969, green: 0.961, blue: 0.941)
        static let canvasWarm = SwiftUI.Color(red: 0.982, green: 0.974, blue: 0.953)
        static let canvasRaised = canvasWarm

        static let text = SwiftUI.Color(red: 0.075, green: 0.165, blue: 0.160)
        static let secondary = SwiftUI.Color(red: 0.400, green: 0.435, blue: 0.450)
        static let tertiary = SwiftUI.Color(red: 0.535, green: 0.555, blue: 0.560)
        static let disabled = SwiftUI.Color(red: 0.680, green: 0.690, blue: 0.685)

        static let divider = SwiftUI.Color(red: 0.840, green: 0.842, blue: 0.815).opacity(0.72)
        static let hairline = SwiftUI.Color(red: 0.800, green: 0.805, blue: 0.780).opacity(0.62)
        static let track = SwiftUI.Color(red: 0.865, green: 0.862, blue: 0.835)

        static let sage = SwiftUI.Color(red: 0.435, green: 0.610, blue: 0.535)
        static let sageBright = SwiftUI.Color(red: 0.520, green: 0.720, blue: 0.615)
        static let sageMuted = SwiftUI.Color(red: 0.585, green: 0.700, blue: 0.650)
        static let sageSoft = SwiftUI.Color(red: 0.780, green: 0.835, blue: 0.805)
        static let peach = SwiftUI.Color(red: 0.825, green: 0.665, blue: 0.505)
        static let peachSoft = SwiftUI.Color(red: 0.930, green: 0.845, blue: 0.745)

        static let success = sage
        static let warning = peach
        static let critical = SwiftUI.Color(red: 0.720, green: 0.365, blue: 0.335)
        static let unavailable = tertiary

        static let cpu = sage
        static let memory = peach
        static let gpu = sageMuted
        static let disk = peach
        static let network = sage
        static let battery = sage
        static let storage = sageMuted

        static let landscapeLight = SwiftUI.Color(red: 0.875, green: 0.910, blue: 0.890)
        static let landscapeMid = SwiftUI.Color(red: 0.680, green: 0.775, blue: 0.735)
        static let landscapeDeep = SwiftUI.Color(red: 0.500, green: 0.650, blue: 0.600)
        static let sun = SwiftUI.Color(red: 0.930, green: 0.770, blue: 0.600)

        static let surfaceResting = SwiftUI.Color.white.opacity(0.38)
        static let surfaceElevated = SwiftUI.Color.white.opacity(0.56)
        static let surfaceFloating = SwiftUI.Color.white.opacity(0.74)
        static let surface = surfaceResting
        static let surfaceStrong = surfaceFloating
    }

    enum Typography {
        static let display = Font.system(size: 64, weight: .regular, design: .serif)
        static let pageTitle = Font.system(size: 28, weight: .regular, design: .serif)
        static let heroTitle = Font.system(size: 56, weight: .regular, design: .serif)
        static let hero = Font.system(size: 48, weight: .regular, design: .serif)
        static let largeMetric = Font.system(size: 25, weight: .medium)
        static let section = Font.system(size: 13, weight: .medium)
        static let body = Font.system(size: 15, weight: .regular)
        static let secondary = Font.system(size: 14, weight: .regular)
        static let metadata = Font.system(size: 12, weight: .regular)
        static let micro = Font.system(size: 10, weight: .medium)
    }

    enum Space {
        static let micro: CGFloat = 5
        static let icon: CGFloat = 8
        static let compact: CGFloat = 12
        static let control: CGFloat = 16
        static let standard: CGFloat = 20
        static let component: CGFloat = 28
        static let surface: CGFloat = 32
        static let section: CGFloat = 40
        static let large: CGFloat = 48
        static let major: CGFloat = 64
        static let breath: CGFloat = 80
        static let hero: CGFloat = 104
        static let contentX: CGFloat = 32
        static let contentTop: CGFloat = 20
        static let contentBottom: CGFloat = 24
        static let metricLabel: CGFloat = 7
        static let metricViz: CGFloat = 14
        static let metricMeta: CGFloat = 5
        static let sidebarTop: CGFloat = 52
        static let itemHeight: CGFloat = 36
        static let cardGap: CGFloat = 28
        static let pulseWidth: CGFloat = 240
        static let pulseHeight: CGFloat = 36
        static let xs = micro
        static let sm = compact
        static let md = standard
        static let lg = component
        static let xl = section
        static let screen = section
        static let clusterX = component
        static let clusterY = component
    }

    enum Radius {
        static let window: CGFloat = 12
        static let primary: CGFloat = 12
        static let secondary: CGFloat = 10
        static let control: CGFloat = 10
        static let compact: CGFloat = 7
        static let item: CGFloat = 8
        static let pill: CGFloat = 999
        static let palette: CGFloat = 14
    }

    enum Shadow {
        static func contactOpacity(_ level: SurfaceLevel) -> Double {
            switch level {
            case .recessed: 0
            case .resting: 0.08
            case .elevated: 0.12
            case .floating: 0.16
            }
        }

        static func ambientOpacity(_ level: SurfaceLevel) -> Double {
            switch level {
            case .recessed: 0
            case .resting: 0.06
            case .elevated: 0.10
            case .floating: 0.14
            }
        }

        static func contactRadius(_ level: SurfaceLevel) -> CGFloat {
            switch level {
            case .recessed: 0
            case .resting: 2
            case .elevated: 4
            case .floating: 6
            }
        }

        static func ambientRadius(_ level: SurfaceLevel) -> CGFloat {
            switch level {
            case .recessed: 0
            case .resting: 12
            case .elevated: 20
            case .floating: 32
            }
        }

        static func contactY(_ level: SurfaceLevel) -> CGFloat {
            switch level {
            case .recessed: 0
            case .resting: 1
            case .elevated: 2
            case .floating: 3
            }
        }

        static func ambientY(_ level: SurfaceLevel) -> CGFloat {
            switch level {
            case .recessed: 0
            case .resting: 6
            case .elevated: 10
            case .floating: 16
            }
        }

        static func highlight(_ level: SurfaceLevel) -> Double {
            switch level {
            case .recessed: 0.04
            case .resting: 0.10
            case .elevated: 0.16
            case .floating: 0.22
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
        static var materialTint: SwiftUI.Color { SwiftUI.Color.white.opacity(0.18) }
        static let materialOpacity = 0.22
        static let edgeOpacity = 0.22
        static let islandShadow = 0.10
        static let islandShadowRadius: CGFloat = 28
        static let islandShadowY: CGFloat = 8
        static let selectedFill = 0.18
        static let hoverFill = 0.10
        static let focusOutline = 0.28
        static var itemSpacing: CGFloat { Theme.Space.control }
        static let iconSize: CGFloat = 18
        static let iconSlot: CGFloat = 18
    }

    enum Chart {
        static let stroke: CGFloat = 1.6
        static let sparkHeight: CGFloat = 36
        static let fillTop = Theme.Color.sage.opacity(0.14)
        static let fillMid = Theme.Color.sage.opacity(0.06)
        static let fillBottom = Theme.Color.sage.opacity(0.01)
    }
}

enum AppTheme {
    typealias Color = Theme.Color
    typealias Typography = Theme.Typography
    typealias Radius = Theme.Radius
    typealias Space = Theme.Space

    static let canvas = Theme.Color.canvas
    static let canvasWarm = Theme.Color.canvasWarm
    static let canvasRaised = Theme.Color.canvasRaised
    static let text = Theme.Color.text
    static let secondary = Theme.Color.secondary
    static let tertiary = Theme.Color.tertiary
    static let disabled = Theme.Color.disabled
    static let divider = Theme.Color.divider
    static let hairline = Theme.Color.hairline
    static let track = Theme.Color.track
    static let sage = Theme.Color.sage
    static let sageBright = Theme.Color.sageBright
    static let sageMuted = Theme.Color.sageMuted
    static let sageSoft = Theme.Color.sageSoft
    static let peach = Theme.Color.peach
    static let peachSoft = Theme.Color.peachSoft
    static let success = Theme.Color.success
    static let warning = Theme.Color.warning
    static let critical = Theme.Color.critical
    static let unavailable = Theme.Color.unavailable
    static let cpu = Theme.Color.cpu
    static let memory = Theme.Color.memory
    static let gpu = Theme.Color.gpu
    static let disk = Theme.Color.disk
    static let network = Theme.Color.network
    static let battery = Theme.Color.battery
    static let storage = Theme.Color.storage
    static let landscapeLight = Theme.Color.landscapeLight
    static let landscapeMid = Theme.Color.landscapeMid
    static let landscapeDeep = Theme.Color.landscapeDeep
    static let sun = Theme.Color.sun
    static let surfaceResting = Theme.Color.surfaceResting
    static let surfaceElevated = Theme.Color.surfaceElevated
    static let surfaceFloating = Theme.Color.surfaceFloating
    static let surface = Theme.Color.surface
    static let surfaceStrong = Theme.Color.surfaceStrong
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
            .brightness(pressed ? -0.02 : 0)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    @ViewBuilder
    private var fill: some View {
        switch level {
        case .recessed:
            shape.fill(Theme.Color.canvasWarm.opacity(0.55))
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
                    Color.white.opacity(pressed ? 0.18 : Theme.Shadow.highlight(level) + 0.08),
                    Theme.Color.hairline,
                    Color.black.opacity(level == .recessed ? 0.08 : 0.04)
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
                color: Color.white.opacity(level == .recessed ? 0 : 0.35),
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
