//
//  UsageLimitManager.swift
//  DeepSleep
//
//  Created by Claude on 2025-07-23.
//  Copyright © 2025 DeepSleep. All rights reserved.
//

import Foundation

extension Notification.Name {
    public static let aiUsageLimitWarning = Notification.Name("aiUsageLimitWarning")
    public static let aiUsageLimitReached = Notification.Name("aiUsageLimitReached")
}

/// 🛡️ AI 사용량 제한 관리자 (Secrets.xcconfig 연동)
///
/// **목적**: 모든 AI 기능의 일일 사용량을 중앙에서 관리하여 API 비용 제어
/// **데이터 소스**: Secrets.xcconfig의 AI_LIMITS_*_{FREE,PRO,MAX} 설정값들(SSOT)
/// **저장소**: UserDefaults (앱 재설치 시 초기화)
///
/// PERF-WARNING: 사용량 체크 시 UserDefaults 동기 I/O 발생
/// - 테스트 방법: Instruments Time Profiler로 체크 메서드 성능 측정
/// - 최적화 방안: 메모리 캐시 활용으로 디스크 접근 최소화
public class UsageLimitManager {

    // MARK: - 싱글톤
    public static let shared = UsageLimitManager()
    private init() {
        // 지연 로딩으로 변경: 초기화 시 번들 접근을 하지 않음 (안정성/디버깅 개선)
        // 제한값은 resolvedDailyLimit 호출 시 필요한 키만 즉시 조회합니다.
        startDailyResetTimer()
    }

    // MARK: - 프로퍼티

    /// 메모리 캐시된 제한값들 (성능 최적화)
    private var cachedLimits: [String: Int] = [:]

    /// 오늘 날짜 (일일 초기화 판단용)
    private var currentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    /// UserDefaults 키 접두사
    private let usageKeyPrefix = "ai_usage_"
    private let lastResetDateKey = "ai_usage_last_reset_date"
    private let dailyCountPrefix = "daily_key_count_"  // daily_key_count_<key>_<yyyy-MM-dd>
    private let dailyFPsPrefix = "daily_key_fps_"  // daily_key_fps_<namespace>_<yyyy-MM-dd>

    // MARK: - 📊 사용량 제한 체크 (메인 API)

    /// AI 기능 사용 가능 여부 체크
    /// - Parameter mode: AI 모드
    /// - Returns: (사용가능여부, 현재사용량, 일일제한량)
    public func canUseAIFeature(_ mode: AIMode) -> (
        canUse: Bool, currentUsage: Int, dailyLimit: Int
    ) {
        checkAndResetIfNewDay()

        // 디버그: 프리셋 추천 무제한 모드(디버깅용 일시 해제)
        if DebugFlags.unlimitedPresetRecommendation {
            let currentUsage = getCurrentUsage(for: mode)
            if mode == .presetRecommendation {
                #if DEBUG
                    print(
                        "🧪 [UsageLimitManager] DEBUG 무제한 프리셋 추천 활성화: \(currentUsage)/∞ (사용가능: true)"
                    )
                #endif
                return (true, currentUsage, Int.max)
            }
        }

        let dailyLimit = resolvedDailyLimit(for: mode)
        let currentUsage = getCurrentUsage(for: mode)
        let canUse = currentUsage < dailyLimit

        #if DEBUG
        if DebugFlags.internalUsageVerbose {
            print("🛡️ [UsageLimitManager] (internal) \(mode.displayName): \(currentUsage)/\(dailyLimit) canUse=\(canUse)")
        }
        #endif

        return (canUse: canUse, currentUsage: currentUsage, dailyLimit: dailyLimit)
    }

    /// AI 기능 사용량 증가 (호출 성공 시 호출)
    /// - Parameter mode: AI 모드
    public func incrementUsage(for mode: AIMode) {
        checkAndResetIfNewDay()

        let usageKey = getUsageKeyForMode(mode)
        let currentUsage = UserDefaults.standard.integer(forKey: usageKey)
        let newUsage = currentUsage + 1
        UserDefaults.standard.set(newUsage, forKey: usageKey)

        notifyIfThresholdReached(mode: mode, currentUsage: newUsage)
    }

    /// 전체 AI 사용량 현황 조회 (설정 화면용)
    /// - Returns: [AIMode: (현재사용량, 일일제한량)] 딕셔너리
    public func getAllUsageStatus() -> [AIMode: (currentUsage: Int, dailyLimit: Int)] {
        checkAndResetIfNewDay()

        var status: [AIMode: (currentUsage: Int, dailyLimit: Int)] = [:]

        for mode in AIMode.allCases {
            let dailyLimit = resolvedDailyLimit(for: mode)
            let currentUsage = getCurrentUsage(for: mode)
            status[mode] = (currentUsage: currentUsage, dailyLimit: dailyLimit)
        }

        return status
    }

    // MARK: - 🔑 일일 키 기반 제한(커스텀 기능용)
    public func canUseDailyKeyedFeature(key: String, limit: Int) -> (
        canUse: Bool, remaining: Int, resetAt: Date
    ) {
        checkAndResetIfNewDay()
        let countKey = dailyCountPrefix + key + "_" + currentDate
        let used = UserDefaults.standard.integer(forKey: countKey)
        let can = used < max(0, limit)
        let remaining = max(0, limit - used)
        let resetAt = nextDailyResetAt()
        return (can, remaining, resetAt)
    }

    public func incrementDailyKeyedFeature(key: String) {
        checkAndResetIfNewDay()
        let countKey = dailyCountPrefix + key + "_" + currentDate
        let used = UserDefaults.standard.integer(forKey: countKey)
        UserDefaults.standard.set(used + 1, forKey: countKey)
    }

    public func hasUsedDailyFingerprint(namespace: String, fingerprint: String) -> Bool {
        checkAndResetIfNewDay()
        let k = dailyFPsPrefix + namespace + "_" + currentDate
        let arr = UserDefaults.standard.stringArray(forKey: k) ?? []
        return arr.contains(fingerprint)
    }

    public func markDailyFingerprintUsed(namespace: String, fingerprint: String) {
        checkAndResetIfNewDay()
        let k = dailyFPsPrefix + namespace + "_" + currentDate
        var arr = UserDefaults.standard.stringArray(forKey: k) ?? []
        if !arr.contains(fingerprint) {
            arr.append(fingerprint)
            UserDefaults.standard.set(arr, forKey: k)
        }
    }

    // MARK: - 🔧 내부 구현

    /// Bundle에서 Secrets.xcconfig의 제한값 로드(초기 스냅샷)
    @discardableResult
    private func loadLimitsFromBundle() -> [String: Int] {
        // Info.plist에 매핑된 키에서 안전하게 로드 (Secrets.xcconfig -> Info.plist -> Bundle)
        var loaded: [String: Int] = [:]
        let keys = [
            // SSOT 키(Secrets.xcconfig → Info.plist)
            "AI_LIMITS_CHAT",
            "AI_LIMITS_CHAT_PRO",
            "AI_LIMITS_CHAT_MAX",
            "AI_LIMITS_PRESET_RECOMMENDATION",
            "AI_LIMITS_PRESET_RECOMMENDATION_FREE",
            "AI_LIMITS_PRESET_RECOMMENDATION_PRO",
            "AI_LIMITS_PRESET_RECOMMENDATION_MAX",
            "AI_LIMITS_DIARY_ANALYSIS",
            "AI_LIMITS_DIARY_ANALYSIS_FREE",
            "AI_LIMITS_DIARY_ANALYSIS_PRO",
            "AI_LIMITS_DIARY_ANALYSIS_MAX",
            "AI_LIMITS_MONTHLY_STATISTICS",
            "AI_LIMITS_TODO_ADVICE",
            "AI_LIMITS_TODO_ADVICE_FREE",
            "AI_LIMITS_TODO_ADVICE_PRO",
            "AI_LIMITS_TODO_ADVICE_PREMIUM", // 호환
            "AI_LIMITS_TODO_ADVICE_MAX",
            "AI_LIMITS_TODO_ADVICE_EACH",
            "AI_LIMITS_TODO_OVERALL_ADVICE_FREE",
            "AI_LIMITS_TODO_OVERALL_ADVICE_PRO",
            "AI_LIMITS_TODO_OVERALL_ADVICE_MAX",
            "AI_LIMITS_FORTUNE",
            "AI_LIMITS_EMOTION_ANALYSIS",
            "AI_LIMITS_MONTHLY_REPORT",
        ]

        for key in keys {
            if let intVal = readInt(key) {
                loaded[key] = intVal
            }
        }

        cachedLimits = loaded  // 참고용 캐시(정확한 조회는 resolvedDailyLimit가 수행)
        if loaded.isEmpty {
            #if DEBUG
                print(
                    "⚠️ [UsageLimitManager] Info.plist/xcconfig 매핑에서 제한값을 찾지 못했습니다. 모든 제한값을 0으로 간주합니다."
                )
            #endif
        } else {
            #if DEBUG
                print("✅ [UsageLimitManager] 구성에서 제한값 로드 완료 (키 \(loaded.keys.count)개)")
            #endif
        }
        return loaded
    }

    /// Info.plist 매핑에서 Int 값 안전 로드 (ConfigReader 비의존 로컬 헬퍼)
    private func readInt(_ key: String) -> Int? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) else { return nil }
        if let s = raw as? String {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("$(") { return nil }
            return Int(trimmed)
        }
        if let n = raw as? NSNumber { return n.intValue }
        if let i = raw as? Int { return i }
        return nil
    }

    // (제거됨) xcconfig 직접 파싱 로직은 사용하지 않습니다. 모든 제한값은 Info.plist 매핑을 통해서만 로드합니다.

    // (제거됨) 하드코딩된 기본 제한값은 사용하지 않습니다. 모든 제한값은 Info.plist 매핑을 통해 설정되어야 합니다.

    /// 주어진 모드에 대해 우선순위 키 목록을 반환(티어 우선 AI_LIMITS_*_{FREE,PRO,MAX} → AI_LIMITS_*)
    /// - DRY: 모든 기능은 AI_LIMITS_* 스키마만 사용 (DAILY_* 폴백 제거)
    private func limitKeyCandidates(for mode: AIMode, isPremium: Bool) -> [String] {
        switch mode {
        case .generalConversation:
            // 티어에 따라 우선순위를 다르게 적용 (Max > Pro > Free)
            let tier: SubscriptionTier = StoreKitSubscriptionManager.shared.currentTier
            switch tier {
            case .max:
                return [
                    "AI_LIMITS_CHAT_MAX",
                    "AI_LIMITS_CHAT_PRO",
                    "AI_LIMITS_CHAT",
                ]
            case .pro:
                return [
                    "AI_LIMITS_CHAT_PRO",
                    "AI_LIMITS_CHAT",
                ]
            case .free:
                return ["AI_LIMITS_CHAT"]
            }
        case .emotionDiaryAnalysis:
            let tier: SubscriptionTier = StoreKitSubscriptionManager.shared.currentTier
            switch tier {
            case .max:
                return [
                    "AI_LIMITS_DIARY_ANALYSIS_MAX",
                    "AI_LIMITS_DIARY_ANALYSIS_PRO",
                    "AI_LIMITS_DIARY_ANALYSIS",
                ]
            case .pro:
                return [
                    "AI_LIMITS_DIARY_ANALYSIS_PRO",
                    "AI_LIMITS_DIARY_ANALYSIS",
                ]
            case .free:
                return [
                    "AI_LIMITS_DIARY_ANALYSIS",
                    "AI_LIMITS_DIARY_ANALYSIS_FREE",
                ]
            }
        case .taskAdvice:
            // 티어별 차등 제한 (Max > Pro > Free)
            let tier: SubscriptionTier = StoreKitSubscriptionManager.shared.currentTier
            switch tier {
            case .max:
                return [
                    "AI_LIMITS_TODO_ADVICE_MAX",
                    "AI_LIMITS_TODO_ADVICE_PRO",
                    "AI_LIMITS_TODO_ADVICE_PREMIUM", // 구명칭 호환
                    "AI_LIMITS_TODO_ADVICE",
                ]
            case .pro:
                return [
                    "AI_LIMITS_TODO_ADVICE_PRO",
                    "AI_LIMITS_TODO_ADVICE_PREMIUM",
                    "AI_LIMITS_TODO_ADVICE",
                ]
            case .free:
                return [
                    "AI_LIMITS_TODO_ADVICE_FREE",
                    "AI_LIMITS_TODO_ADVICE",
                ]
            }
        case .taskAdviceOverall:
            // 별도 키-기반 제한 사용하므로 여기서는 빈 배열 반환(0)
            return []
        case .presetRecommendation:
            let tier: SubscriptionTier = StoreKitSubscriptionManager.shared.currentTier
            switch tier {
            case .max:
                return [
                    "AI_LIMITS_PRESET_RECOMMENDATION_MAX",
                    "AI_LIMITS_PRESET_RECOMMENDATION_PRO",
                    "AI_LIMITS_PRESET_RECOMMENDATION",
                ]
            case .pro:
                return [
                    "AI_LIMITS_PRESET_RECOMMENDATION_PRO",
                    "AI_LIMITS_PRESET_RECOMMENDATION",
                ]
            case .free:
                return [
                    "AI_LIMITS_PRESET_RECOMMENDATION_FREE",
                    "AI_LIMITS_PRESET_RECOMMENDATION",
                ]
            }
        case .monthlyStatistics:
            return ["AI_LIMITS_MONTHLY_STATISTICS"]
        case .fortuneTelling:
            return ["AI_LIMITS_FORTUNE"]
        case .emotionAnalysis:
            return ["AI_LIMITS_EMOTION_ANALYSIS"]
        }
    }

    /// xcconfig/Info.plist에서 우선순위에 따라 제한값을 조회
    private func resolvedDailyLimit(for mode: AIMode) -> Int {
        let premium = SubscriptionStatusCenter.shared.isPremium
        let candidates = limitKeyCandidates(for: mode, isPremium: premium)
        // 1) 번들에서 직접 조회 (가장 신선한 값)
        var resolved: Int? = nil
        for key in candidates {
            if let v = readInt(key) {
                resolved = max(0, v)
                break
            }
        }
        // 2) 캐시에 없다면 한 번만 로드 시도 (지연 로딩)
        if resolved == nil {
            if cachedLimits.isEmpty {
                let loaded = loadLimitsFromBundle()
                for key in candidates {
                    if let cached = loaded[key] {
                        resolved = max(0, cached)
                        break
                    }
                }
            } else {
                for key in candidates {
                    if let cached = cachedLimits[key] {
                        resolved = max(0, cached)
                        break
                    }
                }
            }
        }
        let base = resolved ?? 0
        return base
    }

    /// AIMode를 사용량 키로 변환 (UserDefaults용)
    private func getUsageKeyForMode(_ mode: AIMode) -> String {
        return usageKeyPrefix + mode.rawValue + "_" + currentDate
    }

    /// 현재 사용량 조회
    private func getCurrentUsage(for mode: AIMode) -> Int {
        let usageKey = getUsageKeyForMode(mode)
        return UserDefaults.standard.integer(forKey: usageKey)
    }

    // MARK: - 알림 게시 (80% / 100%)
    private func notifyIfThresholdReached(mode: AIMode, currentUsage: Int) {
        let dailyLimit = resolvedDailyLimit(for: mode)
        guard dailyLimit > 0 else { return }
        let ratio = Double(currentUsage) / Double(dailyLimit)
        let center = NotificationCenter.default
        if ratio >= 1.0 {
            center.post(
                name: .aiUsageLimitReached, object: nil,
                userInfo: [
                    "mode": mode.rawValue,
                    "current": currentUsage,
                    "limit": dailyLimit,
                ])
        } else if ratio >= 0.8 {
            center.post(
                name: .aiUsageLimitWarning, object: nil,
                userInfo: [
                    "mode": mode.rawValue,
                    "current": currentUsage,
                    "limit": dailyLimit,
                ])
        }
    }

    // MARK: - 🕐 일일 초기화 시스템

    /// 새로운 날짜인지 체크하고 필요 시 초기화
    private func checkAndResetIfNewDay() {
        let today = currentDate
        let lastResetDate = UserDefaults.standard.string(forKey: lastResetDateKey) ?? ""

        if today != lastResetDate {
            resetDailyUsage()
            UserDefaults.standard.set(today, forKey: lastResetDateKey)
            print("🌅 [UsageLimitManager] 새로운 날: \\(today), 사용량 초기화 완료")
        }
    }

    /// 일일 사용량 초기화
    private func resetDailyUsage() {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys

        // ai_usage_로 시작하는 모든 키 삭제 (날짜별 사용량 데이터)
        for key in allKeys {
            if key.hasPrefix(usageKeyPrefix) && key != lastResetDateKey {
                userDefaults.removeObject(forKey: key)
            }
        }

        #if DEBUG
            print("🔄 [UsageLimitManager] 모든 일일 사용량 데이터 초기화됨")
        #endif
    }

    /// 자정 자동 초기화 타이머 시작
    private func startDailyResetTimer() {
        let calendar = Calendar.current
        let now = Date()

        // 다음 자정 계산
        guard
            let nextMidnight = calendar.nextDate(
                after: now, matching: DateComponents(hour: 0, minute: 0, second: 0),
                matchingPolicy: .nextTime)
        else {
            print("⚠️ [UsageLimitManager] 다음 자정 계산 실패")
            return
        }

        let timeInterval = nextMidnight.timeIntervalSince(now)

        Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            self?.resetDailyUsage()
            _ = self?.loadLimitsFromBundle() // 자정 시 제한값 스냅샷 갱신(Secrets→Info값 재적용)
            // 커스텀 일일 키/지문도 자정에 함께 초기화
            // (별도 키 스페이스를 사용하므로 resetDailyUsage로 일괄 지우기 어렵다)
            let ud = UserDefaults.standard
            let all = ud.dictionaryRepresentation().keys
            for key in all {
                if key.hasPrefix(self?.dailyCountPrefix ?? "daily_key_count_")
                    || key.hasPrefix(self?.dailyFPsPrefix ?? "daily_key_fps_")
                {
                    ud.removeObject(forKey: key)
                }
            }
            self?.startDailyResetTimer()  // 다음 날을 위한 타이머 재설정
            print("🌅 [UsageLimitManager] 자정 자동 초기화 완료")
        }

        #if DEBUG
            print("⏰ [UsageLimitManager] 다음 자정(\\(nextMidnight)) 자동 초기화 예약됨")
        #endif
    }

    /// 다음 일일 초기화 시각(로컬 캘린더 기준 자정)
    public func nextDailyResetAt() -> Date {
        let calendar = Calendar.current
        let now = Date()
        return calendar.nextDate(
            after: now, matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime) ?? now
    }
}

// MARK: - 🔍 디버깅 및 관리 확장

extension UsageLimitManager {

    // MARK: - 주간 1회 제한 (대한민국 KST 월요일 00:00 기준)
    public enum WeekAnchor {
        case kstMonday
    }

    /// 주간 제한 가능 여부 확인
    /// - Parameters:
    ///   - anchor: 주간 앵커(지금은 KST 월요일 00:00만 지원)
    ///   - key: 기능 키(예: "monthly_statistics")
    /// - Returns: (canUse, remaining, resetAt)
    public func canUseWeeklyLimitedFeature(anchor: WeekAnchor, key: String) -> (
        canUse: Bool, remaining: Int, resetAt: Date
    ) {
        let now = Date()
        let (weekId, resetAt) = currentWeekIdAndResetTime(anchor: anchor, now: now)
        let usageKey = weeklyUsageKey(key: key, weekId: weekId)
        let used = UserDefaults.standard.integer(forKey: usageKey)
        let limit = 1
        let canUse = used < limit
        // 역행 방지: lastSeenClock 저장 및 비교
        let lastSeenKey = weeklyLastSeenKey(key: key)
        if let lastSeen = UserDefaults.standard.object(forKey: lastSeenKey) as? TimeInterval {
            if now.timeIntervalSince1970 + 1 < lastSeen {  // 과거로 이동한 경우
                return (false, max(0, limit - used), resetAt)
            }
        }
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastSeenKey)
        return (canUse, max(0, limit - used), resetAt)
    }

    /// 주간 제한 사용 증가(성공 시 호출)
    public func incrementWeeklyLimitedFeature(anchor: WeekAnchor, key: String) {
        let now = Date()
        let (weekId, _) = currentWeekIdAndResetTime(anchor: anchor, now: now)
        let usageKey = weeklyUsageKey(key: key, weekId: weekId)
        let used = UserDefaults.standard.integer(forKey: usageKey)
        UserDefaults.standard.set(used + 1, forKey: usageKey)
        let lastSeenKey = weeklyLastSeenKey(key: key)
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastSeenKey)
    }

    // MARK: - 내부 유틸(주간 앵커)
    private func currentWeekIdAndResetTime(anchor: WeekAnchor, now: Date) -> (String, Date) {
        switch anchor {
        case .kstMonday:
            // 대한민국 표준시(KST, UTC+9) 기준
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
            // 해당 주의 월요일 00:00
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            let weekStart = calendar.date(from: comps) ?? now
            // 다음 주 월요일 00:00 = 리셋 시각
            let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? now
            let weekId = {
                let year = comps.yearForWeekOfYear ?? 0
                let week = comps.weekOfYear ?? 0
                return String(format: "%04d-W%02d-KST", year, week)
            }()
            return (weekId, nextWeekStart)
        }
    }

    private func weeklyUsageKey(key: String, weekId: String) -> String {
        return "weekly_usage_\(key)_\(weekId)"
    }

    private func weeklyLastSeenKey(key: String) -> String {
        return "weekly_lastSeen_\(key)"
    }

    /// 개발자 전용: 모든 사용량 데이터 출력
    public func printAllUsageData() {
        #if DEBUG
            print("📊 [UsageLimitManager] === 전체 사용량 현황 ===")
            let status = getAllUsageStatus()

            for (mode, data) in status {
                let percentage =
                    data.dailyLimit > 0
                    ? Int(Double(data.currentUsage) / Double(data.dailyLimit) * 100) : 0
                print(
                    "   \\(mode.displayName): \\(data.currentUsage)/\\(data.dailyLimit) (\\(percentage)%)"
                )
            }
            print("=====================================")
        #endif
    }

    /// 개발자 전용: 특정 모드 사용량 강제 설정
    public func setUsageForTesting(mode: AIMode, usage: Int) {
        #if DEBUG
            let usageKey = getUsageKeyForMode(mode)
            UserDefaults.standard.set(usage, forKey: usageKey)
            print("🧪 [UsageLimitManager] 테스트용: \\(mode.displayName) 사용량을 \\(usage)로 설정")
        #endif
    }

    /// 개발자 전용: 모든 사용량 강제 초기화
    public func resetAllUsageForTesting() {
        #if DEBUG
            resetDailyUsage()
            print("🧪 [UsageLimitManager] 테스트용: 모든 사용량 강제 초기화")
        #endif
    }
}

// MARK: - 📅 월간 제한 유틸 (KST 기준)

extension UsageLimitManager {
    public enum MonthAnchor { case kstMonth }

    public func canUseMonthlyLimitedFeature(anchor: MonthAnchor, key: String, limit: Int) -> (
        canUse: Bool, remaining: Int, resetAt: Date
    ) {
        let now = Date()
        let (monthId, resetAt) = currentMonthIdAndResetTime(anchor: anchor, now: now)
        let usageKey = monthlyUsageKey(key: key, monthId: monthId)
        let used = UserDefaults.standard.integer(forKey: usageKey)
        let lim = max(0, limit)
        let canUse = used < lim
        let lastSeenKey = monthlyLastSeenKey(key: key)
        if let lastSeen = UserDefaults.standard.object(forKey: lastSeenKey) as? TimeInterval {
            if now.timeIntervalSince1970 + 1 < lastSeen { // 시계 역행 방지
                return (false, max(0, lim - used), resetAt)
            }
        }
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastSeenKey)
        return (canUse, max(0, lim - used), resetAt)
    }

    public func incrementMonthlyLimitedFeature(anchor: MonthAnchor, key: String) {
        let now = Date()
        let (monthId, _) = currentMonthIdAndResetTime(anchor: anchor, now: now)
        let usageKey = monthlyUsageKey(key: key, monthId: monthId)
        let used = UserDefaults.standard.integer(forKey: usageKey)
        UserDefaults.standard.set(used + 1, forKey: usageKey)
        let lastSeenKey = monthlyLastSeenKey(key: key)
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastSeenKey)
    }

    private func currentMonthIdAndResetTime(anchor: MonthAnchor, now: Date) -> (String, Date) {
        switch anchor {
        case .kstMonth:
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
            // 이번 달의 1일 00:00
            let comps = calendar.dateComponents([.year, .month], from: now)
            let monthStart = calendar.date(from: comps) ?? now
            // 다음 달 1일 00:00 = 리셋 시각
            let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now
            let year = comps.year ?? 0
            let month = comps.month ?? 0
            let monthId = String(format: "%04d-%02d-KST", year, month)
            return (monthId, nextMonthStart)
        }
    }

    private func monthlyUsageKey(key: String, monthId: String) -> String {
        return "monthly_usage_\(key)_\(monthId)"
    }
    private func monthlyLastSeenKey(key: String) -> String {
        return "monthly_last_seen_\(key)"
    }
}

// 📝 **사용법 예시**
/*

 // 1. AI 기능 사용 전 체크
 let (canUse, current, limit) = UsageLimitManager.shared.canUseAIFeature(.emotionDiaryAnalysis)
 if !canUse {
     showAlert("일일 감정분석 한도(\\(limit)회)를 초과했습니다. 내일 다시 이용해주세요.")
     return
 }

 // 2. AI 호출 성공 후 사용량 증가
 let response = try await aiService.sendMessage(...)
 UsageLimitManager.shared.incrementUsage(for: .emotionDiaryAnalysis)

 // 3. 설정 화면에서 전체 현황 표시
 let allStatus = UsageLimitManager.shared.getAllUsageStatus()
 for (mode, data) in allStatus {
     print("\\(mode.displayName): \\(data.currentUsage)/\\(data.dailyLimit)")
 }

 */
