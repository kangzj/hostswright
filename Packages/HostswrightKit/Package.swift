// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HostswrightKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "HostsCore", targets: ["HostsCore"]),
        .library(name: "DNSCore", targets: ["DNSCore"]),
    ],
    targets: [
        .target(name: "HostsCore"),
        .target(name: "DNSCore", dependencies: ["HostsCore"]),
        .testTarget(name: "HostsCoreTests", dependencies: ["HostsCore"]),
        .testTarget(name: "DNSCoreTests", dependencies: ["DNSCore"]),
    ]
)
