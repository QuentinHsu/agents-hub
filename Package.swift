// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "AgentsHub",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/QuentinHsu/SVGPath.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "AgentsHub",
            dependencies: [
                .product(name: "SVGPath", package: "SVGPath"),
            ],
            path: "Sources",
            resources: [
                .process("Resources"),
            ]
        )
    ]
)
