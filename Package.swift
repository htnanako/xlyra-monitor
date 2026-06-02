// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "XlyraMonitor",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "XlyraMonitorApp", targets: ["XlyraMonitorApp"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "XlyraMonitorApp"
        ),
        .testTarget(
            name: "XlyraMonitorAppTests",
            dependencies: [
                "XlyraMonitorApp"
            ]
        )
    ]
)
