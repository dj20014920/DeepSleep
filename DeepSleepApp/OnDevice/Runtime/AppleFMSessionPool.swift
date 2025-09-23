import CryptoKit
import Foundation
import OSLog

#if canImport(FoundationModels)
    import FoundationModels
#endif

/// AppleFMSessionPool.swift
/// - 목적: Apple Foundation Models(LanguageModelSession) 세션을 재사용해 TTI/지연을 줄임
/// - 정책:
///   - TTL 기본: 10800s(3시간) [오버라이드: APPLE_FM_SESSION_TTL_SECONDS 또는 CACHE_TTL_SECONDS_DEFAULT]
///   - 동시 세션 상한: 기본 16 [오버라이드: APPLE_FM_SESSION_MAX_COUNT]
///   - 메모리 상한(64MB)/디스크 상한(100MB)은 범용 정책 참고. 본 풀은 메모리 전용이며 디스크 직렬화 없음
///   - Feature Flags:
///       APPLE_FM_SESSION_POOL_ENABLED (기본 true)
/// - 키: personaCoreHash + mode + model + tone(옵션) + systemPromptDigest
///
/// 사용 예:
///   if AppleFMSessionPool.isEnabled {
///       let key = AppleFMSessionPool.buildKey(
///           personaCoreHash: "...",
///           mode: .generalConversation,
///           model: .onDevice,
///           tone: "friendly",
///           systemPrompt: "You are ..."
///       )
///       if #available(iOS 26.0, *), AppleFMAdapter.isAvailable {
///           let session = try await AppleFMSessionPool.shared.acquire(key: key, instructions: "You are ...")
///           let text = try await session.respond(to: "안녕!")
///       }
///   }
///
/// 주의:
/// - 세션은 엔진 상태를 포함하므로 동일 컨텍스트(동일 키)에서만 재사용해야 합니다.
/// - 모델/페르소나/톤/모드/시스템 프롬프트 변경 시 해당 키를 무효화하세요.
public enum AppleFMSessionPool {

    private static let log = Logger(subsystem: "DeepSleep.AppleFM", category: "SessionPool")

    // MARK: - SSOT 설정 로딩

    private static func cfgBool(_ key: String, default def: Bool) -> Bool {
        ConfigReader.bool(key, default: def) ?? def
    }

    private static func cfgInt(_ key: String) -> Int? {
        ConfigReader.int(key)
    }

    /// 풀 사용 가능 플래그 (기본 On)
    public static var isEnabled: Bool {
        cfgBool("APPLE_FM_SESSION_POOL_ENABLED", default: true)
    }

    /// TTL(초). 우선순위: APPLE_FM_SESSION_TTL_SECONDS → CACHE_TTL_SECONDS_DEFAULT → 10800
    private static var ttlSeconds: TimeInterval {
        if let v = cfgInt("APPLE_FM_SESSION_TTL_SECONDS"), v > 0 { return TimeInterval(v) }
        if let v = cfgInt("CACHE_TTL_SECONDS_DEFAULT"), v > 0 { return TimeInterval(v) }
        return 10800
    }

    /// 동시 세션 상한. 기본 16
    private static var maxSessions: Int {
        if let v = cfgInt("APPLE_FM_SESSION_MAX_COUNT"), v > 0 { return v }
        return 16
    }

    /// 현재 기준 시간 (시계 동기화를 위해 SettingsManager 경유)
    private static func now() -> Date {
        SettingsManager.shared.currentDate()
    }

    // MARK: - 키 설계

    /// 시스템 프롬프트 다이제스트(SHA256 hex)
    public static func digestSystemPrompt(_ sys: String?) -> String {
        let s = (sys ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = s.data(using: .utf8) else { return "0" }
        let d = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return d.isEmpty ? "0" : d
    }

    /// 풀 키 생성기
    /// - personaCoreHash: 모델과 무관한 핵심 페르소나 해시(SSOT: UserRulesManager.personaCoreSignature())
    /// - mode: AIMode.rawValue
    /// - model: AIModel.rawValue
    /// - tone: 선택적 톤 식별자(없으면 "-")
    /// - systemPrompt: 시스템 프롬프트 원문(해시로 축약)
    public static func buildKey(
        personaCoreHash: String, mode: AIMode, model: AIModel, tone: String?, systemPrompt: String?
    ) -> String {
        let toneKey =
            (tone?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? tone!.trimmingCharacters(in: .whitespacesAndNewlines) : "-"
        let sysDig = digestSystemPrompt(systemPrompt)
        return "\(personaCoreHash)#\(mode.rawValue)#\(model.rawValue)#\(toneKey)#\(sysDig)"
    }

    // MARK: - 내부 저장소/엔트리

    #if canImport(FoundationModels)
        @available(iOS 26.0, *)
        private struct Entry {
            let session: LanguageModelSession
            var createdAt: Date
            var lastAccess: Date
        }
    #else
        // iOS <26 또는 FoundationModels 미지원 환경용 더미 타입으로 컴파일 경로 정리
        private struct Entry {}
    #endif

    // MARK: - 싱글톤

    public static let shared = AppleFMSessionPoolActor()

    // 본체는 actor로 구현하여 직렬화를 보장
    public actor AppleFMSessionPoolActor {

        // LRU 맵/순서
        #if canImport(FoundationModels)
            // iOS 26 미만에서도 컴파일 가능하도록 타입 정보를 Any로 저장하고,
            // iOS 26 가드 내부에서만 구체 타입으로 캐스팅해 사용한다.
            private var map: [String: Any] = [:] // value: Entry (iOS 26+)
            // 최신 사용을 끝에 두는 LRU 리스트
            private var lru: [String] = []
            // 동시 초기화 중복 방지용: 동일 키의 초기화를 하나로 합침
            private var inflight: [String: Any] = [:] // value: Task<LanguageModelSession, Error> (iOS 26+)
        #endif

        // 메트릭
        private var totalHits: Int = 0
        private var totalMisses: Int = 0
        private var totalEvictions: Int = 0
        private var totalExpirations: Int = 0

        public init() {}

        // MARK: - 유틸

        private func ageString(from since: Date) -> String {
            let age = AppleFMSessionPool.now().timeIntervalSince(since)
            if age < 1 { return String(format: "%.0fms", age * 1000) }
            return String(format: "%.1fs", age)
        }

        // MARK: - 공용 API

        /// 세션 획득(없으면 생성). 동일 키 경쟁에서 단 1회만 초기화.
        /// - Parameters:
        ///   - key: AppleFMSessionPool.buildKey(...)로 생성된 키
        ///   - instructions: 시스템 프롬프트(세션 초기화 시에만 사용)
        /// - Returns: LanguageModelSession (iOS 26+에서만 유효)
        @available(iOS 26.0, *)
        @discardableResult
        public func acquire(key: String, instructions: String?) async throws
            -> LanguageModelSession
        {
            // 풀 비활성: 매 획득 시 새 세션(백도어/롤백용)
            if !AppleFMSessionPool.isEnabled {
                let trimmed = (instructions ?? "").trimmingCharacters(
                    in: .whitespacesAndNewlines)
                let session: LanguageModelSession =
                    trimmed.isEmpty
                    ? LanguageModelSession() : LanguageModelSession(instructions: trimmed)
                AppleFMSessionPool.log.info(
                    "🍎 AFM session ACQUIRE (pool disabled) key=\(key, privacy: .public)")
                return session
            }

            // TTL/만료/히트 확인
            evictExpiredIfNeeded()

            if var e = map[key] as? Entry {
                // 유효한 히트
                totalHits += 1
                e.lastAccess = AppleFMSessionPool.now()
                map[key] = e
                touchLRU(key)
                let age = ageString(from: e.createdAt)
                AppleFMSessionPool.log.info(
                    "🍎 AFM session ACQUIRE (hit) key=\(key, privacy: .public) age=\(age, privacy: .public)"
                )
                return e.session
            }

            // 초기화 경쟁 병합
            if let task = inflight[key] as? Task<LanguageModelSession, Error> {
                totalMisses += 1  // miss 로 집계 (대기 편입)
                let _ = try await task.value
                if let e = map[key] as? Entry {
                    let age = ageString(from: e.createdAt)
                    AppleFMSessionPool.log.info(
                        "🍎 AFM session ACQUIRE (join-inflight) key=\(key, privacy: .public) age=\(age, privacy: .public)"
                    )
                    return e.session
                }
                // 드문 케이스: insert 전 취소된 경우 → 재시도
                return try await acquire(key: key, instructions: instructions)
            }

            // 새로 생성
            totalMisses += 1
            let createTask = Task<LanguageModelSession, Error> {
                let trimmed = (instructions ?? "").trimmingCharacters(
                    in: .whitespacesAndNewlines)
                let s: LanguageModelSession =
                    trimmed.isEmpty
                    ? LanguageModelSession() : LanguageModelSession(instructions: trimmed)
                return s
            }
            inflight[key] = createTask
            do {
                let session = try await createTask.value
                inflight.removeValue(forKey: key)
                let now = AppleFMSessionPool.now()
                let entry = Entry(session: session, createdAt: now, lastAccess: now)
                map[key] = entry
                touchLRU(key)
                AppleFMSessionPool.log.info(
                    "🍎 AFM session ACQUIRE (miss→create) key=\(key, privacy: .public)")
                trimIfNeeded()
                return session
            } catch {
                inflight.removeValue(forKey: key)
                AppleFMSessionPool.log.error(
                    "🍎 AFM session CREATE FAILED key=\(key, privacy: .public) err=\(String(describing: error), privacy: .public)"
                )
                throw error
            }
        }

        /// 세션 키 무효화(단일)
        public func invalidate(key: String, reason: String = "manual") {
            #if canImport(FoundationModels)
                if #available(iOS 26.0, *) {
                    if let _ = map.removeValue(forKey: key) as? Entry {
                        removeFromLRU(key)
                        totalEvictions += 1
                        AppleFMSessionPool.log.info(
                            "🍎 AFM session EVICT key=\(key, privacy: .public) reason=\(reason, privacy: .public)"
                        )
                    }
                    if let t = inflight.removeValue(forKey: key) as? Task<LanguageModelSession, Error> {
                        t.cancel()
                    }
                }
            #endif
        }

        /// 전체 무효화(모델/환경 대변경 시)
        public func invalidateAll(reason: String = "clearAll") {
            #if canImport(FoundationModels)
                if #available(iOS 26.0, *) {
                    map.removeAll(keepingCapacity: false)
                    lru.removeAll(keepingCapacity: false)
                    inflight.values.forEach { (t) in
                        (t as? Task<LanguageModelSession, Error>)?.cancel()
                    }
                    inflight.removeAll(keepingCapacity: false)
                    AppleFMSessionPool.log.info(
                        "🍎 AFM session CLEAR_ALL reason=\(reason, privacy: .public)")
                }
            #endif
        }

        /// 간단 통계 스냅샷
        public func stats() -> [String: Any] {
            #if canImport(FoundationModels)
                if #available(iOS 26.0, *) {
                    return [
                        "enabled": AppleFMSessionPool.isEnabled,
                        "count": map.count,
                        "ttlSeconds": AppleFMSessionPool.ttlSeconds,
                        "maxSessions": AppleFMSessionPool.maxSessions,
                        "hits": totalHits,
                        "misses": totalMisses,
                        "evictions": totalEvictions,
                        "expirations": totalExpirations,
                    ]
                }
            #endif
            return [
                "enabled": AppleFMSessionPool.isEnabled,
                "count": 0,
                "ttlSeconds": AppleFMSessionPool.ttlSeconds,
                "maxSessions": AppleFMSessionPool.maxSessions,
                "hits": totalHits,
                "misses": totalMisses,
                "evictions": totalEvictions,
                "expirations": totalExpirations,
            ]
        }

        // MARK: - 내부: LRU / TTL

        #if canImport(FoundationModels)
            @available(iOS 26.0, *)
            private func touchLRU(_ key: String) {
                if let idx = lru.firstIndex(of: key) { lru.remove(at: idx) }
                lru.append(key)
            }

            @available(iOS 26.0, *)
            private func removeFromLRU(_ key: String) {
                if let idx = lru.firstIndex(of: key) {
                    lru.remove(at: idx)
                }
            }

            @available(iOS 26.0, *)
            private func evictExpiredIfNeeded() {
                guard !map.isEmpty else { return }
                let now = AppleFMSessionPool.now()
                let ttl = AppleFMSessionPool.ttlSeconds
                var expiredKeys: [String] = []
                for (k, v) in map {
                    if let e = v as? Entry, now.timeIntervalSince(e.lastAccess) >= ttl {
                        expiredKeys.append(k)
                    }
                }
                for k in expiredKeys {
                    map.removeValue(forKey: k)
                    removeFromLRU(k)
                    totalExpirations += 1
                    AppleFMSessionPool.log.info("🍎 AFM session EXPIRE key=\(k, privacy: .public)")
                }
            }

            @available(iOS 26.0, *)
            private func trimIfNeeded() {
                let limit = AppleFMSessionPool.maxSessions
                guard limit > 0 else { return }
                while map.count > limit, let victim = lru.first {
                    map.removeValue(forKey: victim)
                    lru.removeFirst()
                    totalEvictions += 1
                    AppleFMSessionPool.log.info(
                        "🍎 AFM session EVICT key=\(victim, privacy: .public) reason=LRU")
                }
            }
        #endif
    }
}
