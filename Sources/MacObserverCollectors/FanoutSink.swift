import MacObserverDomain

public actor FanoutTelemetrySink: TelemetrySink {
    private let sinks: [any TelemetrySink]

    public init(_ sinks: [any TelemetrySink]) {
        self.sinks = sinks
    }

    public func send(_ observation: TelemetryObservation) async {
        for sink in sinks {
            await sink.send(observation)
        }
    }
}

public actor PersistingSink: TelemetrySink {
    private let persist: any TelemetryPersisting
    private var metrics: [Metric] = []
    private var events: [Event] = []
    private let batchSize: Int

    public init(persist: any TelemetryPersisting, batchSize: Int = 32) {
        self.persist = persist
        self.batchSize = batchSize
    }

    public func send(_ observation: TelemetryObservation) async {
        switch observation {
        case .metric(let metric):
            metrics.append(metric)
            if metrics.count >= batchSize {
                await flush()
            }
        case .event(let event):
            events.append(event)
            await flush()
        case .availability:
            break
        }
    }

    public func flush() async {
        let pendingMetrics = metrics
        let pendingEvents = events
        metrics.removeAll()
        events.removeAll()
        if !pendingMetrics.isEmpty {
            try? await persist.insert(metrics: pendingMetrics)
        }
        if !pendingEvents.isEmpty {
            try? await persist.insert(events: pendingEvents)
        }
    }
}
