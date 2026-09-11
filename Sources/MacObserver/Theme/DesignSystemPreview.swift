import SwiftUI

struct DesignSystemPreview: View {
    @Environment(\.designMetrics) private var metrics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: metrics.spacing.xxl) {
                header
                spacingTokens
                radiusTokens
                typeTokens
                surfaces
                statusTones
                backgroundSizes
                motion
            }
            .instrumentContent()
        }
        .instrumentScreen()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: metrics.spacing.sm) {
            Text("Design system")
                .font(metrics.type.pageTitle)
                .foregroundStyle(Theme.Color.text)
            Text(
                "Window \(Int(metrics.containerWidth)) × \(Int(metrics.containerHeight)) · sidebar \(Int(metrics.sidebarWidth)) · canvas \(Int(metrics.canvasWidth)) · \(regimeLabel)"
            )
            .font(metrics.type.secondary)
            .foregroundStyle(Theme.Color.secondary)
        }
    }

    private var spacingTokens: some View {
        tokenGroup("Spacing") {
            tokenRow("XS", metrics.spacing.xs)
            tokenRow("SM", metrics.spacing.sm)
            tokenRow("MD", metrics.spacing.md)
            tokenRow("LG", metrics.spacing.lg)
            tokenRow("XL", metrics.spacing.xl)
            tokenRow("2XL", metrics.spacing.xxl)
            tokenRow("3XL", metrics.spacing.xxxl)
            tokenRow("4XL", metrics.spacing.xxxxl)
            tokenRow("H inset", metrics.horizontalInset)
            tokenRow("Top inset", metrics.topInset)
            tokenRow("Bottom inset", metrics.bottomInset)
        }
    }

    private var radiusTokens: some View {
        tokenGroup("Radius") {
            HStack(spacing: metrics.spacing.md) {
                radiusSwatch("Compact", metrics.radius.compact)
                radiusSwatch("Control", metrics.radius.control)
                radiusSwatch("Secondary", metrics.radius.secondary)
                radiusSwatch("Primary", metrics.radius.primary)
            }
        }
    }

    private var typeTokens: some View {
        tokenGroup("Typography") {
            Text("Display").font(metrics.type.display).foregroundStyle(Theme.Color.text)
            Text("Page title").font(metrics.type.pageTitle).foregroundStyle(Theme.Color.text)
            Text("42.0").font(metrics.type.hero).foregroundStyle(Theme.Color.text)
            Text("Body / secondary / metadata")
                .font(metrics.type.body)
                .foregroundStyle(Theme.Color.secondary)
            Text("Tertiary metadata")
                .font(metrics.type.metadata)
                .foregroundStyle(Theme.Color.tertiary)
        }
    }

    private var surfaces: some View {
        tokenGroup("Surfaces") {
            HStack(spacing: metrics.spacing.md) {
                surfaceSwatch("Recessed", .recessed)
                surfaceSwatch("Resting", .resting)
                surfaceSwatch("Elevated", .elevated)
                surfaceSwatch("Floating", .floating)
            }
        }
    }

    private var statusTones: some View {
        tokenGroup("Status") {
            HStack(spacing: metrics.spacing.md) {
                StatusIndicator(title: "Healthy", tone: .healthy)
                StatusIndicator(title: "Attention", tone: .warning)
                StatusIndicator(title: "Investigate", tone: .critical)
            }
        }
    }

    private var backgroundSizes: some View {
        tokenGroup("Background sizes") {
            HStack(alignment: .bottom, spacing: metrics.spacing.md) {
                sizePreview(width: 1_050, height: 700)
                sizePreview(width: 1_280, height: 820)
                sizePreview(width: 1_440, height: 900)
                sizePreview(width: 1_728, height: 1_117)
            }
        }
    }

    private var motion: some View {
        tokenGroup("Reduced Motion") {
            Text(reduceMotion || Motion.reduceMotion ? "Reduce Motion is on." : "Reduce Motion is off.")
                .foregroundStyle(Theme.Color.secondary)
        }
    }

    private func tokenGroup(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: metrics.spacing.md) {
            Text(title)
                .font(metrics.type.section)
                .foregroundStyle(Theme.Color.tertiary)
            content()
        }
    }

    private func tokenRow(_ name: String, _ value: CGFloat) -> some View {
        HStack(spacing: metrics.spacing.md) {
            Text(name)
                .font(metrics.type.metadata)
                .foregroundStyle(Theme.Color.secondary)
                .frame(width: 88, alignment: .leading)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Theme.Color.accent.opacity(0.45))
                .frame(width: value, height: 8)
            Text("\(Int(value.rounded())) pt")
                .font(metrics.type.micro)
                .foregroundStyle(Theme.Color.tertiary)
        }
    }

    private func radiusSwatch(_ name: String, _ radius: CGFloat) -> some View {
        VStack(spacing: metrics.spacing.xs) {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Theme.Color.surfaceElevated)
                .frame(width: 64, height: 48)
            Text(name)
                .font(metrics.type.micro)
                .foregroundStyle(Theme.Color.tertiary)
        }
    }

    private func surfaceSwatch(_ name: String, _ level: SurfaceLevel) -> some View {
        Text(name)
            .font(metrics.type.metadata)
            .foregroundStyle(Theme.Color.text)
            .padding(metrics.spacing.md)
            .frame(width: 120, height: 72)
            .glass(level, radius: metrics.radius.secondary)
    }

    private func sizePreview(width: CGFloat, height: CGFloat) -> some View {
        let scale = 180 / width
        return VStack(spacing: metrics.spacing.xs) {
            ZStack {
                AppBackground()
                HStack(alignment: .top, spacing: 0) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.black.opacity(0.28))
                        .frame(width: Theme.Space.sidebarWidth * scale)
                        .padding(.leading, metrics.spacing.sm * scale)
                        .padding(.vertical, metrics.spacing.sm * scale)
                    Color.clear
                }
            }
            .frame(width: width * scale, height: height * scale)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Theme.Color.hairline, lineWidth: 1)
            }
            Text("\(Int(width)) × \(Int(height))")
                .font(metrics.type.micro)
                .foregroundStyle(Theme.Color.tertiary)
        }
    }

    private var regimeLabel: String {
        switch metrics.regime {
        case .wide: "Wide"
        case .standard: "Standard"
        case .compact: "Compact"
        }
    }
}
