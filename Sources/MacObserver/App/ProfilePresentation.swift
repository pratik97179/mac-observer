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
        readings.append(tile("CPU", cpu, "cpu", .blue, missing: "Waiting for host CPU"))
        readings.append(tile("Memory", used, "memorychip", .indigo, missing: "Waiting for VM statistics"))
        readings.append(tile("Pressure", pressure, "gauge.with.dots.needle.33percent", .purple, missing: "Pressure unavailable"))
        readings.append(tile("Thermal", thermal, "thermometer.medium", .green, missing: "Thermal unavailable"))

        let rows: [ProfileRow] = [
            ProfileRow(id: "used", cells: ["Used", used.map(MetricFormatter.displayString) ?? "—"]),
            ProfileRow(id: "total", cells: ["Total", total.map(MetricFormatter.displayString) ?? "—"]),
            ProfileRow(id: "wired", cells: ["Wired", wired.map(MetricFormatter.displayString) ?? "—"]),
            ProfileRow(id: "compressed", cells: ["Compressed", compressed.map(MetricFormatter.displayString) ?? "—"]),
            ProfileRow(id: "swap", cells: ["Swap", swap.map(MetricFormatter.displayString) ?? "—"])
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
                    receive.map(MetricFormatter.displayString) ?? "—",
                    transmit.map(MetricFormatter.displayString) ?? "—"
                ]
            )
        }

        let totalRX = rx.reduce(0.0) { $0 + numeric($1) }
        let totalTX = tx.reduce(0.0) { $0 + numeric($1) }
        let readings = [
            OverviewReading(
                name: "Receive",
                value: rx.isEmpty ? "Unavailable" : rateString(totalRX, sample: rx.first),
                detail: "Sum of link counters",
                symbol: "arrow.down.right",
                tint: .cyan
            ),
            OverviewReading(
                name: "Transmit",
                value: tx.isEmpty ? "Unavailable" : rateString(totalTX, sample: tx.first),
                detail: "Not per-process",
                symbol: "arrow.up.right",
                tint: .blue
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
            emptyRows: rows.isEmpty ? "Waiting for interface counters. The second sample produces rates." : nil
        )
    }

    private static func processes(snapshot: LiveSnapshot, freshness: String) -> ProfileLiveModel {
        let processList = OverviewModel.processRows(from: snapshot, limit: 20)
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
            emptyRows: rows.isEmpty ? "Waiting for process samples." : nil
        )
    }

    private static func storage(snapshot: LiveSnapshot, freshness: String) -> ProfileLiveModel {
        let capacity = snapshot.metrics.first { $0.name == .storageCapacityBytes }
        let available = snapshot.metrics.first { $0.name == .storageAvailableBytes }
        let read = snapshot.metrics.filter { $0.name == .storageReadBytesPerSecond }
        let write = snapshot.metrics.filter { $0.name == .storageWriteBytesPerSecond }

        var readings: [OverviewReading] = []
        readings.append(tile("Capacity", capacity, "internaldrive", .orange, missing: "Root volume unavailable"))
        readings.append(tile("Available", available, "internaldrive.fill", .yellow, missing: "Free space unavailable"))
        readings.append(
            OverviewReading(
                name: "Read",
                value: read.isEmpty ? "Unavailable" : rateString(read.reduce(0.0) { $0 + numeric($1) }, sample: read.first),
                detail: "IOBlockStorageDriver when present",
                symbol: "arrow.down",
                tint: .orange
            )
        )
        readings.append(
            OverviewReading(
                name: "Write",
                value: write.isEmpty ? "Unavailable" : rateString(write.reduce(0.0) { $0 + numeric($1) }, sample: write.first),
                detail: "Second sample produces rates",
                symbol: "arrow.up",
                tint: .red
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
        let powerTiles = overviewReadings.filter { $0.name == "Power" || $0.name == "Thermal" }
        return ProfileLiveModel(
            title: "Power",
            summary: "Battery charge and estimated load when IOKit publishes voltage and current.",
            freshness: freshness,
            availability: availability(snapshot, prefix: "standard.power"),
            readings: powerTiles,
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
        _ tint: Color,
        missing: String
    ) -> OverviewReading {
        OverviewReading(
            name: name,
            value: metric.map(MetricFormatter.displayString) ?? "Unavailable",
            detail: metric == nil ? missing : "Direct sample",
            symbol: symbol,
            tint: tint,
            inspect: .from(title: name, metric: metric)
        )
    }

    private static func numeric(_ metric: Metric) -> Double {
        switch metric.value {
        case .double(let value): value
        case .int(let value): Double(value)
        default: 0
        }
    }

    private static func rateString(_ total: Double, sample: Metric?) -> String {
        guard let sample else { return "Unavailable" }
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
