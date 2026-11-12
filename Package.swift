// swift-tools-version: 6.0
// Molekit — a native macOS front end for the Mole (`mo`) CLI.
// Built with SwiftPM; `./build.sh` wraps the binary into Molekit.app.
import PackageDescription

let package = Package(
    name: "Molekit",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        // All logic that talks to `mo` and parses its output. No UI, so it is unit-testable.
        .target(
            name: "MoleKitCore",
            path: "Sources/MoleKitCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Molekit",
            dependencies: ["MoleKitCore"],
            path: "Sources/Molekit",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MolekitTests",
            dependencies: ["MoleKitCore"],
            path: "Tests/MolekitTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
