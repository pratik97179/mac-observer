import Foundation

public enum TelemetryDomain: String, Sendable, Codable, Hashable {
    case cpu
    case memory
    case storage
    case network
    case power
    case thermal
    case process
    case capability
    case system
}

public enum ObservationQuality: String, Sendable, Codable, Hashable {
    case direct
    case derived
    case estimated
    case stale
    case unavailable
}

public enum RetentionClass: String, Sendable, Codable, Hashable {
    case live
    case recent
    case longTerm
    case discardable
}

public enum PrivacyClass: String, Sendable, Codable, Hashable {
    case operational
    case identifyingDeviceContext
    case sensitiveActivityMetadata
    case content
}

public struct ObservationTime: Sendable, Hashable, Codable {
    public let wallTime: Date
    public let monotonicNanoseconds: UInt64?

    public init(wallTime: Date, monotonicNanoseconds: UInt64? = nil) {
        self.wallTime = wallTime
        self.monotonicNanoseconds = monotonicNanoseconds
    }
}
