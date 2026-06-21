// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RITApp",
    platforms: [.macOS(.v13)],
    dependencies: [
        // RoyalVNC (MIT) — embedded VNC view. Vendor the source before shipping.
        .package(url: "https://github.com/royalapplications/royalvnc", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "RITApp",
            dependencies: [.product(name: "RoyalVNCKit", package: "royalvnc")]
        ),
    ]
)
