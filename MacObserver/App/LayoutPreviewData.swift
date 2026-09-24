import Foundation
import MacObserverCollectors
import MacObserverDomain

struct LayoutPreviewPayload {
    var startedAt: Date
    var snapshot: LiveSnapshot
    var capabilities: [CapabilityDescriptor]
    var events: [Event]
    var historyMetrics: [Metric]
}

enum LayoutPreviewData {
    static let boot = BootSessionID("preview-boot")
    static let system = Entity.system(bootSession: boot)
    private static let gigabyte: Int64 = 1_073_741_824

    static func make(now: Date = Date()) -> LayoutPreviewPayload {
        let wifi = Entity.networkInterface(name: "en0", hardwareID: "preview-en0")
        let ethernet = Entity.networkInterface(name: "en1", hardwareID: "preview-en1")
        let volume = Entity.volume(uuid: "preview-root")
        let ioVolume = Entity.volume(uuid: "system")
        let processes = processIdentities()

        var metrics: [Metric] = [
            metric(now, .cpu, .cpuUtilizationRatio, system, .ratio(0.38), .ratio, "standard.cpu_memory"),
            metric(now, .memory, .memoryUsedBytes, system, .int(18 * gigabyte), .bytes, "standard.cpu_memory"),
            metric(now, .memory, .memoryWiredBytes, system, .int(6 * gigabyte), .bytes, "standard.cpu_memory"),
            metric(now, .memory, .memoryCompressedBytes, system, .int(2 * gigabyte), .bytes, "standard.cpu_memory"),
            metric(now, .memory, .memorySwapUsedBytes, system, .int(gigabyte / 4), .bytes, "standard.cpu_memory"),
            metric(now, .memory, .memoryTotalBytes, system, .int(36 * gigabyte), .bytes, "standard.cpu_memory"),
            metric(now, .memory, .memoryPressureState, system, .state("normal"), .enumeration, "standard.cpu_memory"),
            metric(now, .thermal, .thermalState, system, .state("nominal"), .enumeration, "standard.cpu_memory"),
            metric(now, .network, .networkRxBytesPerSecond, wifi, .double(2_400_000), .bytesPerSecond, "standard.network", ["interface": "en0", "direction": "rx"]),
            metric(now, .network, .networkTxBytesPerSecond, wifi, .double(480_000), .bytesPerSecond, "standard.network", ["interface": "en0", "direction": "tx"]),
            metric(now, .network, .networkRxBytesPerSecond, ethernet, .double(12_000), .bytesPerSecond, "standard.network", ["interface": "en1", "direction": "rx"]),
            metric(now, .network, .networkTxBytesPerSecond, ethernet, .double(4_000), .bytesPerSecond, "standard.network", ["interface": "en1", "direction": "tx"]),
            metric(now, .network, .networkPrimaryInterface, system, .state("en0"), .enumeration, "standard.network"),
            metric(now, .network, .networkGatewayAddress, system, .state("192.168.1.1"), .enumeration, "standard.network"),
            metric(now, .network, .networkDNSResolverAddress, system, .state("1.1.1.1"), .enumeration, "standard.network"),
            metric(now, .network, .networkDNSResolverCount, system, .int(2), .count, "standard.network"),
            metric(now, .storage, .storageCapacityBytes, volume, .int(1_000 * gigabyte), .bytes, "standard.storage"),
            metric(now, .storage, .storageAvailableBytes, volume, .int(420 * gigabyte), .bytes, "standard.storage"),
            metric(now, .storage, .storageReadBytesPerSecond, ioVolume, .double(18_000_000), .bytesPerSecond, "standard.storage"),
            metric(now, .storage, .storageWriteBytesPerSecond, ioVolume, .double(6_200_000), .bytesPerSecond, "standard.storage"),
            metric(now, .power, .powerBatteryChargeRatio, system, .ratio(0.72), .ratio, "standard.power"),
            metric(now, .power, .powerLoadWatts, system, .double(14.2), .watts, "standard.power"),
            metric(now, .power, .powerBatteryCharging, system, .state("discharging"), .enumeration, "standard.power"),
            metric(now, .power, .powerTimeToEmptyMinutes, system, .int(248), .count, "standard.power")
        ]

        for process in processes {
            metrics.append(metric(
                now, .cpu, .cpuUtilizationRatio, .processInstance(process.identity),
                .ratio(process.cpu), .ratio, "standard.processes"
            ))
            metrics.append(metric(
                now, .memory, .processResidentBytes, .processInstance(process.identity),
                .int(process.resident), .bytes, "standard.processes"
            ))
        }

        let liveSeries = series(now: now, wifi: wifi, ioVolume: ioVolume)
        let history = historyMetrics(
            now: now,
            wifi: wifi,
            ioVolume: ioVolume,
            topProcess: processes[0].identity
        )
        let events = historyEvents(now: now, topProcess: processes[0].identity)

        return LayoutPreviewPayload(
            startedAt: now.addingTimeInterval(-3_600),
            snapshot: LiveSnapshot(
                metrics: metrics,
                events: Array(events.prefix(6)),
                availability: [
                    "standard.cpu_memory": .available,
                    "standard.processes": .available,
                    "standard.network": .available,
                    "standard.storage": .available,
                    "standard.power": .available,
                    ExternalDiagnosticsCollector.capabilityID: .unavailable(
                        reason: "Off until you turn it on and run a check."
                    )
                ],
                series: liveSeries,
                capturedAt: ObservationTime(wallTime: now)
            ),
            capabilities: StandardCollectors.make().map(\.capability),
            events: events,
            historyMetrics: history
        )
    }

    private static func processIdentities() -> [(identity: ProcessInstanceIdentity, cpu: Double, resident: Int64)] {
        let rows: [(String, Int32, Double, Int64)] = [
            ("Cursor", 4_821, 0.184, Int64(1.8 * Double(gigabyte))),
            ("Google Chrome", 1_204, 0.121, Int64(2.4 * Double(gigabyte))),
            ("WindowServer", 353, 0.082, 420 * 1_048_576),
            ("node", 6_640, 0.064, 380 * 1_048_576),
            ("Safari", 2_188, 0.041, 890 * 1_048_576),
            ("Slack", 3_901, 0.032, 640 * 1_048_576),
            ("kernel_task", 0, 0.028, Int64(1.1 * Double(gigabyte))),
            ("Docker", 5_512, 0.021, 720 * 1_048_576),
            ("Music", 8_044, 0.014, 210 * 1_048_576),
            ("Finder", 412, 0.008, 180 * 1_048_576),
            ("Spotlight", 377, 0.006, 95 * 1_048_576),
            ("Terminal", 9_331, 0.004, 48 * 1_048_576)
        ]
        return rows.enumerated().map { index, row in
            let identity = ProcessInstanceIdentity(
                pid: row.1,
                startNanoseconds: UInt64(index + 1) * 1_000_000_000,
                bootSession: boot,
                attributes: ProcessAttributes(displayName: row.0)
            )
            return (identity, row.2, row.3)
        }
    }

    private static func series(
        now: Date,
        wifi: Entity,
        ioVolume: Entity
    ) -> [String: [SamplePoint]] {
        [
            key(.cpuUtilizationRatio, system): wave(now, count: 60, step: 1.5, base: 0.28, amplitude: 0.16),
            key(.memoryUsedBytes, system): wave(now, count: 60, step: 1.5, base: Double(18 * gigabyte), amplitude: Double(gigabyte)),
            key(.networkRxBytesPerSecond, wifi): wave(now, count: 60, step: 1.5, base: 1_800_000, amplitude: 1_400_000),
            key(.networkTxBytesPerSecond, wifi): wave(now, count: 60, step: 1.5, base: 320_000, amplitude: 220_000),
            key(.storageReadBytesPerSecond, ioVolume): wave(now, count: 60, step: 1.5, base: 12_000_000, amplitude: 8_000_000),
            key(.storageWriteBytesPerSecond, ioVolume): wave(now, count: 60, step: 1.5, base: 4_000_000, amplitude: 3_200_000)
        ]
    }

    private static func historyMetrics(
        now: Date,
        wifi: Entity,
        ioVolume: Entity,
        topProcess: ProcessInstanceIdentity
    ) -> [Metric] {
        let process = Entity.processInstance(topProcess)
        var rows: [Metric] = []
        for index in 0..<60 {
            let time = now.addingTimeInterval(Double(index - 59) * 60)
            let phase = Double(index) / 9
            rows.append(metric(time, .cpu, .cpuUtilizationRatio, system, .ratio(0.28 + 0.16 * sine(phase)), .ratio, "standard.cpu_memory"))
            rows.append(metric(time, .memory, .memoryUsedBytes, system, .int(Int64(Double(18 * gigabyte) + Double(gigabyte) * sine(phase))), .bytes, "standard.cpu_memory"))
            rows.append(metric(time, .power, .powerBatteryChargeRatio, system, .ratio(0.78 - Double(index) * 0.001), .ratio, "standard.power"))
            rows.append(metric(time, .power, .powerLoadWatts, system, .double(12.4 + 3.1 * sine(phase)), .watts, "standard.power"))
            rows.append(metric(time, .network, .networkRxBytesPerSecond, wifi, .double(1_800_000 + 1_400_000 * abs(sine(phase))), .bytesPerSecond, "standard.network"))
            rows.append(metric(time, .storage, .storageReadBytesPerSecond, ioVolume, .double(12_000_000 + 8_000_000 * abs(sine(phase + 1))), .bytesPerSecond, "standard.storage"))
            rows.append(metric(time, .cpu, .cpuUtilizationRatio, process, .ratio(0.12 + 0.08 * abs(sine(phase))), .ratio, "standard.processes"))
            rows.append(metric(time, .memory, .processResidentBytes, process, .int(Int64(1.6 * Double(gigabyte) + 0.3 * Double(gigabyte) * sine(phase))), .bytes, "standard.processes"))
        }
        return rows
    }

    private static func historyEvents(now: Date, topProcess: ProcessInstanceIdentity) -> [Event] {
        [
            event(now.addingTimeInterval(-8 * 60), .memory, .memoryPressureChanged, system, "Memory pressure changed from warning to normal.", "standard.cpu_memory", ["from": "warning", "to": "normal"]),
            event(now.addingTimeInterval(-22 * 60), .thermal, .thermalStateChanged, system, "Thermal state changed from fair to nominal.", "standard.cpu_memory", ["from": "fair", "to": "nominal"]),
            event(now.addingTimeInterval(-36 * 60), .network, .networkConfigurationChanged, system, "Local network path changed.", "standard.network", ["primary": "en0", "dns_count": "2"], .identifyingDeviceContext),
            event(now.addingTimeInterval(-48 * 60), .capability, .capabilityAvailabilityChanged, .capability(id: "standard.network"), "standard.network started collecting.", "capabilities", ["capability": "standard.network", "enabled": "true"]),
            event(now.addingTimeInterval(-3 * 3_600), .memory, .memoryPressureChanged, system, "Memory pressure changed from normal to warning.", "standard.cpu_memory", ["from": "normal", "to": "warning"]),
            event(now.addingTimeInterval(-5 * 3_600), .thermal, .thermalStateChanged, system, "Thermal state changed from nominal to fair.", "standard.cpu_memory", ["from": "nominal", "to": "fair"]),
            event(now.addingTimeInterval(-9 * 3_600), .system, .explanationGenerated, system, "Memory pressure became warning. Cursor resident size was elevated.", "explanation.rules", ["explanation_id": "preview.memory", "rule_id": ExplanationRules.memoryRuleID, "detected_state": "attention", "threshold": "memory.pressure_state in warning"]),
            event(now.addingTimeInterval(-26 * 3_600), .network, .networkExternalLookup, system, "Internet check completed.", "external.internet", ["endpoint": "1.1.1.1"], .identifyingDeviceContext),
            event(now.addingTimeInterval(-2 * 24 * 3_600), .capability, .capabilityAvailabilityChanged, .capability(id: ExternalDiagnosticsCollector.capabilityID), "external.internet was disabled in Capabilities.", "capabilities", ["capability": ExternalDiagnosticsCollector.capabilityID, "enabled": "false"]),
            event(now.addingTimeInterval(-4 * 24 * 3_600), .process, .processLaunched, .processInstance(topProcess), "Cursor launched.", "standard.processes", ["pid": "4821"])
        ]
    }

    private static func wave(
        _ now: Date,
        count: Int,
        step: TimeInterval,
        base: Double,
        amplitude: Double
    ) -> [SamplePoint] {
        (0..<count).map { index in
            let time = now.addingTimeInterval(Double(index - count + 1) * step)
            return SamplePoint(time: time, value: base + amplitude * sine(Double(index) / 8))
        }
    }

    private static func sine(_ phase: Double) -> Double {
        sin(phase)
    }

    private static func key(_ name: MetricName, _ entity: Entity) -> String {
        "\(name.rawValue)|\(entity.identityKey)"
    }

    private static func metric(
        _ time: Date,
        _ domain: TelemetryDomain,
        _ name: MetricName,
        _ entity: Entity,
        _ value: MetricValue,
        _ unit: MacObserverDomain.Unit,
        _ source: String,
        _ dimensions: [String: String] = [:]
    ) -> Metric {
        Metric(
            time: ObservationTime(wallTime: time),
            domain: domain,
            name: name,
            entity: entity,
            value: value,
            unit: unit,
            dimensions: dimensions,
            source: source,
            quality: .direct
        )
    }

    private static func event(
        _ time: Date,
        _ domain: TelemetryDomain,
        _ type: EventType,
        _ entity: Entity,
        _ summary: String,
        _ source: String,
        _ metadata: [String: String] = [:],
        _ privacy: PrivacyClass = .operational
    ) -> Event {
        Event(
            time: ObservationTime(wallTime: time),
            domain: domain,
            type: type,
            entity: entity,
            summary: summary,
            metadata: metadata,
            source: source,
            quality: .direct,
            privacyClass: privacy
        )
    }
}
