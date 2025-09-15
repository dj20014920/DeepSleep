import Foundation
import CryptoKit

// 중앙집중형 페르소나/모드/모델 캐시 시그니처 빌더
// DRY: AIContextBuilder, UnifiedAIServiceImpl 등에서 동일 유틸 사용
public enum AIContextSignature {
    // 입력을 안전하게 정규화
    private static func norm(_ s: String) -> String {
        return s.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\u{0000}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sha256(_ s: String) -> String {
        let data = Data(s.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // 공용: AIModelType → AIModel 매핑(단일 출처)
    public static func mapModel(from type: AIModelType) -> AIModel {
        switch type {
        case .claude35: return .claude
        case .gpt4:     return .openAI
        case .gemini:   return .gemini
        case .naver:    return .naver
        case .onDevice: return .onDevice
        case .freeModel:return .freeModel
        case .testModel:return .freeModel
        }
    }

    // personaSignature: UserRulesManager.shared.personaSignature() 반환값(sha256) 등 안전지문
    public static func build(personaSignature: String, mode: AIMode, model: AIModel, memorySummaryFP: String?) -> String {
        let p = norm(personaSignature)
        let m = model.rawValue
        let md = mode.rawValue
        let mem = memorySummaryFP ?? "none"
        let joined = "p:\(p)|mode:\(md)|model:\(m)|mem:\(mem)"
        return sha256(joined)
    }

    // Base cache key without model dimension (for cross-model sharing)
    public static func buildBase(personaSignature: String, mode: AIMode, memorySummaryFP: String?) -> String {
        let p = norm(personaSignature)
        let md = mode.rawValue
        let mem = memorySummaryFP ?? "none"
        let joined = "p:\(p)|mode:\(md)|mem:\(mem)"
        return sha256(joined)
    }

    // MARK: - SSOT helpers for consistent base key across the app
    /// Stable fingerprint for current memory summary (sha256 of normalized summary). Returns nil if empty.
    public static func currentMemorySummaryFP(maxItems: Int = 5) -> String? {
        let summary = MemoryManager.shared.getMemorySummary(maxItems: maxItems)
        if summary.isEmpty { return nil }
        return sha256(norm(summary))
    }

    /// Single Source of Truth: compute base cache key for the current user + mode.
    public static func computeBaseKeyForCurrentUser(mode: AIMode, maxItems: Int = 5) -> String {
        let personaCore = UserRulesManager.shared.personaCoreSignature()
        let memFP = currentMemorySummaryFP(maxItems: maxItems)
        return buildBase(personaSignature: personaCore, mode: mode, memorySummaryFP: memFP)
    }
}
