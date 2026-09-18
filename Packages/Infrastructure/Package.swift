// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Infrastructure",
    platforms: [.macOS(.v15)],
    products: [.library(name: "Infrastructure", targets: ["Infrastructure"])],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../Application"),
    ],
    targets: [
        .target(
            name: "Infrastructure",
            dependencies: [
                .product(name: "Domain", package: "Domain"),
                .product(name: "Application", package: "Application"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "InfrastructureTests",
            dependencies: [
                "Infrastructure",
                .product(name: "Domain", package: "Domain"),
                .product(name: "Application", package: "Application"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
