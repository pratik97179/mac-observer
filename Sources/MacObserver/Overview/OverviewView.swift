import SwiftUI

struct OverviewView: View {
    let store: OverviewStore

    private var model: OverviewModel {
        OverviewModel.from(snapshot: store.snapshot)
    }

    var body: some View {
        NavigationStack {
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
            .navigationDestination(for: MetricInspectTarget.self) { target in
                MetricInspectView(store: store, target: target)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 7) {
                Text(model.machineName)
                    .font(.system(size: 28, weight: .semibold))
                Text("A quiet look at your Mac, right now.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Label(model.health.state.rawValue, systemImage: healthSymbol)
                    .font(.headline)
                    .foregroundStyle(healthColor)
                Text(model.freshness)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var healthSymbol: String {
        switch model.health.state {
        case .healthy: "checkmark.circle.fill"
        case .attention: "exclamationmark.circle.fill"
        case .investigate: "exclamationmark.triangle.fill"
        }
    }

    private var healthColor: Color {
        switch model.health.state {
        case .healthy: .green
        case .attention: .orange
        case .investigate: .red
        }
    }

    private var metrics: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 190), spacing: 12)],
            spacing: 12
        ) {
            ForEach(model.readings) { reading in
                if let inspect = reading.inspect {
                    NavigationLink(value: inspect) {
                        MetricTile(reading: reading)
                    }
                    .buttonStyle(.plain)
                } else {
                    MetricTile(reading: reading)
                }
            }
        }
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Top Activity")
                    .font(.headline)
                Spacer()
                Text("CPU and memory · network is not per-process")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if model.processes.isEmpty {
                Text("Waiting for process samples.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
            } else {
                Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 12) {
                    GridRow {
                        Text("Process")
                        Text("CPU")
                        Text("Memory")
                        Text("Network")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                    ForEach(model.processes) { process in
                        GridRow {
                            Label(process.name, systemImage: "cpu")
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
}
