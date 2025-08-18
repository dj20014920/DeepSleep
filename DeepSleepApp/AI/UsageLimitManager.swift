//
//  UsageLimitManager.swift
//  DeepSleep
//
//  Created by Claude on 2025-07-23.
//  Copyright © 2025 DeepSleep. All rights reserved.
//

import Foundation

public extension Notification.Name {
    static let aiUsageLimitWarning = Notification.Name("aiUsageLimitWarning")
    static let aiUsageLimitReached = Notification.Name("aiUsageLimitReached")
}

/// 🛡️ AI 사용량 제한 관리자 (Secrets.xcconfig 연동)
/// 
/// **목적**: 모든 AI 기능의 일일 사용량을 중앙에서 관리하여 API 비용 제어
/// **데이터 소스**: Secrets.xcconfig의 DAILY_*_LIMIT 설정값들
/// **저장소**: UserDefaults (앱 재설치 시 초기화)
///
/// PERF-WARNING: 사용량 체크 시 UserDefaults 동기 I/O 발생
/// - 테스트 방법: Instruments Time Profiler로 체크 메서드 성능 측정
/// - 최적화 방안: 메모리 캐시 활용으로 디스크 접근 최소화
public class UsageLimitManager {
    
    // MARK: - 싱글톤
    public static let shared = UsageLimitManager()
    private init() {
        loadLimitsFromBundle()
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
    
    // MARK: - 📊 사용량 제한 체크 (메인 API)
    
    /// AI 기능 사용 가능 여부 체크
    /// - Parameter mode: AI 모드
    /// - Returns: (사용가능여부, 현재사용량, 일일제한량)
    public func canUseAIFeature(_ mode: AIMode) -> (canUse: Bool, currentUsage: Int, dailyLimit: Int) {
        checkAndResetIfNewDay()
        
        let limitKey = getLimitKeyForMode(mode)
        let dailyLimit = cachedLimits[limitKey] ?? 0
        let currentUsage = getCurrentUsage(for: mode)
        let canUse = currentUsage < dailyLimit
        
        #if DEBUG
        print("🛡️ [UsageLimitManager] \(mode.displayName): \(currentUsage)/\(dailyLimit) (사용가능: \(canUse))")
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
            let limitKey = getLimitKeyForMode(mode)
            let dailyLimit = cachedLimits[limitKey] ?? 0
            let currentUsage = getCurrentUsage(for: mode)
            status[mode] = (currentUsage: currentUsage, dailyLimit: dailyLimit)
        }
        
        return status
    }
    
    // MARK: - 🔧 내부 구현
    
    /// Bundle에서 Secrets.xcconfig의 제한값 로드
    private func loadLimitsFromBundle() {
        // Info.plist에 매핑된 키에서 안전하게 로드 (Secrets.xcconfig -> Info.plist -> Bundle)
        var loaded: [String: Int] = [:]
        let keys = [
            "DAILY_CHAT_LIMIT",
            "DAILY_PRESET_RECOMMENDATION_LIMIT",
            "DAILY_DIARY_ANALYSIS_LIMIT",
            "DAILY_TODO_ADVICE_LIMIT",
            "DAILY_FORTUNE_LIMIT",
            "DAILY_EMOTION_ANALYSIS_LIMIT",
            "DAILY_MONTHLY_STATISTICS_LIMIT"
        ]
        
        for key in keys {
            if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, let intVal = Int(value) {
                loaded[key] = intVal
            } else if let intVal = Bundle.main.object(forInfoDictionaryKey: key) as? Int {
                loaded[key] = intVal
            }
        }
        
        // 백업 하드코딩 없이, 구성 누락 시 0으로만 처리
        cachedLimits = loaded
        if loaded.isEmpty {
            print("⚠️ [UsageLimitManager] Info.plist 매핑에서 제한값을 찾지 못했습니다. 모든 제한값을 0으로 간주합니다.")
        } else {
            print("✅ [UsageLimitManager] Info.plist 매핑에서 제한값 로드 완료")
        }
    }
    
    // (제거됨) xcconfig 직접 파싱 로직은 사용하지 않습니다. 모든 제한값은 Info.plist 매핑을 통해서만 로드합니다.
    
    // (제거됨) 하드코딩된 기본 제한값은 사용하지 않습니다. 모든 제한값은 Info.plist 매핑을 통해 설정되어야 합니다.
    
    /// AIMode를 제한값 키로 변환
    private func getLimitKeyForMode(_ mode: AIMode) -> String {
        switch mode {
        case .generalConversation:
            return "DAILY_CHAT_LIMIT"
        case .emotionDiaryAnalysis:
            return "DAILY_DIARY_ANALYSIS_LIMIT"
        case .taskAdvice:
            return "DAILY_TODO_ADVICE_LIMIT"
        case .presetRecommendation:
            return "DAILY_PRESET_RECOMMENDATION_LIMIT"
        case .monthlyStatistics:
            return "DAILY_MONTHLY_STATISTICS_LIMIT"
        case .fortuneTelling:
            return "DAILY_FORTUNE_LIMIT"
        case .emotionAnalysis:
            return "DAILY_EMOTION_ANALYSIS_LIMIT"
        }
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
        let limitKey = getLimitKeyForMode(mode)
        let dailyLimit = cachedLimits[limitKey] ?? 0
        guard dailyLimit > 0 else { return }
        let ratio = Double(currentUsage) / Double(dailyLimit)
        let center = NotificationCenter.default
        if ratio >= 1.0 {
            center.post(name: .aiUsageLimitReached, object: nil, userInfo: [
                "mode": mode.rawValue,
                "current": currentUsage,
                "limit": dailyLimit
            ])
        } else if ratio >= 0.8 {
            center.post(name: .aiUsageLimitWarning, object: nil, userInfo: [
                "mode": mode.rawValue,
                "current": currentUsage,
                "limit": dailyLimit
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
        guard let nextMidnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime) else {
            print("⚠️ [UsageLimitManager] 다음 자정 계산 실패")
            return
        }
        
        let timeInterval = nextMidnight.timeIntervalSince(now)
        
        Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            self?.resetDailyUsage()
            self?.startDailyResetTimer() // 다음 날을 위한 타이머 재설정
            print("🌅 [UsageLimitManager] 자정 자동 초기화 완료")
        }
        
        #if DEBUG
        print("⏰ [UsageLimitManager] 다음 자정(\\(nextMidnight)) 자동 초기화 예약됨")
        #endif
    }
}

// MARK: - 🔍 디버깅 및 관리 확장

extension UsageLimitManager {
    
    /// 개발자 전용: 모든 사용량 데이터 출력
    public func printAllUsageData() {
        #if DEBUG
        print("📊 [UsageLimitManager] === 전체 사용량 현황 ===")
        let status = getAllUsageStatus()
        
        for (mode, data) in status {
            let percentage = data.dailyLimit > 0 ? Int(Double(data.currentUsage) / Double(data.dailyLimit) * 100) : 0
            print("   \\(mode.displayName): \\(data.currentUsage)/\\(data.dailyLimit) (\\(percentage)%)")
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
