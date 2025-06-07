import Foundation
import CoreLocation
import UIKit

// MARK: - 🧠 Enterprise-Grade AI Data Models

/// 고도화된 감정 데이터 모델 (Google/Meta 수준)
struct EnhancedEmotion: Codable {
    let id: UUID
    let emotion: String                    // 기본 감정
    let intensity: Float                   // 0.0-1.0 강도
    let confidence: Float                  // AI 분석 신뢰도
    let triggers: [String]                 // 감정 유발 요인들
    let physicalSymptoms: [String]         // 신체 증상
    let cognitiveState: CognitiveState     // 인지 상태
    let socialContext: SocialContext       // 사회적 맥락
    let timestamp: Date
    
    struct CognitiveState: Codable {
        let focus: Float           // 집중도 0-1
        let energy: Float          // 에너지 수준 0-1
        let motivation: Float      // 동기 수준 0-1
        let clarity: Float         // 정신적 명료도 0-1
    }
    
    struct SocialContext: Codable {
        let isAlone: Bool
        let socialActivity: String?    // "가족시간", "업무미팅", "친구만남" 등
        let communicationMode: String? // "대화", "텍스트", "혼자" 등
    }
    
    /// 감정 복합도 계산 (여러 감정 동시 존재)
    var complexityScore: Float {
        return triggers.count > 1 ? min(1.0, Float(triggers.count) * 0.2) : 0.0
    }
    
    /// 전체적 웰빙 점수
    var wellbeingScore: Float {
        let positiveEmotions = ["😊", "😄", "🥰", "🙂"]
        let baseScore = positiveEmotions.contains(emotion) ? intensity : (1.0 - intensity)
        let cognitiveBonus = (cognitiveState.focus + cognitiveState.energy + cognitiveState.motivation + cognitiveState.clarity) / 4.0 * 0.3
        return min(1.0, baseScore + cognitiveBonus)
    }
}

/// Netflix/Spotify 스타일 프리셋 피드백 시스템
struct PresetFeedback: Codable {
    let id: UUID
    let presetId: UUID
    let userId: String                     // 익명화된 사용자 ID
    let sessionId: UUID                    // 세션 추적
    
    // 📊 정량적 피드백 (5점 척도 → 0.0-1.0 변환)
    let effectiveness: Float               // 0.0-1.0 효과성
    let relaxation: Float                 // 0.0-1.0 이완 정도
    let focus: Float                      // 0.0-1.0 집중도 향상
    let sleepQuality: Float               // 0.0-1.0 수면 품질 (해당시)
    let overallSatisfaction: Float        // 0.0-1.0 전체 만족도
    
    // 🎯 사용 컨텍스트
    let usageDuration: TimeInterval       // 실제 사용 시간
    let intentionalStop: Bool             // 의도적 중단 vs 자연 종료
    let repeatUsage: Bool                 // 같은 세션에서 재사용
    let deviceContext: DeviceContext      // 기기 사용 환경
    let environmentContext: EnvironmentContext // 물리적 환경
    
    // 📝 정성적 피드백
    let tags: [String]                    // "너무시끄러움", "완벽함", "졸림" 등
    let preferredAdjustments: [String]    // "고양이소리 더", "바람소리 줄임" 등
    let moodAfter: String                 // 사용 후 감정
    let wouldRecommend: Bool              // 타인 추천 의향
    
    let timestamp: Date
    
    struct DeviceContext: Codable {
        let volume: Float                 // 시스템 볼륨
        let brightness: Float             // 화면 밝기
        let batteryLevel: Float           // 배터리 수준
        let deviceOrientation: String     // 기기 방향
        let headphonesConnected: Bool     // 헤드폰 연결 여부
    }
    
    struct EnvironmentContext: Codable {
        let lightLevel: String            // "어두움", "밝음", "보통"
        let noiseLevel: Float             // 0.0-1.0 주변 소음
        let weatherCondition: String?     // 날씨 (가능시)
        let location: String?             // "집", "사무실", "카페" 등 (일반화)
        let timeOfUse: String             // "아침", "점심", "저녁", "밤", "새벽"
    }
    
    /// 학습 가중치 계산 (최신 피드백일수록 높은 가중치)
    var learningWeight: Float {
        let daysSince = Date().timeIntervalSince(timestamp) / (24 * 3600)
        return max(0.1, exp(-Float(daysSince) / 30.0)) // 30일 반감기
    }
    
    /// 신뢰도 점수 (사용 시간과 완성도 기반)
    var reliabilityScore: Float {
        let durationScore = min(1.0, Float(usageDuration) / 600.0) // 10분 이상 사용시 최대 점수
        let completenessScore: Float = tags.isEmpty ? 0.5 : 1.0
        return (durationScore + completenessScore) / 2.0
    }
}

/// Amazon 스타일 사용 패턴 추적
struct UsagePattern: Codable {
    let id: UUID
    let sessionId: UUID
    let startTime: Date
    let endTime: Date
    
    // 📊 세션 메트릭
    let totalDuration: TimeInterval
    let activeDuration: TimeInterval      // 실제 활성 시간
    let pauseCount: Int                   // 일시정지 횟수
    let volumeAdjustments: Int            // 볼륨 조정 횟수
    let soundToggleCount: Int             // 음원 on/off 횟수
    
    // 🎵 음원 사용 패턴
    let soundUsage: [String: SoundUsageMetric] // 음원별 상세 사용
    let finalPreset: [Float]              // 최종 볼륨 상태
    let presetChanges: [PresetChange]     // 프리셋 변경 이력
    
    // 🧠 감정 변화 추적
    let emotionStart: EnhancedEmotion?    // 세션 시작 감정
    let emotionEnd: EnhancedEmotion?      // 세션 종료 감정
    
    // 🌍 컨텍스트 정보
    let userContext: UserContext
    let sessionType: SessionType
    let exitReason: ExitReason
    
    struct SoundUsageMetric: Codable {
        let averageVolume: Float
        let maxVolume: Float
        let timeActive: TimeInterval
        let adjustmentCount: Int
        let version: Int                  // 사용된 버전
    }
    
    struct PresetChange: Codable {
        let timestamp: Date
        let fromPreset: String?
        let toPreset: String
        let trigger: String               // "ai_recommendation", "manual", "mood_change"
    }
    
    struct UserContext: Codable {
        let activity: String              // "work", "sleep", "meditation", "study"
        let goal: String                  // "relaxation", "focus", "sleep", "anxiety_relief"
        let urgency: Float                // 0.0-1.0 긴급도
        let commitment: Float             // 0.0-1.0 몰입 의지
    }
    
    enum SessionType: String, Codable {
        case quickRelief = "빠른 완화"
        case deepSession = "깊은 세션"
        case background = "배경음"
        case sleep = "수면 유도"
        case meditation = "명상"
        case work = "업무 집중"
        case study = "학습"
    }
    
    enum ExitReason: String, Codable {
        case naturalCompletion = "자연 완료"
        case userStop = "사용자 중단"
        case interruption = "외부 방해"
        case deviceIssue = "기기 문제"
        case effectivenessConcern = "효과 부족"
        case tooStimulating = "과도한 자극"
        case perfectTiming = "완벽한 타이밍"
    }
    
    /// 세션 성공도 계산
    var sessionSuccessScore: Float {
        guard let emotionStart = emotionStart, let emotionEnd = emotionEnd else { return 0.5 }
        
        let emotionImprovement = emotionEnd.wellbeingScore - emotionStart.wellbeingScore
        let durationScore = min(1.0, Float(activeDuration) / Float(totalDuration))
        let completionBonus: Float = exitReason == .naturalCompletion ? 0.2 : 0.0
        
        return max(0.0, min(1.0, emotionImprovement + durationScore * 0.3 + completionBonus))
    }
    
    /// 재사용 가능성 예측
    var reusePredict: Float {
        let successWeight = sessionSuccessScore * 0.4
        let durationWeight = min(1.0, Float(activeDuration / 1800.0)) * 0.3 // 30분 기준
        let adjustmentPenalty = min(0.2, Float(volumeAdjustments) * 0.02)
        
        return max(0.0, min(1.0, successWeight + durationWeight - adjustmentPenalty))
    }
}

// MARK: - 🔧 Enterprise Data Manager

class EnhancedDataManager {
    static let shared = EnhancedDataManager()
    private init() {}
    
    // UserDefaults Keys
    private enum Keys {
        static let enhancedEmotions = "enhanced_emotions_v2"
        static let presetFeedbacks = "preset_feedbacks_v2"
        static let usagePatterns = "usage_patterns_v2"
        static let personalizationProfile = "personalization_profile_v2"
        static let experimentTracking = "experiment_tracking_v2"
    }
    
    // MARK: - 📊 Data Collection Methods
    
    /// 고도화된 감정 저장
    func saveEnhancedEmotion(_ emotion: EnhancedEmotion) {
        var emotions = loadEnhancedEmotions()
        emotions.append(emotion)
        
        // 최근 1000개만 유지 (메모리 최적화)
        if emotions.count > 1000 {
            emotions = Array(emotions.suffix(1000))
        }
        
        saveToUserDefaults(emotions, key: Keys.enhancedEmotions)
        
        // 실시간 학습 트리거
        triggerRealTimeLearning()
    }
    
    /// 프리셋 피드백 저장 (Netflix 스타일)
    func savePresetFeedback(_ feedback: PresetFeedback) {
        var feedbacks = loadPresetFeedbacks()
        feedbacks.append(feedback)
        
        // 최근 500개만 유지
        if feedbacks.count > 500 {
            feedbacks = Array(feedbacks.suffix(500))
        }
        
        saveToUserDefaults(feedbacks, key: Keys.presetFeedbacks)
        
        // 추천 모델 업데이트
        updateRecommendationModel(with: feedback)
    }
    
    /// 사용 패턴 저장 (Amazon 스타일)
    func saveUsagePattern(_ pattern: UsagePattern) {
        var patterns = loadUsagePatterns()
        patterns.append(pattern)
        
        // 최근 200개만 유지
        if patterns.count > 200 {
            patterns = Array(patterns.suffix(200))
        }
        
        saveToUserDefaults(patterns, key: Keys.usagePatterns)
    }
    
    // MARK: - 📈 Data Loading Methods
    
    func loadEnhancedEmotions() -> [EnhancedEmotion] {
        return loadFromUserDefaults(key: Keys.enhancedEmotions) ?? []
    }
    
    func loadPresetFeedbacks() -> [PresetFeedback] {
        return loadFromUserDefaults(key: Keys.presetFeedbacks) ?? []
    }
    
    func loadUsagePatterns() -> [UsagePattern] {
        return loadFromUserDefaults(key: Keys.usagePatterns) ?? []
    }
    
    // MARK: - 🧠 Advanced Analytics Methods
    
    /// 지난 N일간의 감정 트렌드 분석 (Google Analytics 스타일)
    func analyzeEmotionTrend(days: Int = 7) -> [String: Float] {
        let emotions = loadEnhancedEmotions()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recentEmotions = emotions.filter { $0.timestamp >= cutoffDate }
        
        var emotionCounts: [String: Float] = [:]
        var intensitySum: [String: Float] = [:]
        var confidenceSum: [String: Float] = [:]
        
        for emotion in recentEmotions {
            emotionCounts[emotion.emotion, default: 0] += 1
            intensitySum[emotion.emotion, default: 0] += emotion.intensity * emotion.confidence
            confidenceSum[emotion.emotion, default: 0] += emotion.confidence
        }
        
        var trends: [String: Float] = [:]
        for (emotion, count) in emotionCounts {
            let weightedIntensity = intensitySum[emotion]! / confidenceSum[emotion]!
            let frequency = Float(count) / Float(recentEmotions.count)
            trends[emotion] = weightedIntensity * frequency
        }
        
        return trends
    }
    
    /// 프리셋 효과성 분석 (Netflix 추천 알고리즘 스타일)
    func analyzePresetEffectiveness() -> [UUID: PresetEffectivenessMetric] {
        let feedbacks = loadPresetFeedbacks()
        var effectiveness: [UUID: (feedbacks: [PresetFeedback], totalWeight: Float)] = [:]
        
        for feedback in feedbacks {
            let current = effectiveness[feedback.presetId] ?? ([], 0)
            effectiveness[feedback.presetId] = (
                current.feedbacks + [feedback],
                current.totalWeight + feedback.learningWeight
            )
        }
        
        return effectiveness.mapValues { data in
            let weightedScore = data.feedbacks.reduce(0) { sum, feedback in
                return sum + (feedback.overallSatisfaction * feedback.learningWeight * feedback.reliabilityScore)
            }
            
            let confidenceScore = min(1.0, data.totalWeight / 10.0) // 10회 이상 피드백시 최대 신뢰도
            
            return PresetEffectivenessMetric(
                score: data.totalWeight > 0 ? weightedScore / data.totalWeight : 0.5,
                confidence: confidenceScore,
                sampleSize: data.feedbacks.count,
                lastUpdate: data.feedbacks.last?.timestamp ?? Date()
            )
        }
    }
    
    /// 개인화 추천 정확도 계산 (Spotify Discover Weekly 스타일)
    func calculatePersonalizationAccuracy() -> PersonalizationMetric {
        let recentFeedbacks = loadPresetFeedbacks().suffix(20)
        guard !recentFeedbacks.isEmpty else { 
            return PersonalizationMetric(accuracy: 0.5, confidence: 0.0, improvement: 0.0)
        }
        
        let weightedAccuracy = recentFeedbacks.reduce(0) { sum, feedback in
            return sum + (feedback.overallSatisfaction * feedback.reliabilityScore * feedback.learningWeight)
        }
        
        let totalWeight = recentFeedbacks.reduce(0) { sum, feedback in
            return sum + (feedback.reliabilityScore * feedback.learningWeight)
        }
        
        let accuracy = totalWeight > 0 ? weightedAccuracy / totalWeight : 0.5
        let confidence = min(1.0, Float(recentFeedbacks.count) / 20.0)
        
        // 이전 기간과 비교하여 개선도 계산
        let previousFeedbacks = loadPresetFeedbacks().dropLast(20).suffix(20)
        let previousAccuracy = previousFeedbacks.isEmpty ? 0.5 : 
            previousFeedbacks.reduce(0) { sum, feedback in
                return sum + feedback.overallSatisfaction
            } / Float(previousFeedbacks.count)
        
        let improvement = accuracy - previousAccuracy
        
        return PersonalizationMetric(
            accuracy: accuracy,
            confidence: confidence,
            improvement: improvement
        )
    }
    
    /// 실시간 추천 최적화 (Google RankBrain 스타일)
    func getOptimizedRecommendations(for context: RecommendationContext) -> [OptimizedRecommendation] {
        let emotionTrends = analyzeEmotionTrend(days: 7)
        let presetEffectiveness = analyzePresetEffectiveness()
        let usagePatterns = loadUsagePatterns().suffix(10)
        
        // 컨텍스트 기반 후보 필터링
        let candidates = SoundPresetCatalog.samplePresets.keys.map { presetName in
            return OptimizedRecommendation(
                presetName: presetName,
                contextScore: calculateContextScore(presetName, context: context),
                historicalScore: calculateHistoricalScore(presetName, effectiveness: presetEffectiveness),
                trendScore: calculateTrendScore(presetName, trends: emotionTrends),
                diversityBonus: calculateDiversityBonus(presetName, recentPatterns: Array(usagePatterns))
            )
        }
        
        // 종합 점수로 정렬하여 상위 3개 반환
        return candidates.sorted { $0.overallScore > $1.overallScore }.prefix(3).map { $0 }
    }
    
    // MARK: - 🔄 Real-time Learning Methods
    
    private func triggerRealTimeLearning() {
        // 실시간 감정 패턴 업데이트
        let recentEmotions = loadEnhancedEmotions().suffix(50)
        if recentEmotions.count >= 10 {
            updateEmotionPatternModel(emotions: Array(recentEmotions))
        }
    }
    
    private func updateRecommendationModel(with feedback: PresetFeedback) {
        // 피드백 기반 추천 모델 실시간 업데이트
        if feedback.overallSatisfaction < 0.3 {
            // 낮은 만족도 프리셋 패널티 적용
            applyNegativeFeedbackLearning(for: feedback.presetId)
        } else if feedback.overallSatisfaction > 0.8 {
            // 높은 만족도 프리셋 보상 적용
            applyPositiveFeedbackLearning(for: feedback.presetId)
        }
    }
    
    private func updateEmotionPatternModel(emotions: [EnhancedEmotion]) {
        // 감정 패턴 모델 업데이트
        // TODO: 감정 전이 확률 매트릭스 갱신
    }
    
    private func applyNegativeFeedbackLearning(for presetId: UUID) {
        // 부정적 피드백 학습
        // TODO: 추천 확률 감소 로직
    }
    
    private func applyPositiveFeedbackLearning(for presetId: UUID) {
        // 긍정적 피드백 학습
        // TODO: 추천 확률 증가 로직
    }
    
    // MARK: - 🎯 Helper Methods for Optimization
    
    private func calculateContextScore(_ presetName: String, context: RecommendationContext) -> Float {
        // 현재 컨텍스트와 프리셋의 적합도 계산
        // TODO: 시간, 감정, 환경 등을 종합한 점수
        return 0.5
    }
    
    private func calculateHistoricalScore(_ presetName: String, effectiveness: [UUID: PresetEffectivenessMetric]) -> Float {
        // 과거 효과성 기반 점수
        // TODO: 프리셋별 과거 성과 점수
        return 0.5
    }
    
    private func calculateTrendScore(_ presetName: String, trends: [String: Float]) -> Float {
        // 감정 트렌드 기반 점수
        // TODO: 현재 감정 트렌드와 프리셋의 연관성
        return 0.5
    }
    
    private func calculateDiversityBonus(_ presetName: String, recentPatterns: [UsagePattern]) -> Float {
        // 다양성 보너스 (최근에 사용하지 않은 프리셋에 보너스)
        let recentPresets = recentPatterns.flatMap { $0.presetChanges.map { $0.toPreset } }
        let timesUsedRecently = recentPresets.filter { $0.contains(presetName) }.count
        
        return max(0.0, 1.0 - Float(timesUsedRecently) * 0.2)
    }
    
    // MARK: - 💾 Private Helpers
    
    private func saveToUserDefaults<T: Codable>(_ data: T, key: String) {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    private func loadFromUserDefaults<T: Codable>(key: String, type: T.Type = T.self) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(type, from: data) else {
            return nil
        }
        return decoded
    }
}

// MARK: - 📊 Supporting Data Structures

struct PresetEffectivenessMetric {
    let score: Float           // 0.0-1.0 효과성 점수
    let confidence: Float      // 0.0-1.0 신뢰도
    let sampleSize: Int        // 샘플 수
    let lastUpdate: Date       // 마지막 업데이트
}

struct PersonalizationMetric {
    let accuracy: Float        // 0.0-1.0 추천 정확도
    let confidence: Float      // 0.0-1.0 신뢰도
    let improvement: Float     // -1.0~1.0 개선도
}

struct RecommendationContext {
    let currentEmotion: EnhancedEmotion
    let timeOfDay: String
    let environment: String
    let recentActivity: String
    let urgency: Float
}

struct OptimizedRecommendation {
    let presetName: String
    let contextScore: Float
    let historicalScore: Float
    let trendScore: Float
    let diversityBonus: Float
    
    var overallScore: Float {
        return (contextScore * 0.4 + historicalScore * 0.3 + trendScore * 0.2 + diversityBonus * 0.1)
    }
} 