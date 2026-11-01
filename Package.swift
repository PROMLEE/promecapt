// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Promecapt",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Promecapt", targets: ["Promecapt"])],
    targets: [
        .executableTarget(name: "Promecapt", resources: [.copy("Resources/Translations.json")]),
        .testTarget(name: "PromecaptTests", dependencies: ["Promecapt"])
    ]
)
