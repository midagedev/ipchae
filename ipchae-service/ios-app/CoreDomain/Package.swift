// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CoreDomain",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CoreDomain",
            targets: ["CoreDomain"]
        ),
        .executable(
            name: "EditorSpikeCLI",
            targets: ["EditorSpikeCLI"]
        )
    ],
    targets: [
        .target(
            name: "CoreDomain"
        ),
        .executableTarget(
            name: "EditorSpikeCLI",
            dependencies: ["CoreDomain"]
        ),
        .testTarget(
            name: "CoreDomainTests",
            dependencies: ["CoreDomain"]
        )
    ]
)
