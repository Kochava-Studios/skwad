// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Skwad",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", from: "0.10.2"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
        .package(url: "https://github.com/nalexn/ViewInspector.git", from: "0.10.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),
        .package(url: "https://github.com/lzell/AIProxySwift", from: "0.145.1"),
    ],
    targets: [
        .executableTarget(
            name: "Skwad",
            dependencies: [
                "SwiftTerm",
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "AIProxy", package: "AIProxySwift"),
            ],
            path: "Skwad"
        ),
        .testTarget(
            name: "SkwadTests",
            dependencies: [
                "Skwad",
                "ViewInspector",
            ],
            path: "SkwadTests"
        )
    ]
)
