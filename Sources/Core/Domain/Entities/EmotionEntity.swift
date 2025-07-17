import Foundation

// MARK: - Emotion Domain Entities

public enum EmotionCategory: String, CaseIterable, Codable {
    case happy = "기쁨"
    case sad = "슬픔"
    case anxious = "불안"
    case tired = "피곤"
    case angry = "화남"
    case neutral = "평온"
    
    public var description: String {
        return self.rawValue
    }
}

// MARK: - Legacy EmotionType for Compatibility
public enum EmotionType: String, CaseIterable, Codable, Hashable {
    // 기본 감정들
    case happy = "happy"
    case sad = "sad"
    case anxious = "anxious"
    case stressed = "stressed"
    case excited = "excited"
    case tired = "tired"
    case angry = "angry"
    case calm = "calm"
    case nostalgic = "nostalgic"
    case grateful = "grateful"
    case confused = "confused"
    case neutral = "neutral"
    
    // EnhancedEmotion에서 통합된 케이스들
    case peaceful = "peaceful"
    case tense = "tense"
    case focused = "focused"
    case energetic = "energetic"
    
    public var emojiSymbol: String {
        switch self {
        case .happy: return "😊"
        case .sad: return "😢"
        case .anxious: return "😰"
        case .stressed: return "😣"
        case .excited: return "😄"
        case .tired: return "😴"
        case .angry: return "😡"
        case .calm: return "😌"
        case .nostalgic: return "🥺"
        case .grateful: return "🙏"
        case .confused: return "😕"
        case .neutral: return "😐"
        // 통합된 케이스들
        case .peaceful: return "☮️"
        case .tense: return "😬"
        case .focused: return "🧘"
        case .energetic: return "⚡"
        }
    }
    
    // PERF-WARNING: 감정 강도를 계산하는 메서드 - EnhancedEmotion의 intensity 기능 통합
    public var intensity: Float {
        switch self {
        case .excited, .angry, .energetic: return 0.8
        case .anxious, .stressed, .tense: return 0.7
        case .happy, .grateful, .focused: return 0.6
        case .sad, .nostalgic, .tired: return 0.4
        case .confused: return 0.3
        case .calm, .peaceful, .neutral: return 0.2
        }
    }
    
    public var localizedName: String {
        switch self {
        case .happy: return "기쁨"
        case .sad: return "슬픔"
        case .anxious: return "불안"
        case .stressed: return "스트레스"
        case .excited: return "신남"
        case .tired: return "피곤"
        case .angry: return "화남"
        case .calm: return "평온"
        case .nostalgic: return "그리움"
        case .grateful: return "감사"
        case .confused: return "혼란"
        case .neutral: return "무덤덤"
        // 통합된 케이스들
        case .peaceful: return "평화로움"
        case .tense: return "긴장"
        case .focused: return "집중"
        case .energetic: return "활력"
        }
    }
    
    public var category: EmotionCategory {
        switch self {
        case .happy, .excited, .grateful:
            return .happy
        case .sad, .nostalgic:
            return .sad
        case .anxious, .stressed, .confused, .tense:
            return .anxious
        case .tired:
            return .tired
        case .angry:
            return .angry
        case .calm, .neutral, .peaceful:
            return .neutral
        case .focused, .energetic:
            return .happy  // 집중과 활력은 긍정적 감정으로 분류
        }
    }
    
    // Convert to EmotionEntity
    public func toEntity() -> EmotionEntity {
        return EmotionEntity(
            emoji: self.emojiSymbol,
            name: self.localizedName,
            description: self.localizedName,
            category: self.category,
            intensity: self.intensity
        )
    }
}

public struct EmotionEntity: Codable, Identifiable, Equatable {
    public let id: UUID
    public let emoji: String
    public let name: String
    public let description: String
    public let category: EmotionCategory
    public let intensity: Float // 0.0 ~ 1.0
    
    public init(
        id: UUID = UUID(),
        emoji: String,
        name: String,
        description: String,
        category: EmotionCategory,
        intensity: Float = 0.5
    ) {
        self.id = id
        self.emoji = emoji
        self.name = name
        self.description = description
        self.category = category
        self.intensity = max(0.0, min(1.0, intensity))
    }
    
    public static func == (lhs: EmotionEntity, rhs: EmotionEntity) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Convert to EmotionType
    public func toType() -> EmotionType? {
        return EmotionType.allCases.first { $0.localizedName == self.name }
    }
}

// MARK: - Emotional Profile Entity
public struct EmotionalProfileEntity: Codable, Identifiable, Equatable {
    public let id: UUID
    public let primaryEmotion: EmotionEntity
    public let secondaryEmotions: [EmotionEntity]
    public let intensity: Float
    public let complexity: Float
    public let context: String?
    public let timestamp: Date
    
    public init(
        id: UUID = UUID(),
        primaryEmotion: EmotionEntity,
        secondaryEmotions: [EmotionEntity] = [],
        intensity: Float,
        complexity: Float,
        context: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.primaryEmotion = primaryEmotion
        self.secondaryEmotions = secondaryEmotions
        self.intensity = max(0.0, min(1.0, intensity))
        self.complexity = max(0.0, min(1.0, complexity))
        self.context = context
        self.timestamp = timestamp
    }
    
    public static func == (lhs: EmotionalProfileEntity, rhs: EmotionalProfileEntity) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Emotion Diary Entry Entity
public struct EmotionDiaryEntryEntity: Codable, Identifiable {
    public let id: UUID
    public let title: String
    public let content: String
    public let emotionalProfile: EmotionalProfileEntity
    public let tags: [String]
    public let createdAt: Date
    public let updatedAt: Date
    public let isPrivate: Bool
    
    public init(
        id: UUID = UUID(),
        title: String,
        content: String,
        emotionalProfile: EmotionalProfileEntity,
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isPrivate: Bool = true
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.emotionalProfile = emotionalProfile
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPrivate = isPrivate
    }
}

// MARK: - Predefined Emotions
public extension EmotionEntity {
    static let predefinedEmotions: [EmotionEntity] = [
        // Happy category
        EmotionEntity(emoji: "😊", name: "기쁨", description: "행복하고 즐거운", category: .happy, intensity: 0.7),
        EmotionEntity(emoji: "😄", name: "신남", description: "에너지 넘치는", category: .happy, intensity: 0.9),
        EmotionEntity(emoji: "🥰", name: "사랑", description: "따뜻하고 포근한", category: .happy, intensity: 0.8),
        
        // Sad category  
        EmotionEntity(emoji: "😢", name: "슬픔", description: "눈물이 나는", category: .sad, intensity: 0.8),
        EmotionEntity(emoji: "😞", name: "우울", description: "마음이 무거운", category: .sad, intensity: 0.6),
        EmotionEntity(emoji: "😔", name: "실망", description: "기대가 무너진", category: .sad, intensity: 0.5),
        
        // Anxious category
        EmotionEntity(emoji: "😰", name: "불안", description: "마음이 조급한", category: .anxious, intensity: 0.7),
        EmotionEntity(emoji: "😱", name: "공포", description: "두렵고 무서운", category: .anxious, intensity: 0.9),
        EmotionEntity(emoji: "😨", name: "걱정", description: "앞이 막막한", category: .anxious, intensity: 0.6),
        
        // Tired category
        EmotionEntity(emoji: "😴", name: "졸림", description: "잠이 오는", category: .tired, intensity: 0.6),
        EmotionEntity(emoji: "😪", name: "피곤", description: "몸과 마음이 지친", category: .tired, intensity: 0.7),
        
        // Angry category
        EmotionEntity(emoji: "😡", name: "화남", description: "분노가 치미는", category: .angry, intensity: 0.8),
        EmotionEntity(emoji: "😤", name: "짜증", description: "신경이 날카로운", category: .angry, intensity: 0.6),
        
        // Neutral category
        EmotionEntity(emoji: "😐", name: "무덤덤", description: "특별한 감정 없는", category: .neutral, intensity: 0.3),
        EmotionEntity(emoji: "🙂", name: "평온", description: "마음이 고요한", category: .neutral, intensity: 0.5)
    ]
} 
