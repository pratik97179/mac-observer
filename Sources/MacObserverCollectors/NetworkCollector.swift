import Foundation
import Darwin
import MacObserverDomain

public actor NetworkCollector: TelemetryCollector {
    public nonisolated let capability = CapabilityDescriptor(
        id: "standard.network",
        title: "Network Interfaces",
        accessLevel: .standard,
        domains: [.network],
        summary: "Interface throughput from getifaddrs, plus local gateway and DNS from SystemConfiguration. Not per-process.",
        collectionMethod: "getifaddrs link counters and SCDynamicStore State:/Network/Global IPv4, IPv6, and DNS. Stays on this Mac."
    )

    private let clock: any Clock
    private let bootSession: BootSessionID
    private let pathSource: any NetworkPathSource
    private let interval: Duration
    private let loop = LoopingCollector()
    private var previous: [String: (rx: UInt64, tx: UInt64, at: Date)] = [:]
    private var previousPathSignature: String?

    public init(clock: any Clock = SystemClock(), bootSession: BootSessionID) {
        self.init(clock: clock, bootSession: bootSession, pathSource: SystemConfigurationPathSource())
    }

    init(
        clock: any Clock,
        bootSession: BootSessionID,
        pathSource: any NetworkPathSource,
        interval: Duration = .seconds(2)
    ) {
        self.clock = clock
        self.bootSession = bootSession
        self.pathSource = pathSource
        self.interval = interval
    }

    public func start(sink: any TelemetrySink) async throws {
        await loop.start(interval: interval) {
            await self.publish(to: sink)
        }
    }

    public func stop() async {
        await loop.stop()
    }

    private func publish(to sink: any TelemetrySink) async {
        let hadCounters = await publishCounters(to: sink)
        let hadPath = await publishPath(to: sink)
        if hadCounters || hadPath {
            await sink.send(.availability(capabilityID: capability.id, .available))
        } else {
            await sink.send(.availability(capabilityID: capability.id, .unavailable(reason: "network path unavailable")))
        }
    }

    private func publishCounters(to sink: any TelemetrySink) async -> Bool {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let first = ifap else {
            return false
        }
        defer { freeifaddrs(first) }

        var totals: [String: (rx: UInt64, tx: UInt64, hardware: String?)] = [:]
        var cursor = Optional(first)
        while let pointer = cursor {
            let address = pointer.pointee
            cursor = address.ifa_next
            let flags = Int32(address.ifa_flags)
            guard (flags & IFF_LOOPBACK) == 0 else { continue }
            guard let addr = address.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
            let name = String(cString: address.ifa_name)
            guard let data = address.ifa_data else { continue }
            let stats = data.assumingMemoryBound(to: if_data.self).pointee
            totals[name] = (UInt64(stats.ifi_ibytes), UInt64(stats.ifi_obytes), nil)
        }

        let now = clock.wallTime
        for (name, counters) in totals {
            let entity = Entity.networkInterface(name: name, hardwareID: counters.hardware)
            if let last = previous[name], now.timeIntervalSince(last.at) > 0 {
                if let rx = SampleMath.perSecond(previous: last.rx, current: counters.rx, elapsed: now.timeIntervalSince(last.at)) {
                    await sink.send(.metric(MetricFactory.make(
                        clock: clock, domain: .network, name: .networkRxBytesPerSecond, entity: entity,
                        value: .double(rx), unit: .bytesPerSecond, source: capability.id,
                        dimensions: ["interface": name, "direction": "rx"]
                    )))
                }
                if let tx = SampleMath.perSecond(previous: last.tx, current: counters.tx, elapsed: now.timeIntervalSince(last.at)) {
                    await sink.send(.metric(MetricFactory.make(
                        clock: clock, domain: .network, name: .networkTxBytesPerSecond, entity: entity,
                        value: .double(tx), unit: .bytesPerSecond, source: capability.id,
                        dimensions: ["interface": name, "direction": "tx"]
                    )))
                }
            }
            previous[name] = (counters.rx, counters.tx, now)
        }
        return !totals.isEmpty
    }

    private func publishPath(to sink: any TelemetrySink) async -> Bool {
        guard let path = pathSource.currentPath(), !path.isEmpty else { return false }
        let system = Entity.system(bootSession: bootSession)
        if let primary = path.primaryInterface {
            await sink.send(.metric(MetricFactory.make(
                clock: clock, domain: .network, name: .networkPrimaryInterface, entity: system,
                value: .state(primary), unit: .enumeration, source: capability.id
            )))
        }
        if let gateway = path.gateway {
            await sink.send(.metric(MetricFactory.make(
                clock: clock, domain: .network, name: .networkGatewayAddress, entity: system,
                value: .state(gateway), unit: .enumeration, source: capability.id
            )))
        }
        if let resolver = path.dnsServers.first {
            await sink.send(.metric(MetricFactory.make(
                clock: clock, domain: .network, name: .networkDNSResolverAddress, entity: system,
                value: .state(resolver), unit: .enumeration, source: capability.id
            )))
        }
        await sink.send(.metric(MetricFactory.make(
            clock: clock, domain: .network, name: .networkDNSResolverCount, entity: system,
            value: .int(Int64(path.dnsServers.count)), unit: .count, source: capability.id
        )))

        let signature = path.signature
        if let previousPathSignature, previousPathSignature != signature {
            await sink.send(.event(EventFactory.make(
                clock: clock,
                domain: .network,
                type: .networkConfigurationChanged,
                entity: system,
                summary: "Local network path changed.",
                source: capability.id,
                metadata: [
                    "primary": path.primaryInterface ?? "",
                    "dns_count": "\(path.dnsServers.count)"
                ],
                privacyClass: .identifyingDeviceContext
            )))
        }
        previousPathSignature = signature
        return true
    }
}
