import Foundation
import Darwin
import MacObserverDomain

public protocol Clock: Sendable {
    var wallTime: Date { get }
    var monotonicNanoseconds: UInt64 { get }
}

extension Clock {
    public var observationTime: ObservationTime {
        ObservationTime(wallTime: wallTime, monotonicNanoseconds: monotonicNanoseconds)
    }
}

public struct SystemClock: Clock {
    public init() {}

    public var wallTime: Date { Date() }

    public var monotonicNanoseconds: UInt64 {
        clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
    }
}

public final class FakeClock: Clock, @unchecked Sendable {
    private let lock = NSLock()
    private var wall: Date
    private var monotonic: UInt64

    public init(wallTime: Date = Date(timeIntervalSince1970: 0), monotonicNanoseconds: UInt64 = 0) {
        self.wall = wallTime
        self.monotonic = monotonicNanoseconds
    }

    public var wallTime: Date {
        lock.lock()
        defer { lock.unlock() }
        return wall
    }

    public var monotonicNanoseconds: UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return monotonic
    }

    public func advance(seconds: TimeInterval) {
        lock.lock()
        wall = wall.addingTimeInterval(seconds)
        monotonic += UInt64(max(0, seconds) * 1_000_000_000)
        lock.unlock()
    }
}
