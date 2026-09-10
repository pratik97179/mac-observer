import Foundation

public enum Unit: String, Sendable, Codable, Hashable {
    case ratio
    case bytes
    case bytesPerSecond
    case watts
    case count
    case nanoseconds
    case celsius
    case enumeration
}

public enum MetricValue: Sendable, Hashable, Codable {
    case ratio(Double)
    case int(Int64)
    case double(Double)
    case state(String)
}

public struct MetricName: Sendable, Hashable, Codable, RawRepresentable {
    public let rawValue: String

    public init?(rawValue: String) {
        guard Self.isValid(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public static let cpuUtilizationRatio = MetricName(valid: "cpu.utilization_ratio")
    public static let memoryUsedBytes = MetricName(valid: "memory.used_bytes")
    public static let memoryWiredBytes = MetricName(valid: "memory.wired_bytes")
    public static let memoryCompressedBytes = MetricName(valid: "memory.compressed_bytes")
    public static let memorySwapUsedBytes = MetricName(valid: "memory.swap_used_bytes")
    public static let memoryTotalBytes = MetricName(valid: "memory.total_bytes")
    public static let memoryPressureState = MetricName(valid: "memory.pressure_state")
    public static let networkRxBytesPerSecond = MetricName(valid: "network.rx_bytes_per_second")
    public static let networkTxBytesPerSecond = MetricName(valid: "network.tx_bytes_per_second")
    public static let storageWriteBytesPerSecond = MetricName(valid: "storage.write_bytes_per_second")
    public static let storageReadBytesPerSecond = MetricName(valid: "storage.read_bytes_per_second")
    public static let storageCapacityBytes = MetricName(valid: "storage.capacity_bytes")
    public static let storageAvailableBytes = MetricName(valid: "storage.available_bytes")
    public static let processResidentBytes = MetricName(valid: "process.resident_bytes")
    public static let powerBatteryChargeRatio = MetricName(valid: "power.battery_charge_ratio")
    public static let powerLoadWatts = MetricName(valid: "power.load_watts")
    public static let thermalState = MetricName(valid: "thermal.state")

    public static func isValid(_ rawValue: String) -> Bool {
        let parts = rawValue.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return false }
        return rawValue.allSatisfy { character in
            character.isASCII && (character.isLowercase || character.isNumber || character == "." || character == "_")
        }
    }

    private init(valid rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct Derivation: Sendable, Hashable, Codable {
    public let sourceMetricIDs: [UUID]
    public let method: String

    public init(sourceMetricIDs: [UUID], method: String) {
        self.sourceMetricIDs = sourceMetricIDs
        self.method = method
    }
}

public struct Metric: Sendable, Identifiable, Hashable, Codable {
    public let id: UUID
    public let time: ObservationTime
    public let domain: TelemetryDomain
    public let name: MetricName
    public let entity: Entity
    public let value: MetricValue
    public let unit: Unit
    public let dimensions: [String: String]
    public let source: String
    public let quality: ObservationQuality
    public let retentionClass: RetentionClass
    public let derivation: Derivation?

    public init(
        id: UUID = UUID(),
        time: ObservationTime,
        domain: TelemetryDomain,
        name: MetricName,
        entity: Entity,
        value: MetricValue,
        unit: Unit,
        dimensions: [String: String] = [:],
        source: String,
        quality: ObservationQuality,
        retentionClass: RetentionClass = .live,
        derivation: Derivation? = nil
    ) {
        self.id = id
        self.time = time
        self.domain = domain
        self.name = name
        self.entity = entity
        self.value = value
        self.unit = unit
        self.dimensions = dimensions
        self.source = source
        self.quality = quality
        self.retentionClass = retentionClass
        self.derivation = derivation
    }

    public func replacing(
        time: ObservationTime? = nil,
        quality: ObservationQuality? = nil
    ) -> Metric {
        Metric(
            id: id,
            time: time ?? self.time,
            domain: domain,
            name: name,
            entity: entity,
            value: value,
            unit: unit,
            dimensions: dimensions,
            source: source,
            quality: quality ?? self.quality,
            retentionClass: retentionClass,
            derivation: derivation
        )
    }
}

public enum MetricFormatter {
    public static func displayString(for metric: Metric) -> String {
        switch (metric.value, metric.unit) {
        case (.ratio(let ratio), .ratio):
            "\(Int((ratio * 100).rounded()))%"
        case (.int(let value), .bytes):
            byteString(Double(value))
        case (.double(let value), .bytes):
            byteString(value)
        case (.int(let value), .bytesPerSecond):
            "\(byteString(Double(value)))/s"
        case (.double(let value), .bytesPerSecond):
            "\(byteString(value))/s"
        case (.double(let value), .watts):
            "\(value.formatted(.number.precision(.fractionLength(1)))) W"
        case (.int(let value), .count):
            value.formatted(.number)
        case (.state(let state), .enumeration):
            state
        default:
            String(describing: metric.value)
        }
    }

    private static func byteString(_ value: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(value))
    }
}
