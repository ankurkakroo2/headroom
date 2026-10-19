// swift-tools-version: 6.0
import PackageDescription

var products: [Product] = []
var targets: [Target] = [
    .target(name: "HeadroomCore"),
    .testTarget(name: "HeadroomCoreTests", dependencies: ["HeadroomCore"])
]
#if os(macOS)
products.append(.executable(name: "Headroom", targets: ["Headroom"]))
targets.append(.target(name: "HeadroomSystem"))
targets.append(.testTarget(name: "HeadroomSystemTests", dependencies: ["HeadroomSystem"]))
targets.append(.executableTarget(name: "Headroom", dependencies: ["HeadroomCore", "HeadroomSystem"]))
#endif

let package = Package(name: "Headroom", platforms: [.macOS(.v14)], products: products, targets: targets)
