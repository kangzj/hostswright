// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HostsMasterKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "HostsCore", targets: ["HostsCore"]),
    ],
    targets: [
        .target(name: "HostsCore"),
        .testTarget(name: "HostsCoreTests", dependencies: ["HostsCore"]),
    ]
)
