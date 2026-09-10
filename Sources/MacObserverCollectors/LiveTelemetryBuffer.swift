import MacObserverDomain

public struct LiveSnapshot: Sendable, Equatable {
    public var metrics: [Metric]
    public var events: [Event]
    public var availability: [String: CapabilityAvailability]
    public var capturedAt: ObservationTime

    public func metric(named name: MetricName, entity: Entity) -> Metric? {
        metrics.first { $0.name == name && $0.entity == entity }
    }
}

public actor LiveTelemetryBuffer: TelemetrySink {
    private var metrics: [String: Metric] = [:]
    private var events: [Event] = []
    private var availability: [String: CapabilityAvailability] = [:]
    private let clock: any Clock
    private let eventLimit: Int

    public init(clock: any Clock = SystemClock(), eventLimit: Int = 200) {
        self.clock = clock
        self.eventLimit = eventLimit
    }

    public func send(_ observation: TelemetryObservation) async {
        switch observation {
        case .metric(let metric):
            metrics[Self.key(for: metric)] = metric
        case .event(let event):
            events.append(event)
            if events.count > eventLimit {
                events.removeFirst(events.count - eventLimit)
            }
        case .availability(let capabilityID, let state):
            availability[capabilityID] = state
        }
    }

    public func snapshot() -> LiveSnapshot {
        LiveSnapshot(
            metrics: Array(metrics.values),
            events: events,
            availability: availability,
            capturedAt: clock.observationTime
        )
    }

    private static func key(for metric: Metric) -> String {
        "\(metric.name.rawValue)|\(metric.entity.identityKey)"
    }
}
