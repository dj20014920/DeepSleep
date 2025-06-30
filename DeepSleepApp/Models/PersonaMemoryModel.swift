import Foundation
import SwiftData

/// 사용자 페르소나 정보를 저장하는 모델
@available(iOS 17.0, *)
@Model
final class UserPersona {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    
    // 기본 정보
    var name: String
    var preferredName: String // 호칭 선호도
    var age: Int?
    var occupation: String?
    var location: String?
    
    // 성격 및 선호도
    var personalityTraits: [String] // ["친근한", "전문적인", "유머러스한"]
    var communicationStyle: String // "격식있는", "친근한", "간결한"
    var interests: [String]
    var goals: [String]
    var values: [String]
    
    // AI 상호작용 선호도
    var preferredAIPersonality: String // "친근한 친구", "전문 어시스턴트", "현명한 조언자"
    var responseStyle: String // "상세한", "간결한", "단계별"
    var emotionalTone: String // "따뜻한", "중립적인", "격려하는"
    
    // 학습 선호도
    var learningStyle: String // "시각적", "청각적", "실습형"
    var feedbackPreference: String // "즉시", "요약형", "상세형"
    
    // 프라이버시 설정
    var memoryRetentionDays: Int // 기억 보존 기간
    var allowPersonalization: Bool
    var shareInsights: Bool
    
    init(
        name: String = "사용자",
        preferredName: String = "사용자",
        personalityTraits: [String] = [],
        communicationStyle: String = "친근한",
        interests: [String] = [],
        goals: [String] = [],
        values: [String] = [],
        preferredAIPersonality: String = "친근한 친구",
        responseStyle: String = "상세한",
        emotionalTone: String = "따뜻한",
        learningStyle: String = "시각적",
        feedbackPreference: String = "즉시",
        memoryRetentionDays: Int = 30,
        allowPersonalization: Bool = true,
        shareInsights: Bool = true
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.name = name
        self.preferredName = preferredName
        self.personalityTraits = personalityTraits
        self.communicationStyle = communicationStyle
        self.interests = interests
        self.goals = goals
        self.values = values
        self.preferredAIPersonality = preferredAIPersonality
        self.responseStyle = responseStyle
        self.emotionalTone = emotionalTone
        self.learningStyle = learningStyle
        self.feedbackPreference = feedbackPreference
        self.memoryRetentionDays = memoryRetentionDays
        self.allowPersonalization = allowPersonalization
        self.shareInsights = shareInsights
    }
    
    func updateTimestamp() {
        self.updatedAt = Date()
    }
}

/// 대화 기억을 저장하는 모델
@available(iOS 17.0, *)
@Model
final class ConversationMemory {
    var id: UUID
    var createdAt: Date
    var lastAccessedAt: Date
    
    var topic: String
    var summary: String
    var keyPoints: [String]
    var emotionalContext: String
    var importance: Double // 0.0 - 1.0
    var category: String // "personal", "work", "hobby", "learning"
    
    // 벡터 임베딩 (나중에 벡터 검색용)
    var embedding: [Float]?
    
    // 연관 태그
    var tags: [String]
    
    // 사용자 반응
    var userSatisfaction: Double? // 0.0 - 1.0
    var userFeedback: String?
    
    init(
        topic: String,
        summary: String,
        keyPoints: [String] = [],
        emotionalContext: String = "neutral",
        importance: Double = 0.5,
        category: String = "general",
        tags: [String] = []
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.lastAccessedAt = Date()
        self.topic = topic
        self.summary = summary
        self.keyPoints = keyPoints
        self.emotionalContext = emotionalContext
        self.importance = importance
        self.category = category
        self.tags = tags
    }
    
    func updateAccess() {
        self.lastAccessedAt = Date()
    }
}

/// 사용자 선호도 학습 데이터
@available(iOS 17.0, *)
@Model
final class PreferenceMemory {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    
    var preferenceType: String // "response_style", "topic_interest", "interaction_pattern"
    var context: String
    var userAction: String // "liked", "disliked", "ignored", "saved"
    var value: String
    var confidence: Double // 0.0 - 1.0
    
    // 학습 가중치
    var weight: Double
    var frequency: Int
    
    init(
        preferenceType: String,
        context: String,
        userAction: String,
        value: String,
        confidence: Double = 0.5,
        weight: Double = 1.0
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.preferenceType = preferenceType
        self.context = context
        self.userAction = userAction
        self.value = value
        self.confidence = confidence
        self.weight = weight
        self.frequency = 1
    }
    
    func incrementFrequency() {
        self.frequency += 1
        self.updatedAt = Date()
        // 빈도가 높을수록 가중치 증가
        self.weight = min(2.0, 1.0 + log(Double(frequency)) * 0.1)
    }
}

/// 컨텍스트 기반 기억 검색을 위한 모델
@available(iOS 17.0, *)
@Model
final class ContextualMemory {
    var id: UUID
    var createdAt: Date
    var relevanceScore: Double
    
    var situationType: String // "morning", "work", "relaxation", "problem_solving"
    var triggerKeywords: [String]
    var responseTemplate: String
    var successRate: Double // 0.0 - 1.0
    
    // 적응형 학습
    var usageCount: Int
    var lastUsedAt: Date?
    
    init(
        situationType: String,
        triggerKeywords: [String],
        responseTemplate: String,
        relevanceScore: Double = 0.5
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.situationType = situationType
        self.triggerKeywords = triggerKeywords
        self.responseTemplate = responseTemplate
        self.relevanceScore = relevanceScore
        self.successRate = 0.5
        self.usageCount = 0
    }
    
    func recordUsage(success: Bool) {
        self.usageCount += 1
        self.lastUsedAt = Date()
        
        // 성공률 업데이트 (이동 평균)
        let alpha = 0.1 // 학습률
        if success {
            self.successRate = self.successRate * (1 - alpha) + alpha
        } else {
            self.successRate = self.successRate * (1 - alpha)
        }
        
        // 관련성 점수 조정
        self.relevanceScore = min(1.0, self.relevanceScore + (success ? 0.05 : -0.02))
    }
}

@available(iOS 17.0, *)
@Model
public final class ConversationTurn {
    // ... existing code ...
}

@available(iOS 17.0, *)
@Model
public final class FeedbackLog {
    // ... existing code ...
}

@available(iOS 17.0, *)
@Model
public final class UserContext {
    // ... existing code ...
} 