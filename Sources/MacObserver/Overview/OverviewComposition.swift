import SwiftUI
import MacObserverDomain
import MacObserverCollectors

struct OverviewCockpit: View {
    let store: OverviewStore
    var availableSize: CGSize
    var onOpenProcess: (OverviewProcessRow) -> Void = { _ in }
    var onOpenProfile: (Profile) -> Void = { _ in }
    var onSearch: () -> Void = {}
    var onRefresh: () -> Void = {}
    @Environment(\.designMetrics) private var metrics

    private var model: OverviewModel { OverviewModel.from(snapshot: store.snapshot) }
    private var snapshot: LiveSnapshot { store.snapshot }

    var body: some View {
        let cockpitPadding: CGFloat = 12
        let innerHeight = max(availableSize.height - cockpitPadding * 2, 1)
        let innerWidth = min(max(availableSize.width - cockpitPadding * 2, 1), metrics.contentMaxWidth)
        let compactHeight = innerHeight < 780
        let compactWidth = metrics.regime == .compact || innerWidth < 820
        VStack(alignment: .leading, spacing: metrics.spacing.sm) {
            OverviewUtilityHeader(onSearch: onSearch, onRefresh: onRefresh)
            OverviewHero(
                model: model,
                snapshot: snapshot,
                compactWidth: compactWidth,
                compactHeight: compactHeight,
                onOpenProfile: onOpenProfile
            )
            .frame(maxWidth: .infinity)
            SystemActivityRegion(
                snapshot: snapshot,
                staleAge: staleAge,
                compact: compactHeight
            )
            .frame(maxWidth: .infinity, maxHeight: 56)
            OverviewBottomSection(
                snapshot: snapshot,
                staleAge: staleAge,
                compact: compactHeight,
                compactWidth: compactWidth,
                onOpenProcess: onOpenProcess,
                onOpenProfile: onOpenProfile
            )
            .frame(maxWidth: .infinity)
        }
        .padding(cockpitPadding)
        .frame(width: availableSize.width, height: availableSize.height, alignment: .top)
        .animation(.easeInOut(duration: 0.28), value: compactWidth)
        .animation(.easeInOut(duration: 0.28), value: compactHeight)
    }

    private var staleAge: TimeInterval? {
        guard let age = model.sampleAge, age > 15 else { return nil }
        return age
    }
}

struct OverviewUtilityHeader: View {
    var onSearch: () -> Void
    var onRefresh: () -> Void
    @Environment(\.designMetrics) private var metrics

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.compact) {
            Text("")
                .font(Theme.Typography.section)
                .foregroundStyle(Theme.Color.secondary)
            Spacer(minLength: Theme.Space.standard)
            Button(action: onSearch) {
                HStack(spacing: Theme.Space.compact) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                    if metrics.regime != .compact {
                        Text("Search…")
                            .font(Theme.Typography.secondary)
                        Text("⌘K")
                            .font(Theme.Typography.micro)
                            .foregroundStyle(Theme.Color.tertiary)
                    }
                }
                .foregroundStyle(Theme.Color.secondary)
                .padding(.horizontal, Theme.Space.control)
                .padding(.vertical, 7)
                .glass(.recessed, radius: Theme.Radius.control)
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("k", modifiers: .command)
            .focusEffectDisabled()
            .help("Search")
            .accessibilityLabel("Open command palette")

            Button(action: onRefresh) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Color.secondary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .glass(.recessed, radius: Theme.Radius.control)
            .help("Refresh")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum OverviewHeroSlot {
    case identity, machine, cpu, memory, gpu, thermal, pulse
}

private struct OverviewHeroSlotKey: LayoutValueKey {
    static let defaultValue = OverviewHeroSlot.machine
}

private extension View {
    func overviewHeroSlot(_ slot: OverviewHeroSlot) -> some View {
        layoutValue(key: OverviewHeroSlotKey.self, value: slot)
    }
}

private struct OverviewHeroLayout: Layout {
    var spacing: SpacingScale

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        guard let fit = measure(width: width, maxHeight: proposal.height, subviews: subviews) else {
            return CGSize(width: width, height: 0)
        }
        return CGSize(width: width, height: fit.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let fit = measure(width: bounds.width, maxHeight: bounds.height, subviews: subviews) else { return }

        let identityY = bounds.minY
        let machineY = identityY + fit.identityH + spacing.sm
        let pulseY = machineY + fit.machineRowH + spacing.md

        fit.identity.place(
            at: CGPoint(x: bounds.midX - min(fit.identitySize.width, fit.identityWidth) / 2, y: identityY),
            proposal: .init(width: fit.identityWidth, height: fit.identityH)
        )
        fit.machine.place(
            at: CGPoint(x: bounds.midX - fit.machineW / 2, y: machineY),
            proposal: .init(width: fit.machineW, height: fit.machineH)
        )
        fit.pulse.place(
            at: CGPoint(x: bounds.midX - fit.pulseSize.width / 2, y: pulseY),
            proposal: .init(width: fit.pulseSize.width, height: fit.pulseSize.height)
        )

        let cpuX = bounds.minX + 72
        let gpuX = bounds.minX + 46.8
        let memoryX = bounds.maxX - fit.memorySize.width - 72
        let thermalX = bounds.maxX - fit.thermalSize.width - 46.8
        let columnTop = machineY + max((fit.machineRowH - fit.sideColumnH) * 0.5, 0)

        fit.cpu.place(at: CGPoint(x: cpuX, y: columnTop), proposal: .unspecified)
        fit.gpu.place(at: CGPoint(x: gpuX, y: columnTop + fit.cpuSize.height + spacing.md), proposal: .unspecified)
        fit.memory.place(at: CGPoint(x: memoryX, y: columnTop), proposal: .unspecified)
        fit.thermal.place(at: CGPoint(x: thermalX, y: columnTop + fit.memorySize.height + spacing.md), proposal: .unspecified)
    }

    private struct Fit {
        let identity: LayoutSubview
        let machine: LayoutSubview
        let cpu: LayoutSubview
        let memory: LayoutSubview
        let gpu: LayoutSubview
        let thermal: LayoutSubview
        let pulse: LayoutSubview
        let identityWidth: CGFloat
        let identitySize: CGSize
        let pulseSize: CGSize
        let cpuSize: CGSize
        let memorySize: CGSize
        let gpuSize: CGSize
        let thermalSize: CGSize
        let identityH: CGFloat
        let machineH: CGFloat
        let machineW: CGFloat
        let machineRowH: CGFloat
        let sideColumnH: CGFloat
        let height: CGFloat
    }

    private func measure(width: CGFloat, maxHeight: CGFloat?, subviews: Subviews) -> Fit? {
        func item(_ slot: OverviewHeroSlot) -> LayoutSubview? {
            subviews.first { $0[OverviewHeroSlotKey.self] == slot }
        }
        guard
            let identity = item(.identity),
            let machine = item(.machine),
            let cpu = item(.cpu),
            let memory = item(.memory),
            let gpu = item(.gpu),
            let thermal = item(.thermal),
            let pulse = item(.pulse)
        else { return nil }

        let identityWidth = min(max(width * 0.72, 160), max(width, 160))
        let identitySize = identity.sizeThatFits(.init(width: identityWidth, height: nil))
        let pulseWidth = min(max(width * 0.36, 180), max(width * 0.48, 180))
        let pulseSize = pulse.sizeThatFits(.init(width: pulseWidth, height: nil))
        let machineIdeal = machine.sizeThatFits(.unspecified)
        let cpuSize = cpu.sizeThatFits(.unspecified)
        let memorySize = memory.sizeThatFits(.unspecified)
        let gpuSize = gpu.sizeThatFits(.unspecified)
        let thermalSize = thermal.sizeThatFits(.unspecified)
        let sideColumnH = max(
            cpuSize.height + spacing.md + gpuSize.height,
            memorySize.height + spacing.md + thermalSize.height
        )

        let identityH = identitySize.height
        var machineH = machineIdeal.height
        var machineW = machineIdeal.width
        let reserved = identityH + pulseSize.height + spacing.sm + spacing.md
        if let maxHeight {
            let room = max(maxHeight - reserved, 48)
            if machineH > room {
                let scale = machineIdeal.height > 0 ? room / machineIdeal.height : 1
                machineH = room
                machineW = machineIdeal.width * scale
            }
        }

        let machineRowH = max(machineH, sideColumnH)
        var height = identityH + spacing.sm + machineRowH + spacing.md + pulseSize.height
        if let maxHeight, height > maxHeight {
            height = maxHeight
        }

        return Fit(
            identity: identity,
            machine: machine,
            cpu: cpu,
            memory: memory,
            gpu: gpu,
            thermal: thermal,
            pulse: pulse,
            identityWidth: identityWidth,
            identitySize: identitySize,
            pulseSize: pulseSize,
            cpuSize: cpuSize,
            memorySize: memorySize,
            gpuSize: gpuSize,
            thermalSize: thermalSize,
            identityH: identityH,
            machineH: machineH,
            machineW: machineW,
            machineRowH: machineRowH,
            sideColumnH: sideColumnH,
            height: height
        )
    }
}

struct OverviewHero: View {
    let model: OverviewModel
    let snapshot: LiveSnapshot
    var compactWidth: Bool
    var compactHeight: Bool
    var onOpenProfile: (Profile) -> Void
    @Environment(\.designMetrics) private var metrics

    var body: some View {
        OverviewHeroLayout(spacing: metrics.spacing) {
            MachineIdentity(model: model, compact: compactHeight)
                .overviewHeroSlot(.identity)
            MachineVisual(deviceName: model.machineName)
                .overviewHeroSlot(.machine)
                .layoutPriority(1)
            CPUObject(snapshot: snapshot, collecting: model.presentsSampling) {
                onOpenProfile(.performance)
            }
            .overviewHeroSlot(.cpu)
            MemoryObject(snapshot: snapshot, collecting: model.presentsSampling, compact: compactHeight) {
                onOpenProfile(.performance)
            }
            .overviewHeroSlot(.memory)
            GPUObject(snapshot: snapshot) {
                onOpenProfile(.performance)
            }
            .overviewHeroSlot(.gpu)
            ThermalObject(snapshot: snapshot, compact: compactHeight) {
                onOpenProfile(.performance)
            }
            .overviewHeroSlot(.thermal)
            OverviewSystemPulse(
                snapshot: snapshot,
                cpuRatio: cpuRatio,
                action: { onOpenProfile(.performance) }
            )
            .overviewHeroSlot(.pulse)
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var cpuRatio: Double {
        snapshot.series(named: .cpuUtilizationRatio).last?.value ?? model.cpuRatio
    }
}

struct MachineIdentity: View {
    let model: OverviewModel
    var compact: Bool = false
    @Environment(\.designMetrics) private var metrics

    var body: some View {
        VStack(spacing: metrics.spacing.xs) {
            Text(model.machineName)
                .font(.system(size: 28 * metrics.scale, weight: .regular))
                .foregroundStyle(Theme.Color.text)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(model.machineSubtitle)
                .font(metrics.type.secondary)
                .foregroundStyle(Theme.Color.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .tracking(0.4)
            HealthState(model: model, compact: compact)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct HealthState: View {
    let model: OverviewModel
    var compact: Bool = false

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: Theme.Space.compact) {
                Circle()
                    .fill(dot)
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundStyle(dot)
            }
            if !compact {
                Text(subtitle)
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.tertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .fixedSize(horizontal: true, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }

    private var title: String {
        if model.presentsSampling { return "Collecting" }
        if let age = model.sampleAge, age > 15 { return "Health data stale" }
        switch model.health.state {
        case .healthy: return "Healthy"
        case .attention: return "Investigate"
        case .investigate:
            if model.health.detail.contains("pressure") { return "Critical" }
            return "Investigate"
        }
    }

    private var subtitle: String {
        if model.presentsSampling { return "Waiting for the first sample." }
        if let age = model.sampleAge, age > 15 {
            return "Updated \(Int(age))s ago"
        }
        switch model.health.state {
        case .healthy: return "Everything looks good."
        case .attention, .investigate: return model.health.detail
        }
    }

    private var dot: Color {
        if model.presentsSampling { return Theme.Color.tertiary }
        if let age = model.sampleAge, age > 15 { return Theme.Color.warning }
        switch model.health.state {
        case .healthy: return Theme.Color.success
        case .attention: return Theme.Color.warning
        case .investigate:
            if model.health.detail.contains("pressure") { return Theme.Color.critical }
            return Theme.Color.warning
        }
    }
}

struct MachineVisual: View {
    var deviceName: String

    /// Fixed display width: 6 inches at 72pt/inch (2× previous 3-inch size).
    private static let maxWidth: CGFloat = 432

    var body: some View {
        Group {
            if let image = AppImage.macBookHero() {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
            } else {
                Color.clear
                    .frame(maxWidth: Self.maxWidth)
                    .aspectRatio(3 / 2, contentMode: .fit)
                    .overlay {
                        VStack(spacing: Theme.Space.xs) {
                            Text(fallbackName)
                                .font(Theme.Typography.section)
                                .foregroundStyle(Theme.Color.text)
                            Text("Device visual unavailable")
                                .font(Theme.Typography.metadata)
                                .foregroundStyle(Theme.Color.tertiary)
                        }
                        .multilineTextAlignment(.center)
                    }
                    .accessibilityLabel("Device visual unavailable")
            }
        }
        .frame(maxWidth: Self.maxWidth)
    }

    private var fallbackName: String {
        let name = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = name.range(of: "'s ", options: [.backwards, .caseInsensitive]) {
            let suffix = name[range.upperBound...].trimmingCharacters(in: .whitespaces)
            if !suffix.isEmpty { return suffix }
        }
        return name.isEmpty ? "Mac" : name
    }
}

struct CPUObject: View {
    let snapshot: LiveSnapshot
    var collecting: Bool
    var action: () -> Void

    var body: some View {
        let series = snapshot.series(named: .cpuUtilizationRatio)
        let hasValue = series.last != nil || OverviewMetrics.has(snapshot, .cpuUtilizationRatio)
        Button(action: action) {
            HStack(alignment: .center, spacing: Theme.Space.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CPU")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Color.tertiary)
                    Text(hasValue ? OverviewMetrics.percent(series.last?.value ?? OverviewMetrics.ratio(snapshot, .cpuUtilizationRatio) ?? 0) : "—")
                        .font(.system(size: 24, weight: .medium).monospacedDigit())
                        .foregroundStyle(Theme.Color.text)
                        .lineLimit(1)
                    Text(hasValue ? "Host utilization" : "Collecting telemetry")
                        .font(Theme.Typography.micro)
                        .foregroundStyle(Theme.Color.tertiary)
                        .lineLimit(1)
                }
                Sparkline(values: series.map(\.value), height: 28, showsEmptyCaption: false)
                    .frame(width: 72, height: 20)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help(hasValue ? "Open Performance" : "Collecting telemetry")
        .accessibilityLabel(hasValue ? "CPU, \(OverviewMetrics.percent(series.last?.value ?? OverviewMetrics.ratio(snapshot, .cpuUtilizationRatio) ?? 0)), live" : "CPU, collecting")
    }
}

struct MemoryObject: View {
    let snapshot: LiveSnapshot
    var collecting: Bool
    var compact: Bool = false
    var action: () -> Void

    var body: some View {
        let used = OverviewMetrics.numeric(snapshot, .memoryUsedBytes)
        let total = OverviewMetrics.numeric(snapshot, .memoryTotalBytes)
        let hasValue = total > 0
        let ratio = hasValue ? used / total : 0
        let pressure = OverviewMetrics.state(snapshot, .memoryPressureState)
        let series = snapshot.series(named: .memoryUsedBytes)
        Button(action: action) {
            HStack(alignment: .center, spacing: Theme.Space.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Memory")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Color.tertiary)
                    Text(hasValue ? "\(OverviewMetrics.bytes(used)) / \(OverviewMetrics.bytes(total))" : "—")
                        .font(.system(size: 24, weight: .medium).monospacedDigit())
                        .foregroundStyle(Theme.Color.text)
                        .lineLimit(1)
                    if hasValue {
                        if !compact {
                            Text("Pressure: \(pressure?.capitalized ?? "—")")
                                .font(Theme.Typography.micro)
                                .foregroundStyle(Theme.Color.tertiary)
                                .lineLimit(1)
                        } else {
                            Text(OverviewMetrics.percent(ratio))
                                .font(Theme.Typography.micro)
                                .foregroundStyle(Theme.Color.tertiary)
                                .monospacedDigit()
                        }
                    } else {
                        Text("Collecting telemetry")
                            .font(Theme.Typography.micro)
                            .foregroundStyle(Theme.Color.tertiary)
                    }
                }
                if hasValue {
                    VStack(spacing: 4) {
                        MetricBar(ratio: ratio, tint: Theme.Color.accent, height: 5)
                            .frame(width: 72)
                        Sparkline(values: series.map(\.value), height: 20, tint: Theme.Color.accent.opacity(0.78), showsEmptyCaption: false)
                            .frame(width: 72, height: 20)
                    }
                } else {
                    Color.clear.frame(width: 72, height: 28)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help("Open Performance")
        .accessibilityLabel("Memory")
    }
}

struct GPUObject: View {
    let snapshot: LiveSnapshot
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: Theme.Space.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GPU")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Color.text)
                    Text("Not collected")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.Color.tertiary)
                        .lineLimit(1)
                    Text("Unavailable")
                        .font(Theme.Typography.micro)
                        .foregroundStyle(Theme.Color.tertiary)
                }
                Color.clear.frame(width: 72, height: 28)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help("GPU telemetry is not collected in this build")
        .accessibilityLabel("GPU unavailable")
    }
}

struct ThermalObject: View {
    let snapshot: LiveSnapshot
    var compact: Bool = false
    var action: () -> Void

    var body: some View {
        let state = OverviewMetrics.state(snapshot, .thermalState)
        let title: String = {
            switch state?.lowercased() {
            case "fair": return "Elevated"
            case "serious", "critical": return "Critical"
            case "nominal", "normal": return "Nominal"
            case nil: return "—"
            default: return OverviewVisualFill.thermalTitle(state: state)
            }
        }()
        Button(action: action) {
            HStack(alignment: .center, spacing: Theme.Space.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Thermal")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Color.text)
                    HStack(spacing: Theme.Space.compact) {
                        Circle()
                            .fill(tone(state))
                            .frame(width: 7, height: 7)
                        Text(state == nil ? "—" : title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(state == nil ? Theme.Color.tertiary : Theme.Color.secondary)
                            .lineLimit(1)
                    }
                    if state == nil {
                        Text("Collecting telemetry")
                            .font(Theme.Typography.micro)
                            .foregroundStyle(Theme.Color.tertiary)
                    } else if !compact {
                        Text(title)
                            .font(Theme.Typography.micro)
                            .foregroundStyle(Theme.Color.tertiary)
                    }
                }
                Color.clear.frame(width: 72, height: 28)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help("Open Performance")
        .accessibilityLabel("Thermal \(title)")
    }

    private func tone(_ state: String?) -> Color {
        switch state?.lowercased() {
        case "fair": Theme.Color.warning
        case "serious", "critical": Theme.Color.critical
        case "nominal", "normal": Theme.Color.success
        default: Theme.Color.tertiary
        }
    }
}

struct OverviewSystemPulse: View {
    let snapshot: LiveSnapshot
    let cpuRatio: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Space.xs) {
                Text("SYSTEM PULSE")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.secondary)
                    .tracking(1.2)
                Text("Live blend of CPU, memory, disk and network activity")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.secondary)
            }
        }
        .buttonStyle(.plain)
        .help("Open Performance")
        .accessibilityLabel("System pulse, \(OverviewVisualFill.pulseLabel(cpu: cpuRatio))")
    }
}

struct SystemActivityRegion: View {
    let snapshot: LiveSnapshot
    var staleAge: TimeInterval?
    var compact: Bool = false
    @Environment(\.designMetrics) private var metrics

    var body: some View {
        let traces = OverviewActivityTrace.all(from: snapshot)
        let collecting = traces.allSatisfy { $0.points.count < 2 && !$0.unavailable }
        VStack(alignment: .leading, spacing: compact ? metrics.spacing.xs : metrics.spacing.sm) {
            HStack(spacing: Theme.Space.standard) {
                ForEach(traces) { trace in
                    HStack(spacing: 6) {
                        Circle().fill(trace.unavailable ? Theme.Color.tertiary : trace.color).frame(width: 6, height: 6)
                        Text(trace.unavailable ? "\(trace.name)  Unavailable" : trace.name)
                            .font(Theme.Typography.micro)
                            .foregroundStyle(Theme.Color.secondary)
                    }
                }
            }
            OverviewActivityChart(traces: traces, collecting: collecting)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(compact ? metrics.spacing.sm : metrics.spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.secondary, style: .continuous)
                .fill(Color.black.opacity(0.14))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.secondary, style: .continuous)
                .strokeBorder(Color.white.opacity(0.04), lineWidth: 1)
        }
    }
}

struct OverviewActivityTrace: Identifiable {
    let name: String
    let points: [SamplePoint]
    let color: Color
    let unit: MacObserverDomain.Unit
    var unavailable: Bool
    var id: String { name }

    static func all(from snapshot: LiveSnapshot) -> [OverviewActivityTrace] {
        [
            OverviewActivityTrace(
                name: "CPU",
                points: snapshot.series(named: .cpuUtilizationRatio),
                color: Theme.Color.accent,
                unit: .ratio,
                unavailable: false
            ),
            OverviewActivityTrace(
                name: "Memory",
                points: snapshot.series(named: .memoryUsedBytes),
                color: Theme.Color.accent.opacity(0.78),
                unit: .bytes,
                unavailable: false
            ),
            OverviewActivityTrace(
                name: "Disk",
                points: diskPoints(snapshot),
                color: Theme.Color.accent.opacity(0.56),
                unit: .bytesPerSecond,
                unavailable: isUnavailable(snapshot, "standard.storage")
            ),
            OverviewActivityTrace(
                name: "Network",
                points: networkPoints(snapshot),
                color: Theme.Color.accent.opacity(0.38),
                unit: .bytesPerSecond,
                unavailable: isUnavailable(snapshot, "standard.network")
            )
        ]
    }

    private static func isUnavailable(_ snapshot: LiveSnapshot, _ key: String) -> Bool {
        switch snapshot.availability[key] {
        case .unavailable, .denied: true
        default: false
        }
    }

    private static func diskPoints(_ snapshot: LiveSnapshot) -> [SamplePoint] {
        summed(snapshot, [.storageReadBytesPerSecond, .storageWriteBytesPerSecond])
    }

    private static func networkPoints(_ snapshot: LiveSnapshot) -> [SamplePoint] {
        summed(snapshot, [.networkRxBytesPerSecond, .networkTxBytesPerSecond])
    }

    private static func summed(_ snapshot: LiveSnapshot, _ names: [MetricName]) -> [SamplePoint] {
        let tracks = names.map { snapshot.series(named: $0) }.filter { $0.count >= 2 }
        guard let count = tracks.map(\.count).min() else { return [] }
        return (0..<count).map { index in
            let sample = tracks[0][tracks[0].count - count + index]
            let sum = tracks.reduce(0.0) { partial, track in
                partial + track[track.count - count + index].value
            }
            return SamplePoint(time: sample.time, value: sum)
        }
    }
}

struct OverviewActivityChart: View {
    let traces: [OverviewActivityTrace]
    var collecting: Bool
    @State private var hoverX: CGFloat?
    @State private var dragStart: CGFloat?
    @State private var selection: ClosedRange<CGFloat>?

    var body: some View {
        GeometryReader { geo in
            let times = axisTimes
            ZStack(alignment: .topLeading) {
                chart(size: geo.size, times: times)
                if collecting {
                    Text("Collecting system history…")
                        .font(Theme.Typography.metadata)
                        .foregroundStyle(Theme.Color.tertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                if let hoverX, !collecting {
                    readout(at: hoverX, width: geo.size.width)
                        .frame(maxWidth: 220, alignment: .leading)
                        .offset(x: min(max(hoverX - 8, 0), max(geo.size.width - 228, 0)), y: 8)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        hoverX = value.location.x
                        if abs(value.translation.width) > 10 {
                            let start = dragStart ?? (value.location.x - value.translation.width)
                            dragStart = start
                            let a = min(max(start, 0), geo.size.width)
                            let b = min(max(value.location.x, 0), geo.size.width)
                            selection = min(a, b)...max(a, b)
                        }
                    }
                    .onEnded { _ in
                        dragStart = nil
                    }
            )
            .onHover { inside in
                if !inside {
                    hoverX = nil
                }
            }
        }
    }

    private var axisTimes: [Date] {
        traces.flatMap(\.points).map(\.time).sorted()
    }

    @ViewBuilder
    private func chart(size: CGSize, times: [Date]) -> some View {
        let plotHeight = max(size.height - 22, 40)
        Canvas { context, canvasSize in
            let plot = CGSize(width: canvasSize.width, height: plotHeight)
            if let selection {
                let rect = Path(
                    CGRect(
                        x: selection.lowerBound,
                        y: 0,
                        width: max(selection.upperBound - selection.lowerBound, 1),
                        height: plot.height
                    )
                )
                context.fill(rect, with: .color(Theme.Color.accent.opacity(0.10)))
            }
            if let hoverX {
                var line = Path()
                line.move(to: CGPoint(x: hoverX, y: 0))
                line.addLine(to: CGPoint(x: hoverX, y: plot.height))
                context.stroke(line, with: .color(Color.white.opacity(0.22)), lineWidth: 1)
            }
            for trace in traces where !trace.unavailable && trace.points.count >= 2 {
                draw(trace, in: plot, context: context)
            }
        }
        .frame(height: plotHeight)
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottom) {
            timeAxis(times: times, width: size.width)
        }
    }

    private func draw(_ trace: OverviewActivityTrace, in size: CGSize, context: GraphicsContext) {
        let values = trace.points.map(\.value)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let span = max(maxValue - minValue, 0.0001)
        let points: [CGPoint] = values.enumerated().map { index, value in
            CGPoint(
                x: size.width * CGFloat(index) / CGFloat(values.count - 1),
                y: size.height - CGFloat((value - minValue) / span) * size.height * 0.92
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
        }
        fill.addLine(to: CGPoint(x: points.last?.x ?? 0, y: size.height))
        fill.closeSubpath()
        context.fill(fill, with: .color(trace.color.opacity(0.10)))
        context.stroke(line, with: .color(trace.color.opacity(0.85)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
    }

    private func timeAxis(times: [Date], width: CGFloat) -> some View {
        let marks = axisMarks(times)
        return HStack {
            ForEach(Array(marks.enumerated()), id: \.offset) { index, date in
                if index > 0 { Spacer(minLength: 0) }
                Text(date.formatted(date: .omitted, time: .shortened))
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.tertiary)
            }
        }
        .frame(width: width)
        .padding(.top, 4)
    }

    private func axisMarks(_ times: [Date]) -> [Date] {
        guard let first = times.first, let last = times.last, first != last else {
            return times.last.map { [$0] } ?? []
        }
        let count = 5
        return (0..<count).map { index in
            let t = Double(index) / Double(count - 1)
            return first.addingTimeInterval(last.timeIntervalSince(first) * t)
        }
    }

    @ViewBuilder
    private func readout(at x: CGFloat, width: CGFloat) -> some View {
        let fraction = width > 0 ? min(max(x / width, 0), 1) : 0
        VStack(alignment: .leading, spacing: 4) {
            if let time = sampleTime(fraction: fraction) {
                Text(time.formatted(date: .omitted, time: .standard))
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.secondary)
            }
            ForEach(traces) { trace in
                HStack {
                    Text(trace.name)
                        .foregroundStyle(Theme.Color.tertiary)
                    Spacer(minLength: 8)
                    Text(sampleValue(trace, fraction: fraction))
                        .monospacedDigit()
                        .foregroundStyle(Theme.Color.text)
                }
                .font(Theme.Typography.micro)
            }
            if let summary = selectionSummary(width: width) {
                Text(summary)
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.secondary)
            }
        }
        .padding(Theme.Space.compact)
        .glass(.floating, radius: Theme.Radius.control)
    }

    private func sampleTime(fraction: CGFloat) -> Date? {
        guard let points = traces.first(where: { $0.points.count >= 2 })?.points else { return nil }
        let index = Int((fraction * CGFloat(points.count - 1)).rounded())
        return points[min(max(index, 0), points.count - 1)].time
    }

    private func sampleValue(_ trace: OverviewActivityTrace, fraction: CGFloat) -> String {
        if trace.unavailable { return "Unavailable" }
        guard trace.points.count >= 2 else { return "—" }
        let index = Int((fraction * CGFloat(trace.points.count - 1)).rounded())
        let value = trace.points[min(max(index, 0), trace.points.count - 1)].value
        return format(value, unit: trace.unit)
    }

    private func selectionSummary(width: CGFloat) -> String? {
        guard let selection, width > 0 else { return nil }
        guard let start = sampleTime(fraction: selection.lowerBound / width),
              let end = sampleTime(fraction: selection.upperBound / width) else { return nil }
        let duration = max(end.timeIntervalSince(start), 0)
        return "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened)) · \(Int(duration))s"
    }

    private func format(_ value: Double, unit: MacObserverDomain.Unit) -> String {
        switch unit {
        case .ratio: OverviewMetrics.percent(value)
        case .bytes: OverviewMetrics.bytes(value)
        case .bytesPerSecond: OverviewMetrics.rate(value)
        default: String(format: "%.1f", value)
        }
    }
}

struct OverviewBottomSection: View {
    let snapshot: LiveSnapshot
    var staleAge: TimeInterval? = nil
    var compact: Bool = false
    var compactWidth: Bool = false
    var onOpenProcess: (OverviewProcessRow) -> Void
    var onOpenProfile: (Profile) -> Void
    @Environment(\.designMetrics) private var metrics

    var body: some View {
        OverviewBottomLayout(
            compact: compactWidth || compact,
            groupSpacing: metrics.spacing.xl,
            processWeight: 0.65,
            resourceWeight: 0.35
        ) {
            TopProcesses(
                snapshot: snapshot,
                staleAge: staleAge,
                limit: compact ? 4 : 5,
                showMemory: !compact && !compactWidth,
                onOpenProcess: onOpenProcess
            )
            SystemResources(
                snapshot: snapshot,
                compact: compact,
                onOpenProfile: onOpenProfile
            )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct OverviewBottomLayout: Layout {
    var compact: Bool
    var groupSpacing: CGFloat
    var processWeight: CGFloat
    var resourceWeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        guard let fit = measure(width: width, maxHeight: proposal.height, subviews: subviews) else {
            return CGSize(width: width, height: 0)
        }
        return CGSize(width: width, height: fit.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let fit = measure(width: bounds.width, maxHeight: bounds.height, subviews: subviews) else { return }
        if fit.stack {
            fit.processes.place(
                at: bounds.origin,
                proposal: .init(width: bounds.width, height: fit.processSize.height)
            )
            fit.resources.place(
                at: CGPoint(x: bounds.minX, y: bounds.minY + fit.processSize.height + groupSpacing),
                proposal: .init(width: bounds.width, height: fit.resourceSize.height)
            )
            return
        }
        fit.processes.place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            proposal: .init(width: fit.processW, height: fit.processSize.height)
        )
        fit.resources.place(
            at: CGPoint(x: bounds.maxX - fit.resourceW, y: bounds.minY),
            proposal: .init(width: fit.resourceW, height: fit.resourceSize.height)
        )
    }

    private struct Fit {
        let processes: LayoutSubview
        let resources: LayoutSubview
        let stack: Bool
        let processW: CGFloat
        let resourceW: CGFloat
        let processSize: CGSize
        let resourceSize: CGSize
        let height: CGFloat
    }

    private func measure(width: CGFloat, maxHeight: CGFloat?, subviews: Subviews) -> Fit? {
        guard subviews.count == 2 else { return nil }
        let processes = subviews[0]
        let resources = subviews[1]
        let stack = compact && width < 720
        let processW: CGFloat
        let resourceW: CGFloat
        if stack {
            processW = width
            resourceW = width
        } else {
            let available = max(width - groupSpacing, 1)
            let resourcePreferred = resources.sizeThatFits(.init(width: available * 0.40, height: nil))
            resourceW = min(max(resourcePreferred.width, available * 0.33), available * 0.38)
            processW = max(available - resourceW, available * 0.62)
        }
        let processSize = processes.sizeThatFits(.init(width: processW, height: nil))
        let resourceSize = resources.sizeThatFits(.init(width: resourceW, height: nil))
        var height = stack
            ? processSize.height + groupSpacing + resourceSize.height
            : max(processSize.height, resourceSize.height)
        if let maxHeight, height > maxHeight {
            height = maxHeight
        }
        return Fit(
            processes: processes,
            resources: resources,
            stack: stack,
            processW: processW,
            resourceW: resourceW,
            processSize: processSize,
            resourceSize: resourceSize,
            height: height
        )
    }
}

struct TopProcesses: View {
    let snapshot: LiveSnapshot
    var staleAge: TimeInterval? = nil
    var limit: Int = 5
    var showMemory: Bool = true
    var onOpenProcess: (OverviewProcessRow) -> Void
    @Environment(\.designMetrics) private var metrics

    var body: some View {
        let unavailable = isUnavailable
        let collecting = isCollecting
        let processes = displayedProcesses
        let peak = max(processes.map(\.cpuRatio).max() ?? 0, 0.01)
        VStack(alignment: .leading, spacing: metrics.spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.compact) {
                Text("Top Processes")
                    .font(Theme.Typography.section)
                    .foregroundStyle(Theme.Color.text)
                if let staleAge {
                    Text("Updated \(Int(staleAge))s ago")
                        .font(Theme.Typography.micro)
                        .foregroundStyle(Theme.Color.tertiary)
                }
            }
            if unavailable {
                Text("Process telemetry unavailable")
                    .font(Theme.Typography.metadata)
                    .foregroundStyle(Theme.Color.tertiary)
            } else if collecting {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    ForEach(0..<limit, id: \.self) { _ in
                        ProcessRowSkeleton(showMemory: showMemory)
                    }
                }
            } else if processes.isEmpty {
                Text("No notable activity")
                    .font(Theme.Typography.metadata)
                    .foregroundStyle(Theme.Color.tertiary)
            } else {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    ForEach(processes) { process in
                        Button {
                            onOpenProcess(process)
                        } label: {
                            OverviewProcessRowView(
                                process: process,
                                relativeRatio: process.cpuRatio / peak,
                                showMemory: showMemory
                            )
                        }
                        .buttonStyle(.plain)
                        .help(processHelp(process))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var displayedProcesses: [OverviewProcessRow] {
        OverviewModel.processRows(from: snapshot, limit: limit * 2, pad: false)
            .filter { $0.pid != 0 && $0.cpuRatio > 0.004 }
            .sorted { lhs, rhs in
                if abs(lhs.cpuRatio - rhs.cpuRatio) > 0.0005 {
                    return lhs.cpuRatio > rhs.cpuRatio
                }
                if lhs.name != rhs.name { return lhs.name < rhs.name }
                return lhs.pid < rhs.pid
            }
            .prefix(limit)
            .map { $0 }
    }

    private var isUnavailable: Bool {
        switch snapshot.availability["standard.processes"] {
        case .unavailable, .denied: true
        default: false
        }
    }

    private var isCollecting: Bool {
        guard !isUnavailable else { return false }
        return !snapshot.metrics.contains { metric in
            guard metric.name == .cpuUtilizationRatio else { return false }
            if case .processInstance = metric.entity { return true }
            return false
        }
    }

    private func processHelp(_ process: OverviewProcessRow) -> String {
        var parts = [
            ProcessDisplay.name(pid: process.pid, fallback: process.name),
            "PID \(process.pid)",
            "CPU \(process.cpu)"
        ]
        if !process.memory.isEmpty {
            parts.append("Memory \(process.memory)")
        }
        return parts.joined(separator: " · ")
    }
}

struct OverviewProcessRowView: View {
    let process: OverviewProcessRow
    var relativeRatio: Double
    var showMemory: Bool = true

    var body: some View {
        HStack(spacing: Theme.Space.control) {
            ProcessGlyph(pid: process.pid, name: process.name, size: 18)
            Text(ProcessDisplay.name(pid: process.pid, fallback: process.name))
                .font(Theme.Typography.secondary)
                .foregroundStyle(Theme.Color.text)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: 64, maxWidth: 128, alignment: .leading)
            MetricBar(ratio: relativeRatio, tint: Theme.Color.accent, height: 5)
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 0.18), value: relativeRatio)
            Text(process.cpu)
                .font(Theme.Typography.secondary)
                .monospacedDigit()
                .foregroundStyle(Theme.Color.secondary)
                .frame(minWidth: 36, alignment: .trailing)
                .fixedSize()
            if showMemory, !process.memory.isEmpty {
                Text(process.memory)
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.tertiary)
                    .lineLimit(1)
                    .frame(minWidth: 44, alignment: .trailing)
                    .fixedSize()
            }
        }
        .frame(height: 28, alignment: .center)
        .contentShape(Rectangle())
        .accessibilityLabel("\(process.name), CPU \(process.cpu)")
    }
}

private struct ProcessRowSkeleton: View {
    var showMemory: Bool

    var body: some View {
        HStack(spacing: Theme.Space.control) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Theme.Color.track)
                .frame(width: 18, height: 18)
            Capsule()
                .fill(Theme.Color.track)
                .frame(width: 92, height: 8)
            Capsule()
                .fill(Theme.Color.track)
                .frame(maxWidth: .infinity)
                .frame(height: 5)
            Capsule()
                .fill(Theme.Color.track)
                .frame(width: 28, height: 8)
            if showMemory {
                Capsule()
                    .fill(Theme.Color.track)
                    .frame(width: 36, height: 8)
            }
        }
        .frame(height: 28, alignment: .center)
        .accessibilityHidden(true)
    }
}

struct SystemResources: View {
    let snapshot: LiveSnapshot
    var compact: Bool = false
    var onOpenProfile: (Profile) -> Void
    @Environment(\.designMetrics) private var metrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.spacing.sm) {
            Text("System Resources")
                .font(Theme.Typography.section)
                .foregroundStyle(Theme.Color.text)
            SystemResourceLayout(spacing: metrics.spacing.md) {
                StorageSummary(snapshot: snapshot, compact: compact, action: { onOpenProfile(.storage) })
                NetworkSummary(snapshot: snapshot, compact: compact, action: { onOpenProfile(.network) })
                BatterySummary(snapshot: snapshot, compact: compact, action: { onOpenProfile(.power) })
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct SystemResourceLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else {
            return CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
        }
        let width = proposal.width ?? 0
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rowWidth = sizes.map(\.width).reduce(0, +) + spacing * CGFloat(max(subviews.count - 1, 0))
        if width <= 0 || rowWidth <= width {
            let height = sizes.map(\.height).max() ?? 0
            return CGSize(width: width > 0 ? width : rowWidth, height: height)
        }
        let first = sizes.prefix(2)
        let firstHeight = first.map(\.height).max() ?? 0
        let batteryHeight = sizes.last?.height ?? 0
        return CGSize(width: width, height: firstHeight + spacing + batteryHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rowWidth = sizes.map(\.width).reduce(0, +) + spacing * CGFloat(max(subviews.count - 1, 0))
        if rowWidth <= bounds.width {
            var x = bounds.minX
            for index in subviews.indices {
                let size = sizes[index]
                subviews[index].place(
                    at: CGPoint(x: x, y: bounds.minY),
                    proposal: .init(width: size.width, height: size.height)
                )
                x += size.width + spacing
            }
            return
        }
        var x = bounds.minX
        let pair = min(2, subviews.count)
        let pairHeight = sizes.prefix(pair).map(\.height).max() ?? 0
        for index in 0..<pair {
            let size = sizes[index]
            subviews[index].place(
                at: CGPoint(x: x, y: bounds.minY),
                proposal: .init(width: size.width, height: size.height)
            )
            x += size.width + spacing
        }
        if subviews.count > 2 {
            let size = sizes[2]
            subviews[2].place(
                at: CGPoint(x: bounds.minX, y: bounds.minY + pairHeight + spacing),
                proposal: .init(width: size.width, height: size.height)
            )
        }
    }
}

struct StorageSummary: View {
    let snapshot: LiveSnapshot
    var compact: Bool = false
    var action: () -> Void

    var body: some View {
        let capacity = OverviewMetrics.numeric(snapshot, .storageCapacityBytes)
        let available = OverviewMetrics.numeric(snapshot, .storageAvailableBytes)
        let used = max(0, capacity - available)
        let ratio = capacity > 0 ? used / capacity : 0
        let freeRatio = capacity > 0 ? available / capacity : 1
        let unavailable = capacity <= 0 || OverviewMetrics.isUnavailable(snapshot, "standard.storage")
        let tint: Color = {
            if freeRatio < 0.05 { return Theme.Color.critical }
            if freeRatio < 0.15 { return Theme.Color.warning }
            return Theme.Color.accent
        }()
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("Storage")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.tertiary)
                if unavailable {
                    Text("Unavailable")
                        .font(Theme.Typography.secondary)
                        .foregroundStyle(Theme.Color.tertiary)
                } else {
                    Text("\(OverviewMetrics.bytes(available)) free")
                        .font(Theme.Typography.section)
                        .foregroundStyle(freeRatio < 0.15 ? tint : Theme.Color.text)
                    if !compact {
                        Text("of \(OverviewMetrics.bytes(capacity))")
                            .font(Theme.Typography.micro)
                            .foregroundStyle(Theme.Color.tertiary)
                    }
                    MetricBar(ratio: ratio, tint: tint, height: 4)
                        .frame(width: 88)
                }
            }
            .frame(minWidth: 88, alignment: .leading)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help("Open Storage")
    }
}

struct NetworkSummary: View {
    let snapshot: LiveSnapshot
    var compact: Bool = false
    var action: () -> Void

    var body: some View {
        let unavailable = OverviewMetrics.isUnavailable(snapshot, "standard.network")
        let rx = snapshot.metrics
            .filter { $0.name == .networkRxBytesPerSecond }
            .reduce(0.0) { $0 + OverviewMetrics.numericValue($1) }
        let tx = snapshot.metrics
            .filter { $0.name == .networkTxBytesPerSecond }
            .reduce(0.0) { $0 + OverviewMetrics.numericValue($1) }
        let hasSamples = snapshot.metrics.contains {
            $0.name == .networkRxBytesPerSecond || $0.name == .networkTxBytesPerSecond
        }
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("Network")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.tertiary)
                if unavailable {
                    Text("Unavailable")
                        .font(Theme.Typography.secondary)
                        .foregroundStyle(Theme.Color.tertiary)
                } else if !hasSamples {
                    Text("↓ —")
                        .font(Theme.Typography.secondary)
                        .foregroundStyle(Theme.Color.tertiary)
                        .monospacedDigit()
                    Text("↑ —")
                        .font(Theme.Typography.secondary)
                        .foregroundStyle(Theme.Color.tertiary)
                        .monospacedDigit()
                } else {
                    Text("↓ \(OverviewMetrics.rate(rx))")
                        .font(Theme.Typography.secondary)
                        .foregroundStyle(Theme.Color.text)
                        .monospacedDigit()
                    Text("↑ \(OverviewMetrics.rate(tx))")
                        .font(Theme.Typography.secondary)
                        .foregroundStyle(Theme.Color.text)
                        .monospacedDigit()
                }
            }
            .frame(minWidth: 84, alignment: .leading)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help("Open Network")
    }
}

struct BatterySummary: View {
    let snapshot: LiveSnapshot
    var compact: Bool = false
    var action: () -> Void

    var body: some View {
        let ratio = OverviewMetrics.ratio(snapshot, .powerBatteryChargeRatio)
        let charging = OverviewMetrics.stateFlag(snapshot, .powerBatteryCharging) == true
        let empty = OverviewMetrics.intValue(snapshot, .powerTimeToEmptyMinutes)
        let full = OverviewMetrics.intValue(snapshot, .powerTimeToFullMinutes)
        let fullyCharged = (ratio ?? 0) >= 0.995
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("Battery")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.tertiary)
                if let ratio {
                    Text(OverviewMetrics.percent(ratio))
                        .font(Theme.Typography.section)
                        .foregroundStyle(Theme.Color.text)
                        .monospacedDigit()
                    MetricBar(ratio: ratio, tint: Theme.Color.accent, height: 4)
                        .frame(width: 72)
                    if !compact {
                        if fullyCharged {
                            Text("Fully charged")
                                .font(Theme.Typography.micro)
                                .foregroundStyle(Theme.Color.tertiary)
                        } else if charging {
                            if let copy = OverviewVisualFill.remainingCopy(minutes: full, charging: true) {
                                Text(copy)
                                    .font(Theme.Typography.micro)
                                    .foregroundStyle(Theme.Color.tertiary)
                                    .lineLimit(1)
                            } else {
                                Text("Charging")
                                    .font(Theme.Typography.micro)
                                    .foregroundStyle(Theme.Color.tertiary)
                            }
                        } else if let copy = OverviewVisualFill.remainingCopy(minutes: empty, charging: false) {
                            Text(copy)
                                .font(Theme.Typography.micro)
                                .foregroundStyle(Theme.Color.tertiary)
                                .lineLimit(1)
                        }
                    } else if charging && !fullyCharged {
                        Text("Charging")
                            .font(Theme.Typography.micro)
                            .foregroundStyle(Theme.Color.tertiary)
                    }
                } else {
                    Text("Unavailable")
                        .font(Theme.Typography.secondary)
                        .foregroundStyle(Theme.Color.tertiary)
                }
            }
            .frame(minWidth: 72, alignment: .leading)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help("Open Power")
    }
}

enum OverviewMetrics {
    static func numeric(_ snapshot: LiveSnapshot, _ name: MetricName) -> Double {
        guard let metric = snapshot.metrics.first(where: { $0.name == name }) else { return 0 }
        return numericValue(metric)
    }

    static func numericValue(_ metric: Metric) -> Double {
        switch metric.value {
        case .int(let value): Double(value)
        case .double(let value): value
        case .ratio(let value): value
        default: 0
        }
    }

    static func ratio(_ snapshot: LiveSnapshot, _ name: MetricName) -> Double? {
        guard let metric = snapshot.metrics.first(where: { $0.name == name }) else { return nil }
        if case .ratio(let value) = metric.value { return value }
        return nil
    }

    static func has(_ snapshot: LiveSnapshot, _ name: MetricName) -> Bool {
        snapshot.metrics.contains { $0.name == name }
    }

    static func state(_ snapshot: LiveSnapshot, _ name: MetricName) -> String? {
        snapshot.metrics.first { $0.name == name }.flatMap { metric in
            if case .state(let value) = metric.value { return value }
            return nil
        }
    }

    static func stateFlag(_ snapshot: LiveSnapshot, _ name: MetricName) -> Bool? {
        guard let metric = snapshot.metrics.first(where: { $0.name == name }) else { return nil }
        switch metric.value {
        case .state(let value):
            return value == "true" || value == "1" || value.lowercased() == "charging"
        case .int(let value):
            return value != 0
        default:
            return nil
        }
    }

    static func intValue(_ snapshot: LiveSnapshot, _ name: MetricName) -> Int? {
        guard let metric = snapshot.metrics.first(where: { $0.name == name }) else { return nil }
        if case .int(let value) = metric.value { return Int(value) }
        if case .double(let value) = metric.value { return Int(value) }
        return nil
    }

    static func isUnavailable(_ snapshot: LiveSnapshot, _ key: String) -> Bool {
        switch snapshot.availability[key] {
        case .unavailable, .denied: true
        default: false
        }
    }

    static func percent(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }

    static func bytes(_ value: Double) -> String {
        MetricFormatter.displayString(value: value, unit: .bytes)
    }

    static func rate(_ value: Double) -> String {
        MetricFormatter.displayString(value: value, unit: .bytesPerSecond)
    }
}
