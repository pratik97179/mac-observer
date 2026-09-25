import SwiftUI

struct StatusIndicator: View {
    enum Tone {
        case healthy, warning, critical, muted, unavailable
    }

    let title: String
    var tone: Tone = .healthy

    var body: some View {
        TimelineView(.animation(minimumInterval: tone == .critical && !Motion.reduceMotion ? 0.25 : 10, paused: tone != .critical || Motion.reduceMotion)) { context in
            let phase = sin(context.date.timeIntervalSinceReferenceDate / 1.4 * .pi * 2)
            let glow = tone == .critical && !Motion.reduceMotion ? 0.18 + 0.12 * phase : glowBase
            HStack(spacing: Theme.Space.compact) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                    .shadow(color: color.opacity(glow), radius: 4)
                Text(title)
                    .font(Theme.Typography.secondary)
                    .foregroundStyle(Theme.Color.text)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    private var glowBase: Double {
        switch tone {
        case .healthy, .warning: 0.22
        case .critical: 0.28
        case .muted, .unavailable: 0
        }
    }

    private var color: Color {
        switch tone {
        case .healthy: Theme.Color.success
        case .warning: Theme.Color.warning
        case .critical: Theme.Color.critical
        case .muted: Theme.Color.tertiary
        case .unavailable: Theme.Color.unavailable
        }
    }
}

struct MetricBar: View {
    let ratio: Double
    var enabled: Bool = true
    var empty: Bool = false
    var tint: Color = Theme.Color.sage
    var height: CGFloat = 7

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Color.track)
                if empty {
                    Capsule()
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(Theme.Color.tertiary)
                        .frame(width: 18, height: 2)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                } else {
                    Capsule()
                        .fill(enabled ? tint : Theme.Color.unavailable)
                        .frame(width: geo.size.width * CGFloat(min(max(ratio, 0), 1)))
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

struct CapacityBar: View {
    let used: Double
    let total: Double
    var tint: Color = Theme.Color.sage
    var showsCaption: Bool = true

    private var ratio: Double {
        guard total > 0 else { return 0 }
        return min(1, used / total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.micro) {
            MetricBar(ratio: ratio, empty: total <= 0, tint: tint)
            if showsCaption, total > 0 {
                Text("\(Int((ratio * 100).rounded()))% of capacity")
                    .font(Theme.Typography.metadata)
                    .foregroundStyle(Theme.Color.tertiary)
            }
        }
    }
}

struct SegmentedBar: View {
    let segments: [(Double, Color)]

    var body: some View {
        GeometryReader { geo in
            let total = max(segments.map(\.0).reduce(0, +), 0.0001)
            HStack(spacing: 3) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, item in
                    Capsule()
                        .fill(item.1)
                        .frame(width: geo.size.width * CGFloat(item.0 / total))
                }
            }
        }
        .frame(height: 7)
    }
}

struct MetricBlock<Visualization: View, Metadata: View>: View {
    let label: String
    let value: String
    var loading: Bool = false
    @Environment(\.designMetrics) private var metrics
    @ViewBuilder var visualization: Visualization
    @ViewBuilder var metadata: Metadata

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.spacing.xs) {
            SectionEyebrow(title: label)
            if loading {
                Text(" ")
                    .font(Theme.Typography.secondary)
                    .foregroundStyle(Theme.Color.tertiary)
            } else {
                Text(value)
                    .font(Theme.Typography.secondary)
                    .foregroundStyle(Theme.Color.text)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .readoutTransition(value)
            }
            visualization
            metadata
                .font(Theme.Typography.micro)
                .foregroundStyle(Theme.Color.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }
}

struct FlowIndicator: View {
    let inbound: String
    let outbound: String
    var inboundRatio: Double = 0.25
    var outboundRatio: Double = 0.12

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.standard) {
            flowRow("arrow.down", inbound, inboundRatio)
            flowRow("arrow.up", outbound, outboundRatio)
        }
    }

    private func flowRow(_ symbol: String, _ value: String, _ ratio: Double) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.micro) {
            HStack(spacing: Theme.Space.compact) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Color.sage)
                Text(value)
                    .font(Theme.Typography.largeMetric)
                    .readoutTransition(value)
            }
            FlowTrack(ratio: ratio)
        }
    }
}

struct FlowTrack: View {
    let ratio: Double

    var body: some View {
        let idle = ratio < 0.02
        let period = cyclePeriod
        TimelineView(.animation(minimumInterval: Motion.reduceMotion || idle ? 10 : 0.25, paused: Motion.reduceMotion || idle)) { context in
            GeometryReader { geo in
                let width = geo.size.width
                let fill = width * CGFloat(min(max(ratio, idle ? 0 : 0.08), 1))
                let travel = max(width - 14, 1)
                let t: CGFloat = {
                    if Motion.reduceMotion || idle { return 0.28 }
                    let raw = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
                    return CGFloat(raw)
                }()
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Color.track)
                    Capsule()
                        .fill(Theme.Color.sage.opacity(0.35))
                        .frame(width: fill)
                    if !idle {
                        Capsule()
                            .fill(Theme.Color.sageBright)
                            .frame(width: 10, height: 7)
                            .offset(x: travel * t)
                    }
                }
            }
        }
        .frame(height: 7)
        .accessibilityHidden(true)
    }

    private var cyclePeriod: Double {
        if ratio < 0.2 { return 1.6 }
        if ratio < 0.55 { return 1.0 }
        return 0.55
    }
}

struct PressableSurface<Content: View>: View {
    var action: () -> Void = {}
    @ViewBuilder var content: Content
    @State private var hovering = false
    @State private var pressed = false

    var body: some View {
        content
            .scaleEffect(pressed ? 0.985 : 1)
            .brightness(pressed ? -0.03 : (hovering ? 0.02 : 0))
            .onHover { hovering = $0 }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        withAnimation(Motion.press) { pressed = true }
                    }
                    .onEnded { _ in
                        withAnimation(Motion.press) { pressed = false }
                        action()
                    }
            )
    }
}

struct Pulse: View {
    let values: [Double]

    var body: some View {
        Sparkline(values: values, height: Theme.Space.pulseHeight, showsTooltip: false)
            .frame(width: Theme.Space.pulseWidth, height: Theme.Space.pulseHeight)
            .accessibilityLabel("System pulse")
    }
}

struct LoadingState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.compact) {
            RoundedRectangle(cornerRadius: 4).fill(Theme.Color.track).frame(width: 40, height: 10)
            RoundedRectangle(cornerRadius: 6).fill(Theme.Color.track).frame(width: 96, height: 32)
            MetricBar(ratio: 0.35, empty: true)
        }
        .redacted(reason: .placeholder)
    }
}

struct StaleState: View {
    let age: Int

    var body: some View {
        Text("Updated \(age)s ago")
            .font(Theme.Typography.metadata)
            .foregroundStyle(Theme.Color.tertiary)
    }
}

struct UnavailableState: View {
    let title: String
    var action: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.compact) {
            Text(title)
                .font(Theme.Typography.secondary)
                .foregroundStyle(Theme.Color.secondary)
            if let action, let onAction {
                Button(action, action: onAction)
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.Color.sage)
                    .font(Theme.Typography.metadata)
            }
        }
    }
}

struct PermissionState: View {
    let message: String
    var onCapabilities: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.micro) {
            SectionEyebrow(title: "Permission required")
            Text(message)
                .font(Theme.Typography.secondary)
                .foregroundStyle(Theme.Color.secondary)
            Button("Open Capabilities", action: onCapabilities)
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Color.sage)
                .font(Theme.Typography.secondary)
        }
    }
}

struct FreshnessBadge: View {
    let age: TimeInterval?
    let sampling: Bool

    var body: some View {
        let seconds = age.map { max(0, Int($0)) } ?? 0
        let band = band(for: age)
        Text(label(seconds: seconds, band: band))
            .font(Theme.Typography.micro)
            .foregroundStyle(Theme.Color.tertiary)
            .tracking(1.2)
            .accessibilityLabel(label(seconds: seconds, band: band))
    }

    private enum Band {
        case sampling, live, muted, stale, expired
    }

    private func band(for age: TimeInterval?) -> Band {
        if sampling { return .sampling }
        guard let age, age.isFinite else { return .sampling }
        if age > 60 { return .expired }
        if age > 15 { return .stale }
        if age > 5 { return .muted }
        return .live
    }

    private func label(seconds: Int, band: Band) -> String {
        switch band {
        case .sampling: "Collecting"
        case .live, .muted: "Live · \(seconds)s ago"
        case .stale, .expired: "Stale · \(seconds)s ago"
        }
    }
}
