public enum HealthState: String, Sendable, Hashable {
    case healthy = "Healthy"
    case attention = "Attention"
    case investigate = "Investigate"
}

public struct HealthAssessment: Sendable, Equatable {
    public let state: HealthState
    public let detail: String

    public init(state: HealthState, detail: String) {
        self.state = state
        self.detail = detail
    }
}

public enum HealthRules {
    public static func assess(
        cpuRatio: Double?,
        memoryPressure: String?,
        thermal: String?,
        coreUnavailable: Bool,
        stale: Bool,
        hasAnySample: Bool
    ) -> HealthAssessment {
        if coreUnavailable {
            return HealthAssessment(state: .investigate, detail: "A core collector is unavailable.")
        }
        if !hasAnySample {
            return HealthAssessment(state: .attention, detail: "Waiting for the first live sample.")
        }
        if cpuRatio ?? 0 >= 0.95 || memoryPressure == "urgent" || memoryPressure == "critical"
            || thermal == "serious" || thermal == "critical" {
            return HealthAssessment(state: .investigate, detail: "A resource is under heavy pressure.")
        }
        if stale {
            return HealthAssessment(state: .attention, detail: "Readings are stale.")
        }
        if cpuRatio ?? 0 >= 0.80 || memoryPressure == "warning" || thermal == "fair" {
            return HealthAssessment(state: .attention, detail: "Load is elevated.")
        }
        return HealthAssessment(state: .healthy, detail: "Live")
    }
}
