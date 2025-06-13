import XCTest
@testable import DeepSleep

@available(iOS 17.0, *)
final class DynamicLoRAAdapterTests: XCTestCase {
    func testDownloadAdapterCachesFile() async throws {
        let url = URL(string: "https://example.com/test.adapter")!
        // 네트워크 mock 필요: 실제 다운로드 대신 임시 파일/데이터 사용
        // 여기선 실제 다운로드 생략, 캐시 경로만 검증
        let adapter = DynamicLoRAAdapter.shared
        let cached = try await adapter.downloadAdapter(from: url, rank: 4)
        XCTAssertTrue(FileManager.default.fileExists(atPath: cached.path))
    }
    func testDownloadAdapterSkipsIfExists() async throws {
        let url = URL(string: "https://example.com/test2.adapter")!
        let adapter = DynamicLoRAAdapter.shared
        let cached1 = try await adapter.downloadAdapter(from: url, rank: 2)
        let cached2 = try await adapter.downloadAdapter(from: url, rank: 2)
        XCTAssertEqual(cached1, cached2)
    }
    func testDownloadAdapterHandlesError() async throws {
        let url = URL(string: "https://invalid-url/adapter")!
        let adapter = DynamicLoRAAdapter.shared
        do {
            _ = try await adapter.downloadAdapter(from: url, rank: 1)
            XCTFail("에러가 발생해야 함")
        } catch {
            XCTAssertNotNil(error)
        }
    }
} 