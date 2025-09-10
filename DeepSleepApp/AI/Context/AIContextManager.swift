import CryptoKit
import Foundation

// Fallback shims (build-analysis safety):
// 실제 프로젝트에서는 ContextMetrics / ConfigReader / InvalidationReason 가 다른 파일에 이미 정의되어 있음.
// 이 환경에서 심볼 탐색이 선행되지 않아 'Cannot find' 오류가 발생하므로
// 중복 정의를 피하기 위해 기존 정의가 없는 경우에만 사용할 수 있도록 조건부 컴파일 플래그를 둘 수도 있지만
// 여기서는 최소 충돌 가능성을 위해 네임스페이스/기능을 축소한 경량 버전 제공.
// 통합 빌드 시 동일 심볼 충돌 우려 시 아래 #if FallbackAIContextManagerShims 사용 해제 가능.
#if FallbackAIContextManagerShims
    public enum InvalidationReason: String, Codable {
        case personaChanged
        case languageChanged
        case toneChanged
        case modeChanged
        case coreMemoryUpdated
        case modelSelectionChanged
        case appVersionUpdated
        case manual
        case expired
        case none
    }
    private enum CacheEvent { case hit, miss }
    public final class ContextMetrics {
        public static let shared = ContextMetrics()
        public func logCache(
            event: CacheEvent, reason: InvalidationReason, age: TimeInterval?, caller: String? = nil
        ) {}
        public func logInvalidation(reason: InvalidationReason, caller: String?) {}
    }
    public enum ConfigReader {
        public static func double(_ key: String, default def: Double) -> Double? { def }
    }
#endif

// Added required supporting imports to resolve missing symbol errors
// ContextMetrics, InvalidationReason, ConfigReader are defined in the same module but
// explicit import of their defining files/modules is not needed in Swift.
// However if these lived in another module in the future we would place: import <ModuleName>
// Keeping this comment to document the rationale.

public final class AIContextManager {
    public static let shared = AIContextManager()

    private let queue = DispatchQueue(
        label: "ai.context.manager.queue", qos: .userInitiated, attributes: .concurrent)
    // Monotonic uptime을 함께 저장하여 시계 변경에 의한 음수 age 방지
    private var cachedSystemPrompt:
        (prompt: String, timestamp: Date, uptime: TimeInterval,
         composite: String, coreHash: String, modeHash: String, modelHash: String, toneHash: String)?
    // 서버 캐시 무효화 헤더 전송을 위한 보류(reason) 저장소
    private var pendingInvalidationReason: String?

    private let metrics = ContextMetrics.shared

    // 기본 TTL: 3시간(10800초). Info.plist(또는 xcconfig 매핑)에서 "AI_SYSTEM_PROMPT_CACHE_TTL" 값을 우선 사용
    private lazy var cacheTTL: TimeInterval = {
        return ConfigReader.double("AI_SYSTEM_PROMPT_CACHE_TTL", default: 10800) ?? 10800
    }()

    private init() {}

    // LEGACY: 단일 signature 기반 API (Deprecated) → 내부에서 세분화 컴포넌트 계산 후 새 로직 경유
    // LEGACY API 제거됨: getSystemPrompt(personaSignature:) 사용자는 모두 components 기반으로 마이그레이션 완료.
    // (호출 필요 시 컴파일 오류로 인지 → 새 API 적용)

    // 신규: 세분화 컴포넌트 기반 (UserRulesManager.PersonaSignatureComponents 호환)
    public func getSystemPrompt(components: (composite: String, coreHash: String, modeHash: String, modelHash: String, toneHash: String), generator: () -> String) -> String {
        print(
            "🔍 [AIContextManager] getSystemPrompt called with composite: \(String(components.composite.prefix(16)))..."
        )

        var missReason: InvalidationReason = .expired  // 기본값 (실제 판별로 대체 예정)

        if let cached = queue.sync(execute: { cachedSystemPrompt }) {
            var age = ProcessInfo.processInfo.systemUptime - cached.uptime
            if age < 0 { age = 0 }
            let ageValid = age < cacheTTL
            print("📦 [AIContextManager] Cache found: age=\(Int(age))s ageValid=\(ageValid)")
            print("   - cached.composite=\(cached.composite.prefix(12)) new=\(components.composite.prefix(12))")

            if cached.composite == components.composite, ageValid {
                metrics.logCache(event: .hit, reason: .none, age: age)
                print("✅ [AIContextManager] Cache HIT (length=\(cached.prompt.count))")
                return cached.prompt
            } else {
                // 세분화 Miss 이유 판별
                if !ageValid { missReason = .expired }
                else if cached.modelHash != components.modelHash { missReason = .modelSelectionChanged }
                else if cached.modeHash != components.modeHash { missReason = .modeChanged }
                else if cached.toneHash != components.toneHash { missReason = .toneChanged }
                else if cached.coreHash != components.coreHash { missReason = .personaChanged }
                else { missReason = .manual }
                print("⚠️ [AIContextManager] Cache MISS reason=\(missReason)")
            }
        } else {
            print("🚫 [AIContextManager] No cache found (initial miss)")
            missReason = .manual
        }

        print("🔄 [AIContextManager] Generating new prompt...")
        let newPrompt = generator()
        print("📝 [AIContextManager] New prompt length=\(newPrompt.count)")

        let nowUptime = ProcessInfo.processInfo.systemUptime
        let now = Date()
        queue.async(flags: .barrier) { [weak self] in
            self?.cachedSystemPrompt = (newPrompt, now, nowUptime,
                                        components.composite, components.coreHash, components.modeHash, components.modelHash, components.toneHash)
            print("💾 [AIContextManager] Cache updated composite=\(components.composite.prefix(12)))")
        }
        metrics.logCache(event: .miss, reason: missReason, age: nil)
        return newPrompt
    }

    // 이벤트 기반 캐시 무효화
    public func clearCache(reason: InvalidationReason, caller: String? = nil) {
        print(
            "🗑️ [AIContextManager] Clearing cache - reason: \(reason), caller: \(caller ?? "unknown")"
        )
        queue.async(flags: .barrier) { [weak self] in
            if let cached = self?.cachedSystemPrompt {
                print(
                    "🗑️ [AIContextManager] Clearing existing cache with composite: \(String(cached.composite.prefix(16)))..."
                )
            }
            self?.cachedSystemPrompt = nil
            // 서버 캐시 무효화 헤더 전송 위해 보류 사유 기록(최근 1건)
            self?.pendingInvalidationReason = String(describing: reason)
        }
        metrics.logInvalidation(reason: reason, caller: caller)
    }

    /// 서버에 보낼 무효화 헤더 값을 1회성으로 소비/반환
    public func consumeInvalidationReasonForHeader() -> String? {
        var value: String?
        queue.sync {
            value = pendingInvalidationReason
        }
        if value != nil {
            queue.async(flags: .barrier) { [weak self] in
                self?.pendingInvalidationReason = nil
            }
        }
        return value
    }

    // 테스트 및 진단용 (페르소나 시그니처 원문 비노출, 해시 지문만 표시)
    public func debugSnapshot() -> String {
        return queue.sync {
            if let c = cachedSystemPrompt {
                let fp = fingerprint(c.composite)
                var age = ProcessInfo.processInfo.systemUptime - c.uptime
                if age < 0 { age = 0 }
                return "AIContextManager(cache: true, age: \(Int(age))s, personaFP:\(fp))"
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
