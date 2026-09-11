import Foundation

public enum EvidenceRelation: String, Sendable, Hashable, Codable {
    case evidence
    case correlation
}

public struct ExplanationInspect: Sendable, Hashable, Codable {
    public let title: String
    public let metricName: MetricName
    public let domain: TelemetryDomain
    public let entityKey: String?

    public init(title: String, metricName: MetricName, domain: TelemetryDomain, entityKey: String?) {
        self.title = title
        self.metricName = metricName
        self.domain = domain
        self.entityKey = entityKey
    }
}

public struct ExplanationClaim: Sendable, Hashable, Identifiable, Codable {
    public let id: String
    public let summary: String
    public let relation: EvidenceRelation
    public let inspect: ExplanationInspect?
    public let rank: Int

    public init(
        id: String,
        summary: String,
        relation: EvidenceRelation,
        inspect: ExplanationInspect?,
        rank: Int
    ) {
        self.id = id
        self.summary = summary
        self.relation = relation
        self.inspect = inspect
        self.rank = rank
    }
}

public struct Explanation: Sendable, Hashable, Identifiable, Codable {
    public let id: String
    public let ruleID: String
    public let headline: String
    public let detectedState: String
    public let threshold: String
    public let window: TimeRange
    public let triggerTime: Date
    public let claims: [ExplanationClaim]
    public let inspect: ExplanationInspect

    public init(
        id: String,
        ruleID: String,
        headline: String,
        detectedState: String,
        threshold: String,
        window: TimeRange,
        triggerTime: Date,
        claims: [ExplanationClaim],
        inspect: ExplanationInspect
    ) {
        self.id = id
        self.ruleID = ruleID
        self.headline = headline
        self.detectedState = detectedState
        self.threshold = threshold
        self.window = window
        self.triggerTime = triggerTime
        self.claims = claims
        self.inspect = inspect
    }

    public func asEvent(now: Date, entity: Entity) -> Event {
        Event(
            time: ObservationTime(wallTime: now),
            domain: .system,
            type: .explanationGenerated,
            entity: entity,
            summary: headline,
            metadata: [
                "explanation_id": id,
                "rule_id": ruleID,
                "detected_state": detectedState,
                "threshold": threshold
            ],
            source: "explanation.rules",
            quality: .derived,
            privacyClass: .operational
        )
    }
}

public enum ExplanationRules {
    public static let lookback: TimeInterval = 90
    public static let recentHorizon: TimeInterval = 15 * 60
    public static let cpuSustained: TimeInterval = 60
    public static let cpuAttentionRatio = 0.80
    public static let cpuInvestigateRatio = 0.95
    public static let processMemoryDeltaBytes: Double = 50 * 1024 * 1024
    public static let swapDeltaBytes: Double = 32 * 1024 * 1024
    public static let ioCorrelationBytesPerSecond: Double = 40 * 1024 * 1024
    public static let processCPURatio = 0.10
    public static let maxContributorClaims = 3

    public static let memoryRuleID = "memory.pressure"
    public static let thermalRuleID = "thermal.state"
    public static let cpuRuleID = "cpu.sustained"

    public static func isSupportedTrigger(_ event: Event) -> Bool {
        switch event.type {
        case .memoryPressureChanged:
            isElevatedPressure(event.metadata["to"])
        case .thermalStateChanged:
            isElevatedThermal(event.metadata["to"])
        default:
            false
        }
    }

    public static func select(events: [Event], metrics: [Metric], now: Date) -> Explanation? {
        let triggers = events
            .filter(isSupportedTrigger)
            .sorted { $0.time.wallTime > $1.time.wallTime }
        var candidates: [Explanation] = []
        if let event = triggers.first,
           let explanation = explain(trigger: event, metrics: metrics, now: now) {
            candidates.append(explanation)
        }
        if let cpu = explainSustainedCPU(metrics: metrics, now: now) {
            candidates.append(cpu)
        }
        return candidates.max { lhs, rhs in
            if lhs.triggerTime != rhs.triggerTime {
                return lhs.triggerTime < rhs.triggerTime
            }
            return severity(lhs) < severity(rhs)
        }
    }

    public static func explain(trigger: Event, metrics: [Metric], now: Date) -> Explanation? {
        let end = max(trigger.time.wallTime, now)
        let window = TimeRange(start: trigger.time.wallTime.addingTimeInterval(-lookback), end: end)
        let scoped = metrics.filter { metric in
            metric.time.wallTime >= window.start && metric.time.wallTime <= window.end
        }
        switch trigger.type {
        case .memoryPressureChanged:
            return memoryExplanation(trigger: trigger, metrics: scoped, window: window)
        case .thermalStateChanged:
            return thermalExplanation(trigger: trigger, metrics: scoped, window: window)
        default:
            return nil
        }
    }

    public static func explainSustainedCPU(metrics: [Metric], now: Date) -> Explanation? {
        let window = TimeRange(start: now.addingTimeInterval(-cpuSustained), end: now)
        let samples = series(
            named: .cpuUtilizationRatio,
            entityIsSystem: true,
            in: metrics,
            window: TimeRange(start: now.addingTimeInterval(-cpuSustained - 5), end: now)
        )
        guard samples.count >= 3 else { return nil }
        let recent = samples.filter { $0.time.wallTime >= window.start }
        let values = recent.compactMap(scalar)
        guard let minimum = values.min(), minimum >= cpuAttentionRatio else { return nil }
        guard let first = recent.first, let last = recent.last else { return nil }
        let span = last.time.wallTime.timeIntervalSince(first.time.wallTime)
        guard span >= 45 else { return nil }

        let investigate = minimum >= cpuInvestigateRatio
        let threshold = investigate ? "95%" : "80%"
        let percent = Int((values.last ?? minimum) * 100)
        let headline = "CPU stayed at or above \(threshold) for \(Int(span.rounded())) seconds."
        var claims: [ExplanationClaim] = [
            ExplanationClaim(
                id: "cpu.system",
                summary: "Host CPU reached \(percent)% against a \(threshold) threshold.",
                relation: .evidence,
                inspect: ExplanationInspect(
                    title: "CPU",
                    metricName: .cpuUtilizationRatio,
                    domain: .cpu,
                    entityKey: last.entity.identityKey
                ),
                rank: 0
            )
        ]
        claims.append(contentsOf: processCPUClaims(metrics: metrics, window: window, startRank: 1))
        claims.append(contentsOf: ioClaims(metrics: metrics, window: window, startRank: claims.count))

        let bucket = Int(window.start.timeIntervalSince1970 / recentHorizon)
        return Explanation(
            id: "\(cpuRuleID):\(bucket)",
            ruleID: cpuRuleID,
            headline: headline,
            detectedState: investigate ? "investigate" : "attention",
            threshold: "cpu.utilization_ratio >= \(investigate ? cpuInvestigateRatio : cpuAttentionRatio) for \(Int(cpuSustained))s",
            window: window,
            triggerTime: last.time.wallTime,
            claims: claims,
            inspect: ExplanationInspect(
                title: "CPU",
                metricName: .cpuUtilizationRatio,
                domain: .cpu,
                entityKey: last.entity.identityKey
            )
        )
    }

    private static func memoryExplanation(trigger: Event, metrics: [Metric], window: TimeRange) -> Explanation? {
        guard let to = trigger.metadata["to"], isElevatedPressure(to) else { return nil }
        let clock = trigger.time.wallTime.formatted(date: .omitted, time: .shortened)
        let inspect = ExplanationInspect(
            title: "Memory pressure",
            metricName: .memoryPressureState,
            domain: .memory,
            entityKey: trigger.entity.identityKey
        )
        var claims = [
            ExplanationClaim(
                id: "memory.pressure",
                summary: "Memory pressure changed from \(trigger.metadata["from"] ?? "unknown") to \(to).",
                relation: .evidence,
                inspect: inspect,
                rank: 0
            )
        ]
        if let swap = swapClaim(metrics: metrics, window: window, rank: 1) {
            claims.append(swap)
        }
        claims.append(contentsOf: processMemoryClaims(metrics: metrics, window: window, startRank: claims.count))

        return Explanation(
            id: trigger.id.uuidString,
            ruleID: memoryRuleID,
            headline: "Memory pressure became \(to) at \(clock).",
            detectedState: to,
            threshold: "memory.pressure_state in warning, urgent, critical",
            window: window,
            triggerTime: trigger.time.wallTime,
            claims: claims,
            inspect: inspect
        )
    }

    private static func thermalExplanation(trigger: Event, metrics: [Metric], window: TimeRange) -> Explanation? {
        guard let to = trigger.metadata["to"], isElevatedThermal(to) else { return nil }
        let clock = trigger.time.wallTime.formatted(date: .omitted, time: .shortened)
        let inspect = ExplanationInspect(
            title: "Thermal",
            metricName: .thermalState,
            domain: .thermal,
            entityKey: trigger.entity.identityKey
        )
        var claims = [
            ExplanationClaim(
                id: "thermal.state",
                summary: "Thermal state changed from \(trigger.metadata["from"] ?? "unknown") to \(to).",
                relation: .evidence,
                inspect: inspect,
                rank: 0
            )
        ]
        let cpu = series(named: .cpuUtilizationRatio, entityIsSystem: true, in: metrics, window: window)
        if let last = cpu.last, let value = scalar(last), value >= cpuAttentionRatio {
            claims.append(
                ExplanationClaim(
                    id: "thermal.cpu",
                    summary: "Host CPU was \(Int((value * 100).rounded()))% in the same window and may be related.",
                    relation: .correlation,
                    inspect: ExplanationInspect(
                        title: "CPU",
                        metricName: .cpuUtilizationRatio,
                        domain: .cpu,
                        entityKey: last.entity.identityKey
                    ),
                    rank: claims.count
                )
            )
        }
        claims.append(contentsOf: processCPUClaims(metrics: metrics, window: window, startRank: claims.count))
        claims.append(contentsOf: ioClaims(metrics: metrics, window: window, startRank: claims.count))

        return Explanation(
            id: trigger.id.uuidString,
            ruleID: thermalRuleID,
            headline: "Thermal state became \(to) at \(clock).",
            detectedState: to,
            threshold: "thermal.state in fair, serious, critical",
            window: window,
            triggerTime: trigger.time.wallTime,
            claims: claims,
            inspect: inspect
        )
    }

    private static func processMemoryClaims(metrics: [Metric], window: TimeRange, startRank: Int) -> [ExplanationClaim] {
        let grouped = Dictionary(grouping: metrics.filter {
            $0.name == .processResidentBytes && isProcess($0.entity)
        }, by: \.entity.identityKey)
        let ranked = grouped.compactMap { key, samples -> (String, Entity, Double)? in
            let ordered = samples.sorted { $0.time.wallTime < $1.time.wallTime }
            guard let first = ordered.first, let last = ordered.last,
                  let start = scalar(first), let end = scalar(last) else { return nil }
            let delta = end - start
            guard delta >= processMemoryDeltaBytes else { return nil }
            return (key, last.entity, delta)
        }
        .sorted { $0.2 > $1.2 }
        .prefix(maxContributorClaims)

        return ranked.enumerated().map { index, item in
            let name = entityName(item.1)
            return ExplanationClaim(
                id: "process.memory.\(item.0)",
                summary: "\(name) increased resident memory by \(MetricFormatter.displayString(value: item.2, unit: .bytes)) and may be related.",
                relation: .correlation,
                inspect: ExplanationInspect(
                    title: name,
                    metricName: .processResidentBytes,
                    domain: .memory,
                    entityKey: item.0
                ),
                rank: startRank + index
            )
        }
    }

    private static func processCPUClaims(metrics: [Metric], window: TimeRange, startRank: Int) -> [ExplanationClaim] {
        let grouped = Dictionary(grouping: metrics.filter {
            $0.name == .cpuUtilizationRatio && isProcess($0.entity)
                && $0.time.wallTime >= window.start && $0.time.wallTime <= window.end
        }, by: \.entity.identityKey)
        let ranked = grouped.compactMap { key, samples -> (String, Entity, Double)? in
            guard let last = samples.max(by: { $0.time.wallTime < $1.time.wallTime }),
                  let value = scalar(last), value >= processCPURatio else { return nil }
            return (key, last.entity, value)
        }
        .sorted { $0.2 > $1.2 }
        .prefix(maxContributorClaims)

        return ranked.enumerated().map { index, item in
            let name = entityName(item.1)
            return ExplanationClaim(
                id: "process.cpu.\(item.0)",
                summary: "\(name) used \(Int((item.2 * 100).rounded()))% CPU and may be related.",
                relation: .correlation,
                inspect: ExplanationInspect(
                    title: name,
                    metricName: .cpuUtilizationRatio,
                    domain: .cpu,
                    entityKey: item.0
                ),
                rank: startRank + index
            )
        }
    }

    private static func ioClaims(metrics: [Metric], window: TimeRange, startRank: Int) -> [ExplanationClaim] {
        let write = average(named: .storageWriteBytesPerSecond, in: metrics, window: window)
        let read = average(named: .storageReadBytesPerSecond, in: metrics, window: window)
        let total = (write ?? 0) + (read ?? 0)
        guard total >= ioCorrelationBytesPerSecond else { return [] }
        let sample = metrics.last { $0.name == .storageWriteBytesPerSecond || $0.name == .storageReadBytesPerSecond }
        return [
            ExplanationClaim(
                id: "storage.io",
                summary: "Disk I/O averaged \(MetricFormatter.displayString(value: total, unit: .bytesPerSecond)) and may be related.",
                relation: .correlation,
                inspect: sample.map {
                    ExplanationInspect(
                        title: "Disk",
                        metricName: $0.name,
                        domain: .storage,
                        entityKey: $0.entity.identityKey
                    )
                },
                rank: startRank
            )
        ]
    }

    private static func swapClaim(metrics: [Metric], window: TimeRange, rank: Int) -> ExplanationClaim? {
        let ordered = series(named: .memorySwapUsedBytes, entityIsSystem: true, in: metrics, window: window)
        guard let first = ordered.first, let last = ordered.last,
              let start = scalar(first), let end = scalar(last) else { return nil }
        let delta = end - start
        guard delta >= swapDeltaBytes else { return nil }
        return ExplanationClaim(
            id: "memory.swap",
            summary: "Swap grew by \(MetricFormatter.displayString(value: delta, unit: .bytes)) over \(Int(lookback)) seconds and may be related.",
            relation: .correlation,
            inspect: ExplanationInspect(
                title: "Swap",
                metricName: .memorySwapUsedBytes,
                domain: .memory,
                entityKey: last.entity.identityKey
            ),
            rank: rank
        )
    }

    private static func series(
        named name: MetricName,
        entityIsSystem: Bool,
        in metrics: [Metric],
        window: TimeRange
    ) -> [Metric] {
        metrics.filter { metric in
            metric.name == name
                && (entityIsSystem ? isSystem(metric.entity) : true)
                && metric.time.wallTime >= window.start
                && metric.time.wallTime <= window.end
        }
        .sorted { $0.time.wallTime < $1.time.wallTime }
    }

    private static func average(named name: MetricName, in metrics: [Metric], window: TimeRange) -> Double? {
        let values = series(named: name, entityIsSystem: true, in: metrics, window: window).compactMap(scalar)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func scalar(_ metric: Metric) -> Double? {
        switch metric.value {
        case .int(let value): Double(value)
        case .double(let value): value
        case .ratio(let value): value
        case .state: nil
        }
    }

    private static func isSystem(_ entity: Entity) -> Bool {
        if case .system = entity { return true }
        return false
    }

    private static func isProcess(_ entity: Entity) -> Bool {
        if case .processInstance = entity { return true }
        return false
    }

    private static func entityName(_ entity: Entity) -> String {
        switch entity {
        case .processInstance(let process):
            process.attributes.displayName ?? "PID \(process.pid)"
        case .system:
            "This Mac"
        default:
            entity.identityKey
        }
    }

    private static func isElevatedPressure(_ state: String?) -> Bool {
        switch state {
        case "warning", "urgent", "critical": true
        default: false
        }
    }

    private static func isElevatedThermal(_ state: String?) -> Bool {
        switch state {
        case "fair", "serious", "critical": true
        default: false
        }
    }

    private static func severity(_ explanation: Explanation) -> Int {
        switch explanation.detectedState {
        case "critical", "urgent", "investigate": 3
        case "serious", "warning": 2
        case "fair", "attention": 1
        default: 0
        }
    }
}
