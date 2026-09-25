import SwiftUI
import MacObserverCollectors
import MacObserverDomain

struct LiveProfileView: View {
    let store: OverviewStore
    let profile: Profile
    var onOpenProcess: (OverviewProcessRow) -> Void = { _ in }
    var onOpenCapabilities: () -> Void = {}
    @Environment(\.designMetrics) private var metrics
    @State private var model: ProfileLiveModel?
    @State private var overview: OverviewModel?

    private var resolvedModel: ProfileLiveModel {
        model ?? ProfilePresentation.model(for: profile, snapshot: store.snapshot)
    }

    private var resolvedOverview: OverviewModel {
        overview ?? OverviewModel.from(snapshot: store.snapshot)
    }

    var body: some View {
        ScreenPage {
            VStack(alignment: .leading, spacing: Theme.Space.section) {
                header
                switch profile {
                case .performance:
                    performanceBody
                case .network:
                    networkBody
                case .storage:
                    storageBody
                case .power:
                    powerBody
                case .processes:
                    processBody
                default:
                    EmptyView()
                }
            }
        }
        .onAppear { refreshModels() }
        .onChange(of: store.snapshot.capturedAt.wallTime) { _, _ in
            refreshModels()
        }
        .onChange(of: profile) { _, _ in
            refreshModels()
        }
    }

    private func refreshModels() {
        model = ProfilePresentation.model(for: profile, snapshot: store.snapshot)
        overview = OverviewModel.from(snapshot: store.snapshot)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.compact) {
            SectionEyebrow(title: "Live")
            Text(resolvedModel.title)
                .font(metrics.type.display)
                .foregroundStyle(Theme.Color.text)
            Text(resolvedModel.summary)
                .font(Theme.Typography.secondary)
                .foregroundStyle(Theme.Color.secondary)
            FreshnessBadge(age: resolvedOverview.sampleAge, sampling: resolvedOverview.presentsSampling)
            if let availability = resolvedModel.availability {
                PermissionState(message: availability, onCapabilities: onOpenCapabilities)
            }
        }
    }

    private var performanceBody: some View {
        VStack(alignment: .leading, spacing: Theme.Space.section) {
            let cpuSeries = store.snapshot.series(named: .cpuUtilizationRatio)
            if cpuSeries.count >= 2 {
                TelemetryChart(plot: cpuSeries.map { point in
                    InspectPlotPoint(time: point.time, value: point.value, unit: .ratio)
                })
                .padding(Theme.Space.standard)
            } else {
                EmptyState(title: "History unavailable", message: "Historical analysis becomes available after enough telemetry has been recorded.")
                    .padding(Theme.Space.standard)
            }

            Grid(alignment: .topLeading, horizontalSpacing: Theme.Space.cardGap, verticalSpacing: 0) {
                GridRow(alignment: .top) {
                    ForEach(resolvedModel.readings) { reading in
                        performanceBlock(reading)
                            .cardCell()
                    }
                }
            }
            .padding(Theme.Space.component)

            if !resolvedModel.rows.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Space.micro) {
                    Text("Memory")
                        .font(Theme.Typography.section)
                    EntityColumnHeader(columns: resolvedModel.columns)
                    ForEach(resolvedModel.rows) { row in
                        EntityRow(cells: row.cells)
                    }
                }
                .padding(Theme.Space.component)
            }
        }
    }

    @ViewBuilder
    private func performanceBlock(_ reading: OverviewReading) -> some View {
        MetricBlock(
            label: reading.name,
            value: reading.value.isEmpty ? " " : reading.value,
            loading: reading.kind == .pending
        ) {
            if reading.name == "CPU" {
                MetricBar(ratio: LiveSeries.values(for: reading, snapshot: store.snapshot).last ?? 0, empty: reading.kind != .live, tint: Theme.Color.cpu)
            } else if reading.name == "Memory" {
                VStack(alignment: .leading, spacing: Theme.Space.compact) {
                    CapacityBar(used: numeric(.memoryUsedBytes), total: numeric(.memoryTotalBytes), tint: Theme.Color.memory)
                    if !memorySegments.isEmpty {
                        SegmentedBar(segments: memorySegments)
                    }
                }
            } else if reading.name == "Pressure" || reading.name == "Thermal" {
                StatusIndicator(title: reading.value.isEmpty ? "unavailable" : reading.value, tone: thermalTone(reading.value))
            } else {
                MetricBar(ratio: 0, empty: true)
            }
        } metadata: {
            if reading.kind == .unavailable {
                UnavailableState(title: "Telemetry unavailable", action: "View Capabilities", onAction: onOpenCapabilities)
            } else if reading.name == "Memory" {
                Text(memoryCompositionCopy)
            } else {
                Text(reading.detail)
            }
        }
        .modifier(InspectLinkModifier(target: reading.inspect))
    }

    private var memorySegments: [(Double, Color)] {
        let wired = numeric(.memoryWiredBytes)
        let compressed = numeric(.memoryCompressedBytes)
        let swap = numeric(.memorySwapUsedBytes)
        var items: [(Double, Color)] = []
        if wired > 0 { items.append((wired, Theme.Color.sage)) }
        if compressed > 0 { items.append((compressed, Theme.Color.sageMuted)) }
        if swap > 0 { items.append((swap, Theme.Color.warning.opacity(0.8))) }
        return items
    }

    private var memoryCompositionCopy: String {
        let wired = store.snapshot.metrics.first { $0.name == .memoryWiredBytes }
        let compressed = store.snapshot.metrics.first { $0.name == .memoryCompressedBytes }
        let swap = store.snapshot.metrics.first { $0.name == .memorySwapUsedBytes }
        return [
            wired.map { "Wired \(MetricFormatter.displayString(for: $0))" },
            compressed.map { "Compressed \(MetricFormatter.displayString(for: $0))" },
            swap.map { "Swap \(MetricFormatter.displayString(for: $0))" }
        ].compactMap { $0 }.joined(separator: " · ")
    }

    private func thermalTone(_ value: String) -> StatusIndicator.Tone {
        let lowered = value.lowercased()
        if lowered.contains("critical") || lowered.contains("serious") { return .critical }
        if lowered.contains("fair") || lowered.contains("elevat") { return .warning }
        if value.isEmpty { return .unavailable }
        return .healthy
    }

    private var networkBody: some View {
        let rx = resolvedModel.readings.first { $0.name == "Receive" }
        let tx = resolvedModel.readings.first { $0.name == "Transmit" }
        return VStack(alignment: .leading, spacing: Theme.Space.section) {
            VStack(alignment: .leading, spacing: Theme.Space.standard) {
                Text("NETWORK")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.tertiary)
                StatusIndicator(
                    title: rx?.kind == .live ? "Connected" : "unavailable",
                    tone: rx?.kind == .live ? .healthy : .unavailable
                )
                if rx?.kind == .live || tx?.kind == .live {
                    FlowIndicator(
                        inbound: flowValue(rx),
                        outbound: flowValue(tx),
                        inboundRatio: flowRatio(.networkRxBytesPerSecond),
                        outboundRatio: flowRatio(.networkTxBytesPerSecond)
                    )
                } else {
                    UnavailableState(title: "Interface counters unavailable", action: "View Capabilities", onAction: onOpenCapabilities)
                }
                localPath
                internetCheck
            }
            .padding(Theme.Space.surface)

            VStack(alignment: .leading, spacing: Theme.Space.micro) {
                Text("Interfaces")
                    .font(Theme.Typography.section)
                if resolvedModel.rows.isEmpty {
                    EmptyState(title: "No interfaces", message: "Interface counters appear after the network collector publishes a sample.")
                } else {
                    EntityColumnHeader(columns: resolvedModel.columns)
                    ForEach(resolvedModel.rows) { row in
                        EntityRow(cells: row.cells)
                    }
                }
            }
            .padding(Theme.Space.component)
        }
    }

    private var localPath: some View {
        let gateway = resolvedModel.readings.first { $0.name == "Gateway" }
        let dns = resolvedModel.readings.first { $0.name == "DNS" }
        let primary = store.snapshot.metrics.first { $0.name == .networkPrimaryInterface }
        let count = store.snapshot.metrics.first { $0.name == .networkDNSResolverCount }
        return VStack(alignment: .leading, spacing: Theme.Space.micro) {
            if gateway?.kind == .live {
                Text("Gateway \(gateway?.value ?? "")")
                    .font(Theme.Typography.secondary)
                    .foregroundStyle(Theme.Color.secondary)
            } else {
                Text("Gateway unavailable")
                    .font(Theme.Typography.secondary)
                    .foregroundStyle(Theme.Color.tertiary)
            }
            if dns?.kind == .live {
                let extra = count.flatMap { metric -> String? in
                    if case .int(let value) = metric.value, value > 1 {
                        return " · \(value) resolvers"
                    }
                    return nil
                } ?? ""
                Text("DNS \(dns?.value ?? "")\(extra)")
                    .font(Theme.Typography.secondary)
                    .foregroundStyle(Theme.Color.secondary)
            }
            if let primary {
                Text("Primary \(MetricFormatter.displayString(for: primary))")
                    .font(Theme.Typography.metadata)
                    .foregroundStyle(Theme.Color.tertiary)
            }
        }
    }

    private var internetCheck: some View {
        let enabled = store.isCapabilityEnabled(ExternalDiagnosticsCollector.capabilityID)
        let address = store.snapshot.metrics.first { $0.name == .networkPublicAddress }
        let rtt = store.snapshot.metrics.first { $0.name == .networkExternalRoundTripNanoseconds }
        return VStack(alignment: .leading, spacing: Theme.Space.compact) {
            if !enabled {
                UnavailableState(
                    title: "Public address and latency stay off until you enable Internet Check.",
                    action: "View Capabilities",
                    onAction: onOpenCapabilities
                )
            } else if let address {
                Text("Public address \(MetricFormatter.displayString(for: address))")
                    .font(Theme.Typography.secondary)
                    .foregroundStyle(Theme.Color.secondary)
                if let rtt {
                    Text("Round trip \(MetricFormatter.displayString(for: rtt))")
                        .font(Theme.Typography.metadata)
                        .foregroundStyle(Theme.Color.tertiary)
                }
                Button("Run internet check") {
                    Task { await store.runExternalDiagnostic() }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Color.sage)
                .font(Theme.Typography.metadata)
            } else {
                UnavailableState(
                    title: "No public address yet. This does not run until you ask.",
                    action: "Run internet check",
                    onAction: { Task { await store.runExternalDiagnostic() } }
                )
            }
        }
    }

    private var storageBody: some View {
        VStack(alignment: .leading, spacing: Theme.Space.section) {
            MetricBlock(
                label: "Capacity",
                value: resolvedModel.readings.first { $0.name == "Capacity" }?.value.nonEmpty ?? " ",
                loading: resolvedModel.readings.first { $0.name == "Capacity" }?.kind == .pending
            ) {
                CapacityBar(used: numeric(.storageCapacityBytes) - numeric(.storageAvailableBytes), total: numeric(.storageCapacityBytes), tint: Theme.Color.storage, showsCaption: true)
            } metadata: {
                Text(resolvedModel.readings.first { $0.name == "Available" }.map { "Available \($0.value)" } ?? "Root volume")
            }

            FlowIndicator(
                inbound: resolvedModel.readings.first { $0.name == "Read" }?.value.nonEmpty ?? "unavailable",
                outbound: resolvedModel.readings.first { $0.name == "Write" }?.value.nonEmpty ?? "unavailable",
                inboundRatio: flowRatio(.storageReadBytesPerSecond),
                outboundRatio: flowRatio(.storageWriteBytesPerSecond)
            )
        }
        .padding(Theme.Space.surface)
    }

    private var powerBody: some View {
        VStack(alignment: .leading, spacing: Theme.Space.standard) {
            ForEach(resolvedModel.readings) { reading in
                MetricBlock(
                    label: reading.name,
                    value: reading.value.isEmpty ? " " : reading.value,
                    loading: reading.kind == .pending
                ) {
                    if reading.name == "Battery" {
                        CapacityBar(used: batteryRatio, total: 1, tint: Theme.Color.battery, showsCaption: false)
                    } else if reading.name == "Thermal" {
                        StatusIndicator(title: reading.value.isEmpty ? "unavailable" : reading.value, tone: thermalTone(reading.value))
                    } else {
                        EmptyView()
                    }
                } metadata: {
                    Text(reading.detail)
                }
            }
        }
        .padding(Theme.Space.surface)
    }

    private var processBody: some View {
        let processes = OverviewModel.processRows(from: store.snapshot, limit: PanelLayout.tableRowCountProcesses, pad: false)
        return VStack(alignment: .leading, spacing: Theme.Space.compact) {
            if processes.isEmpty {
                EmptyState(title: "No notable activity", message: "The system is currently quiet.")
            } else {
                EntityColumnHeader(columns: resolvedModel.columns.isEmpty ? ["Process", "CPU", "Memory", "Network"] : resolvedModel.columns)
                ForEach(processes) { process in
                    Button {
                        onOpenProcess(process)
                    } label: {
                        ProcessRow(process: process)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Theme.Space.component)
    }

    private var batteryRatio: Double {
        guard let metric = store.snapshot.metrics.first(where: { $0.name == .powerBatteryChargeRatio }) else { return 0 }
        if case .ratio(let value) = metric.value { return value }
        return 0
    }

    private func numeric(_ name: MetricName) -> Double {
        guard let metric = store.snapshot.metrics.first(where: { $0.name == name }) else { return 0 }
        switch metric.value {
        case .int(let value): return Double(value)
        case .double(let value): return value
        case .ratio(let value): return value
        default: return 0
        }
    }

    private func flowRatio(_ name: MetricName) -> Double {
        let total = store.snapshot.series(named: name).last.map(\.value) ?? 0
        return min(1, max(total <= 0 ? 0 : 0.08, total / 12_500_000))
    }

    private func flowValue(_ reading: OverviewReading?) -> String {
        guard let reading, !reading.value.isEmpty else { return "unavailable" }
        return reading.value
    }
}

private struct InspectLinkModifier: ViewModifier {
    let target: MetricInspectTarget?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let target {
            NavigationLink(value: target) {
                content
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens metric history")
        } else {
            content
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
