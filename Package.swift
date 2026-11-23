// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KirkTranslation",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KirkTranslation", targets: ["KirkTranslation"]),
        .library(name: "KirkTranslationUI", targets: ["KirkTranslationUI"]),
    ],
    targets: [
        .target(name: "KirkTranslation"),
        .target(name: "KirkTranslationUI", dependencies: ["KirkTranslation"]),
        .testTarget(name: "KirkTranslationTests", dependencies: ["KirkTranslation"]),
    ],
    swiftLanguageModes: [.v5]
)
