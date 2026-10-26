// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "FoldContextKit",
    platforms: [.iOS("26.0"), .macOS("26.0")],
    products: [.library(name: "FoldContextKit", targets: ["FoldContextKit"])],
    targets: [
        .target(name: "FoldContextKit"),
        // Compile probes only, excluded from the library product.
        .target(name: "PlatformAPIValidation", dependencies: ["FoldContextKit"],
                path: "Validation/PlatformAPIValidation"),
        .testTarget(name: "FoldContextKitTests",
                    dependencies: ["FoldContextKit", "PlatformAPIValidation"])
    ]
)
