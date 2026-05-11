// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeDash",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "ClaudeDash", path: "Sources/ClaudeDash"),
    ]
)
