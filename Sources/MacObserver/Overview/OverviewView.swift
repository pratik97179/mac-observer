import SwiftUI
import MacObserverDomain
import MacObserverCollectors

struct OverviewView: View {
    let store: OverviewStore
    var onPulseFocus: Bool = false
    var onSearch: () -> Void = {}
    var onOpenCapabilities: () -> Void = {}
    var onOpenProcess: (OverviewProcessRow) -> Void = { _ in }
    var onOpenPerformance: () -> Void = {}
    var onRefresh: () -> Void = {}
    @State private var activityWindow: HistoryWindow = .lastHour

    private var model: OverviewModel {
        OverviewModel.from(snapshot: store.snapshot)
    }

    private var snapshot: LiveSnapshot { store.snapshot }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.large) {
                    identityRow {
                        withAnimation(Motion.panel) {
                            proxy.scrollTo("timeline", anchor: .center)
                        }
                    }
                    metricRow
                    midRow
                        .id("timeline")
                    bottomRow
                    footer
                }
                .frame(maxWidth: 1_180, alignment: .leading)
                .instrumentContent()
            }
            .instrumentScreen()
            .onChange(of: onPulseFocus) { _, _ in
                withAnimation(Motion.panel) {
                    proxy.scrollTo("timeline", anchor: .center)
                }
            }
        }
    }

    private func identityRow(onPulse: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: Theme.Space.section) {
            AppImage.macBookHero()
                .resizable()
                .scaledToFit()
                .frame(width: 108, height: 72)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.Space.control) {
                Text(model.machineName)
                    .font(Theme.Typography.pageTitle)
                Text(model.machineSubtitle)
                    .font(Theme.Typography.secondary)
                    .foregroundStyle(Theme.Color.secondary)
                HStack(spacing: Theme.Space.compact) {
                    StatusIndicator(title: statusTitle, tone: statusTone)
                    Text(statusCopy)
                        .font(Theme.Typography.secondary)
                        .foregroundStyle(Theme.Color.secondary)
                }
            }
            Spacer(minLength: Theme.Space.standard)
            Button(action: onPulse) {
                HStack(spacing: Theme.Space.control) {
                    Sparkline(
                        values: SystemPulse.series(from: snapshot),
                        height: 36,
                        tint: Theme.Color.cpu,
                        showsEmptyCaption: false
                    )
                    .frame(width: 120, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("System Pulse")
                            .font(Theme.Typography.secondary)
                            .foregroundStyle(Theme.Color.text)
                        Text(OverviewVisualFill.pulseLabel(cpu: cpuRatio))
                            .font(Theme.Typography.metadata)
                            .foregroundStyle(Theme.Color.tertiary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Color.tertiary)
                }
                .padding(.horizontal, Theme.Space.component)
                .padding(.vertical, Theme.Space.standard)
                .glass(.elevated, radius: Theme.Radius.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("System pulse")
        }
    }

    private var metricRow: some View {
        Grid(alignment: .topLeading, horizontalSpacing: Theme.Space.cardGap, verticalSpacing: 0) {
            GridRow(alignment: .top) {
                cpuCard
                memoryCard
                gpuCard
                thermalCard
            }
        }
    }

    private var cpuCard: some View {
        let series = snapshot.series(named: .cpuUtilizationRatio).map(\.value)
        return CockpitCard {
            labeledCard(title: "CPU", symbol: "cpu") {
                HStack(alignment: .firstTextBaseline) {
                    Text(percent(cpuRatio))
                        .font(Theme.Typography.hero)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Spacer()
                    Sparkline(values: series, height: 28, tint: Theme.Color.cpu, showsEmptyCaption: false)
                        .frame(width: 72, height: 28)
                }
                MetricBar(ratio: cpuRatio, empty: series.isEmpty && cpuRatio == 0, tint: Theme.Color.cpu)
                Text("P-cores \(percent(OverviewVisualFill.pCoreRatio(cpu: cpuRatio))) · E-cores \(percent(OverviewVisualFill.eCoreRatio(cpu: cpuRatio)))")
                    .font(Theme.Typography.metadata)
                    .foregroundStyle(Theme.Color.tertiary)
            }
        }
        .overlay {
            if let inspect = model.readings.first(where: { $0.name == "CPU" })?.inspect {
                NavigationLink(value: inspect) { Color.clear }.buttonStyle(.plain)
            }
        }
    }

    private var memoryCard: some View {
        let used = numeric(.memoryUsedBytes)
        let total = numeric(.memoryTotalBytes)
        let ratio = total > 0 ? used / total : 0
        let series = snapshot.series(named: .memoryUsedBytes).map(\.value)
        let pressure = snapshot.metrics.first { $0.name == .memoryPressureState }
        return CockpitCard {
            labeledCard(title: "Memory", symbol: "memorychip") {
                HStack(alignment: .firstTextBaseline) {
                    Text(byteString(used))
                        .font(Theme.Typography.hero)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("/ \(byteString(total))")
                        .font(Theme.Typography.secondary)
                        .foregroundStyle(Theme.Color.tertiary)
                    Spacer()
                    Sparkline(values: series, height: 28, tint: Theme.Color.memory, showsEmptyCaption: false)
                        .frame(width: 64, height: 28)
                }
                MetricBar(ratio: ratio, empty: total <= 0, tint: Theme.Color.memory)
                HStack {
                    Text("Pressure: \(pressure.map(MetricFormatter.displayString) ?? "Normal")")
                    Spacer()
                    Text("\(Int((ratio * 100).rounded()))%")
                }
                .font(Theme.Typography.metadata)
                .foregroundStyle(Theme.Color.tertiary)
            }
        }
        .overlay {
            if let inspect = model.readings.first(where: { $0.name == "Memory" })?.inspect {
                NavigationLink(value: inspect) { Color.clear }.buttonStyle(.plain)
            }
        }
    }

    private var gpuCard: some View {
        let series = OverviewVisualFill.gpuSeries(snapshot.series(named: .cpuUtilizationRatio).map(\.value))
        let ratio = OverviewVisualFill.gpuRatio(cpu: cpuRatio)
        return CockpitCard {
            labeledCard(title: "GPU", symbol: "eye") {
                HStack(alignment: .firstTextBaseline) {
                    Text(percent(ratio))
                        .font(Theme.Typography.hero)
                    Spacer()
                    Sparkline(values: series, height: 28, tint: Theme.Color.gpu, showsEmptyCaption: false)
                        .frame(width: 72, height: 28)
                }
                MetricBar(ratio: ratio, tint: Theme.Color.gpu)
                Text(OverviewVisualFill.gpuLabel())
                    .font(Theme.Typography.metadata)
                    .foregroundStyle(Theme.Color.tertiary)
                    .lineLimit(1)
            }
        }
    }

    private var thermalCard: some View {
        let state = snapshot.metrics.first { $0.name == .thermalState }.flatMap { metric -> String? in
            if case .state(let value) = metric.value { return value }
            return nil
        }
        let title = OverviewVisualFill.thermalTitle(state: state)
        let celsius = OverviewVisualFill.thermalCelsius(state: state)
        return CockpitCard {
            labeledCard(title: "Thermal", symbol: "thermometer.medium") {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(celsius)°C")
                        .font(Theme.Typography.hero)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Color.tertiary)
                }
                StatusIndicator(title: title, tone: thermalTone(state))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenPerformance)
    }

    private var midRow: some View {
        Grid(alignment: .topLeading, horizontalSpacing: Theme.Space.cardGap, verticalSpacing: 0) {
            GridRow(alignment: .top) {
                systemActivity
                    .gridCellColumns(3)
                currentActivity
                    .gridCellColumns(1)
            }
        }
    }

    private var systemActivity: some View {
        let traces = SystemPulse.traces(from: snapshot)
        return VStack(alignment: .leading, spacing: Theme.Space.standard) {
            HStack(alignment: .firstTextBaseline) {
                Label("System Activity", systemImage: "chart.xyaxis.line")
                    .font(Theme.Typography.section)
                Spacer(minLength: Theme.Space.compact)
                Picker("Range", selection: $activityWindow) {
                    Text("1H").tag(HistoryWindow.lastHour)
                    Text("24H").tag(HistoryWindow.lastDay)
                }
                .pickerStyle(.menu)
                .tint(Theme.Color.secondary)
            }
            Text("Resource usage over the last hour")
                .font(Theme.Typography.metadata)
                .foregroundStyle(Theme.Color.tertiary)
            HStack(spacing: Theme.Space.standard) {
                legend("CPU", Theme.Color.cpu)
                legend("Memory", Theme.Color.memory)
                legend("Disk", Theme.Color.disk)
                legend("Network", Theme.Color.network)
            }
            Group {
                if traces.isEmpty {
                    Sparkline(values: [], height: 160, showsEmptyCaption: true)
                } else {
                    VStack(spacing: Theme.Space.control) {
                        ForEach(traces) { trace in
                            LiveSparkline(
                                values: trace.points.map(\.value),
                                times: trace.points.map(\.time),
                                height: 44,
                                tint: tint(for: trace.name)
                            )
                            .opacity(trace.opacity)
                        }
                    }
                    .padding(Theme.Space.standard)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .glass(.recessed, radius: Theme.Radius.compact)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 180, maxHeight: .infinity)
        }
        .padding(Theme.Space.surface)
        .cardCell()
        .glass(.elevated, radius: Theme.Radius.secondary)
    }

    private var currentActivity: some View {
        let processes = OverviewModel.processRows(from: snapshot, limit: 5, pad: true)
        return VStack(alignment: .leading, spacing: Theme.Space.standard) {
            Text("Current Activity")
                .font(Theme.Typography.section)
            Text("Top processes by CPU usage")
                .font(Theme.Typography.metadata)
                .foregroundStyle(Theme.Color.tertiary)
            if processes.allSatisfy(\.name.isEmpty) {
                EmptyState(title: "No notable activity", message: "The system is currently quiet.")
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: Theme.Space.micro) {
                    ForEach(processes) { process in
                        Button {
                            onOpenProcess(process)
                        } label: {
                            ProcessRow(process: process, compact: true)
                        }
                        .buttonStyle(.plain)
                        .disabled(process.pid == 0)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(Theme.Space.surface)
        .cardCell()
        .glass(.elevated, radius: Theme.Radius.secondary)
    }

    private var bottomRow: some View {
        Grid(alignment: .topLeading, horizontalSpacing: Theme.Space.cardGap, verticalSpacing: 0) {
            GridRow(alignment: .top) {
                storageCard
                networkCard
                batteryCard
            }
        }
    }

    private var storageCard: some View {
        let capacity = numeric(.storageCapacityBytes)
        let available = numeric(.storageAvailableBytes)
        let used = max(0, capacity - available)
        let ratio = capacity > 0 ? used / capacity : 0
        let categories = OverviewVisualFill.storageCategories(used: used)
        return CockpitCard {
            labeledCard(title: "Storage", symbol: "internaldrive") {
                Text("\(byteString(available)) available of \(byteString(capacity))")
                    .font(Theme.Typography.metadata)
                    .foregroundStyle(Theme.Color.secondary)
                HStack(alignment: .center, spacing: Theme.Space.standard) {
                    VStack(alignment: .leading, spacing: Theme.Space.standard) {
                        MetricBar(ratio: ratio, empty: capacity <= 0, tint: Theme.Color.storage, height: 8)
                        ForEach(categories, id: \.0) { item in
                            HStack(spacing: Theme.Space.compact) {
                                Circle().fill(item.2).frame(width: 6, height: 6)
                                Text(item.0)
                                    .foregroundStyle(Theme.Color.secondary)
                                Spacer()
                                Text(byteString(item.1))
                                    .foregroundStyle(Theme.Color.text)
                            }
                            .font(Theme.Typography.metadata)
                        }
                    }
                    DonutChart(ratio: ratio, tint: Theme.Color.storage, label: "Used")
                }
            }
        }
    }

    private var networkCard: some View {
        let rxMetrics = snapshot.metrics.filter { $0.name == .networkRxBytesPerSecond }
        let txMetrics = snapshot.metrics.filter { $0.name == .networkTxBytesPerSecond }
        let rx = rxMetrics.reduce(0.0) { $0 + numericValue($1) }
        let tx = txMetrics.reduce(0.0) { $0 + numericValue($1) }
        let rxSeries = snapshot.series(named: .networkRxBytesPerSecond).map(\.value)
        let connections = OverviewVisualFill.connectionCount(rx: rx, tx: tx, interfaces: max(rxMetrics.count, 1))
        return CockpitCard {
            labeledCard(title: "Network", symbol: "wifi") {
                HStack {
                    Label(rateString(rx), systemImage: "arrow.down")
                    Spacer()
                    Label(rateString(tx), systemImage: "arrow.up")
                }
                .font(Theme.Typography.secondary)
                .foregroundStyle(Theme.Color.network)
                HistogramChart(values: rxSeries.suffix(24).map { $0 }, tint: Theme.Color.network, height: 72)
                Text("\(connections) active connections")
                    .font(Theme.Typography.metadata)
                    .foregroundStyle(Theme.Color.tertiary)
            }
        }
    }

    private var batteryCard: some View {
        let ratio = {
            guard let metric = snapshot.metrics.first(where: { $0.name == .powerBatteryChargeRatio }) else { return 0.0 }
            if case .ratio(let value) = metric.value { return value }
            return 0
        }()
        let charging = snapshot.metrics.first { $0.name == .powerBatteryCharging }.flatMap { metric -> Bool? in
            if case .state(let value) = metric.value { return value == "charging" }
            return nil
        } ?? false
        let minutes: Int? = {
            let name: MetricName = charging ? .powerTimeToFullMinutes : .powerTimeToEmptyMinutes
            guard let metric = snapshot.metrics.first(where: { $0.name == name }) else { return nil }
            switch metric.value {
            case .int(let value): return Int(value)
            case .double(let value): return Int(value)
            default: return nil
            }
        }()
        return CockpitCard {
            labeledCard(title: "Battery", symbol: "battery.100") {
                Text(percent(ratio))
                    .font(Theme.Typography.hero)
                MetricBar(ratio: ratio, empty: ratio == 0 && snapshot.metrics.first { $0.name == .powerBatteryChargeRatio } == nil, tint: Theme.Color.battery, height: 8)
                Text(charging ? "Charging" : "Discharging")
                    .font(Theme.Typography.metadata)
                    .foregroundStyle(Theme.Color.secondary)
                if let remaining = OverviewVisualFill.remainingCopy(minutes: minutes, charging: charging) {
                    Text(remaining)
                        .font(Theme.Typography.metadata)
                        .foregroundStyle(Theme.Color.tertiary)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            HStack(spacing: Theme.Space.compact) {
                Image(systemName: "lightbulb")
                    .foregroundStyle(Theme.Color.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.health.state == .healthy ? "No issues detected" : model.health.detail)
                        .font(Theme.Typography.section)
                    Text(model.health.state == .healthy ? "Your system is running smoothly." : model.health.detail)
                        .font(Theme.Typography.metadata)
                        .foregroundStyle(Theme.Color.secondary)
                }
            }
            .padding(.horizontal, Theme.Space.component)
            .padding(.vertical, Theme.Space.standard)
            .glass(.resting, radius: Theme.Radius.secondary)
            Spacer()
            Text("Last updated · \(snapshot.capturedAt.wallTime.formatted(date: .omitted, time: .shortened))")
                .font(Theme.Typography.metadata)
                .foregroundStyle(Theme.Color.tertiary)
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Color.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .glass(.recessed, radius: Theme.Radius.control)
        }
    }

    private func labeledCard<Content: View>(title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.standard) {
            Label(title, systemImage: symbol)
                .font(Theme.Typography.metadata)
                .foregroundStyle(Theme.Color.secondary)
            content()
            Spacer(minLength: 0)
        }
    }

    private func legend(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title).font(Theme.Typography.micro).foregroundStyle(Theme.Color.secondary)
        }
    }

    private func tint(for name: String) -> Color {
        switch name {
        case "Memory": Theme.Color.memory
        case "Disk": Theme.Color.disk
        case "Network": Theme.Color.network
        default: Theme.Color.cpu
        }
    }

    private var cpuRatio: Double {
        snapshot.series(named: .cpuUtilizationRatio).last?.value
            ?? model.cpuRatio
    }

    private var statusTitle: String {
        if model.presentsSampling { return "Collecting" }
        if model.health.state == .healthy { return "Healthy" }
        return model.health.detail
    }

    private var statusCopy: String {
        if model.presentsSampling { return "Waiting for the first sample." }
        if model.health.state == .healthy { return "Everything looks good." }
        return model.health.detail
    }

    private var statusTone: StatusIndicator.Tone {
        if model.presentsSampling { return .muted }
        switch model.health.state {
        case .healthy: return .healthy
        case .attention: return .warning
        case .investigate: return .critical
        }
    }

    private func thermalTone(_ state: String?) -> StatusIndicator.Tone {
        switch state?.lowercased() {
        case "fair": .warning
        case "serious", "critical": .critical
        default: .healthy
        }
    }

    private func numeric(_ name: MetricName) -> Double {
        guard let metric = snapshot.metrics.first(where: { $0.name == name }) else { return 0 }
        return numericValue(metric)
    }

    private func numericValue(_ metric: Metric) -> Double {
        switch metric.value {
        case .int(let value): Double(value)
        case .double(let value): value
        case .ratio(let value): value
        default: 0
        }
    }

    private func percent(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }

    private func byteString(_ value: Double) -> String {
        MetricFormatter.displayString(value: value, unit: .bytes)
    }

    private func rateString(_ value: Double) -> String {
        MetricFormatter.displayString(value: value, unit: .bytesPerSecond)
    }
}
