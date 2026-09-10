import Foundation
import MacObserverDomain
import MacObserverCollectors

@MainActor
@Observable
final class OverviewStore {
    private let pipeline: CollectorPipeline
    private(set) var snapshot: LiveSnapshot

    init(pipeline: CollectorPipeline = CollectorPipeline(collectors: StandardCollectors.make())) {
        self.pipeline = pipeline
        self.snapshot = LiveSnapshot(
            metrics: [],
            events: [],
            availability: [:],
            capturedAt: ObservationTime(wallTime: Date())
        )
    }

    func run() async {
        try? await pipeline.start()
        while !Task.isCancelled {
            snapshot = await pipeline.snapshot()
            try? await Task.sleep(for: .seconds(1))
        }
        await pipeline.stop()
    }
}
