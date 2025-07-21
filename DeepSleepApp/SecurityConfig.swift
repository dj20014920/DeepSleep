//
//  SecurityConfig.swift
//  DeepSleep
//
//  Created by Security Team on 2025-01-20.
//  Copyright © 2025 DeepSleep. All rights reserved.
//

import Foundation

/// 🔒 **중앙화된 보안 설정 관리자**
/// Secrets.xcconfig에서 모든 보안 설정을 로드하여 일관성 있게 관리
class SecurityConfig {
    static let shared = SecurityConfig()
    
    private init() {}
    
    // MARK: - 🔒 보안 제한 설정 (Secrets.xcconfig에서 로드)
    
    /// 사용자가 AI에게 보낼 수 있는 메시지의 최대 글자 수
    /// 프롬프트 인젝션 공격 방지 목적
    var maxPromptLength: Int {
        return getConfigValue("MAX_PROMPT_LENGTH", defaultValue: 2000)
    }
    
    /// 사용자가 하루에 AI에게 보낼 수 있는 최대 메시지 횟수
    /// API 비용 및 남용 방지 목적
    var maxDailyRequests: Int {
        return getConfigValue("MAX_DAILY_REQUESTS", defaultValue: 100)
    }
    
    /// 하나의 대화 세션에서 주고받을 수 있는 최대 턴 수
    /// (사용자 메시지 + AI 응답 = 1턴)
    /// 메모리 및 컨텍스트 관리 목적
    var maxConversationTurns: Int {
        return getConfigValue("MAX_CONVERSATION_TURNS", defaultValue: 200)
    }
    
    /// 레이트 리미팅 활성화 여부
    var isRateLimitEnabled: Bool {
        return getBoolConfigValue("RATE_LIMIT_ENABLED", defaultValue: true)
    }
    
    /// 디버그 모드 활성화 여부
    var isDebugMode: Bool {
        return getBoolConfigValue("DEBUG_MODE", defaultValue: false)
    }
    
    /// 상세 로깅 활성화 여부
    var isVerboseLogging: Bool {
        return getBoolConfigValue("VERBOSE_LOGGING", defaultValue: false)
    }
    
    /// 모의 AI 응답 사용 여부
    var isMockAIResponses: Bool {
        return getBoolConfigValue("MOCK_AI_RESPONSES", defaultValue: false)
    }
    
    // MARK: - 🤖 AI 기능별 일일 제한
    
    /// 일반 채팅 일일 제한 횟수
    var dailyChatLimit: Int {
        return getConfigValue("DAILY_CHAT_LIMIT", defaultValue: 50)
    }
    
    /// 프리셋 추천 일일 제한 횟수
    var dailyPresetRecommendationLimit: Int {
        return getConfigValue("DAILY_PRESET_RECOMMENDATION_LIMIT", defaultValue: 5)
    }
    
    /// 일기 분석 일일 제한 횟수
    var dailyDiaryAnalysisLimit: Int {
        return getConfigValue("DAILY_DIARY_ANALYSIS_LIMIT", defaultValue: 5)
    }
    
    /// 패턴 분석 일일 제한 횟수
    var dailyPatternAnalysisLimit: Int {
        return getConfigValue("DAILY_PATTERN_ANALYSIS_LIMIT", defaultValue: 3)
    }
    
    /// 할일 조언 일일 제한 횟수
    var dailyTodoAdviceLimit: Int {
        return getConfigValue("DAILY_TODO_ADVICE_LIMIT", defaultValue: 5)
    }
    
    /// 운세 일일 제한 횟수
    var dailyFortuneLimit: Int {
        return getConfigValue("DAILY_FORTUNE_LIMIT", defaultValue: 1)
    }
    
    // MARK: - 📝 사용자 경험 제한
    
    /// 하루 최대 일기 작성 수
    var maxDiaryEntriesPerDay: Int {
        return getConfigValue("MAX_DIARY_ENTRIES_PER_DAY", defaultValue: 10)
    }
    
    /// 최대 할일 개수
    var maxTodoItems: Int {
        return getConfigValue("MAX_TODO_ITEMS", defaultValue: 100)
    }
    
    /// 하루 최대 감정 기록 수
    var maxEmotionEntriesPerDay: Int {
        return getConfigValue("MAX_EMOTION_ENTRIES_PER_DAY", defaultValue: 20)
    }
    
    /// 채팅 기록 보관 일수
    var maxChatHistoryDays: Int {
        return getConfigValue("MAX_CHAT_HISTORY_DAYS", defaultValue: 30)
    }
    
    /// 분석 기록 보관 일수
    var maxAnalysisHistoryDays: Int {
        return getConfigValue("MAX_ANALYSIS_HISTORY_DAYS", defaultValue: 90)
    }
    
    // MARK: - 🛠️ Private Helper Methods
    
    private func getConfigValue(_ key: String, defaultValue: Int) -> Int {
        guard let stringValue = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              let intValue = Int(stringValue) else {
            print("⚠️ [SecurityConfig] \(key) 설정을 찾을 수 없음. 기본값 \(defaultValue) 사용")
            return defaultValue
        }
        return intValue
    }
    
    private func getBoolConfigValue(_ key: String, defaultValue: Bool) -> Bool {
        guard let stringValue = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            print("⚠️ [SecurityConfig] \(key) 설정을 찾을 수 없음. 기본값 \(defaultValue) 사용")
            return defaultValue
        }
        
        switch stringValue.uppercased() {
        case "YES", "TRUE", "1":
            return true
        case "NO", "FALSE", "0":
            return false
        default:
            print("⚠️ [SecurityConfig] \(key) 값이 올바르지 않음: \(stringValue). 기본값 \(defaultValue) 사용")
            return defaultValue
        }
    }
    
    // MARK: - 📊 설정 정보 출력
    
    /// 현재 보안 설정 상태를 로그로 출력
    func logCurrentSettings() {
        print("🔒 [SecurityConfig] 현재 보안 설정:")
        print("   📝 최대 프롬프트 길이: \(maxPromptLength)글자")
        print("   📊 일일 최대 요청: \(maxDailyRequests)회")
        print("   💬 최대 대화 턴: \(maxConversationTurns)턴")
        print("   🚦 레이트 리미팅: \(isRateLimitEnabled ? "활성화" : "비활성화")")
        print("   🐛 디버그 모드: \(isDebugMode ? "활성화" : "비활성화")")
        print("   📋 상세 로깅: \(isVerboseLogging ? "활성화" : "비활성화")")
        print("   🤖 모의 응답: \(isMockAIResponses ? "활성화" : "비활성화")")
        print("")
        print("🤖 [AI 기능별 일일 제한]:")
        print("   💬 일반 채팅: \(dailyChatLimit)회/일")
        print("   🎵 프리셋 추천: \(dailyPresetRecommendationLimit)회/일")
        print("   📔 일기 분석: \(dailyDiaryAnalysisLimit)회/일")
        print("   📊 패턴 분석: \(dailyPatternAnalysisLimit)회/일")
        print("   ✅ 할일 조언: \(dailyTodoAdviceLimit)회/일")
        print("   🔮 운세: \(dailyFortuneLimit)회/일")
        print("")
        print("📝 [사용자 경험 제한]:")
        print("   📔 일기 작성: \(maxDiaryEntriesPerDay)개/일")
        print("   ✅ 할일 개수: \(maxTodoItems)개")
        print("   😊 감정 기록: \(maxEmotionEntriesPerDay)개/일")
        print("   💬 채팅 보관: \(maxChatHistoryDays)일")
        print("   📊 분석 보관: \(maxAnalysisHistoryDays)일")
    }
}