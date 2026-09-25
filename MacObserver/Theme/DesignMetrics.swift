import Foundation
import SwiftUI

struct SpacingScale: Equatable, Sendable {
    let xs: CGFloat
    let sm: CGFloat
    let md: CGFloat
    let lg: CGFloat
    let xl: CGFloat
    let xxl: CGFloat
    let xxxl: CGFloat
    let xxxxl: CGFloat

    init(unit: CGFloat) {
        xs = unit * 0.75
        sm = unit * 1.25
        md = unit * 2
        lg = unit * 3
        xl = unit * 4
        xxl = unit * 6
        xxxl = unit * 8
        xxxxl = unit * 10
    }
}

struct RadiusScale: Equatable, Sendable {
    let compact: CGFloat
    let item: CGFloat
    let control: CGFloat
    let secondary: CGFloat
    let primary: CGFloat
    let palette: CGFloat
    let window: CGFloat
    let pill: CGFloat

    static let standard = RadiusScale(
        compact: 9,
        item: 10,
        control: 12,
        secondary: 16,
        primary: 20,
        palette: 18,
        window: 22,
        pill: 999
    )
}

struct TypeScale: Sendable {
    let display: Font
    let pageTitle: Font
    let heroTitle: Font
    let hero: Font
    let largeMetric: Font
    let section: Font
    let body: Font
    let secondary: Font
    let metadata: Font
    let micro: Font

    init(scale: CGFloat) {
        display = .system(size: 32 * scale, weight: .semibold)
        pageTitle = .system(size: 26, weight: .semibold)
        heroTitle = display
        hero = .system(size: 42 * scale, weight: .semibold).monospacedDigit()
        largeMetric = .system(size: 28 * scale, weight: .medium).monospacedDigit()
        section = .system(size: 15, weight: .semibold)
        body = .system(size: 14)
        secondary = .system(size: 13)
        metadata = .system(size: 11, weight: .medium)
        micro = .system(size: 10, weight: .medium)
    }
}

struct DesignMetrics: Equatable, Sendable {
    let containerWidth: CGFloat
    let containerHeight: CGFloat
    let unit: CGFloat
    let scale: CGFloat
    let spacing: SpacingScale
    let radius: RadiusScale
    let type: TypeScale
    let horizontalInset: CGFloat
    let topInset: CGFloat
    let bottomInset: CGFloat
    let contentMaxWidth: CGFloat
    let canvasWidth: CGFloat
    let regime: CockpitRegime

    static let contentMaxWidthLimit: CGFloat = 1_520
    static let reference = DesignMetrics(containerWidth: 1_280, containerHeight: 820)

    static func == (lhs: DesignMetrics, rhs: DesignMetrics) -> Bool {
        lhs.containerWidth == rhs.containerWidth && lhs.containerHeight == rhs.containerHeight
    }

    init(containerWidth: CGFloat, containerHeight: CGFloat) {
        let width = max(containerWidth, 1)
        let height = max(containerHeight, 1)
        self.containerWidth = width
        self.containerHeight = height
        let shortAxis = min(width, height)
        unit = min(max(shortAxis * 0.008, 5), 8)
        scale = min(max(width / 1_280, 0.88), 1.12)
        spacing = SpacingScale(unit: unit)
        radius = .standard
        type = TypeScale(scale: scale)
        horizontalInset = min(max(width * 0.032, 24), 48)
        topInset = min(max(height * 0.032, 20), 32)
        bottomInset = min(max(height * 0.040, 24), 40)
        contentMaxWidth = Self.contentMaxWidthLimit
        canvasWidth = min(max(width - (horizontalInset * 2), 1), contentMaxWidth)
        if canvasWidth >= 1_100 {
            regime = .wide
        } else if canvasWidth >= 820 {
            regime = .standard
        } else {
            regime = .compact
        }
    }
}

enum CockpitRegime: Equatable, Sendable {
    case wide
    case standard
    case compact
}

enum DesignMetricsStore {
    // Retained only for layout-preview tooling compatibility. Prefer `@Environment(\.designMetrics)`.
    private static let lock = NSLock()
    nonisolated(unsafe) private static var value = DesignMetrics.reference

    static var current: DesignMetrics {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            value = newValue
            lock.unlock()
        }
    }
}

private struct DesignMetricsKey: EnvironmentKey {
    static let defaultValue = DesignMetrics.reference
}

extension EnvironmentValues {
    var designMetrics: DesignMetrics {
        get { self[DesignMetricsKey.self] }
        set { self[DesignMetricsKey.self] = newValue }
    }
}

struct DesignMetricsReader<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var size: CGSize = CGSize(
        width: DesignMetrics.reference.containerWidth,
        height: DesignMetrics.reference.containerHeight
    )

    var body: some View {
        let metrics = DesignMetrics(containerWidth: size.width, containerHeight: size.height)
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.designMetrics, metrics)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newSize in
                guard abs(newSize.width - size.width) > 0.5 || abs(newSize.height - size.height) > 0.5 else {
                    return
                }
                size = newSize
            }
    }
}
