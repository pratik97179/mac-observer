# Privacy And Security

## Privacy Position

Mac Observer observes sensitive facts about a person’s device use. The product’s credibility depends on minimizing collection, keeping it local, and making each expansion of access intelligible before it happens.

## Default Rules

- No account, cloud upload, telemetry beacon, or remote collection by default.
- Persist only data needed for the documented investigation experience.
- Do not inspect or retain network payloads in the standard product.
- Do not initiate public-IP, ASN, ISP, geolocation, or diagnostic requests until the user asks.
- Do not collect content from user files, clipboard, camera, microphone, or messages.
- Every stored record has a retention class and privacy class.
- A user can delete locally retained history without uninstalling the application.
- Standard collectors can be turned off from Capabilities. Disabled collectors stop immediately and do not emit further samples.

## Data Classes

| Class | Examples | Default handling |
| --- | --- | --- |
| Operational | CPU, memory, disk capacity, thermal state, generic interface counters. | Local, retained under normal metrics policy. |
| Identifying device context | Hostname, SSID/BSSID, local addresses, hardware identifiers. | Local; minimize display and retention; never transmit by default. |
| Sensitive activity metadata | Process executable paths, signing data, connection endpoints, DNS names, event details. | Feature-gated; shortest practical retention; no export by default. |
| Content | Packet payload, credentials, file contents, communications. | Out of scope. Do not collect. |

## Consent Model

A system prompt is not a sufficient explanation. Before prompting for a capability, show an app-owned disclosure containing the capability name, data categories, reason, effect of denial, local retention, and disable path.

For optional deep network or security capability, activation must be a separate affirmative action. The overview never uses fear-based copy to drive activation. Revoking a capability stops future collection; the UI offers a choice to retain or delete history collected by that capability.

## External Requests

External requests are distinct from device permissions. Show the provider or endpoint category where feasible, the data sent, why it is needed, and whether a result will be stored. Cache enrichment sparingly and allow the user to clear it.

## Logging And Diagnostics

Application logs must not contain raw telemetry values, hostnames, addresses, paths, or identifiers at normal log levels. Diagnostic exports are an explicit future feature and must use user-selected destination, previewed contents, redaction options, and a documented format.

## Threat Model Summary

The application should protect against accidental overcollection, confusing permission escalation, unwanted data persistence, and an attacker obtaining a convenient local behavioral archive. It is not itself a security product, so it must avoid security claims that exceed its access level or validation.

## Security Baseline

- Use least-privilege APIs and separate privileged components from the UI process.
- Keep privileged extensions narrowly scoped and independently reviewable.
- Validate and migrate local database schemas safely.
- Avoid shelling out to parse human-readable system command output when a stable structured API exists.
- Treat imported or exported files as untrusted input.
- Document any new entitlement in [macOS capabilities](macos-capabilities.md) before code that depends on it lands.
