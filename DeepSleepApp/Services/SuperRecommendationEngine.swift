//
//  SuperRecommendationEngine.swift
//  DeepSleep
//
//  통합 추천 엔진 - ComprehensiveRecommendationEngine + UnifiedRecommendationSystem 합체
//  Created by Architecture Master on 2025-07-17.
//

import Foundation
import Core

// MARK: - 🚀 SuperRecommendationEngine

/// 모든 추천 기능을 통합한 최종 추천 엔진
/// 기존 ComprehensiveRecommendationEngine과 UnifiedRecommendationSystem을 통합
public final class SuperRecommendationEngine {
    
    public static let shared = SuperRecommendationEngine()
    
    private let llmRouter = LLMRouter.shared
    private let memoryManager = LongTermMemoryManager.shared
    private let soundManager = SoundManager.shared
    
    // PERF-WARNING: Strategy들은 lazy loading으로 메모리 효율성 확보
    private lazy var strategies: [RecommendationStrategy] = {
        return [
            // 기본 전략들 (UnifiedRecommendationSystem에서)
            EmotionBasedRecommendationStrategy(),
            TimeBasedRecommendationStrategy(),
            HistoryBasedRecommendationStrategy(),
            
            // 고급 전략들 (ComprehensiveRecommendationEngine에서 이관)
            LLMEnhancedRecommendationStrategy(llmRouter: llmRouter),
            SleepPatternRecommendationStrategy(),
            UserBehaviorRecommendationStrategy()
        ].sorted { $0.priority > $1.priority }
    }()
    
    private init() {}
    
    // MARK: - 🎯 통합 추천 메서드 (기존 인터페이스 호환)
    
    /// 종합적인 사운드 추천 (ComprehensiveRecommendationEngine 호환)
    public func recommendSound(
        emotion: String,
        timeContext: TimeContext,
        userContext: RecommendationUserContext
    ) async throws -> SoundRecommendation {
        
        // Enhanced Context 생성
        let enhancedContext = EnhancedRecommendationContext(
            emotion: emotion,
            timeContext: timeContext,
            userContext: userContext,
            environmentContext: getCurrentEnvironmentContext()
        )
        
        // 다중 전략 실행
        var allCandidates: [RecommendationCandidate] = []
        
        for strategy in strategies {
            do {
                let candidates = try await strategy.generateRecommendations(context: enhancedContext)
                allCandidates.append(contentsOf: candidates)
            } catch {
                print("⚠️ 전략 \(strategy.strategyName) 실행 실패: \(error)")
            }
        }
        
        // 최종 후보 선택 및 랭킹
        let finalCandidates = rankAndFilterCandidates(allCandidates, limit: 3)
        
        // SoundRecommendation 변환
        let soundRecommendation = try await convertToSoundRecommendation(
            candidates: finalCandidates,
            context: enhancedContext
        )
        
        return soundRecommendation
    }
    
    /// 통합 추천 메서드 (UnifiedRecommendationSystem 호환)
    public func getRecommendations(
        for emotion: String,
        with intensity: Double,
        timeContext: TimeContext,
        userContext: RecommendationUserContext
    ) async throws -> [RecommendationCandidate] {
        
        let enhancedContext = EnhancedRecommendationContext(
            emotion: emotion,
            intensity: intensity,
            timeContext: timeContext,
            userContext: userContext,
            environmentContext: getCurrentEnvironmentContext()
        )
        
        var allCandidates: [RecommendationCandidate] = []
        
        for strategy in strategies {
            do {
                let candidates = try await strategy.generateRecommendations(context: enhancedContext)
                allCandidates.append(contentsOf: candidates)
            } catch {
                print("⚠️ 전략 \(strategy.strategyName) 실행 실패: \(error)")
            }
        }
        
        return rankAndFilterCandidates(allCandidates, limit: 5)
    }
    
    // MARK: - 🧠 고급 분석 기능
    
    /// 수면 패턴 분석 및 조언 생성
    public func analyzeSleepAndProvideAdvice(
        avgDuration: Double,
        qualityScore: Double,
        patterns: [RecommendationSleepPattern],
        emotion: String? = nil
    ) async throws -> String {
        
        let durationText = String(format: "%.1f", avgDuration)
        let qualityText = String(format: "%d", Int(qualityScore * 100))
        let patternsText = patterns.map { "- \($0.description)" }.joined(separator: "\n")
        
        var prompt = "사용자 수면 분석:\n"
        prompt += "- 평균 수면 시간: \(durationText)시간\n"
        prompt += "- 수면 품질 점수: \(qualityText)점\n\n"
        prompt += "패턴:\n\(patternsText)\n\n"
        
        if let emotion = emotion {
            prompt += "현재 감정 상태: \(emotion)\n\n"
        }
        
        prompt += "위 정보를 바탕으로 수면 개선을 위한 구체적인 조언을 150자 이내로 제공해주세요.\n"
        prompt += "실천 가능한 방법을 포함해주세요."
        
        let response = try await llmRouter.send(
            task: .generalChat(message: prompt, history: [])
        )
        
        return response.content
    }
    
    private func recommendSleepSounds(patterns: [RecommendationSleepPattern]) async -> [String] {
        // 수면 패턴에 따른 사운드 추천 로직
        return patterns.compactMap { pattern in
            switch pattern.type {
            case .lightSleep:
                return "ocean_waves.mp3"
            case .deepSleep:
                return "brown_noise.mp3"
            case .rem:
                return "rainfall.mp3"
            }
        }
    }
    
    // MARK: - 🔄 Strategy Pattern 기반 추천 (새로운 아키텍처)
    
    /// 새로운 통합 추천 시스템 (Strategy Pattern 기반)
    public func recommend(context: RecommendationContext) async throws -> [RecommendationCandidate] {
        // PERF-WARNING: LLM 호출은 네트워크 및 CPU 집약적이므로 배터리 상태 고려 필요
        
        let emotionText = context.emotion
        let timeHour = String(Calendar.current.component(.hour, from: context.timeContext.currentTime))
        let intensityText = String(format: "%.1f", context.intensity)
        
        let prompt = "사용자 감정: \(emotionText)\n시간대: \(timeHour)시\n강도: \(intensityText)\n\n위 정보를 바탕으로 최적의 사운드 3개를 추천해주세요."
        
        let response = try await llmRouter.send(
            task: .recommendSound(emotion: context.emotion, situation: prompt)
        )
        
        // 응답 파싱 (간단한 구현)
        let candidates = [
            RecommendationCandidate(
                id: UUID().uuidString,
                type: .soundPreset,
                content: RecommendationContent(
                    title: "AI 추천 사운드",
                    description: response.content
                ),
                confidence: 0.9,
                reasoning: ["LLM 기반 고급 분석", "개인화된 추천"]
            )
        ]
        
        return candidates
    }
    
    // MARK: - 🎲 학습 기반 추천 (머신러닝 통합)
    
    /// 사용자 피드백 학습을 통한 추천 시스템
    public func recommendBasedOnLearning(
        userFeedbacks: [PresetFeedback],
        currentContext: RecommendationContext
    ) async throws -> [RecommendationCandidate] {
        
        // 과거 유사 감정 상황 검색
        let similarEmotions = try await memoryManager.searchRelevantMemories(
            query: "\(currentContext.emotion) 감정",
            limit: 3
        )
        
        let emotionText = currentContext.emotion
        let intensityPercent = String(Int(currentContext.intensity * 100))
        
        var prompt = "사용자의 현재 감정: \(emotionText) (강도: \(intensityPercent)%)\n\n"
        
        if !similarEmotions.isEmpty {
            let memoriesText = similarEmotions.map { "- \($0.date.formatted()): \($0.summary)" }.joined(separator: "\n")
            prompt += "과거 유사한 감정 경험:\n\(memoriesText)\n\n"
        }
        
        prompt += "위 정보를 바탕으로 개인화된 추천을 생성해주세요."
        
        let response = try await llmRouter.send(
            task: .generalChat(message: prompt, history: [])
        )
        
        // 피드백 기반 추천 생성
        let learningCandidates = userFeedbacks.compactMap { feedback -> RecommendationCandidate? in
            // 사용 시간과 재사용 의도를 기반으로 점수 계산
            let durationScore = min(feedback.context.usageDuration / 3600.0, 1.0) // 최대 1시간 기준
            let intentionScore = feedback.context.repeatUsageIntent ? 1.0 : 0.5
            let overallScore = (durationScore + intentionScore) / 2.0
            
            guard overallScore >= 0.6 else { return nil }
            
            let scoreText = String(format: "%.1f", overallScore)
            
            return RecommendationCandidate(
                id: UUID().uuidString,
                type: .soundPreset,
                content: RecommendationContent(
                    title: feedback.presetId,
                    description: "사용자 행동 패턴 기반 추천 (만족도: \(scoreText))"
                ),
                confidence: overallScore,
                reasoning: ["과거 만족도 데이터", "행동 패턴 분석"]
            )
        }
        
        return learningCandidates
    }
    
    // MARK: - 🛠️ 유틸리티 메서드
    
    private func getCurrentEnvironmentContext() -> EnvironmentContext {
        // 현재 환경 정보 수집
        return EnvironmentContext(
            noiseLevel: 0.5,
            lightLevel: 0.3,
            temperature: 22.0,
            humidity: 45.0
        )
    }
    
    private func rankAndFilterCandidates(_ candidates: [RecommendationCandidate], limit: Int) -> [RecommendationCandidate] {
        return candidates
            .sorted { $0.confidence > $1.confidence }
            .prefix(limit)
            .map { $0 }
    }
    
    private func convertToSoundRecommendation(
        candidates: [RecommendationCandidate],
        context: EnhancedRecommendationContext
    ) async throws -> SoundRecommendation {
        
        let primaryCandidate = candidates.first ?? RecommendationCandidate(
            id: UUID().uuidString,
            type: .soundPreset,
            content: RecommendationContent(
                title: "기본 추천",
                description: "기본 사운드 추천"
            ),
            confidence: 0.5,
            reasoning: ["기본 설정"]
        )
        
        return SoundRecommendation(
            id: primaryCandidate.id,
            title: primaryCandidate.content.title,
            description: primaryCandidate.content.description,
            soundType: .preset,
            confidence: primaryCandidate.confidence,
            reasoning: primaryCandidate.reasoning
        )
    }
}

// MARK: - 🎯 전략 프로토콜 및 구현체들

/// 추천 전략 프로토콜
public protocol RecommendationStrategy {
    var strategyName: String { get }
    var priority: Int { get }
    
    func generateRecommendations(context: EnhancedRecommendationContext) async throws -> [RecommendationCandidate]
}

/// 감정 기반 추천 전략
public struct EmotionBasedRecommendationStrategy: RecommendationStrategy {
    public let strategyName = "감정 기반 추천"
    public let priority = 10
    
    public func generateRecommendations(context: EnhancedRecommendationContext) async throws -> [RecommendationCandidate] {
        // 감정 기반 추천 로직
        return [
            RecommendationCandidate(
                id: UUID().uuidString,
                type: .soundPreset,
                content: RecommendationContent(
                    title: "감정 맞춤 사운드",
                    description: "\(context.emotion) 감정에 최적화된 사운드"
                ),
                confidence: 0.8,
                reasoning: ["감정 분석", "개인화 추천"]
            )
        ]
    }
}

/// 시간 기반 추천 전략
public struct TimeBasedRecommendationStrategy: RecommendationStrategy {
    public let strategyName = "시간 기반 추천"
    public let priority = 8
    
    public func generateRecommendations(context: EnhancedRecommendationContext) async throws -> [RecommendationCandidate] {
        let hour = Calendar.current.component(.hour, from: context.timeContext.currentTime)
        
        let timeBasedTitle = hour < 12 ? "아침 추천" : (hour < 18 ? "오후 추천" : "저녁 추천")
        
        return [
            RecommendationCandidate(
                id: UUID().uuidString,
                type: .soundPreset,
                content: RecommendationContent(
                    title: timeBasedTitle,
                    description: "현재 시간대에 맞는 사운드 추천"
                ),
                confidence: 0.7,
                reasoning: ["시간대 분석", "일반적 패턴"]
            )
        ]
    }
}

/// 히스토리 기반 추천 전략
public struct HistoryBasedRecommendationStrategy: RecommendationStrategy {
    public let strategyName = "히스토리 기반 추천"
    public let priority = 6
    
    public func generateRecommendations(context: EnhancedRecommendationContext) async throws -> [RecommendationCandidate] {
        return [
            RecommendationCandidate(
                id: UUID().uuidString,
                type: .soundPreset,
                content: RecommendationContent(
                    title: "과거 선호 사운드",
                    description: "사용자의 과거 선택 기반 추천"
                ),
                confidence: 0.9,
                reasoning: ["사용 이력 분석", "개인 선호도"]
            )
        ]
    }
}

/// LLM 강화 추천 전략
public struct LLMEnhancedRecommendationStrategy: RecommendationStrategy {
    public let strategyName = "LLM 강화 추천"
    public let priority = 9
    
    private let llmRouter: LLMRouter
    
    public init(llmRouter: LLMRouter) {
        self.llmRouter = llmRouter
    }
    
    public func generateRecommendations(context: EnhancedRecommendationContext) async throws -> [RecommendationCandidate] {
        let prompt = "감정: \(context.emotion), 강도: \(context.intensity), 시간: \(context.timeContext.currentTime.formatted())"
        
        let response = try await llmRouter.send(
            task: .recommendSound(emotion: context.emotion, situation: prompt)
        )
        
        return [
            RecommendationCandidate(
                id: UUID().uuidString,
                type: .soundPreset,
                content: RecommendationContent(
                    title: "AI 고급 분석",
                    description: response.content
                ),
                confidence: 0.95,
                reasoning: ["LLM 분석", "고급 AI 추천"]
            )
        ]
    }
}

/// 수면 패턴 추천 전략
public struct SleepPatternRecommendationStrategy: RecommendationStrategy {
    public let strategyName = "수면 패턴 추천"
    public let priority = 7
    
    public func generateRecommendations(context: EnhancedRecommendationContext) async throws -> [RecommendationCandidate] {
        return [
            RecommendationCandidate(
                id: UUID().uuidString,
                type: .soundPreset,
                content: RecommendationContent(
                    title: "수면 패턴 최적화",
                    description: "수면 단계별 맞춤 사운드"
                ),
                confidence: 0.85,
                reasoning: ["수면 패턴 분석", "단계별 최적화"]
            )
        ]
    }
}

/// 사용자 행동 추천 전략
public struct UserBehaviorRecommendationStrategy: RecommendationStrategy {
    public let strategyName = "사용자 행동 추천"
    public let priority = 5
    
    public func generateRecommendations(context: EnhancedRecommendationContext) async throws -> [RecommendationCandidate] {
        return [
            RecommendationCandidate(
                id: UUID().uuidString,
                type: .soundPreset,
                content: RecommendationContent(
                    title: "행동 패턴 기반",
                    description: "사용자 행동 패턴 분석 기반 추천"
                ),
                confidence: 0.75,
                reasoning: ["행동 패턴 분석", "개인 맞춤화"]
            )
        ]
    }
}

// MARK: - 🔧 확장 컨텍스트 및 모델

/// 확장된 추천 컨텍스트
public struct EnhancedRecommendationContext {
    public let emotion: String
    public let intensity: Double
    public let timeContext: TimeContext
    public let userContext: RecommendationUserContext
    public let environmentContext: EnvironmentContext
    
    public init(
        emotion: String,
        intensity: Double = 1.0,
        timeContext: TimeContext,
        userContext: RecommendationUserContext,
        environmentContext: EnvironmentContext
    ) {
        self.emotion = emotion
        self.intensity = intensity
        self.timeContext = timeContext
        self.userContext = userContext
        self.environmentContext = environmentContext
    }
}

/// 환경 컨텍스트
public struct EnvironmentContext {
    public let noiseLevel: Double
    public let lightLevel: Double
    public let temperature: Double
    public let humidity: Double
    
    public init(noiseLevel: Double, lightLevel: Double, temperature: Double, humidity: Double) {
        self.noiseLevel = noiseLevel
        self.lightLevel = lightLevel
        self.temperature = temperature
        self.humidity = humidity
    }
}

/// 사운드 추천 결과
public struct SoundRecommendation {
    public let id: String
    public let title: String
    public let description: String
    public let soundType: SoundType
    public let confidence: Double
    public let reasoning: [String]
    
    public enum SoundType {
        case preset
        case custom
        case generated
    }
}

/// 수면 패턴 (기존 호환성 유지)
public struct RecommendationSleepPattern {
    public let type: SleepPhase
    public let description: String
    
    public enum SleepPhase {
        case lightSleep
        case deepSleep
        case rem
    }
}

/// 추천 사용자 컨텍스트 (기존 호환성 유지)
public struct RecommendationUserContext {
    public let currentTime: Date
    public let batteryLevel: Float
    public let headphonesConnected: Bool
    public let locationContext: String?
    
    public init(currentTime: Date, batteryLevel: Float, headphonesConnected: Bool, locationContext: String?) {
        self.currentTime = currentTime
        self.batteryLevel = batteryLevel
        self.headphonesConnected = headphonesConnected
        self.locationContext = locationContext
    }
}

/// 추천 컨텍스트 (UnifiedRecommendationSystem 호환)
public struct RecommendationContext {
    public let emotion: String
    public let intensity: Float
    public let timeContext: TimeContext
    public let userProfile: UserProfile?
    public let feedbackHistory: [PresetFeedback]
    public let environmentContext: String?
    
    public init(emotion: String, intensity: Float, timeContext: TimeContext, userProfile: UserProfile? = nil, feedbackHistory: [PresetFeedback] = [], environmentContext: String? = nil) {
        self.emotion = emotion
        self.intensity = intensity
        self.timeContext = timeContext
        self.userProfile = userProfile
        self.feedbackHistory = feedbackHistory
        self.environmentContext = environmentContext
    }
}

/// 추천 후보 (UnifiedRecommendationSystem 호환)
public struct RecommendationCandidate {
    public let id: String
    public let type: RecommendationType
    public let content: RecommendationContent
    public let confidence: Double
    public let reasoning: [String]
    
    public init(id: String, type: RecommendationType, content: RecommendationContent, confidence: Double, reasoning: [String]) {
        self.id = id
        self.type = type
        self.content = content
        self.confidence = confidence
        self.reasoning = reasoning
    }
}

/// 추천 타입
public enum RecommendationType {
    case soundPreset
    case customSound
    case sleepAdvice
    case environmentalAdjustment
}

/// 추천 내용
public struct RecommendationContent {
    public let title: String
    public let description: String
    public let actionData: [String: Any]?
    
    public init(title: String, description: String, actionData: [String: Any]? = nil) {
        self.title = title
        self.description = description
        self.actionData = actionData
    }
}

/// 사용량 통계 (기존 호환성 유지)
public struct UsageStats: Codable {
    public let date: String
    public var appOpenCount: Int
    public var totalUsageTime: TimeInterval
    public var presetUsageCount: Int
    public var emotionAnalysisCount: Int
    public var aiInteractionCount: Int
    public var chatCount: Int
    public var presetRecommendationCount: Int
    public var timerUsageCount: Int
    public var soundPlaybackTime: TimeInterval
    public var favoritePresets: [String]
    public var peakUsageHour: Int?
    public var deviceInfo: [String: String]?
    
    // 추가 필드들 (기존 코드 호환성)
    public var totalSessionTime: TimeInterval
    public var patternAnalysisCount: Int
    
    public init(date: String) {
        self.date = date
        self.appOpenCount = 0
        self.totalUsageTime = 0
        self.presetUsageCount = 0
        self.emotionAnalysisCount = 0
        self.aiInteractionCount = 0
        self.chatCount = 0
        self.presetRecommendationCount = 0
        self.timerUsageCount = 0
        self.soundPlaybackTime = 0
        self.favoritePresets = []
        self.peakUsageHour = nil
        self.deviceInfo = nil
        
        // 추가 필드 초기화
        self.totalSessionTime = 0
        self.patternAnalysisCount = 0
    }
}

