# Roadmap

## Delivery Strategy

Ship in small GitHub pushes. Each checkpoint is reviewable on its own. Do not wait for a finished product.

The agent implements one checkpoint, then stops. It does not commit or push. The maintainer commits and pushes when ready.

Current series (live dashboard first) is complete. Persistence series:

1. SQLite store, queries, and retention.
2. Persist live collector output.
3. Downsampling and inspection charts later.

Resource sidebar profiles now share the live snapshot. Capabilities can disable a standard collector. Settings can delete local history. Events queries SQLite for 1 hour, 24 hours, or 7 days. Metric tiles open a query-backed history chart. Persistent downsampling is not shipped yet.

## Milestone 1: Application Foundation

**Status:** Complete locally.

Deliverables:

- Swift package and native SwiftUI entry point.
- Navigation shell and overview composition.
- Display-only sample values.
- Project documentation and Git baseline.

Acceptance criteria:

- The app builds with the selected supported Xcode toolchain.
- The overview makes it obvious that readings are samples.
- No system data is read or stored.

## Milestone 2: Live Standard Overview

**Status:** Complete locally.

Deliverables:

- Real macOS app bundle and working profile routing.
- `Metric`, `Event`, `Entity`, `Capability`, time, and quality domain types.
- Collector protocol, in-memory live buffer, and fakes.
- CPU, memory, process, basic network, storage, battery, and thermal collectors where public APIs support them.
- Live Overview replacing sample data, with freshness and unavailable states.
- Live Performance, Network, Processes, Storage, and Power profiles on the same snapshot.

Acceptance criteria:

- Sidebar selection changes the detail pane.
- A process instance cannot be confused with a reused PID.
- Stored-on-disk metrics are not required for Overview.
- Collector work is not performed on the main actor.
- Missing data is visible as unavailable or stale.
- Collection works without optional extensions.
- Resource usage of Mac Observer itself is measured and bounded.

## Milestone 3: Telemetry Domain Persistence

**Status:** In progress. Live collectors persist to SQLite. Events can query stored history by time range. Metric inspection charts query stored samples and bucket them for drawing. Persistent downsampling is not shipped yet.

Deliverables:

- SQLite schema and migrations for metrics and events.
- Deterministic clock and in-memory/test storage implementations.
- Retention and downsampling policy implementation.

Acceptance criteria:

- Stored metrics use typed values and base units.
- Queries honor time range, entity, metric/event type, and gaps.
- Unit and persistence tests cover migrations, ordering, and retention.

## Milestone 4: Contextual Inspection

Deliverables:

- Metric detail views with breakdown and chart.
- Entity detail views, beginning with process instances.
- Range selection and query-backed navigation between chart and timeline.
- Basic Command-K navigation search.

Acceptance criteria:

- A user can move from a top contributor to its history without losing the selected time range.
- All displayed chart values correspond to a typed query result.
- Search result targets carry sufficient context to open a useful view.

## Milestone 5: Events And Deterministic Explanations

Deliverables:

- Unified event timeline with filters.
- Health state rules for supported resource conditions.
- Explanation cards with cited observations and inspect actions.

Acceptance criteria:

- Explanations are reproducible from stored telemetry.
- The app distinguishes direct evidence from correlation.
- Event volume and retention remain bounded in normal use.

## Milestone 6: Optional Capabilities

Deliverables:

- Capabilities and permissions screen.
- Carefully scoped optional network or Endpoint Security integration only after feasibility and entitlement validation.
- External diagnostics as a separately enabled action.

Acceptance criteria:

- Standard product behavior remains intact when every optional capability is disabled.
- Consent, retention, and revocation are testable.
- Required Apple approvals and distribution constraints are documented before release planning.

## Not Scheduled Yet

- Remote sync or fleet management.
- AI-generated recommendations.
- Payload-level traffic inspection.
- Security enforcement or threat detection.
