import SwiftUI

struct MetricTile: View {
    let reading: OverviewReading
    var sparkline: [Double] = []

    var body: some View {
        MetricBlock(
            label: reading.name,
            value: reading.value.isEmpty ? " " : reading.value,
            loading: reading.kind == .pending
        ) {
            if reading.kind == .unavailable {
                MetricBar(ratio: 0, empty: true)
            } else {
                VStack(alignment: .leading, spacing: Theme.Space.micro) {
                    MetricBar(ratio: sparkline.last ?? 0, enabled: reading.kind == .live, empty: reading.kind != .live)
                    Sparkline(values: sparkline)
                }
            }
        } metadata: {
            Text(reading.detail)
        }
    }
}
