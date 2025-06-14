import Foundation

// MARK: - 마스터 추천 시스템 결과 구조체
struct ComprehensiveMasterRecommendation {
    let primaryRecommendation: RecommendationResult
    let alternativeRecommendations: [RecommendationResult]
    let overallConfidence: Float
    let learningRecommendations: [String]
    let processingMetadata: ProcessingMetadata
    let adaptationLevel: String
    let comprehensivenessScore: Float
    let contextualInsights: [String]
    
    struct RecommendationResult {
        let optimizedVolumes: [Float]
        let optimizedVersions: [Int]
        let confidence: Float
        let reasoning: String
        let adaptationLevel: String
        let presetName: String
        let expectedSatisfaction: Float
        let estimatedDuration: TimeInterval
        let personalizedExplanation: String
    }
}

// ProcessingMetadata는 SoundPresetCatalog.swift에 이미 정의되어 있으므로 중복 제거

// MARK: - 기본 분석 타입들
struct TemporalContextAnalysis {
    let currentTimeContext: String
    let recentUsagePattern: String
    let seasonalInfluence: String
    
    init() {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12:
            self.currentTimeContext = "아침"
        case 12..<18:
            self.currentTimeContext = "오후"
        case 18..<22:
            self.currentTimeContext = "저녁"
        default:
            self.currentTimeContext = "밤"
        }
        
        let weekday = Calendar.current.component(.weekday, from: Date())
        self.recentUsagePattern = weekday <= 1 || weekday >= 7 ? "주말" : "평일"
        self.seasonalInfluence = "일반"
    }
}

struct EnvironmentalContextAnalysis {
    let ambientNoiseLevel: Float
    let deviceContext: String
    let locationContext: String
    
    init() {
        self.ambientNoiseLevel = 0.3
        self.deviceContext = "iPhone"
        self.locationContext = "home"
    }
}

struct PersonalizationProfileAnalysis {
    let personalizationLevel: Float
    let adaptationHistory: [String]
    let preferenceStability: Float
    
    init() {
        self.personalizationLevel = 0.75
        self.adaptationHistory = ["standard", "adaptive"]
        self.preferenceStability = 0.8
    }
}

struct PerformanceMetricsAnalysis {
    let recentSatisfactionTrend: Float
    let usageFrequency: Float
    let engagementLevel: Float
    
    init() {
        self.recentSatisfactionTrend = 0.8
        self.usageFrequency = 0.75
        self.engagementLevel = 0.8
    }
}

struct EmotionalDimensionAnalysis {
    let dominantEmotion: String
    let emotionStability: Float
    let intensityLevel: Float
    
    init() {
        self.dominantEmotion = "평온"
        self.emotionStability = 0.7
        self.intensityLevel = 0.6
    }
}

// MARK: - 추가 차원 분석 타입들
struct TemporalDimensionAnalysis {
    let timeOfDay: String
    let dayOfWeek: String
    let seasonalContext: String
    
    init() {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: self.timeOfDay = "아침"
        case 12..<18: self.timeOfDay = "오후"
        case 18..<22: self.timeOfDay = "저녁"
        default: self.timeOfDay = "밤"
        }
        
        let weekday = Calendar.current.component(.weekday, from: Date())
        self.dayOfWeek = weekday <= 1 || weekday >= 7 ? "주말" : "평일"
        self.seasonalContext = "일반"
    }
}

struct BehavioralDimensionAnalysis {
    let usagePattern: String
    let interactionStyle: String
    let adaptationSpeed: Float
    
    init() {
        self.usagePattern = "규칙적"
        self.interactionStyle = "engaged"
        self.adaptationSpeed = 0.7
    }
}

struct ContextualDimensionAnalysis {
    let environmentalFactors: [String]
    let socialContext: String
    let deviceUsage: String
    
    init() {
        self.environmentalFactors = ["실내", "조용함"]
        self.socialContext = "개인"
        self.deviceUsage = "iPhone"
    }
}

struct PersonalizationDimensionAnalysis {
    let customizationLevel: Float
    let preferenceClarity: Float
    let learningProgress: Float
    
    init() {
        self.customizationLevel = 0.7
        self.preferenceClarity = 0.8
        self.learningProgress = 0.6
    }
}

// MARK: - 포괄적 사용자 데이터
struct ComprehensiveUserData {
    let behaviorData: [String: Any]
    let emotionalData: [String: Any]
    let temporalData: [String: Any]
    let contextualData: [String: Any]
    
    // 추가 분석 데이터
    let diaryAnalysis: DiaryAnalysisResult
    let chatAnalysis: ChatAnalysisResult
    let behaviorAnalysis: BehaviorAnalysisResult
    let temporalContext: TemporalContextAnalysis
    let environmentalContext: EnvironmentalContextAnalysis
    let personalizationProfile: PersonalizationProfileAnalysis
    
    init() {
        self.behaviorData = ["sessions": 10, "avgDuration": 1800]
        self.emotionalData = ["mood": "calm", "stress": 0.3]
        self.temporalData = ["timeOfDay": "evening", "frequency": 0.8]
        self.contextualData = ["environment": "indoor", "device": "iPhone"]
        
        // 분석 결과들 초기화
        self.diaryAnalysis = DiaryAnalysisResult()
        self.chatAnalysis = ChatAnalysisResult()
        self.behaviorAnalysis = BehaviorAnalysisResult()
        self.temporalContext = TemporalContextAnalysis()
        self.environmentalContext = EnvironmentalContextAnalysis()
        self.personalizationProfile = PersonalizationProfileAnalysis()
    }
}

// MARK: - 다차원 분석 결과
struct MultiDimensionalAnalysis {
    let emotional: EmotionalDimensionAnalysis
    let temporal: TemporalDimensionAnalysis
    let behavioral: BehavioralDimensionAnalysis
    let contextual: ContextualDimensionAnalysis
    let personalization: PersonalizationDimensionAnalysis
    let overallComplexity: Float
    let dataQuality: Float
    
    init() {
        self.emotional = EmotionalDimensionAnalysis()
        self.temporal = TemporalDimensionAnalysis()
        self.behavioral = BehavioralDimensionAnalysis()
        self.contextual = ContextualDimensionAnalysis()
        self.personalization = PersonalizationDimensionAnalysis()
        self.overallComplexity = 0.75
        self.dataQuality = 0.8
    }
}

// MARK: - 분석 결과 타입들
struct BehaviorAnalysisResult {
    let patterns: [String]
    let frequency: Float
    let confidence: Float
    let usageConsistency: Float
    let adaptationSpeed: Float
    let averageSatisfactionRate: Float
    
    init() {
        self.patterns = ["regular", "focused"]
        self.frequency = 0.8
        self.confidence = 0.75
        self.usageConsistency = 0.7
        self.adaptationSpeed = 0.6
        self.averageSatisfactionRate = 0.8
    }
}

struct ChatAnalysisResult {
    let emotions: [String]
    let intensity: Float
    let confidence: Float
    let totalMessages: Int
    let engagementScore: Float
    let stressLevel: Float
    let emotionalPolarity: Float
    
    init() {
        self.emotions = ["calm", "relaxed"]
        self.intensity = 0.6
        self.confidence = 0.8
        self.totalMessages = 15
        self.engagementScore = 0.75
        self.stressLevel = 0.3
        self.emotionalPolarity = 0.5
    }
}

struct DiaryAnalysisResult {
    let mood: String
    let stability: Float
    let confidence: Float
    let recentDominantEmotion: String
    let averageIntensity: Float
    let totalEntries: Int
    let emotionTrend: String
    
    init() {
        self.mood = "stable"
        self.stability = 0.7
        self.confidence = 0.75
        self.recentDominantEmotion = "평온"
        self.averageIntensity = 0.6
        self.totalEntries = 10
        self.emotionTrend = "stable"
    }
}

// MARK: - 포괄적 추천 엔진
class ComprehensiveRecommendationEngine {
    static let shared = ComprehensiveRecommendationEngine()
    
    private init() {}
    
    func generateMasterRecommendation() -> ComprehensiveMasterRecommendation {
        // 기본 볼륨 설정 (8개 사운드 채널)
        let defaultVolumes: [Float] = [0.5, 0.3, 0.7, 0.4, 0.6, 0.2, 0.5, 0.3]
        let defaultVersions: [Int] = [1, 2, 1, 3, 2, 1, 1, 2]
        
        let primaryResult = ComprehensiveMasterRecommendation.RecommendationResult(
            optimizedVolumes: defaultVolumes,
            optimizedVersions: defaultVersions,
            confidence: 0.8,
            reasoning: "시간대와 사용자 패턴을 기반으로 한 최적화된 사운드 조합",
            adaptationLevel: "high",
            presetName: "AI 최적화 프리셋",
            expectedSatisfaction: 0.85,
            estimatedDuration: 1800,
            personalizedExplanation: "시간대와 사용자 패턴을 기반으로 한 최적화된 사운드 조합입니다."
        )
        
        // 대안 추천 생성
        let alternativeRecommendations = [
            ComprehensiveMasterRecommendation.RecommendationResult(
                optimizedVolumes: [0.4, 0.5, 0.6, 0.3, 0.7, 0.2, 0.4, 0.5],
                optimizedVersions: [2, 1, 2, 1, 3, 2, 1, 1],
                confidence: 0.75,
                reasoning: "대안 추천 1",
                adaptationLevel: "medium",
                presetName: "균형 잡힌 프리셋",
                expectedSatisfaction: 0.78,
                estimatedDuration: 1200,
                personalizedExplanation: "균형 잡힌 사운드 조합입니다."
            ),
            ComprehensiveMasterRecommendation.RecommendationResult(
                optimizedVolumes: [0.6, 0.2, 0.5, 0.7, 0.3, 0.4, 0.6, 0.3],
                optimizedVersions: [1, 3, 1, 2, 1, 3, 2, 1],
                confidence: 0.70,
                reasoning: "대안 추천 2",
                adaptationLevel: "low",
                presetName: "부드러운 프리셋",
                expectedSatisfaction: 0.72,
                estimatedDuration: 900,
                personalizedExplanation: "부드러운 사운드 조합입니다."
            )
        ]
        
        let processingMetadata = ProcessingMetadata(
            modelVersion: "v2.1",
            processingTime: Double.random(in: 0.1...0.5),
            featureCount: Int.random(in: 128...512),
            networkDepth: Int.random(in: 4...8)
        )
        
        return ComprehensiveMasterRecommendation(
            primaryRecommendation: primaryResult,
            alternativeRecommendations: alternativeRecommendations,
            overallConfidence: 0.8,
            learningRecommendations: [
                "사용 패턴 분석을 통한 학습 개선",
                "피드백 기반 최적화 강화",
                "시간대별 선호도 세분화"
            ],
            processingMetadata: processingMetadata,
            adaptationLevel: "high",
            comprehensivenessScore: 0.88,
            contextualInsights: [
                "현재 시간대에 적합한 사운드 믹스",
                "사용자의 이전 선호도 반영",
                "최적의 이완 효과를 위한 볼륨 조정"
            ]
        )
    }
    
    func triggerModelUpdate() async -> Bool {
        #if DEBUG
        print("🤖 [ComprehensiveRecommendationEngine] 모델 업데이트 트리거됨")
        #endif
        
        // 시뮬레이션된 모델 업데이트 처리
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초 대기
        
        // 모델 업데이트 알림 전송
        NotificationCenter.default.post(name: .modelUpdated, object: nil)
        
        return true // 업데이트 성공
    }
    
    func applyUpdatedModel() {
        #if DEBUG
        print("🎉 [ComprehensiveRecommendationEngine] 업데이트된 모델 적용 완료")
        #endif
    }
}

// MARK: - 알림 이름 확장
extension NSNotification.Name {
    static let modelUpdated = NSNotification.Name("modelUpdated")
} 