import Foundation
import IOKit.ps
import MacObserverDomain

public actor PowerCollector: TelemetryCollector {
    public nonisolated let capability = CapabilityDescriptor(
        id: "standard.power",
        title: "Power",
        accessLevel: .standard,
        domains: [.power],
        summary: "Battery charge from IOPS. Watts only when voltage and current are present."
    )

    private let clock: any Clock
    private let bootSession: BootSessionID
    private let loop = LoopingCollector()

    public init(clock: any Clock = SystemClock(), bootSession: BootSessionID) {
        self.clock = clock
        self.bootSession = bootSession
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
        let system = Entity.system(bootSession: bootSession)
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            await sink.send(.availability(capabilityID: capability.id, .unavailable(reason: "IOPSCopyPowerSourcesInfo failed")))
            return
        }
        guard let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            await sink.send(.availability(capabilityID: capability.id, .unavailable(reason: "no power sources")))
            return
        }

        var emittedCharge = false
        var emittedWatts = false
        for source in list {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            if let capacity = description[kIOPSCurrentCapacityKey] as? Int,
               let max = description[kIOPSMaxCapacityKey] as? Int,
               max > 0 {
                let ratio = Swift.min(1, Swift.max(0, Double(capacity) / Double(max)))
                await sink.send(.metric(MetricFactory.make(
                    clock: clock, domain: .power, name: .powerBatteryChargeRatio, entity: system,
                    value: .ratio(ratio), unit: .ratio, source: capability.id
                )))
                emittedCharge = true
            }

            let voltage = Self.number(description[kIOPSVoltageKey])
            let current = Self.number(description[kIOPSCurrentKey])
            if let voltage, let current, voltage != 0, current != 0 {
                let watts = abs(voltage * current) / 1_000_000
                await sink.send(.metric(MetricFactory.make(
                    clock: clock, domain: .power, name: .powerLoadWatts, entity: system,
                    value: .double(watts), unit: .watts, source: capability.id,
                    quality: .estimated
                )))
                emittedWatts = true
            }

            let charging = (description[kIOPSIsChargingKey] as? Bool) ?? false
            await sink.send(.metric(MetricFactory.make(
                clock: clock, domain: .power, name: .powerBatteryCharging, entity: system,
                value: .state(charging ? "charging" : "discharging"),
                unit: .enumeration, source: capability.id
            )))

            if let empty = Self.number(description[kIOPSTimeToEmptyKey]), empty > 0 {
                await sink.send(.metric(MetricFactory.make(
                    clock: clock, domain: .power, name: .powerTimeToEmptyMinutes, entity: system,
                    value: .int(Int64(empty.rounded())), unit: .count, source: capability.id
                )))
            }
            if let full = Self.number(description[kIOPSTimeToFullChargeKey]), full > 0 {
                await sink.send(.metric(MetricFactory.make(
                    clock: clock, domain: .power, name: .powerTimeToFullMinutes, entity: system,
                    value: .int(Int64(full.rounded())), unit: .count, source: capability.id
                )))
            }
        }

        if emittedCharge {
            await sink.send(.availability(capabilityID: capability.id, .available))
        } else {
            await sink.send(.availability(capabilityID: capability.id, .unavailable(reason: "battery capacity not reported")))
        }

        if !emittedWatts {
            await sink.send(.availability(
                capabilityID: "\(capability.id).watts",
                .unavailable(reason: "voltage or current not reported")
            ))
        }
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }
}
