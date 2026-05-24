// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CanonC100DataImporter",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "C100ImportCore",
            targets: ["C100ImportCore"]
        ),
        .executable(
            name: "C100Importer",
            targets: ["C100Importer"]
        )
    ],
    targets: [
        .target(
            name: "C100ImportCore"
        ),
        .executableTarget(
            name: "C100Importer",
            dependencies: ["C100ImportCore"],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVKit"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .testTarget(
            name: "C100ImportCoreTests",
            dependencies: ["C100ImportCore"]
        )
    ],
    swiftLanguageModes: [.v5]
)
