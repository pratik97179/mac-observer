import Charts
import SwiftUI
import MacObserverDomain

struct Sparkline: View {
    let values: [Double]
    var times: [Date] = []
    var height: CGFloat = Theme.Chart.sparkHeight
    var showsTooltip: Bool = false
    var hoverIndex: Binding<Int?>? = nil
    var dimmed: Bool = false
    var tint: Color = Theme.Color.sage
    var showsEmptyCaption: Bool = true

    var body: some View {
        if values.count < 2 {
            VStack(alignment: .leading, spacing: Theme.Space.micro) {
                HStack(spacing: 3) {
                    ForEach(0..<18, id: \.self) { _ in
                        Circle()
                            .fill(tint.opacity(0.35))
                            .frame(width: 3, height: 3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if showsEmptyCaption {
                    Text("Collecting history…")
                        .font(Theme.Typography.metadata)
                        .foregroundStyle(Theme.Color.tertiary)
                }
            }
            .frame(height: height, alignment: .center)
            .accessibilityLabel("Collecting history")
        } else {
            LiveSparkline(
                values: values,
                times: times,
                height: height,
                showsTooltip: showsTooltip,
                hoverIndex: hoverIndex,
                dimmed: dimmed,
                tint: tint
            )
        }
    }
}

struct LiveSparkline: View {
    let values: [Double]
    var times: [Date] = []
    var height: CGFloat = Theme.Chart.sparkHeight
    var showsTooltip: Bool = false
    var hoverIndex: Binding<Int?>? = nil
    var dimmed: Bool = false
    var tint: Color = Theme.Color.sage

    var body: some View {
        GeometryReader { geo in
        Canvas { context, size in
            guard values.count >= 2 else { return }
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 1
            let span = max(maxValue - minValue, 0.0001)
            let points: [CGPoint] = values.enumerated().map { index, value in
                CGPoint(
                    x: size.width * CGFloat(index) / CGFloat(values.count - 1),
                    y: size.height - CGFloat((value - minValue) / span) * size.height
                )
            }
            var line = Path()
            var fill = Path()
            line.move(to: points[0])
            fill.move(to: CGPoint(x: points[0].x, y: size.height))
            fill.addLine(to: points[0])
            for index in 1..<points.count {
                let previous = points[index - 1]
                let current = points[index]
                let mid = CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2)
                line.addQuadCurve(to: mid, control: previous)
                fill.addQuadCurve(to: mid, control: previous)
                if index == points.count - 1 {
                    line.addQuadCurve(to: current, control: current)
                    fill.addQuadCurve(to: current, control: current)
                }
            }
            fill.addLine(to: CGPoint(x: points.last?.x ?? size.width, y: size.height))
            fill.closeSubpath()
            let opacity = dimmed ? 0.45 : 1
            context.fill(
                fill,
                with: .linearGradient(
                    Gradient(colors: [tint.opacity(0.22 * opacity), tint.opacity(0.02 * opacity)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
            context.stroke(line, with: .color(tint.opacity(opacity)), lineWidth: Theme.Chart.stroke)
            if let hover = hoverIndex?.wrappedValue, hover >= 0, hover < points.count {
                var rule = Path()
                rule.move(to: CGPoint(x: points[hover].x, y: 0))
                rule.addLine(to: CGPoint(x: points[hover].x, y: size.height))
                context.stroke(rule, with: .color(Theme.Color.secondary), lineWidth: 0.8)
                context.fill(
                    Path(ellipseIn: CGRect(x: points[hover].x - 3, y: points[hover].y - 3, width: 6, height: 6)),
                    with: .color(tint)
                )
            }
        }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            guard showsTooltip || hoverIndex != nil, values.count >= 2 else { return }
            let width = max(geo.size.width, 1)
            switch phase {
            case .active(let point):
                let span = max(values.count - 1, 1)
                let x = min(max(point.x, 0), width)
                hoverIndex?.wrappedValue = min(span, max(0, Int((x / width * CGFloat(span)).rounded())))
            case .ended:
                hoverIndex?.wrappedValue = nil
            }
        }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

struct TelemetryChart: View {
    let plot: [InspectPlotPoint]
    var height: CGFloat = 260
    var selected: Date?
    var onSelect: (InspectPlotPoint?) -> Void = { _ in }

    var body: some View {
        Chart {
            ForEach(plot) { point in
                AreaMark(
                    x: .value("Time", point.time),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.Chart.fillTop, Theme.Chart.fillBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
                LineMark(
                    x: .value("Time", point.time),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(Theme.Color.sage)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: Theme.Chart.stroke))
            }
            if let selected {
                RuleMark(x: .value("Focus", selected))
                    .foregroundStyle(Theme.Color.secondary.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartLegend(.hidden)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel()
                    .foregroundStyle(Theme.Color.tertiary)
                    .font(Theme.Typography.metadata)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        let x = resolvedX(location.x, proxy: proxy, geometry: geo)
                        guard let date: Date = proxy.value(atX: x) else { return }
                        if let match = nearest(to: date) {
                            if selected == match.time {
                                onSelect(nil)
                            } else {
                                onSelect(match)
                            }
                        }
                    }
            }
        }
        .frame(height: height)
        .accessibilityLabel("Telemetry chart")
    }

    private func resolvedX(_ tapX: CGFloat, proxy: ChartProxy, geometry: GeometryProxy) -> CGFloat {
        if let frame = proxy.plotFrame {
            return tapX - geometry[frame].origin.x
        }
        return tapX
    }

    private func nearest(to date: Date) -> InspectPlotPoint? {
        plot.min(by: { abs($0.time.timeIntervalSince(date)) < abs($1.time.timeIntervalSince(date)) })
    }
}

struct InspectPlotPoint: Identifiable {
    var id: Date { time }
    let time: Date
    let value: Double
    let unit: MacObserverDomain.Unit
}

struct TimeRangeSelector: View {
    @Binding var window: HistoryWindow

    var body: some View {
        Picker("Range", selection: $window) {
            ForEach(HistoryWindow.allCases) { item in
                Text(item.rawValue).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 360)
        .tint(Theme.Color.sage)
    }
}

struct EmptyState: View {
    var title: String? = nil
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.micro) {
            if let title {
                SectionEyebrow(title: title)
            }
            Text(message)
                .font(Theme.Typography.secondary)
                .foregroundStyle(Theme.Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Space.compact)
    }
}

struct DonutChart: View {
    let ratio: Double
    var tint: Color = Theme.Color.storage
    var label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Color.track, lineWidth: 10)
            Circle()
                .trim(from: 0, to: min(max(ratio, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int((min(max(ratio, 0), 1) * 100).rounded()))%")
                    .font(Theme.Typography.section)
                    .monospacedDigit()
                Text(label)
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.tertiary)
            }
        }
        .frame(width: 88, height: 88)
        .accessibilityLabel("\(label) \(Int((ratio * 100).rounded())) percent")
    }
}

struct HistogramChart: View {
    let values: [Double]
    var tint: Color = Theme.Color.network
    var height: CGFloat = 56

    var body: some View {
        GeometryReader { geo in
            let maxValue = max(values.max() ?? 1, 0.0001)
            let count = max(values.count, 1)
            let gap: CGFloat = 2
            let barWidth = max(2, (geo.size.width - gap * CGFloat(count - 1)) / CGFloat(count))
            HStack(alignment: .bottom, spacing: gap) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    Capsule()
                        .fill(tint.opacity(0.85))
                        .frame(width: barWidth, height: max(3, geo.size.height * CGFloat(value / maxValue)))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
