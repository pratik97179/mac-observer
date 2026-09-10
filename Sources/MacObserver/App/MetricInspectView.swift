import SwiftUI
import Charts
import MacObserverDomain

struct MetricInspectTarget: Hashable, Identifiable {
    let title: String
    let metricName: MetricName
    let domain: TelemetryDomain
    let entityKey: String?

    var id: String { "\(metricName.rawValue)|\(entityKey ?? "*")" }

    static func from(title: String, metric: Metric?) -> MetricInspectTarget? {
        guard let metric else { return nil }
        return MetricInspectTarget(
            title: title,
            metricName: metric.name,
            domain: metric.domain,
            entityKey: metric.entity.identityKey
        )
    }
}

struct MetricInspectView: View {
    let store: OverviewStore
    let target: MetricInspectTarget
    @State private var window: HistoryWindow = .lastHour
    @State private var series: [Metric] = []
    @State private var events: [Event] = []

    private var current: Metric? { series.last }
    private var plot: [PlotPoint] {
        series.compactMap { metric in
            guard let value = numeric(metric) else { return nil }
            return PlotPoint(id: metric.id, time: metric.time.wallTime, value: value, unit: metric.unit)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                rangePicker
                if !plot.isEmpty {
                    chart
                } else if !series.isEmpty {
                    stateList
                } else {
                    empty
                }
                if !events.isEmpty {
                    related
                }
            }
            .padding(32)
            .frame(maxWidth: 1_080, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(target.title)
        .task(id: window) { await reload() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(target.title)
                .font(.system(size: 28, weight: .semibold))
            Text(current.map(MetricFormatter.displayString) ?? "No sample in this range")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(target.metricName.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Values are typed query results from local history. The chart keeps about 240 points.")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 720, alignment: .leading)
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: $window) {
            ForEach(HistoryWindow.allCases) { item in
                Text(item.rawValue).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 420)
    }

    private var chart: some View {
        Chart(plot) { point in
            LineMark(
                x: .value("Time", point.time),
                y: .value("Value", point.value)
            )
            .interpolationMethod(.linear)
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let number = value.as(Double.self), let unit = plot.last?.unit {
                        Text(MetricFormatter.displayString(value: number, unit: unit))
                    }
                }
            }
        }
        .chartYScale(domain: yDomain)
        .frame(height: 240)
        .padding(18)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var yDomain: ClosedRange<Double> {
        if plot.first?.unit == .ratio {
            return 0...1
        }
        let values = plot.map(\.value)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        if minValue == maxValue {
            return (minValue - 1)...(maxValue + 1)
        }
        return minValue...maxValue
    }

    private var stateList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("State over time")
                .font(.headline)
            ForEach(series.suffix(40).reversed()) { metric in
                HStack {
                    Text(metric.time.wallTime, format: timeFormat)
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: window.showsCalendarDate ? 148 : 88, alignment: .leading)
                    Text(MetricFormatter.displayString(for: metric))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var related: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Related events")
                .font(.headline)
            ForEach(events.reversed()) { event in
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.summary)
                    Text(event.time.wallTime, format: timeFormat)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var empty: some View {
        Text("No stored samples in this range yet. Metrics are written in batches, so the first minute after launch can be empty.")
            .font(.body)
            .foregroundStyle(.secondary)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var timeFormat: Date.FormatStyle {
        if window.showsCalendarDate {
            return .dateTime.month(.abbreviated).day().hour().minute().second()
        }
        return .dateTime.hour().minute().second()
    }

    private func reload() async {
        series = await store.metricSeries(for: target, window: window)
        events = await store.relatedEvents(for: target, window: window)
    }

    private func numeric(_ metric: Metric) -> Double? {
        switch metric.value {
        case .ratio(let value), .double(let value): value
        case .int(let value): Double(value)
        case .state: nil
        }
    }
}

private struct PlotPoint: Identifiable {
    let id: UUID
    let time: Date
    let value: Double
    let unit: MacObserverDomain.Unit
}
