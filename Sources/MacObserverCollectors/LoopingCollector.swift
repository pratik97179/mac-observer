import Foundation
import MacObserverDomain

actor LoopingCollector {
    private var task: Task<Void, Never>?

    func start(interval: Duration = .seconds(2), work: @escaping @Sendable () async -> Void) {
        task?.cancel()
        task = Task.detached(priority: .utility) {
            while !Task.isCancelled {
                await work()
                try? await Task.sleep(for: interval)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
