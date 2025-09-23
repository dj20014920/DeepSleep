import CryptoKit
import Foundation

// MARK: - AppleFM 캐시 (KISS/DRY)
// - 단순 키-값 캐시: (sys + user) → response 텍스트
// - TTL: 기본 3600초 (ConfigReader.int("APPLE_FM_CACHE_TTL_SECONDS") 우선)
// - 시간 동기화: SettingsManager.shared.currentDate() 기반으로 만료 관리
// - 저장소: UserDefaults (소량 문자열 캐시에 충분)
// - 동시성: actor로 직렬화 보장
// - 기본 Off: APPLE_FM_RESPONSE_CACHE_ENABLED=false (레거시/긴급 롤백용, 정상 경로에서는 미사용)

public actor AppleFMCache {
    // LEGACY: 응답 텍스트 캐시는 기본 Off입니다. 세션 풀 전환 이후 긴급 롤백용으로만 유지합니다.
    // 플래그: APPLE_FM_RESPONSE_CACHE_ENABLED (기본 false)
    public static let shared = AppleFMCache()
    private static var isEnabled: Bool {
        ConfigReader.bool("APPLE_FM_RESPONSE_CACHE_ENABLED", default: false) ?? false
    }
    private let ud = UserDefaults.standard

    private struct Entry: Codable {
        let key: String
        let content: String
        let savedAt: Date
        let expiryAt: Date
    }

    private let indexKey = "APPLE_FM_CACHE_INDEX"
    private let itemPrefix = "APPLE_FM_CACHE_ITEM_"
    private let maxEntries = 200

    private func ttlSeconds() -> TimeInterval {
        // ConfigReader가 없으면 기본값 사용
        if let t = ConfigReader.int("APPLE_FM_CACHE_TTL_SECONDS") { return TimeInterval(t) }
        return 3600
    }

    private func now() -> Date { SettingsManager.shared.currentDate() }

    private func buildKey(sys: String?, user: String) -> String {
        let sysNorm = (sys ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let userNorm = user.trimmingCharacters(in: .whitespacesAndNewlines)
        let joined = sysNorm + "\u{241F}" + userNorm  // unit separator
        let digest = SHA256.hash(data: joined.data(using: .utf8)!)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public func get(sys: String?, user: String) -> String? {
        // Feature flag: 기본 Off. 플래그가 꺼져 있으면 사용하지 않음.
        guard Self.isEnabled else { return nil }
        // Normalize (sys + user) for cache key to make greeting-only variations hit the same entry.
        let sysNorm = (sys ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let userTrim = user.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Collapse whitespace
        let compact = userTrim.replacingOccurrences(
            of: "\\s+", with: " ", options: .regularExpression
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        // Heuristic: detect greeting-only short inputs across ko/en variants
        let isGreetingOnly: Bool = {
            if compact.count > 24 { return false }
            let patterns = [
                "^안녕(?:하세요|하십니까)?[!?.~…]*$",
                "^하이[!?.~…]*$",
                "^ㅎㅇ[!?.~…]*$",
                "^헬로(?:우)?[!?.~…]*$",
                "^(?:hello|hi|hey|yo|sup)[!?.~…]*$",
                "^좋은\\s*(?:아침|오전|오후|저녁|밤)[!?.~…]*$",
                "^good\\s*(?:morning|afternoon|evening)[!?.~…]*$",
                "^반가(?:워|습니다)[!?.~…]*$",
                "^오랜만(?:이야|이에요|입니다)?[!?.~…]*$",
            ]
            for p in patterns {
                if compact.range(of: p, options: .regularExpression) != nil { return true }
            }
            return false
        }()
        let normUser =
            isGreetingOnly
            ? "__GREETING__"
            : compact
        let key = buildKey(sys: sysNorm, user: normUser)
        return get(byKey: key)
    }

    public func get(byKey key: String) -> String? {
        guard Self.isEnabled else { return nil }
        let itemKey = itemPrefix + key
        guard let data = ud.data(forKey: itemKey),
            let entry = try? JSONDecoder().decode(Entry.self, from: data)
        else {
            removeFromIndex(key)
            return nil
        }
        if entry.expiryAt <= now() {
            // 만료 → 제거
            ud.removeObject(forKey: itemKey)
            removeFromIndex(key)
            return nil
        }
        return entry.content
    }

    public func put(sys: String?, user: String, content: String) {
        // Feature flag: 기본 Off. 플래그가 꺼져 있으면 저장하지 않음.
        guard Self.isEnabled else { return }
        // 동일 정규화 규칙을 적용해 저장 키를 생성 (인사 변형 → __GREETING__)
        let sysNorm = (sys ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let userTrim = user.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let compact =
            userTrim
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let isGreetingOnly: Bool = {
            if compact.count > 24 { return false }
            let patterns = [
                "^안녕(?:하세요|하십니까)?[!?.~…]*$",
                "^하이[!?.~…]*$",
                "^ㅎㅇ[!?.~…]*$",
                "^헬로(?:우)?[!?.~…]*$",
                "^(?:hello|hi|hey|yo|sup)[!?.~…]*$",
                "^좋은\\s*(?:아침|오전|오후|저녁|밤)[!?.~…]*$",
                "^good\\s*(?:morning|afternoon|evening)[!?.~…]*$",
                "^반가(?:워|습니다)[!?.~…]*$",
                "^오랜만(?:이야|이에요|입니다)?[!?.~…]*$",
            ]
            for p in patterns {
                if compact.range(of: p, options: .regularExpression) != nil { return true }
            }
            return false
        }()

        let normUser = isGreetingOnly ? "__GREETING__" : compact
        let key = buildKey(sys: sysNorm, user: normUser)
        put(byKey: key, content: content)
    }

    public func put(byKey key: String, content: String) {
        guard Self.isEnabled else { return }
        let saved = now()
        let entry = Entry(
            key: key, content: content, savedAt: saved,
            expiryAt: saved.addingTimeInterval(ttlSeconds()))
        if let data = try? JSONEncoder().encode(entry) {
            ud.set(data, forKey: itemPrefix + key)
            addToIndex(key)
            trimIfNeeded()
        }
    }

    // MARK: - Index helpers
    private func addToIndex(_ key: String) {
        var arr = (ud.array(forKey: indexKey) as? [String]) ?? []
        if let idx = arr.firstIndex(of: key) { arr.remove(at: idx) }
        arr.append(key)
        ud.set(arr, forKey: indexKey)
    }

    private func removeFromIndex(_ key: String) {
        var arr = (ud.array(forKey: indexKey) as? [String]) ?? []
        if let idx = arr.firstIndex(of: key) {
            arr.remove(at: idx)
            ud.set(arr, forKey: indexKey)
        }
    }

    private func trimIfNeeded() {
        var arr = (ud.array(forKey: indexKey) as? [String]) ?? []
        guard arr.count > maxEntries else { return }
        let overflow = arr.count - maxEntries
        let victims = arr.prefix(overflow)
        for k in victims { ud.removeObject(forKey: itemPrefix + k) }
        arr.removeFirst(overflow)
        ud.set(arr, forKey: indexKey)
    }
}
