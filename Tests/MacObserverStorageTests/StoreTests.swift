import Foundation
import Testing
import MacObserverDomain
@testable import MacObserverStorage

struct TelemetryStoreTests {
    @Test func memoryAndSQLiteHonorTimeEntityAndName() async throws {
        try await assertQueryBehavior(MemoryTelemetryStore())
        try await assertQueryBehavior(SQLiteTelemetryStore.inMemory())
    }

    @Test func sqliteMigratesToVersion1() async throws {
        let store = try SQLiteTelemetryStore.inMemory()
        #expect(try await store.schemaVersion() == SQLiteTelemetryStore.currentSchemaVersion)
    }

    @Test func reusedPIDIsStoredSeparately() async throws {
        let store = try SQLiteTelemetryStore.inMemory()
        let boot = BootSessionID("boot-1")
        let first = ProcessInstanceIdentity(pid: 442, startNanoseconds: 100, bootSession: boot)
        let reused = ProcessInstanceIdentity(pid: 442, startNanoseconds: 900, bootSession: boot)
        try await store.insert(metrics: [
            cpu(entity: .processInstance(first), at: 10, ratio: 0.2),
            cpu(entity: .processInstance(reused), at: 11, ratio: 0.9)
        ])
        let range = TimeRange(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 20))
        let firstRows = try await store.metrics(matching: MetricQuery(range: range, entityKey: Entity.processInstance(first).identityKey))
        let reusedRows = try await store.metrics(matching: MetricQuery(range: range, entityKey: Entity.processInstance(reused).identityKey))
        #expect(firstRows.count == 1)
        #expect(reusedRows.count == 1)
        if case .ratio(let value) = firstRows[0].value { #expect(value == 0.2) }
        if case .ratio(let value) = reusedRows[0].value { #expect(value == 0.9) }
    }

    @Test func retentionRemovesOldRowsAndDeleteAllClears() async throws {
        let store = try SQLiteTelemetryStore.inMemory()
        try await store.insert(metrics: [
            cpu(entity: .system(bootSession: BootSessionID("boot-1")), at: 0, ratio: 0.1),
            cpu(entity: .system(bootSession: BootSessionID("boot-1")), at: 100, ratio: 0.2)
        ])
        try await store.insert(events: [
            Event(
                time: ObservationTime(wallTime: Date(timeIntervalSince1970: 0)),
                domain: .process,
                type: .processLaunched,
                entity: .system(bootSession: BootSessionID("boot-1")),
                summary: "old",
                source: "test",
                quality: .direct,
                privacyClass: .operational
            )
        ])
        try await store.applyRetention(
            RetentionPolicy(recentMetrics: 50, events: 50),
            now: Date(timeIntervalSince1970: 100)
        )
        let range = TimeRange(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 200))
        let remaining = try await store.metrics(matching: MetricQuery(range: range))
        #expect(remaining.count == 1)
        if case .ratio(let value) = remaining[0].value { #expect(value == 0.2) }
        #expect(try await store.events(matching: EventQuery(range: range)).isEmpty)

        try await store.deleteAll()
        #expect(try await store.metrics(matching: MetricQuery(range: range)).isEmpty)
    }

    @Test func eventQueriesHonorDomainAndNewestLimit() async throws {
        try await assertEventLimit(MemoryTelemetryStore())
        try await assertEventLimit(SQLiteTelemetryStore.inMemory())
    }

    private func assertEventLimit(_ store: some TelemetryStore) async throws {
        let system = Entity.system(bootSession: BootSessionID("boot-1"))
        try await store.insert(events: [
            sampleEvent(entity: system, at: 1, domain: .memory, summary: "one"),
            sampleEvent(entity: system, at: 2, domain: .thermal, summary: "two"),
            sampleEvent(entity: system, at: 3, domain: .memory, summary: "three")
        ])
        let range = TimeRange(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 10))
        let limited = try await store.events(matching: EventQuery(range: range, limit: 2))
        #expect(limited.map(\.summary) == ["two", "three"])
        let memory = try await store.events(matching: EventQuery(range: range, domain: .memory))
        #expect(memory.map(\.summary) == ["one", "three"])
    }

    private func sampleEvent(entity: Entity, at seconds: TimeInterval, domain: TelemetryDomain, summary: String) -> Event {
        Event(
            time: ObservationTime(wallTime: Date(timeIntervalSince1970: seconds)),
            domain: domain,
            type: domain == .memory ? .memoryPressureChanged : .thermalStateChanged,
            entity: entity,
            summary: summary,
            source: "test",
            quality: .direct,
            privacyClass: .operational
        )
    }

    private func assertQueryBehavior(_ store: some TelemetryStore) async throws {
        let system = Entity.system(bootSession: BootSessionID("boot-1"))
        try await store.insert(metrics: [
            cpu(entity: system, at: 5, ratio: 0.1),
            cpu(entity: system, at: 15, ratio: 0.4),
            Metric(
                time: ObservationTime(wallTime: Date(timeIntervalSince1970: 15)),
                domain: .memory,
                name: .memoryUsedBytes,
                entity: system,
                value: .int(1_000),
                unit: .bytes,
                source: "test",
                quality: .direct
            )
        ])
        let inside = try await store.metrics(
            matching: MetricQuery(
                range: TimeRange(start: Date(timeIntervalSince1970: 10), end: Date(timeIntervalSince1970: 20)),
                name: .cpuUtilizationRatio
            )
        )
        #expect(inside.count == 1)
        if case .ratio(let value) = inside[0].value { #expect(value == 0.4) }
    }

    private func cpu(entity: Entity, at seconds: TimeInterval, ratio: Double) -> Metric {
        Metric(
            time: ObservationTime(wallTime: Date(timeIntervalSince1970: seconds)),
            domain: .cpu,
            name: .cpuUtilizationRatio,
            entity: entity,
            value: .ratio(ratio),
            unit: .ratio,
            source: "test",
            quality: .direct
        )
    }
}
