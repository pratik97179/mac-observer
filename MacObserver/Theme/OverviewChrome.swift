import SwiftUI

struct ScreenPage<Content: View>: View {
    @Environment(\.designMetrics) private var metrics
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, metrics.horizontalInset)
                .padding(.top, metrics.spacing.md)
                .padding(.bottom, metrics.bottomInset)
                .frame(maxWidth: metrics.contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollContentBackground(.hidden)
        .background(.clear)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct SectionEyebrow: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(Theme.Typography.micro)
            .foregroundStyle(Theme.Color.tertiary)
            .tracking(1.6)
    }
}

struct FlatSection<Content: View>: View {
    var showsDivider: Bool = true
    @Environment(\.designMetrics) private var metrics
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.spacing.md) {
            content
            if showsDivider {
                Rectangle()
                    .fill(Theme.Color.divider)
                    .frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
