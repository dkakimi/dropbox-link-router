// swift-tools-version: 6.0
import Foundation
import PackageDescription

// テストはローカルのみ（リポジトリには含めない）
let hasTests = FileManager.default.fileExists(
    atPath: URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Tests/RouterCoreTests").path)

let package = Package(
    name: "DropboxLinkRouter",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "RouterCore"),
        .executableTarget(name: "DropboxLinkRouter", dependencies: ["RouterCore"]),
    ] + (hasTests ? [.testTarget(name: "RouterCoreTests", dependencies: ["RouterCore"])] : []),
    swiftLanguageModes: [.v5]
)
