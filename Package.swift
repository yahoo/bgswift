// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BGSwift",
    platforms: [
        .macOS(.v10_15), // These are where Combine becomes available which we will use in SwiftPM compatibility
        .iOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "BGSwift",
            targets: ["BGSwift"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "BGSwift",
            path: "BGSwift/Classes"),
        .testTarget(
            name: "BGSwiftTests",
            dependencies: ["BGSwift"],
            path: "Example/Tests"),
    ],
    swiftLanguageVersions: [.v5]
)
