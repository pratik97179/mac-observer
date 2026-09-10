import MacObserverDomain

public enum TelemetryObservation: Sendable, Hashable {
    case metric(Metric)
    case event(Event)
    case availability(capabilityID: String, CapabilityAvailability)
}

public protocol TelemetrySink: Sendable {
    func send(_ observation: TelemetryObservation) async
}

public protocol TelemetryCollector: Sendable {
    var capability: CapabilityDescriptor { get }
    func start(sink: any TelemetrySink) async throws
    func stop() async
}
