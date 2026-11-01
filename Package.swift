// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Promecapt",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Promecapt", targets: ["Promecapt"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")],
    targets: [
        .executableTarget(name: "Promecapt", dependencies: [.product(name: "Sparkle", package: "Sparkle")], resources: [.copy("Resources/Translations.json")]),
        .testTarget(name: "PromecaptTests", dependencies: ["Promecapt"])
    ]
)
