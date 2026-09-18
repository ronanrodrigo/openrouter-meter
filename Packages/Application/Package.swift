// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Application",
    platforms: [.macOS(.v15)],
    products: [.library(name: "Application", targets: ["Application"])],
    dependencies: [.package(path: "../Domain")],
    targets: [
        .target(
            name: "Application",
            dependencies: [.product(name: "Domain", package: "Domain")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "ApplicationTests",
            dependencies: ["Application", .product(name: "Domain", package: "Domain")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
