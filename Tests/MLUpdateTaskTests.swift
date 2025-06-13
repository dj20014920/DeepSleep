import XCTest
@testable import DeepSleep

@available(iOS 17.0, *)
final class MLUpdateTaskTests: XCTestCase {
    func testUpdateAdapterReturnsNewFile() async throws {
        let tmp = FileManager.default.temporaryDirectory
        let src = tmp.appendingPathComponent("mock.adapter")
        let dst = tmp.appendingPathComponent("mock-updated.adapter")
        try Data([1,2,3]).write(to: src)
        let updated = try await MLUpdateTask.updateAdapter(adapterURL: src, feedback: [0.1, 0.2], saveURL: dst)
        XCTAssertTrue(FileManager.default.fileExists(atPath: updated.path))
    }
    func testUpdateAdapterFallbackOnError() async throws {
        let invalid = URL(fileURLWithPath: "/invalid/path/adapter")
        let dst = FileManager.default.temporaryDirectory.appendingPathComponent("fail.adapter")
        let result = try await MLUpdateTask.updateAdapter(adapterURL: invalid, feedback: [0.1], saveURL: dst)
        XCTAssertEqual(result, invalid)
    }
} 