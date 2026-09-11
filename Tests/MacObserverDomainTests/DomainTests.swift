import Foundation
import Testing
@testable import MacObserverDomain

struct EntityIdentityTests {
    @Test func processIdentityIgnoresDisplayName() {
        let boot = BootSessionID("boot-1")
        let chrome = ProcessInstanceIdentity(
            pid: 442,
            startNanoseconds: 100,
            bootSession: boot,
            attributes: ProcessAttributes(displayName: "Chrome")
        )
        let helper = ProcessInstanceIdentity(
            pid: 442,
            startNanoseconds: 100,
            bootSession: boot,
            attributes: ProcessAttributes(displayName: "Google Chrome Helper")
        )

        #expect(chrome == helper)
        #expect(Set([chrome, helper]).count == 1)
        #expect(chrome.identityKey == helper.identityKey)
    }

    @Test func reusedPIDIsADifferentProcess() {
        let boot = BootSessionID("boot-1")
        let first = ProcessInstanceIdentity(pid: 442, startNanoseconds: 100, bootSession: boot)
        let reused = ProcessInstanceIdentity(pid: 442, startNanoseconds: 900, bootSession: boot)

        #expect(first != reused)
        #expect(first.identityKey != reused.identityKey)
    }

    @Test func samePIDOnAnotherBootIsADifferentProcess() {
        let first = ProcessInstanceIdentity(
            pid: 442,
            startNanoseconds: 100,
            bootSession: BootSessionID("boot-1")
        )
        let afterReboot = ProcessInstanceIdentity(
            pid: 442,
            startNanoseconds: 100,
            bootSession: BootSessionID("boot-2")
        )

        #expect(first != afterReboot)
    }

    @Test func displayTitleUsesStableIdentityNotAPrettyLabel() {
        let process = Entity.processInstance(
            ProcessInstanceIdentity(
                pid: 442,
                startNanoseconds: 100,
                bootSession: BootSessionID("boot-1"),
                attributes: ProcessAttributes(displayName: "Chrome")
            )
        )
        #expect(process.displayTitle == "Chrome")
        #expect(process.identityKey == "process:boot-1:442:100")
        #expect(Entity.system(bootSession: BootSessionID("boot-1")).displayTitle == "This Mac")
        #expect(Entity.capability(id: "power").displayTitle == "power")
    }
}

struct MetricContractTests {
    @Test func metricNamesMustBeNamespacedAndLowercase() {
        #expect(MetricName(rawValue: "cpu.utilization_ratio") != nil)
        #expect(MetricName(rawValue: "32%") == nil)
        #expect(MetricName(rawValue: "CPU") == nil)
        #expect(MetricName(rawValue: "memory") == nil)
        #expect(MetricName(rawValue: "Memory Used") == nil)
    }

    @Test func utilizationIsStoredAsARatioNotAPercentString() {
        let metric = Metric(
            time: ObservationTime(wallTime: Date(timeIntervalSince1970: 0)),
            domain: .cpu,
            name: .cpuUtilizationRatio,
            entity: .system(bootSession: BootSessionID("boot-1")),
            value: .ratio(0.32),
            unit: .ratio,
            source: "test",
            quality: .direct
        )

        #expect(metric.unit == .ratio)
        if case .ratio(let value) = metric.value {
            #expect(value == 0.32)
        } else {
            Issue.record("expected a ratio value")
        }
        #expect(MetricFormatter.displayString(for: metric) == "32%")
    }

    @Test func derivedMetricsKeepTheirSource() {
        let sourceID = UUID()
        let metric = Metric(
            time: ObservationTime(wallTime: Date(timeIntervalSince1970: 0)),
            domain: .memory,
            name: .memoryUsedBytes,
            entity: .system(bootSession: BootSessionID("boot-1")),
            value: .int(11_800_000_000),
            unit: .bytes,
            source: "test",
            quality: .derived,
            derivation: Derivation(sourceMetricIDs: [sourceID], method: "sum.resident")
        )

        #expect(metric.quality == .derived)
        #expect(metric.derivation?.sourceMetricIDs == [sourceID])
        #expect(metric.derivation?.method == "sum.resident")
    }
}

struct SeriesBucketingTests {
    @Test func lastSampleKeepsNewestPointInEachBucket() {
        let system = Entity.system(bootSession: BootSessionID("boot-1"))
        let points = [0.0, 1.0, 3.0].map { seconds in
            Metric(
                time: ObservationTime(wallTime: Date(timeIntervalSince1970: seconds)),
                domain: .cpu,
                name: .cpuUtilizationRatio,
                entity: system,
                value: .ratio(seconds / 10),
                unit: .ratio,
                source: "test",
                quality: .direct
            )
        }
        let bucketed = SeriesBucketing.lastSample(in: points, bucketSeconds: 2)
        #expect(bucketed.count == 2)
        #expect(bucketed[0].time.wallTime.timeIntervalSince1970 == 1)
        #expect(bucketed[1].time.wallTime.timeIntervalSince1970 == 3)
    }
}

struct MetricDownsampleTests {
    @Test func agingNumericSamplesRollIntoMinMaxAverageAndCount() {
        let system = Entity.system(bootSession: BootSessionID("boot-1"))
        let samples = [0.0, 10.0, 20.0, 80.0].enumerated().map { index, seconds in
            Metric(
                time: ObservationTime(wallTime: Date(timeIntervalSince1970: seconds)),
                domain: .cpu,
                name: .cpuUtilizationRatio,
                entity: system,
                value: .ratio(Double(index + 1) / 10),
                unit: .ratio,
                source: "test",
                quality: .direct
            )
        }
        let kept = MetricDownsampler.retainedMetrics(
            samples,
            policy: RetentionPolicy(
                recentMetrics: 50,
                events: 50,
                longTermMetrics: 500,
                downsampleBucket: 60
            ),
            now: Date(timeIntervalSince1970: 100)
        )
        #expect(kept.count == 2)
        #expect(kept[0].retentionClass == .longTerm)
        #expect(kept[0].quality == .derived)
        if case .ratio(let value) = kept[0].value {
            #expect(abs(value - 0.2) < 0.0001)
        } else {
            Issue.record("expected average ratio")
        }
        #expect(Double(kept[0].dimensions["downsample.min"] ?? "") == 0.1)
        #expect(Double(kept[0].dimensions["downsample.max"] ?? "") == 0.3)
        #expect(kept[0].dimensions["downsample.count"] == "3")
        if case .ratio(let value) = kept[1].value {
            #expect(value == 0.4)
        } else {
            Issue.record("expected recent raw sample")
        }
        #expect(kept[1].retentionClass == .live)
    }

    @Test func stateSamplesKeepTheLastValueInTheBucket() {
        let system = Entity.system(bootSession: BootSessionID("boot-1"))
        let samples = ["nominal", "fair"].enumerated().map { index, state in
            Metric(
                time: ObservationTime(wallTime: Date(timeIntervalSince1970: Double(index * 10))),
                domain: .thermal,
                name: .thermalState,
                entity: system,
                value: .state(state),
                unit: .enumeration,
                source: "test",
                quality: .direct
            )
        }
        let rolled = MetricDownsampler.collapse(samples, bucketSeconds: 60)
        #expect(rolled.count == 1)
        if case .state(let value) = rolled[0].value {
            #expect(value == "fair")
        } else {
            Issue.record("expected last thermal state")
        }
        #expect(rolled[0].derivation?.method == "last_60s")
    }
}

struct EventContractTests {
    @Test func eventTypesFollowTheSameNameRulesAsMetrics() {
        #expect(EventType(rawValue: "process.launched") != nil)
        #expect(EventType(rawValue: "memory.pressure_changed") != nil)
        #expect(EventType(rawValue: "thermal.state_changed") != nil)
        #expect(EventType(rawValue: "capability.availability_changed") != nil)
        #expect(EventType(rawValue: "explanation.generated") != nil)
        #expect(EventType(rawValue: "network.external_lookup") != nil)
        #expect(EventType(rawValue: "network.configuration_changed") != nil)
        #expect(EventType(rawValue: "launched") == nil)
    }
}

struct HealthRulesTests {
    @Test func heavyCPUIsInvestigate() {
        let result = HealthRules.assess(
            cpuRatio: 0.96,
            memoryPressure: "normal",
            thermal: "nominal",
            coreUnavailable: false,
            stale: false,
            hasAnySample: true
        )
        #expect(result.state == .investigate)
    }

    @Test func firstSampleWaitIsAttention() {
        let result = HealthRules.assess(
            cpuRatio: nil,
            memoryPressure: nil,
            thermal: nil,
            coreUnavailable: false,
            stale: false,
            hasAnySample: false
        )
        #expect(result.state == .attention)
    }

    @Test func normalLoadIsHealthy() {
        let result = HealthRules.assess(
            cpuRatio: 0.21,
            memoryPressure: "normal",
            thermal: "nominal",
            coreUnavailable: false,
            stale: false,
            hasAnySample: true
        )
        #expect(result.state == .healthy)
    }
}

struct InvestigationIntervalTests {
    @Test func aroundAPointStaysInsideTheParentWindow() {
        let range = TimeRange(
            start: Date(timeIntervalSince1970: 100),
            end: Date(timeIntervalSince1970: 200)
        )
        let focused = InvestigationInterval.around(
            Date(timeIntervalSince1970: 150),
            bucketSeconds: 10,
            in: range
        )
        #expect(focused.start == Date(timeIntervalSince1970: 140))
        #expect(focused.end == Date(timeIntervalSince1970: 160))
    }

    @Test func aroundAPointNearTheStartDoesNotLeaveTheWindow() {
        let range = TimeRange(
            start: Date(timeIntervalSince1970: 100),
            end: Date(timeIntervalSince1970: 200)
        )
        let focused = InvestigationInterval.around(
            Date(timeIntervalSince1970: 102),
            bucketSeconds: 10,
            in: range
        )
        #expect(focused.start == Date(timeIntervalSince1970: 100))
        #expect(focused.end == Date(timeIntervalSince1970: 112))
    }
}

struct CapabilityPolicyTests {
    @Test func optionalSourcesStayOffUntilExplicitlyEnabled() {
        let standard = CapabilityDescriptor(
            id: "standard.cpu_memory",
            title: "CPU",
            accessLevel: .standard,
            domains: [.cpu],
            summary: "Host CPU"
        )
        let external = CapabilityDescriptor(
            id: "external.internet",
            title: "Internet Check",
            accessLevel: .external,
            domains: [.network],
            summary: "Lookup",
            remainsLocal: false,
            privacyClass: .identifyingDeviceContext,
            defaultEnabled: false
        )
        let none = CapabilityPolicy.enabledIDs(
            capabilities: [standard, external],
            disabledStandard: [],
            enabledOptional: []
        )
        #expect(none == ["standard.cpu_memory"])
        let both = CapabilityPolicy.enabledIDs(
            capabilities: [standard, external],
            disabledStandard: [],
            enabledOptional: ["external.internet"]
        )
        #expect(both == ["standard.cpu_memory", "external.internet"])
    }
}
