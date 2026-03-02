// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AppShell",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AppShell",
            targets: ["AppShell"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0"),
        .package(path: "../CoreDomain")
    ],
    targets: [
        .target(
            name: "AppShell",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "CoreDomain", package: "CoreDomain")
            ]
        ),
        .testTarget(
            name: "AppShellTests",
            dependencies: ["AppShell"]
        )
    ]
)
