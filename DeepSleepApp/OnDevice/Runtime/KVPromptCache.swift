import Foundation
import os.log

/// KVPromptCache
/// - 목적: 동일한 시스템 프롬프트 접두부(prefix)에 대해 llama.cpp의 KV 상태를 메모리에 보관하여
///         이후 요청에서 프롬프트 처리 비용(프리필)과 first token latency(TTI)를 줄이는 경량 캐시.
/// - 설계:
///   1) 완전한 엔진 종속성을 만들지 않기 위해 "세션 저장/복원"은 추상 프로토콜(LlamaSessionIO)로 분리.
///      (엔진 컨텍스트 접근이 가능한 쪽에서 이 프로토콜을 구현해 KV 스냅샷 save/load를 수행)
///   2) 키는 "모델+시스템프롬프트 지문" 조합(예: personaSignatureComponents.composite + modelId)로 구성.
///   3) LRU + TTL 정책으로 관리, 앱 프로세스 메모리 내에서만 유지(디스크 저장 없음).
///   4) DRY/KISS: 캐시 존재 여부/무효화 사유를 중앙에서 판정. 실제 호출부에서는 간단한 두 단계만 수행:
///         - restoreIfPossible(...)
///         - saveIfBeneficial(...)
///
/// 사용 시나리오(권장):
///   - 프롬프트를 '시스템 프롬프트 파트'와 '유저/최근 대화 파트'로 분리 가능한 구조일 때 효과적.
///   - 1) 시스템 프롬프트(템플릿 포함)만 먼저 평가 → KV 저장(saveIfBeneficial)
///     2) 다음 턴에서 동일 키면 restoreIfPossible → 이후 유저/최근 대화 파트만 이어서 평가(접두부 스킵)
///
/// 주의:
///   - 본 캐시는 "메모리 내 임시 최적화"입니다. 앱 재시작 시 사라집니다.
///   - 모델/모드/톤/언어/페르소나/시스템 프롬프트 포맷이 달라지면 키가 달라져 자동 무효화됩니다.
///   - 엔진 세션 크기는 모델/컨텍스트에 따라 수십~수백 MB일 수 있으므로 capacity, TTL을 보수적으로 유지하세요.
public actor KVPromptCache {

    // MARK: Public types

    /// llama.cpp 컨텍스트에 대한 세션 스냅샷 save/load를 제공하는 추상화
    /// - 구현부 예: 내부에서 llama_state_get_size / llama_state_get_data / llama_state_set_data 등을 호출
    public protocol LlamaSessionIO: Sendable {
        /// 현재 컨텍스트의 세션 상태(kv 포함)를 Data로 직렬화
        func saveState() throws -> Data
        /// 주어진 세션 상태를 컨텍스트에 복원
        func loadState(_ data: Data) throws
        /// 시스템 프롬프트만 프리필(토큰화+디코드). 반환: 누적 토큰 수(프리픽스 길이)
        func prefillSystem(_ system: String) throws -> Int
        /// 임의의 접두 텍스트(이미 템플릿으로 직렬화된 recent 3+3 등)를 프리필
        /// - 반환: 누적 토큰 수 증가분(해당 텍스트 토큰 길이)
        func prefillText(_ text: String) throws -> Int
    }

    /// 캐시 엔트리 메타데이터
    public struct Entry: Sendable {
        public let key: String
        public let createdAt: Date
        public internal(set) var lastAccessAt: Date
        public let bytes: Int
        public let nPrefixTokens: Int
        public let version: Int
        public let payload: Data
    }

    /// 복원 시도 결과(상위에서 이유/지표 로그를 남기기 용이하도록 상세 제공)
    public struct RestoreResult: Sendable {
        public let success: Bool
        public let reason: String
        public let entry: Entry?
    }

    /// 저장 시도 결과
    public struct SaveResult: Sendable {
        public let success: Bool
        public let reason: String
        public let entry: Entry?
    }

    // MARK: Singleton

    public static let shared = KVPromptCache()

    // MARK: Configuration (xcconfig 기반, 중앙 관리)

    /// 최대 보관 엔트리 수(LRU). Secrets.xcconfig의 KV_CACHE_CAPACITY 값 사용
    /// - 기본값: 2 (메모리 보호)
    private let capacity: Int = {
        if let v = ConfigReader.int("KV_CACHE_CAPACITY") { return v }
        return 2
    }()

    /// TTL(초). Secrets.xcconfig의 KV_CACHE_TTL_SECONDS 값 사용
    /// - 기본값: 7200 (2시간)
    private let ttl: TimeInterval = {
        if let v = ConfigReader.double("KV_CACHE_TTL_SECONDS") { return v }
        return 7200
    }()

    /// 동일 키에 대해 최소 저장 간격(초). Secrets.xcconfig의 KV_CACHE_MIN_SAVE_INTERVAL 값 사용
    /// - 기본값: 60초 (불필요한 저장 방지)
    private let minSaveIntervalForSameKey: TimeInterval = {
        if let v = ConfigReader.double("KV_CACHE_MIN_SAVE_INTERVAL") { return v }
        return 60
    }()

    // MARK: Storage

    private var store: [String: Entry] = [:]
    private var lru: [String] = []  // 가장 뒤가 가장 최근 사용
    private let log = OSLog(subsystem: "DeepSleep.OnDevice", category: "KVPromptCache")

    // MARK: Keys

    /// 캐시 키 구성 도우미
    /// - 추천: personaSignatureComponents.composite + ":" + modelId.rawValue
    public static func makeKey(model: String, personaCompositeHash: String) -> String {
        return "\(model)#\(personaCompositeHash)"
    }

    // MARK: Public API

    /// 캐시 적합성 판단(상위 레이어에서 미리 HIT 가능성만 보고 싶을 때 사용)
    public func hasValidEntry(for key: String, now: Date = Date()) -> Bool {
        purgeExpired(now: now)
        guard let e = store[key] else { return false }
        return now.timeIntervalSince(e.createdAt) < ttl
    }

    /// KV 복원 시도: 캐시 히트 + TTL 통과 시 엔진에 로드
    /// - Returns: RestoreResult(success/reason/entry)
    public func restoreIfPossible(for key: String, using io: LlamaSessionIO, now: Date = Date())
        -> RestoreResult
    {
        purgeExpired(now: now)

        guard var entry = store[key] else {
            os_log("🪣 [KVCache] MISS - no entry for %{public}@", log: log, type: .info, key)
            return RestoreResult(success: false, reason: "miss:not_found", entry: nil)
        }
        if now.timeIntervalSince(entry.createdAt) >= ttl {
            // TTL 만료 → 제거
            os_log("⌛️ [KVCache] EXPIRED - removing %{public}@", log: log, type: .info, key)
            remove(key)
            return RestoreResult(success: false, reason: "miss:expired", entry: nil)
        }

        do {
            try io.loadState(entry.payload)
            // LRU 갱신
            entry.lastAccessAt = now
            store[key] = entry
            touch(key)
            os_log(
                "✅ [KVCache] RESTORE OK (bytes=%{public}d, tokens=%{public}d) %{public}@",
                log: log, type: .info, entry.bytes, entry.nPrefixTokens, key)
            return RestoreResult(success: true, reason: "hit:restored", entry: entry)
        } catch {
            os_log(
                "❌ [KVCache] RESTORE FAIL %{public}@ error=%{public}@",
                log: log, type: .error, key, String(describing: error))
            // 복원 실패 시 해당 엔트리는 삭제(오염방지)
            remove(key)
            return RestoreResult(success: false, reason: "miss:restore_failed", entry: nil)
        }
    }

    /// KV 저장 시도: 현재 엔진 세션 상태를 스냅샷하여 LRU에 보관
    /// - nPrefixTokens: 저장한 접두부 토큰 수(옵션, 추후 로깅/디버깅에 도움)
    /// - version: 상태 포맷 버전(동일 엔진/모델 조합에서만 복원되도록 상위에서 구분자 역할 가능)
    public func saveIfBeneficial(
        for key: String,
        using io: LlamaSessionIO,
        nPrefixTokens: Int,
        version: Int = 1,
        now: Date = Date()
    ) -> SaveResult {

        // 동일 키에 대한 과도한 저장 제한
        if let existing = store[key],
            now.timeIntervalSince(existing.lastAccessAt) < minSaveIntervalForSameKey
        {
            os_log("⏸️ [KVCache] SAVE SKIPPED (cooldown) %{public}@", log: log, type: .info, key)
            return SaveResult(success: false, reason: "skip:cooldown", entry: existing)
        }

        // 스냅샷 추출
        let data: Data
        do {
            data = try io.saveState()
        } catch {
            os_log(
                "❌ [KVCache] SAVE FAIL %{public}@ error=%{public}@",
                log: log, type: .error, key, String(describing: error))
            return SaveResult(success: false, reason: "error:save_state_failed", entry: nil)
        }

        // LRU/TTL 고려하여 삽입
        let entry = Entry(
            key: key,
            createdAt: now,
            lastAccessAt: now,
            bytes: data.count,
            nPrefixTokens: max(0, nPrefixTokens),
            version: version,
            payload: data
        )
        insert(entry)
        os_log(
            "💾 [KVCache] SAVED (bytes=%{public}d, tokens=%{public}d) %{public}@",
            log: log, type: .info, entry.bytes, entry.nPrefixTokens, key)
        return SaveResult(success: true, reason: "saved", entry: entry)
    }

    /// 현재 캐시 상태 요약(디버깅/텔레메트리)
    public func debugSnapshot() -> String {
        let now = Date()
        purgeExpired(now: now)
        let items = lru.reversed().compactMap { store[$0] }
        let lines = items.map { e in
            let age = Int(now.timeIntervalSince(e.createdAt))
            return
                "- key:\(e.key.prefix(18))… bytes:\(e.bytes) tokens:\(e.nPrefixTokens) age:\(age)s"
        }
        return """
            KVPromptCache(capacity:\(capacity) ttl:\(Int(ttl))s size:\(store.count))
            \(lines.joined(separator: "\n"))
            """
    }

    // MARK: Internal LRU helpers

    /// 새 엔트리 삽입 및 LRU 정책 적용
    /// - 용량 초과 시 가장 오래된 항목부터 자동 제거
    private func insert(_ entry: Entry) {
        // 1. 신규 엔트리 저장
        store[entry.key] = entry
        touch(entry.key)

        // 2. 용량 초과 체크 및 자동 제거 (LRU 정책)
        // ⚠️ 중요: store.count가 아닌 lru.count를 사용해야 정확
        while store.count > capacity {
            if let oldKey = lru.first {
                os_log(
                    "🗑️ [KVCache] EVICT (capacity=%{public}d) key=%{public}@", 
                    log: log, type: .info, capacity, oldKey
                )
                remove(oldKey)
            } else {
                // lru 리스트가 비어있는데 store에 데이터가 있는 경우 (비정상)
                // 모든 항목 강제 정리
                os_log("⚠️ [KVCache] LRU 불일치 감지 - 전체 정리", log: log, type: .error)
                store.removeAll()
                lru.removeAll()
                break
            }
        }
        
        #if DEBUG
        // 디버그: LRU 상태 일관성 체크
        if store.count != lru.count {
            os_log(
                "⚠️ [KVCache] 불일치: store.count=%{public}d lru.count=%{public}d",
                log: log, type: .error, store.count, lru.count
            )
        }
        #endif
    }

    private func touch(_ key: String) {
        if let idx = lru.firstIndex(of: key) {
            lru.remove(at: idx)
        }
        lru.append(key)
    }

    private func remove(_ key: String) {
        store.removeValue(forKey: key)
        if let idx = lru.firstIndex(of: key) {
            lru.remove(at: idx)
        }
    }

    private func purgeExpired(now: Date) {
        var removed: [String] = []
        for (k, v) in store {
            if now.timeIntervalSince(v.createdAt) >= ttl {
                removed.append(k)
            }
        }
        guard !removed.isEmpty else { return }
        for k in removed {
            os_log("🧹 [KVCache] PURGE EXPIRED %{public}@", log: log, type: .info, k)
            remove(k)
        }
    }
}

// MARK: - Integration helpers (non-invasive)

// 상위 코드에서 의존성 없는 형태로 사용할 수 있도록 간단한 보조 구조체/유틸 제공
public enum KVPromptKeyBuilder {
    /// UnifiedAIServiceImpl/AIContextSignature/OnDeviceModelID 등 외부 타입 의존 없이 키 생성
    public static func from(
        modelRaw: String,
        personaCompositeHash: String
    ) -> String {
        KVPromptCache.makeKey(model: modelRaw, personaCompositeHash: personaCompositeHash)
    }
}

/// 통계/메트릭 훅(선택사항): 기존 프로젝트의 ContextMetrics가 있다면 여기에 연결해 사용할 수 있음.
/// 사용 예:
///   KVMetricsHook.shared.onRestore(result)
///   KVMetricsHook.shared.onSave(result)
public final class KVMetricsHook {
    public static let shared = KVMetricsHook()

    public var onRestore: @Sendable (KVPromptCache.RestoreResult) -> Void = { _ in }
    public var onSave: @Sendable (KVPromptCache.SaveResult) -> Void = { _ in }

    private init() {}
}

// MARK: - Example usage (Doc only)
/*
    // 1) 프롬프트 키 구성
    //    let components = UserRulesManager.shared.personaSignatureComponents(...)
    //    let key = KVPromptKeyBuilder.from(modelRaw: modelId.rawValue, personaCompositeHash: components.composite)

    // 2) 시스템 프롬프트만 먼저 평가 → saveIfBeneficial
    //    (엔진 바인딩에서 시스템 프롬프트만 토크나이즈/디코드하고, 해당 시점의 컨텍스트를 save)
    //    let saveRes = await KVPromptCache.shared.saveIfBeneficial(for: key, using: io, nPrefixTokens: sysTokCount)
    //    KVMetricsHook.shared.onSave(saveRes)

    // 3) 다음 턴: 동일 키면 restoreIfPossible → 유저/최근 대화만 이어서 디코드
    //    let restoreRes = await KVPromptCache.shared.restoreIfPossible(for: key, using: io)
    //    KVMetricsHook.shared.onRestore(restoreRes)
    //    if restoreRes.success {
    //       // 이후 유저 입력만 이어서 디코드 (시스템 프롬프트 재디코드 불필요)
    //    } else {
    //       // 평상시 경로로 전체 프롬프트 디코드
    //    }

    // 참고:
    //  - 위 로직은 OnDeviceAdapter/LlamaModelLoader에 소량의 코드만 추가하여 쉽게 통합 가능
    //  - 본 파일은 캐시/세션 상태 관리만 책임(단일 책임 원칙). 엔진 세부(C API 호출)는 LlamaSessionIO 구현부가 책임.
*/
