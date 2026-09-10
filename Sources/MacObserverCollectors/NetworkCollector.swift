import Foundation
import Darwin
import MacObserverDomain

public actor NetworkCollector: TelemetryCollector {
    public nonisolated let capability = CapabilityDescriptor(
        id: "standard.network",
        title: "Network Interfaces",
        accessLevel: .standard,
        domains: [.network],
        summary: "Interface throughput from getifaddrs link counters. Not per-process."
    )

    private let clock: any Clock
    private let loop = LoopingCollector()
    private var previous: [String: (rx: UInt64, tx: UInt64, at: Date)] = [:]

    public init(clock: any Clock = SystemClock()) {
        self.clock = clock
    }

    public func start(sink: any TelemetrySink) async throws {
        await loop.start {
            await self.publish(to: sink)
        }
    }

    public func stop() async {
        await loop.stop()
    }

    private func publish(to sink: any TelemetrySink) async {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let first = ifap else {
            await sink.send(.availability(capabilityID: capability.id, .unavailable(reason: "getifaddrs failed")))
            return
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

        await sink.send(.availability(capabilityID: capability.id, .available))
    }
}
