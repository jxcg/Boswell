// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BoswellCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "BoswellCore", targets: ["BoswellCore"])],
    targets: [
        .target(name: "BoswellCore"),
        .testTarget(name: "BoswellCoreTests", dependencies: ["BoswellCore"])
    ]
)
