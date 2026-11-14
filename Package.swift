// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Keytone",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Keytone", path: "Sources/Keytone")
    ]
)
