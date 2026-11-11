// swift-tools-version: 6.0
import PackageDescription

// Artoperce is built as an Xcode project (Artoperce.xcodeproj) that depends on this package.
// SwiftPM has no iOS application product, so the app bundle lives in the project.
let package = Package(
    name: "Artoperce",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "ArtoperceEngine", targets: ["ArtoperceEngine"]),
        .library(name: "ArtoperceApp", targets: ["ArtoperceApp"]),
    ],
    targets: [
        // Pixel model, brush, history, and the crash-safe package store.
        // UIKit-free, so `swift test` runs on macOS.
        .target(
            name: "ArtoperceEngine",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // SwiftUI and UIKit user interface. iOS and iPadOS only.
        .target(
            name: "ArtoperceApp",
            dependencies: ["ArtoperceEngine"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ArtoperceEngineTests",
            dependencies: ["ArtoperceEngine"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
