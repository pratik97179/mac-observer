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
    private var plot: [InspectPlotPoint] {
        series.compactMap { metric in
            guard let value = numeric(metric) else { return nil }
            return InspectPlotPoint(time: metric.time.wallTime, value: value, unit: metric.unit)
        }
    }

    private var lastAge: TimeInterval? {
        current.map { Date().timeIntervalSince($0.time.wallTime) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.section) {
                VStack(alignment: .leading, spacing: Theme.Space.compact) {
                    Text(target.title)
                        .font(Theme.Typography.pageTitle)
                    Text(current.map(MetricFormatter.displayString) ?? " ")
                        .font(Theme.Typography.hero)
                        .readoutTransition(current.map(MetricFormatter.displayString) ?? "")
                    Text(target.metricName.rawValue)
                        .font(Theme.Typography.metadata)
                        .foregroundStyle(Theme.Color.secondary)
                    if let lastAge, lastAge > 15 {
                        StaleState(age: Int(lastAge))
                    }
                }

                TimeRangeSelector(window: $window)

                if !plot.isEmpty {
                    TelemetryChart(plot: plot)
                        .padding(Theme.Space.standard)
                        .glass(.recessed, radius: Theme.Radius.secondary)
                        .transition(Motion.fadeUp)
                } else if !series.isEmpty {
                    stateList
                        .padding(Theme.Space.standard)
                        .glass(.elevated, radius: Theme.Radius.secondary)
                        .transition(Motion.fadeUp)
                } else {
                    EmptyState(
                        title: "History unavailable",
                        message: "Historical analysis becomes available after enough telemetry has been recorded."
                    )
                    .padding(Theme.Space.standard)
                    .glass(.elevated, radius: Theme.Radius.secondary)
                    .transition(Motion.fadeUp)
                }

                if !events.isEmpty {
                    related
                        .padding(Theme.Space.standard)
                        .glass(.elevated, radius: Theme.Radius.secondary)
                        .transition(Motion.fadeUp)
                }
            }
            .frame(maxWidth: 1_080, alignment: .leading)
            .animation(Motion.panel, value: window)
            .animation(Motion.panel, value: plot.isEmpty)
            .instrumentContent()
        }
        .instrumentScreen()
        .task(id: window) { await reload() }
    }

    private var stateList: some View {
        VStack(alignment: .leading, spacing: Theme.Space.compact) {
            Text("State")
                .font(Theme.Typography.section)
                .foregroundStyle(Theme.Color.tertiary)
            ForEach(series.suffix(40).reversed()) { metric in
                HStack {
                    Text(metric.time.wallTime, format: timeFormat)
                        .font(Theme.Typography.secondary)
                        .monospacedDigit()
                        .foregroundStyle(Theme.Color.secondary)
                        .frame(width: window.showsCalendarDate ? 148 : 72, alignment: .leading)
                    Text(MetricFormatter.displayString(for: metric))
                        .font(Theme.Typography.body)
                }
            }
        }
    }

    private var related: some View {
        VStack(alignment: .leading, spacing: Theme.Space.compact) {
            Text("Related events")
                .font(Theme.Typography.section)
                .foregroundStyle(Theme.Color.tertiary)
            ForEach(events.reversed()) { event in
                EventRow(event: event, showsCalendarDate: window.showsCalendarDate)
            }
        }
    }

    private var timeFormat: Date.FormatStyle {
        if window.showsCalendarDate {
            return .dateTime.month(.abbreviated).day().hour().minute().second()
        }
        return .dateTime.hour().minute().second()
    }

    private func reload() async {
        let nextSeries = await store.metricSeries(for: target, window: window)
        let nextEvents = await store.relatedEvents(for: target, window: window)
        withAnimation(Motion.crossfade) {
            series = nextSeries
            events = nextEvents
        }
    }

    private func numeric(_ metric: Metric) -> Double? {
        switch metric.value {
        case .ratio(let value), .double(let value): value
        case .int(let value): Double(value)
        case .state: nil
        }
    }
}
