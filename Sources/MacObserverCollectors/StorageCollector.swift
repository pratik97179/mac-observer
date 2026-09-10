import Foundation
import IOKit
import Darwin
import MacObserverDomain

public actor StorageCollector: TelemetryCollector {
    public nonisolated let capability = CapabilityDescriptor(
        id: "standard.storage",
        title: "Storage",
        accessLevel: .standard,
        domains: [.storage],
        summary: "Volume capacity from FileManager. System I/O from IOBlockStorageDriver when available."
    )

    private let clock: any Clock
    private let loop = LoopingCollector()
    private var previousIO: (read: UInt64, write: UInt64, at: Date)?

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
        let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeUUIDStringKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey],
            options: [.skipHiddenVolumes]
        ) ?? []

        var emittedVolume = false
        for url in volumes {
            guard url.path == "/" else { continue }
            let values = try? url.resourceValues(forKeys: [
                .volumeUUIDStringKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey
            ])
            let entity = Entity.volume(uuid: values?.volumeUUIDString ?? "root")
            if let total = values?.volumeTotalCapacity {
                await sink.send(.metric(MetricFactory.make(
                    clock: clock, domain: .storage, name: .storageCapacityBytes, entity: entity,
                    value: .int(Int64(total)), unit: .bytes, source: capability.id
                )))
                emittedVolume = true
            }
            if let available = values?.volumeAvailableCapacity {
                await sink.send(.metric(MetricFactory.make(
                    clock: clock, domain: .storage, name: .storageAvailableBytes, entity: entity,
                    value: .int(Int64(available)), unit: .bytes, source: capability.id
                )))
            }
        }

        let io = blockStorageBytes()
        let now = clock.wallTime
        if let io {
            if let previous = previousIO, now.timeIntervalSince(previous.at) > 0 {
                let entity = Entity.volume(uuid: "system")
                if let read = SampleMath.perSecond(previous: previous.read, current: io.read, elapsed: now.timeIntervalSince(previous.at)) {
                    await sink.send(.metric(MetricFactory.make(
                        clock: clock, domain: .storage, name: .storageReadBytesPerSecond, entity: entity,
                        value: .double(read), unit: .bytesPerSecond, source: capability.id
                    )))
                }
                if let write = SampleMath.perSecond(previous: previous.write, current: io.write, elapsed: now.timeIntervalSince(previous.at)) {
                    await sink.send(.metric(MetricFactory.make(
                        clock: clock, domain: .storage, name: .storageWriteBytesPerSecond, entity: entity,
                        value: .double(write), unit: .bytesPerSecond, source: capability.id
                    )))
                }
            }
            previousIO = (io.read, io.write, now)
        }

        if emittedVolume {
            await sink.send(.availability(capabilityID: capability.id, .available))
        } else {
            await sink.send(.availability(capabilityID: capability.id, .unavailable(reason: "root volume capacity unavailable")))
        }
    }

    private func blockStorageBytes() -> (read: UInt64, write: UInt64)? {
        guard let matching = IOServiceMatching("IOBlockStorageDriver") else { return nil }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var read: UInt64 = 0
        var write: UInt64 = 0
        var service = IOIteratorNext(iterator)
        while service != 0 {
            var properties: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = properties?.takeRetainedValue() as? [String: Any],
               let stats = dict["Statistics"] as? [String: Any] {
                if let value = stats["Bytes (Read)"] as? UInt64 { read += value }
                if let value = stats["Bytes (Written)"] as? UInt64 { write += value }
                if let value = stats["Bytes (Read)"] as? Int { read += UInt64(value) }
                if let value = stats["Bytes (Written)"] as? Int { write += UInt64(value) }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return (read, write)
    }
}
