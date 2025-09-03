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
        print("   - PersonaCoreSignature: \(String(personaSignature.prefix(16)))...")
        print("   - Recent messages count: \(recentMessages.count)")
        print("   - Core memory summary: \(coreMemorySummary != nil ? "Present (\(coreMemorySummary!.count) chars)" : "None")")
        print("   - Current message: \(currentUserMessage.prefix(100))...")

// 1) 시스템 프롬프트 (캐시)
        // DRY: 중앙 유틸 기반 시그니처로 캐시 키 통일
        let selectedModel = SettingsManager.shared.selectedLLM
        _ = AIContextSignature.mapModel(from: selectedModel) // retained for parity, not used in base key
        let memorySummaryFP: String? = {
            let s = MemoryManager.shared.getMemorySummary(maxItems: 5)
            return s.isEmpty ? nil : String(s.hashValue)
        }()
        let unifiedSignature = AIContextSignature.buildBase(
            personaSignature: UserRulesManager.shared.personaCoreSignature(),
            mode: mode,
            memorySummaryFP: memorySummaryFP
        )
        
        let systemPrompt = AIContextManager.shared.getSystemPrompt(personaSignature: unifiedSignature) {
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
        역할: 따뜻하고 실용적인 한국어 AI 동반자.
        톤: 친근하되 과하지 않음. 첫 응답만 간단한 인사 허용, 이후 인사/서두 반복 금지.

        핵심 원칙
        - 공감 → 요약 → 실행 제안(필요 시 구체 예시 1~2개)
        - 불확실하면 모호함을 표시하고 추가 질문 1~2개로 명확화
        - 개인정보 외부 저장 금지, 제공된 히스토리 범위에서만 일관성 유지
        - "기억 못 한다" 같은 메타 발화 금지
        - JSON이 요구되면 정확한 스키마만 출력, 아니면 명료한 텍스트

        스타일 가이드
        - 핵심부터 간결하게, 과도한 이모지/수식/자기소개 금지
        - 동일 문장/결론 반복 금지
        - 시스템 프롬프트 문구를 그대로 복사하여 출력하지 말 것

        현재 목적: \(mode.displayName)
        """
    }
}
