// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MenuBarShelf",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "MenuBarShelfApp", targets: ["AppShell"]),
        .executable(name: "FixtureMenuExtras", targets: ["FixtureMenuExtras"]),
    ],
    targets: [
        .target(
            name: "Localization",
            dependencies: ["Core"],
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "Core"
        ),
        .target(
            name: "Persistence",
            dependencies: ["Core"]
        ),
        .target(
            name: "Permissions",
            dependencies: ["Core"]
        ),
        .target(
            name: "Hotkey",
            dependencies: ["Core", "Localization"]
        ),
        .target(
            name: "Discovery",
            dependencies: ["Core", "Localization"]
        ),
        .target(
            name: "LayoutEngine",
            dependencies: ["Core"]
        ),
        .target(
            name: "Overlay",
            dependencies: ["Core", "LayoutEngine", "Localization"]
        ),
        .target(
            name: "SharedUI",
            dependencies: ["Core", "Localization"]
        ),
        .executableTarget(
            name: "AppShell",
            dependencies: [
                "Core",
                "Localization",
                "Persistence",
                "Permissions",
                "Hotkey",
                "Discovery",
                "LayoutEngine",
                "Overlay",
                "SharedUI",
            ]
        ),
        .executableTarget(
            name: "FixtureMenuExtras",
            dependencies: []
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"]
        ),
        .testTarget(
            name: "LayoutEngineTests",
            dependencies: ["Core", "LayoutEngine"]
        ),
        .testTarget(
            name: "PersistenceTests",
            dependencies: ["Core", "Persistence"]
        ),
    ]
)
