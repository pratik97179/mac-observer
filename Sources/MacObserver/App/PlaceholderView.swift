import SwiftUI

struct PlaceholderView: View {
    let profile: Profile

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Not live yet", systemImage: "circle.dotted")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text(profile.rawValue)
                .font(.system(size: 28, weight: .semibold))

            Text(profile.placeholderSummary)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 520, alignment: .leading)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(profile.rawValue)
    }
}
