// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Enpitsu",
    products: [
        .library(name: "Enpitsu", targets: ["Enpitsu"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.0.0-alpha.4")
    ],
    targets: [
        .target(name: "Enpitsu", dependencies: ["NIO", "AsyncHTTPClient"]),
        .testTarget(name: "EnpitsuTests", dependencies: ["Enpitsu"]),
    ]
)
