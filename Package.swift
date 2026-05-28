// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Sub2APIQuota",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Sub2APIQuotaCore", targets: ["Sub2APIQuotaCore"]),
        .executable(name: "Sub2APIQuotaApp", targets: ["Sub2APIQuotaApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.99.0")
    ],
    targets: [
        .target(name: "Sub2APIQuotaCore"),
        .executableTarget(
            name: "Sub2APIQuotaApp",
            dependencies: ["Sub2APIQuotaCore"]
        ),
        .testTarget(
            name: "Sub2APIQuotaCoreTests",
            dependencies: [
                "Sub2APIQuotaCore",
                .product(name: "Testing", package: "swift-testing")
            ]
        ),
        .testTarget(
            name: "Sub2APIQuotaAppTests",
            dependencies: [
                "Sub2APIQuotaApp",
                .product(name: "Testing", package: "swift-testing")
            ]
        )
    ]
)
