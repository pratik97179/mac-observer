import Foundation
import SQLite3
import MacObserverDomain

public actor SQLiteTelemetryStore: TelemetryStore {
    public static let currentSchemaVersion = 1

    nonisolated(unsafe) private var db: OpaquePointer?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(path: String) throws {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK, let handle else {
            throw StoreError.sqlite("unable to open database")
        }
        db = handle
        try Self.migrate(handle)
    }

    public nonisolated static func applicationSupportPath() throws -> String {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacObserver", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("telemetry.sqlite").path
    }

    public static func inMemory() throws -> SQLiteTelemetryStore {
        try SQLiteTelemetryStore(path: ":memory:")
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    public func schemaVersion() throws -> Int {
        guard let db else { return 0 }
        return try Self.userVersion(db)
    }

    public func insert(metrics: [Metric]) async throws {
        guard let db, !metrics.isEmpty else { return }
        try Self.exec(db, "BEGIN IMMEDIATE")
        do {
            let sql = """
                INSERT OR REPLACE INTO metrics (
                    id, wall_time, monotonic_ns, domain, name, entity_key, entity_json,
                    value_json, unit, dimensions_json, source, quality, retention_class, derivation_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
                throw StoreError.sqlite(Self.message(db))
            }
            defer { sqlite3_finalize(statement) }
            for metric in metrics {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                try bindMetric(statement, metric)
                guard sqlite3_step(statement) == SQLITE_DONE else {
                    throw StoreError.sqlite(Self.message(db))
                }
            }
            try Self.exec(db, "COMMIT")
        } catch {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            throw error
        }
    }

    public func insert(events: [Event]) async throws {
        guard let db, !events.isEmpty else { return }
        try Self.exec(db, "BEGIN IMMEDIATE")
        do {
            let sql = """
                INSERT OR REPLACE INTO events (
                    id, wall_time, monotonic_ns, domain, type, entity_key, entity_json,
                    related_json, summary, metadata_json, source, quality, privacy_class
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
                throw StoreError.sqlite(Self.message(db))
            }
            defer { sqlite3_finalize(statement) }
            for event in events {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                try bindEvent(statement, event)
                guard sqlite3_step(statement) == SQLITE_DONE else {
                    throw StoreError.sqlite(Self.message(db))
                }
            }
            try Self.exec(db, "COMMIT")
        } catch {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            throw error
        }
    }

    public func metrics(matching query: MetricQuery) async throws -> [Metric] {
        guard let db else { return [] }
        let filters = metricFilterSQL(query)
        let sql: String
        if let bucket = query.bucketSeconds, bucket > 0 {
            sql = """
                SELECT m.entity_json, m.value_json, m.dimensions_json, m.derivation_json,
                       m.id, m.wall_time, m.monotonic_ns, m.domain, m.name, m.unit, m.source, m.quality, m.retention_class
                FROM metrics m
                INNER JOIN (
                    SELECT entity_key, name, MAX(wall_time) AS wall_time
                    FROM metrics
                    WHERE wall_time >= ? AND wall_time <= ?
                    \(filters)
                    GROUP BY entity_key, name, CAST(wall_time / ? AS INTEGER)
                ) b
                ON m.entity_key = b.entity_key AND m.name = b.name AND m.wall_time = b.wall_time
                ORDER BY m.wall_time ASC, m.monotonic_ns ASC
                """
        } else {
            sql = """
                SELECT entity_json, value_json, dimensions_json, derivation_json,
                       id, wall_time, monotonic_ns, domain, name, unit, source, quality, retention_class
                FROM metrics
                WHERE wall_time >= ? AND wall_time <= ?
                \(filters)
                ORDER BY wall_time ASC, monotonic_ns ASC
                """
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw StoreError.sqlite(Self.message(db))
        }
        defer { sqlite3_finalize(statement) }

        var index: Int32 = 1
        sqlite3_bind_double(statement, index, query.range.start.timeIntervalSince1970)
        index += 1
        sqlite3_bind_double(statement, index, query.range.end.timeIntervalSince1970)
        index += 1
        index = bindMetricFilters(statement, query: query, index: index)
        if let bucket = query.bucketSeconds, bucket > 0 {
            sqlite3_bind_double(statement, index, bucket)
        }

        var rows: [Metric] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(try decodeMetric(statement))
        }
        return rows
    }

    private func metricFilterSQL(_ query: MetricQuery) -> String {
        var sql = ""
        if query.entityKey != nil { sql += " AND entity_key = ?" }
        if query.name != nil { sql += " AND name = ?" }
        if query.domain != nil { sql += " AND domain = ?" }
        return sql
    }

    private func bindMetricFilters(_ statement: OpaquePointer, query: MetricQuery, index: Int32) -> Int32 {
        var index = index
        if let entityKey = query.entityKey {
            sqlite3_bind_text(statement, index, entityKey, -1, SQLITE_TRANSIENT)
            index += 1
        }
        if let name = query.name {
            sqlite3_bind_text(statement, index, name.rawValue, -1, SQLITE_TRANSIENT)
            index += 1
        }
        if let domain = query.domain {
            sqlite3_bind_text(statement, index, domain.rawValue, -1, SQLITE_TRANSIENT)
            index += 1
        }
        return index
    }

    public func events(matching query: EventQuery) async throws -> [Event] {
        guard let db else { return [] }
        var sql = """
            SELECT entity_json, related_json, metadata_json,
                   id, wall_time, monotonic_ns, domain, type, summary, source, quality, privacy_class
            FROM events
            WHERE wall_time >= ? AND wall_time <= ?
            """
        if query.entityKey != nil { sql += " AND entity_key = ?" }
        if query.type != nil { sql += " AND type = ?" }
        if query.domain != nil { sql += " AND domain = ?" }
        if query.limit != nil {
            sql += " ORDER BY wall_time DESC, monotonic_ns DESC LIMIT ?"
        } else {
            sql += " ORDER BY wall_time ASC, monotonic_ns ASC"
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw StoreError.sqlite(Self.message(db))
        }
        defer { sqlite3_finalize(statement) }

        var index: Int32 = 1
        sqlite3_bind_double(statement, index, query.range.start.timeIntervalSince1970)
        index += 1
        sqlite3_bind_double(statement, index, query.range.end.timeIntervalSince1970)
        index += 1
        if let entityKey = query.entityKey {
            sqlite3_bind_text(statement, index, entityKey, -1, SQLITE_TRANSIENT)
            index += 1
        }
        if let type = query.type {
            sqlite3_bind_text(statement, index, type.rawValue, -1, SQLITE_TRANSIENT)
            index += 1
        }
        if let domain = query.domain {
            sqlite3_bind_text(statement, index, domain.rawValue, -1, SQLITE_TRANSIENT)
            index += 1
        }
        if let limit = query.limit {
            sqlite3_bind_int(statement, index, Int32(limit))
        }

        var rows: [Event] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(try decodeEvent(statement))
        }
        return query.limit == nil ? rows : rows.reversed()
    }

    public func applyRetention(_ policy: RetentionPolicy, now: Date) async throws {
        guard let db else { return }
        let recentCutoff = now.addingTimeInterval(-policy.recentMetrics).timeIntervalSince1970
        let longTermCutoff = now.addingTimeInterval(-policy.longTermMetrics).timeIntervalSince1970
        let eventCutoff = now.addingTimeInterval(-policy.events).timeIntervalSince1970
        let aging = try loadAgingRawMetrics(recentCutoff: recentCutoff, longTermCutoff: longTermCutoff)
        let rolled = MetricDownsampler.collapse(aging, bucketSeconds: policy.downsampleBucket)

        try Self.exec(db, "BEGIN IMMEDIATE")
        do {
            if !rolled.isEmpty {
                try insertMetricsInTransaction(rolled)
            }
            try deleteRawOlderThan(recentCutoff)
            try deleteOlderThan(table: "metrics", cutoff: longTermCutoff)
            try deleteOlderThan(table: "events", cutoff: eventCutoff)
            try Self.exec(db, "COMMIT")
        } catch {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            throw error
        }
    }

    private func loadAgingRawMetrics(recentCutoff: Double, longTermCutoff: Double) throws -> [Metric] {
        guard let db else { return [] }
        let sql = """
            SELECT entity_json, value_json, dimensions_json, derivation_json,
                   id, wall_time, monotonic_ns, domain, name, unit, source, quality, retention_class
            FROM metrics
            WHERE wall_time < ? AND wall_time >= ? AND retention_class != 'longTerm'
            ORDER BY wall_time ASC, monotonic_ns ASC
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw StoreError.sqlite(Self.message(db))
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_double(statement, 1, recentCutoff)
        sqlite3_bind_double(statement, 2, longTermCutoff)
        var rows: [Metric] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(try decodeMetric(statement))
        }
        return rows
    }

    private func insertMetricsInTransaction(_ metrics: [Metric]) throws {
        guard let db, !metrics.isEmpty else { return }
        let sql = """
            INSERT OR REPLACE INTO metrics (
                id, wall_time, monotonic_ns, domain, name, entity_key, entity_json,
                value_json, unit, dimensions_json, source, quality, retention_class, derivation_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw StoreError.sqlite(Self.message(db))
        }
        defer { sqlite3_finalize(statement) }
        for metric in metrics {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            try bindMetric(statement, metric)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw StoreError.sqlite(Self.message(db))
            }
        }
    }

    private func deleteRawOlderThan(_ cutoff: Double) throws {
        guard let db else { return }
        let sql = "DELETE FROM metrics WHERE wall_time < ? AND retention_class != 'longTerm'"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw StoreError.sqlite(Self.message(db))
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_double(statement, 1, cutoff)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StoreError.sqlite(Self.message(db))
        }
    }

    private func deleteOlderThan(table: String, cutoff: Double) throws {
        guard let db else { return }
        let sql = "DELETE FROM \(table) WHERE wall_time < ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw StoreError.sqlite(Self.message(db))
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_double(statement, 1, cutoff)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StoreError.sqlite(Self.message(db))
        }
    }

    public func deleteAll() async throws {
        guard let db else { return }
        try Self.exec(db, "BEGIN IMMEDIATE")
        try Self.exec(db, "DELETE FROM metrics")
        try Self.exec(db, "DELETE FROM events")
        try Self.exec(db, "COMMIT")
    }

    private static func migrate(_ db: OpaquePointer) throws {
        try exec(db, "PRAGMA journal_mode = WAL")
        try exec(db, "PRAGMA foreign_keys = ON")
        let version = try userVersion(db)
        if version < 1 {
            try exec(db, """
                CREATE TABLE IF NOT EXISTS metrics (
                    id TEXT PRIMARY KEY,
                    wall_time REAL NOT NULL,
                    monotonic_ns INTEGER,
                    domain TEXT NOT NULL,
                    name TEXT NOT NULL,
                    entity_key TEXT NOT NULL,
                    entity_json TEXT NOT NULL,
                    value_json TEXT NOT NULL,
                    unit TEXT NOT NULL,
                    dimensions_json TEXT NOT NULL,
                    source TEXT NOT NULL,
                    quality TEXT NOT NULL,
                    retention_class TEXT NOT NULL,
                    derivation_json TEXT
                );
                CREATE TABLE IF NOT EXISTS events (
                    id TEXT PRIMARY KEY,
                    wall_time REAL NOT NULL,
                    monotonic_ns INTEGER,
                    domain TEXT NOT NULL,
                    type TEXT NOT NULL,
                    entity_key TEXT NOT NULL,
                    entity_json TEXT NOT NULL,
                    related_json TEXT NOT NULL,
                    summary TEXT NOT NULL,
                    metadata_json TEXT NOT NULL,
                    source TEXT NOT NULL,
                    quality TEXT NOT NULL,
                    privacy_class TEXT NOT NULL
                );
                CREATE INDEX IF NOT EXISTS idx_metrics_wall ON metrics(wall_time);
                CREATE INDEX IF NOT EXISTS idx_metrics_entity_name_wall ON metrics(entity_key, name, wall_time);
                CREATE INDEX IF NOT EXISTS idx_metrics_domain_wall ON metrics(domain, wall_time);
                CREATE INDEX IF NOT EXISTS idx_metrics_mono ON metrics(monotonic_ns);
                CREATE INDEX IF NOT EXISTS idx_events_wall ON events(wall_time);
                CREATE INDEX IF NOT EXISTS idx_events_entity_type_wall ON events(entity_key, type, wall_time);
                CREATE INDEX IF NOT EXISTS idx_events_domain_wall ON events(domain, wall_time);
                """)
            try exec(db, "PRAGMA user_version = 1")
        }
    }

    private static func userVersion(_ db: OpaquePointer) throws -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK, let statement else {
            throw StoreError.sqlite(message(db))
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(statement, 0))
    }

    private static func exec(_ db: OpaquePointer, _ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        let status = sqlite3_exec(db, sql, nil, nil, &error)
        if let error {
            let text = String(cString: error)
            sqlite3_free(error)
            if status != SQLITE_OK { throw StoreError.sqlite(text) }
        } else if status != SQLITE_OK {
            throw StoreError.sqlite(message(db))
        }
    }

    private static func message(_ db: OpaquePointer) -> String {
        sqlite3_errmsg(db).map { String(cString: $0) } ?? "sqlite error"
    }

    private func bindMetric(_ statement: OpaquePointer, _ metric: Metric) throws {
        sqlite3_bind_text(statement, 1, metric.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 2, metric.time.wallTime.timeIntervalSince1970)
        if let monotonic = metric.time.monotonicNanoseconds {
            sqlite3_bind_int64(statement, 3, Int64(monotonic))
        } else {
            sqlite3_bind_null(statement, 3)
        }
        sqlite3_bind_text(statement, 4, metric.domain.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 5, metric.name.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 6, metric.entity.identityKey, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 7, try encode(metric.entity), -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 8, try encode(metric.value), -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 9, metric.unit.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 10, try encode(metric.dimensions), -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 11, metric.source, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 12, metric.quality.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 13, metric.retentionClass.rawValue, -1, SQLITE_TRANSIENT)
        if let derivation = metric.derivation {
            sqlite3_bind_text(statement, 14, try encode(derivation), -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 14)
        }
    }

    private func bindEvent(_ statement: OpaquePointer, _ event: Event) throws {
        sqlite3_bind_text(statement, 1, event.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 2, event.time.wallTime.timeIntervalSince1970)
        if let monotonic = event.time.monotonicNanoseconds {
            sqlite3_bind_int64(statement, 3, Int64(monotonic))
        } else {
            sqlite3_bind_null(statement, 3)
        }
        sqlite3_bind_text(statement, 4, event.domain.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 5, event.type.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 6, event.entity.identityKey, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 7, try encode(event.entity), -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 8, try encode(event.relatedEntities), -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 9, event.summary, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 10, try encode(event.metadata), -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 11, event.source, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 12, event.quality.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 13, event.privacyClass.rawValue, -1, SQLITE_TRANSIENT)
    }

    private func decodeMetric(_ statement: OpaquePointer) throws -> Metric {
        let entity: Entity = try decode(statement, column: 0)
        let value: MetricValue = try decode(statement, column: 1)
        let dimensions: [String: String] = try decode(statement, column: 2)
        let derivation: Derivation? = sqlite3_column_type(statement, 3) == SQLITE_NULL
            ? nil
            : try decode(statement, column: 3)
        guard let id = uuid(statement, 4),
              let name = MetricName(rawValue: text(statement, 8)),
              let unit = Unit(rawValue: text(statement, 9)),
              let domain = TelemetryDomain(rawValue: text(statement, 7)),
              let quality = ObservationQuality(rawValue: text(statement, 11)),
              let retention = RetentionClass(rawValue: text(statement, 12)) else {
            throw StoreError.decodingFailed
        }
        let monotonic: UInt64? = sqlite3_column_type(statement, 6) == SQLITE_NULL
            ? nil
            : UInt64(sqlite3_column_int64(statement, 6))
        return Metric(
            id: id,
            time: ObservationTime(
                wallTime: Date(timeIntervalSince1970: sqlite3_column_double(statement, 5)),
                monotonicNanoseconds: monotonic
            ),
            domain: domain,
            name: name,
            entity: entity,
            value: value,
            unit: unit,
            dimensions: dimensions,
            source: text(statement, 10),
            quality: quality,
            retentionClass: retention,
            derivation: derivation
        )
    }

    private func decodeEvent(_ statement: OpaquePointer) throws -> Event {
        let entity: Entity = try decode(statement, column: 0)
        let related: [Entity] = try decode(statement, column: 1)
        let metadata: [String: String] = try decode(statement, column: 2)
        guard let id = uuid(statement, 3),
              let domain = TelemetryDomain(rawValue: text(statement, 6)),
              let type = EventType(rawValue: text(statement, 7)),
              let quality = ObservationQuality(rawValue: text(statement, 10)),
              let privacy = PrivacyClass(rawValue: text(statement, 11)) else {
            throw StoreError.decodingFailed
        }
        let monotonic: UInt64? = sqlite3_column_type(statement, 5) == SQLITE_NULL
            ? nil
            : UInt64(sqlite3_column_int64(statement, 5))
        return Event(
            id: id,
            time: ObservationTime(
                wallTime: Date(timeIntervalSince1970: sqlite3_column_double(statement, 4)),
                monotonicNanoseconds: monotonic
            ),
            domain: domain,
            type: type,
            entity: entity,
            relatedEntities: related,
            summary: text(statement, 8),
            metadata: metadata,
            source: text(statement, 9),
            quality: quality,
            privacyClass: privacy
        )
    }

    private func encode<T: Encodable>(_ value: T) throws -> String {
        String(data: try encoder.encode(value), encoding: .utf8) ?? "{}"
    }

    private func decode<T: Decodable>(_ statement: OpaquePointer, column: Int32) throws -> T {
        let json = text(statement, column)
        guard let data = json.data(using: .utf8) else { throw StoreError.decodingFailed }
        return try decoder.decode(T.self, from: data)
    }

    private func text(_ statement: OpaquePointer, _ column: Int32) -> String {
        guard let pointer = sqlite3_column_text(statement, column) else { return "" }
        return String(cString: pointer)
    }

    private func uuid(_ statement: OpaquePointer, _ column: Int32) -> UUID? {
        UUID(uuidString: text(statement, column))
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
