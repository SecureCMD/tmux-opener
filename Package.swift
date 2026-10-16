// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TmuxOpener",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TmuxOpener",
            path: "Sources/TmuxOpener"
        )
    ]
)
