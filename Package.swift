// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iCarouselView",
    platforms: [
        .iOS(.v15) // o el mínimo que soporte tu vista
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
            path: "iCarouselSwift/iCarouselView"
        )
    ]
)
