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
            guard let value = Bundle.main.object(forInfoDictionaryKey: "MAX_PROMPT_LENGTH") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.Security] MAX_PROMPT_LENGTH 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let maxDailyRequests: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "MAX_DAILY_REQUESTS") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.Security] MAX_DAILY_REQUESTS 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let maxConversationTurns: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "MAX_CONVERSATION_TURNS") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.Security] MAX_CONVERSATION_TURNS 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let isRateLimitEnabled = true        // 레이트 리미팅 활성화
        static let allowedLanguages: Set<String> = ["ko", "en"]  // 허용 언어
    }
    
    // MARK: - 🤖 AI 기능별 일일 제한
    
    /// AI 기능별 일일 사용 제한
    struct AILimits {
        static let chat: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_LIMITS_CHAT") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.AILimits] AI_LIMITS_CHAT 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let presetRecommendation: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_LIMITS_PRESET_RECOMMENDATION") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.AILimits] AI_LIMITS_PRESET_RECOMMENDATION 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let diaryAnalysis: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_LIMITS_DIARY_ANALYSIS") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.AILimits] AI_LIMITS_DIARY_ANALYSIS 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let monthlyStatistics: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_LIMITS_MONTHLY_STATISTICS") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.AILimits] AI_LIMITS_MONTHLY_STATISTICS 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let todoAdvice: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_LIMITS_TODO_ADVICE") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.AILimits] AI_LIMITS_TODO_ADVICE 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let fortune: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_LIMITS_FORTUNE") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.AILimits] AI_LIMITS_FORTUNE 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let emotionAnalysis: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_LIMITS_EMOTION_ANALYSIS") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.AILimits] AI_LIMITS_EMOTION_ANALYSIS 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let monthlyReport: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_LIMITS_MONTHLY_REPORT") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.AILimits] AI_LIMITS_MONTHLY_REPORT 참조 실패")
                return 0
            }
            return intValue
        }()
    }
    
    // MARK: - 📝 사용자 경험 제한
    
    /// 사용자 데이터 및 경험 제한
    struct UserLimits {
        static let maxDiaryEntriesPerDay: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "MAX_DIARY_ENTRIES_PER_DAY") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.UserLimits] MAX_DIARY_ENTRIES_PER_DAY 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let maxTodoItems: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "MAX_TODO_ITEMS") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.UserLimits] MAX_TODO_ITEMS 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let maxEmotionEntriesPerDay: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "MAX_EMOTION_ENTRIES_PER_DAY") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.UserLimits] MAX_EMOTION_ENTRIES_PER_DAY 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let maxChatHistoryDays: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "MAX_CHAT_HISTORY_DAYS") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.UserLimits] MAX_CHAT_HISTORY_DAYS 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let maxAnalysisHistoryDays: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "MAX_ANALYSIS_HISTORY_DAYS") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.UserLimits] MAX_ANALYSIS_HISTORY_DAYS 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let maxPresetCount: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "MAX_PRESET_COUNT") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.UserLimits] MAX_PRESET_COUNT 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let maxCustomSoundCount: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "MAX_CUSTOM_SOUND_COUNT") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.UserLimits] MAX_CUSTOM_SOUND_COUNT 참조 실패")
                return 0
            }
            return intValue
        }()
    }
    
    // MARK: - 🎵 오디오 설정
    
    /// 오디오 관련 설정
    struct Audio {
        static let defaultGlobalVolume: Float = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "DEFAULT_GLOBAL_VOLUME") as? String,
                  let floatValue = Float(value) else {
                print("⚠️ [AppConfig.Audio] DEFAULT_GLOBAL_VOLUME 참조 실패")
                return 0.0
            }
            return floatValue
        }()
        
        static let defaultMasterVolume: Float = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "DEFAULT_MASTER_VOLUME") as? String,
                  let floatValue = Float(value) else {
                print("⚠️ [AppConfig.Audio] DEFAULT_MASTER_VOLUME 참조 실패")
                return 0.0
            }
            return floatValue
        }()
        
        static let maxCategoryCount: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "MAX_CATEGORY_COUNT") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.Audio] MAX_CATEGORY_COUNT 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let fadeInDuration: TimeInterval = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "FADE_IN_DURATION") as? String,
                  let doubleValue = Double(value) else {
                print("⚠️ [AppConfig.Audio] FADE_IN_DURATION 참조 실패")
                return 0.0
            }
            return doubleValue
        }()
        
        static let fadeOutDuration: TimeInterval = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "FADE_OUT_DURATION") as? String,
                  let doubleValue = Double(value) else {
                print("⚠️ [AppConfig.Audio] FADE_OUT_DURATION 참조 실패")
                return 0.0
            }
            return doubleValue
        }()
    }
    
    // MARK: - 🐛 개발 설정
    
    /// 개발 및 디버그 설정
    struct Development {
        static let isDebugMode: Bool = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "DEBUG_MODE") as? String else {
                print("⚠️ [AppConfig.Development] DEBUG_MODE 참조 실패")
                return false
            }
            return value.uppercased() == "YES"
        }()
        
        static let isVerboseLogging: Bool = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "VERBOSE_LOGGING") as? String else {
                print("⚠️ [AppConfig.Development] VERBOSE_LOGGING 참조 실패")
                return false
            }
            return value.uppercased() == "YES"
        }()
        
        static let isMockAIResponses: Bool = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "MOCK_AI_RESPONSES") as? String else {
                print("⚠️ [AppConfig.Development] MOCK_AI_RESPONSES 참조 실패")
                return false
            }
            return value.uppercased() == "YES"
        }()
        
        static let isTestMode: Bool = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "TEST_MODE") as? String else {
                print("⚠️ [AppConfig.Development] TEST_MODE 참조 실패")
                return false
            }
            return value.uppercased() == "YES"
        }()
    }
    
    // MARK: - 📊 로깅 및 모니터링
    
    /// 로깅 및 모니터링 설정
    struct Monitoring {
        static let enableCrashReporting: Bool = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "ENABLE_CRASH_REPORTING") as? String else {
                print("⚠️ [AppConfig.Monitoring] ENABLE_CRASH_REPORTING 참조 실패")
                return false
            }
            return value.uppercased() == "YES"
        }()
        
        static let enableAnalytics: Bool = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "ENABLE_ANALYTICS") as? String else {
                print("⚠️ [AppConfig.Monitoring] ENABLE_ANALYTICS 참조 실패")
                return false
            }
            return value.uppercased() == "YES"
        }()
        
        static let enablePerformanceMonitoring: Bool = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "ENABLE_PERFORMANCE_MONITORING") as? String else {
                print("⚠️ [AppConfig.Monitoring] ENABLE_PERFORMANCE_MONITORING 참조 실패")
                return false
            }
            return value.uppercased() == "YES"
        }()
        
        static let logRetentionDays: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "LOG_RETENTION_DAYS") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.Monitoring] LOG_RETENTION_DAYS 참조 실패")
                return 0
            }
            return intValue
        }()
    }
    
    // MARK: - 🔄 네트워크 및 재시도 설정
    
    /// 네트워크 관련 설정
    struct Network {
        static let maxRetryAttempts: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "MAX_RETRY_ATTEMPTS") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.Network] MAX_RETRY_ATTEMPTS 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let retryDelay: TimeInterval = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "RETRY_DELAY") as? String,
                  let doubleValue = Double(value) else {
                print("⚠️ [AppConfig.Network] RETRY_DELAY 참조 실패")
                return 0.0
            }
            return doubleValue
        }()
        
        static let cacheExpirationTime: TimeInterval = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "CACHE_EXPIRATION_TIME") as? String,
                  let doubleValue = Double(value) else {
                print("⚠️ [AppConfig.Network] CACHE_EXPIRATION_TIME 참조 실패")
                return 0.0
            }
            return doubleValue
        }()
        
        static let memoryCheckInterval: TimeInterval = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "MEMORY_CHECK_INTERVAL") as? String,
                  let doubleValue = Double(value) else {
                print("⚠️ [AppConfig.Network] MEMORY_CHECK_INTERVAL 참조 실패")
                return 0.0
            }
            return doubleValue
        }()
        
        static let statusUpdateInterval: TimeInterval = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "STATUS_UPDATE_INTERVAL") as? String,
                  let doubleValue = Double(value) else {
                print("⚠️ [AppConfig.Network] STATUS_UPDATE_INTERVAL 참조 실패")
                return 0.0
            }
            return doubleValue
        }()
    }
    
    // MARK: - 🤖 AI 토큰 설정
    
    /// AI 토큰 관련 설정
    struct AITokens {
        static let generalConversationMaxTokens: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_GENERAL_CONVERSATION_MAX_TOKENS") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.AITokens] AI_GENERAL_CONVERSATION_MAX_TOKENS 참조 실패")
                return 0
            }
            return intValue
        }()
        
        static let generalConversationTemperature: Double = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_GENERAL_CONVERSATION_TEMPERATURE") as? String,
                  let doubleValue = Double(value) else {
                print("⚠️ [AppConfig.AITokens] AI_GENERAL_CONVERSATION_TEMPERATURE 참조 실패")
                return 0.0
            }
            return doubleValue
        }()
        
        static let emotionDiaryAnalysisMaxTokens: Int = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "AI_EMOTION_DIARY_ANALYSIS_MAX_TOKENS") as? String,
                  let intValue = Int(value) else {
                print("⚠️ [AppConfig.AITokens] AI_EMOTION_DIARY_ANALYSIS_MAX_TOKENS 참조 실패")
                return 0
            }
            return intValue
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