// MLAssetManager.swift – URLSession/Unarchiver/파일매니저 의존성 주입 및 테스트 지원 구조
// CoreML 모델 다운로드, 압축 해제, 경로 관리, 테스트를 위한 의존성 주입 구조 포함
// Summary: New manager for downloading, unzipping, and managing CoreML model assets.

import Foundation

#if os(iOS)
// -------------------------------------------------------------
// iOS STUB IMPLEMENTATION
// -------------------------------------------------------------
/// Error placeholders
public enum MLAssetError: Error {
    case unsupported
}

/// Dummy manager – real implementation uses ZIPFoundation (todo).
public final class MLAssetManager {
    public static let shared = MLAssetManager()
    private init() {}
    /// Returns dummy URL; throws until implemented.
    public func downloadModelIfNeeded(from remoteURL: URL, to localName: String) async throws -> URL {
        throw MLAssetError.unsupported
    }
}
#else
// -------------------------------------------------------------
// macOS IMPLEMENTATION (simulator builds OK – uses /usr/bin/unzip)
// -------------------------------------------------------------
public enum MLAssetError: Error {
    case downloadFailed(underlying: Error)
    case unzipFailed(underlying: Error)
    case invalidModelFormat
}

public protocol URLSessionProtocol {
    func download(from url: URL) async throws -> (URL, URLResponse)
}
extension URLSession: URLSessionProtocol {}

public protocol Unarchiver {
    func unzipItem(at zipURL: URL, to destinationURL: URL) throws
}

public struct DefaultUnarchiver: Unarchiver {
    public init() {}
    public func unzipItem(at zipURL: URL, to destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", zipURL.path, "-d", destinationURL.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw MLAssetError.unzipFailed(underlying: NSError(domain: "MLAssetManager", code: Int(process.terminationStatus), userInfo: nil))
        }
    }
}

public final class MLAssetManager {
    public static let shared = MLAssetManager()

    private let session: URLSessionProtocol
    private let fileManager: FileManager
    private let unarchiver: Unarchiver

    public init(session: URLSessionProtocol = URLSession.shared,
                fileManager: FileManager = .default,
                unarchiver: Unarchiver = DefaultUnarchiver()) {
        self.session = session
        self.fileManager = fileManager
        self.unarchiver = unarchiver
    }

    public func downloadModelIfNeeded(from remoteURL: URL, to localName: String) async throws -> URL {
        let documentsURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let modelsDir = documentsURL.appendingPathComponent("Models", isDirectory: true)
        try fileManager.createDirectory(at: modelsDir, withIntermediateDirectories: true, attributes: nil)

        let ext = remoteURL.pathExtension.lowercased()
        let folderName = "\(localName).\(ext == "zip" ? remoteURL.deletingPathExtension().pathExtension : ext)"
        let finalURL = modelsDir.appendingPathComponent(folderName, isDirectory: true)
        if fileManager.fileExists(atPath: finalURL.path) { return finalURL }

        do {
            let (tempURL, _) = try await session.download(from: remoteURL)
            if ext == "zip" {
                try unarchiver.unzipItem(at: tempURL, to: modelsDir)
                try? fileManager.removeItem(at: tempURL)
            } else {
                try fileManager.moveItem(at: tempURL, to: finalURL)
            }
            return finalURL
        } catch {
            throw MLAssetError.downloadFailed(underlying: error)
        }
    }
}
#endif 