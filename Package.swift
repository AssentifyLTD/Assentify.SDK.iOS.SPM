// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "AssentifySdk",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "AssentifySdk", targets: ["AssentifySdk"])
    ],
    dependencies: [
        // Official SPM
        .package(url: "https://github.com/SVGKit/SVGKit.git", from: "3.0.0"),
        .package(url: "https://github.com/AndyQ/NFCPassportReader.git", exact: "2.1.0"),
        .package(url: "https://github.com/bugsnag/bugsnag-cocoa.git", from: "6.0.0"),
        .package(url: "https://github.com/bugsnag/bugsnag-cocoa-performance.git", from: "2.0.0"),

        // Unofficial SPM
        .package(url: "https://github.com/kewlbear/TensorFlowLiteSwift.git", branch: "2.6.0"),
    ],
    targets: [
        .target(
            name: "AssentifySdk",
            dependencies: [
                "SVGKit",
                "NFCPassportReader",
                .product(name: "Bugsnag", package: "bugsnag-cocoa"),
                .product(name: "BugsnagPerformance", package: "bugsnag-cocoa-performance"),
                .product(name: "TensorFlowLiteSwift", package: "TensorFlowLiteSwift"),
            ],
            resources: [
                .copy("Resources/best-fp16.tflite"),
                .copy("Resources/classes.txt"),
                .process("Resources/card_background.svg"),
                .process("Resources/face_background.svg"),
                .process("Resources/passport_background.svg"),
                .process("Resources/transmitting_background.svg"),
                .process("Resources/audio_card_success.mp3"),
                .process("Resources/audio_face_success.mp3"),
                .process("Resources/audio_wrong.mp3"),
                .process("Resources/down.gif"),
                .process("Resources/up.gif"),
                .process("Resources/right.gif"),
                .process("Resources/left.gif"),
                .process("Resources/wink_left.gif"),
                .process("Resources/wink_right.gif"),
                .process("Resources/blink.gif"),
                .process("Resources/error_layout.svg"),
                .process("Resources/success_layout.svg"),
                .process("Resources/qr_background.svg"),
                .process("Resources/ic_data_entry_step.svg"),
                .process("Resources/ic_face_step.svg"),
                .process("Resources/ic_id_step.svg"),
                .process("Resources/ic_signing_step.svg"),
                .process("Resources/ic_terms_step.svg"),
                .process("Resources/id_card.svg"),
                .process("Resources/ic_passport.svg"),
                .process("Resources/passport-video.mp4"),
                .process("Resources/id-video.mp4"),
                .process("Resources/face-video.mp4"),
                .process("Resources/ic_bar.svg"),
                .process("Resources/ic_scan_id.svg"),
                .process("Resources/ic_uploading.svg"),
                .process("Resources/ic_error.svg"),
                .process("Resources/ic_complete.svg"),
                .process("Resources/ic_nfc.svg"),
                .process("Resources/ic_face_id.svg"),
                .process("Resources/ic_uploading_face.svg"),
                .process("Resources/ic_wrong_template.svg"),
                .process("Resources/ic_flip_card.svg"),
                .process("Resources/qr-video.mp4"),
                .process("Resources/ic_phone.svg"),
                .process("Resources/ic_warning.svg")
            ]
        ),
        .testTarget(
            name: "AssentifySdkTests",
            dependencies: ["AssentifySdk"]
        )
    ]
)
