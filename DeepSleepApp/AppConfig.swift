//
//  AppConfig.swift
//  DeepSleep
//
//  Created by System on 2025-01-20.
//  Copyright © 2025 DeepSleep. All rights reserved.
//

import Foundation

/// 🔒 **앱 전역 설정 관리**
/// 모든 제한 설정을 한 곳에서 관리하는 전역 구조체
struct AppConfig {
    
    // MARK: - 🔒 보안 제한 설정
    
    /// AI 보안 관련 제한
    struct Security {
        static let maxPromptLength = 2000           // 사용자 메시지 최대 글자 수
        static let maxDailyRequests = 100           // 하루 최대 메시지 전송 횟수
        static let maxConversationTurns = 200       // 대화 세션당 최대 턴 수
        static let isRateLimitEnabled = true        // 레이트 리미팅 활성화
        static let allowedLanguages: Set<String> = ["ko", "en"]  // 허용 언어
    }
    
    // MARK: - 🤖 AI 기능별 일일 제한
    
    /// AI 기능별 일일 사용 제한
    struct AILimits {
        static let chat = 50                        // 일반 채팅 (하루 50회)
        static let presetRecommendation = 5         // 프리셋 추천 (하루 5회)
        static let diaryAnalysis = 5                // 일기 분석 (하루 5회)
        static let monthlyStatistics = 3            // 월간 통계 (하루 3회)
        static let todoAdvice = 5                   // 할일 조언 (하루 5회)
        static let fortune = 1                      // 운세 (하루 1회)
        static let emotionAnalysis = 10             // 감정 분석 (하루 10회)
        static let monthlyReport = 1                // 월간 리포트 (하루 1회)
    }
    
    // MARK: - 📝 사용자 경험 제한
    
    /// 사용자 데이터 및 경험 제한
    struct UserLimits {
        static let maxDiaryEntriesPerDay = 10       // 하루 최대 일기 작성 수
        static let maxTodoItems = 100               // 최대 할일 개수
        static let maxEmotionEntriesPerDay = 20     // 하루 최대 감정 기록 수
        static let maxChatHistoryDays = 30          // 채팅 기록 보관 일수
        static let maxAnalysisHistoryDays = 90      // 분석 기록 보관 일수
        static let maxPresetCount = 50              // 최대 프리셋 개수
        static let maxCustomSoundCount = 20         // 최대 커스텀 사운드 개수
    }
    
    // MARK: - 🎵 오디오 설정
    
    /// 오디오 관련 설정
    struct Audio {
        static let defaultGlobalVolume: Float = 0.75    // 기본 전역 볼륨
        static let defaultMasterVolume: Float = 50.0    // 기본 마스터 볼륨
        static let maxCategoryCount = 13                // 최대 카테고리 수
        static let fadeInDuration: TimeInterval = 2.0   // 페이드인 시간
        static let fadeOutDuration: TimeInterval = 2.0  // 페이드아웃 시간
    }
    
    // MARK: - 🐛 개발 설정
    
    /// 개발 및 디버그 설정
    struct Development {
        static let isDebugMode = false              // 디버그 모드
        static let isVerboseLogging = false         // 상세 로깅
        static let isMockAIResponses = false        // 모의 AI 응답
        static let isTestMode = false               // 테스트 모드
    }
    
    // MARK: - 📊 로깅 및 모니터링
    
    /// 로깅 및 모니터링 설정
    struct Monitoring {
        static let enableCrashReporting = true      // 크래시 리포팅
        static let enableAnalytics = true           // 사용자 분석
        static let enablePerformanceMonitoring = true  // 성능 모니터링
        static let logRetentionDays = 7             // 로그 보관 일수
    }
    
    // MARK: - 🔧 편의 메서드
    
    /// 현재 설정 상태를 로그로 출력
    static func logCurrentSettings() {
        print("🔒 [AppConfig] 현재 앱 설정:")
        print("")
        print("🔒 [보안 설정]:")
        print("   📝 최대 프롬프트 길이: \(Security.maxPromptLength)글자")
        print("   📊 일일 최대 요청: \(Security.maxDailyRequests)회")
        print("   💬 최대 대화 턴: \(Security.maxConversationTurns)턴")
        print("   🚦 레이트 리미팅: \(Security.isRateLimitEnabled ? "활성화" : "비활성화")")
        print("")
        print("🤖 [AI 기능별 일일 제한]:")
        print("   💬 일반 채팅: \(AILimits.chat)회/일")
        print("   🎵 프리셋 추천: \(AILimits.presetRecommendation)회/일")
        print("   📔 일기 분석: \(AILimits.diaryAnalysis)회/일")
        print("   📊 월간 통계: \(AILimits.monthlyStatistics)회/일")
        print("   ✅ 할일 조언: \(AILimits.todoAdvice)회/일")
        print("   🔮 운세: \(AILimits.fortune)회/일")
        print("   😊 감정 분석: \(AILimits.emotionAnalysis)회/일")
        print("   📈 월간 리포트: \(AILimits.monthlyReport)회/일")
        print("")
        print("📝 [사용자 경험 제한]:")
        print("   📔 일기 작성: \(UserLimits.maxDiaryEntriesPerDay)개/일")
        print("   ✅ 할일 개수: \(UserLimits.maxTodoItems)개")
        print("   😊 감정 기록: \(UserLimits.maxEmotionEntriesPerDay)개/일")
        print("   💬 채팅 보관: \(UserLimits.maxChatHistoryDays)일")
        print("   📊 분석 보관: \(UserLimits.maxAnalysisHistoryDays)일")
        print("   🎵 프리셋 개수: \(UserLimits.maxPresetCount)개")
        print("")
        print("🎵 [오디오 설정]:")
        print("   🔊 기본 전역 볼륨: \(Audio.defaultGlobalVolume)")
        print("   🎚️ 기본 마스터 볼륨: \(Audio.defaultMasterVolume)")
        print("   📂 최대 카테고리: \(Audio.maxCategoryCount)개")
        print("")
        print("🐛 [개발 설정]:")
        print("   🐛 디버그 모드: \(Development.isDebugMode ? "활성화" : "비활성화")")
        print("   📋 상세 로깅: \(Development.isVerboseLogging ? "활성화" : "비활성화")")
        print("   🤖 모의 응답: \(Development.isMockAIResponses ? "활성화" : "비활성화")")
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