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

    // 최근 대화 요약(롤링 요약): 변동 정보는 시스템 프롬프트가 아닌 사용자 메시지로 전달하기 위해 사용
    // - 최신순 상위 maxItems만 압축, 개인정보/토큰 최소화를 위해 1줄 요약형으로 구성
    public func summarizeRecent(_ recent: [ChatMessageLite], maxItems: Int = 16) -> String {
        guard !recent.isEmpty else { return "" }
        let top = Array(recent.prefix(maxItems))
        var bullets: [String] = []
        for item in top {
            let role: String = (item.role == "assistant") ? "AI" : (item.role == "system" ? "시스템" : "사용자")
            let text = item.content
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { continue }
            let trimmed = text.count > 80 ? String(text.prefix(80)) + "…" : text
            bullets.append("- \(role): \(trimmed)")
        }
        let joined = bullets.joined(separator: "\n")
        return joined.isEmpty ? "" : "최근 대화 요약:\n" + joined
    }

    // 적응형 요약: 목표 토큰 예산에 맞춰 항목 수를 동적으로 조절
    public func summarizeRecentAdaptive(_ recent: [ChatMessageLite], targetTokens: Int, maxItemsLimit: Int = 20) -> String {
        guard !recent.isEmpty else { return "" }
        let safeTarget = max(80, min(280, targetTokens))
        var bullets: [String] = []
        var accTokens = 0
        // 최신순 상위 maxItemsLimit만 후보로
        let top = Array(recent.prefix(maxItemsLimit))
        for item in top {
            let role: String = (item.role == "assistant") ? "AI" : (item.role == "system" ? "시스템" : "사용자")
            var text = item.content.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if text.count > 80 { text = String(text.prefix(80)) + "…" }
            let line = "- \(role): \(text)"
            let lineTokens = TokenOptimizer.shared.estimateTokens(for: line)
            if bullets.count >= 3 && accTokens + lineTokens > safeTarget { break }
            bullets.append(line)
            accTokens += lineTokens
        }
        let joined = bullets.joined(separator: "\n")
        return joined.isEmpty ? "" : "최근 대화 요약:\n" + joined
    }

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
        // SSOT: base key는 AIContextSignature.computeBaseKeyForCurrentUser를 통해 일관 생성
        let unifiedSignature = AIContextSignature.computeBaseKeyForCurrentUser(mode: mode, maxItems: 5)
        
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
        역할: 따뜻하고 실용적인 한국어 공감 일상대화 친구.
        톤: 사용자의 말투와 상황에 맞게 유연하게 진지하고,유쾌하고,장난스럽게 대답할것
        - 개인정보 외부 저장 금지, 제공된 히스토리 범위에서만 일관성 유지
        - JSON이 요구되면 정확한 스키마만 출력, 아니면 명료한 텍스트
        스타일 가이드
        - 핵심부터 간결하게, 자기소개(모델명출력) 금지
        - 동일 문장/결론 반복 금지
        - 시스템 프롬프트 문구를 그대로 복사하여 출력하지 말 것
        현재 목적: \(mode.displayName)
        """
    }
}
