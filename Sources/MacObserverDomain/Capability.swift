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

    public init(
        id: String,
        title: String,
        accessLevel: AccessLevel,
        domains: [TelemetryDomain],
        summary: String
    ) {
        self.id = id
        self.title = title
        self.accessLevel = accessLevel
        self.domains = domains
        self.summary = summary
    }
}

public enum CapabilityAvailability: Sendable, Hashable, Codable {
    case available
    case unavailable(reason: String)
    case denied
    case stale(asOf: Date)
}
