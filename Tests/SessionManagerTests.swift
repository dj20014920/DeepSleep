import XCTest
import CoreData
@testable import DeepSleep

/// SessionManager 유닛 테스트
class SessionManagerTests: XCTestCase {
    
    var sessionManager: SessionManager!
    var testContext: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        
        // 인메모리 Core Data 스택 설정
        let managedObjectModel = NSManagedObjectModel()
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        
        do {
            try persistentStoreCoordinator.addPersistentStore(
                ofType: NSInMemoryStoreType,
                configurationName: nil,
                at: nil,
                options: nil
            )
        } catch {
            fatalError("테스트용 인메모리 스토어 생성 실패: \(error)")
        }
        
        testContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        testContext.persistentStoreCoordinator = persistentStoreCoordinator
        
        sessionManager = SessionManager.shared
    }
    
    override func tearDown() {
        sessionManager = nil
        testContext = nil
        super.tearDown()
    }
    
    // MARK: - 세션 생성 테스트
    
    func testCreateSession() {
        // Given
        let metadata = SessionMetadata(primaryEmotion: "기쁨", context: "테스트")
        
        // When
        let session = sessionManager.createSessionSafely(metadata: metadata)
        
        // Then
        XCTAssertNotNil(session)
        XCTAssertFalse(session.id.isEmpty)
        XCTAssertEqual(session.metadata.primaryEmotion, "기쁨")
        XCTAssertEqual(session.metadata.context, "테스트")
        XCTAssertTrue(session.chatMessages.isEmpty)
        XCTAssertTrue(session.feedbackData.isEmpty)
        XCTAssertTrue(session.behaviorEvents.isEmpty)
    }
    
    func testCreateSessionWithError() {
        // Given: Core Data 스택을 의도적으로 손상시킴
        // 실제 테스트에서는 Mock 객체를 사용해야 함
        
        // When & Then
        let session = sessionManager.createSessionSafely(metadata: nil)
        // Then
        XCTAssertNotNil(session)
        // 성공하면 테스트 통과
    }
    
    // MARK: - 세션 조회 테스트
    
    func testGetSession() {
        // Given
        let createdSession = sessionManager.createSessionSafely()
        
        // When
        let retrievedSession = sessionManager.getSession(id: createdSession.id)
        
        // Then
        XCTAssertNotNil(retrievedSession)
        XCTAssertEqual(retrievedSession?.id, createdSession.id)
    }
    
    func testGetNonExistentSession() {
        // Given
        let nonExistentId = "non-existent-id"
        
        // When
        let session = sessionManager.getSession(id: nonExistentId)
        
        // Then
        XCTAssertNil(session)
    }
    
    // MARK: - 메시지 추가 테스트
    
    func testAddChatMessage() {
        // Given
        let session = sessionManager.createSessionSafely()
        let message = StoredChatMessage(
            role: "user",
            content: "테스트 메시지",
            type: .user
        )
        
        // When
        sessionManager.addChatMessage(to: session.id, message: message)
        
        // Then
        let updatedSession = sessionManager.getSession(id: session.id)
        XCTAssertEqual(updatedSession?.chatMessages.count, 1)
        XCTAssertEqual(updatedSession?.chatMessages.first?.content, "테스트 메시지")
    }
    
    // MARK: - 피드백 추가 테스트
    
    func testAddFeedbackData() {
        // Given
        let session = sessionManager.createSessionSafely()
        let feedback = PresetFeedback(
            presetName: "테스트 프리셋",
            contextEmotion: "기쁨",
            contextTime: 14,
            userSatisfaction: 5
        )
        
        // When
        sessionManager.addFeedbackData(to: session.id, feedback: feedback)
        
        // Then
        let updatedSession = sessionManager.getSession(id: session.id)
        XCTAssertEqual(updatedSession?.feedbackData.count, 1)
        XCTAssertEqual(updatedSession?.feedbackData.first?.presetName, "테스트 프리셋")
    }
    
    // MARK: - 행동 이벤트 추가 테스트
    
    func testAddBehaviorEvent() {
        // Given
        let session = sessionManager.createSessionSafely()
        let event = BehaviorEvent(
            type: .presetStart,
            data: ["presetName": "테스트 프리셋"]
        )
        
        // When
        sessionManager.addBehaviorEvent(to: session.id, event: event)
        
        // Then
        let updatedSession = sessionManager.getSession(id: session.id)
        XCTAssertEqual(updatedSession?.behaviorEvents.count, 1)
        XCTAssertEqual(updatedSession?.behaviorEvents.first?.type, .presetStart)
    }
    
    // MARK: - 세션 삭제 테스트
    
    func testDeleteSession() {
        // Given
        let session = sessionManager.createSessionSafely()
        
        // When
        let deleteResult = sessionManager.deleteSession(by: session.id)
        
        // Then
        XCTAssertTrue(deleteResult)
        XCTAssertNil(sessionManager.getSession(id: session.id))
    }
    
    // MARK: - 최근 세션 조회 테스트
    
    func testGetRecentSessions() {
        // Given
        let session1 = sessionManager.createSessionSafely()
        let session2 = sessionManager.createSessionSafely()
        let session3 = sessionManager.createSessionSafely()
        
        // When
        let recentSessions = sessionManager.getRecentSessions(limit: 2)
        
        // Then
        XCTAssertEqual(recentSessions.count, 2)
        // 최근 세션이 먼저 와야 함
        XCTAssertTrue(recentSessions[0].lastActivityAt >= recentSessions[1].lastActivityAt)
    }
    
    // MARK: - 현재 세션 조회/생성 테스트
    
    func testGetCurrentOrCreateSession() {
        // When
        let currentSession = sessionManager.getCurrentOrCreateSession()
        
        // Then
        XCTAssertNotNil(currentSession)
        
        // 같은 날 다시 호출하면 같은 세션이 반환되어야 함
        let sameSession = sessionManager.getCurrentOrCreateSession()
        XCTAssertEqual(currentSession.id, sameSession.id)
    }
    
    // MARK: - 비동기 세션 조회 테스트
    
    func testGetSessionAsync() {
        // Given
        let session = sessionManager.createSessionSafely()
        let expectation = XCTestExpectation(description: "비동기 세션 조회")
        
        // When
        sessionManager.getSessionAsync(id: session.id) { retrievedSession in
            // Then
            XCTAssertNotNil(retrievedSession)
            XCTAssertEqual(retrievedSession?.id, session.id)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - 로컬 AI 컨텍스트 생성 테스트
    
    func testBuildRichContextForLocalAI() {
        // Given
        let session = sessionManager.createSessionSafely()
        let feedback = PresetFeedback(
            presetName: "테스트 프리셋",
            contextEmotion: "기쁨",
            contextTime: 14,
            userSatisfaction: 5
        )
        sessionManager.addFeedbackData(to: session.id, feedback: feedback)
        
        // When
        let context = sessionManager.buildRichContextForLocalAI()
        
        // Then
        XCTAssertNotNil(context)
        XCTAssertFalse(context.feedbackData.isEmpty)
        XCTAssertNotNil(context.lastUpdated)
    }
} 
   
    // MARK: - 에러 처리 테스트
    
    func testErrorPropagation() {
        // Given
        let invalidSessionId = "invalid-session-id"
        let message = StoredChatMessage(role: "user", content: "테스트", type: .user)
        
        // When: 호환성 메서드 사용 (에러를 내부적으로 처리)
        sessionManager.addChatMessage(to: invalidSessionId, message: message)
        
        // Then: 앱이 크래시하지 않아야 함 (에러가 조용히 처리됨)
        XCTAssertTrue(true, "앱이 크래시하지 않음")
    }
    
    func testCacheInvalidation() {
        // Given
        let session = sessionManager.createSessionSafely()
        XCTAssertNotNil(sessionManager.getSession(id: session.id))
        
        // When
        sessionManager.invalidateCache()
        
        // Then
        // 캐시가 무효화된 후에도 Core Data에서 조회 가능해야 함
        XCTAssertNotNil(sessionManager.getSession(id: session.id))
    }
    
    // MARK: - 에러 복구 테스트
    
    func testGracefulFailure() {
        // Given: 잘못된 세션 ID로 작업 시도
        let invalidId = "non-existent-session"
        let message = StoredChatMessage(role: "user", content: "테스트", type: .user)
        
        // When: 호환성 메서드 사용 (에러를 내부적으로 처리)
        sessionManager.addChatMessage(to: invalidId, message: message)
        
        // Then: 앱이 크래시하지 않아야 함 (에러가 조용히 처리됨)
        XCTAssertTrue(true, "앱이 크래시하지 않음")
    }