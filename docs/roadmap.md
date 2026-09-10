# Roadmap

## Delivery Strategy

Each milestone should be a coherent Git commit or small commit series, followed by a GitHub push. A milestone may be demonstrated or reviewed on its own; do not wait for the whole product to become valuable.

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

## Milestone 2: Telemetry Domain And Local Store

Deliverables:

- `Metric`, `Event`, `Entity`, `Capability`, time, quality, and retention domain types.
- SQLite schema and migrations.
- Deterministic clock and in-memory/test storage implementations.
- Retention/downsampling policy implementation.

Acceptance criteria:

- A process instance cannot be confused with a reused PID.
- Stored metrics use typed values and base units.
- Queries honor time range, entity, metric/event type, and gaps.
- Unit and persistence tests cover migrations, ordering, and retention.

## Milestone 3: Standard Collectors

Deliverables:

- CPU, memory, process, basic network, storage, battery, and thermal collectors where public APIs support them.
- Capability availability reporting and data freshness.
- Live overview replacing sample data.

Acceptance criteria:

- The collector work is not performed on the main actor.
- Missing data is visible as unavailable or stale.
- Collection continues to work without optional extensions.
- Resource usage of Mac Observer itself is measured and bounded.

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
