import Foundation

public struct Event: Sendable, Identifiable, Hashable, Codable {
    public let id: UUID
    public let time: ObservationTime
    public let domain: TelemetryDomain
    public let type: EventType
    public let entity: Entity
    public let relatedEntities: [Entity]
    public let summary: String
    public let metadata: [String: String]
    public let source: String
    public let quality: ObservationQuality
    public let privacyClass: PrivacyClass

    public init(
        id: UUID = UUID(),
        time: ObservationTime,
        domain: TelemetryDomain,
        type: EventType,
        entity: Entity,
        relatedEntities: [Entity] = [],
        summary: String,
        metadata: [String: String] = [:],
        source: String,
        quality: ObservationQuality,
        privacyClass: PrivacyClass
    ) {
        self.id = id
        self.time = time
        self.domain = domain
        self.type = type
        self.entity = entity
        self.relatedEntities = relatedEntities
        self.summary = summary
        self.metadata = metadata
        self.source = source
        self.quality = quality
        self.privacyClass = privacyClass
    }
}

public struct EventType: Sendable, Hashable, Codable, RawRepresentable {
    public let rawValue: String

    public init?(rawValue: String) {
        guard MetricName.isValid(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public static let processLaunched = EventType(valid: "process.launched")
    public static let capabilityAvailabilityChanged = EventType(valid: "capability.availability_changed")
    public static let memoryPressureChanged = EventType(valid: "memory.pressure_changed")
    public static let thermalStateChanged = EventType(valid: "thermal.state_changed")
    public static let explanationGenerated = EventType(valid: "explanation.generated")
    public static let networkExternalLookup = EventType(valid: "network.external_lookup")
    public static let networkConfigurationChanged = EventType(valid: "network.configuration_changed")

    private init(valid rawValue: String) {
        self.rawValue = rawValue
    }
}
