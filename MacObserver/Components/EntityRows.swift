import SwiftUI
import AppKit
import MacObserverDomain

struct ProcessRow: View {
    let process: OverviewProcessRow
    var compact: Bool = false
    @State private var hovering = false

    var body: some View {
        if compact {
            compactRow
        } else {
            detailedRow
        }
    }

    private var compactRow: some View {
        HStack(spacing: Theme.Space.control) {
            ProcessGlyph(pid: process.pid, name: process.name)
            Text(ProcessDisplay.name(pid: process.pid, fallback: process.name))
                .font(Theme.Typography.body)
                .lineLimit(1)
            Spacer(minLength: Theme.Space.compact)
            Text(process.cpu.isEmpty ? " " : process.cpu)
                .font(Theme.Typography.secondary)
                .monospacedDigit()
                .foregroundStyle(AppTheme.secondary)
                .frame(width: 40, alignment: .trailing)
            MetricBar(ratio: process.cpuRatio, empty: process.cpu.isEmpty, tint: AppTheme.cpu)
                .frame(width: 72)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.tertiary)
        }
        .padding(.vertical, Theme.Space.control)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .overlay(alignment: .leading) {
            if hovering, process.pid != 0 {
                Text("PID \(process.pid)")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(AppTheme.tertiary)
                    .offset(y: 18)
            }
        }
        .accessibilityLabel("\(process.name), CPU \(process.cpu)")
    }

    private var detailedRow: some View {
        VStack(alignment: .leading, spacing: Theme.Space.icon) {
            HStack {
                ProcessGlyph(pid: process.pid, name: process.name)
                Text(ProcessDisplay.name(pid: process.pid, fallback: process.name))
                    .font(Theme.Typography.body)
                    .foregroundStyle(process.name.isEmpty ? AppTheme.tertiary : AppTheme.text)
                    .lineLimit(1)
                Spacer()
                Text(process.cpu.isEmpty ? " " : process.cpu)
                    .font(Theme.Typography.largeMetric)
                    .readoutTransition(process.cpu)
            }
            MetricBar(ratio: process.cpuRatio, empty: process.cpu.isEmpty, tint: AppTheme.cpu)
            HStack {
                Text(process.memory.isEmpty ? "RAM unavailable" : "\(process.memory) RAM")
                    .font(Theme.Typography.metadata)
                    .foregroundStyle(AppTheme.secondary)
                Spacer()
                Text("PID \(process.pid)")
                    .font(Theme.Typography.metadata)
                    .foregroundStyle(AppTheme.tertiary)
                    .opacity(hovering && process.pid != 0 ? 1 : 0)
                    .accessibilityHidden(!hovering || process.pid == 0)
                Text(process.network == "unavailable" ? "Network unavailable" : process.network)
                    .font(Theme.Typography.metadata)
                    .foregroundStyle(AppTheme.tertiary)
            }
        }
        .padding(.vertical, Theme.Space.compact)
        .onHover { hovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(process.name), CPU \(process.cpu), memory \(process.memory)")
    }
}

struct ProcessGlyph: View {
    let pid: Int32
    let name: String
    var size: CGFloat = 22

    var body: some View {
        Group {
            if pid != 0, let icon = ProcessChrome.icon(pid: pid) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: fallback)
                    .font(.system(size: size * 0.5, weight: .medium))
                    .foregroundStyle(AppTheme.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(5, size / 5), style: .continuous))
    }

    private var fallback: String {
        let lowered = name.lowercased()
        if lowered.contains("finder") { return "folder" }
        if lowered.contains("chrome") { return "globe" }
        if lowered.contains("safari") { return "safari" }
        return "app.fill"
    }
}

struct EntityColumnHeader: View {
    let columns: [String]

    var body: some View {
        HStack(spacing: Theme.Space.standard) {
            ForEach(Array(columns.enumerated()), id: \.offset) { index, title in
                Text(title)
                    .font(Theme.Typography.micro)
                    .foregroundStyle(AppTheme.tertiary)
                    .frame(maxWidth: index == 0 ? .infinity : 120, alignment: index == 0 ? .leading : .trailing)
            }
        }
        .padding(.bottom, Theme.Space.micro)
        .accessibilityAddTraits(.isHeader)
    }
}

struct EntityRow: View {
    let cells: [String]

    var body: some View {
        HStack(spacing: Theme.Space.standard) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                Text(cell.isEmpty ? "unavailable" : cell)
                    .font(index == 0 ? Theme.Typography.body : Theme.Typography.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .foregroundStyle(cell.isEmpty || cell == "unavailable" ? AppTheme.unavailable : AppTheme.text)
                    .frame(maxWidth: index == 0 ? .infinity : 120, alignment: index == 0 ? .leading : .trailing)
                    .readoutTransition(cell)
            }
        }
        .padding(.vertical, Theme.Space.compact)
    }
}

struct EventRow: View {
    let event: Event
    let showsCalendarDate: Bool
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.micro) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.control) {
                Text(event.time.wallTime, format: timeFormat)
                    .font(Theme.Typography.metadata)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.tertiary)
                    .frame(width: showsCalendarDate ? 148 : 72, alignment: .leading)
                Text(event.domain.rawValue.uppercased())
                    .font(Theme.Typography.micro)
                    .foregroundStyle(AppTheme.sageMuted)
                Text(event.summary)
                    .font(Theme.Typography.body)
                    .foregroundStyle(AppTheme.text)
                Spacer(minLength: 0)
            }
            if hovering, !event.metadata.isEmpty {
                Text(event.metadata.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }.joined(separator: "  "))
                    .font(Theme.Typography.metadata)
                    .foregroundStyle(AppTheme.tertiary)
            }
        }
        .padding(.vertical, Theme.Space.control)
        .onHover { hovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.summary), \(event.domain.rawValue)")
    }

    private var timeFormat: Date.FormatStyle {
        if showsCalendarDate {
            return .dateTime.month(.abbreviated).day().hour().minute().second()
        }
        return .dateTime.hour().minute().second()
    }
}

struct EventGroup: View {
    let events: [Event]
    let showsCalendarDate: Bool
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Motion.state) { expanded.toggle() }
            } label: {
                HStack {
                    Text("\(events.count) events")
                        .font(Theme.Typography.section)
                    Spacer()
                    Text(expanded ? "Collapse" : "Expand")
                        .font(Theme.Typography.metadata)
                        .foregroundStyle(AppTheme.sage)
                }
                .padding(.vertical, Theme.Space.control)
            }
            .buttonStyle(.plain)
            if expanded {
                ForEach(events) { event in
                    EventRow(event: event, showsCalendarDate: showsCalendarDate)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(events.count) events")
    }
}

struct FilterBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.standard) {
            content
            Spacer(minLength: 0)
        }
    }
}
