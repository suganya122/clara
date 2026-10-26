// swift-tools-version:5.9
import PackageDescription

// The assistant's name is deliberately not used in package or target names.
// It lives in Core/AppConfig.swift only.
let package = Package(
    name: "Assistant",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "assistant-app", targets: ["AssistantApp"]),
    ],
    targets: [
        // Protocols and data models. Foundation only. Source of truth.
        .target(name: "Contracts"),
        // Agent logic. Imports Contracts only, never platform backends.
        .target(name: "Core", dependencies: ["Contracts"]),
        // Claude provider.
        .target(name: "Models", dependencies: ["Contracts"]),
        // Menu bar app, hotkey, Keychain, overlay.
        .executableTarget(name: "AssistantApp", dependencies: ["Contracts", "Core", "Models"]),

        .testTarget(name: "ContractsTests", dependencies: ["Contracts"]),
        .testTarget(name: "CoreTests", dependencies: ["Contracts", "Core"]),
        .testTarget(name: "ModelsTests", dependencies: ["Contracts", "Models"]),
    ]
)
