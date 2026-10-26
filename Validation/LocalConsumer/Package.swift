// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "LocalConsumer",
    platforms: [.macOS("26.0")],
    dependencies: [.package(name: "FoldContextKit", path: "../..")],
    targets: [
        .executableTarget(
            name: "LocalConsumer",
            dependencies: [.product(name: "FoldContextKit", package: "FoldContextKit")]
        )
    ]
)
