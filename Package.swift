// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CCSessionCounter",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CCSessionCounter",
            path: "Sources/CCSessionCounter"
        )
    ]
)
