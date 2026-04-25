// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Tmwid",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Tmwid", targets: ["TmwidApp"]),
    ],
    targets: [
        .target(
            name: "Tmwid",
            path: "Sources/Tmwid",

            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "TmwidApp",
            dependencies: ["Tmwid"],
            path: "Sources/TmwidApp"
        ),
        .testTarget(
            name: "TmwidTests",
            dependencies: ["Tmwid"],
            path: "Tests/TmwidTests"
        ),
    ]
)
