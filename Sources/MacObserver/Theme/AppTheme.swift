import SwiftUI

enum Theme {
    enum Color {
        static let canvas = SwiftUI.Color(red: 0.028, green: 0.031, blue: 0.045)
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
        static let display = Font.system(size: 32, weight: .semibold)
        static let pageTitle = Font.system(size: 26, weight: .semibold)
        static let hero = Font.system(size: 42, weight: .semibold).monospacedDigit()
        static let largeMetric = Font.system(size: 28, weight: .medium).monospacedDigit()
        static let section = Font.system(size: 15, weight: .semibold)
        static let body = Font.system(size: 14)
        static let secondary = Font.system(size: 13)
        static let metadata = Font.system(size: 11, weight: .medium)
        static let micro = Font.system(size: 10, weight: .medium)
    }

    enum Space {
        static let micro: CGFloat = 4
        static let icon: CGFloat = 6
        static let compact: CGFloat = 8
        static let control: CGFloat = 12
        static let standard: CGFloat = 16
        static let component: CGFloat = 20
        static let surface: CGFloat = 24
        static let section: CGFloat = 28
        static let large: CGFloat = 32
        static let major: CGFloat = 40
        static let breath: CGFloat = 48
        static let hero: CGFloat = 64
        static let contentX: CGFloat = 52
        static let contentTop: CGFloat = 28
        static let contentBottom: CGFloat = 56
        static let scrollGutter: CGFloat = 18
        static let cardGap: CGFloat = 24
        static let sidebarTop: CGFloat = 52
        static let sidebarWidth: CGFloat = 240
        static let itemHeight: CGFloat = 36
        static let search: CGFloat = 40
        static let pulseWidth: CGFloat = 240
        static let pulseHeight: CGFloat = 36
        static let metricLabel: CGFloat = 8
        static let metricViz: CGFloat = 10
        static let metricMeta: CGFloat = 8
        static let column: CGFloat = 28
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let screen: CGFloat = 28
        static let clusterX: CGFloat = 28
        static let clusterY: CGFloat = 24
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
            .background {
                ZStack {
                    Theme.Color.canvas
                    RadialGradient(
                        colors: [Theme.Color.accent.opacity(0.05), .clear],
                        center: .topLeading,
                        startRadius: 20,
                        endRadius: 720
                    )
                }
                .ignoresSafeArea()
            }
    }

    func instrumentScreen() -> some View {
        scrollClipDisabled()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay(alignment: .top) {
                LinearGradient(
                    stops: [
                        .init(color: Theme.Color.canvas, location: 0),
                        .init(color: Theme.Color.canvas.opacity(0.72), location: 0.28),
                        .init(color: Theme.Color.canvas.opacity(0), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 28)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: Theme.Color.canvas.opacity(0), location: 0),
                        .init(color: Theme.Color.canvas.opacity(0.72), location: 0.55),
                        .init(color: Theme.Color.canvas, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 56)
                .allowsHitTesting(false)
            }
    }

    func instrumentContent() -> some View {
        padding(.leading, Theme.Space.contentX)
            .padding(.trailing, Theme.Space.contentX + Theme.Space.scrollGutter)
            .padding(.top, Theme.Space.contentTop)
            .padding(.bottom, Theme.Space.contentBottom)
    }

    func cardCell() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
