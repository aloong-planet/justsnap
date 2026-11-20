// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "JustSnap",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS("14.4"),
    ],
    products: [
        .library(name: "JustSnapCore", targets: ["JustSnapCore"]),
        .library(name: "JustSnapSparkle", targets: ["JustSnapSparkle"]),
        .library(name: "JustSnapUI", targets: ["JustSnapUI"]),
        .library(
            name: "JustSnapReleaseSupport",
            targets: ["JustSnapReleaseSupport"]
        ),
        .executable(name: "JustSnapApp", targets: ["JustSnapApp"]),
        .executable(
            name: "JustSnapLiveProviderGate",
            targets: ["JustSnapLiveProviderGate"]
        ),
        .executable(
            name: "JustSnapSigningTool",
            targets: ["JustSnapSigningTool"]
        ),
        .executable(
            name: "JustSnapUIHarness",
            targets: ["JustSnapUIHarness"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/sparkle-project/Sparkle",
            exact: "2.9.6"
        ),
    ],
    targets: [
        .target(
            name: "JustSnapCore",
            dependencies: ["JustSnapHotKeyShim", "JustSnapProcessShim"],
            linkerSettings: [
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ImageIO"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("Security"),
                .linkedFramework("UniformTypeIdentifiers"),
            ]
        ),
        .target(
            name: "JustSnapHotKeyShim",
            path: "Sources/JustSnapHotKeyShim",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("Carbon"),
            ]
        ),
        .target(
            name: "JustSnapProcessShim",
            path: "Sources/JustSnapProcessShim",
            publicHeadersPath: "include",
            linkerSettings: [.linkedLibrary("z")]
        ),
        .target(
            name: "JustSnapUI",
            dependencies: ["JustSnapCore"],
            path: "JustSnap",
            sources: ["UI"],
            resources: [.process("Resources/Localization")]
        ),
        .target(
            name: "JustSnapSparkle",
            dependencies: [
                "JustSnapCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
        .target(
            name: "JustSnapReleaseSupport",
            linkerSettings: [.linkedFramework("Security")]
        ),
        .executableTarget(
            name: "JustSnapApp",
            dependencies: [
                "JustSnapCore",
                "JustSnapSparkle",
                "JustSnapUI",
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks",
                ]),
            ]
        ),
        .executableTarget(
            name: "JustSnapAXFixture",
            dependencies: ["JustSnapCore", "JustSnapUI"],
            path: "Tests/AXFixture",
            exclude: ["Info.plist"]
        ),
        .executableTarget(
            name: "JustSnapUIHarness",
            dependencies: ["JustSnapCore", "JustSnapUI"]
        ),
        .executableTarget(
            name: "JustSnapLiveProviderGate",
            dependencies: ["JustSnapCore"],
            linkerSettings: [
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreText"),
                .linkedFramework("ImageIO"),
                .linkedFramework("UniformTypeIdentifiers"),
            ]
        ),
        .executableTarget(
            name: "JustSnapSigningTool",
            dependencies: ["JustSnapReleaseSupport"]
        ),
        .testTarget(
            name: "JustSnapAppTests",
            dependencies: ["JustSnapApp", "JustSnapCore", "JustSnapUI"]
        ),
        .testTarget(
            name: "JustSnapCoreTests",
            dependencies: ["JustSnapCore"]
        ),
        .testTarget(
            name: "JustSnapUITests",
            dependencies: ["JustSnapCore", "JustSnapUI"]
        ),
        .testTarget(
            name: "JustSnapSparkleTests",
            dependencies: ["JustSnapCore", "JustSnapSparkle"]
        ),
        .testTarget(
            name: "JustSnapReleaseSupportTests",
            dependencies: ["JustSnapReleaseSupport"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
