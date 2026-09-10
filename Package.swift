// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacObserver",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "MacObserver", targets: ["MacObserver"])
    ],
    targets: [
        .executableTarget(name: "MacObserver")
    ]
)
