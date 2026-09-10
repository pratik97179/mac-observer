// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacObserver",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "MacObserverDomain", targets: ["MacObserverDomain"]),
        .library(name: "MacObserverCollectors", targets: ["MacObserverCollectors"]),
        .executable(name: "MacObserver", targets: ["MacObserver"])
    ],
    targets: [
        .target(name: "MacObserverDomain"),
        .target(
            name: "MacObserverCollectors",
            dependencies: ["MacObserverDomain"]
        ),
        .executableTarget(
            name: "MacObserver",
            dependencies: ["MacObserverDomain", "MacObserverCollectors"]
        ),
        .testTarget(
            name: "MacObserverDomainTests",
            dependencies: ["MacObserverDomain"]
        ),
        .testTarget(
            name: "MacObserverCollectorsTests",
            dependencies: ["MacObserverCollectors", "MacObserverDomain"]
        )
    ]
)
