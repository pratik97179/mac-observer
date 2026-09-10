import SwiftUI

struct MetricTile: View {
    let reading: OverviewReading

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label(reading.name, systemImage: reading.symbol)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(reading.value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(reading.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .background(reading.tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
    }
}
