import SwiftUI

struct OverviewView: View {
    private let readings = SystemReading.samples
    private let processes = ProcessActivity.samples

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                metrics
                activity
            }
            .padding(32)
            .frame(maxWidth: 1_280, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Overview")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Search", systemImage: "magnifyingglass") {}
                    .keyboardShortcut("k", modifiers: .command)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 7) {
                Text("M4 Air")
                    .font(.system(size: 28, weight: .semibold))
                Text("A quiet look at your Mac, right now.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Label("Healthy", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("Sample data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var metrics: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 190), spacing: 12)],
            spacing: 12
        ) {
            ForEach(readings) { reading in
                MetricTile(reading: reading)
            }
        }
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Top Activity")
                    .font(.headline)
                Spacer()
                Text("Sample data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 12) {
                GridRow {
                    Text("Process")
                    Text("CPU")
                    Text("Memory")
                    Text("Network")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

                ForEach(processes) { process in
                    GridRow {
                        Label(process.name, systemImage: process.symbol)
                        Text(process.cpu)
                        Text(process.memory)
                        Text(process.network)
                    }
                    .font(.body.monospacedDigit())
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
