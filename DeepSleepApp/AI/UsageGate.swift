//
//  UsageGate.swift
//  DeepSleep
//
//  Created by AI Assistant on 2025-09-09.
//  Copyright © 2025 EmoZleep. All rights reserved.
//

import Foundation

// Expose WeekAnchor (defined inside UsageLimitManager extension) to this file
// so that wrapper signatures using `WeekAnchor` compile without fully qualifying.
typealias WeekAnchor = UsageLimitManager.WeekAnchor

/// 사용량 체크 결과를 담는 구조체
public struct UsageResult: Equatable {
    public let canUse: Bool
    public let currentUsage: Int
    public let dailyLimit: Int
    public let remaining: Int
    public let resetTime: Date
    public let mode: AIMode

    public init(canUse: Bool, currentUsage: Int, dailyLimit: Int, mode: AIMode) {
        self.canUse = canUse
        self.currentUsage = currentUsage
        self.dailyLimit = dailyLimit
        self.remaining = max(0, dailyLimit - currentUsage)
        self.resetTime = UsageLimitManager.shared.nextDailyResetAt()
        self.mode = mode
    }
}

/// 중앙집중형 사용량 관리 게이트웨이
/// - 목적: UsageLimitManager 중복 호출 제거 및 캐싱을 통한 성능 최적화
/// - SOLID 원칙: SRP(단일 책임 - 사용량 체크만 담당), DIP(의존성 역전 - UsageLimitManager에 의존)
/// - DRY 원칙: 모든 컴포넌트가 이 클래스를 통해서만 사용량 체크
public final class UsageGate {

    // MARK: - 싱글톤
    public static let shared = UsageGate()

    // MARK: - Properties
    private let usageLimitManager = UsageLimitManager.shared
    private let queue = DispatchQueue(
        label: "ai.usage.gate.queue", qos: .userInitiated, attributes: .concurrent)

    /// 캐시된 사용량 체크 결과 (중복 호출 방지)
    private var cachedResults: [AIMode: (result: UsageResult, timestamp: Date)] = [:]

    /// 캐시 유효 시간 (초) - 짧은 시간 내 동일한 체크 요청 시 캐시된 결과 반환
    private let cacheValidityInterval: TimeInterval = 3.0

    /// 마지막 캐시 무효화 시간
    private var lastCacheInvalidation: Date = Date()

    // MARK: - Initialization
    private init() {
        #if DEBUG
            print("🚪 [UsageGate] 중앙집중형 사용량 게이트 초기화됨")
        #endif

        // 사용량 한도 도달 알림 구독
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUsageLimitReached),
            name: .aiUsageLimitReached,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    /// AI 기능 사용 가능 여부 체크 (캐싱 적용)
    /// - Parameter mode: AI 모드
    /// - Returns: 사용량 체크 결과
    public func checkUsage(for mode: AIMode) -> UsageResult {
        return queue.sync {
            // 1. 캐시 체크
            if let cached = getCachedResult(for: mode) {
                #if DEBUG
                    print(
                        "🎯 [UsageGate] 캐시 히트: \(mode.displayName) - \(cached.currentUsage)/\(cached.dailyLimit)"
                    )
                #endif
                return cached
            }

            // 2. 실제 사용량 체크
            let usage = usageLimitManager.canUseAIFeature(mode)
            let result = UsageResult(
                canUse: usage.canUse,
                currentUsage: usage.currentUsage,
                dailyLimit: usage.dailyLimit,
                mode: mode
            )

            // 3. 캐시 저장
            setCachedResult(result, for: mode)

            #if DEBUG
                print(
                    "🚪 [UsageGate] 새 체크: \(mode.displayName) - \(result.currentUsage)/\(result.dailyLimit) (사용가능: \(result.canUse))"
                )
            #endif

            return result
        }
    }

    /// AI 기능 사용량 증가 (성공적인 호출 후 사용)
    /// - Parameter mode: AI 모드
    public func incrementUsage(for mode: AIMode) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            // 1. 사용량 증가
            self.usageLimitManager.incrementUsage(for: mode)

            // 2. 해당 모드의 캐시 무효화
            self.invalidateCache(for: mode)

            #if DEBUG
                print("⬆️ [UsageGate] 사용량 증가: \(mode.displayName)")
            #endif
        }
    }

    /// 일일 키 기반 기능 사용 가능 여부 체크 (할일 조언 등)
    /// - Parameters:
    ///   - key: 기능 식별 키
    ///   - limit: 일일 제한량
    /// - Returns: 사용 가능 여부와 현재 사용량
    public func canUseDailyKeyedFeature(key: String, limit: Int) -> (
        canUse: Bool, remaining: Int, resetAt: Date
    ) {
        return queue.sync {
            let tuple = usageLimitManager.canUseDailyKeyedFeature(key: key, limit: limit)
            #if DEBUG
                print(
                    "🗝️ [UsageGate] 일일 키 기능 체크: \(key) - 남은횟수 \(tuple.remaining)/\(limit) (사용가능: \(tuple.canUse))"
                )
            #endif
            return tuple
        }
    }

    /// 일일 키 기반 기능 사용량 증가
    /// - Parameter key: 기능 식별 키
    public func incrementDailyKeyedFeature(key: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            self.usageLimitManager.incrementDailyKeyedFeature(key: key)

            #if DEBUG
                print("⬆️ [UsageGate] 일일 키 기능 사용량 증가: \(key)")
            #endif
        }
    }

    /// 전체 사용량 상태 조회
    /// - Returns: 모든 AI 모드의 사용량 상태
    public func getAllUsageStatus() -> [AIMode: UsageResult] {
        return queue.sync {
            var results: [AIMode: UsageResult] = [:]

            // 주요 AI 모드들의 상태 조회
            let modes: [AIMode] = [
                .generalConversation,
                .emotionDiaryAnalysis,
                .presetRecommendation,
                .taskAdvice,
                .monthlyStatistics,
                .fortuneTelling,
            ]

            for mode in modes {
                results[mode] = checkUsage(for: mode)
            }

            return results
        }
    }

    /// 캐시 전체 무효화 (일일 리셋 시 사용)
    public func invalidateAllCache() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            self.cachedResults.removeAll()
            self.lastCacheInvalidation = Date()

            #if DEBUG
                print("🗑️ [UsageGate] 전체 캐시 무효화됨")
            #endif
        }
    }

    // MARK: - Private Methods

    /// 캐시된 결과 조회
    private func getCachedResult(for mode: AIMode) -> UsageResult? {
        guard let cached = cachedResults[mode] else { return nil }

        let age = Date().timeIntervalSince(cached.timestamp)
        let cacheAge = Date().timeIntervalSince(lastCacheInvalidation)

        // 캐시가 유효한지 체크
        if age < cacheValidityInterval && cacheAge > 0 {
            return cached.result
        }

        // 만료된 캐시 제거
        cachedResults.removeValue(forKey: mode)
        return nil
    }

    /// 캐시 결과 저장
    private func setCachedResult(_ result: UsageResult, for mode: AIMode) {
        cachedResults[mode] = (result: result, timestamp: Date())
        enforceCacheMemoryCap()
    }

    /// 특정 모드의 캐시 무효화
    private func invalidateCache(for mode: AIMode) {
        cachedResults.removeValue(forKey: mode)

        #if DEBUG
            print("🗑️ [UsageGate] 캐시 무효화: \(mode.displayName)")
        #endif
    }

    /// 사용량 한도 도달 알림 처리
    @objc private func handleUsageLimitReached(_ notification: Notification) {
        guard let modeString = notification.userInfo?["mode"] as? String,
            let mode = AIMode(rawValue: modeString)
        else { return }

        // 해당 모드의 캐시 무효화
        queue.async(flags: .barrier) { [weak self] in
            self?.invalidateCache(for: mode)
        }

        #if DEBUG
            print("⚠️ [UsageGate] 사용량 한도 도달 알림 처리: \(mode.displayName)")
        #endif
    }

    // MARK: - 내부 메모리 상한 (오래된 캐시 정리)
    /// 캐시 항목 수가 상한을 초과하면 가장 오래된 항목부터 제거
    private func enforceCacheMemoryCap(maxEntries: Int = 32) {
        if cachedResults.count <= maxEntries { return }
        // 오래된 순으로 정렬 후 초과분 제거
        let overflow =
            cachedResults
            .sorted { $0.value.timestamp < $1.value.timestamp }
            .prefix(cachedResults.count - maxEntries)
        for (mode, _) in overflow {
            cachedResults.removeValue(forKey: mode)
        }
        #if DEBUG
            print("🧹 [UsageGate] 캐시 메모리 상한 적용 - 현재 \(cachedResults.count)개 (cap=\(maxEntries))")
        #endif
    }
}

// MARK: - 편의 메서드 확장
extension UsageGate {

    /// 빠른 사용 가능 여부 체크 (Bool만 반환)
    /// - Parameter mode: AI 모드
    /// - Returns: 사용 가능 여부
    public func canUse(_ mode: AIMode) -> Bool {
        return checkUsage(for: mode).canUse
    }

    /// 남은 사용량 조회
    /// - Parameter mode: AI 모드
    /// - Returns: 남은 사용 가능 횟수
    public func remainingCount(for mode: AIMode) -> Int {
        return checkUsage(for: mode).remaining
    }

    /// 현재 사용량 조회
    /// - Parameter mode: AI 모드
    /// - Returns: 현재 사용 횟수
    public func currentCount(for mode: AIMode) -> Int {
        return checkUsage(for: mode).currentUsage
    }

    /// 일일 한도 조회
    /// - Parameter mode: AI 모드
    /// - Returns: 일일 사용 한도
    public func dailyLimit(for mode: AIMode) -> Int {
        return checkUsage(for: mode).dailyLimit
    }

    // MARK: - Weekly Feature Wrappers (DRY 통일)
    /// 주간 제한 기능 사용 가능 여부
    func canUseWeeklyFeature(anchor: WeekAnchor, key: String) -> (
        canUse: Bool, remaining: Int, resetAt: Date
    ) {
        return usageLimitManager.canUseWeeklyLimitedFeature(anchor: anchor, key: key)
    }

    /// 주간 제한 기능 사용량 증가
    func incrementWeeklyFeature(anchor: WeekAnchor, key: String) {
        queue.async(flags: .barrier) { [weak self] in
            self?.usageLimitManager.incrementWeeklyLimitedFeature(anchor: anchor, key: key)
        }
    }

    // MARK: - Daily Fingerprint Wrappers (개별 항목 1회 제한)
    /// 특정 fingerprint(예: 개별 할 일) 하루 1회 사용 여부
    public func hasUsedDailyFingerprint(namespace: String, fingerprint: String) -> Bool {
        return usageLimitManager.hasUsedDailyFingerprint(
            namespace: namespace, fingerprint: fingerprint)
    }

    /// fingerprint 사용 기록
    public func markDailyFingerprintUsed(namespace: String, fingerprint: String) {
        queue.async(flags: .barrier) { [weak self] in
            self?.usageLimitManager.markDailyFingerprintUsed(
                namespace: namespace, fingerprint: fingerprint)
        }
    }
}

// MARK: - 디버그 및 테스트 지원
#if DEBUG
    extension UsageGate {

        /// 현재 캐시 상태 출력 (디버깅용)
        public func printCacheStatus() {
            queue.sync {
                print("📊 [UsageGate] 캐시 상태:")
                print("   - 캐시된 모드 수: \(cachedResults.count)")
                print("   - 캐시 유효 시간: \(cacheValidityInterval)초")
                print("   - 마지막 무효화: \(lastCacheInvalidation)")

                for (mode, cached) in cachedResults {
                    let age = Date().timeIntervalSince(cached.timestamp)
                    print(
                        "   - \(mode.displayName): \(cached.result.currentUsage)/\(cached.result.dailyLimit) (age: \(String(format: "%.1f", age))s)"
                    )
                }
            }
        }

        /// 캐시 통계 조회 (테스트용)
        public func getCacheStats() -> (cachedModes: Int, averageAge: TimeInterval) {
            return queue.sync {
                let count = cachedResults.count
                guard count > 0 else { return (0, 0) }

                let totalAge = cachedResults.values.reduce(0) { sum, cached in
                    sum + Date().timeIntervalSince(cached.timestamp)
                }

                return (count, totalAge / Double(count))
            }
        }

        /// (디버그) 내부 캐시 메모리 상한 검사 결과 출력
        public func debugEnforceCacheCapPreview(maxEntries: Int = 32) {
            queue.sync {
                if cachedResults.count > maxEntries {
                    print(
                        "⚠️ [UsageGate] (preview) 캐시 항목 \(cachedResults.count)개 → 상한 \(maxEntries) 초과"
                    )
                } else {
                    print("✅ [UsageGate] (preview) 캐시 항목 \(cachedResults.count)/\(maxEntries)")
                }
            }
        }
    }
#endif
