// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "Enpitsu",
    products: [
        .library(name: "Enpitsu", targets: ["Enpitsu"]),
    ],
    targets: [
        .target(name: "Enpitsu", dependencies: []),
        .testTarget(name: "EnpitsuTests", dependencies: ["Enpitsu"]),
    ]
)
