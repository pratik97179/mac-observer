# Product Brief

## Mission

Help a technically curious Mac user understand current system health and trace a meaningful change back to its likely cause, without requiring them to learn where each metric lives or surrender their device data to a cloud service.

## Product Shape

Mac Observer is not a replacement for every administration or security product. It is a cohesive local observability workspace with three progressively deeper modes:

1. **Orient:** see whether the machine is healthy and what is consuming resources.
2. **Inspect:** select a metric, process, interface, or event to see relevant detail in context.
3. **Explain:** correlate a recent abnormal condition with the smallest useful set of contributing changes.

The design should never present the full complexity of the operating system before the user asks for it.

## Target User

The primary user is a developer, designer, power user, or technically confident Mac owner who needs a clear answer during slowdowns, battery drain, unexpected network activity, or storage pressure. They value credible data, privacy, and direct control more than elaborate dashboards.

The working assumption is a single-user personal Mac. Managed fleets, remote administration, cloud aggregation, and enterprise policy enforcement are out of scope unless the product direction changes explicitly.

## Jobs To Be Done

| Situation | User need | Product outcome |
| --- | --- | --- |
| The Mac feels slow. | Identify whether CPU, memory, disk, or thermal state is responsible. | A health summary points to a constrained resource and the leading contributors. |
| One app behaves oddly. | Understand its resource use and recent activity. | An entity page shows its CPU, memory, I/O, network, and related events. |
| A spike has already passed. | Reconstruct what changed around it. | A filtered timeline and historical metrics preserve enough context to investigate. |
| A permission is requested. | Know exactly why it is needed and what it unlocks. | A capability screen explains the data source, scope, risk, and reversible action. |
| An alert appears. | Decide whether it matters and what to do next. | A deterministic explanation cites observations and provides an inspection path. |

## Principles

### Context before density

The default view is a calm overview, not a wall of diagnostics. Details appear after an intentional click or search.

### One system, many lenses

Overview, Performance, Network, Processes, Storage, Power, Security, Privacy, and Events are views over the same telemetry. A profile must not become a silo with a separate data model.

### Evidence before inference

The application may correlate observations, but it must identify correlations as evidence rather than claim causality it cannot prove. “Memory pressure rose while Docker memory increased by 1.4 GB” is acceptable; “Docker caused the problem” needs stronger evidence.

### Local by default

System telemetry stays on the Mac unless a user enables a narrowly defined external diagnostic action. There is no account requirement and no default cloud sync.

### Progressive privilege

The standard application must remain genuinely useful without a system extension, Endpoint Security entitlement, or network interception. Optional deep inspection is additive, reversible, and explained in plain language.

### Honest gaps

Unavailable or partial data must be represented as such. The UI must not imply that an estimate is direct measurement or that all traffic and all process activity is observable.

## Non-Goals For The Initial Product

- Antivirus, endpoint detection and response, or policy enforcement.
- Packet capture, payload inspection, or a cloud network archive.
- Remote fleet management or shared dashboards.
- A general-purpose log viewer.
- Advice that changes the user’s system automatically.
- A promise of complete per-process GPU, energy, or encrypted-DNS attribution.

## Success Criteria

The first useful release succeeds when a user can:

1. Open the app and understand current CPU, memory, network, storage, power, and thermal state within a few seconds.
2. Identify the top process contributors for the currently relevant resource.
3. Select a metric or process and receive a focused historical view, rather than another dashboard.
4. See a clear, locally generated explanation for a supported abnormal condition.
5. Understand the exact data and privacy consequence before enabling any optional capability.
