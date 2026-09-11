import Foundation
import Testing
@testable import MacObserverDomain

struct ExplanationRulesTests {
    private let boot = BootSessionID("boot-1")
    private let origin = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func memoryPressureCitesSwapAndRanksProcessGrowth() {
        let trigger = pressureEvent(from: "normal", to: "urgent", at: origin)
        let docker = process(pid: 10, name: "Docker")
        let chrome = process(pid: 11, name: "Chrome")
        let metrics = [
            metric(.memorySwapUsedBytes, entity: system, at: origin.addingTimeInterval(-80), int: 100_000_000),
            metric(.memorySwapUsedBytes, entity: system, at: origin, int: 1_600_000_000),
            metric(.processResidentBytes, entity: docker, at: origin.addingTimeInterval(-80), int: 200_000_000),
            metric(.processResidentBytes, entity: docker, at: origin, int: 1_400_000_000),
            metric(.processResidentBytes, entity: chrome, at: origin.addingTimeInterval(-80), int: 100_000_000),
            metric(.processResidentBytes, entity: chrome, at: origin, int: 920_000_000)
        ]

        let explanation = ExplanationRules.explain(trigger: trigger, metrics: metrics, now: origin)
        guard let explanation else {
            Issue.record("expected a memory explanation")
            return
        }

        #expect(explanation.ruleID == ExplanationRules.memoryRuleID)
        #expect(explanation.headline.contains("urgent"))
        #expect(explanation.claims.contains { $0.relation == .evidence && $0.summary.contains("urgent") })
        #expect(explanation.claims.contains { $0.id == "memory.swap" && $0.relation == .correlation && $0.summary.contains("may be related") })
        let processes = explanation.claims.filter { $0.id.hasPrefix("process.memory") }
        #expect(processes.count == 2)
        #expect(processes.first?.summary.contains("Docker") == true)
        #expect(processes.allSatisfy { $0.summary.contains("may be related") })
        #expect(explanation.inspect.metricName == .memoryPressureState)
    }

    @Test func recoveredPressureIsNotExplained() {
        let trigger = pressureEvent(from: "urgent", to: "normal", at: origin)
        #expect(ExplanationRules.isSupportedTrigger(trigger) == false)
        #expect(ExplanationRules.explain(trigger: trigger, metrics: [], now: origin) == nil)
    }

    @Test func thermalCitesCPUAsCorrelation() {
        let trigger = thermalEvent(from: "nominal", to: "serious", at: origin)
        let metrics = [
            metric(.cpuUtilizationRatio, entity: system, at: origin, ratio: 0.91)
        ]
        let explanation = ExplanationRules.explain(trigger: trigger, metrics: metrics, now: origin)
        guard let explanation else {
            Issue.record("expected a thermal explanation")
            return
        }
        #expect(explanation.claims.contains { $0.id == "thermal.cpu" && $0.relation == .correlation })
        #expect(explanation.claims.contains { $0.summary.contains("may be related") })
    }

    @Test func sustainedCPURequiresTheDocumentedThreshold() {
        let samples = stride(from: 0, through: 50, by: 10).map { offset in
            metric(
                .cpuUtilizationRatio,
                entity: system,
                at: origin.addingTimeInterval(Double(offset)),
                ratio: 0.86
            )
        }
        let now = origin.addingTimeInterval(50)
        let explanation = ExplanationRules.explainSustainedCPU(metrics: samples, now: now)
        #expect(explanation?.ruleID == ExplanationRules.cpuRuleID)
        #expect(explanation?.claims.contains { $0.relation == .evidence } == true)

        let low = samples.map { sample in
            metric(.cpuUtilizationRatio, entity: system, at: sample.time.wallTime, ratio: 0.4)
        }
        #expect(ExplanationRules.explainSustainedCPU(metrics: low, now: now) == nil)
    }

    @Test func selectPrefersTheLatestSupportedTrigger() {
        let thermal = thermalEvent(from: "nominal", to: "fair", at: origin.addingTimeInterval(-30))
        let memory = pressureEvent(from: "normal", to: "warning", at: origin)
        let selected = ExplanationRules.select(
            events: [thermal, memory],
            metrics: [
                metric(.cpuUtilizationRatio, entity: system, at: origin, ratio: 0.2)
            ],
            now: origin
        )
        #expect(selected?.ruleID == ExplanationRules.memoryRuleID)
    }

    private var system: Entity { .system(bootSession: boot) }

    private func process(pid: Int32, name: String) -> Entity {
        .processInstance(
            ProcessInstanceIdentity(
                pid: pid,
                startNanoseconds: 1,
                bootSession: boot,
                attributes: ProcessAttributes(displayName: name)
            )
        )
    }

    private func pressureEvent(from: String, to: String, at time: Date) -> Event {
        Event(
            time: ObservationTime(wallTime: time),
            domain: .memory,
            type: .memoryPressureChanged,
            entity: system,
            summary: "Memory pressure changed from \(from) to \(to).",
            metadata: ["from": from, "to": to],
            source: "standard.cpu_memory",
            quality: .direct,
            privacyClass: .operational
        )
    }

    private func thermalEvent(from: String, to: String, at time: Date) -> Event {
        Event(
            time: ObservationTime(wallTime: time),
            domain: .thermal,
            type: .thermalStateChanged,
            entity: system,
            summary: "Thermal state changed from \(from) to \(to).",
            metadata: ["from": from, "to": to],
            source: "standard.cpu_memory",
            quality: .direct,
            privacyClass: .operational
        )
    }

    private func metric(
        _ name: MetricName,
        entity: Entity,
        at time: Date,
        int: Int64? = nil,
        ratio: Double? = nil
    ) -> Metric {
        let value: MetricValue
        let unit: MacObserverDomain.Unit
        let domain: TelemetryDomain
        if let int {
            value = .int(int)
            unit = .bytes
            domain = .memory
        } else {
            value = .ratio(ratio ?? 0)
            unit = .ratio
            domain = .cpu
        }
        return Metric(
            time: ObservationTime(wallTime: time),
            domain: domain,
            name: name,
            entity: entity,
            value: value,
            unit: unit,
            source: "test",
            quality: .direct
        )
    }
}
