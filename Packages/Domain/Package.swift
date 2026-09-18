// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Domain",
    platforms: [.macOS(.v15)],
    products: [.library(name: "Domain", targets: ["Domain"])],
    targets: [
        .target(name: "Domain", swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "DomainTests", dependencies: ["Domain"], swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
