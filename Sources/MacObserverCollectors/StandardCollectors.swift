import MacObserverDomain

public enum StandardCollectors {
    public static func make(clock: any Clock = SystemClock()) -> [any TelemetryCollector] {
        let boot = BootSession.current()
        return [
            CPUMemoryCollector(clock: clock, bootSession: boot),
            ProcessCollector(clock: clock, bootSession: boot),
            NetworkCollector(clock: clock),
            StorageCollector(clock: clock),
            PowerCollector(clock: clock, bootSession: boot)
        ]
    }
}
