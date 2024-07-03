// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ImageGallery",
    platforms: [.macOS(.v12), .iOS(.v14), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ImageGallery",
            targets: ["ImageGallery"]),
    ],
    dependencies: [
        .package(url: "https://github.com/0xfeedface1993/url-image.git", branch: "main"),
        .package(url: "https://github.com/0xfeedface1993/ChainBuilder.git", from: "0.1.1"),
        .package(path: "../async-system")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ImageGallery",
            dependencies: [
                .product(name: "URLImage", package: "url-image"),
                .product(name: "URLImageStore", package: "url-image"),
                .product(name: "ChainBuilder", package: "ChainBuilder"),
                .product(name: "AsyncSystem", package: "async-system"),
            ]
        ),
        .testTarget(
            name: "ImageGalleryTests",
            dependencies: ["ImageGallery"]
        ),
    ]
)
