// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SeedExpand",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SeedExpandCore", targets: ["SeedExpandCore"]),
        .executable(name: "seedexpand", targets: ["seedexpand"])
    ],
    targets: [
        .target(name: "SeedExpandCore"),
        .executableTarget(name: "seedexpand", dependencies: ["SeedExpandCore"]),
        .testTarget(name: "SeedExpandCoreTests", dependencies: ["SeedExpandCore"])
    ]
)
