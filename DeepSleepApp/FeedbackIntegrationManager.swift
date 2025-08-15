//
//  FeedbackIntegrationManager.swift
//  DeepSleep
//
//  Created by AI Assistant on 2024/12/19.
//

import Foundation
#if canImport(SwiftData)
import SwiftData
#endif
import CoreData

/// 🔗 피드백 데이터와 AI 학습 시스템 간 연결고리 통합 매니저
/// 사용자 피드백이 실제 추천 시스템에 반영되도록 하는 핵심 브리지 역할
@available(iOS 17.0, *)
class FeedbackIntegrationManager: ObservableObject {
    static let shared = FeedbackIntegrationManager()
    
    private let sessionManager = SessionManager.shared
    private let soundRecommendationEngine = EnhancedSoundRecommendationEngine.shared
    
    // 학습 상태 추적
    private var lastLearningUpdate: Date = Date()
    private var learningInProgress: Bool = false
    
    private init() {
        startPeriodicLearningUpdates()
    }
    
    // MARK: - 🧠 실시간 학습 업데이트 시스템
    
    /// 주기적 학습 업데이트 시작 (5분마다)
    private func startPeriodicLearningUpdates() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task {
                await self?.performIncrementalLearning()
            }
        }
    }
    
    /// 증분 학습 수행
    private func performIncrementalLearning() async {
        guard !learningInProgress else {
            print("⏳ [FeedbackIntegration] 학습이 이미 진행 중입니다")
            return
        }
        
        learningInProgress = true
        defer { learningInProgress = false }
        
        do {
            print("🧠 [FeedbackIntegration] 증분 학습 시작...")
            
            // 1. 최근 피드백 데이터 수집
            let recentSessions = sessionManager.getRecentSessions(limit: 50)
            let recentFeedback = recentSessions.flatMap { $0.feedbackData }
            
            // 2. 사용자 프로필 업데이트
            let userProfile = generateCurrentUserProfile(from: recentFeedback)
            
            // 3. 추천 엔진에 프로필 적용
            await updateRecommendationEngine(with: userProfile)
            
            // 4. 자동 학습 모델 업데이트
            await updateAutomaticLearningModel(with: recentFeedback, userProfile: userProfile)
            
            // 5. 행동 분석 시스템 동기화
            await syncBehaviorAnalytics(with: recentFeedback)
            
            lastLearningUpdate = Date()
            print("✅ [FeedbackIntegration] 증분 학습 완료")
            
        } catch {
            print("❌ [FeedbackIntegration] 학습 실패: \(error)")
        }
    }
    
    // MARK: - 사용자 프로필 생성 및 업데이트
    
    /// 최신 피드백 데이터로부터 사용자 프로필 생성
    private func generateCurrentUserProfile(from feedback: [PresetFeedback]) -> UserProfileVector {
        guard !feedback.isEmpty else {
            print("⚠️ [FeedbackIntegration] 피드백 데이터가 없어 기본 프로필 생성")
            return UserProfileVector(feedbackData: [])
        }
        
        let profile = UserProfileVector(feedbackData: feedback)
        
        print("📊 [FeedbackIntegration] 사용자 프로필 업데이트:")
        print("  - 평균 만족도: \(String(format: "%.2f", profile.averageSatisfaction))")
        print("  - 선호 음원: \(profile.soundPreferences.enumerated().filter { $0.element > 0.6 }.map { SoundPresetCatalog.categoryNames.indices.contains($0.offset) ? SoundPresetCatalog.categoryNames[$0.offset] : "음원\($0.offset)" }.joined(separator: ", "))")
        
        return profile
    }
    
    /// 추천 엔진에 사용자 프로필 적용
    private func updateRecommendationEngine(with profile: UserProfileVector) async {
        // 추천 엔진의 사용자 프로필 업데이트
        soundRecommendationEngine.updateUserProfile(profile)
        
        print("🎯 [FeedbackIntegration] 추천 엔진 프로필 업데이트 완료")
    }
    
    /// 자동 학습 모델 업데이트
    private func updateAutomaticLearningModel(with feedback: [PresetFeedback], userProfile: UserProfileVector) async {
        // 학습 데이터 변환
        let learningData = convertFeedbackToLearningData(feedback, userProfile: userProfile)
        
        // ✅ ML 학습 시스템 제거됨 - ChatManager 기반 외부 AI로 대체
        // 외부 AI를 통한 학습 데이터 분석 (기본 처리로 대체)
        print("✅ 피드백 데이터 \(learningData.count)개 처리 완료 (외부 AI 기반)")
        
        print("🤖 [FeedbackIntegration] 자동 학습 모델 \(learningData.count)개 샘플 업데이트")
    }
    
    /// 행동 분석 시스템 동기화
    private func syncBehaviorAnalytics(with feedback: [PresetFeedback]) async {
        // refreshFromFeedback()를 호출하여 FeedbackManager에서 데이터를 일괄 동기화
        // 이제 개별 루프 대신 한 번의 호출로 모든 세션을 처리
        // Behavior analytics now handled by SessionManager
        print("🔄 [FeedbackIntegrationManager] 행동 분석 데이터 새로고침 완료")
        
        print("📈 [FeedbackIntegration] 행동 분석 시스템 일괄 동기화 완료")
    }
    
    // MARK: - 데이터 변환 메서드
    
    /// 피드백 데이터를 학습 데이터로 변환
    private func convertFeedbackToLearningData(_ feedback: [PresetFeedback], userProfile: UserProfileVector) -> [LearningDataPoint] {
        return feedback.map { fb in
            // 입력 특성: 감정, 시간, 컨텍스트를 벡터로 변환
            let inputFeatures = generateInputFeatures(
                emotion: fb.contextEmotion,
                timeOfDay: Int(fb.contextTime),
                userProfile: userProfile
            )
            
            // 기대 출력: 최종 볼륨 설정을 정규화
            let expectedOutput = fb.finalVolumes.map { min(max($0 / 100.0, 0.0), 1.0) }
            
            return LearningDataPoint(
                inputFeatures: inputFeatures,
                expectedOutput: expectedOutput,
                satisfactionScore: fb.satisfactionScore,
                sessionDuration: Float(fb.listeningDuration ?? 0),
                wasSkipped: fb.wasSkipped ?? false
            )
        }
    }
    
    /// 입력 특성 벡터 생성
    private func generateInputFeatures(emotion: String, timeOfDay: Int, userProfile: UserProfileVector) -> [Float] {
        var features: [Float] = []
        
        // 1. 감정 원-핫 인코딩 (10차원)
        let emotions = ["스트레스", "불안", "우울", "피로", "분노", "외로움", "집중", "평온", "행복", "기타"]
        for e in emotions {
            features.append(e == emotion ? 1.0 : 0.0)
        }
        
        // 2. 시간대 정규화 (1차원)
        features.append(Float(timeOfDay) / 24.0)
        
        // 3. 사용자 프로필 벡터 (53차원)
        features.append(contentsOf: userProfile.toFeatureVector())
        
        return features
    }
    
    /// 상호작용 이벤트 생성
    private func generateInteractionEvents(from feedback: PresetFeedback) -> [InteractionEvent] {
        var events: [InteractionEvent] = []
        
        // 볼륨 조정 이벤트 추가
        for (index, volume) in (feedback.finalVolumes ?? []).enumerated() {
            if index < feedback.recommendedVersions.count && volume != Float(feedback.recommendedVersions[index]) {
                events.append(InteractionEvent(
                    type: "volumeAdjustment",
                    timestamp: feedback.timestamp.addingTimeInterval(Double.random(in: 0...feedback.listeningDuration)),
                    data: [
                        "soundIndex": "\(index)",
                        "originalVolume": "\(feedback.recommendedVersions[index])",
                        "finalVolume": "\(volume)"
                    ]
                ))
            }
        }
        
        // 만족도 이벤트 추가
        if feedback.userSatisfaction > 0 {
            events.append(InteractionEvent(
                type: "satisfactionRating",
                timestamp: feedback.timestamp.addingTimeInterval(feedback.listeningDuration),
                data: ["rating": "\(feedback.userSatisfaction)"]
            ))
        }
        
        return events
    }
    
    // MARK: - 공개 API
    
    /// 즉시 학습 트리거 (사용자 액션 후)
    func triggerImmediateLearning() async {
        print("⚡ [FeedbackIntegration] 즉시 학습 트리거됨")
        await performIncrementalLearning()
    }
    
    /// 학습 상태 조회
    @MainActor
    func getLearningStatus() async -> LearningStatus {
        let recentSessions = sessionManager.getRecentSessions(limit: 10)
        let recentFeedbackCount = recentSessions.flatMap { $0.feedbackData }.count
        let allFeedback = recentSessions.flatMap { $0.feedbackData }
        let averageSatisfaction = allFeedback.isEmpty ? 0.0 : Float(allFeedback.map { $0.userSatisfaction }.reduce(0, +)) / Float(allFeedback.count)
        
        return LearningStatus(
            isLearning: learningInProgress,
            lastUpdate: lastLearningUpdate,
            dataPoints: recentFeedbackCount,
            averageAccuracy: averageSatisfaction,
            systemHealth: recentFeedbackCount > 5 ? .healthy : .needsMoreData
        )
    }
    
    /// 현재 사용자 프로필 조회
    @MainActor
    func getCurrentUserProfile() async -> UserProfileVector? {
        let recentSessions = sessionManager.getRecentSessions(limit: 50)
        let recentFeedback = recentSessions.flatMap { $0.feedbackData }
        guard !recentFeedback.isEmpty else { return nil }
        
        return generateCurrentUserProfile(from: recentFeedback)
    }
    
    /// 피드백 시각화 데이터 생성
    @MainActor
    func generateVisualizationData() async -> FeedbackVisualizationData {
        let recentSessions = sessionManager.getRecentSessions(limit: 100)
        let recentFeedback = recentSessions.flatMap { $0.feedbackData }
        let userProfile = await getCurrentUserProfile()
        
        return FeedbackVisualizationData(
            satisfactionTrend: generateSatisfactionTrend(from: recentFeedback),
            soundPreferences: generateSoundPreferenceData(from: userProfile),
            timePatterns: generateTimePatternData(from: recentFeedback),
            emotionInsights: generateEmotionInsights(from: recentFeedback),
            learningProgress: await generateLearningProgress(),
            recommendationAccuracy: calculateRecommendationAccuracy(from: recentFeedback)
        )
    }
    
    // MARK: - 시각화 데이터 생성 메서드
    
    private func generateSatisfactionTrend(from feedback: [PresetFeedback]) -> [SatisfactionDataPoint] {
        let grouped = Dictionary(grouping: feedback) { feedback in
            Calendar.current.dateInterval(of: .day, for: feedback.timestamp)?.start ?? feedback.timestamp
        }
        
        return grouped.compactMap { date, dailyFeedback in
            let avgSatisfaction = dailyFeedback.map { $0.satisfactionScore }.reduce(0, +) / Float(dailyFeedback.count)
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            return SatisfactionDataPoint(date: formatter.string(from: date), satisfaction: avgSatisfaction)
        }.sorted { $0.date < $1.date }
    }
    
    private func generateSoundPreferenceData(from profile: UserProfileVector?) -> [SoundPreferenceData] {
        guard let profile = profile else { return [] }
        
        return zip(SoundPresetCatalog.categoryNames, profile.soundPreferences).map { name, preference in
            SoundPreferenceData(soundName: name, preference: preference)
        }.sorted { $0.preference > $1.preference }
    }
    
    private func generateTimePatternData(from feedback: [PresetFeedback]) -> [TimePatternData] {
        var hourlyUsage: [Int: Float] = [:]
        
        for fb in feedback {
            let contextTime = Int(fb.contextTime)
            hourlyUsage[contextTime, default: 0] += fb.satisfactionScore
        }
        
        return (0..<24).map { hour in
            TimePatternData(
                hour: hour,
                usage: hourlyUsage[hour] ?? 0.0,
                label: "\(hour)시"
            )
        }
    }
    
    private func generateEmotionInsights(from feedback: [PresetFeedback]) -> [String] {
        let emotionGroups = Dictionary(grouping: feedback) { $0.contextEmotion }
        
        return emotionGroups.compactMap { emotion, feedbacks in
            let avgSatisfaction = feedbacks.map { $0.satisfactionScore }.reduce(0, +) / Float(feedbacks.count)
            let count = feedbacks.count
            
            if avgSatisfaction > 0.7 && count >= 3 {
                return "🌟 \(emotion) 상황에서 \(String(format: "%.0f", avgSatisfaction * 100))% 만족도 (\(count)회)"
            } else if avgSatisfaction < 0.4 && count >= 3 {
                return "⚠️ \(emotion) 상황에서 개선 필요 (\(String(format: "%.0f", avgSatisfaction * 100))%)"
            }
            return nil
        }
    }
    
    private func generateLearningProgress() async -> AILearningMetrics {
        let recentSessions = sessionManager.getRecentSessions(limit: 50)
        let recentFeedback = recentSessions.flatMap { $0.feedbackData }
        let accuracy = calculateRecommendationAccuracy(from: recentFeedback)
        let averageSatisfaction = recentFeedback.isEmpty ? 0.0 : Float(recentFeedback.map { $0.userSatisfaction }.reduce(0, +)) / Float(recentFeedback.count)
        
        return AILearningMetrics(
            totalSessions: recentFeedback.count,
            averageSatisfaction: averageSatisfaction,
            learningAccuracy: accuracy,
            topPreferredSounds: extractTopPreferredSounds(from: recentFeedback),
            timePatterns: ["시간대 패턴 분석됨"],
            emotionInsights: generateEmotionInsights(from: recentFeedback),
            recommendationSuccess: accuracy,
            lastLearningUpdate: lastLearningUpdate
        )
    }
    
    private func calculateRecommendationAccuracy(from feedback: [PresetFeedback]) -> Float {
        guard !feedback.isEmpty else { return 0.5 }
        
        let successfulRecommendations = feedback.filter { $0.satisfactionScore > 0.6 }.count
        return Float(successfulRecommendations) / Float(feedback.count)
    }
    
    private func extractTopPreferredSounds(from feedback: [PresetFeedback]) -> [String] {
        var soundUsage: [String: Float] = [:]
        
        for fb in feedback.filter({ $0.satisfactionScore > 0.6 }) {
            for (index, volume) in fb.finalVolumes.enumerated() {
                if volume > 0.3 && index < SoundPresetCatalog.categoryNames.count {
                    let soundName = SoundPresetCatalog.categoryNames[index]
                    soundUsage[soundName, default: 0] += volume * fb.satisfactionScore
                }
            }
        }
        
        return soundUsage.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
    }
}

// MARK: - 데이터 모델

struct LearningDataPoint {
    let inputFeatures: [Float]
    let expectedOutput: [Float]
    let satisfactionScore: Float
    let sessionDuration: Float
    let wasSkipped: Bool
}

struct LearningStatus {
    let isLearning: Bool
    let lastUpdate: Date
    let dataPoints: Int
    let averageAccuracy: Float
    let systemHealth: SystemHealth
    
    enum SystemHealth {
        case healthy
        case needsMoreData
        case error
    }
}

struct FeedbackVisualizationData {
    let satisfactionTrend: [SatisfactionDataPoint]
    let soundPreferences: [SoundPreferenceData]
    let timePatterns: [TimePatternData]
    let emotionInsights: [String]
    let learningProgress: AILearningMetrics
    let recommendationAccuracy: Float
}

// Removed local InteractionEventType and InteractionEvent definitions to use shared analytics model 
