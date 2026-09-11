import SwiftUI

enum RegionSizing {
    case intrinsic
    case flexible
    case expanded
    case fixed
}

struct WeightedHStack: Layout {
    var spacing: CGFloat = 16
    var weights: [CGFloat] = [1, 1]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let widths = distributedWidths(in: proposal.width ?? 0, count: subviews.count)
        var height: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.init(width: widths[index], height: proposal.height))
            height = max(height, size.height)
        }
        return CGSize(width: proposal.width ?? widths.reduce(0, +), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = distributedWidths(in: bounds.width, count: subviews.count)
        var x = bounds.minX
        for (index, subview) in subviews.enumerated() {
            let width = widths[index]
            let size = subview.sizeThatFits(.init(width: width, height: bounds.height))
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                proposal: .init(width: width, height: size.height)
            )
            x += width + spacing
        }
    }

    private func distributedWidths(in total: CGFloat, count: Int) -> [CGFloat] {
        guard count > 0 else { return [] }
        let gaps = spacing * CGFloat(max(count - 1, 0))
        let available = max(total - gaps, 0)
        let usedWeights = (0..<count).map { index in
            index < weights.count ? max(weights[index], 0.01) : 1
        }
        let sum = usedWeights.reduce(0, +)
        return usedWeights.map { available * ($0 / sum) }
    }
}

struct CockpitBand<Content: View>: View {
    @Environment(\.designMetrics) private var metrics
    var weights: [CGFloat] = [5, 3]
    @ViewBuilder var content: Content

    var body: some View {
        if metrics.regime == .compact {
            VStack(alignment: .leading, spacing: metrics.spacing.lg) {
                content
            }
        } else {
            WeightedHStack(spacing: metrics.spacing.lg, weights: weights) {
                content
            }
        }
    }
}

extension View {
    func regionSizing(_ sizing: RegionSizing) -> some View {
        modifier(RegionSizingModifier(sizing: sizing))
    }
}

private struct RegionSizingModifier: ViewModifier {
    var sizing: RegionSizing

    @ViewBuilder
    func body(content: Content) -> some View {
        switch sizing {
        case .intrinsic:
            content.fixedSize(horizontal: true, vertical: false)
        case .flexible, .expanded:
            content.frame(maxWidth: .infinity, alignment: .topLeading)
        case .fixed:
            content
        }
    }
}
