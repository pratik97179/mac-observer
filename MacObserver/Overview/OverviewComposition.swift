import AppKit
import SwiftUI
import MacObserverDomain

struct OverviewHeader: View {
    @Binding var selection: Profile
    var onSearch: () -> Void = {}
    @Environment(\.designMetrics) private var metrics

    var body: some View {
        HStack(spacing: metrics.spacing.md) {
            WindowControls()
            Text("Mac Observer")
                .font(Theme.Typography.section)
                .foregroundStyle(Theme.Color.text)
                .lineLimit(1)
                .fixedSize()

            Spacer(minLength: metrics.spacing.md)

            OverviewNavigation(selection: $selection)

            Spacer(minLength: metrics.spacing.md)

            HeaderUtilities(onSearch: onSearch)
        }
        .padding(.horizontal, metrics.horizontalInset)
        .padding(.top, metrics.topInset)
        .padding(.bottom, metrics.spacing.sm)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
    }
}

struct OverviewNavigation: View {
    @Binding var selection: Profile
    @Environment(\.designMetrics) private var metrics

    var body: some View {
        HStack(spacing: metrics.spacing.lg) {
            ForEach(Profile.views) { profile in
                Button {
                    selection = profile
                } label: {
                    VStack(spacing: 4) {
                        Text(profile.rawValue)
                            .font(Theme.Typography.secondary)
                            .foregroundStyle(selection == profile ? Theme.Color.text : Theme.Color.secondary)
                            .lineLimit(1)
                            .fixedSize()
                        Capsule()
                            .fill(selection == profile ? Theme.Color.text : Color.clear)
                            .frame(height: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == profile ? .isSelected : [])
            }
        }
        .fixedSize()
    }
}

struct HeaderUtilities: View {
    var onSearch: () -> Void = {}
    @Environment(\.designMetrics) private var metrics

    var body: some View {
        HStack(spacing: metrics.spacing.sm) {
            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Color.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Search")
            .accessibilityLabel("Open command palette")

            Rectangle()
                .fill(Theme.Color.divider)
                .frame(width: 1, height: 12)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: metrics.spacing.sm) {
                    Text(Self.dateText(context.date))
                        .foregroundStyle(Theme.Color.secondary)
                    Text(Self.timeText(context.date))
                        .foregroundStyle(Theme.Color.secondary)
                        .monospacedDigit()
                }
                .font(Theme.Typography.secondary)
            }
        }
        .fixedSize()
        .frame(alignment: .trailing)
    }

    private static func dateText(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    private static func timeText(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

struct OverviewMain: View {
    let store: OverviewStore
    var onOpenProfile: (Profile) -> Void = { _ in }
    @Environment(\.designMetrics) private var metrics

    private var model: OverviewModel { OverviewModel.from(snapshot: store.snapshot) }

    var body: some View {
        VStack(spacing: 0) {
            StatusSection(model: model)
                .layoutPriority(1)

            Spacer(minLength: metrics.spacing.md)

            Spacer(minLength: metrics.spacing.md)

            MetricsSection(snapshot: store.snapshot, onOpenProfile: onOpenProfile)
                .layoutPriority(1)
        }
        .padding(.horizontal, metrics.horizontalInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

struct StatusSection: View {
    let model: OverviewModel
    @Environment(\.designMetrics) private var metrics

    var body: some View {
        VStack(spacing: metrics.spacing.xs) {
            Text("SYSTEM STATUS")
                .font(Theme.Typography.micro)
                .foregroundStyle(Theme.Color.tertiary)
                .tracking(1.6)
            Text(title)
                .font(metrics.type.display)
                .foregroundStyle(Theme.Color.text)
            Text(description)
                .font(Theme.Typography.secondary)
                .foregroundStyle(Theme.Color.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("System status, \(title). \(description)")
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

    private var description: String {
        if model.presentsSampling { return "Waiting for the first sample." }
        if let age = model.sampleAge, age > 15 {
            return "Updated \(Int(age))s ago"
        }
        switch model.health.state {
        case .healthy: return "Your Mac is running smoothly."
        case .attention, .investigate: return model.health.detail
        }
    }
}

struct MetricsSection: View {
    let snapshot: LiveSnapshot
    var onOpenProfile: (Profile) -> Void
    @Environment(\.designMetrics) private var metrics

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(Theme.Color.divider)
                        .frame(width: 1)
                        .padding(.vertical, 6)
                }
                MetricGroup(item: item, action: { onOpenProfile(item.profile) })
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.bottom, metrics.spacing.sm)
    }

    private var items: [OverviewMetricItem] {
        OverviewMetricItem.all(from: snapshot)
    }
}

struct MetricGroup: View {
    let item: OverviewMetricItem
    var action: () -> Void
    @Environment(\.designMetrics) private var metrics

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: metrics.spacing.sm) {
                Image(systemName: item.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Color.secondary)
                    .frame(width: 18, height: 18)
                    .fixedSize()

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.label)
                        .font(Theme.Typography.micro)
                        .foregroundStyle(Theme.Color.tertiary)
                        .lineLimit(1)
                    Text(item.value)
                        .font(Theme.Typography.secondary)
                        .foregroundStyle(item.enabled ? Theme.Color.text : Theme.Color.tertiary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    MetricBar(
                        ratio: item.progress,
                        enabled: item.enabled,
                        empty: !item.enabled,
                        height: 4
                    )
                    .frame(width: 72)
                    .fixedSize(horizontal: true, vertical: true)
                }
                .fixedSize(horizontal: true, vertical: true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(item.caption)
        .accessibilityLabel("\(item.label), \(item.value), \(item.caption)")
    }
}

struct OverviewFooter: View {
    var onViewProcesses: () -> Void
    @Environment(\.designMetrics) private var metrics

    var body: some View {
        HStack(spacing: metrics.spacing.md) {
            BrandStatement()
            Spacer(minLength: metrics.spacing.md)
            ViewProcessesButton(action: onViewProcesses)
        }
        .padding(.horizontal, metrics.horizontalInset)
        .padding(.top, metrics.spacing.sm)
        .padding(.bottom, metrics.bottomInset)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct BrandStatement: View {
    @Environment(\.designMetrics) private var metrics

    var body: some View {
        HStack(alignment: .center, spacing: metrics.spacing.sm) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Color.sageMuted)
                .frame(width: 18, height: 18)
                .fixedSize()
            VStack(alignment: .leading, spacing: 1) {
                Text("Mac Observer")
                    .font(Theme.Typography.section)
                    .foregroundStyle(Theme.Color.text)
                    .lineLimit(1)
                Text("Live on this Mac")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.tertiary)
                    .lineLimit(1)
            }
            .fixedSize()
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mac Observer, live on this Mac")
    }
}

struct ViewProcessesButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("View Processes")
                    .font(Theme.Typography.secondary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Theme.Color.secondary)
            .fixedSize()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Open Processes")
        .accessibilityLabel("View Processes")
    }
}

struct OverviewMetricItem: Identifiable {
    let id: String
    let icon: String
    let label: String
    let value: String
    let caption: String
    let progress: Double
    let enabled: Bool
    let profile: Profile

    static func all(from snapshot: LiveSnapshot) -> [OverviewMetricItem] {
        [cpu(snapshot), memory(snapshot), storage(snapshot), thermal(snapshot), battery(snapshot)]
    }

    private static func cpu(_ snapshot: LiveSnapshot) -> OverviewMetricItem {
        let ratio = snapshot.series(named: .cpuUtilizationRatio).last?.value
            ?? OverviewMetrics.ratio(snapshot, .cpuUtilizationRatio)
        let enabled = ratio != nil
        return OverviewMetricItem(
            id: "cpu",
            icon: "cpu",
            label: "CPU",
            value: ratio.map(OverviewMetrics.percent) ?? "—",
            caption: "CPU utilisation",
            progress: ratio ?? 0,
            enabled: enabled,
            profile: .performance
        )
    }

    private static func memory(_ snapshot: LiveSnapshot) -> OverviewMetricItem {
        let used = OverviewMetrics.numeric(snapshot, .memoryUsedBytes)
        let total = OverviewMetrics.numeric(snapshot, .memoryTotalBytes)
        let enabled = total > 0
        let progress = enabled ? used / total : 0
        return OverviewMetricItem(
            id: "memory",
            icon: "memorychip",
            label: "Memory",
            value: enabled ? "\(OverviewMetrics.bytes(used)) / \(OverviewMetrics.bytes(total))" : "—",
            caption: "Memory utilisation",
            progress: progress,
            enabled: enabled,
            profile: .performance
        )
    }

    private static func storage(_ snapshot: LiveSnapshot) -> OverviewMetricItem {
        let capacity = OverviewMetrics.numeric(snapshot, .storageCapacityBytes)
        let available = OverviewMetrics.numeric(snapshot, .storageAvailableBytes)
        let used = max(0, capacity - available)
        let enabled = capacity > 0 && !OverviewMetrics.isUnavailable(snapshot, "standard.storage")
        let progress = enabled ? used / capacity : 0
        return OverviewMetricItem(
            id: "storage",
            icon: "internaldrive",
            label: "Storage",
            value: enabled ? "\(OverviewMetrics.bytes(used)) / \(OverviewMetrics.bytes(capacity))" : "—",
            caption: "Storage utilisation",
            progress: progress,
            enabled: enabled,
            profile: .storage
        )
    }

    private static func thermal(_ snapshot: LiveSnapshot) -> OverviewMetricItem {
        let state = OverviewMetrics.state(snapshot, .thermalState)
        let enabled = state != nil
        return OverviewMetricItem(
            id: "thermal",
            icon: "thermometer.medium",
            label: "Thermal",
            value: enabled ? OverviewVisualFill.thermalTitle(state: state) : "—",
            caption: "Thermal level",
            progress: thermalProgress(state),
            enabled: enabled,
            profile: .performance
        )
    }

    private static func battery(_ snapshot: LiveSnapshot) -> OverviewMetricItem {
        let ratio = OverviewMetrics.ratio(snapshot, .powerBatteryChargeRatio)
        let enabled = ratio != nil && !OverviewMetrics.isUnavailable(snapshot, "standard.power")
        return OverviewMetricItem(
            id: "battery",
            icon: "battery.100",
            label: "Battery",
            value: ratio.map(OverviewMetrics.percent) ?? "—",
            caption: "Battery charge",
            progress: ratio ?? 0,
            enabled: enabled,
            profile: .power
        )
    }

    private static func thermalProgress(_ state: String?) -> Double {
        switch state?.lowercased() {
        case "nominal", "normal": 0.22
        case "fair": 0.5
        case "serious": 0.78
        case "critical": 1
        default: 0
        }
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
