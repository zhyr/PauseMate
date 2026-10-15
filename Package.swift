// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PauseMate",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "PauseMate", targets: ["PauseMate"])],
    targets: [
        .executableTarget(name: "PauseMate", path: "Sources/PauseMate"),
        .testTarget(name: "PauseMateTests", dependencies: ["PauseMate"], path: "Tests/PauseMateTests")
    ]
)
