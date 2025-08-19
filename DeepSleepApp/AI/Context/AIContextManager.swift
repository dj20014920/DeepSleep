import Foundation
import Foundation
import CryptoKit

public final class AIContextManager {
    public static let shared = AIContextManager()

    private let queue = DispatchQueue(label: "ai.context.manager.queue", qos: .userInitiated, attributes: .concurrent)
    private var cachedSystemPrompt: (prompt: String, timestamp: Date, personaHash: String)?

    private let metrics = ContextMetrics.shared

    // 기본 TTL: 3시간(10800초). Info.plist(또는 xcconfig 매핑)에서 "AI_SYSTEM_PROMPT_CACHE_TTL" 값을 우선 사용
    private lazy var cacheTTL: TimeInterval = {
        if let v = ConfigReader.double("AI_SYSTEM_PROMPT_CACHE_TTL") { return v }
        return 10800
    }()

    private init() {}

    // personaSignature는 페르소나/언어/톤/모드 등의 설정을 해시한 문자열 사용을 권장
    public func getSystemPrompt(personaSignature: String, generator: () -> String) -> String {
        // 읽기 경로
        if let cached = queue.sync(execute: { cachedSystemPrompt }) {
            let age = Date().timeIntervalSince(cached.timestamp)
            if cached.personaHash == personaSignature, age < cacheTTL {
                metrics.logCache(event: .hit, reason: .none, age: age)
                return cached.prompt
            }
        }

        // 미스 또는 만료 → 갱신
        let newPrompt = generator()
        queue.async(flags: .barrier) { [weak self] in
            self?.cachedSystemPrompt = (newPrompt, Date(), personaSignature)
        }
        metrics.logCache(event: .miss, reason: .expiredOrPersonaChanged, age: nil)
        return newPrompt
    }

    // 이벤트 기반 캐시 무효화
    public func clearCache(reason: InvalidationReason, caller: String? = nil) {
        queue.async(flags: .barrier) { [weak self] in
            self?.cachedSystemPrompt = nil
        }
        metrics.logInvalidation(reason: reason, caller: caller)
    }

    // 테스트 및 진단용 (페르소나 시그니처 원문 비노출, 해시 지문만 표시)
    public func debugSnapshot() -> String {
        return queue.sync {
            if let c = cachedSystemPrompt {
                let fp = fingerprint(c.personaHash)
                return "AIContextManager(cache: true, age: \(Int(Date().timeIntervalSince(c.timestamp)))s, personaFP:\(fp))"
            } else {
                return "AIContextManager(cache: false)"
            }
        }
    }

    private func fingerprint(_ s: String) -> String {
        let data = Data(s.utf8)
        let digest = SHA256.hash(data: data)
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(8))
    }
}
