// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacObserver",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "MacObserverDomain", targets: ["MacObserverDomain"]),
        .executable(name: "MacObserver", targets: ["MacObserver"])
    ],
    targets: [
        .target(name: "MacObserverDomain"),
        .executableTarget(
            name: "MacObserver",
            dependencies: ["MacObserverDomain"]
        ),
        .testTarget(
            name: "MacObserverDomainTests",
            dependencies: ["MacObserverDomain"]
        )
    ]
)
