// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "XlyraMonitor",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "XlyraMonitorApp", targets: ["XlyraMonitorApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.99.0")
    ],
    targets: [
        .executableTarget(
            name: "XlyraMonitorApp"
        ),
        .testTarget(
            name: "XlyraMonitorAppTests",
            dependencies: [
                "XlyraMonitorApp",
                .product(name: "Testing", package: "swift-testing")
            ]
        )
    ]
)
