import XCTest
@testable import DeepSleep

final class LoRAAdapterManagerTests: XCTestCase {
    let manager = LoRAAdapterManager.shared
    let testName = "test-adapter"
    let testData = Data([1,2,3,4])
    override func tearDown() {
        manager.deleteAdapter(named: testName)
        super.tearDown()
    }
    func testSaveAndLoadAdapter() {
        manager.saveAdapter(named: testName, data: testData)
        let loaded = manager.loadAdapter(named: testName)
        XCTAssertEqual(loaded, testData, "저장/불러오기 데이터가 일치해야 함")
    }
    func testDeleteAdapterRemovesData() {
        manager.saveAdapter(named: testName, data: testData)
        manager.deleteAdapter(named: testName)
        let loaded = manager.loadAdapter(named: testName)
        XCTAssertNil(loaded, "삭제 후 데이터는 nil이어야 함")
    }
    func testDownloadAdapterSuccess() {
        let exp = expectation(description: "다운로드 성공")
        // 임시 파일 생성 (네트워크 대신 로컬 파일)
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("mock-")
        try? testData.write(to: tmpURL)
        // AdapterDownloader를 실제 네트워크 대신 성공 stub으로 대체해야 함 (DI 구조가 아니므로 실제 네트워크 호출 발생 가능)
        manager.downloadAdapter(from: tmpURL, named: testName) { success in
            XCTAssertTrue(success, "다운로드 성공해야 함")
            let loaded = self.manager.loadAdapter(named: self.testName)
            XCTAssertEqual(loaded, self.testData, "다운로드 후 데이터 일치해야 함")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2)
        try? FileManager.default.removeItem(at: tmpURL)
    }
    func testDownloadAdapterFailure() {
        let exp = expectation(description: "다운로드 실패")
        let invalidURL = URL(fileURLWithPath: "/invalid/path/adapter")
        manager.downloadAdapter(from: invalidURL, named: testName) { success in
            XCTAssertFalse(success, "실패 케이스에서 true 반환하면 안 됨")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2)
    }
    func testCachePreventsRedundantLoad() {
        manager.saveAdapter(named: testName, data: testData)
        // 캐시를 일부러 지우지 않고 loadAdapter 여러 번 호출
        let loaded1 = manager.loadAdapter(named: testName)
        let loaded2 = manager.loadAdapter(named: testName)
        XCTAssertEqual(loaded1, loaded2, "캐시 hit 시 데이터 일치해야 함")
    }
} 