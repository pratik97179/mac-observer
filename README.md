# Mac Observer

A privacy-minded, local macOS observability app. It starts with one question: is my Mac okay?

## Milestones

1. App foundation and health overview
2. Live standard Overview (domain types, collectors, no SQLite yet)
3. Local metrics and event storage
4. Contextual inspection and event timeline
5. Explain-this correlations and optional privileged capabilities

## Development

Open the macOS app:

```sh
open MacObserver.xcodeproj
```

Or run the Swift package executable from the repository root:

```sh
swift run
```

Overview still uses labeled sample readings. Other sidebar views are placeholders. No system data is collected or persisted yet.
