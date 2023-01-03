// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SharedUIComponents",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        .library(name: "SharedUIComponents",
                 targets: ["SharedUIComponents"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ivkuznetsov/CommonUtils.git", branch: "main")
    ],
    targets: [
        .target(name: "SharedUIComponents",
                dependencies: ["CommonUtils"])
    ]
)
