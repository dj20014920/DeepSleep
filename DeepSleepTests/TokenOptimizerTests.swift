import XCTest
@testable import DeepSleep

final class TokenOptimizerTests: XCTestCase {
    
    var sut: TokenOptimizer!
    
    override func setUpWithError() throws {
        super.setUp()
        sut = TokenOptimizer.shared
    }
    
    override func tearDownWithError() throws {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Token Estimation Tests
    
    func testEstimateTokens_EmptyString_ReturnsZero() {
        // Given
        let text = ""
        
        // When
        let result = sut.estimateTokens(for: text)
        
        // Then
        XCTAssertEqual(result, 0)
    }
    
    func testEstimateTokens_EnglishText_EstimatesCorrectly() {
        // Given
        let text = "Hello, this is a test message for token estimation."
        // 약 10개 단어, 대략 3-4문자당 1토큰이므로 약 14-15토큰 예상
        
        // When
        let result = sut.estimateTokens(for: text)
        
        // Then
        XCTAssertGreaterThan(result, 10)
        XCTAssertLessThan(result, 20)
    }
    
    func testEstimateTokens_KoreanText_AppliesCJKWeight() {
        // Given
        let text = "안녕하세요. 이것은 토큰 추정을 위한 테스트 메시지입니다."
        // CJK 문자가 포함되어 있으므로 가중치가 적용되어야 함
        
        // When
        let result = sut.estimateTokens(for: text)
        
        // Then
        XCTAssertGreaterThan(result, 15)
        XCTAssertLessThan(result, 30)
    }
    
    func testEstimateTokens_MixedLanguage_HandlesCorrectly() {
        // Given
        let text = "Hello 안녕하세요 こんにちは 你好 Bonjour"
        // 여러 언어가 섞여있는 경우
        
        // When
        let result = sut.estimateTokens(for: text)
        
        // Then
        XCTAssertGreaterThan(result, 5)
        XCTAssertLessThan(result, 20)
    }
    
    func testEstimateTokens_SpecialCharactersAndEmoji_HandlesCorrectly() {
        // Given
        let text = "Special chars: !@#$%^&*() 이모지: 😀🎵💤 \n\t줄바꿈과 탭"
        
        // When
        let result = sut.estimateTokens(for: text)
        
        // Then
        XCTAssertGreaterThan(result, 10)
        XCTAssertLessThan(result, 30)
    }
    
    func testEstimateTokens_VeryLongText_ScalesApropriately() {
        // Given
        let text = String(repeating: "긴 텍스트 ", count: 1000)
        
        // When
        let result = sut.estimateTokens(for: text)
        
        // Then
        XCTAssertGreaterThan(result, 1000)
        XCTAssertLessThan(result, 5000)
    }
    
    // MARK: - Max Tokens Tests
    
    func testMaxTokens_AllModes_ReturnsPositiveValues() {
        // Given
        let modes: [AIMode] = [
            .generalConversation,
            .presetRecommendation,
            .emotionDiaryAnalysis,
            .monthlyStatistics,
            .taskAdvice,
            .fortuneTelling,
            .emotionAnalysis
        ]
        
        // When & Then
        for mode in modes {
            let maxTokens = sut.maxTokens(for: mode)
            XCTAssertGreaterThan(maxTokens, 0, "모드 \(mode.rawValue)의 최대 토큰이 0보다 커야 함")
            XCTAssertLessThanOrEqual(maxTokens, 10000, "모드 \(mode.rawValue)의 최대 토큰이 합리적인 범위 내여야 함")
        }
    }
    
    func testMaxTokens_GeneralConversation_ReturnsExpectedValue() {
        // When
        let result = sut.maxTokens(for: .generalConversation)
        
        // Then
        // Bundle에서 읽을 수 없는 경우 기본값 800이 반환되어야 함
        XCTAssertGreaterThanOrEqual(result, 800)
    }
    
    func testMaxTokens_PresetRecommendation_ReturnsLowerValue() {
        // When
        let generalTokens = sut.maxTokens(for: .generalConversation)
        let presetTokens = sut.maxTokens(for: .presetRecommendation)
        
        // Then
        // 프리셋 추천은 일반 대화보다 적은 토큰을 사용해야 함
        XCTAssertLessThanOrEqual(presetTokens, generalTokens)
    }
    
    // MARK: - Fit Recent Messages Tests
    
    func testFitRecentMessages_WithinBudget_IncludesAllMessages() {
        // Given
        let systemPrompt = "시스템 프롬프트"
        let memories = "핵심 기억"
        let recentMessages = ["메시지1", "메시지2", "메시지3"]
        let userInput = "사용자 입력"
        let budget = 1000 // 충분한 예산
        
        // When
        let result = sut.fitRecentMessages(
            systemPrompt: systemPrompt,
            memories: memories,
            recentMessages: recentMessages,
            userInput: userInput,
            budget: budget
        )
        
        // Then
        XCTAssertEqual(result.included.count, recentMessages.count)
        XCTAssertEqual(result.included, recentMessages)
        XCTAssertLessThan(result.total, budget)
    }
    
    func testFitRecentMessages_ExceedsBudget_TruncatesOldestMessages() {
        // Given
        let systemPrompt = "시스템 프롬프트"
        let memories = "핵심 기억"
        let recentMessages = Array(repeating: "긴 메시지 내용 ".repeat(100), count: 10)
        let userInput = "사용자 입력"
        let budget = 200 // 제한된 예산
        
        // When
        let result = sut.fitRecentMessages(
            systemPrompt: systemPrompt,
            memories: memories,
            recentMessages: recentMessages,
            userInput: userInput,
            budget: budget
        )
        
        // Then
        XCTAssertLessThan(result.included.count, recentMessages.count)
        XCTAssertLessThanOrEqual(result.total, budget)
        // 최신 메시지가 포함되었는지 확인
        if !result.included.isEmpty {
            XCTAssertEqual(result.included.last, recentMessages.last)
        }
    }
    
    func testFitRecentMessages_NoMemories_HandlesNilCorrectly() {
        // Given
        let systemPrompt = "시스템 프롬프트"
        let memories: String? = nil
        let recentMessages = ["메시지1", "메시지2"]
        let userInput = "사용자 입력"
        let budget = 500
        
        // When
        let result = sut.fitRecentMessages(
            systemPrompt: systemPrompt,
            memories: memories,
            recentMessages: recentMessages,
            userInput: userInput,
            budget: budget
        )
        
        // Then
        XCTAssertGreaterThanOrEqual(result.included.count, 0)
        XCTAssertLessThanOrEqual(result.total, budget)
    }
    
    func testFitRecentMessages_EmptyRecentMessages_HandlesCorrectly() {
        // Given
        let systemPrompt = "시스템 프롬프트"
        let memories = "핵심 기억"
        let recentMessages: [String] = []
        let userInput = "사용자 입력"
        let budget = 500
        
        // When
        let result = sut.fitRecentMessages(
            systemPrompt: systemPrompt,
            memories: memories,
            recentMessages: recentMessages,
            userInput: userInput,
            budget: budget
        )
        
        // Then
        XCTAssertEqual(result.included.count, 0)
        XCTAssertGreaterThan(result.total, 0) // 시스템 프롬프트와 사용자 입력의 토큰
        XCTAssertLessThanOrEqual(result.total, budget)
    }
    
    func testFitRecentMessages_VerySmallBudget_PrioritizesSystemAndUser() {
        // Given
        let systemPrompt = "시스템"
        let memories = "기억"
        let recentMessages = ["매우 긴 메시지 ".repeat(100)]
        let userInput = "입력"
        let budget = 10 // 매우 작은 예산
        
        // When
        let result = sut.fitRecentMessages(
            systemPrompt: systemPrompt,
            memories: memories,
            recentMessages: recentMessages,
            userInput: userInput,
            budget: budget
        )
        
        // Then
        // 예산이 매우 작으면 최근 메시지는 포함되지 않을 수 있음
        XCTAssertEqual(result.included.count, 0)
        XCTAssertLessThanOrEqual(result.total, budget)
    }
    
    func testFitRecentMessages_PreservesMessageOrder() {
        // Given
        let systemPrompt = "시스템"
        let memories = nil
        let recentMessages = ["첫번째", "두번째", "세번째", "네번째", "다섯번째"]
        let userInput = "입력"
        let budget = 500
        
        // When
        let result = sut.fitRecentMessages(
            systemPrompt: systemPrompt,
            memories: memories,
            recentMessages: recentMessages,
            userInput: userInput,
            budget: budget
        )
        
        // Then
        // 포함된 메시지들의 순서가 유지되어야 함
        for i in 0..<result.included.count-1 {
            let firstIndex = recentMessages.firstIndex(of: result.included[i]) ?? -1
            let secondIndex = recentMessages.firstIndex(of: result.included[i+1]) ?? -1
            XCTAssertLessThan(firstIndex, secondIndex, "메시지 순서가 유지되어야 함")
        }
    }
    
    // MARK: - Edge Cases
    
    func testFitRecentMessages_ZeroBudget_ReturnsEmpty() {
        // Given
        let systemPrompt = "시스템"
        let memories = "기억"
        let recentMessages = ["메시지"]
        let userInput = "입력"
        let budget = 0
        
        // When
        let result = sut.fitRecentMessages(
            systemPrompt: systemPrompt,
            memories: memories,
            recentMessages: recentMessages,
            userInput: userInput,
            budget: budget
        )
        
        // Then
        XCTAssertEqual(result.included.count, 0)
        XCTAssertGreaterThanOrEqual(result.total, 0)
    }
    
    func testFitRecentMessages_NegativeBudget_HandlesGracefully() {
        // Given
        let systemPrompt = "시스템"
        let memories = "기억"
        let recentMessages = ["메시지"]
        let userInput = "입력"
        let budget = -100
        
        // When
        let result = sut.fitRecentMessages(
            systemPrompt: systemPrompt,
            memories: memories,
            recentMessages: recentMessages,
            userInput: userInput,
            budget: budget
        )
        
        // Then
        XCTAssertEqual(result.included.count, 0)
        XCTAssertGreaterThanOrEqual(result.total, 0)
    }
    
    // MARK: - Performance Tests
    
    func testEstimateTokens_Performance() {
        let text = String(repeating: "테스트 텍스트 ", count: 1000)
        
        measure {
            _ = sut.estimateTokens(for: text)
        }
    }
    
    func testFitRecentMessages_Performance() {
        let systemPrompt = "시스템 프롬프트"
        let memories = "핵심 기억"
        let recentMessages = Array(repeating: "메시지 내용", count: 100)
        let userInput = "사용자 입력"
        let budget = 1000
        
        measure {
            _ = sut.fitRecentMessages(
                systemPrompt: systemPrompt,
                memories: memories,
                recentMessages: recentMessages,
                userInput: userInput,
                budget: budget
            )
        }
    }
}

// MARK: - Helper Extension

private extension String {
    func `repeat`(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}
