import XCTest
@testable import DeepSleep

final class AIContextBuilderTests: XCTestCase {
    
    var sut: AIContextBuilder!
    
    override func setUpWithError() throws {
        super.setUp()
        sut = AIContextBuilder.shared
    }
    
    override func tearDownWithError() throws {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Happy Path Tests
    
    func testBuildPrompt_WithAllComponents_Success() {
        // Given
        let mode = AIMode.generalConversation
        let personaSignature = "test-persona-sig"
        let recentMessages = [
            ChatMessageLite(role: "user", content: "안녕하세요"),
            ChatMessageLite(role: "assistant", content: "안녕하세요! 무엇을 도와드릴까요?"),
            ChatMessageLite(role: "user", content: "수면에 도움이 되는 음악을 추천해주세요")
        ]
        let coreMemorySummary = "사용자는 클래식 음악을 선호하고 저녁 10시에 주로 잠을 잔다."
        let currentUserMessage = "오늘은 비가 와서 잠이 안 와요"
        
        // When
        let result = sut.buildPrompt(
            for: mode,
            personaSignature: personaSignature,
            recentMessages: recentMessages,
            coreMemorySummary: coreMemorySummary,
            currentUserMessage: currentUserMessage
        )
        
        // Then
        XCTAssertFalse(result.text.isEmpty, "프롬프트 텍스트가 비어있으면 안됨")
        XCTAssertTrue(result.text.contains("### System"), "시스템 프롬프트 섹션이 포함되어야 함")
        XCTAssertTrue(result.text.contains("### Memory"), "메모리 섹션이 포함되어야 함")
        XCTAssertTrue(result.text.contains("### Recent"), "최근 대화 섹션이 포함되어야 함")
        XCTAssertTrue(result.text.contains("### User"), "사용자 입력 섹션이 포함되어야 함")
        XCTAssertTrue(result.text.contains(currentUserMessage), "현재 사용자 메시지가 포함되어야 함")
        XCTAssertTrue(result.text.contains(coreMemorySummary), "핵심 기억이 포함되어야 함")
        XCTAssertGreaterThan(result.qualityScore, 60, "품질 점수는 60 이상이어야 함")
        XCTAssertGreaterThan(result.tokenEstimate, 0, "토큰 추정치는 0보다 커야 함")
        XCTAssertTrue(result.segmentsIncluded.contains("system"), "세그먼트에 시스템이 포함되어야 함")
        XCTAssertTrue(result.segmentsIncluded.contains("memory:summary"), "세그먼트에 메모리가 포함되어야 함")
    }
    
    func testBuildPrompt_WithoutMemory_Success() {
        // Given
        let mode = AIMode.taskAdvice
        let personaSignature = "test-persona-sig"
        let recentMessages = [
            ChatMessageLite(role: "user", content: "할 일 관리 팁을 알려주세요")
        ]
        let coreMemorySummary: String? = nil
        let currentUserMessage = "효율적인 할 일 관리 방법이 궁금해요"
        
        // When
        let result = sut.buildPrompt(
            for: mode,
            personaSignature: personaSignature,
            recentMessages: recentMessages,
            coreMemorySummary: coreMemorySummary,
            currentUserMessage: currentUserMessage
        )
        
        // Then
        XCTAssertFalse(result.text.isEmpty)
        XCTAssertTrue(result.text.contains("### System"))
        XCTAssertFalse(result.text.contains("### Memory"), "메모리가 없으면 메모리 섹션이 없어야 함")
        XCTAssertTrue(result.text.contains("### User"))
        XCTAssertTrue(result.segmentsIncluded.contains("memory:none"), "세그먼트에 메모리 없음이 표시되어야 함")
    }
    
    func testBuildPrompt_WithEmptyRecentMessages_Success() {
        // Given
        let mode = AIMode.emotionDiaryAnalysis
        let personaSignature = "test-persona-sig"
        let recentMessages: [ChatMessageLite] = []
        let coreMemorySummary = "사용자는 평소 스트레스를 많이 받는다."
        let currentUserMessage = "오늘 하루를 분석해주세요"
        
        // When
        let result = sut.buildPrompt(
            for: mode,
            personaSignature: personaSignature,
            recentMessages: recentMessages,
            coreMemorySummary: coreMemorySummary,
            currentUserMessage: currentUserMessage
        )
        
        // Then
        XCTAssertFalse(result.text.isEmpty)
        XCTAssertTrue(result.text.contains("### System"))
        XCTAssertTrue(result.text.contains("### Memory"))
        XCTAssertTrue(result.text.contains("### User"))
        XCTAssertTrue(result.segmentsIncluded.contains("recent:0"), "최근 메시지가 0개임을 표시해야 함")
    }
    
    // MARK: - Edge Cases
    
    func testBuildPrompt_WithEmptyUserMessage_HandlesGracefully() {
        // Given
        let mode = AIMode.generalConversation
        let personaSignature = "test-persona-sig"
        let recentMessages = [
            ChatMessageLite(role: "user", content: "테스트")
        ]
        let coreMemorySummary = "테스트 메모리"
        let currentUserMessage = "" // 빈 사용자 메시지
        
        // When
        let result = sut.buildPrompt(
            for: mode,
            personaSignature: personaSignature,
            recentMessages: recentMessages,
            coreMemorySummary: coreMemorySummary,
            currentUserMessage: currentUserMessage
        )
        
        // Then
        XCTAssertFalse(result.text.isEmpty)
        XCTAssertTrue(result.text.contains("### User\n\n"), "빈 사용자 메시지도 섹션은 포함되어야 함")
        XCTAssertGreaterThan(result.qualityScore, 0, "품질 점수는 0보다 커야 함")
    }
    
    func testBuildPrompt_WithVeryLongMessages_TruncatesCorrectly() {
        // Given
        let mode = AIMode.generalConversation
        let personaSignature = "test-persona-sig"
        let longContent = String(repeating: "긴 메시지 ", count: 1000)
        let recentMessages = Array(repeating: ChatMessageLite(role: "user", content: longContent), count: 20)
        let coreMemorySummary = "테스트"
        let currentUserMessage = "질문"
        
        // When
        let result = sut.buildPrompt(
            for: mode,
            personaSignature: personaSignature,
            recentMessages: recentMessages,
            coreMemorySummary: coreMemorySummary,
            currentUserMessage: currentUserMessage
        )
        
        // Then
        XCTAssertFalse(result.text.isEmpty)
        XCTAssertLessThan(result.tokenEstimate, 10000, "토큰 추정치가 예산을 초과하지 않아야 함")
        XCTAssertGreaterThan(result.qualityScore, 0)
        
        // TokenOptimizer가 메시지를 적절히 잘라냈는지 확인
        let includedCount = result.segmentsIncluded.first { $0.hasPrefix("recent:") }
            .flatMap { segment in
                let numberString = segment.replacingOccurrences(of: "recent:", with: "")
                return Int(numberString)
            } ?? 0
        XCTAssertLessThan(includedCount, 20, "모든 메시지가 포함되지 않고 일부만 포함되어야 함")
    }
    
    func testBuildPrompt_WithSpecialCharacters_HandlesCorrectly() {
        // Given
        let mode = AIMode.generalConversation
        let personaSignature = "test-persona-sig"
        let recentMessages = [
            ChatMessageLite(role: "user", content: "특수문자 테스트: \"안녕\" 'hello' \n\t탭과 줄바꿈"),
            ChatMessageLite(role: "assistant", content: "이모지 테스트 😀🎵💤")
        ]
        let coreMemorySummary = "특수문자: & < > \" ' \\ / 백슬래시"
        let currentUserMessage = "JSON 테스트: {\"key\": \"value\"}"
        
        // When
        let result = sut.buildPrompt(
            for: mode,
            personaSignature: personaSignature,
            recentMessages: recentMessages,
            coreMemorySummary: coreMemorySummary,
            currentUserMessage: currentUserMessage
        )
        
        // Then
        XCTAssertFalse(result.text.isEmpty)
        XCTAssertTrue(result.text.contains("특수문자 테스트"))
        XCTAssertTrue(result.text.contains("이모지 테스트"))
        XCTAssertTrue(result.text.contains("JSON 테스트"))
        XCTAssertGreaterThan(result.qualityScore, 0)
    }
    
    // MARK: - Exception Cases
    
    func testBuildPrompt_WithNilMemoryAndEmptyMessages_StillProducesValidPrompt() {
        // Given
        let mode = AIMode.generalConversation
        let personaSignature = ""
        let recentMessages: [ChatMessageLite] = []
        let coreMemorySummary: String? = nil
        let currentUserMessage = "단독 메시지"
        
        // When
        let result = sut.buildPrompt(
            for: mode,
            personaSignature: personaSignature,
            recentMessages: recentMessages,
            coreMemorySummary: coreMemorySummary,
            currentUserMessage: currentUserMessage
        )
        
        // Then
        XCTAssertFalse(result.text.isEmpty)
        XCTAssertTrue(result.text.contains("### System"))
        XCTAssertTrue(result.text.contains("### User"))
        XCTAssertTrue(result.text.contains(currentUserMessage))
        XCTAssertGreaterThan(result.qualityScore, 40, "최소한 시스템과 사용자 입력으로 40점 이상")
    }
    
    func testBuildPrompt_WithDifferentAIModes_GeneratesAppropriateSystems() {
        // Given
        let modes: [AIMode] = [
            .generalConversation,
            .emotionDiaryAnalysis,
            .taskAdvice,
            .presetRecommendation,
            .fortuneTelling,
            .monthlyStatistics
        ]
        let personaSignature = "test-persona-sig"
        let recentMessages = [ChatMessageLite(role: "user", content: "테스트")]
        let coreMemorySummary = "테스트 메모리"
        let currentUserMessage = "테스트 메시지"
        
        // When & Then
        for mode in modes {
            let result = sut.buildPrompt(
                for: mode,
                personaSignature: personaSignature,
                recentMessages: recentMessages,
                coreMemorySummary: coreMemorySummary,
                currentUserMessage: currentUserMessage
            )
            
            XCTAssertFalse(result.text.isEmpty, "모드 \(mode.rawValue)에서 프롬프트가 비어있으면 안됨")
            XCTAssertTrue(result.text.contains(mode.rawValue), "시스템 프롬프트에 현재 모드가 포함되어야 함")
            XCTAssertGreaterThan(result.qualityScore, 0, "모드 \(mode.rawValue)에서 품질 점수가 0보다 커야 함")
        }
    }
    
    // MARK: - Quality Score Tests
    
    func testQualityScore_Calculation() {
        // Given - 최소 구성
        let minimalResult = sut.buildPrompt(
            for: .generalConversation,
            personaSignature: "",
            recentMessages: [],
            coreMemorySummary: nil,
            currentUserMessage: "테스트"
        )
        
        // Given - 풍부한 구성
        let richResult = sut.buildPrompt(
            for: .generalConversation,
            personaSignature: "rich-persona",
            recentMessages: Array(repeating: ChatMessageLite(role: "user", content: "메시지"), count: 10),
            coreMemorySummary: "풍부한 핵심 기억 요약",
            currentUserMessage: "상세한 사용자 입력"
        )
        
        // Then
        XCTAssertLessThan(minimalResult.qualityScore, richResult.qualityScore,
                         "풍부한 컨텍스트의 품질 점수가 더 높아야 함")
        XCTAssertLessThanOrEqual(richResult.qualityScore, 100, "품질 점수는 100을 초과할 수 없음")
        XCTAssertGreaterThanOrEqual(minimalResult.qualityScore, 50, "최소 품질 점수는 50 이상이어야 함")
    }
    
    // MARK: - Performance Tests
    
    func testBuildPrompt_Performance() {
        // Given
        let mode = AIMode.generalConversation
        let personaSignature = "test-persona-sig"
        let recentMessages = Array(repeating: ChatMessageLite(role: "user", content: "테스트 메시지"), count: 100)
        let coreMemorySummary = "테스트 메모리"
        let currentUserMessage = "테스트 입력"
        
        // When & Then
        measure {
            _ = sut.buildPrompt(
                for: mode,
                personaSignature: personaSignature,
                recentMessages: recentMessages,
                coreMemorySummary: coreMemorySummary,
                currentUserMessage: currentUserMessage
            )
        }
    }
}
