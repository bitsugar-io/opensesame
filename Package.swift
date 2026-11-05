// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "OpenSesame", platforms: [.macOS(.v13)], products: [
    .executable(name: "OpenSesame", targets: ["OpenSesame"])
], dependencies: [
    .package(url: "https://github.com/dduan/TOMLDecoder.git", exact: "0.4.5")
], targets: [
    .target(name: "OpenSesameCore", dependencies: ["TOMLDecoder"]),
    .target(name: "OpenSesameBrand", dependencies: ["OpenSesameCore"]),
    .executableTarget(name: "BrandAssets", dependencies: ["OpenSesameBrand"]),
    .executableTarget(name: "OpenSesame", dependencies: ["OpenSesameCore", "OpenSesameBrand"]),
    .testTarget(name: "OpenSesameCoreTests", dependencies: ["OpenSesameCore"]),
    .testTarget(name: "OpenSesameTests", dependencies: ["OpenSesame"])
], swiftLanguageModes: [.v5])
