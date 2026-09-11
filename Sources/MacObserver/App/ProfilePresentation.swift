import Foundation
import SwiftUI
import MacObserverDomain
import MacObserverCollectors

struct ProfileRow: Identifiable {
    let id: String
    let cells: [String]
}

struct ProfileLiveModel {
    let title: String
    let summary: String
    let freshness: String
    let availability: String?
    let readings: [OverviewReading]
    let columns: [String]
    let rows: [ProfileRow]
    let emptyRows: String?
}

enum ProfilePresentation {
    static func model(for profile: Profile, snapshot: LiveSnapshot, now: Date = Date()) -> ProfileLiveModel {
        let overview = OverviewModel.from(snapshot: snapshot, now: now)
        switch profile {
        case .performance:
            return performance(snapshot: snapshot, freshness: overview.freshness)
        case .network:
            return network(snapshot: snapshot, freshness: overview.freshness)
        case .processes:
            return processes(snapshot: snapshot, freshness: overview.freshness)
        case .storage:
            return storage(snapshot: snapshot, freshness: overview.freshness)
        case .power:
            return power(snapshot: snapshot, freshness: overview.freshness, readings: overview.readings)
        default:
            return ProfileLiveModel(
                title: profile.rawValue,
                summary: profile.placeholderSummary,
                freshness: overview.freshness,
                availability: nil,
                readings: [],
                columns: [],
                rows: [],
                emptyRows: nil
            )
        }
    }

    private static func performance(snapshot: LiveSnapshot, freshness: String) -> ProfileLiveModel {
        let system = systemEntity(in: snapshot)
        let cpu = system.flatMap { snapshot.metric(named: .cpuUtilizationRatio, entity: $0) }
        let used = system.flatMap { snapshot.metric(named: .memoryUsedBytes, entity: $0) }
        let total = system.flatMap { snapshot.metric(named: .memoryTotalBytes, entity: $0) }
        let wired = system.flatMap { snapshot.metric(named: .memoryWiredBytes, entity: $0) }
        let compressed = system.flatMap { snapshot.metric(named: .memoryCompressedBytes, entity: $0) }
        let swap = system.flatMap { snapshot.metric(named: .memorySwapUsedBytes, entity: $0) }
        let pressure = system.flatMap { snapshot.metric(named: .memoryPressureState, entity: $0) }
        let thermal = system.flatMap { snapshot.metric(named: .thermalState, entity: $0) }

        var readings: [OverviewReading] = []
        readings.append(tile("CPU", cpu, "cpu", pending: "Waiting for host CPU", availability: snapshot.availability["standard.cpu_memory"]))
        readings.append(tile("Memory", used, "memorychip", pending: "Waiting for VM statistics", availability: snapshot.availability["standard.cpu_memory"]))
        readings.append(tile("Pressure", pressure, "gauge.with.dots.needle.33percent", pending: "Waiting for pressure", availability: snapshot.availability["standard.cpu_memory"]))
        readings.append(tile("Thermal", thermal, "thermometer.medium", pending: "Waiting for thermal", availability: snapshot.availability["standard.cpu_memory"]))

        let rows: [ProfileRow] = [
            ProfileRow(id: "used", cells: ["Used", used.map(MetricFormatter.displayString) ?? "unavailable"]),
            ProfileRow(id: "total", cells: ["Total", total.map(MetricFormatter.displayString) ?? "unavailable"]),
            ProfileRow(id: "wired", cells: ["Wired", wired.map(MetricFormatter.displayString) ?? "unavailable"]),
            ProfileRow(id: "compressed", cells: ["Compressed", compressed.map(MetricFormatter.displayString) ?? "unavailable"]),
            ProfileRow(id: "swap", cells: ["Swap", swap.map(MetricFormatter.displayString) ?? "unavailable"])
        ]

        return ProfileLiveModel(
            title: "Performance",
            summary: "Host CPU, memory, and thermal from Mach and ProcessInfo.",
            freshness: freshness,
            availability: availability(snapshot, prefix: "standard.cpu"),
            readings: readings,
            columns: ["Breakdown", "Value"],
            rows: rows,
            emptyRows: nil
        )
    }

    private static func network(snapshot: LiveSnapshot, freshness: String) -> ProfileLiveModel {
        let rx = snapshot.metrics.filter { $0.name == .networkRxBytesPerSecond }
        let tx = snapshot.metrics.filter { $0.name == .networkTxBytesPerSecond }
        let names = Set(rx.map(\.entity.identityKey) + tx.map(\.entity.identityKey)).sorted()

        let rows = names.map { key in
            let receive = rx.first { $0.entity.identityKey == key }
            let transmit = tx.first { $0.entity.identityKey == key }
            let title: String
            if let entity = receive?.entity ?? transmit?.entity, case .networkInterface(let name, _) = entity {
                title = name
            } else {
                title = key
            }
            return ProfileRow(
                id: key,
                cells: [
                    title,
                    receive.map(MetricFormatter.displayString) ?? "unavailable",
                    transmit.map(MetricFormatter.displayString) ?? "unavailable"
                ]
            )
        }
        let totalRX = rx.reduce(0.0) { $0 + numeric($1) }
        let totalTX = tx.reduce(0.0) { $0 + numeric($1) }
        let networkAvailability = snapshot.availability["standard.network"]
        let readings = [
            OverviewReading(
                name: "Receive",
                value: rx.isEmpty ? placeholderValue(networkAvailability) : rateString(totalRX, sample: rx.first),
                detail: "Sum of link counters",
                symbol: "arrow.down.right",
                tint: AppTheme.Color.accent,
                kind: rx.isEmpty ? placeholderKind(networkAvailability) : .live
            ),
            OverviewReading(
                name: "Transmit",
                value: tx.isEmpty ? placeholderValue(networkAvailability) : rateString(totalTX, sample: tx.first),
                detail: "Not per-process",
                symbol: "arrow.up.right",
                tint: AppTheme.Color.accent,
                kind: tx.isEmpty ? placeholderKind(networkAvailability) : .live
            )
        ]

        return ProfileLiveModel(
            title: "Network",
            summary: "Interface throughput from getifaddrs. Loopback is omitted.",
            freshness: freshness,
            availability: availability(snapshot, prefix: "standard.network"),
            readings: readings,
            columns: ["Interface", "Receive", "Transmit"],
            rows: rows,
            emptyRows: nil
        )
    }

    private static func processes(snapshot: LiveSnapshot, freshness: String) -> ProfileLiveModel {
        let processList = OverviewModel.processRows(from: snapshot, limit: PanelLayout.tableRowCountProcesses, pad: false)
        let rows = processList.map {
            ProfileRow(id: $0.id, cells: [$0.name, $0.cpu, $0.memory, $0.network])
        }
        return ProfileLiveModel(
            title: "Processes",
            summary: "Top processes by CPU, identified by PID plus start time plus boot.",
            freshness: freshness,
            availability: availability(snapshot, prefix: "standard.processes"),
            readings: [],
            columns: ["Process", "CPU", "Memory", "Network"],
            rows: rows,
            emptyRows: nil
        )
    }

    private static func storage(snapshot: LiveSnapshot, freshness: String) -> ProfileLiveModel {
        let capacity = snapshot.metrics.first { $0.name == .storageCapacityBytes }
        let available = snapshot.metrics.first { $0.name == .storageAvailableBytes }
        let read = snapshot.metrics.filter { $0.name == .storageReadBytesPerSecond }
        let write = snapshot.metrics.filter { $0.name == .storageWriteBytesPerSecond }

        var readings: [OverviewReading] = []
        readings.append(tile("Capacity", capacity, "internaldrive", pending: "Waiting for root volume", availability: snapshot.availability["standard.storage"]))
        readings.append(tile("Available", available, "internaldrive.fill", pending: "Waiting for free space", availability: snapshot.availability["standard.storage"]))
        readings.append(
            OverviewReading(
                name: "Read",
                value: read.isEmpty ? placeholderValue(snapshot.availability["standard.storage"]) : rateString(read.reduce(0.0) { $0 + numeric($1) }, sample: read.first),
                detail: "IOBlockStorageDriver when present",
                symbol: "arrow.down",
                tint: AppTheme.Color.accent,
                kind: read.isEmpty ? placeholderKind(snapshot.availability["standard.storage"]) : .live
            )
        )
        readings.append(
            OverviewReading(
                name: "Write",
                value: write.isEmpty ? placeholderValue(snapshot.availability["standard.storage"]) : rateString(write.reduce(0.0) { $0 + numeric($1) }, sample: write.first),
                detail: "Second sample produces rates",
                symbol: "arrow.up",
                tint: AppTheme.Color.accent,
                kind: write.isEmpty ? placeholderKind(snapshot.availability["standard.storage"]) : .live
            )
        )

        return ProfileLiveModel(
            title: "Storage",
            summary: "Root volume capacity and system block I/O.",
            freshness: freshness,
            availability: availability(snapshot, prefix: "standard.storage"),
            readings: readings,
            columns: [],
            rows: [],
            emptyRows: nil
        )
    }

    private static func power(
        snapshot: LiveSnapshot,
        freshness: String,
        readings overviewReadings: [OverviewReading]
    ) -> ProfileLiveModel {
        let system = systemEntity(in: snapshot)
        let battery = system.flatMap { snapshot.metric(named: .powerBatteryChargeRatio, entity: $0) }
        let watts = system.flatMap { snapshot.metric(named: .powerLoadWatts, entity: $0) }
        let thermal = overviewReadings.first { $0.name == "Thermal" }
        var readings: [OverviewReading] = []
        if let battery {
            readings.append(OverviewReading(
                name: "Battery",
                value: MetricFormatter.displayString(for: battery),
                detail: "Charge remaining",
                symbol: "battery.100",
                tint: AppTheme.Color.accent,
                kind: .live,
                inspect: .from(title: "Battery", metric: battery)
            ))
        }
        if let watts {
            readings.append(OverviewReading(
                name: "Power",
                value: MetricFormatter.displayString(for: watts),
                detail: "Estimated from voltage and current",
                symbol: "bolt",
                tint: AppTheme.Color.accent,
                kind: .live,
                inspect: .from(title: "Power", metric: watts)
            ))
        }
        if readings.isEmpty {
            readings.append(contentsOf: overviewReadings.filter { $0.name == "Power" })
        }
        if let thermal {
            readings.append(thermal)
        }
        return ProfileLiveModel(
            title: "Power",
            summary: "Battery charge and estimated load when IOKit publishes voltage and current.",
            freshness: freshness,
            availability: availability(snapshot, prefix: "standard.power"),
            readings: readings,
            columns: [],
            rows: [],
            emptyRows: nil
        )
    }

    private static func systemEntity(in snapshot: LiveSnapshot) -> Entity? {
        snapshot.metrics.compactMap { metric -> Entity? in
            if case .system = metric.entity { return metric.entity }
            return nil
        }.first
    }

    private static func tile(
        _ name: String,
        _ metric: Metric?,
        _ symbol: String,
        pending: String,
        availability: CapabilityAvailability?
    ) -> OverviewReading {
        let readingKind = placeholderKind(availability, hasMetric: metric != nil)
        let value: String
        switch readingKind {
        case .pending: value = ""
        case .unavailable: value = ""
        case .live: value = metric.map(MetricFormatter.displayString) ?? ""
        }
        return OverviewReading(
            name: name,
            value: value,
            detail: metric == nil ? pending : "Direct sample",
            symbol: symbol,
            tint: AppTheme.Color.accent,
            kind: readingKind,
            inspect: .from(title: name, metric: metric)
        )
    }

    private static func placeholderKind(
        _ availability: CapabilityAvailability?,
        hasMetric: Bool = false
    ) -> OverviewReading.Kind {
        if case .unavailable = availability { return .unavailable }
        if hasMetric { return .live }
        return .pending
    }

    private static func placeholderValue(_ availability: CapabilityAvailability?) -> String {
        placeholderKind(availability) == .unavailable ? "unavailable" : ""
    }

    private static func numeric(_ metric: Metric) -> Double {
        switch metric.value {
        case .double(let value): value
        case .int(let value): Double(value)
        default: 0
        }
    }

    private static func rateString(_ total: Double, sample: Metric?) -> String {
        guard let sample else { return "" }
        let synthetic = Metric(
            time: sample.time,
            domain: sample.domain,
            name: sample.name,
            entity: sample.entity,
            value: .double(total),
            unit: .bytesPerSecond,
            source: sample.source,
            quality: .derived
        )
        return MetricFormatter.displayString(for: synthetic)
    }

    private static func availability(_ snapshot: LiveSnapshot, prefix: String) -> String? {
        for (key, value) in snapshot.availability where key.hasPrefix(prefix) {
            if case .unavailable(let reason) = value {
                return reason
            }
        }
        return nil
    }
}
