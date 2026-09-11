import MacObserverDomain

public actor CollectorPipeline {
    private let collectors: [any TelemetryCollector]
    public let buffer: LiveTelemetryBuffer
    private let additionalSinks: [any TelemetrySink]
    private var sink: (any TelemetrySink)?
    private var running: Set<String> = []

    public init(
        collectors: [any TelemetryCollector],
        buffer: LiveTelemetryBuffer = LiveTelemetryBuffer(),
        additionalSinks: [any TelemetrySink] = []
    ) {
        self.collectors = collectors
        self.buffer = buffer
        self.additionalSinks = additionalSinks
    }

    public func start(enabled: Set<String>? = nil) async throws {
        let resolved: any TelemetrySink
        if additionalSinks.isEmpty {
            resolved = buffer
        } else {
            resolved = FanoutTelemetrySink([buffer] + additionalSinks)
        }
        sink = resolved

        let allowed = enabled ?? Set(collectors.map(\.capability.id))
        for collector in collectors {
            let id = collector.capability.id
            if allowed.contains(id) {
                try await collector.start(sink: resolved)
                running.insert(id)
            } else {
                await sendDisabled(id: id, sink: resolved)
            }
        }
    }

    public func setEnabled(_ id: String, enabled: Bool) async throws {
        guard let collector = collectors.first(where: { $0.capability.id == id }), let sink else { return }
        if enabled {
            guard !running.contains(id) else { return }
            try await collector.start(sink: sink)
            running.insert(id)
            await sink.send(.event(EventFactory.capabilityAvailabilityChanged(
                clock: SystemClock(),
                capabilityID: id,
                enabled: true
            )))
        } else {
            guard running.contains(id) else { return }
            await collector.stop()
            running.remove(id)
            await sendDisabled(id: id, sink: sink)
        }
    }

    public func stop() async {
        for collector in collectors {
            await collector.stop()
        }
        running.removeAll()
        sink = nil
    }

    public func snapshot() async -> LiveSnapshot {
        await buffer.snapshot()
    }

    public func runExternalDiagnostic() async {
        guard running.contains(ExternalDiagnosticsCollector.capabilityID) else { return }
        for collector in collectors {
            if let diagnostics = collector as? ExternalDiagnosticsCollector {
                await diagnostics.probe()
                return
            }
        }
    }

    private func sendDisabled(id: String, sink: any TelemetrySink) async {
        await sink.send(.availability(capabilityID: id, .unavailable(reason: "Disabled in Capabilities")))
        await sink.send(.event(EventFactory.capabilityAvailabilityChanged(
            clock: SystemClock(),
            capabilityID: id,
            enabled: false
        )))
    }
}