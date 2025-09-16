// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LlamaFrameworkPackage",
    platforms: [
        .iOS(.v15), .macOS(.v12)
    ],
    products: [
        // llama.cpp 공식 가이드와 동일하게 모듈명을 "llama"로 노출
        .library(name: "llama", targets: ["llama"]) 
    ],
    targets: [
        .binaryTarget(
            // 모듈명은 XCFramework의 module.modulemap과 일치해야 함 → "llama"
            name: "llama",
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b6484/llama-b6484-xcframework.zip",
            checksum: "470e601271e98928b25f54bc361196d7206dcb7fcdc107935ea38d220b3aa933"
        )
    ]
)
