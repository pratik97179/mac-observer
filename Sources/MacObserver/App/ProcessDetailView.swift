import AppKit
import SwiftUI
import MacObserverDomain
import MacObserverCollectors

struct ProcessDetailView: View {
    let store: OverviewStore
    let process: OverviewProcessRow
    var onInspect: (MetricInspectTarget) -> Void = { _ in }

    private var live: OverviewProcessRow {
        OverviewModel.processRows(from: store.snapshot, limit: 20, pad: false)
            .first { $0.id == process.id } ?? process
    }

    private var title: String {
        ProcessDisplay.name(pid: live.pid, fallback: live.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.section) {
            header
            metrics
            collectedNote
        }
        .padding(Theme.Space.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.Color.canvas)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Theme.Space.standard) {
            ProcessGlyph(pid: live.pid, name: title, size: 40)
            VStack(alignment: .leading, spacing: Theme.Space.micro) {
                Text(title)
                    .font(Theme.Typography.pageTitle)
                    .lineLimit(1)
                Text(subtitle)
                    .font(Theme.Typography.metadata)
                    .foregroundStyle(Theme.Color.tertiary)
            }
            Spacer(minLength: 0)
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if live.pid != 0 {
            parts.append("PID \(live.pid)")
        }
        if let bundle = ProcessDisplay.bundleIdentifier(pid: live.pid) {
            parts.append(bundle)
        }
        return parts.isEmpty ? "Process" : parts.joined(separator: " · ")
    }

    private var metrics: some View {
        HStack(alignment: .top, spacing: Theme.Space.cardGap) {
            Button {
                inspect(title: "CPU", name: .cpuUtilizationRatio, domain: .cpu)
            } label: {
                metricCard(title: "CPU", value: live.cpu.isEmpty ? "—" : live.cpu, chevron: inspectEntityKey != nil) {
                    MetricBar(ratio: live.cpuRatio, empty: live.cpu.isEmpty, tint: Theme.Color.cpu, height: 8)
                    Text("Open history")
                        .font(Theme.Typography.metadata)
                        .foregroundStyle(Theme.Color.tertiary)
                }
            }
            .buttonStyle(.plain)
            .disabled(inspectEntityKey == nil)
            Button {
                inspect(title: "Memory", name: .processResidentBytes, domain: .memory)
            } label: {
                metricCard(title: "Memory", value: live.memory.isEmpty ? "—" : live.memory, chevron: inspectEntityKey != nil) {
                    Text("Resident size")
                        .font(Theme.Typography.metadata)
                        .foregroundStyle(Theme.Color.tertiary)
                    Text("Open history")
                        .font(Theme.Typography.metadata)
                        .foregroundStyle(Theme.Color.tertiary)
                }
            }
            .buttonStyle(.plain)
            .disabled(inspectEntityKey == nil)
        }
    }

    private var inspectEntityKey: String? {
        live.pid == 0 ? nil : "process:\(live.id)"
    }

    private func inspect(title: String, name: MetricName, domain: TelemetryDomain) {
        guard let entityKey = inspectEntityKey else { return }
        onInspect(
            MetricInspectTarget(
                title: "\(self.title) \(title)",
                metricName: name,
                domain: domain,
                entityKey: entityKey
            )
        )
    }

    private func metricCard<Footer: View>(
        title: String,
        value: String,
        chevron: Bool = false,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.standard) {
            HStack {
                Text(title)
                    .font(Theme.Typography.metadata)
                    .foregroundStyle(Theme.Color.secondary)
                Spacer()
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Color.tertiary)
                }
            }
            Text(value)
                .font(Theme.Typography.hero)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .monospacedDigit()
            footer()
            Spacer(minLength: 0)
        }
        .padding(Theme.Space.component)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .glass(.elevated, radius: Theme.Radius.secondary)
        .contentShape(Rectangle())
    }

    private var collectedNote: some View {
        VStack(alignment: .leading, spacing: Theme.Space.control) {
            Text("Not collected")
                .font(Theme.Typography.metadata)
                .foregroundStyle(Theme.Color.tertiary)
            Text("Network · Disk I/O · GPU")
                .font(Theme.Typography.secondary)
                .foregroundStyle(Theme.Color.secondary)
        }
        .padding(Theme.Space.component)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(.resting, radius: Theme.Radius.secondary)
    }
}

@MainActor
enum ProcessDisplay {
    static func name(pid: Int32, fallback: String) -> String {
        if pid != 0, let localized = ProcessChrome.name(pid: pid), !localized.isEmpty {
            return localized
        }
        if fallback.hasPrefix("pid ") {
            return "Process \(fallback.dropFirst(4))"
        }
        if fallback.isEmpty {
            return pid == 0 ? "Process" : "Process \(pid)"
        }
        return fallback
    }

    static func bundleIdentifier(pid: Int32) -> String? {
        ProcessChrome.bundleIdentifier(pid: pid)
    }
}

@MainActor
enum ProcessChrome {
    private struct Record {
        var name: String?
        var bundle: String?
        var icon: NSImage?
        var sampledAt: Date
    }

    private static var records: [Int32: Record] = [:]
    private static let ttl: TimeInterval = 30

    static func name(pid: Int32) -> String? {
        record(pid: pid)?.name
    }

    static func bundleIdentifier(pid: Int32) -> String? {
        let value = record(pid: pid)?.bundle
        return value?.isEmpty == false ? value : nil
    }

    static func icon(pid: Int32) -> NSImage? {
        record(pid: pid)?.icon
    }

    private static func record(pid: Int32) -> Record? {
        guard pid != 0 else { return nil }
        if let existing = records[pid], Date().timeIntervalSince(existing.sampledAt) < ttl {
            return existing
        }
        let app = NSRunningApplication(processIdentifier: pid)
        let next = Record(
            name: app?.localizedName,
            bundle: app?.bundleIdentifier,
            icon: app?.icon,
            sampledAt: Date()
        )
        records[pid] = next
        if records.count > 256 {
            let stale = records.filter { Date().timeIntervalSince($0.value.sampledAt) >= ttl }.map(\.key)
            stale.forEach { records.removeValue(forKey: $0) }
        }
        return next
    }
}
