// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Generated file. Do not edit.
//

import PackageDescription

let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    platforms: [
        .macOS("10.15")
    ],
    products: [
        .library(name: "FlutterGeneratedPluginSwiftPackage", type: .static, targets: ["FlutterGeneratedPluginSwiftPackage"])
    ],
    dependencies: [
        .package(name: "shared_preferences_foundation", path: "../.packages/shared_preferences_foundation-2.5.6"),
        .package(name: "share_plus", path: "../.packages/share_plus-10.1.4"),
        .package(name: "record_macos", path: "../.packages/record_macos-2.1.0"),
        .package(name: "package_info_plus", path: "../.packages/package_info_plus-8.3.1"),
        .package(name: "just_audio", path: "../.packages/just_audio-0.9.46"),
        .package(name: "audio_session", path: "../.packages/audio_session-0.1.25"),
        .package(name: "in_app_purchase_storekit", path: "../.packages/in_app_purchase_storekit-0.4.10"),
        .package(name: "FlutterFramework", path: "../.packages/FlutterFramework")
    ],
    targets: [
        .target(
            name: "FlutterGeneratedPluginSwiftPackage",
            dependencies: [
                .product(name: "shared-preferences-foundation", package: "shared_preferences_foundation"),
                .product(name: "share-plus", package: "share_plus"),
                .product(name: "record-macos", package: "record_macos"),
                .product(name: "package-info-plus", package: "package_info_plus"),
                .product(name: "just-audio", package: "just_audio"),
                .product(name: "audio-session", package: "audio_session"),
                .product(name: "in-app-purchase-storekit", package: "in_app_purchase_storekit"),
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
