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
        return ConfigReader.double("AI_SYSTEM_PROMPT_CACHE_TTL", default: 10800) ?? 10800
    }()

    private init() {}

    // personaSignature는 페르소나/언어/톤/모드 등의 설정을 해시한 문자열 사용을 권장
    public func getSystemPrompt(personaSignature: String, generator: () -> String) -> String {
        print("🔍 [AIContextManager] getSystemPrompt called with personaSignature: \(String(personaSignature.prefix(16)))...")
        
        // 읽기 경로
        if let cached = queue.sync(execute: { cachedSystemPrompt }) {
            let age = Date().timeIntervalSince(cached.timestamp)
            print("📦 [AIContextManager] Cache found:")
            print("   - Cached personaHash: \(String(cached.personaHash.prefix(16)))...")
            print("   - Current personaSignature: \(String(personaSignature.prefix(16)))...")
            print("   - Cache age: \(age) seconds")
            print("   - Cache TTL: \(cacheTTL) seconds")
            print("   - Hash match: \(cached.personaHash == personaSignature)")
            print("   - Age valid: \(age < cacheTTL)")
            
            if cached.personaHash == personaSignature, age < cacheTTL {
                metrics.logCache(event: .hit, reason: .none, age: age)
                print("✅ [AIContextManager] Cache HIT! Returning cached prompt (length: \(cached.prompt.count))")
                print("📝 Cached prompt preview: \(String(cached.prompt.prefix(200)))...")
                return cached.prompt
            } else {
                print("⚠️ [AIContextManager] Cache invalid - persona changed or expired")
            }
        } else {
            print("🚫 [AIContextManager] No cache found")
        }

        // 미스 또는 만료 → 갱신
        print("🔄 [AIContextManager] Generating new prompt...")
        let newPrompt = generator()
        print("📝 [AIContextManager] New prompt generated (length: \(newPrompt.count))")
        print("📝 New prompt preview: \(String(newPrompt.prefix(200)))...")
        
        queue.async(flags: .barrier) { [weak self] in
            self?.cachedSystemPrompt = (newPrompt, Date(), personaSignature)
            print("💾 [AIContextManager] Cache updated with new prompt and personaSignature: \(String(personaSignature.prefix(16)))...")
        }
        metrics.logCache(event: .miss, reason: .expiredOrPersonaChanged, age: nil)
        return newPrompt
    }

    // 이벤트 기반 캐시 무효화
    public func clearCache(reason: InvalidationReason, caller: String? = nil) {
        print("🗑️ [AIContextManager] Clearing cache - reason: \(reason), caller: \(caller ?? "unknown")")
        queue.async(flags: .barrier) { [weak self] in
            if let cached = self?.cachedSystemPrompt {
                print("🗑️ [AIContextManager] Clearing existing cache with personaHash: \(String(cached.personaHash.prefix(16)))...")
            }
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
