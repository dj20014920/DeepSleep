//
//  UnifiedRecommendationSystem.swift
//  DeepSleep
//
//  ⚠️ DEPRECATED: 이 파일은 SuperRecommendationEngine.swift로 통합되었습니다.
//  통합 추천 시스템 - 전략 패턴 기반 아키텍처
//  Created by Architecture Master on 2025-07-17.
//  Deprecated on 2025/07/17 - Use SuperRecommendationEngine instead
//

import Foundation
import Core

// MARK: - 🎯 통합 추천 시스템 프로토콜

/// 추천 컨텍스트를 정의하는 구조체
public struct RecommendationContext: Codable {
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

/// 추천 후보를 정의하는 구조체
public struct RecommendationCandidate: Codable, Identifiable {
    public let id: String
    public let type: RecommendationType
    public let content: RecommendationContent
    public let confidence: Float
    public let reasoning: [String]
    public let metadata: [String: Any]?
    
    public init(id: String, type: RecommendationType, content: RecommendationContent, confidence: Float, reasoning: [String], metadata: [String: Any]? = nil) {
        self.id = id
        self.type = type
        self.content = content
        self.confidence = confidence
        self.reasoning = reasoning
        self.metadata = metadata
    }
}

/// 추천 타입 열거형
public enum RecommendationType: String, CaseIterable, Codable {
    case soundPreset = "sound_preset"
    case activitySuggestion = "activity_suggestion"
    case emotionGuidance = "emotion_guidance"
    case userBehaviorPattern = "user_behavior_pattern"
}

/// 추천 콘텐츠 구조체
public struct RecommendationContent: Codable {
    public let title: String
    public let description: String
    public let actionParameters: [String: Any]?
    
    public init(title: String, description: String, actionParameters: [String: Any]? = nil) {
        self.title = title
        self.description = description
        self.actionParameters = actionParameters
    }
}

/// 최종 추천 결과
public struct UnifiedRecommendationResult: Codable {
    public let primaryRecommendation: RecommendationCandidate
    public let alternativeRecommendations: [RecommendationCandidate]
    public let totalCandidates: Int
    public let processingTimeMs: Int
    public let confidenceScore: Float
    public let strategyUsed: String
    
    public init(primaryRecommendation: RecommendationCandidate, alternativeRecommendations: [RecommendationCandidate], totalCandidates: Int, processingTimeMs: Int, confidenceScore: Float, strategyUsed: String) {
        self.primaryRecommendation = primaryRecommendation
        self.alternativeRecommendations = alternativeRecommendations
        self.totalCandidates = totalCandidates
        self.processingTimeMs = processingTimeMs
        self.confidenceScore = confidenceScore
        self.strategyUsed = strategyUsed
    }
}

// MARK: - 🧩 추천 전략 프로토콜

/// 추천 전략의 기본 프로토콜
public protocol RecommendationStrategy {
    var strategyName: String { get }
    var priority: Int { get }
    
    func canHandle(context: RecommendationContext) -> Bool
    func recommend(context: RecommendationContext) async throws -> [RecommendationCandidate]
}

// MARK: - 🎵 구체적 추천 전략들

/// 감정 기반 추천 전략
public final class EmotionBasedRecommendationStrategy: RecommendationStrategy {
    public let strategyName = "EmotionBased"
    public let priority = 100
    
    public func canHandle(context: RecommendationContext) -> Bool {
        return !context.emotion.isEmpty && context.intensity > 0.0
    }
    
    public func recommend(context: RecommendationContext) async throws -> [RecommendationCandidate] {
        // PERF-WARNING: 감정 분석 기반 추천은 CPU 집약적일 수 있음
        var candidates: [RecommendationCandidate] = []
        
        // 감정별 사운드 프리셋 매핑
        let emotionPresetMap: [String: [String]] = [
            "happy": ["기쁜-새소리", "밝은-피아노", "경쾌한-물소리"],
            "sad": ["평온한-비소리", "위로-현악기", "따뜻한-불소리"],
            "anxious": ["차분한-바다소리", "안정적-드론", "이완-명상"],
            "stressed": ["스트레스해소-자연음", "깊은-호흡가이드", "진정-클래식"],
            "tired": ["숙면-백색소음", "피로회복-바이노럴", "휴식-앰비언트"],
            "angry": ["분노해소-타악기", "정화-물소리", "균형-명상음악"],
            "neutral": ["균형-자연음", "중성-앰비언트", "일반-백색소음"]
        ]
        
        if let presets = emotionPresetMap[context.emotion.lowercased()] {
            for (index, preset) in presets.enumerated() {
                let confidence = Float(1.0 - Double(index) * 0.2) * context.intensity
                
                let candidate = RecommendationCandidate(
                    id: UUID().uuidString,
                    type: .soundPreset,
                    content: RecommendationContent(
                        title: preset,
                        description: "\\(context.emotion) 감정에 최적화된 사운드 프리셋",
                        actionParameters: ["presetId": preset, "intensity": context.intensity]
                    ),
                    confidence: confidence,
                    reasoning: ["감정 \\(context.emotion)에 최적화", "강도 \\(context.intensity) 반영"]
                )
                
                candidates.append(candidate)
            }
        }
        
        return candidates
    }
}

/// 시간 기반 추천 전략
public final class TimeBasedRecommendationStrategy: RecommendationStrategy {
    public let strategyName = "TimeBased"
    public let priority = 80
    
    public func canHandle(context: RecommendationContext) -> Bool {
        return true // 시간 컨텍스트는 항상 사용 가능
    }
    
    public func recommend(context: RecommendationContext) async throws -> [RecommendationCandidate] {
        var candidates: [RecommendationCandidate] = []
        
        let hour = Calendar.current.component(.hour, from: context.timeContext.currentTime)
        let timeBasedRecommendations: [String]
        
        switch hour {
        case 6...9:
            timeBasedRecommendations = ["아침-새소리", "활력-커피숍", "기상-밝은음악"]
        case 10...14:
            timeBasedRecommendations = ["집중-화이트노이즈", "생산성-미니멀", "오전-자연음"]
        case 15...18:
            timeBasedRecommendations = ["오후-카페음악", "에너지-업비트", "전환-클래식"]
        case 19...22:
            timeBasedRecommendations = ["저녁-재즈", "휴식-피아노", "마무리-현악기"]
        default:
            timeBasedRecommendations = ["숙면-백색소음", "깊은잠-바이노럴", "밤-명상음악"]
        }
        
        for (index, recommendation) in timeBasedRecommendations.enumerated() {
            let confidence = Float(0.8 - Double(index) * 0.15)
            
            let candidate = RecommendationCandidate(
                id: UUID().uuidString,
                type: .soundPreset,
                content: RecommendationContent(
                    title: recommendation,
                    description: "현재 시간대(\\(hour)시)에 최적화된 사운드",
                    actionParameters: ["presetId": recommendation, "timeOfDay": hour]
                ),
                confidence: confidence,
                reasoning: ["시간대 \\(hour)시에 최적화", "시간 기반 패턴 분석"]
            )
            
            candidates.append(candidate)
        }
        
        return candidates
    }
}

/// 히스토리 기반 추천 전략
public final class HistoryBasedRecommendationStrategy: RecommendationStrategy {
    public let strategyName = "HistoryBased"
    public let priority = 90
    
    public func canHandle(context: RecommendationContext) -> Bool {
        return !context.feedbackHistory.isEmpty
    }
    
    public func recommend(context: RecommendationContext) async throws -> [RecommendationCandidate] {
        // PERF-WARNING: 피드백 히스토리 분석은 메모리 집약적일 수 있음
        var candidates: [RecommendationCandidate] = []
        
        // 피드백 히스토리에서 높은 평점을 받은 프리셋들 분석
        let positivePresets = context.feedbackHistory
            .filter { $0.overallScore >= 4.0 }
            .prefix(5)
        
        for feedback in positivePresets {
            let confidence = Float(feedback.overallScore / 5.0) * 0.9
            
            let candidate = RecommendationCandidate(
                id: UUID().uuidString,
                type: .soundPreset,
                content: RecommendationContent(
                    title: feedback.presetId,
                    description: "이전에 높은 평가를 받은 프리셋 (평점: \\(feedback.overallScore))",
                    actionParameters: ["presetId": feedback.presetId, "previousScore": feedback.overallScore]
                ),
                confidence: confidence,
                reasoning: ["이전 사용자 피드백 긍정적", "평점 \\(feedback.overallScore)/5.0"]
            )
            
            candidates.append(candidate)
        }
        
        return candidates
    }
}

// MARK: - 🎯 통합 추천 엔진

/// 통합 추천 엔진 - 모든 추천 로직을 통합 관리
public final class UnifiedRecommendationEngine {
    
    public static let shared = UnifiedRecommendationEngine()
    
    private var strategies: [RecommendationStrategy] = []
    
    private init() {
        setupStrategies()
    }
    
    private func setupStrategies() {
        strategies = [
            EmotionBasedRecommendationStrategy(),
            TimeBasedRecommendationStrategy(),
            HistoryBasedRecommendationStrategy()
        ].sorted { $0.priority > $1.priority }
    }
    
    /// 메인 추천 메서드
    public func getRecommendation(for context: RecommendationContext) async throws -> UnifiedRecommendationResult {
        let startTime = Date()
        
        var allCandidates: [RecommendationCandidate] = []
        var usedStrategies: [String] = []
        
        // 각 전략을 사용하여 추천 후보들 수집
        for strategy in strategies {
            if strategy.canHandle(context: context) {
                do {
                    let candidates = try await strategy.recommend(context: context)
                    allCandidates.append(contentsOf: candidates)
                    usedStrategies.append(strategy.strategyName)
                } catch {
                    print("⚠️ 전략 \\(strategy.strategyName) 실행 실패: \\(error)")
                }
            }
        }
        
        // 후보들을 신뢰도 순으로 정렬
        allCandidates.sort { $0.confidence > $1.confidence }
        
        // 최고 추천과 대안들 분리
        guard let primaryRecommendation = allCandidates.first else {
            throw RecommendationError.noRecommendationsGenerated
        }
        
        let alternativeRecommendations = Array(allCandidates.dropFirst().prefix(4))
        
        let processingTime = Int(Date().timeIntervalSince(startTime) * 1000)
        let overallConfidence = allCandidates.isEmpty ? 0.0 : allCandidates.map { $0.confidence }.reduce(0, +) / Float(allCandidates.count)
        
        return UnifiedRecommendationResult(
            primaryRecommendation: primaryRecommendation,
            alternativeRecommendations: alternativeRecommendations,
            totalCandidates: allCandidates.count,
            processingTimeMs: processingTime,
            confidenceScore: overallConfidence,
            strategyUsed: usedStrategies.joined(separator: ", ")
        )
    }
    
    /// 전략 추가
    public func addStrategy(_ strategy: RecommendationStrategy) {
        strategies.append(strategy)
        strategies.sort { $0.priority > $1.priority }
    }
    
    /// 전략 제거
    public func removeStrategy(named strategyName: String) {
        strategies.removeAll { $0.strategyName == strategyName }
    }
}

// MARK: - 🚨 에러 타입

public enum RecommendationError: Error, LocalizedError {
    case noRecommendationsGenerated
    case invalidContext
    case strategyNotFound
    
    public var errorDescription: String? {
        switch self {
        case .noRecommendationsGenerated:
            return "추천을 생성할 수 없습니다"
        case .invalidContext:
            return "잘못된 추천 컨텍스트입니다"
        case .strategyNotFound:
            return "요청된 추천 전략을 찾을 수 없습니다"
        }
    }
}

// MARK: - 🔧 유틸리티 확장

extension RecommendationCandidate {
    /// 신뢰도 기반 색상 반환
    public var confidenceColor: String {
        switch confidence {
        case 0.8...1.0: return "green"
        case 0.6..<0.8: return "yellow"
        case 0.4..<0.6: return "orange"
        default: return "red"
        }
    }
    
    /// 추천 강도 텍스트
    public var strengthText: String {
        switch confidence {
        case 0.8...1.0: return "강력 추천"
        case 0.6..<0.8: return "추천"
        case 0.4..<0.6: return "보통"
        default: return "약한 추천"
        }
    }
}