# Experience Specification

## Navigation Model

The application has a persistent sidebar for profiles and one detail area. Profiles are saved viewpoints, not independent products.

Shipped now:

- Overview, Performance, Network, Processes, Storage, Power: live readings from the same snapshot
- Capabilities: standard collectors, live state, and an enable/disable path
- Settings: retention policy, history path, and delete local history
- Events: local SQLite history with 1 hour, 24 hour, and 7 day ranges, filterable by domain

Later, when supported data exists:

- Security
- Privacy

The selected context determines the detail view. Selecting Chrome in Overview should open Chrome’s investigation context; it should not merely apply a filter to the old machine-wide screen.

## Overview

The default screen answers only: **Is my Mac okay, and what is currently consuming resources?**

It contains:

- Machine identity and one health state: Healthy, Attention, or Investigate. First paint before any sample is shown as Sampling, not Attention.
- A compact resource summary: CPU, memory, network, storage I/O, power, thermal state, and battery when available. Tiles and the activity table keep a reserved skeleton; pending values are "—" until a sample arrives. Layout does not reflow when those strings change.
- A short ranked activity list. The columns must correspond to the currently relevant types of activity, not every possible metric. Unused rows stay as placeholders so the table height is stable.
- A visible data freshness indicator when a collector is stale or unavailable.

It does not contain timelines, connection lists, dense tables, or permissions prompts by default.

## Metric Inspection

Selecting a metric tile with a chevron opens a history view. It shows the latest stored value, a 1 hour / 24 hour / 7 day range, a chart of typed query results (about 240 buckets), and related events in the same domain. Network and Storage totals that sum several entities are not inspectable yet.

Every metric inspection view has the same structural order:

1. Current value and current state.
2. Breakdown appropriate to the metric.
3. Time range and chart.
4. Related entities and events.
5. Actions to narrow the investigation.

The user must be able to move from a chart point to events in the matching interval and back without losing their current context.

## Entity Inspection

An entity is any named thing that may own or produce telemetry: a process instance, app, network interface, volume, device, or capability. An entity view is the primary investigation unit.

For a process, the view may show CPU, memory, GPU where honestly available, disk I/O, network activity, process ancestry, signing identity, and lifecycle events. Its tabs or segmented controls are scoped to that process; they must not silently revert to global data.

Process identity must include more than a display name or PID. A PID can be reused, so the model uses a process start time plus PID, and may associate a stable app identity when available.

## Events Timeline

The timeline is a cross-domain investigation surface, not an unbounded log dump. Events reads stored rows for the selected range (1 hour, 24 hours, or 7 days), newest first, and can filter by domain. Entity and importance filters remain later work.

Shipped event types: `memory.pressure_changed`, `thermal.state_changed`, and `capability.availability_changed`. Process lifecycle and I/O bursts are not emitted yet. The live buffer still caps in-memory events at 200; the Events screen queries SQLite instead.

Events need a concise human summary, a source capability, a precise timestamp, and structured detail for the inspector. Avoid recording high-frequency resource samples as individual events.

## Global Search

Command-K opens a search surface that accepts application names, process names, metric names, hostnames or addresses when present locally, network interfaces, and settings. Search results are navigation targets with a small contextual preview.

Search is deterministic in the first release. Natural-language query interpretation is not required to make it useful.

## Explain This

An explanation is a deterministic correlation generated after a supported state change. It contains the detected state and threshold, relevant time window, top observed changes ranked by contribution/confidence, the measurements behind each claim, and an Inspect action.

For example: “Memory pressure became high at 11:42. Swap grew by 1.4 GB over 90 seconds. Docker and Chrome increased resident memory by 1.2 GB and 820 MB.”

An explanation must say “may be related” whenever the app cannot establish direct ownership or causality.

## Capabilities And Permissions

Capabilities is a first-class screen. Each capability shows its state, the data it makes available, collection method, whether data remains local, and an enable/disable path. It distinguishes standard access, user-authorized capability, Apple-restricted system extension, and external lookup.

## Writing And Visual Tone

Use direct, calm language. Prefer “Memory pressure is normal” to “Optimization complete.” Use units consistently, preserve significant precision only when it changes a decision, and make uncertainty legible. The interface should feel like a focused instrument panel, not a marketing page or security scare screen. Motion is quiet: ease in and out, short fades, no bounce.
