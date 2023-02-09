// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "ens-api",
    platforms: [
       .macOS(.v12)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/planetable/enskit.git", branch: "main"),
        .package(url: "https://github.com/g-mark/nullcodable.git", branch: "master"),
        .package(url: "https://github.com/argentlabs/web3.swift.git", from: "1.4.1")
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "ENSKit", package: "enskit"),
                .product(name: "NullCodable", package: "nullcodable"),
                .product(name: "web3.swift", package: "web3.swift"),
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides/blob/main/docs/building.md#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .executableTarget(name: "Run", dependencies: [.target(name: "App")]),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
        ])
    ]
)
