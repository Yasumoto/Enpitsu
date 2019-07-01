// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "Enpitsu",
    products: [
        .library(name: "Enpitsu", targets: ["Enpitsu"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/swift-nio-http-client", .branch("master"))
    ],
    targets: [
        .target(name: "Enpitsu", dependencies: ["NIO", "NIOHTTPClient"]),
        .testTarget(name: "EnpitsuTests", dependencies: ["Enpitsu"]),
    ]
)
