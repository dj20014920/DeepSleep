import XCTest
@testable import DeepSleep

final class ProxyModeBehaviorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // 각 테스트마다 초기화
        #if DEBUG
        EnvironmentConfig.testUseProxyOverride = nil
        EnvironmentConfig.testProxyBaseURLOverride = nil
        #endif
    }

    func test_UseProxyOverride_True_ReflectsInEnvironment() {
        #if DEBUG
        EnvironmentConfig.testUseProxyOverride = true
        EnvironmentConfig.testProxyBaseURLOverride = "https://proxy.example.com"

        XCTAssertTrue(EnvironmentConfig.shared.useProxy)
        XCTAssertEqual(EnvironmentConfig.shared.proxyBaseURL, "https://proxy.example.com")
        #else
        XCTExpectFailure("This test requires DEBUG configuration.")
        #endif
    }

    func test_UseProxyOverride_False_DefaultsWhenNil() {
        #if DEBUG
        EnvironmentConfig.testUseProxyOverride = false
        XCTAssertFalse(EnvironmentConfig.shared.useProxy)
        // BaseURL override 미설정 시 빈 문자열일 수 있음 (환경에 따라 상이)
        #else
        XCTExpectFailure("This test requires DEBUG configuration.")
        #endif
    }
}

