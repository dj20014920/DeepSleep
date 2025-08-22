import Foundation

public struct AssembledPrompt {
    public let text: String
    public let qualityScore: Int
    public let tokenEstimate: Int
    public let segmentsIncluded: [String]
}

public struct ChatMessageLite: Codable {
    public let role: String   // "user" | "assistant" | "system"
    public let content: String
    public let createdAt: Date

    public init(role: String, content: String, createdAt: Date = Date()) {
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

public final class AIContextBuilder {
    public static let shared = AIContextBuilder()
    private let optimizer = TokenOptimizer.shared
    private let metrics = ContextMetrics.shared

    private init() {}

    public func buildPrompt(for mode: AIMode,
                            personaSignature: String,
                            recentMessages: [ChatMessageLite],
                            coreMemorySummary: String?,
                            currentUserMessage: String) -> AssembledPrompt {

        print("🏗️ [AIContextBuilder] Building prompt:")
        print("   - Mode: \(mode.rawValue)")
        print("   - PersonaSignature: \(String(personaSignature.prefix(16)))...")
        print("   - Recent messages count: \(recentMessages.count)")
        print("   - Core memory summary: \(coreMemorySummary != nil ? "Present (\(coreMemorySummary!.count) chars)" : "None")")
        print("   - Current message: \(currentUserMessage.prefix(100))...")

// 1) 시스템 프롬프트 (캐시)
        let systemPrompt = AIContextManager.shared.getSystemPrompt(personaSignature: personaSignature) {
            // UserSettingsModel에서 AI 컨텍스트 생성
            let userSettings = UserSettingsModel.loadFromUserDefaults()
            let userContext = userSettings.generateAIContext()
            
            // 기본 시스템 프롬프트에 사용자 컨텍스트 추가
            let basePrompt = self.generateDefaultSystemPrompt(mode: mode)
            let fullPrompt = basePrompt + "\n\n" + userContext
            
            print("🎯 [AIContextBuilder] Generated system prompt with user context (length: \(fullPrompt.count))")
            print("👤 [AIContextBuilder] User context included: \(userContext.prefix(200))...")
            
            return fullPrompt
        }

        // 2) 핵심 기억 요약
        let memoryBlock: String? = {
            guard let s = coreMemorySummary, s.isEmpty == false else { return nil }
            return "## 핵심기억 요약\n\(s)"
        }()

        // 3) 최근 n턴(본문만)
        let recentPlain: [String] = recentMessages.map { "\($0.role): \($0.content)" }

        // 4) 토큰 예산
        let budget = optimizer.maxTokens(for: mode)
        let fit = optimizer.fitRecentMessages(systemPrompt: systemPrompt,
                                              memories: memoryBlock,
                                              recentMessages: recentPlain,
                                              userInput: currentUserMessage,
                                              budget: budget)

        // 포함된 최근 대화만 사용
        let includedRecent = fit.included.joined(separator: "\n")

        // 5) 최종 프롬프트 조립
        var parts: [String] = []
        parts.append("### System\n\(systemPrompt)")
        if let mem = memoryBlock {
            parts.append("### Memory\n\(mem)")
        }
        if !includedRecent.isEmpty {
            parts.append("### Recent\n\(includedRecent)")
        }
        parts.append("### User\n\(currentUserMessage)")
        let final = parts.joined(separator: "\n\n")

        // 6) 품질 점수(간단한 휴리스틱)
        var quality = 0
        if !systemPrompt.isEmpty { quality += 40 }
        if memoryBlock != nil { quality += 20 }
        quality += min(30, fit.included.count * 3) // 최근 메시지 포함 수에 비례
        quality += 10 // 현재 입력 존재
        quality = min(100, quality)

        let estimate = optimizer.estimateTokens(for: final)
        metrics.logQualityScore(quality)
        metrics.logTokenEstimate(estimate)

        return AssembledPrompt(text: final,
                               qualityScore: quality,
                               tokenEstimate: estimate,
                               segmentsIncluded: [
                                   "system",
                                   memoryBlock == nil ? "memory:none" : "memory:summary",
                                   "recent:\(fit.included.count)",
                                   "user:1"
                               ])
    }

    // 기본 시스템 프롬프트(PII 노출 방지: 페르소나 시그니처 원문 미포함)
    private func generateDefaultSystemPrompt(mode: AIMode) -> String {
        """
        당신은 사용자만의 친구입니다 대나무숲이라는 대화창에서 사용자가 편하게 느끼도록 대화를 나누어주세요.
        - 한국어로 간결하고 친절하게 답변하세요.
        - JSON이 필요한 경우, 올바른 스키마와 이스케이프를 준수하세요.
        - 개인정보를 요구하거나 저장하지 마세요.
        - 현재 모드: \(mode.rawValue)
        - 안전/윤리 가이드를 준수하세요.
        """
    }
}
