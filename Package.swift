// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "skip-foundation",
    defaultLocalization: "en",
    platforms: [.iOS(.v16), .macOS(.v13), .tvOS(.v16), .watchOS(.v9), .macCatalyst(.v16)],
    products: [
        .library(name: "SkipFoundation", targets: ["SkipFoundation"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vindhyadatascience/skip.git", revision: "00434800e13a37955e72e4a6e3915531dc718978"),
        // VDS fork: immutable source pin; SwiftPM ignores +build metadata when matching versions.
        // Source alias 1.4.4+vds.3; immutable revision is authoritative.
        .package(url: "https://github.com/vindhyadatascience/skip-lib.git", revision: "9242796bd40c4d8418cfb040f9493c2cf9ca7a4a"),
    ],
    targets: [
        .target(name: "SkipFoundation", dependencies: [.product(name: "SkipLib", package: "skip-lib")], plugins: [.plugin(name: "skipstone", package: "skip")]),
        .testTarget(name: "SkipFoundationTests", dependencies: ["SkipFoundation", .product(name: "SkipTest", package: "skip")], resources: [.process("Resources"), .copy("ResourcesCopy")], plugins: [.plugin(name: "skipstone", package: "skip")]),
    ]
)

// SKIP_DYNAMIC_LIBRARIES and SKIP_BRIDGE both enforce building as dynamic
// libraries; SKIP_BRIDGE additionally puts the skipstone plugin in bridge mode
let bridgeMode = (Context.environment["SKIP_BRIDGE"] ?? "0") != "0"
let forceDylib = bridgeMode || (Context.environment["SKIP_DYNAMIC_LIBRARIES"] ?? "0") != "0"

if forceDylib {
    // all library types must be dynamic to support bridging
    package.products = package.products.map({ product in
        guard let libraryProduct = product as? Product.Library else { return product }
        return .library(name: libraryProduct.name, type: .dynamic, targets: libraryProduct.targets)
    })
}
