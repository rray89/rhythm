// swift-tools-version: 6.0
import Foundation
import PackageDescription

let sparkleEnabled = ProcessInfo.processInfo.environment["RHYTHM_ENABLE_SPARKLE"] == "1"
let sparkleDependencies: [Package.Dependency] = sparkleEnabled
    ? [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.1")]
    : []
let rhythmDependencies: [Target.Dependency] = sparkleEnabled
    ? [
        "RhythmCore",
        .product(name: "Sparkle", package: "Sparkle")
    ]
    : ["RhythmCore"]

let package = Package(
    name: "Rhythm",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "RhythmCore", targets: ["RhythmCore"]),
        .executable(name: "Rhythm", targets: ["Rhythm"]),
        .executable(name: "RhythmTDD", targets: ["RhythmTDD"])
    ],
    dependencies: sparkleDependencies,
    targets: [
        .target(
            name: "RhythmCore",
            path: "Sources/RhythmCore"
        ),
        .executableTarget(
            name: "Rhythm",
            dependencies: rhythmDependencies,
            path: "Sources/RhythmApp"
        ),
        .executableTarget(
            name: "RhythmTDD",
            dependencies: ["RhythmCore"],
            path: "Sources/RhythmTDD"
        )
    ]
)
