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

The repository Overview is bound to live standard collectors. Other profiles remain placeholders. History is session-only; SQLite is next.

## Product In One Sentence

Mac Observer is a local-first Mac health dashboard that turns abnormal resource use into an understandable, time-bounded investigation without making surveillance the default.
