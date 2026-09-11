# Contributor Guide

## Before Changing Code

1. Read [the product brief](product-brief.md), [architecture](architecture.md), and the relevant domain document.
2. Check [decisions and open questions](decisions.md) for an existing constraint.
3. Keep the change within one push checkpoint unless scope expansion is explicitly agreed.
4. Update documentation in the same change when behavior, data collection, storage, permissions, or product scope changes.

## Implementation Conventions

- Use Swift and SwiftUI for the native application.
- Keep domain types free of SwiftUI, SQLite implementation details, and platform framework dependencies.
- Prefer structured macOS APIs over parsing command-line output.
- Use typed units and canonical base values in storage; format only at the display boundary.
- Keep collectors isolated from the main actor and make them testable with fake time and sinks.
- Add only the smallest abstraction that matches an established boundary in [architecture](architecture.md).
- Never add a privileged capability as a hidden prerequisite for a standard dashboard feature.

## Testing Expectations

| Change type | Minimum verification |
| --- | --- |
| Domain model | Unit tests for invariants, serialization, and identifiers. |
| SQLite/store | Migration, query, retention, and ordering tests. |
| Collector | Fake-source tests plus a documented manual macOS validation path. |
| Explanation rule | Fixture-based tests proving threshold and evidence behavior. |
| SwiftUI view | Preview/sample-state coverage and manual checks for unavailable, stale, and long-value states. |
| Permission or extension | Capability disclosure, revocation, and no-access behavior tests. |

## Git And Pushes

Use small commits with a single intent. Suggested prefixes are `docs:`, `feat:`, `fix:`, `test:`, `refactor:`, and `chore:`. Do not mix a broad refactor with a behavioral feature.

The coding agent implements one checkpoint and stops. It never runs `git commit` or `git push`. The maintainer owns every push to `origin`.

When the maintainer asks for the git command, use:

```sh
git add . && git commit -m "[commit message]" && git push
```

Commit messages stay under 15 words.

Before a push:

1. Inspect `git status` and preserve unrelated work.
2. Run the relevant tests and formatting checks.
3. Record any environment limitation honestly in the commit/PR notes.
4. Ensure new data collection or persistence is described in the docs.

## Current Toolchain Note

Develop against Command Line Tools. On this Mac the compiler is Swift 6.4. It builds SwiftUI against `MacOSX26.5.sdk`. The `macosx` symlink currently points at 27.0, which this compiler cannot compile (`SwiftUIMacros`, `_SwiftifyImport`). `scripts/dev-run.sh` pins `SDKROOT` to 26.5.

Because the kernel is newer than that SDK, collectors may only call Darwin APIs that take an explicit buffer size. Process CPU and RSS use `proc_pidinfo`. Do not call `proc_pid_rusage`.

Run the app with `./scripts/dev-run.sh`. That produces `.build/MacObserver.app`. Do not `open` the product under `swift build --show-bin-path`; Launch Services treats that file as a command-line tool. Do not use `swift run`; it invokes `actool` for asset catalogs, and Command Line Tools cannot run `actool`.

`scripts/dev-test.sh` runs `swift test` with the Testing macros plugin this Command Line Tools install keeps under `usr/lib/swift/host/plugins/testing`.
