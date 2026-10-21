// swift-tools-version: 6.0
import PackageDescription

// `capture` and its window lookup need macOS. On Linux, stand-ins named like the Apple modules
// (CoreGraphics, AppKit, ImageIO, UniformTypeIdentifiers) implement the subset arrowshot uses on Cairo and Pango, so
// upstream's geometry and rendering build unchanged; only `annotate` is offered there.
#if os(Linux)
let platformTargets: [Target] = [
    .systemLibrary(
        name: "CCairo", path: "Sources/LinuxShims/CCairo", pkgConfig: "pangocairo",
        providers: [.apt(["libcairo2-dev", "libpango1.0-dev"])]
    ),
    .target(name: "CoreGraphics", dependencies: ["CCairo"], path: "Sources/LinuxShims/CoreGraphics"),
    .target(name: "AppKit", dependencies: ["CoreGraphics", "CCairo"], path: "Sources/LinuxShims/AppKit"),
    .target(name: "ImageIO", dependencies: ["CoreGraphics", "CCairo"], path: "Sources/LinuxShims/ImageIO"),
    .target(name: "UniformTypeIdentifiers", path: "Sources/LinuxShims/UniformTypeIdentifiers")
]
let coreShims: [Target.Dependency] = ["CoreGraphics"]
let overlayShims: [Target.Dependency] = ["AppKit", "CCairo", "ImageIO", "UniformTypeIdentifiers"]
let imageShims: [Target.Dependency] = ["ImageIO", "UniformTypeIdentifiers"]
let macOnly: [Target.Dependency] = []
// Swift Testing would look for its CoreGraphics overlay, which exists only on Apple platforms.
let testSettings: [SwiftSetting] = [.unsafeFlags(["-Xfrontend", "-disable-cross-import-overlays"])]
#else
let platformTargets: [Target] = [
    .target(name: "BigArrowTargeting", dependencies: ["BigArrowCore"])
]
let coreShims: [Target.Dependency] = []
let overlayShims: [Target.Dependency] = []
let imageShims: [Target.Dependency] = []
let macOnly: [Target.Dependency] = ["BigArrowTargeting"]
let testSettings: [SwiftSetting] = []
#endif

let package = Package(
    name: "arrowshot",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "arrowshot", targets: ["arrowshot"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0")
    ],
    targets: platformTargets + [
        .target(name: "BigArrowCore", dependencies: coreShims),
        .target(name: "BigArrowOverlay", dependencies: ["BigArrowCore"] + overlayShims),
        .executableTarget(
            name: "arrowshot",
            dependencies: [
                "BigArrowCore",
                "BigArrowOverlay",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ] + macOnly
        ),
        .testTarget(
            name: "BigArrowCoreTests",
            dependencies: ["BigArrowCore"] + imageShims,
            resources: [.copy("Fixtures")],
            swiftSettings: testSettings
        ),
        .testTarget(
            name: "ArrowShotTests",
            dependencies: ["BigArrowCore", "BigArrowOverlay"],
            swiftSettings: testSettings
        )
    ]
)
