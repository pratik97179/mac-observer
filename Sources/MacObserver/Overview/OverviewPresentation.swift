import Foundation
import SwiftUI
import MacObserverDomain
import MacObserverCollectors

struct OverviewReading: Identifiable {
    let name: String
    let value: String
    let detail: String
    let symbol: String
    let tint: Color
    var id: String { name }
}

struct OverviewProcessRow: Identifiable {
    let id: String
    let name: String
    let cpu: String
    let memory: String
    let network: String
}

struct OverviewModel {
    let machineName: String
    let health: HealthAssessment
    let freshness: String
    let readings: [OverviewReading]
    let processes: [OverviewProcessRow]

    static func from(snapshot: LiveSnapshot, now: Date = Date()) -> OverviewModel {
        let systemEntity = snapshot.metrics.compactMap { metric -> Entity? in
            if case .system = metric.entity { return metric.entity }
            return nil
        }.first

        let cpu = systemEntity.flatMap { snapshot.metric(named: .cpuUtilizationRatio, entity: $0) }
        let memoryUsed = systemEntity.flatMap { snapshot.metric(named: .memoryUsedBytes, entity: $0) }
        let memoryTotal = systemEntity.flatMap { snapshot.metric(named: .memoryTotalBytes, entity: $0) }
        let pressure = systemEntity.flatMap { snapshot.metric(named: .memoryPressureState, entity: $0) }
        let thermal = systemEntity.flatMap { snapshot.metric(named: .thermalState, entity: $0) }
        let battery = systemEntity.flatMap { snapshot.metric(named: .powerBatteryChargeRatio, entity: $0) }
        let watts = systemEntity.flatMap { snapshot.metric(named: .powerLoadWatts, entity: $0) }

        let rx = snapshot.metrics.filter { $0.name == .networkRxBytesPerSecond }
        let tx = snapshot.metrics.filter { $0.name == .networkTxBytesPerSecond }
        let read = snapshot.metrics.filter { $0.name == .storageReadBytesPerSecond }
        let write = snapshot.metrics.filter { $0.name == .storageWriteBytesPerSecond }
        let capacity = snapshot.metrics.first { $0.name == .storageCapacityBytes }
        let available = snapshot.metrics.first { $0.name == .storageAvailableBytes }

        let newest = snapshot.metrics.map(\.time.wallTime).max()
        let age = newest.map { now.timeIntervalSince($0) } ?? .infinity
        let stale = newest != nil && age > 15
        let coreUnavailable = snapshot.availability.contains { key, value in
            key.hasPrefix("standard.") && ifCaseUnavailable(value)
        }

        let health = HealthRules.assess(
            cpuRatio: ratio(cpu),
            memoryPressure: state(pressure),
            thermal: state(thermal),
            coreUnavailable: coreUnavailable,
            stale: stale,
            hasAnySample: cpu != nil || memoryUsed != nil
        )

        let freshness: String
        if !snapshot.metrics.isEmpty, age.isFinite {
            freshness = stale ? "Stale · \(Int(age))s ago" : "Live · \(max(0, Int(age)))s ago"
        } else {
            freshness = "No live readings yet"
        }

        var readings: [OverviewReading] = []
        readings.append(OverviewReading(
            name: "CPU",
            value: cpu.map(MetricFormatter.displayString) ?? "Unavailable",
            detail: cpu == nil ? "Waiting for a sample" : "System load",
            symbol: "cpu",
            tint: .blue
        ))
        readings.append(OverviewReading(
            name: "Memory",
            value: memoryUsed.map(MetricFormatter.displayString) ?? "Unavailable",
            detail: memoryDetail(used: memoryUsed, total: memoryTotal, pressure: pressure),
            symbol: "memorychip",
            tint: .indigo
        ))
        readings.append(OverviewReading(
            name: "Network",
            value: combinedRate(rx + tx),
            detail: rx.isEmpty && tx.isEmpty ? "Interface counters" : "All interfaces",
            symbol: "arrow.down.right",
            tint: .cyan
        ))
        readings.append(OverviewReading(
            name: "Storage",
            value: combinedRate(read + write),
            detail: storageDetail(capacity: capacity, available: available),
            symbol: "internaldrive",
            tint: .orange
        ))
        readings.append(powerReading(watts: watts, battery: battery))
        readings.append(OverviewReading(
            name: "Thermal",
            value: thermal.map(MetricFormatter.displayString)?.capitalized ?? "Unavailable",
            detail: battery.map { "Battery \(MetricFormatter.displayString(for: $0))" } ?? "ProcessInfo thermal state",
            symbol: "thermometer.medium",
            tint: .green
        ))

        return OverviewModel(
            machineName: Host.current().localizedName ?? ProcessInfo.processInfo.hostName,
            health: health,
            freshness: freshness,
            readings: readings,
            processes: processRows(from: snapshot)
        )
    }

    private static func ifCaseUnavailable(_ availability: CapabilityAvailability) -> Bool {
        if case .unavailable = availability { return true }
        return false
    }

    private static func ratio(_ metric: Metric?) -> Double? {
        guard let metric, case .ratio(let value) = metric.value else { return nil }
        return value
    }

    private static func state(_ metric: Metric?) -> String? {
        guard let metric, case .state(let value) = metric.value else { return nil }
        return value
    }

    private static func memoryDetail(used: Metric?, total: Metric?, pressure: Metric?) -> String {
        let pressureText = state(pressure).map { "Pressure \($0)" }
        if let used, let total {
            let usedBytes = intValue(used)
            let totalBytes = intValue(total)
            if let usedBytes, let totalBytes, totalBytes > 0 {
                let percent = Int((Double(usedBytes) / Double(totalBytes) * 100).rounded())
                return [pressureText, "\(percent)% of \(MetricFormatter.displayString(for: total))"]
                    .compactMap { $0 }
                    .joined(separator: " · ")
            }
        }
        return pressureText ?? "Resident plus wired plus compressor"
    }

    private static func storageDetail(capacity: Metric?, available: Metric?) -> String {
        if let capacity, let available, let cap = intValue(capacity), let free = intValue(available), cap > 0 {
            let usedPercent = Int((Double(cap - free) / Double(cap) * 100).rounded())
            return "\(usedPercent)% of volume used"
        }
        return "Root volume"
    }

    private static func powerReading(watts: Metric?, battery: Metric?) -> OverviewReading {
        if let watts {
            return OverviewReading(
                name: "Power",
                value: MetricFormatter.displayString(for: watts),
                detail: battery.map { "Battery \(MetricFormatter.displayString(for: $0))" } ?? "Estimated from voltage and current",
                symbol: "bolt",
                tint: .yellow
            )
        }
        if let battery {
            return OverviewReading(
                name: "Power",
                value: MetricFormatter.displayString(for: battery),
                detail: "Battery charge",
                symbol: "bolt",
                tint: .yellow
            )
        }
        return OverviewReading(
            name: "Power",
            value: "Unavailable",
            detail: "No battery or watt reading",
            symbol: "bolt",
            tint: .yellow
        )
    }

    private static func combinedRate(_ metrics: [Metric]) -> String {
        let total = metrics.reduce(0.0) { partial, metric in
            switch metric.value {
            case .double(let value): partial + value
            case .int(let value): partial + Double(value)
            default: partial
            }
        }
        guard !metrics.isEmpty else { return "Unavailable" }
        let synthetic = Metric(
            time: metrics[0].time,
            domain: .network,
            name: .networkRxBytesPerSecond,
            entity: metrics[0].entity,
            value: .double(total),
            unit: .bytesPerSecond,
            source: "overview",
            quality: .derived
        )
        return MetricFormatter.displayString(for: synthetic)
    }

    private static func intValue(_ metric: Metric) -> Int64? {
        switch metric.value {
        case .int(let value): value
        case .double(let value): Int64(value)
        default: nil
        }
    }

    private static func processRows(from snapshot: LiveSnapshot) -> [OverviewProcessRow] {
        let cpuMetrics = snapshot.metrics.filter { isProcessCPU($0) }
            .sorted { lhs, rhs in
                (ratio(lhs) ?? 0) > (ratio(rhs) ?? 0)
            }

        return cpuMetrics.prefix(8).map { metric in
            guard case .processInstance(let identity) = metric.entity else {
                return OverviewProcessRow(id: metric.id.uuidString, name: "Process", cpu: "—", memory: "—", network: "—")
            }
            let memory = snapshot.metric(named: .processResidentBytes, entity: metric.entity)
            return OverviewProcessRow(
                id: identity.identityKey,
                name: identity.attributes.displayName ?? "pid \(identity.pid)",
                cpu: MetricFormatter.displayString(for: metric),
                memory: memory.map(MetricFormatter.displayString) ?? "—",
                network: "—"
            )
        }
    }

    private static func isProcessCPU(_ metric: Metric) -> Bool {
        guard metric.name == .cpuUtilizationRatio else { return false }
        if case .processInstance = metric.entity { return true }
        return false
    }
}
