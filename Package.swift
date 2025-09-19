// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clipper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ClipperApp", targets: ["ClipperApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections", from: "1.1.0")
    ],
    targets: [
        .executableTarget(
            name: "ClipperApp",
            dependencies: [
                .product(name: "OrderedCollections", package: "swift-collections")
            ],
            path: "Sources/ClipperApp",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ClipperAppTests",
            dependencies: ["ClipperApp"],
            path: "Tests/ClipperAppTests"
        )
    ]
)
