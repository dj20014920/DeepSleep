//
//  AppConfig.swift
//  DeepSleep
//
//  Created by System on 2025-01-20.
//  Copyright © 2025 DeepSleep. All rights reserved.
//

import Foundation

/// 🔒 **보안 강화된 설정 관리**
/// 모든 설정값을 Secrets.xcconfig에서 로드하며, 참조 실패 시 로그만 출력
struct AppConfig {
    
    // MARK: - 🔒 보안 제한 설정
    
    /// AI 보안 관련 제한
    struct Security {
        static let maxPromptLength: Int = {
            ConfigReader.int("MAX_PROMPT_LENGTH") ?? { print("⚠️ [AppConfig.Security] MAX_PROMPT_LENGTH 누락 — 0(비활성) 처리"); return 0 }()
        }()
        
        static let maxDailyRequests: Int = {
            ConfigReader.int("MAX_DAILY_REQUESTS") ?? { print("⚠️ [AppConfig.Security] MAX_DAILY_REQUESTS 누락 — 0(비활성) 처리"); return 0 }()
        }()
        
        static let maxConversationTurns: Int = {
            ConfigReader.int("MAX_CONVERSATION_TURNS") ?? { print("⚠️ [AppConfig.Security] MAX_CONVERSATION_TURNS 누락 — 0(비활성) 처리"); return 0 }()
        }()
        
        static let isRateLimitEnabled: Bool = {
            ConfigReader.bool("RATE_LIMIT_ENABLED") ?? { print("⚠️ [AppConfig.Security] RATE_LIMIT_ENABLED 누락 — false 처리"); return false }()
        }()
        static let allowedLanguages: Set<String> = ["ko", "en"]  // 허용 언어(고정)
    }
    
    // MARK: - 🤖 AI 기능별 일일 제한
    
    /// AI 기능별 일일 사용 제한
    struct AILimits {
        static let chat: Int = {
            ConfigReader.int("AI_LIMITS_CHAT") ?? { print("⚠️ [AppConfig.AILimits] AI_LIMITS_CHAT 누락 — 0 처리"); return 0 }()
        }()
        
        static let presetRecommendation: Int = {
            ConfigReader.int("AI_LIMITS_PRESET_RECOMMENDATION") ?? { print("⚠️ [AppConfig.AILimits] AI_LIMITS_PRESET_RECOMMENDATION 누락 — 0 처리"); return 0 }()
        }()
        
        static let diaryAnalysis: Int = {
            ConfigReader.int("AI_LIMITS_DIARY_ANALYSIS") ?? { print("⚠️ [AppConfig.AILimits] AI_LIMITS_DIARY_ANALYSIS 누락 — 0 처리"); return 0 }()
        }()
        
        static let monthlyStatistics: Int = {
            ConfigReader.int("AI_LIMITS_MONTHLY_STATISTICS") ?? { print("⚠️ [AppConfig.AILimits] AI_LIMITS_MONTHLY_STATISTICS 누락 — 0 처리"); return 0 }()
        }()
        
        static let todoAdvice: Int = {
            ConfigReader.int("AI_LIMITS_TODO_ADVICE") ?? { print("⚠️ [AppConfig.AILimits] AI_LIMITS_TODO_ADVICE 누락 — 0 처리"); return 0 }()
        }()
        
        static let fortune: Int = {
            ConfigReader.int("AI_LIMITS_FORTUNE") ?? { print("⚠️ [AppConfig.AILimits] AI_LIMITS_FORTUNE 누락 — 0 처리"); return 0 }()
        }()
        
        static let emotionAnalysis: Int = {
            ConfigReader.int("AI_LIMITS_EMOTION_ANALYSIS") ?? { print("⚠️ [AppConfig.AILimits] AI_LIMITS_EMOTION_ANALYSIS 누락 — 0 처리"); return 0 }()
        }()
        
        static let monthlyReport: Int = {
            ConfigReader.int("AI_LIMITS_MONTHLY_REPORT") ?? { print("⚠️ [AppConfig.AILimits] AI_LIMITS_MONTHLY_REPORT 누락 — 0 처리"); return 0 }()
        }()
    }
    
    // MARK: - 📝 사용자 경험 제한
    
    /// 사용자 데이터 및 경험 제한
    struct UserLimits {
        static let maxDiaryEntriesPerDay: Int = {
            ConfigReader.int("MAX_DIARY_ENTRIES_PER_DAY") ?? { print("⚠️ [AppConfig.UserLimits] MAX_DIARY_ENTRIES_PER_DAY 누락 — 0 처리"); return 0 }()
        }()
        
        static let maxTodoItems: Int = {
            ConfigReader.int("MAX_TODO_ITEMS") ?? { print("⚠️ [AppConfig.UserLimits] MAX_TODO_ITEMS 누락 — 0 처리"); return 0 }()
        }()
        
        static let maxEmotionEntriesPerDay: Int = {
            ConfigReader.int("MAX_EMOTION_ENTRIES_PER_DAY") ?? { print("⚠️ [AppConfig.UserLimits] MAX_EMOTION_ENTRIES_PER_DAY 누락 — 0 처리"); return 0 }()
        }()
        
        static let maxChatHistoryDays: Int = {
            ConfigReader.int("MAX_CHAT_HISTORY_DAYS") ?? { print("⚠️ [AppConfig.UserLimits] MAX_CHAT_HISTORY_DAYS 누락 — 0 처리"); return 0 }()
        }()
        
        static let maxAnalysisHistoryDays: Int = {
            ConfigReader.int("MAX_ANALYSIS_HISTORY_DAYS") ?? { print("⚠️ [AppConfig.UserLimits] MAX_ANALYSIS_HISTORY_DAYS 누락 — 0 처리"); return 0 }()
        }()
        
        static let maxPresetCount: Int = {
            ConfigReader.int("MAX_PRESET_COUNT") ?? { print("⚠️ [AppConfig.UserLimits] MAX_PRESET_COUNT 누락 — 0 처리"); return 0 }()
        }()
        
        static let maxCustomSoundCount: Int = {
            ConfigReader.int("MAX_CUSTOM_SOUND_COUNT") ?? { print("⚠️ [AppConfig.UserLimits] MAX_CUSTOM_SOUND_COUNT 누락 — 0 처리"); return 0 }()
        }()
    }
    
    // MARK: - 🎵 오디오 설정
    
    /// 오디오 관련 설정
    struct Audio {
        static let defaultGlobalVolume: Float = {
            Float(ConfigReader.double("DEFAULT_GLOBAL_VOLUME") ?? { print("⚠️ [AppConfig.Audio] DEFAULT_GLOBAL_VOLUME 누락 — 0.0 처리"); return 0.0 }())
        }()
        
        static let defaultMasterVolume: Float = {
            Float(ConfigReader.double("DEFAULT_MASTER_VOLUME") ?? { print("⚠️ [AppConfig.Audio] DEFAULT_MASTER_VOLUME 누락 — 0.0 처리"); return 0.0 }())
        }()
        
        static let maxCategoryCount: Int = {
            ConfigReader.int("MAX_CATEGORY_COUNT") ?? { print("⚠️ [AppConfig.Audio] MAX_CATEGORY_COUNT 누락 — 0 처리"); return 0 }()
        }()
        
        static let fadeInDuration: TimeInterval = {
            ConfigReader.double("FADE_IN_DURATION") ?? { print("⚠️ [AppConfig.Audio] FADE_IN_DURATION 누락 — 0.0 처리"); return 0.0 }()
        }()
        
        static let fadeOutDuration: TimeInterval = {
            ConfigReader.double("FADE_OUT_DURATION") ?? { print("⚠️ [AppConfig.Audio] FADE_OUT_DURATION 누락 — 0.0 처리"); return 0.0 }()
        }()
    }
    
    // MARK: - 🐛 개발 설정
    
    /// 개발 및 디버그 설정
    struct Development {
        static let isDebugMode: Bool = {
            ConfigReader.bool("DEBUG_MODE") ?? { print("⚠️ [AppConfig.Development] DEBUG_MODE 누락 — false 처리"); return false }()
        }()
        
        static let isVerboseLogging: Bool = {
            ConfigReader.bool("VERBOSE_LOGGING") ?? { print("⚠️ [AppConfig.Development] VERBOSE_LOGGING 누락 — false 처리"); return false }()
        }()
        
        static let isMockAIResponses: Bool = {
            ConfigReader.bool("MOCK_AI_RESPONSES") ?? { print("⚠️ [AppConfig.Development] MOCK_AI_RESPONSES 누락 — false 처리"); return false }()
        }()
        
        static let isTestMode: Bool = {
            ConfigReader.bool("TEST_MODE") ?? { print("⚠️ [AppConfig.Development] TEST_MODE 누락 — false 처리"); return false }()
        }()
    }
    
    // MARK: - 📊 로깅 및 모니터링
    
    /// 로깅 및 모니터링 설정
    struct Monitoring {
        static let enableCrashReporting: Bool = {
            ConfigReader.bool("ENABLE_CRASH_REPORTING") ?? { print("⚠️ [AppConfig.Monitoring] ENABLE_CRASH_REPORTING 누락 — false 처리"); return false }()
        }()
        
        static let enableAnalytics: Bool = {
            ConfigReader.bool("ENABLE_ANALYTICS") ?? { print("⚠️ [AppConfig.Monitoring] ENABLE_ANALYTICS 누락 — false 처리"); return false }()
        }()
        
        static let enablePerformanceMonitoring: Bool = {
            ConfigReader.bool("ENABLE_PERFORMANCE_MONITORING") ?? { print("⚠️ [AppConfig.Monitoring] ENABLE_PERFORMANCE_MONITORING 누락 — false 처리"); return false }()
        }()
        
        static let logRetentionDays: Int = {
            ConfigReader.int("LOG_RETENTION_DAYS") ?? { print("⚠️ [AppConfig.Monitoring] LOG_RETENTION_DAYS 누락 — 0 처리"); return 0 }()
        }()
    }
    
    // MARK: - 🔄 네트워크 및 재시도 설정
    
    /// 네트워크 관련 설정
    struct Network {
        static let maxRetryAttempts: Int = {
            ConfigReader.int("MAX_RETRY_ATTEMPTS") ?? { print("⚠️ [AppConfig.Network] MAX_RETRY_ATTEMPTS 누락 — 0 처리"); return 0 }()
        }()
        
        static let retryDelay: TimeInterval = {
            ConfigReader.double("RETRY_DELAY") ?? { print("⚠️ [AppConfig.Network] RETRY_DELAY 누락 — 0.0 처리"); return 0.0 }()
        }()
        
        static let cacheExpirationTime: TimeInterval = {
            ConfigReader.double("CACHE_EXPIRATION_TIME") ?? { print("⚠️ [AppConfig.Network] CACHE_EXPIRATION_TIME 누락 — 0.0 처리"); return 0.0 }()
        }()
        
        static let memoryCheckInterval: TimeInterval = {
            ConfigReader.double("MEMORY_CHECK_INTERVAL") ?? { print("⚠️ [AppConfig.Network] MEMORY_CHECK_INTERVAL 누락 — 0.0 처리"); return 0.0 }()
        }()
        
        static let statusUpdateInterval: TimeInterval = {
            ConfigReader.double("STATUS_UPDATE_INTERVAL") ?? { print("⚠️ [AppConfig.Network] STATUS_UPDATE_INTERVAL 누락 — 0.0 처리"); return 0.0 }()
        }()
    }
    
    // MARK: - 🤖 AI 토큰 설정
    
    /// AI 토큰 관련 설정
    struct AITokens {
        static let generalConversationMaxTokens: Int = {
            ConfigReader.int("AI_GENERAL_CONVERSATION_MAX_TOKENS") ?? { print("⚠️ [AppConfig.AITokens] AI_GENERAL_CONVERSATION_MAX_TOKENS 누락 — 0 처리"); return 0 }()
        }()
        
        static let generalConversationTemperature: Double = {
            ConfigReader.double("AI_GENERAL_CONVERSATION_TEMPERATURE") ?? { print("⚠️ [AppConfig.AITokens] AI_GENERAL_CONVERSATION_TEMPERATURE 누락 — 0.0 처리"); return 0.0 }()
        }()
        
        static let emotionDiaryAnalysisMaxTokens: Int = {
            ConfigReader.int("AI_EMOTION_DIARY_ANALYSIS_MAX_TOKENS") ?? { print("⚠️ [AppConfig.AITokens] AI_EMOTION_DIARY_ANALYSIS_MAX_TOKENS 누락 — 0 처리"); return 0 }()
        }()
        
        static let emotionDiaryAnalysisTemperature: Double = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_EMOTION_DIARY_ANALYSIS_TEMPERATURE") as? String,
                  let doubleValue = Double(value) else {
                print("⚠️ [AppConfig.AITokens] AI_EMOTION_DIARY_ANALYSIS_TEMPERATURE 참조 실패")
                return 0.0
            }
            return doubleValue
        }()
        
        static let taskAdviceMaxTokens: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_TASK_ADVICE_MAX_TOKENS") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.AITokens] AI_TASK_ADVICE_MAX_TOKENS 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let taskAdviceTemperature: Double = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_TASK_ADVICE_TEMPERATURE") as? String,
                  let doubleValue = Double(value) else {
                print("⚠️ [AppConfig.AITokens] AI_TASK_ADVICE_TEMPERATURE 참조 실패")
                return 0.0
            }
            return doubleValue
        }()
        
        static let presetRecommendationMaxTokens: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_PRESET_RECOMMENDATION_MAX_TOKENS") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.AITokens] AI_PRESET_RECOMMENDATION_MAX_TOKENS 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let presetRecommendationTemperature: Double = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_PRESET_RECOMMENDATION_TEMPERATURE") as? String,
                  let doubleValue = Double(value) else {
                print("⚠️ [AppConfig.AITokens] AI_PRESET_RECOMMENDATION_TEMPERATURE 참조 실패")
                return 0.0
            }
            return doubleValue
        }()
        
        static let monthlyStatisticsMaxTokens: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_MONTHLY_STATISTICS_MAX_TOKENS") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.AITokens] AI_MONTHLY_STATISTICS_MAX_TOKENS 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let monthlyStatisticsTemperature: Double = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_MONTHLY_STATISTICS_TEMPERATURE") as? String,
                  let doubleValue = Double(value) else {
                print("⚠️ [AppConfig.AITokens] AI_MONTHLY_STATISTICS_TEMPERATURE 참조 실패")
                return 0.0
            }
            return doubleValue
        }()
        
        static let fortuneTellingMaxTokens: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_FORTUNE_TELLING_MAX_TOKENS") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.AITokens] AI_FORTUNE_TELLING_MAX_TOKENS 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let fortuneTellingTemperature: Double = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_FORTUNE_TELLING_TEMPERATURE") as? String,
                  let doubleValue = Double(value) else {
                print("⚠️ [AppConfig.AITokens] AI_FORTUNE_TELLING_TEMPERATURE 참조 실패")
                return 0.0
            }
            return doubleValue
        }()
        
        static let emotionAnalysisMaxTokens: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_EMOTION_ANALYSIS_MAX_TOKENS") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.AITokens] AI_EMOTION_ANALYSIS_MAX_TOKENS 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let emotionAnalysisTemperature: Double = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_EMOTION_ANALYSIS_TEMPERATURE") as? String,
                  let doubleValue = Double(value) else {
                print("⚠️ [AppConfig.AITokens] AI_EMOTION_ANALYSIS_TEMPERATURE 참조 실패")
                return 0.0
            }
            return doubleValue
        }()
    }
    
    // MARK: - 📄 페이징 설정
    
    /// 페이징 관련 설정
    struct Pagination {
        static let defaultPageSize: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "DEFAULT_PAGE_SIZE") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.Pagination] DEFAULT_PAGE_SIZE 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let maxCachedMessages: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "MAX_CACHED_MESSAGES") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.Pagination] MAX_CACHED_MESSAGES 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let recentSessionsLimit: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "RECENT_SESSIONS_LIMIT") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.Pagination] RECENT_SESSIONS_LIMIT 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let recentMessagesLimit: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "RECENT_MESSAGES_LIMIT") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.Pagination] RECENT_MESSAGES_LIMIT 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let recentFeedbackLimit: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "RECENT_FEEDBACK_LIMIT") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.Pagination] RECENT_FEEDBACK_LIMIT 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let recentBehaviorEventsLimit: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "RECENT_BEHAVIOR_EVENTS_LIMIT") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.Pagination] RECENT_BEHAVIOR_EVENTS_LIMIT 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let feedbackVisualizationLimit: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "FEEDBACK_VISUALIZATION_LIMIT") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.Pagination] FEEDBACK_VISUALIZATION_LIMIT 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let behaviorEventsAnalysisLimit: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "BEHAVIOR_EVENTS_ANALYSIS_LIMIT") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.Pagination] BEHAVIOR_EVENTS_ANALYSIS_LIMIT 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let usageAnalyticsSessionLimit: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "USAGE_ANALYTICS_SESSION_LIMIT") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.Pagination] USAGE_ANALYTICS_SESSION_LIMIT 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let feedbackIntegrationSessionLimit: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "FEEDBACK_INTEGRATION_SESSION_LIMIT") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.Pagination] FEEDBACK_INTEGRATION_SESSION_LIMIT 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let learningStatusSessionLimit: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "LEARNING_STATUS_SESSION_LIMIT") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.Pagination] LEARNING_STATUS_SESSION_LIMIT 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let userProfileSessionLimit: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "USER_PROFILE_SESSION_LIMIT") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.Pagination] USER_PROFILE_SESSION_LIMIT 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let visualizationDataSessionLimit: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "VISUALIZATION_DATA_SESSION_LIMIT") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.Pagination] VISUALIZATION_DATA_SESSION_LIMIT 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let learningProgressSessionLimit: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "LEARNING_PROGRESS_SESSION_LIMIT") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.Pagination] LEARNING_PROGRESS_SESSION_LIMIT 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let richContextSessionLimit: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "RICH_CONTEXT_SESSION_LIMIT") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.Pagination] RICH_CONTEXT_SESSION_LIMIT 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let recentFeedbackForRecommendationLimit: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "RECENT_FEEDBACK_FOR_RECOMMENDATION_LIMIT") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.Pagination] RECENT_FEEDBACK_FOR_RECOMMENDATION_LIMIT 참조 실패")
                return 0
            }
            return intValue
        }()
    }
    
    // MARK: - 🔧 편의 메서드
    
    /// 현재 설정 상태를 로그로 출력 (실제 값은 보안상 숨김)
    static func logCurrentSettings() {
        print("🔒 [AppConfig] 보안 강화된 설정 로드 완료")
        print("   📊 AI 기능별 제한: \(AILimits.chat > 0 ? "✅" : "❌") 로드됨")
        print("   🔒 보안 설정: \(Security.maxPromptLength > 0 ? "✅" : "❌") 로드됨")
        print("   📝 사용자 제한: \(UserLimits.maxTodoItems > 0 ? "✅" : "❌") 로드됨")
        print("   🎵 오디오 설정: \(Audio.maxCategoryCount > 0 ? "✅" : "❌") 로드됨")
        print("   🔄 네트워크 설정: \(Network.maxRetryAttempts > 0 ? "✅" : "❌") 로드됨")
        print("   🤖 AI 토큰 설정: \(AITokens.generalConversationMaxTokens > 0 ? "✅" : "❌") 로드됨")
        print("   📄 페이징 설정: \(Pagination.defaultPageSize > 0 ? "✅" : "❌") 로드됨")
        print("   🐛 개발 설정: \(Development.isDebugMode ? "디버그" : "프로덕션") 모드")
        print("   📊 모니터링: \(Monitoring.enableAnalytics ? "활성화" : "비활성화")")
    }
    
    /// 프로덕션 환경 여부 확인
    static var isProduction: Bool {
        return !Development.isDebugMode && !Development.isTestMode
    }
    
    /// 개발 환경 여부 확인
    static var isDevelopment: Bool {
        return Development.isDebugMode || Development.isTestMode
    }
}