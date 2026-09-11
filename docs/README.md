# Mac Observer Documentation

Mac Observer is a privacy-minded macOS observability app. It answers a simple question first: **is my Mac okay?** From there, it supports a deliberate investigation path from a machine-wide signal to a specific process, subsystem, event, and time range.

This directory is the durable product and engineering reference. Treat it as the source of truth when product discussions, implementation shortcuts, and existing code disagree.

## Read This First

| Document | Use it for |
| --- | --- |
| [Product brief](product-brief.md) | Mission, user, scope, principles, and success criteria. |
| [Experience specification](experience.md) | Required interaction model, screens, and language. |
| [Architecture](architecture.md) | Module boundaries, data flow, storage, and query behavior. |
| [Telemetry contract](telemetry.md) | Canonical records, entity identity, retention, and collector rules. |
| [macOS capabilities](macos-capabilities.md) | Feasibility, APIs, permissions, and platform constraints. |
| [Privacy and security](privacy-security.md) | Data handling rules and capability consent requirements. |
| [Roadmap](roadmap.md) | Delivery increments and acceptance criteria. |
| [Contributor guide](contributor-guide.md) | Development conventions and how to make a change safely. |
| [Decisions and open questions](decisions.md) | Recorded decisions and questions that still need an owner. |

## Current State

The repository is in a polish series after M1–M5. Overview and resource profiles bind to live collectors and must not invent numbers. Capabilities lists those sources and can turn them off. Optional Internet Check starts off and only leaves this Mac when you run a check. Network shows local gateway and DNS from SystemConfiguration. Settings shows a documented retention policy and can delete the local SQLite history. Events queries that store by time range and can filter by domain or entity. Metric tiles open a history chart from the same store. Clicking a chart point loads events in that interval. Overview can show a deterministic explanation after memory pressure, thermal change, or sustained CPU. Metrics older than 7 days are stored as 15-minute downsampled points for 90 days. M6 privileged Network Extension / Endpoint Security remains blocked on Apple entitlements. Security and Privacy profiles stay parked.

## Product In One Sentence

Mac Observer is a local-first Mac health dashboard that turns abnormal resource use into an understandable, time-bounded investigation without making surveillance the default.
