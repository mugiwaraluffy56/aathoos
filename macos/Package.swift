// swift-tools-version: 5.9
import PackageDescription
import Foundation

let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let coreLibsPath = packageDir.appendingPathComponent("CoreLibs").path

let package = Package(
  name: "aathoos",
  platforms: [.macOS(.v13)],
  targets: [
    .systemLibrary(
      name: "AathoosCore",
      path: "AathoosCoreLib"
    ),
    .executableTarget(
      name: "aathoos",
      dependencies: ["AathoosCore"],
      path: "Sources/aathoos",
      linkerSettings: [
        .unsafeFlags(["-L\(coreLibsPath)", "-laathoos_core"]),
      ]
    ),
  ]
)
