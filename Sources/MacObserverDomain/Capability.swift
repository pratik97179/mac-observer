import Foundation

public enum AccessLevel: String, Sendable, Codable, Hashable {
    case standard
    case privileged
    case external
}

public struct CapabilityDescriptor: Sendable, Hashable, Codable, Identifiable {
    public let id: String
    public let title: String
    public let accessLevel: AccessLevel
    public let domains: [TelemetryDomain]
    public let summary: String
    public let collectionMethod: String
    public let remainsLocal: Bool
    public let privacyClass: PrivacyClass
    public let defaultEnabled: Bool

    public init(
        id: String,
        title: String,
        accessLevel: AccessLevel,
        domains: [TelemetryDomain],
        summary: String,
        collectionMethod: String = "Public macOS APIs on this Mac.",
        remainsLocal: Bool = true,
        privacyClass: PrivacyClass = .operational,
        defaultEnabled: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.accessLevel = accessLevel
        self.domains = domains
        self.summary = summary
        self.collectionMethod = collectionMethod
        self.remainsLocal = remainsLocal
        self.privacyClass = privacyClass
        self.defaultEnabled = defaultEnabled ?? (accessLevel == .standard)
    }
}

public enum CapabilityAvailability: Sendable, Hashable, Codable {
    case available
    case unavailable(reason: String)
    case denied
    case stale(asOf: Date)
}

public enum CapabilityPolicy {
    public static func enabledIDs(
        capabilities: [CapabilityDescriptor],
        disabledStandard: Set<String>,
        enabledOptional: Set<String>
    ) -> Set<String> {
        Set(capabilities.compactMap { capability in
            if capability.defaultEnabled {
                return disabledStandard.contains(capability.id) ? nil : capability.id
            }
            return enabledOptional.contains(capability.id) ? capability.id : nil
        })
    }

    public static func isEnabled(
        _ capability: CapabilityDescriptor,
        disabledStandard: Set<String>,
        enabledOptional: Set<String>
    ) -> Bool {
        enabledIDs(
            capabilities: [capability],
            disabledStandard: disabledStandard,
            enabledOptional: enabledOptional
        ).contains(capability.id)
    }
}
