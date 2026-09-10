import SwiftUI

struct LiveProfileView: View {
    let store: OverviewStore
    let profile: Profile

    private var model: ProfileLiveModel {
        ProfilePresentation.model(for: profile, snapshot: store.snapshot)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    if !model.readings.isEmpty {
                        tiles
                    }
                    if let empty = model.emptyRows {
                        Text(empty)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
                    } else if !model.rows.isEmpty {
                        table
                    }
                }
                .padding(32)
                .frame(maxWidth: 1_280, alignment: .leading)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle(model.title)
            .navigationDestination(for: MetricInspectTarget.self) { target in
                MetricInspectView(store: store, target: target)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 7) {
                Text(model.title)
                    .font(.system(size: 28, weight: .semibold))
                Text(model.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                if let availability = model.availability {
                    Text(availability)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            Text(model.freshness)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var tiles: some View {
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

    private var table: some View {
        Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 12) {
            GridRow {
                ForEach(model.columns, id: \.self) { column in
                    Text(column)
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)

            ForEach(model.rows) { row in
                GridRow {
                    ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                        Text(cell)
                    }
                }
                .font(.body.monospacedDigit())
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }
}
