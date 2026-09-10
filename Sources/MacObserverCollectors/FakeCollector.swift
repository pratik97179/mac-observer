import MacObserverDomain

public actor FakeCollector: TelemetryCollector {
    public nonisolated let capability: CapabilityDescriptor

    private let clock: FakeClock
    private var sink: (any TelemetrySink)?
    private var initial: [TelemetryObservation]

    public init(
        capability: CapabilityDescriptor = CapabilityDescriptor(
            id: "fake.standard",
            title: "Fake Collector",
            accessLevel: .standard,
            domains: [.cpu],
            summary: "Test collector. Emits configured observations only."
        ),
        clock: FakeClock,
        initial: [TelemetryObservation] = []
    ) {
        self.capability = capability
        self.clock = clock
        self.initial = initial
    }

    public func start(sink: any TelemetrySink) async throws {
        self.sink = sink
        for observation in initial {
            await sink.send(stamped(observation))
        }
    }

    public func stop() async {
        sink = nil
    }

    public func emit(_ observation: TelemetryObservation) async {
        guard let sink else { return }
        await sink.send(stamped(observation))
    }

    private func stamped(_ observation: TelemetryObservation) -> TelemetryObservation {
        switch observation {
        case .metric(let metric):
            .metric(metric.replacing(time: clock.observationTime))
        case .event(let event):
            .event(event)
        case .availability(let capabilityID, let state):
            .availability(capabilityID: capabilityID, state)
        }
    }
}

public actor CollectorPipeline {
    private let collectors: [any TelemetryCollector]
    public let buffer: LiveTelemetryBuffer

    public init(collectors: [any TelemetryCollector], buffer: LiveTelemetryBuffer = LiveTelemetryBuffer()) {
        self.collectors = collectors
        self.buffer = buffer
    }

    public func start() async throws {
        for collector in collectors {
            try await collector.start(sink: buffer)
        }
    }

    public func stop() async {
        for collector in collectors {
            await collector.stop()
        }
    }

    public func snapshot() async -> LiveSnapshot {
        await buffer.snapshot()
    }
}
