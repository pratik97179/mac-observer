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
        let innerHeight = max(availableSize.height - metrics.spacing.md - metrics.bottomInset, 1)
        let innerWidth = min(max(availableSize.width - metrics.horizontalInset * 2, 1), metrics.contentMaxWidth)
        let compactHeight = innerHeight < 780
        let compactWidth = metrics.regime == .compact || innerWidth < 820
        OverviewCompositionLayout(spacing: metrics.spacing, compactHeight: compactHeight) {
            OverviewUtilityHeader(onSearch: onSearch, onRefresh: onRefresh)
                .overviewBand(.header)
            OverviewHero(
                model: model,
                snapshot: snapshot,
                compactWidth: compactWidth,
                compactHeight: compactHeight,
                onOpenProfile: onOpenProfile
            )
            .overviewBand(.hero)
            SystemActivityRegion(
                snapshot: snapshot,
                staleAge: staleAge,
                compact: compactHeight
            )
            .overviewBand(.activity)
            OverviewBottomRegion(
                snapshot: snapshot,
                compact: compactHeight,
                compactWidth: compactWidth,
                onOpenProcess: onOpenProcess,
                onOpenProfile: onOpenProfile
            )
            .overviewBand(.bottom)
        }
        .padding(.top, metrics.spacing.md)
        .padding(.bottom, metrics.bottomInset)
        .padding(.horizontal, metrics.horizontalInset)
        .frame(width: availableSize.width, height: availableSize.height, alignment: .top)
        .animation(.easeInOut(duration: 0.28), value: compactWidth)
        .animation(.easeInOut(duration: 0.28), value: compactHeight)
    }

    private var staleAge: TimeInterval? {
        guard let age = model.sampleAge, age > 15 else { return nil }
        return age
    }
}

private enum OverviewBand {
    case header, hero, activity, bottom
}

private struct OverviewBandKey: LayoutValueKey {
    static let defaultValue = OverviewBand.hero
}

private extension View {
    func overviewBand(_ band: OverviewBand) -> some View {
        layoutValue(key: OverviewBandKey.self, value: band)
    }
}

private struct OverviewCompositionLayout: Layout {
    var spacing: SpacingScale
    var compactHeight: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        func item(_ band: OverviewBand) -> LayoutSubview? {
            subviews.first { $0[OverviewBandKey.self] == band }
        }
        guard
            let header = item(.header),
            let hero = item(.hero),
            let activity = item(.activity),
            let bottom = item(.bottom)
        else { return }

        let headerFit = header.sizeThatFits(.init(width: bounds.width, height: nil))
        let headerH = min(max(headerFit.height, bounds.height * 0.05), bounds.height * 0.09)

        let bottomCap = bounds.height * (compactHeight ? 0.17 : 0.22)
        let bottomFit = bottom.sizeThatFits(.init(width: bounds.width, height: bottomCap))
        let bottomMin = min(compactHeight ? 96 as CGFloat : 120, bottomCap)
        let bottomH = min(max(bottomFit.height, bottomMin), bottomCap)

        let rest = max(bounds.height - headerH - bottomH - spacing.xs - spacing.sm - spacing.md, 1)
        var heroH = rest * (compactHeight ? 0.58 : 0.41 / 0.74)
        var activityH = rest - heroH
        let activityMin: CGFloat = compactHeight ? 96 : 120
        if activityH < activityMin {
            activityH = min(activityMin, rest * 0.38)
            heroH = rest - activityH
        }

        var y = bounds.minY
        header.place(at: CGPoint(x: bounds.minX, y: y), proposal: .init(width: bounds.width, height: headerH))
        y += headerH + spacing.xs
        hero.place(at: CGPoint(x: bounds.minX, y: y), proposal: .init(width: bounds.width, height: heroH))
        y += heroH + spacing.sm
        activity.place(at: CGPoint(x: bounds.minX, y: y), proposal: .init(width: bounds.width, height: activityH))
        y += activityH + spacing.md
        bottom.place(at: CGPoint(x: bounds.minX, y: y), proposal: .init(width: bounds.width, height: bottomH))
    }
}

struct OverviewUtilityHeader: View {
    var onSearch: () -> Void
    var onRefresh: () -> Void
    @Environment(\.designMetrics) private var metrics

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.compact) {
            Text("Overview")
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
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Color.secondary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .glass(.recessed, radius: Theme.Radius.control)
            .help("Refresh")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
    var compact: Bool
    var spacing: SpacingScale

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
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
        else { return }

        func fit(_ view: LayoutSubview, in box: CGSize) -> CGSize {
            let proposed = view.sizeThatFits(.init(width: box.width, height: box.height))
            return CGSize(
                width: min(max(proposed.width, 1), max(box.width, 1)),
                height: min(max(proposed.height, 1), max(box.height, 1))
            )
        }

        let identityWidth = min(max(bounds.width * 0.72, 160), bounds.width)
        let identitySize = identity.sizeThatFits(.init(width: identityWidth, height: nil))
        let identityH = min(identitySize.height, bounds.height * 0.30)
        identity.place(
            at: CGPoint(x: bounds.midX - min(identitySize.width, identityWidth) / 2, y: bounds.minY),
            proposal: .init(width: identityWidth, height: identityH)
        )

        let pulseWidth = min(max(bounds.width * 0.36, 180), bounds.width * 0.48)
        let pulseSize = pulse.sizeThatFits(.init(width: pulseWidth, height: nil))
        let pulseY = bounds.maxY - pulseSize.height
        pulse.place(
            at: CGPoint(x: bounds.midX - pulseSize.width / 2, y: pulseY),
            proposal: .init(width: pulseSize.width, height: pulseSize.height)
        )

        let clearance = max(spacing.md, bounds.width * 0.02)
        let stageTop = bounds.minY + identityH + spacing.sm
        let stageBottom = pulseY - spacing.md
        let stageHeight = max(stageBottom - stageTop, 1)
        let cpuSize = cpu.sizeThatFits(.unspecified)
        let memorySize = memory.sizeThatFits(.unspecified)
        let gpuSize = gpu.sizeThatFits(.unspecified)
        let thermalSize = thermal.sizeThatFits(.unspecified)
        let leftRail = min(max(max(cpuSize.width, gpuSize.width), 88), bounds.width * 0.26)
        let rightRail = min(max(max(memorySize.width, thermalSize.width), 96), bounds.width * 0.30)
        let pairGap = spacing.xs
        let widthFits = bounds.width >= leftRail + rightRail + 140 + clearance * 2
        let heightFits = stageHeight >= max(
            cpuSize.height + gpuSize.height + pairGap,
            memorySize.height + thermalSize.height + pairGap
        )
        let stacked = compact || !widthFits || !heightFits

        if stacked {
            let row1 = max(cpuSize.height, memorySize.height)
            let row2 = max(gpuSize.height, thermalSize.height)
            let telemetryHeight = row1 + spacing.sm + row2
            let machineBudget = max(stageHeight - telemetryHeight - spacing.sm, 72)
            let machineSize = fit(
                machine,
                in: CGSize(
                    width: min(bounds.width * 0.64, machineBudget * AppImage.macBookHeroAspect),
                    height: machineBudget
                )
            )
            let telemetryY = stageTop + machineSize.height + spacing.sm
            cpu.place(at: CGPoint(x: bounds.minX, y: telemetryY), proposal: .unspecified)
            memory.place(
                at: CGPoint(x: bounds.maxX - memorySize.width, y: telemetryY),
                proposal: .unspecified
            )
            gpu.place(
                at: CGPoint(x: bounds.minX, y: telemetryY + row1 + spacing.sm),
                proposal: .unspecified
            )
            thermal.place(
                at: CGPoint(x: bounds.maxX - thermalSize.width, y: telemetryY + row1 + spacing.sm),
                proposal: .unspecified
            )
            machine.place(
                at: CGPoint(x: bounds.midX - machineSize.width / 2, y: stageTop),
                proposal: .init(width: machineSize.width, height: machineSize.height)
            )
            return
        }

        let centerWidth = max(bounds.width - leftRail - rightRail - clearance * 2, 120)
        let machineSize = fit(machine, in: CGSize(width: centerWidth, height: stageHeight))
        let machineX = bounds.midX - machineSize.width / 2
        let machineY = stageTop + max((stageHeight - machineSize.height) * 0.10, 0)
        let cpuX = max(bounds.minX, machineX - clearance - cpuSize.width)
        let memoryX = min(bounds.maxX - memorySize.width, machineX + machineSize.width + clearance)
        var cpuY = machineY
        var gpuY = machineY + machineSize.height - gpuSize.height
        if gpuY < cpuY + cpuSize.height + pairGap {
            cpuY = stageTop
            gpuY = stageTop + stageHeight - gpuSize.height
        }
        var thermalY = machineY + machineSize.height - thermalSize.height
        var memoryY = machineY
        if thermalY < memoryY + memorySize.height + pairGap {
            memoryY = stageTop
            thermalY = stageTop + stageHeight - thermalSize.height
        }
        cpu.place(at: CGPoint(x: cpuX, y: cpuY), proposal: .unspecified)
        memory.place(at: CGPoint(x: memoryX, y: memoryY), proposal: .unspecified)
        gpu.place(at: CGPoint(x: cpuX, y: gpuY), proposal: .unspecified)
        thermal.place(at: CGPoint(x: memoryX, y: thermalY), proposal: .unspecified)
        machine.place(
            at: CGPoint(x: machineX, y: machineY),
            proposal: .init(width: machineSize.width, height: machineSize.height)
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
        OverviewHeroLayout(compact: compactWidth, spacing: metrics.spacing) {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .font(metrics.type.heroTitle)
                .foregroundStyle(Theme.Color.text)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(model.machineSubtitle)
                .font(metrics.type.secondary)
                .foregroundStyle(Theme.Color.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
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
                    .foregroundStyle(Theme.Color.text)
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

    var body: some View {
        Group {
            if let image = AppImage.macBookHero() {
                image
                    .resizable()
                    .scaledToFit()
                    .aspectRatio(AppImage.macBookHeroAspect, contentMode: .fit)
                    .shadow(color: Color.black.opacity(0.10), radius: 8, y: 5)
                    .accessibilityLabel(deviceName)
            } else {
                Color.clear
                    .aspectRatio(AppImage.macBookHeroAspect, contentMode: .fit)
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
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("CPU")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.tertiary)
                Text(hasValue ? OverviewMetrics.percent(series.last?.value ?? OverviewMetrics.ratio(snapshot, .cpuUtilizationRatio) ?? 0) : "—")
                    .font(Theme.Typography.largeMetric)
                    .foregroundStyle(hasValue ? Theme.Color.text : Theme.Color.tertiary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Sparkline(values: series.map(\.value), height: 22, tint: Theme.Color.accent, showsEmptyCaption: false)
                    .frame(width: 96, height: 22)
                Text(hasValue ? "Host utilization" : (collecting ? "Collecting telemetry" : "Collecting telemetry"))
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.tertiary)
                    .lineLimit(1)
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
        let swap = OverviewMetrics.numeric(snapshot, .memorySwapUsedBytes)
        let series = snapshot.series(named: .memoryUsedBytes)
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("Memory")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.tertiary)
                Text(hasValue ? "\(OverviewMetrics.bytes(used)) / \(OverviewMetrics.bytes(total))" : "—")
                    .font(Theme.Typography.largeMetric)
                    .foregroundStyle(hasValue ? Theme.Color.text : Theme.Color.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .monospacedDigit()
                if hasValue {
                    MetricBar(ratio: ratio, tint: Theme.Color.accent, height: 5)
                        .frame(width: 120)
                    Text(OverviewMetrics.percent(ratio))
                        .font(Theme.Typography.micro)
                        .foregroundStyle(Theme.Color.secondary)
                        .monospacedDigit()
                    Sparkline(values: series.map(\.value), height: 16, tint: Theme.Color.accent.opacity(0.78), showsEmptyCaption: false)
                        .frame(width: 120, height: 16)
                    if !compact {
                        Text("Pressure: \(pressure?.capitalized ?? "—")")
                            .font(Theme.Typography.micro)
                            .foregroundStyle(Theme.Color.tertiary)
                        if swap > 0 {
                            Text("Swap \(OverviewMetrics.bytes(swap))")
                                .font(Theme.Typography.micro)
                                .foregroundStyle(Theme.Color.tertiary)
                        }
                    }
                } else {
                    Text(collecting ? "Collecting telemetry" : "Collecting telemetry")
                        .font(Theme.Typography.micro)
                        .foregroundStyle(Theme.Color.tertiary)
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
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("GPU")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.tertiary)
                Text("Not collected")
                    .font(Theme.Typography.largeMetric)
                    .foregroundStyle(Theme.Color.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Unavailable")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.tertiary)
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
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("Thermal")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.tertiary)
                HStack(spacing: Theme.Space.compact) {
                    Circle()
                        .fill(tone(state))
                        .frame(width: 7, height: 7)
                    Text(state == nil ? "—" : title)
                        .font(Theme.Typography.largeMetric)
                        .foregroundStyle(state == nil ? Theme.Color.tertiary : Theme.Color.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
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
                Sparkline(
                    values: SystemPulse.series(from: snapshot),
                    height: 28,
                    tint: pulseTint,
                    showsEmptyCaption: false
                )
                .frame(height: 28)
                Text(OverviewVisualFill.pulseLabel(cpu: cpuRatio))
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.tertiary)
            }
        }
        .buttonStyle(.plain)
        .help("Open Performance")
        .accessibilityLabel("System pulse, \(OverviewVisualFill.pulseLabel(cpu: cpuRatio))")
    }

    private var pulseTint: Color {
        if cpuRatio >= 0.8 { return Theme.Color.critical }
        if cpuRatio >= 0.45 { return Theme.Color.warning }
        return Theme.Color.accent
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
            Text("System Activity")
                .font(Theme.Typography.section)
            if !compact {
                Text(staleAge.map { "Updated \(Int($0))s ago" } ?? "Recent live samples from this session")
                    .font(Theme.Typography.metadata)
                    .foregroundStyle(Theme.Color.tertiary)
            } else if let staleAge {
                Text("Updated \(Int(staleAge))s ago")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.tertiary)
            }
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
            if let selection, let summary = selectionSummary(width: width) {
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

struct OverviewBottomRegion: View {
    let snapshot: LiveSnapshot
    var compact: Bool = false
    var compactWidth: Bool = false
    var onOpenProcess: (OverviewProcessRow) -> Void
    var onOpenProfile: (Profile) -> Void
    @Environment(\.designMetrics) private var metrics

    var body: some View {
        OverviewBottomLayout(compact: compactWidth, spacing: metrics.spacing.lg) {
            TopProcesses(snapshot: snapshot, limit: compact ? 4 : 5, onOpenProcess: onOpenProcess)
            SystemResources(snapshot: snapshot, compact: compact, onOpenProfile: onOpenProfile)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct OverviewBottomLayout: Layout {
    var compact: Bool
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let processes = subviews[0]
        let resources = subviews[1]
        if compact && bounds.width < 700 {
            let processSize = processes.sizeThatFits(.init(width: bounds.width, height: bounds.height * 0.58))
            processes.place(
                at: bounds.origin,
                proposal: .init(width: bounds.width, height: processSize.height)
            )
            resources.place(
                at: CGPoint(x: bounds.minX, y: bounds.minY + processSize.height + spacing),
                proposal: .init(width: bounds.width, height: max(bounds.maxY - bounds.minY - processSize.height - spacing, 1))
            )
            return
        }
        let resourceSize = resources.sizeThatFits(.init(width: bounds.width * 0.40, height: bounds.height))
        let resourceW = min(max(resourceSize.width, bounds.width * 0.35), bounds.width * 0.40)
        let processW = min(bounds.width * 0.65, max(bounds.width - resourceW - spacing, bounds.width * 0.55))
        processes.place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            proposal: .init(width: processW, height: bounds.height)
        )
        resources.place(
            at: CGPoint(x: bounds.maxX - resourceW, y: bounds.minY),
            proposal: .init(width: resourceW, height: bounds.height)
        )
    }
}

struct TopProcesses: View {
    let snapshot: LiveSnapshot
    var limit: Int = 5
    var onOpenProcess: (OverviewProcessRow) -> Void

    var body: some View {
        let unavailable = isUnavailable
        let processes = OverviewModel.processRows(from: snapshot, limit: limit, pad: false)
            .filter { $0.pid != 0 && $0.cpuRatio > 0.004 }
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("Top Processes")
                .font(Theme.Typography.section)
            if unavailable {
                Text("Process telemetry unavailable")
                    .font(Theme.Typography.metadata)
                    .foregroundStyle(Theme.Color.tertiary)
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
                            OverviewProcessRowView(process: process)
                        }
                        .buttonStyle(.plain)
                        .help(ProcessDisplay.name(pid: process.pid, fallback: process.name))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var isUnavailable: Bool {
        switch snapshot.availability["standard.processes"] {
        case .unavailable, .denied: true
        default: false
        }
    }
}

struct OverviewProcessRowView: View {
    let process: OverviewProcessRow

    var body: some View {
        HStack(spacing: Theme.Space.control) {
            ProcessGlyph(pid: process.pid, name: process.name)
            Text(ProcessDisplay.name(pid: process.pid, fallback: process.name))
                .font(Theme.Typography.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: 72, maxWidth: 140, alignment: .leading)
                .layoutPriority(1)
            MetricBar(ratio: process.cpuRatio, tint: Theme.Color.accent, height: 5)
                .frame(maxWidth: .infinity)
            Text(process.cpu)
                .font(Theme.Typography.secondary)
                .monospacedDigit()
                .foregroundStyle(Theme.Color.secondary)
                .fixedSize()
            if !process.memory.isEmpty {
                Text(process.memory)
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.tertiary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityLabel("\(process.name), CPU \(process.cpu)")
    }
}

struct SystemResources: View {
    let snapshot: LiveSnapshot
    var compact: Bool = false
    var onOpenProfile: (Profile) -> Void
    @Environment(\.designMetrics) private var metrics

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("System Resources")
                .font(Theme.Typography.section)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: metrics.spacing.lg) {
                    StorageSummary(snapshot: snapshot, compact: compact, action: { onOpenProfile(.storage) })
                    NetworkSummary(snapshot: snapshot, compact: compact, action: { onOpenProfile(.network) })
                    BatterySummary(snapshot: snapshot, compact: compact, action: { onOpenProfile(.power) })
                }
                VStack(alignment: .leading, spacing: metrics.spacing.md) {
                    HStack(alignment: .top, spacing: metrics.spacing.lg) {
                        StorageSummary(snapshot: snapshot, compact: compact, action: { onOpenProfile(.storage) })
                        NetworkSummary(snapshot: snapshot, compact: compact, action: { onOpenProfile(.network) })
                    }
                    BatterySummary(snapshot: snapshot, compact: compact, action: { onOpenProfile(.power) })
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
        let unavailable = capacity <= 0
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("Storage")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.tertiary)
                if unavailable {
                    Text("Storage data unavailable")
                        .font(Theme.Typography.secondary)
                        .foregroundStyle(Theme.Color.tertiary)
                        .lineLimit(2)
                } else {
                    Text("\(OverviewMetrics.bytes(available)) free")
                        .font(Theme.Typography.section)
                        .foregroundStyle(Theme.Color.text)
                    if !compact {
                        Text("of \(OverviewMetrics.bytes(capacity))")
                            .font(Theme.Typography.micro)
                            .foregroundStyle(Theme.Color.tertiary)
                    }
                    MetricBar(ratio: ratio, tint: Theme.Color.accent, height: 4)
                        .frame(width: 88)
                }
            }
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
        let disconnected = OverviewMetrics.isUnavailable(snapshot, "standard.network")
        let rxMetrics = snapshot.metrics.filter { $0.name == .networkRxBytesPerSecond }
        let txMetrics = snapshot.metrics.filter { $0.name == .networkTxBytesPerSecond }
        let rx = rxMetrics.reduce(0.0) { $0 + OverviewMetrics.numericValue($1) }
        let tx = txMetrics.reduce(0.0) { $0 + OverviewMetrics.numericValue($1) }
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("Network")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.tertiary)
                if disconnected {
                    Text("Disconnected")
                        .font(Theme.Typography.section)
                        .foregroundStyle(Theme.Color.warning)
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
        let charging = OverviewMetrics.stateFlag(snapshot, .powerBatteryCharging)
        let empty = OverviewMetrics.intValue(snapshot, .powerTimeToEmptyMinutes)
        let full = OverviewMetrics.intValue(snapshot, .powerTimeToFullMinutes)
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
                    if !compact, let copy = OverviewVisualFill.remainingCopy(
                        minutes: charging == true ? full : empty,
                        charging: charging == true
                    ) {
                        Text(copy)
                            .font(Theme.Typography.micro)
                            .foregroundStyle(Theme.Color.tertiary)
                            .lineLimit(1)
                    } else if charging == true {
                        Text("Charging")
                            .font(Theme.Typography.micro)
                            .foregroundStyle(Theme.Color.tertiary)
                    }
                } else {
                    Text("Unavailable")
                        .font(Theme.Typography.section)
                        .foregroundStyle(Theme.Color.tertiary)
                }
            }
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
