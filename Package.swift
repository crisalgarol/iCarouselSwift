// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iCarouselView",
    platforms: [
        .iOS(.v15),
        .visionOS(.v1),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "iCarouselSwift",
            targets: ["iCarouselView"]
        ),
    ],
    targets: [
        .target(
            name: "iCarouselView",
            dependencies: [],
            path: "Sources/iCarouselView"
        )
    ]
)
