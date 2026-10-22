// swift-tools-version: 5.9
import PackageDescription

var nativeProducts: [Product] = []
var nativeTargets: [Target] = []
#if os(macOS)
nativeProducts = [.executable(name: "SeedExpandApp", targets: ["SeedExpandApp"])]
nativeTargets = [.executableTarget(name: "SeedExpandApp", dependencies: ["SeedExpandCore"])]
#endif
let package = Package(
    name: "SeedExpand",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SeedExpandCore", targets: ["SeedExpandCore"]),
        .executable(name: "seedexpand", targets: ["seedexpand"])
    ] + nativeProducts,
    targets: [
        .target(name: "SeedExpandCore"),
        .executableTarget(name: "seedexpand", dependencies: ["SeedExpandCore"]),
        .testTarget(name: "SeedExpandCoreTests", dependencies: ["SeedExpandCore"])
    ] + nativeTargets
)
