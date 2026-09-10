# Architecture

## Overview

Mac Observer is a local event and metrics pipeline with a SwiftUI client. The UI never reads macOS APIs directly. Collectors own platform access, normalize their observations, and publish them through one internal telemetry interface.

```text
macOS APIs / optional system extensions / external diagnostics
                         |
                         v
                    Collectors
                         |
                         v
              Telemetry normalization
                    /              \
                   v                v
             Metrics store      Event store
                    \              /
                     v            v
                      Query service
                           |
                           v
                        SwiftUI
```

## Modules

| Module | Responsibility | Must not do |
| --- | --- | --- |
| `App` | App lifecycle, dependency composition, navigation. | Call system APIs or contain collector-specific logic. |
| `Domain` | Typed telemetry records, entity identities, health rules, and query types. | Depend on SwiftUI, SQLite, or specific macOS frameworks. |
| `Collectors` | Obtain readings from one platform source and report availability. | Make presentation decisions or write directly to UI state. |
| `Normalization` | Validate units, associate entities, assign source metadata, and deduplicate. | Invent a measurement when a source is unavailable. |
| `Storage` | Persist and retrieve normalized data with retention. | Encode UI navigation state. |
| `Query` | Join metrics and events into time-bounded investigation results. | Reach around storage into collectors. |
| `Explanation` | Apply deterministic, documented rules to a query window. | Present ungrounded diagnosis as fact. |
| `Capabilities` | Describe and manage access state for optional collection. | Hide a data collection consequence. |
| `UI` | Render state, navigate context, and issue typed queries. | Own telemetry persistence or permission policy. |

## Collector Contract

Each collector reports a capability descriptor and emits either normalized observations or an explicit availability state. A collector is independently startable, stoppable, and testable with a fake clock and sink.

```swift
protocol TelemetryCollector {
    var capability: CapabilityDescriptor { get }
    func start(sink: TelemetrySink) async throws
    func stop() async
}
```

The exact Swift API can change, but the ownership boundary cannot: the collector publishes observations; the pipeline assigns retention and storage behavior.

## Storage

SQLite is the intended local store. It is mature, inspectable, transactional, and sufficient for the expected scale. Do not introduce a custom time-series database.

Store metrics and events separately. Metrics are high-volume numerical observations optimized for range queries and downsampling. Events are individually preserved structured records optimized for entity and time filtering.

Required database characteristics:

- Explicit schema versions and migrations.
- Indexed queries by monotonic time, wall-clock time, entity, domain, and metric/event type.
- Batched writes off the main actor.
- Transactional retention and downsampling jobs.
- A way to delete all locally retained telemetry on request.

## Query Semantics

All investigations are explicit queries. A query has a time window, optional entity selector, domains, metric names or event types, granularity, and ordering.

Examples: all telemetry for this Chrome process instance from 11:40 to 11:45; memory-pressure transitions plus top memory contributors around this interval; network interface changes during CPU above 90%.

The query layer owns join behavior. The UI must not combine unrelated raw arrays and label the result as a correlation.

## Time And Failure Behavior

Every record carries wall-clock time and a monotonic timestamp when available. Wall-clock time makes results readable; monotonic time prevents clock changes from corrupting durations and ordering. The session/boot identity is stored with each record so a restart becomes a visible boundary.

The app must remain usable when a collector fails, a permission is declined, a database is unavailable, or a privileged extension is absent. Report the capability as unavailable or stale, retain the last known reading with its age, and do not fabricate a healthy state.
