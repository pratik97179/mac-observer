// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacObserver",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "MacObserverDomain", targets: ["MacObserverDomain"]),
        .library(name: "MacObserverCollectors", targets: ["MacObserverCollectors"]),
        .library(name: "MacObserverStorage", targets: ["MacObserverStorage"]),
        .executable(name: "MacObserver", targets: ["MacObserver"])
    ],
    targets: [
        .target(name: "MacObserverDomain"),
        .target(
            name: "MacObserverCollectors",
            dependencies: ["MacObserverDomain"],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("SystemConfiguration")
            ]
        ),
        .target(
            name: "MacObserverStorage",
            dependencies: ["MacObserverDomain"],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "MacObserver",
            dependencies: ["MacObserverDomain", "MacObserverCollectors", "MacObserverStorage"],
            exclude: ["Assets.xcassets"],
            resources: [
                .copy("Resources/macbook.png"),
                .copy("Resources/bg.png")
            ],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("SystemConfiguration")
            ]
        ),
        .testTarget(
            name: "MacObserverDomainTests",
            dependencies: ["MacObserverDomain"]
        ),
        .testTarget(
            name: "MacObserverCollectorsTests",
            dependencies: ["MacObserverCollectors", "MacObserverDomain"]
        ),
        .testTarget(
            name: "MacObserverStorageTests",
            dependencies: ["MacObserverStorage", "MacObserverDomain"]
        )
    ]
)
