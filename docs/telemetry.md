# Telemetry Contract

## Purpose

The telemetry contract makes heterogeneous macOS observations queryable without erasing their source, quality, or privacy characteristics. It is a product contract as much as a storage format.

## Canonical Record Types

### Metric

A metric is a sampled or aggregated measurement that can be charted across time.

| Field | Meaning |
| --- | --- |
| `id` | Immutable record identifier. |
| `wallTime` | User-facing timestamp. |
| `monotonicTime` | Duration-safe timestamp within a boot/session. |
| `domain` | CPU, memory, storage, network, power, thermal, and so on. |
| `name` | Stable, namespaced metric identifier such as `memory.used_bytes`. |
| `entity` | System, interface, process instance, volume, device, or capability. |
| `value` | Typed scalar value; numerical metrics remain numerical. |
| `unit` | Canonical unit, for example bytes, bytes-per-second, percent, watts, or count. |
| `dimensions` | Bounded structured attributes, such as interface name or direction. |
| `source` | Collector and platform source identity. |
| `quality` | Direct, derived, estimated, stale, or unavailable. |
| `retentionClass` | Live, recent, long-term, or discardable. |

Metrics are immutable. Derived values store their derivation source and method instead of overwriting direct readings.

### Event

An event records a meaningful discrete occurrence.

| Field | Meaning |
| --- | --- |
| `id` | Immutable event identifier. |
| `wallTime` and `monotonicTime` | Time representation as defined for metrics. |
| `domain` | Event subsystem. |
| `type` | Stable, namespaced event type such as `process.launched`. |
| `entity` | Primary observed entity. |
| `relatedEntities` | Optional, bounded links to other entities. |
| `summary` | Concise user-facing sentence. |
| `metadata` | Structured, versioned detail for an inspector. |
| `source` and `quality` | Provenance and observation confidence. |
| `privacyClass` | Collection sensitivity and export restriction. |

Events are not free-form logs. New event types require an owner, a documented producer, retention behavior, and privacy classification.

| Type | Producer | When it fires |
| --- | --- | --- |
| `memory.pressure_changed` | `standard.cpu_memory` | Memory pressure state differs from the previous sample. The first sample is not an event. |
| `thermal.state_changed` | `standard.cpu_memory` | ProcessInfo thermal state differs from the previous sample. The first sample is not an event. |
| `capability.availability_changed` | Collector pipeline | A standard collector is disabled or re-enabled in Capabilities. Disabled collectors at launch also emit this. |

## Entity Identity

An entity is a typed reference, not a display string. Required forms include:

- `system`: one record per boot session.
- `processInstance`: PID plus start time and boot/session identity; bundle identifier, executable path, signing identity, and parent are optional attributes.
- `app`: stable bundle identifier where available.
- `networkInterface`: stable interface name plus hardware identity where available.
- `volume`: volume UUID where available.
- `device`: platform-provided stable identifier where privacy rules allow retention.
- `capability`: the collector or optional extension that produced an observation.

Never join process history by PID alone. Never join an entity by display name alone.

## Metric Names And Units

Names are lowercase and namespaced by domain. Use base units in storage and format for display at the UI boundary.

| Example name | Stored unit | Entity |
| --- | --- | --- |
| `cpu.utilization_ratio` | ratio from 0 to 1 | system or process instance |
| `memory.used_bytes` | bytes | system |
| `memory.swap_used_bytes` | bytes | system |
| `network.rx_bytes_per_second` | bytes per second | interface or process when supported |
| `storage.write_bytes_per_second` | bytes per second | volume or process when supported |
| `power.battery_charge_ratio` | ratio from 0 to 1 | system |
| `thermal.state` | enumerated state | system |

Do not store formatted values such as `11.8 GB` or `32%` as telemetry.

## Sampling And Retention

The initial target policy is intentionally conservative and may be refined after measurement:

| Class | Resolution | Suggested retention | Intended use |
| --- | --- | --- | --- |
| Live | 1 to 10 seconds | Memory only or short local buffer | Responsive current UI and immediate explanations. |
| Recent | 1 minute | 7 days | Investigation of recent slowdowns and changes. Metric inspection queries this table and buckets to about 240 points for the chart. |
| Long-term | 5 to 15 minutes | 90 days | Trend comparison without a large local database. |
| Events | Individually preserved | 30 days by default | Timeline and causal context. The Events screen queries up to 500 newest rows in the selected range. |

Retention is a user-visible privacy control. Individual sensitive event categories may use shorter defaults. Downsampling records must preserve min, max, average, count, and gap information where a chart needs them.

## Cardinality Rules

Unbounded dimensions make a local time-series store unusable. Domain names, URLs, remote addresses, file paths, and arbitrary process arguments require explicit policy. The default is to aggregate, hash only when there is a documented user benefit, or not retain the field at all.

## Health And Explanation Inputs

Health rules consume typed metrics and events, never display strings. A rule must document its threshold, look-back window, suppression conditions, and the evidence it can cite. The rule result is itself an event so it can be inspected and audited.
