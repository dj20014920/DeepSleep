// MLAssetManagerTests.swift – 임시 디렉토리 기반, MockURLSession/Unarchiver/FileManager로 완전한 테스트 환경 구축
// MLAssetManager의 다운로드/압축/에러 케이스를 실제 파일시스템 오염 없이 검증
// Summary: Unit tests for MLAssetManager covering download, unzip, and error cases.

import XCTest
@testable import DeepSleep

/// Tests for MLAssetManager behavior.
final class MLAssetManagerTests: XCTestCase {
    private var tempDir: URL!
    private var fileManager: FileManager!
    private var mockFileManager: MockFileManager!
    private var session: MockURLSession!
    private var unarchiver: MockUnarchiver!
    private var manager: MLAssetManager!

    override func setUp() {
        super.setUp()
        // Setup a temporary directory to simulate Documents.
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        fileManager = FileManager.default
        mockFileManager = MockFileManager(mockDocumentsDirectory: tempDir)
        session = MockURLSession()
        unarchiver = MockUnarchiver()
        manager = MLAssetManager(session: session, fileManager: mockFileManager, unarchiver: unarchiver)
    }

    override func tearDown() {
        try? fileManager.removeItem(at: tempDir)
        super.tearDown()
    }

    /// Should return existing model directory without downloading.
    func testModelAlreadyDownloaded() async throws {
        let modelsDir = tempDir.appendingPathComponent("Models", isDirectory: true)
        let modelDir = modelsDir.appendingPathComponent("testmodel.mlmodelc", isDirectory: true)
        try fileManager.createDirectory(at: modelDir, withIntermediateDirectories: true, attributes: nil)
        let url = try await manager.downloadModelIfNeeded(from: URL(string: "https://example.com/testmodel.mlmodelc")!, to: "testmodel")
        XCTAssertEqual(url, modelDir)
        XCTAssertNil(session.lastURL)
        XCTAssertFalse(unarchiver.didUnzip)
    }

    /// Should unzip and return model directory on zip archive download.
    func testZipUnzipSuccess() async throws {
        let remoteURL = URL(string: "https://example.com/model.zip")!
        let zipFileURL = tempDir.appendingPathComponent("model.zip")
        try Data().write(to: zipFileURL)
        session.nextURL = zipFileURL
        session.nextResponse = URLResponse()
        unarchiver.unzipHandler = { zipURL, destination in
            let modelDir = destination.appendingPathComponent("model.mlmodelc", isDirectory: true)
            try self.fileManager.createDirectory(at: modelDir, withIntermediateDirectories: true, attributes: nil)
        }
        let url = try await manager.downloadModelIfNeeded(from: remoteURL, to: "model")
        let expected = tempDir.appendingPathComponent("Models/model.mlmodelc")
        XCTAssertEqual(url, expected)
        XCTAssertEqual(session.lastURL, remoteURL)
        XCTAssertTrue(unarchiver.didUnzip)
    }

    /// Should throw `invalidModelFormat` if unarchived directory is missing.
    func testInvalidZipStructureThrowsInvalidModelFormat() async {
        let remoteURL = URL(string: "https://example.com/invalid.zip")!
        let zipFileURL = tempDir.appendingPathComponent("invalid.zip")
        try? Data().write(to: zipFileURL)
        session.nextURL = zipFileURL
        unarchiver.unzipHandler = { zipURL, destination in /* no-op */ }
        do {
            _ = try await manager.downloadModelIfNeeded(from: remoteURL, to: "invalid")
            XCTFail("Expected invalidModelFormat error")
        } catch {
            guard let assetError = error as? MLAssetError, case .invalidModelFormat = assetError else {
                XCTFail("Expected invalidModelFormat, got \(error)")
                return
            }
        }
    }

    /// Should propagate `unzipFailed` when unarchiver throws.
    func testUnzipFailsThrowsUnzipFailed() async {
        let remoteURL = URL(string: "https://example.com/fail.zip")!
        let zipFileURL = tempDir.appendingPathComponent("fail.zip")
        try? Data().write(to: zipFileURL)
        session.nextURL = zipFileURL
        unarchiver.unzipHandler = { zipURL, destination in
            throw MLAssetError.unzipFailed(underlying: NSError(domain: "", code: 1, userInfo: nil))
        }
        do {
            _ = try await manager.downloadModelIfNeeded(from: remoteURL, to: "fail")
            XCTFail("Expected unzipFailed error")
        } catch {
            guard let assetError = error as? MLAssetError, case .unzipFailed = assetError else {
                XCTFail("Expected unzipFailed, got \(error)")
                return
            }
        }
    }

    /// Should propagate `downloadFailed` when download errors occur.
    func testDownloadFailsThrowsDownloadFailed() async {
        let remoteURL = URL(string: "https://example.com/faildownload.zip")!
        session.nextError = URLError(.notConnectedToInternet)
        do {
            _ = try await manager.downloadModelIfNeeded(from: remoteURL, to: "faildownload")
            XCTFail("Expected downloadFailed error")
        } catch {
            guard let assetError = error as? MLAssetError, case .downloadFailed = assetError else {
                XCTFail("Expected downloadFailed, got \(error)")
                return
            }
        }
    }
}

/// Mock FileManager to override Documents directory during tests.
final class MockFileManager: FileManager {
    private let mockDocumentsDirectory: URL

    init(mockDocumentsDirectory: URL) {
        self.mockDocumentsDirectory = mockDocumentsDirectory
        super.init()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        if directory == .documentDirectory && domainMask == .userDomainMask {
            return [mockDocumentsDirectory]
        }
        return super.urls(for: directory, in: domainMask)
    }
}

/// Mock URLSessionProtocol for simulating download behaviors.
final class MockURLSession: URLSessionProtocol {
    var nextURL: URL?
    var nextResponse: URLResponse?
    var nextError: Error?

    private(set) var lastURL: URL?

    func download(from url: URL) async throws -> (URL, URLResponse) {
        lastURL = url
        if let error = nextError {
            throw error
        }
        guard let url = nextURL, let response = nextResponse else {
            fatalError("MockURLSession not configured with nextURL and nextResponse")
        }
        return (url, response)
    }
}

/// Mock Unarchiver for simulating unzip behaviors.
final class MockUnarchiver: Unarchiver {
    var didUnzip = false
    var unzipHandler: ((URL, URL) throws -> Void)?

    func unzipItem(at zipURL: URL, to destinationURL: URL) throws {
        didUnzip = true
        if let handler = unzipHandler {
            try handler(zipURL, destinationURL)
        }
    }
} 