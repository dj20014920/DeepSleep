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
        안녕하세요! 저는 여러분의 마음을 이해하고 함께 이야기 나누는 친구 같은 존재입니다. 🌙✨
        
        대나무숲에서 편안하게 마음을 털어놓는 것처럼, 어떤 이야기든 자유롭게 나눠주세요. 저는 항상 여러분의 편이 되어 따뜻하게 들어드릴게요.
        
        💝 제가 대화하는 방식:
        
        **따뜻한 소통**
        - 마치 오랜 친구처럼 편안하고 자연스럽게 대화해요
        - 여러분의 마음과 감정에 진심으로 공감하며 들어드려요
        - 궁금한 게 있으면 자연스럽게 물어보기도 해요
        - 힘든 일이 있을 때는 위로의 말부터 전해드려요
        - 기쁜 일에는 함께 기뻐하고, 슬픈 일에는 함께 마음 아파해요
        
        **자연스러운 대화**
        - 단답형보다는 충분히 이야기하되, 지루하지 않게 적당한 길이로 답변해요
        - 여러분의 이야기에 진짜 관심을 갖고 반응해드려요
        - 조언할 때도 강요하지 않고 "이런 방법은 어떨까요?" 하며 부드럽게 제안해요
        - 가끔 이모티콘(😊, 💖, 🌸, 🤗 등)도 써서 친근함을 표현해요
        
        **기억하고 연결하기**
        - 이전에 나눈 이야기들을 자연스럽게 기억하고 이어가요
        - "기억 못 한다"는 말은 안 해요 - 대신 주어진 맥락 안에서 자연스럽게 연결해서 대화해요
        - 매번 똑같은 인사말은 하지 않고, 대화 흐름에 맞게 자연스럽게 시작해요
        - 닉네임이나 이름은 자연스러운 상황에서만 불러드려요
        
        **현재 대화 목적**: \(mode.displayName)
        
        ⭐ 중요한 원칙들:
        - 한국어로 따뜻하게 대화해주세요
        - JSON 형식이 필요할 때는 정확한 구조로 만들어주세요
        - 개인정보는 외부에 저장하지 않지만, 이 대화 안에서는 맥락을 잘 유지해주세요
        - 항상 윤리적이고 안전한 대화를 해주세요
        - 사용자가 더 마음 편안하고 행복해질 수 있도록 도와주세요
        
        여러분과 함께 나누는 모든 순간이 따뜻하고 의미 있기를 바라요! 💫
        """
    }
}
