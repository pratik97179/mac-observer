import Foundation
import SwiftUI
import MacObserverDomain

struct OverviewReading: Identifiable {
    enum Kind {
        case live
        case pending
        case unavailable
    }

    let name: String
    let value: String
    let detail: String
    let symbol: String
    let tint: Color
    let kind: Kind
    let inspect: MetricInspectTarget?
    var id: String { name }

    init(
        name: String,
        value: String,
        detail: String,
        symbol: String,
        tint: Color,
        kind: Kind = .live,
        inspect: MetricInspectTarget? = nil
    ) {
        self.name = name
        self.value = value
        self.detail = detail
        self.symbol = symbol
        self.tint = tint
        self.kind = kind
        self.inspect = inspect
    }
}

enum ActivitySort: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case memory = "Memory"
    var id: Self { self }
}

struct OverviewProcessRow: Identifiable {
    let id: String
    let name: String
    let pid: Int32
    let cpu: String
    let memory: String
    let network: String
    let cpuRatio: Double
    let memoryBytes: Double
}

struct OverviewModel {
    let machineName: String
    let machineSubtitle: String
    let health: HealthAssessment
    let freshness: String
    let sampleAge: TimeInterval?
    let presentsSampling: Bool
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

        let cpuAvailability = snapshot.availability["standard.cpu_memory"]
        let networkAvailability = snapshot.availability["standard.network"]
        let storageAvailability = snapshot.availability["standard.storage"]
        let powerAvailability = snapshot.availability["standard.power"]

        let hasAnySample = cpu != nil || memoryUsed != nil
        let health = HealthRules.assess(
            cpuRatio: ratio(cpu),
            memoryPressure: state(pressure),
            thermal: state(thermal),
            coreUnavailable: coreUnavailable,
            stale: stale,
            hasAnySample: hasAnySample
        )
        let presentsSampling = !hasAnySample && !coreUnavailable

        let sampleAge: TimeInterval? = newest.map { now.timeIntervalSince($0) }
        let freshness: String
        if presentsSampling {
            freshness = "Collecting"
        } else if let sampleAge, sampleAge.isFinite {
            freshness = (sampleAge > 15)
                ? "Stale · \(Int(sampleAge))s ago"
                : "Live · \(max(0, Int(sampleAge)))s ago"
        } else {
            freshness = "Collecting"
        }

        var memoryText: String?
        if let memoryTotal {
            memoryText = MetricFormatter.displayString(for: memoryTotal)
        }
        let machineSubtitle = OverviewVisualFill.osSubtitle(memory: memoryText)

        var readings: [OverviewReading] = []
        readings.append(OverviewReading(
            name: "CPU",
            value: displayValue(cpu, availability: cpuAvailability),
            detail: cpu == nil ? "Waiting for telemetry" : "Host utilization",
            symbol: "cpu",
            tint: Theme.Color.sage,
            kind: kind(cpu, availability: cpuAvailability),
            inspect: .from(title: "CPU", metric: cpu)
        ))
        readings.append(OverviewReading(
            name: "Memory",
            value: displayValue(memoryUsed, availability: cpuAvailability),
            detail: memoryDetail(used: memoryUsed, total: memoryTotal, pressure: pressure),
            symbol: "memorychip",
            tint: Theme.Color.sage,
            kind: kind(memoryUsed, availability: cpuAvailability),
            inspect: .from(title: "Memory", metric: memoryUsed)
        ))
        readings.append(OverviewReading(
            name: "Network",
            value: combinedRate(rx + tx, availability: networkAvailability),
            detail: rx.isEmpty && tx.isEmpty ? "Interface counters" : "All interfaces",
            symbol: "arrow.down.right",
            tint: Theme.Color.sage,
            kind: kind(rx.first ?? tx.first, availability: networkAvailability)
        ))
        readings.append(OverviewReading(
            name: "Storage",
            value: combinedRate(read + write, availability: storageAvailability),
            detail: storageDetail(capacity: capacity, available: available),
            symbol: "internaldrive",
            tint: Theme.Color.sage,
            kind: kind(read.first ?? write.first ?? capacity, availability: storageAvailability)
        ))
        readings.append(powerReading(watts: watts, battery: battery, availability: powerAvailability))
        readings.append(OverviewReading(
            name: "GPU",
            value: "",
            detail: "No public GPU telemetry in this build.",
            symbol: "cpu.fill",
            tint: Theme.Color.sage,
            kind: .unavailable
        ))
        readings.append(OverviewReading(
            name: "Thermal",
            value: thermal.map { MetricFormatter.displayString(for: $0).capitalized } ?? displayValue(thermal, availability: cpuAvailability),
            detail: "ProcessInfo thermal state",
            symbol: "thermometer.medium",
            tint: Theme.Color.sage,
            kind: kind(thermal, availability: cpuAvailability),
            inspect: .from(title: "Thermal", metric: thermal)
        ))

        return OverviewModel(
            machineName: Host.current().localizedName ?? ProcessInfo.processInfo.hostName,
            machineSubtitle: machineSubtitle,
            health: health,
            freshness: freshness,
            sampleAge: sampleAge,
            presentsSampling: presentsSampling,
            readings: readings,
            processes: processRows(from: snapshot, limit: PanelLayout.tableRowCountOverview, pad: false)
        )
    }

    var primaryReadings: [OverviewReading] {
        let cpu = readings.first { $0.name == "CPU" }
        let memory = readings.first { $0.name == "Memory" }
        let gpu = readings.first { $0.name == "GPU" }
        return [cpu, memory, gpu].compactMap { $0 }
    }

    var cpuRatio: Double {
        readings.first { $0.name == "CPU" }.flatMap { reading in
            Double(reading.value.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces))
        }.map { $0 / 100 } ?? 0
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

    private static func powerReading(
        watts: Metric?,
        battery: Metric?,
        availability: CapabilityAvailability?
    ) -> OverviewReading {
        if let watts {
            return OverviewReading(
                name: "Power",
                value: MetricFormatter.displayString(for: watts),
                detail: battery.map { "Battery \(MetricFormatter.displayString(for: $0))" } ?? "Estimated from voltage and current",
                symbol: "bolt",
                tint: Theme.Color.sage,
                kind: .live,
                inspect: .from(title: "Power", metric: watts)
            )
        }
        if let battery {
            return OverviewReading(
                name: "Power",
                value: MetricFormatter.displayString(for: battery),
                detail: "Battery charge",
                symbol: "bolt",
                tint: Theme.Color.sage,
                kind: .live,
                inspect: .from(title: "Power", metric: battery)
            )
        }
        return OverviewReading(
            name: "Power",
            value: displayValue(nil, availability: availability),
            detail: "No battery or watt reading",
            symbol: "bolt",
                tint: Theme.Color.sage,
            kind: kind(nil, availability: availability)
        )
    }

    private static func combinedRate(_ metrics: [Metric], availability: CapabilityAvailability?) -> String {
        let total = metrics.reduce(0.0) { partial, metric in
            switch metric.value {
            case .double(let value): partial + value
            case .int(let value): partial + Double(value)
            default: partial
            }
        }
        guard !metrics.isEmpty else {
            return displayValue(nil, availability: availability)
        }
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

    private static func kind(_ metric: Metric?, availability: CapabilityAvailability?) -> OverviewReading.Kind {
        if case .unavailable = availability { return .unavailable }
        if metric == nil { return .pending }
        return .live
    }

    private static func displayValue(_ metric: Metric?, availability: CapabilityAvailability?) -> String {
        switch kind(metric, availability: availability) {
        case .pending: ""
        case .unavailable: ""
        case .live: metric.map(MetricFormatter.displayString) ?? ""
        }
    }

    private static func intValue(_ metric: Metric) -> Int64? {
        switch metric.value {
        case .int(let value): value
        case .double(let value): Int64(value)
        default: nil
        }
    }

    static func processRows(
        from snapshot: LiveSnapshot,
        limit: Int,
        pad: Bool = false,
        sort: ActivitySort = .cpu
    ) -> [OverviewProcessRow] {
        let cpuMetrics = snapshot.metrics.filter { isProcessCPU($0) }

        var rows = cpuMetrics.map { metric -> OverviewProcessRow in
            let memory = snapshot.metric(named: .processResidentBytes, entity: metric.entity)
            let memoryBytes = memory.map(numericValue) ?? 0
            guard case .processInstance(let identity) = metric.entity else {
                return OverviewProcessRow(
                    id: metric.id.uuidString,
                    name: "Process",
                    pid: 0,
                    cpu: MetricFormatter.displayString(for: metric),
                    memory: memory.map(MetricFormatter.displayString) ?? "",
                    network: "unavailable",
                    cpuRatio: ratio(metric) ?? 0,
                    memoryBytes: memoryBytes
                )
            }
            return OverviewProcessRow(
                id: identity.identityKey,
                name: identity.attributes.displayName ?? "pid \(identity.pid)",
                pid: identity.pid,
                cpu: MetricFormatter.displayString(for: metric),
                memory: memory.map(MetricFormatter.displayString) ?? "",
                network: "unavailable",
                cpuRatio: ratio(metric) ?? 0,
                memoryBytes: memoryBytes
            )
        }
        rows.sort { lhs, rhs in
            switch sort {
            case .cpu: lhs.cpuRatio > rhs.cpuRatio
            case .memory: lhs.memoryBytes > rhs.memoryBytes
            }
        }
        rows = Array(rows.prefix(limit))
        if pad {
            while rows.count < limit {
                rows.append(OverviewProcessRow(
                    id: "placeholder-\(rows.count)",
                    name: "",
                    pid: 0,
                    cpu: "",
                    memory: "",
                    network: "unavailable",
                    cpuRatio: 0,
                    memoryBytes: 0
                ))
            }
        }
        return rows
    }

    private static func numericValue(_ metric: Metric) -> Double {
        switch metric.value {
        case .int(let value): Double(value)
        case .double(let value): value
        case .ratio(let value): value
        default: 0
        }
    }

    private static func isProcessCPU(_ metric: Metric) -> Bool {
        guard metric.name == .cpuUtilizationRatio else { return false }
        if case .processInstance = metric.entity { return true }
        return false
    }
}
