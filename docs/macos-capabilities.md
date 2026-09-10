# macOS Capabilities And Feasibility

## Access Levels

The product uses three access levels. The standard tier defines the baseline product; no other tier is allowed to block it.

| Level | Description | Examples |
| --- | --- | --- |
| Standard | Public APIs and normal system information; no privileged extension. | CPU, memory pressure, process resource use, volumes, interface counters, battery, thermal state, app metadata. |
| Privileged | User-enabled system extension and, in some cases, Apple-granted entitlement. | Network filtering/proxying and Endpoint Security events. |
| External | A user-triggered network request to enrich local state. | Public IP, ASN/ISP, latency, packet loss, optional geolocation. |

## Capability Matrix

| Domain | Initial target | Likely source class | Status and caveats |
| --- | --- | --- | --- |
| CPU | System and process utilization, thread counts, load-like signals. | Standard. | Core v1. Normalize sampling windows carefully. |
| Memory | Used, wired, compressed, cache approximation, swap, pressure, process memory. | Standard. | Core v1. Define each displayed term precisely. |
| Storage | Volume capacity and system I/O; per-process I/O where supported. | Standard. | Core v1 after memory/CPU. File-level tracking is not a v1 goal. |
| Network baseline | Interface state, routes, counters, throughput, gateway/DNS configuration. | Standard. | Core v1. Per-process attribution is not assumed. |
| Wi-Fi | Interface, SSID/BSSID, channel, RSSI/link data, state changes. | Standard. | Candidate v1 enhancement using CoreWLAN. |
| Power and thermal | Battery charge/charging state and thermal state. | Standard. | Core v1 where public sources provide it. Treat watts and per-process energy as conditional. |
| Processes | Lifecycle, hierarchy, CPU/RAM/I/O, bundle/signing metadata where available. | Standard plus privileged optional. | Standard view first; security-grade event coverage requires a different tier. |
| GPU | System or process GPU activity. | Conditional. | Do not promise broad live metrics until a public, supported source is verified for the target data. |
| DNS and network flows | DNS/flow observations and app attribution. | Privileged. | Optional and privacy-sensitive. DNS proxying changes the DNS handling role; encrypted DNS may not be visible. |
| Security events | Execution, file, mount, and similar system events. | Privileged. | Endpoint Security requires an Apple-granted entitlement and privileged deployment. |
| Internet enrichment | Public address, network identity, diagnostics. | External. | Off by default and clearly labeled. |

## Network Extension Boundaries

Network Extension supports DNS proxy, content filter, app proxy, packet tunnel, and related capabilities when configured with appropriate entitlements. A DNS proxy receives conventional DNS flows it proxies and takes responsibility for resolving/forwarding them. It should not be framed as a passive observer of every name resolution.

A content filter has an intentionally restrictive privacy sandbox. Its data provider cannot use normal network access, IPC, or disk writes to export captured content. Any future network feature must be designed around minimal, privacy-safe flow metadata and the deployment model required by Apple, rather than a raw traffic archive.

References: [Network Extensions entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.networkextension), [DNS proxy provider](https://developer.apple.com/documentation/networkextension/nednsproxyprovider), and [content filter providers](https://developer.apple.com/documentation/networkextension/content-filter-providers).

## Endpoint Security Boundary

Endpoint Security is suitable for security-oriented process and system events, but it is not ordinary app-level telemetry. Apple requires the `com.apple.developer.endpoint-security.client` entitlement, which must be requested from Apple; the client may also require privileged execution and user authorization. Do not architect standard process monitoring around it.

References: [Endpoint Security](https://developer.apple.com/documentation/endpointsecurity) and [the client entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.endpoint-security.client).

## Capability Design Requirements

Before enabling a non-standard source, implementation must define:

1. Exact data emitted and its privacy class.
2. The user-facing explanation and disable path.
3. Entitlements, deployment type, and App Store/Developer ID implications.
4. What continues to work when access is denied or removed.
5. Retention, export, and deletion behavior.

## Verification Policy

This document is a planning matrix, not a claim that every listed metric is already available. Before implementation, record the exact API/framework, OS support, entitlement, sampling limitation, and test result in the relevant collector documentation or source code.
