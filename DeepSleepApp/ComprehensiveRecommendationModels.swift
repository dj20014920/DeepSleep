import Foundation

// todo: 이 모델은 확장이 필요하며, 실제 데이터 요구사항에 맞춰 필드가 추가/수정되어야 합니다.
// 특히, 각 추천 결과에 대한 상세 정보(예: 음원 파일 경로, 태그 등)가 포함되어야 합니다.

/// 여러 AI 모델과 사용자 분석 데이터를 종합하여 생성된 최상위 추천 결과입니다.
///
/// 이 구조체는 가장 신뢰도 높은 주 추천(Primary Recommendation)과 함께
/// 대안 추천, 신뢰도 점수, 개인화 설명 등 다양한 컨텍스트 정보를 포함합니다.
public struct ComprehensiveRecommendation: Codable, Equatable {
    
    /// 추천 결과의 핵심 정보를 담는 구조체입니다.
    public struct RecommendationResult: Codable, Equatable {
        /// 추천된 사운드의 고유 ID
        public let soundId: String
        /// 이 사운드를 추천하는 이유 (일반 설명)
        public let reasoning: String
        /// 추천의 신뢰도 점수 (0.0 ~ 1.0)
        public let confidence: Double
        /// 사용자의 컨텍스트를 반영한 개인화된 추천 설명
        public let personalizedExplanation: String?
        
        /// 추가적인 상세 정보 (예: 음원 메타데이터)
        public let details: SoundMetadata? // `SoundMetadata`는 별도 정의 필요
        
        public struct SoundMetadata: Codable, Equatable {
            let duration: TimeInterval
            let format: String
            let artist: String?
        }
    }
    
    public let primaryRecommendation: RecommendationResult
    public let alternativeRecommendations: [RecommendationResult]
    public let overallConfidence: Float
    public let learningRecommendations: [String]
    public let processingMetadata: ProcessingMetadata
    public let adaptationLevel: String
    public let comprehensivenessScore: Float
    public let contextualInsights: [String]
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

// MARK: - 알림 이름 확장
extension NSNotification.Name {
    static let modelUpdated = NSNotification.Name("modelUpdated")
} 
