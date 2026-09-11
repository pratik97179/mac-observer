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

    init(title: String, metricName: MetricName, domain: TelemetryDomain, entityKey: String?) {
        self.title = title
        self.metricName = metricName
        self.domain = domain
        self.entityKey = entityKey
    }

    init(_ inspect: ExplanationInspect) {
        self.init(
            title: inspect.title,
            metricName: inspect.metricName,
            domain: inspect.domain,
            entityKey: inspect.entityKey
        )
    }
}

struct MetricInspectView: View {
    let store: OverviewStore
    let target: MetricInspectTarget
    @State private var window: HistoryWindow = .lastHour
    @State private var series: [Metric] = []
    @State private var events: [Event] = []
    @State private var focus: InspectPlotPoint?
    @State private var focusedEvents: [Event] = []
    @State private var loading = true

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

    private var visibleEvents: [Event] {
        focus == nil ? events : focusedEvents
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.section) {
                VStack(alignment: .leading, spacing: Theme.Space.compact) {
                    Text(target.title)
                        .font(Theme.Typography.pageTitle)
                    Text(heroValue)
                        .font(Theme.Typography.hero)
                        .readoutTransition(heroValue)
                    if let lastAge, lastAge > 15 {
                        StaleState(age: Int(lastAge))
                    }
                }

                TimeRangeSelector(window: $window)

                if !plot.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Space.control) {
                        TelemetryChart(plot: plot, selected: focus?.time, onSelect: select)
                        Text(chartCaption)
                            .font(Theme.Typography.metadata)
                            .foregroundStyle(Theme.Color.tertiary)
                    }
                    .padding(Theme.Space.standard)
                    .glass(.recessed, radius: Theme.Radius.secondary)
                    .transition(Motion.fadeUp)
                } else if !series.isEmpty {
                    stateList
                        .padding(Theme.Space.standard)
                        .glass(.elevated, radius: Theme.Radius.secondary)
                        .transition(Motion.fadeUp)
                } else if loading {
                    Text("Loading history")
                        .font(Theme.Typography.secondary)
                        .foregroundStyle(Theme.Color.secondary)
                        .padding(Theme.Space.standard)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glass(.elevated, radius: Theme.Radius.secondary)
                } else {
                    EmptyState(
                        title: "History unavailable",
                        message: "Historical analysis becomes available after enough telemetry has been recorded."
                    )
                    .padding(Theme.Space.standard)
                    .glass(.elevated, radius: Theme.Radius.secondary)
                    .transition(Motion.fadeUp)
                }

                related
                    .padding(Theme.Space.standard)
                    .glass(.elevated, radius: Theme.Radius.secondary)
                    .transition(Motion.fadeUp)
            }
            .frame(maxWidth: 1_080, alignment: .leading)
            .animation(Motion.panel, value: window)
            .animation(Motion.panel, value: plot.isEmpty)
            .instrumentContent()
        }
        .instrumentScreen()
        .task(id: window) { await reload() }
        .task(id: focus?.time) { await reloadFocusedEvents() }
        .onChange(of: window) { _, _ in
            focus = nil
            focusedEvents = []
        }
    }

    private var heroValue: String {
        if loading { return "Loading" }
        return current.map(MetricFormatter.displayString) ?? "No samples in this range"
    }

    private var chartCaption: String {
        if let focus {
            let value = MetricFormatter.displayString(value: focus.value, unit: focus.unit)
            return "\(focus.time.formatted(date: .omitted, time: .shortened)) · \(value). Related events are limited to this interval."
        }
        return "Click a point to see events in that interval. The selected range stays \(window.rawValue)."
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
            HStack {
                Text(focus == nil ? "Related events" : "Events in this interval")
                    .font(Theme.Typography.section)
                    .foregroundStyle(Theme.Color.tertiary)
                Spacer()
                if focus != nil {
                    Button("Show all") {
                        focus = nil
                        focusedEvents = []
                    }
                    .buttonStyle(.plain)
                    .font(Theme.Typography.metadata)
                    .foregroundStyle(Theme.Color.accent)
                }
            }
            if visibleEvents.isEmpty {
                Text(focus == nil ? "No stored events in this range." : "No events in this interval.")
                    .font(Theme.Typography.secondary)
                    .foregroundStyle(Theme.Color.secondary)
            } else {
                ForEach(visibleEvents.reversed()) { event in
                    EventRow(event: event, showsCalendarDate: window.showsCalendarDate)
                }
            }
        }
    }

    private var timeFormat: Date.FormatStyle {
        if window.showsCalendarDate {
            return .dateTime.month(.abbreviated).day().hour().minute().second()
        }
        return .dateTime.hour().minute().second()
    }

    private func select(_ point: InspectPlotPoint?) {
        focus = point
        if point == nil {
            focusedEvents = []
        }
    }

    private func reload() async {
        loading = true
        let nextSeries = await store.metricSeries(for: target, window: window)
        let nextEvents = await store.relatedEvents(for: target, window: window)
        series = nextSeries
        events = nextEvents
        loading = false
    }

    private func reloadFocusedEvents() async {
        guard let focus else { return }
        let parent = InvestigationInterval.range(for: window.duration)
        let bucket = InvestigationInterval.bucketSeconds(windowDuration: window.duration)
        let range = InvestigationInterval.around(focus.time, bucketSeconds: bucket, in: parent)
        focusedEvents = await store.relatedEvents(for: target, range: range)
    }

    private func numeric(_ metric: Metric) -> Double? {
        switch metric.value {
        case .ratio(let value), .double(let value): value
        case .int(let value): Double(value)
        case .state: nil
        }
    }
}
