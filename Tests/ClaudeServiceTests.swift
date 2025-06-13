import XCTest
@testable import DeepSleep

final class ClaudeServiceTests: XCTestCase {
    var session: URLSession!
    override func setUp() {
        super.setUp()
        // 테스트용 API 키 저장 (Keychain mock)
        SecureEnclaveKeyStore.shared.saveAPIKey("test-key")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
    }
    override func tearDown() {
        SecureEnclaveKeyStore.shared.deleteAPIKey()
        session = nil
        super.tearDown()
    }
    func testSendMessageSuccess() {
        let service = ClaudeService(session: session)
        let exp = expectation(description: "sendMessage returns success")
        MockURLProtocol.requestHandler = { request in
            let data = "ok-response".data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        service.sendMessage("hello") { result in
            switch result {
            case .success(let str):
                XCTAssertTrue(str.contains("ok-response"), "응답 문자열이 포함되어야 함")
            case .failure(let err):
                XCTFail("성공 케이스에서 실패: \(err)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2)
    }
    func testSendMessageNoAPIKey() {
        let service = ClaudeService(session: session)
        SecureEnclaveKeyStore.shared.deleteAPIKey()
        let exp = expectation(description: "API키 없을 때 실패 반환")
        service.sendMessage("test") { result in
            switch result {
            case .success:
                XCTFail("API키 없으면 성공하면 안 됨")
            case .failure(let err):
                XCTAssertNotNil(err, "에러가 반드시 발생해야 함")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
}

// 네트워크 mock용 URLProtocol
final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("requestHandler가 설정되어야 함")
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
} 