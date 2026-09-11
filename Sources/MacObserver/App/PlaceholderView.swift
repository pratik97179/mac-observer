import SwiftUI

struct PlaceholderView: View {
    let profile: Profile

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.compact) {
            Text(profile.rawValue)
                .font(Theme.Typography.pageTitle)
            Text(profile.placeholderSummary)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Color.secondary)
                .frame(maxWidth: 520, alignment: .leading)
        }
        .instrumentContent()
        .instrumentScreen()
    }
}
