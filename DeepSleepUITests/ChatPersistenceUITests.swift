import XCTest

class ChatPersistenceUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    // MARK: - 채팅 메시지 지속성 테스트
    
    func testChatMessagePersistenceAfterLeavingAndReturning() {
        // Given - 채팅 화면으로 이동
        navigateToChatScreen()
        
        // When - 메시지 입력 및 전송
        let testMessage = "UI 테스트 메시지 \(Date().timeIntervalSince1970)"
        sendMessage(testMessage)
        
        // 메시지가 화면에 표시되는지 확인
        XCTAssertTrue(waitForMessageToAppear(testMessage))
        
        // 채팅 화면 나가기
        navigateBack()
        
        // 다시 채팅 화면으로 돌아오기
        navigateToChatScreen()
        
        // Then - 이전 메시지가 여전히 존재하는지 확인
        XCTAssertTrue(isMessageVisible(testMessage), "메시지가 저장되지 않았습니다")
    }
    
    func testChatMessagePersistenceAfterAppRestart() {
        // Given - 채팅 화면으로 이동하고 메시지 전송
        navigateToChatScreen()
        let testMessage = "앱 재시작 테스트 메시지 \(Date().timeIntervalSince1970)"
        sendMessage(testMessage)
        XCTAssertTrue(waitForMessageToAppear(testMessage))
        
        // When - 앱 종료 및 재시작
        app.terminate()
        app.launch()
        
        // 다시 채팅 화면으로 이동
        navigateToChatScreen()
        
        // Then - 메시지가 여전히 존재하는지 확인
        XCTAssertTrue(isMessageVisible(testMessage), "앱 재시작 후 메시지가 유실되었습니다")
    }
    
    func testMultipleMessagesPersistence() {
        // Given - 여러 메시지 전송
        navigateToChatScreen()
        
        let messages = [
            "첫 번째 테스트 메시지",
            "두 번째 테스트 메시지",
            "세 번째 테스트 메시지"
        ]
        
        for message in messages {
            sendMessage(message)
            XCTAssertTrue(waitForMessageToAppear(message))
        }
        
        // When - 앱 재시작
        app.terminate()
        app.launch()
        navigateToChatScreen()
        
        // Then - 모든 메시지가 존재하는지 확인
        for message in messages {
            XCTAssertTrue(isMessageVisible(message), "\(message)가 유실되었습니다")
        }
    }
    
    // MARK: - Storage 화면 테스트
    
    func testDeleteMessagesFromStorageScreen() {
        // Given - 메시지 생성
        navigateToChatScreen()
        let testMessage = "삭제 테스트 메시지 \(Date().timeIntervalSince1970)"
        sendMessage(testMessage)
        XCTAssertTrue(waitForMessageToAppear(testMessage))
        
        // When - Storage 화면으로 이동하여 삭제
        navigateToStorageScreen()
        deleteLatestConversation()
        
        // Then - 채팅 화면으로 돌아가서 메시지가 삭제되었는지 확인
        navigateToChatScreen()
        XCTAssertFalse(isMessageVisible(testMessage), "삭제된 메시지가 여전히 표시됩니다")
    }
    
    func testStorageStatisticsDisplay() {
        // Given - 여러 메시지 생성
        navigateToChatScreen()
        for i in 1...5 {
            sendMessage("통계 테스트 메시지 \(i)")
        }
        
        // When - Storage 화면으로 이동
        navigateToStorageScreen()
        
        // Then - 통계 정보가 표시되는지 확인
        XCTAssertTrue(app.staticTexts["총 저장 크기"].exists)
        XCTAssertTrue(app.staticTexts["메시지 수"].exists)
        
        // 메시지 수가 5개 이상인지 확인
        let messageCountLabel = app.staticTexts.matching(identifier: "messageCount").firstMatch
        if messageCountLabel.exists {
            let countText = messageCountLabel.label
            if let count = Int(countText.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                XCTAssertGreaterThanOrEqual(count, 5, "메시지 수가 예상보다 적습니다")
            }
        }
    }
    
    // MARK: - 경계값 테스트
    
    func testEmptyConversationHandling() {
        // Given - 채팅 화면 진입 (메시지 없음)
        navigateToChatScreen()
        
        // Then - 빈 상태 메시지 또는 UI가 올바르게 표시되는지 확인
        let emptyStateMessage = app.staticTexts["대화를 시작해보세요"]
        let chatInputField = app.textFields["메시지 입력"]
        
        XCTAssertTrue(emptyStateMessage.exists || chatInputField.exists, 
                     "빈 대화 상태가 올바르게 처리되지 않았습니다")
    }
    
    func testSingleMessageHandling() {
        // Given - 단일 메시지만 전송
        navigateToChatScreen()
        let singleMessage = "단일 메시지 테스트"
        sendMessage(singleMessage)
        
        // When - 앱 재시작
        app.terminate()
        app.launch()
        navigateToChatScreen()
        
        // Then - 단일 메시지가 올바르게 표시되는지 확인
        XCTAssertTrue(isMessageVisible(singleMessage))
    }
    
    func testLargeNumberOfMessages() {
        // Given - 많은 메시지 생성 (UI 테스트이므로 50개로 제한)
        navigateToChatScreen()
        
        for i in 1...50 {
            sendMessage("대량 메시지 테스트 #\(i)")
            // 각 메시지 사이에 짧은 대기 시간
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // When - 스크롤하여 첫 메시지 확인
        scrollToTop()
        
        // Then - 첫 번째와 마지막 메시지가 모두 존재하는지 확인
        XCTAssertTrue(isMessageVisible("대량 메시지 테스트 #1"))
        
        scrollToBottom()
        XCTAssertTrue(isMessageVisible("대량 메시지 테스트 #50"))
    }
    
    // MARK: - Helper Methods
    
    private func navigateToChatScreen() {
        // 탭바 또는 네비게이션으로 채팅 화면 이동
        if app.tabBars.buttons["채팅"].exists {
            app.tabBars.buttons["채팅"].tap()
        } else if app.buttons["채팅 시작"].exists {
            app.buttons["채팅 시작"].tap()
        }
        
        // 채팅 화면이 나타날 때까지 대기
        _ = app.navigationBars["채팅"].waitForExistence(timeout: 5)
    }
    
    private func navigateToStorageScreen() {
        // 설정 또는 메뉴를 통해 Storage 화면으로 이동
        if app.tabBars.buttons["설정"].exists {
            app.tabBars.buttons["설정"].tap()
        }
        
        if app.buttons["저장소 관리"].exists {
            app.buttons["저장소 관리"].tap()
        } else if app.cells["저장소 관리"].exists {
            app.cells["저장소 관리"].tap()
        }
        
        _ = app.navigationBars["저장소 관리"].waitForExistence(timeout: 5)
    }
    
    private func navigateBack() {
        if app.navigationBars.buttons["Back"].exists {
            app.navigationBars.buttons["Back"].tap()
        } else if app.navigationBars.buttons.element(boundBy: 0).exists {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }
    
    private func sendMessage(_ message: String) {
        let messageField = app.textFields["메시지 입력"]
        if !messageField.exists {
            // 다른 가능한 식별자 시도
            let textView = app.textViews.firstMatch
            if textView.exists {
                textView.tap()
                textView.typeText(message)
            }
        } else {
            messageField.tap()
            messageField.typeText(message)
        }
        
        // 전송 버튼 탭
        if app.buttons["전송"].exists {
            app.buttons["전송"].tap()
        } else if app.buttons["Send"].exists {
            app.buttons["Send"].tap()
        } else {
            // Return 키로 전송 시도
            app.keyboards.buttons["return"].tap()
        }
    }
    
    private func waitForMessageToAppear(_ message: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", message)
        let messageElement = app.staticTexts.containing(predicate).firstMatch
        return messageElement.waitForExistence(timeout: timeout)
    }
    
    private func isMessageVisible(_ message: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", message)
        return app.staticTexts.containing(predicate).firstMatch.exists
    }
    
    private func deleteLatestConversation() {
        // Storage 화면에서 최신 대화 삭제
        let firstCell = app.tables.cells.element(boundBy: 0)
        if firstCell.exists {
            // 스와이프하여 삭제
            firstCell.swipeLeft()
            if app.buttons["삭제"].exists {
                app.buttons["삭제"].tap()
            } else if app.buttons["Delete"].exists {
                app.buttons["Delete"].tap()
            }
            
            // 확인 다이얼로그가 있을 경우 처리
            if app.alerts.element.exists {
                app.alerts.buttons["확인"].tap()
            }
        }
    }
    
    private func scrollToTop() {
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeDown()
            scrollView.swipeDown() // 여러 번 스와이프하여 확실히 상단으로
        }
    }
    
    private func scrollToBottom() {
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
            scrollView.swipeUp() // 여러 번 스와이프하여 확실히 하단으로
        }
    }
    
    // MARK: - Performance Tests
    
    func testScrollPerformanceWithManyMessages() {
        // Given - 많은 메시지가 있는 채팅 화면
        navigateToChatScreen()
        
        for i in 1...30 {
            sendMessage("스크롤 성능 테스트 메시지 \(i)")
            Thread.sleep(forTimeInterval: 0.05)
        }
        
        // Measure scrolling performance
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
            scrollToTop()
            Thread.sleep(forTimeInterval: 0.5)
            scrollToBottom()
        }
    }
    
    func testMessageLoadingPerformance() {
        // Given - 메시지가 있는 상태
        navigateToChatScreen()
        for i in 1...20 {
            sendMessage("로딩 성능 테스트 \(i)")
        }
        
        // Measure loading performance
        measure {
            app.terminate()
            app.launch()
            navigateToChatScreen()
            _ = waitForMessageToAppear("로딩 성능 테스트", timeout: 10)
        }
    }
}
