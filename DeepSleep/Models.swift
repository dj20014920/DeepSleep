import Foundation

// MARK: - 감정 관련 모델
struct Emotion {
    let emoji: String
    let name: String
    let description: String
    let category: EmotionCategory
    
    enum EmotionCategory: String, CaseIterable {
        case happy = "기쁨"
        case sad = "슬픔"
        case anxious = "불안"
        case tired = "피곤"
        case angry = "화남"
        case neutral = "평온"
    }
    
    static let predefinedEmotions: [Emotion] = [
        Emotion(emoji: "😊", name: "기쁨", description: "행복하고 즐거운", category: .happy),
        Emotion(emoji: "😄", name: "신남", description: "에너지 넘치는", category: .happy),
        Emotion(emoji: "🥰", name: "사랑", description: "따뜻하고 포근한", category: .happy),
        
        Emotion(emoji: "😢", name: "슬픔", description: "눈물이 나는", category: .sad),
        Emotion(emoji: "😞", name: "우울", description: "마음이 무거운", category: .sad),
        Emotion(emoji: "😔", name: "실망", description: "기대가 무너진", category: .sad),
        
        Emotion(emoji: "😰", name: "불안", description: "마음이 조급한", category: .anxious),
        Emotion(emoji: "😱", name: "공포", description: "두렵고 무서운", category: .anxious),
        Emotion(emoji: "😨", name: "걱정", description: "앞이 막막한", category: .anxious),
        
        Emotion(emoji: "😴", name: "졸림", description: "잠이 오는", category: .tired),
        Emotion(emoji: "😪", name: "피곤", description: "몸과 마음이 지친", category: .tired),
        
        Emotion(emoji: "😡", name: "화남", description: "분노가 치미는", category: .angry),
        Emotion(emoji: "😤", name: "짜증", description: "신경이 날카로운", category: .angry),
        
        Emotion(emoji: "😐", name: "무덤덤", description: "특별한 감정 없는", category: .neutral),
        Emotion(emoji: "🙂", name: "평온", description: "마음이 고요한", category: .neutral)
    ]
}

// MARK: - 사운드 프리셋 모델 (기존 Preset 확장)
struct SoundPreset: Codable {
    let id: UUID
    let name: String
    let volumes: [Float]
    let emotion: String?
    let createdDate: Date
    let isAIGenerated: Bool
    let description: String?
    
    init(name: String, volumes: [Float], emotion: String? = nil, isAIGenerated: Bool = false, description: String? = nil) {
        self.id = UUID()
        self.name = name
        self.volumes = volumes
        self.emotion = emotion
        self.createdDate = Date()
        self.isAIGenerated = isAIGenerated
        self.description = description
    }
}

// MARK: - 감정 일기 모델
struct EmotionDiary: Codable, Identifiable {
    let id: UUID
    let date: Date
    let selectedEmotion: String
    let userMessage: String
    let aiResponse: String
    let recommendedPreset: SoundPreset?
    let mood: Int // 1-5 스케일
    let tags: [String]
    
    init(selectedEmotion: String, userMessage: String, aiResponse: String, recommendedPreset: SoundPreset? = nil, mood: Int = 3, tags: [String] = []) {
        self.id = UUID()
        self.date = Date()
        self.selectedEmotion = selectedEmotion
        self.userMessage = userMessage
        self.aiResponse = aiResponse
        self.recommendedPreset = recommendedPreset
        self.mood = mood
        self.tags = tags
    }
}

// MARK: - 사용자 설정 모델
struct UserSettings: Codable {
    var dailyChatLimit: Int = 50
    var dailyPresetLimit: Int = 3
    var enableNotifications: Bool = true
    var autoSavePresets: Bool = true
    var preferredFadeOutDuration: TimeInterval = 30.0
    var enableHapticFeedback: Bool = true
    var preferredTheme: Theme = .system
    
    enum Theme: String, CaseIterable, Codable {
        case light = "라이트"
        case dark = "다크"
        case system = "시스템"
    }
}

// MARK: - 사용 통계 모델
struct UsageStats: Codable {
    let date: String
    var chatCount: Int = 0
    var presetRecommendationCount: Int = 0
    var timerUsageCount: Int = 0
    var totalSessionTime: TimeInterval = 0
    var mostUsedEmotion: String?
    var effectivePresets: [String] = []
}

// MARK: - AI 응답 모델
struct AIResponse {
    let message: String
    let preset: SoundPreset?
    let confidence: Float
    let processingTime: TimeInterval
    let intent: AIIntent
    
    enum AIIntent: String {
        case chat = "일반 대화"
        case diary = "감정 일기"
        case presetRecommendation = "프리셋 추천"
        case comfort = "위로"
        case advice = "조언"
    }
}

// MARK: - 알림 모델
struct DeepSleepNotification: Codable {
    let id: UUID
    let title: String
    let body: String
    let scheduledDate: Date
    let type: NotificationType
    let isRepeating: Bool
    
    enum NotificationType: String, Codable {
        case timerComplete = "타이머 완료"
        case dailyCheckIn = "일일 체크인"
        case recommendationReady = "추천 준비 완료"
        case moodReminder = "기분 체크 알림"
    }
    
    init(title: String, body: String, scheduledDate: Date, type: NotificationType, isRepeating: Bool = false) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.scheduledDate = scheduledDate
        self.type = type
        self.isRepeating = isRepeating
    }
}
