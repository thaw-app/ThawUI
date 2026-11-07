// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "ThawUI",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ThawUI", targets: ["ThawUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/buh/CompactSlider", from: "2.1.0"),
    ],
    targets: [
        .target(
            name: "ThawUI",
            dependencies: ["CompactSlider"],
            // Built from Shaders/ by scripts/build-shaders.sh, so building ThawUI doesn't need the Metal Toolchain.
            resources: [.copy("Resources/ThawUI.metallib")]
        ),
        .testTarget(
            name: "ThawUITests",
            dependencies: ["ThawUI"]
        ),
    ]
)
