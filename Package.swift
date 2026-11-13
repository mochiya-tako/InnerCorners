// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "InnerCorners",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "InnerCorners", targets: ["InnerCorners"])
    ],
    targets: [
        .executableTarget(name: "InnerCorners"),
        .testTarget(
            name: "InnerCornersTests",
            dependencies: ["InnerCorners"]
        )
    ]
)
