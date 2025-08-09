import XCTest
@testable import DeepSleep

class ChatManagerTests: XCTestCase {
    
    var chatManager: ChatManager!
    
    override func setUp() {
        super.setUp()
        // 새로운 ChatManager 인스턴스 생성
        chatManager = ChatManager.shared
        // 테스트 전에 모든 세션 클리어
        chatManager.clearAllSessions()
    }
    
    override func tearDown() {
        // 테스트 후 정리
        chatManager.clearAllSessions()
        chatManager = nil
        super.tearDown()
    }
    
    // MARK: - Round-Trip 테스트 (저장/복원)
    
    func testSaveAndRestoreSingleMessage() {
        // Given - 단일 메시지 생성
        let session = chatManager.createSession()
        let message = StoredChatMessage(
            id: UUID(),
            text: "테스트 메시지입니다",
            type: .user,
            timestamp: Date(),
            metadata: ["test": "value"]
        )
        
        // When - 메시지 추가 및 플러시
        chatManager.addMessage(to: session.id, message: message)
        chatManager.flush()
        
        // Then - 메시지가 올바르게 저장되고 복원되는지 확인
        let restoredSession = chatManager.getSession(id: session.id)
        XCTAssertNotNil(restoredSession)
        XCTAssertEqual(restoredSession?.messages.count, 1)
        XCTAssertEqual(restoredSession?.messages.first?.text, "테스트 메시지입니다")
        XCTAssertEqual(restoredSession?.messages.first?.type, .user)
        XCTAssertEqual(restoredSession?.messages.first?.metadata?["test"], "value")
    }
    
    func testSaveAndRestoreMultipleMessages() {
        // Given - 여러 메시지 생성
        let session = chatManager.createSession()
        let messages = [
            StoredChatMessage(id: UUID(), text: "첫 번째 메시지", type: .user, timestamp: Date(), metadata: nil),
            StoredChatMessage(id: UUID(), text: "두 번째 메시지", type: .bot, timestamp: Date(), metadata: nil),
            StoredChatMessage(id: UUID(), text: "세 번째 메시지", type: .system, timestamp: Date(), metadata: nil)
        ]
        
        // When - 메시지들 추가
        for message in messages {
            chatManager.addMessage(to: session.id, message: message)
        }
        chatManager.flush()
        
        // Then - 모든 메시지가 올바르게 저장되고 복원되는지 확인
        let restoredSession = chatManager.getSession(id: session.id)
        XCTAssertEqual(restoredSession?.messages.count, 3)
        XCTAssertEqual(restoredSession?.messages[0].text, "첫 번째 메시지")
        XCTAssertEqual(restoredSession?.messages[1].text, "두 번째 메시지")
        XCTAssertEqual(restoredSession?.messages[2].text, "세 번째 메시지")
    }
    
    func testSaveAndRestoreSessionMetadata() {
        // Given - 메타데이터가 있는 세션 생성
        let metadata = ChatSessionMetadata(
            emotion: "happy",
            context: "morning routine",
            userProfile: "test_user"
        )
        let session = chatManager.createSession(metadata: metadata)
        
        // When - 플러시
        chatManager.flush()
        
        // Then - 메타데이터가 올바르게 저장되고 복원되는지 확인
        let restoredSession = chatManager.getSession(id: session.id)
        XCTAssertNotNil(restoredSession?.metadata)
        XCTAssertEqual(restoredSession?.metadata?.emotion, "happy")
        XCTAssertEqual(restoredSession?.metadata?.context, "morning routine")
        XCTAssertEqual(restoredSession?.metadata?.userProfile, "test_user")
    }
    
    // MARK: - 경계값 테스트
    
    func testEmptySession() {
        // Given - 빈 세션 생성
        let session = chatManager.createSession()
        
        // When - 플러시
        chatManager.flush()
        
        // Then - 빈 세션이 올바르게 저장되고 복원되는지 확인
        let restoredSession = chatManager.getSession(id: session.id)
        XCTAssertNotNil(restoredSession)
        XCTAssertEqual(restoredSession?.messages.count, 0)
    }
    
    func testSingleMessageSession() {
        // Given - 1개 메시지만 있는 세션
        let session = chatManager.createSession()
        let message = StoredChatMessage(
            id: UUID(),
            text: "단일 메시지",
            type: .user,
            timestamp: Date(),
            metadata: nil
        )
        
        // When
        chatManager.addMessage(to: session.id, message: message)
        chatManager.flush()
        
        // Then
        let restoredSession = chatManager.getSession(id: session.id)
        XCTAssertEqual(restoredSession?.messages.count, 1)
    }
    
    func testLargeNumberOfMessages() {
        // Given - 1000개의 메시지 생성
        let session = chatManager.createSession()
        let messageCount = 1000
        
        // When - 대량의 메시지 추가
        for i in 0..<messageCount {
            let message = StoredChatMessage(
                id: UUID(),
                text: "메시지 \(i)",
                type: i % 2 == 0 ? .user : .bot,
                timestamp: Date(),
                metadata: ["index": String(i)]
            )
            chatManager.addMessage(to: session.id, message: message)
        }
        chatManager.flush()
        
        // Then - 모든 메시지가 올바르게 저장되고 복원되는지 확인
        let restoredSession = chatManager.getSession(id: session.id)
        XCTAssertEqual(restoredSession?.messages.count, messageCount)
        
        // 첫 번째와 마지막 메시지 확인
        XCTAssertEqual(restoredSession?.messages.first?.text, "메시지 0")
        XCTAssertEqual(restoredSession?.messages.last?.text, "메시지 \(messageCount - 1)")
    }
    
    // MARK: - ChatMessage to StoredChatMessage 변환 테스트
    
    func testChatMessageConversion() {
        // Given - ChatMessage 생성
        let chatMessage = ChatMessage(
            id: UUID(),
            text: "테스트 채팅 메시지",
            date: Date(),
            sender: .user,
            type: .user,
            quickActions: [QuickAction(title: "액션1", action: "action1")],
            isPending: false
        )
        
        // When - append 메서드를 통해 저장
        chatManager.append(chatMessage)
        chatManager.flush()
        
        // Then - 올바르게 변환되어 저장되었는지 확인
        let sessions = chatManager.getSessions()
        XCTAssertGreaterThan(sessions.count, 0)
        
        let latestSession = sessions.first
        let storedMessage = latestSession?.messages.last
        XCTAssertNotNil(storedMessage)
        XCTAssertEqual(storedMessage?.text, "테스트 채팅 메시지")
        XCTAssertEqual(storedMessage?.type, .user)
        XCTAssertTrue(storedMessage?.metadata?["quickActions"]?.contains("액션1") ?? false)
    }
    
    // MARK: - 세션 관리 테스트
    
    func testGetRecentMessages() {
        // Given - 여러 메시지가 있는 세션
        let session = chatManager.createSession()
        for i in 0..<20 {
            let message = StoredChatMessage(
                id: UUID(),
                text: "메시지 \(i)",
                type: .user,
                timestamp: Date(),
                metadata: nil
            )
            chatManager.addMessage(to: session.id, message: message)
        }
        
        // When - 최근 10개 메시지 가져오기
        let recentMessages = chatManager.getRecentMessages(limit: 10)
        
        // Then
        XCTAssertEqual(recentMessages.count, 10)
        XCTAssertEqual(recentMessages.last?.text, "메시지 19")
        XCTAssertEqual(recentMessages.first?.text, "메시지 10")
    }
    
    func testDeleteSession() {
        // Given - 세션 생성
        let session = chatManager.createSession()
        let message = StoredChatMessage(
            id: UUID(),
            text: "삭제될 메시지",
            type: .user,
            timestamp: Date(),
            metadata: nil
        )
        chatManager.addMessage(to: session.id, message: message)
        
        // When - 세션 삭제
        chatManager.deleteSession(id: session.id)
        chatManager.flush()
        
        // Then - 세션이 삭제되었는지 확인
        let restoredSession = chatManager.getSession(id: session.id)
        XCTAssertNil(restoredSession)
    }
    
    func testClearAllSessions() {
        // Given - 여러 세션 생성
        for _ in 0..<5 {
            let session = chatManager.createSession()
            let message = StoredChatMessage(
                id: UUID(),
                text: "메시지",
                type: .user,
                timestamp: Date(),
                metadata: nil
            )
            chatManager.addMessage(to: session.id, message: message)
        }
        
        // When - 모든 세션 삭제
        chatManager.clearAllSessions()
        
        // Then - 모든 세션이 삭제되었는지 확인
        let sessions = chatManager.getSessions()
        XCTAssertEqual(sessions.count, 0)
    }
    
    // MARK: - 메모리 관리 테스트
    
    func testMemoryUsageEstimation() {
        // Given - 메시지가 있는 세션
        let session = chatManager.createSession()
        for i in 0..<10 {
            let message = StoredChatMessage(
                id: UUID(),
                text: String(repeating: "테스트", count: 100), // 긴 텍스트
                type: .user,
                timestamp: Date(),
                metadata: nil
            )
            chatManager.addMessage(to: session.id, message: message)
        }
        
        // When
        let memoryUsage = chatManager.estimatedMemoryUsage
        
        // Then - 메모리 사용량이 0보다 큰지 확인
        XCTAssertGreaterThan(memoryUsage, 0)
    }
    
    func testCleanupOldSessions() {
        // Given - 오래된 세션 생성 (시뮬레이션)
        let oldSession = chatManager.createSession()
        
        // 세션의 lastActivityAt을 31일 전으로 수동 설정 (실제로는 private이므로 테스트용 메서드 필요)
        // 이 테스트는 실제 구현에서는 더 복잡한 방법이 필요함
        
        // When
        chatManager.cleanupOldSessions(olderThan: 30)
        
        // Then
        // 오래된 세션이 삭제되었는지 확인
        // 실제 테스트는 날짜 조작이 필요하므로 생략
    }
    
    // MARK: - 동시성 테스트
    
    func testConcurrentMessageAddition() {
        // Given
        let session = chatManager.createSession()
        let expectation = XCTestExpectation(description: "Concurrent messages")
        let messageCount = 100
        
        // When - 여러 스레드에서 동시에 메시지 추가
        DispatchQueue.concurrentPerform(iterations: messageCount) { index in
            let message = StoredChatMessage(
                id: UUID(),
                text: "동시 메시지 \(index)",
                type: .user,
                timestamp: Date(),
                metadata: nil
            )
            chatManager.addMessage(to: session.id, message: message)
            
            if index == messageCount - 1 {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        chatManager.flush()
        
        // Then - 모든 메시지가 저장되었는지 확인
        let restoredSession = chatManager.getSession(id: session.id)
        XCTAssertEqual(restoredSession?.messages.count, messageCount)
    }
    
    // MARK: - 성능 테스트
    
    func testPerformanceOfLargeMessageSave() {
        measure {
            // Given
            let session = chatManager.createSession()
            
            // When - 100개 메시지 저장 성능 측정
            for i in 0..<100 {
                let message = StoredChatMessage(
                    id: UUID(),
                    text: "성능 테스트 메시지 \(i)",
                    type: .user,
                    timestamp: Date(),
                    metadata: ["index": String(i)]
                )
                chatManager.addMessage(to: session.id, message: message)
            }
            chatManager.flush()
        }
    }
    
    func testPerformanceOfMessageRetrieval() {
        // Setup - 미리 많은 메시지 생성
        let session = chatManager.createSession()
        for i in 0..<1000 {
            let message = StoredChatMessage(
                id: UUID(),
                text: "메시지 \(i)",
                type: .user,
                timestamp: Date(),
                metadata: nil
            )
            chatManager.addMessage(to: session.id, message: message)
        }
        chatManager.flush()
        
        // Performance test
        measure {
            _ = chatManager.getRecentMessages(limit: 100)
        }
    }
}
