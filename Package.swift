// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Orbit",
    platforms: [
        .macOS(.v14)  // macOS 14.5+ (Sonoma)
    ],
    products: [
        .executable(
            name: "Orbit",
            targets: ["Orbit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.6.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "Orbit",
            dependencies: [
                "TOMLKit",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/Orbit"
        ),
        .testTarget(
            name: "OrbitTests",
            dependencies: ["Orbit"],
            path: "Tests/OrbitTests"
        )
    ]
)
