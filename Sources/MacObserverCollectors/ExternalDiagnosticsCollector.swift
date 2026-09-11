import Foundation
import MacObserverDomain

public protocol HTTPGetClient: Sendable {
    func get(_ url: URL) async throws -> (Data, TimeInterval)
}

public struct URLSessionGetClient: HTTPGetClient {
    public init() {}

    public func get(_ url: URL) async throws -> (Data, TimeInterval) {
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let started = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let elapsed = Date().timeIntervalSince(started)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return (data, elapsed)
    }
}

public actor ExternalDiagnosticsCollector: TelemetryCollector {
    public static let capabilityID = "external.internet"
    public static let endpoint = URL(string: "https://1.1.1.1/cdn-cgi/trace")!

    public nonisolated let capability = CapabilityDescriptor(
        id: ExternalDiagnosticsCollector.capabilityID,
        title: "Internet Check",
        accessLevel: .external,
        domains: [.network],
        summary: "A user-triggered lookup of this Mac's public address and round-trip time. Off until you turn it on and run a check.",
        collectionMethod: "HTTPS GET to Cloudflare 1.1.1.1 /cdn-cgi/trace. Empty request body. Result stays in the local store unless you delete it.",
        remainsLocal: false,
        privacyClass: .identifyingDeviceContext,
        defaultEnabled: false
    )

    private let clock: any Clock
    private let bootSession: BootSessionID
    private let client: any HTTPGetClient
    private var sink: (any TelemetrySink)?

    public init(
        clock: any Clock = SystemClock(),
        bootSession: BootSessionID,
        client: any HTTPGetClient = URLSessionGetClient()
    ) {
        self.clock = clock
        self.bootSession = bootSession
        self.client = client
    }

    public func start(sink: any TelemetrySink) async throws {
        self.sink = sink
        await sink.send(.availability(capabilityID: capability.id, .available))
    }

    public func stop() async {
        sink = nil
    }

    public func probe() async {
        guard let sink else { return }
        do {
            let (data, elapsed) = try await client.get(Self.endpoint)
            guard let address = Self.publicAddress(in: data) else {
                await sink.send(.availability(capabilityID: capability.id, .unavailable(reason: "Lookup returned no address")))
                return
            }
            let entity = Entity.system(bootSession: bootSession)
            let nanos = Int64((elapsed * 1_000_000_000).rounded())
            await sink.send(.metric(MetricFactory.make(
                clock: clock,
                domain: .network,
                name: .networkPublicAddress,
                entity: entity,
                value: .state(address),
                unit: .enumeration,
                source: capability.id,
                quality: .direct
            )))
            await sink.send(.metric(MetricFactory.make(
                clock: clock,
                domain: .network,
                name: .networkExternalRoundTripNanoseconds,
                entity: entity,
                value: .int(nanos),
                unit: .nanoseconds,
                source: capability.id,
                quality: .estimated
            )))
            await sink.send(.event(EventFactory.make(
                clock: clock,
                domain: .network,
                type: .networkExternalLookup,
                entity: entity,
                summary: "Public address lookup completed.",
                source: capability.id,
                metadata: [
                    "provider": "cloudflare",
                    "endpoint": "1.1.1.1/cdn-cgi/trace",
                    "rtt_ms": "\(Int((elapsed * 1000).rounded()))"
                ],
                privacyClass: .identifyingDeviceContext
            )))
            await sink.send(.availability(capabilityID: capability.id, .available))
        } catch {
            await sink.send(.availability(capabilityID: capability.id, .unavailable(reason: "Lookup failed")))
        }
    }

    static func publicAddress(in data: Data) -> String? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        for line in text.split(whereSeparator: \.isNewline) {
            guard line.hasPrefix("ip=") else { continue }
            let value = line.dropFirst(3).trimmingCharacters(in: .whitespacesAndNewlines)
            guard (3...45).contains(value.count) else { return nil }
            guard value.allSatisfy({ $0.isASCII && ($0.isHexDigit || $0 == "." || $0 == ":") }) else { return nil }
            return value
        }
        return nil
    }
}
