# Decisions And Open Questions

## Recorded Decisions

| Decision | Status | Rationale |
| --- | --- | --- |
| Build a local-first macOS application. | Accepted | The value is immediate machine understanding; cloud collection would add privacy cost without helping the core workflow. |
| Use SwiftUI for the application interface. | Accepted | It is the native UI direction and matches the existing project shell. |
| Use SQLite for local metrics and events. | Accepted | It offers sufficient query power, migrations, inspectability, and operational simplicity. |
| Model metrics and events separately. | Accepted | High-frequency numerical history and discrete investigation context have different retention and query needs. |
| Make entity identity explicit. | Accepted | Names and PIDs are not stable enough for correct historical attribution. |
| Ship standard telemetry before privileged features. | Accepted | The base product must be useful without sensitive or Apple-restricted capabilities. |
| Start explanations with deterministic rules. | Accepted | Evidence-backed correlation is more useful and auditable than speculative automation. |
| Treat network interception as optional. | Accepted | It changes privacy and deployment expectations and is not a prerequisite for the core product. |
| Run the SwiftUI client as an app bundle. | Accepted, 2026-09-11 | A SwiftPM executable is not an `APPL` bundle. Launch Services opens it in Terminal. Stage `.build/MacObserver.app` via `scripts/dev-run.sh` until Xcode matches the host OS. |
| Compile with Command Line Tools and the 26.5 SDK on macOS 27. | Accepted, 2026-09-11 | Xcode 26.6 GUI does not launch. CLT Swift 6.4 cannot compile the 27.0 SDK (`SwiftUIMacros`, `_SwiftifyImport`). The 26.5 SDK is the compiler-compatible SDK; collectors must not assume kernel struct sizes match that SDK. |
| Sample process resources with `proc_pidinfo`. | Accepted, 2026-09-11 | `proc_pid_rusage` writes a flavor-sized record with no caller length. On macOS 27 that overflowed `rusage_info_v4` (296 bytes vs current 464) and aborted the pipeline. |
| Ship live standard telemetry before local SQLite. | Accepted, 2026-09-11 | A polished Overview is the product users judge. Domain types still land first; persistence waits until live readings exist. |
| Deliver in progressive GitHub pushes. | Accepted, 2026-09-11 | Each checkpoint is a small commit the maintainer pushes. The coding agent never commits or pushes. |

## Working Assumptions

These assumptions guide the current design but can change with explicit product direction:

- The product is for a single person using one Mac at a time.
- The first public target is a recent Apple-silicon Mac running a modern supported macOS release.
- Local history defaults to a bounded window rather than indefinite archival.
- The UI favors investigation and understanding over automatic remediation.

## Questions Requiring A Decision Before Implementation

| Question | Why it matters | Default until decided |
| --- | --- | --- |
| What exact macOS versions are supported? | API availability, package deployment target, testing matrix. | Target current macOS; document actual minimum before release. |
| Will distribution be App Store, Developer ID, or both? | Entitlements, system extensions, and review constraints differ. | Do not commit to privileged features. |
| What local-history duration should users receive? | Database size and privacy expectation. | 7 days recent metrics, 90 days downsampled history, 30 days events. |
| Is process network attribution essential to the first release? | It could force a privileged design prematurely. | No; provide interface-level network visibility first. |
| Which health states deserve explanations first? | Defines initial rules and fixtures. | Memory pressure, sustained CPU, disk pressure/I/O, and thermal state. |
| Should diagnostics export exist in the first release? | It changes privacy/UI scope. | No. |
| What is the final product name and visual identity? | Affects bundle identifiers, asset work, and documentation language. | Use `Mac Observer` as a working name. |

## Change Control

When resolving an open question, update this document with the decision, date, owner if known, and affected documentation. When a previously accepted decision changes, preserve the prior rationale in Git history and document the replacement decision rather than silently rewriting the project’s direction.
