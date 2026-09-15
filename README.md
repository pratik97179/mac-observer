# Mac Observer

A privacy-minded, local macOS observability app. It starts with one question: is my Mac okay?

## Milestones

1. App foundation and health overview
2. Live standard Overview (domain types, collectors, no SQLite yet)
3. Local metrics and event storage
4. Contextual inspection and event timeline
5. Explain-this correlations and optional privileged capabilities

## Development

The GUI is a SwiftUI `App`. It must run as a macOS application bundle, not as a raw SwiftPM binary. `open` on the naked executable launches Terminal and the process is not a normal app.

```sh
./scripts/dev-run.sh
```

That script points Swift at Command Line Tools and `MacOSX26.5.sdk` (the SDK this compiler can actually compile), builds `MacObserver`, stages `.build/MacObserver.app`, and opens the bundle.

For layout work with canned telemetry (no live collectors):

```sh
./scripts/dev-preview.sh
```

That launches the full app with fake processes, charts, events, and capability rows. Run it again after a UI change; it replaces the previous preview process. Live collectors stay on `./scripts/dev-run.sh`.

Do not use `swift run`. SPM tries to compile `Assets.xcassets` with `actool`, which needs a full Xcode.app. This Mac only has Command Line Tools.

If Xcode matches this Mac, you can also open `MacObserver.xcodeproj`.

Domain and collector tests:

```sh
./scripts/dev-test.sh
```

Overview, Performance, Network, Processes, Storage, and Power show live readings. Network includes local gateway and DNS. Click a metric tile with a chevron to open stored history. After memory pressure, thermal elevation, or sustained CPU, Overview shows an explanation card with Inspect actions. Capabilities lists each collector, including optional Internet Check which starts off. Settings can delete local history. Events lists discrete stored changes for the last hour, 24 hours, or 7 days. Live observations are saved locally in SQLite under Application Support. Raw metrics stay 7 days; older points are kept as 15-minute averages for 90 days.
