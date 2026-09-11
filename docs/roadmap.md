# Roadmap

## Delivery Strategy

Ship in small GitHub pushes. Each checkpoint is reviewable on its own. Do not wait for a finished product.

The agent implements one checkpoint, then stops. It does not commit or push. The maintainer commits and pushes when ready.

## Polish series

**Status:** Complete locally. Privileged Network Extension and Endpoint Security remain blocked on entitlements.

Pause new collectors and privileged work. Make Overview, search, inspect, and profiles match what is actually collected.

1. Honest Overview: no synthetic GPU, thermal °C, storage category split, connection count, or P/E split. Battery, pressure, health copy, and freshness match typed metrics.
2. Controls that do what they say: System Activity is recent live samples; Command-K opens a process sheet; Performance inspect links work; Settings copy matches a forced dark cockpit and a documented, non-editable retention policy.
3. Profiles and inspect: Performance memory breakdown, Network and Processes column headers, inspect loading and human titles, Capabilities selects the first source by default, Network does not pin a packet-loss error on a healthy path.
4. This roadmap: polish is current; M6 privileged work stays blocked on entitlements; Security and Privacy profiles stay parked until there is real data.

Current series (live dashboard first) is complete. Persistence series:

1. SQLite store, queries, and retention.
2. Persist live collector output.
3. Downsampling and inspection charts.

Resource sidebar profiles now share the live snapshot. Capabilities can disable a standard collector. Settings can delete local history. Events queries SQLite for 1 hour, 24 hours, or 7 days. Metric tiles open a query-backed history chart. Overview can explain memory pressure, thermal elevation, and sustained CPU from stored telemetry. The Network profile shows local gateway and DNS from SystemConfiguration. Retention keeps 7 days of raw samples and 90 days of 15-minute downsampled history.

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

**Status:** Complete locally. Live collectors persist to SQLite. Events can query stored history by time range. Metric inspection charts query stored samples and bucket them for drawing. Retention downsamples metrics older than 7 days into 15-minute long-term points kept for 90 days.

Deliverables:

- SQLite schema and migrations for metrics and events.
- Deterministic clock and in-memory/test storage implementations.
- Retention and downsampling policy implementation.

Acceptance criteria:

- Stored metrics use typed values and base units.
- Queries honor time range, entity, metric/event type, and gaps.
- Unit and persistence tests cover migrations, ordering, and retention.

## Milestone 4: Contextual Inspection

**Status:** Complete locally. Metric inspect charts are query-backed. Clicking a chart point re-queries events in that interval and keeps the selected 1 hour / 24 hour / 7 day range. Process inspect can open CPU or memory history for that instance. Command-K already navigates to those targets.

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

**Status:** Complete locally. Events already filter by domain and range. Overview shows an explanation card after memory pressure, thermal elevation, or sustained CPU. Claims cite measurements, mark process and disk rows as correlation with “may be related”, and Inspect opens the same query-backed history views. Each explanation is stored once as `explanation.generated`.

Deliverables:

- Unified event timeline with filters.
- Health state rules for supported resource conditions.
- Explanation cards with cited observations and inspect actions.

Acceptance criteria:

- Explanations are reproducible from stored telemetry.
- The app distinguishes direct evidence from correlation.
- Event volume and retention remain bounded in normal use.

## Milestone 6: Optional Capabilities

**Status:** In progress locally. Capabilities lists each source with collection method, whether data stays local, privacy class, and an enable path. External Internet Check is off by default, requires an in-app disclosure, and does not request the network until the user runs a check. Turning a source off can keep or delete that source's history. Network Extension and Endpoint Security are not implemented; they still need Apple entitlements before any collector.

Deliverables:

- Capabilities and permissions screen.
- Carefully scoped optional network or Endpoint Security integration only after feasibility and entitlement validation.
- External diagnostics as a separately enabled action.

Acceptance criteria:

- Standard product behavior remains intact when every optional capability is disabled.
- Consent, retention, and revocation are testable.
- Required Apple approvals and distribution constraints are documented before release planning.

## Not Scheduled Yet

- Security and Privacy sidebar profiles until there is real collector data.
- Remote sync or fleet management.
- AI-generated recommendations.
- Payload-level traffic inspection.
- Security enforcement or threat detection.
