// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "claude-signal",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "SignalCore"),
        .executableTarget(name: "claude-signal", dependencies: ["SignalCore"]),
    ]
)
