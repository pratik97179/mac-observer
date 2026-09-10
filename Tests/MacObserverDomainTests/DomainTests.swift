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

struct EventContractTests {
    @Test func eventTypesFollowTheSameNameRulesAsMetrics() {
        #expect(EventType(rawValue: "process.launched") != nil)
        #expect(EventType(rawValue: "launched") == nil)
    }
}
