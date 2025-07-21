import Foundation

/// 👤 사용자 설정 정보 모델
/// AI가 더 나은 추천을 위해 알아야 할 사용자 정보들을 관리
struct UserSettingsModel: Codable {
    
    // MARK: - 기본 정보 (ChatGPT 스타일 페르소나)
    var nickname: String = ""
    var age: Int?
    var personalityDescription: String = "" // 자유로운 자기소개
    var personalityTraits: [String] = [] // 빠른 선택 성격 특성들
    var conversationTones: [String] = [] // 선호하는 대화 스타일들
    
    // MARK: - 음악/소리 선호도
    var musicPreferences: [MusicStyle] = []
    var soundPreferences: [SoundType] = []
    
    // MARK: - AI 상호작용 설정
    var conversationStyle: ConversationStyle = .balanced
    var emotionalSensitivity: EmotionalSensitivity = .medium
    var aiResponseLength: ResponseLength = .medium
    var aiPersonality: AIPersonality = .empathetic
    var useEmotionalAnalysis: Bool = true
    var sharePersonalInfo: Bool = true
    
    // MARK: - Methods
    
    /// UserDefaults에서 설정 불러오기
    static func loadFromUserDefaults() -> UserSettingsModel {
        guard let data = UserDefaults.standard.data(forKey: "userSettings"),
              let settings = try? JSONDecoder().decode(UserSettingsModel.self, from: data) else {
            return UserSettingsModel() // 기본값 반환
        }
        return settings
    }
    
    /// UserDefaults에 설정 저장
    func saveToUserDefaults() {
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: "userSettings")
            print("✅ 사용자 설정 저장 완료")
        } catch {
            print("❌ 사용자 설정 저장 실패: \(error)")
        }
    }
    
    /// AI에게 전달할 컨텍스트 문자열 생성
    func generateAIContext() -> String {
        var context = "\n[사용자 페르소나]\n"
        
        // 기본 정보
        if !nickname.isEmpty {
            context += "• 이름: \(nickname)\n"
        }
        if let age = age {
            context += "• 나이: \(age)세\n"
        }
        
        // 자유로운 자기소개
        if !personalityDescription.isEmpty {
            context += "• 자기소개: \(personalityDescription)\n"
        }
        
        // 성격 특성
        if !personalityTraits.isEmpty {
            context += "• 성격 특성: \(personalityTraits.joined(separator: ", "))\n"
        }
        
        // 선호하는 대화 스타일
        if !conversationTones.isEmpty {
            context += "• 선호 대화 스타일: \(conversationTones.joined(separator: ", "))\n"
        }
        
        // 음악/소리 선호도
        context += "\n[선호도]\n"
        context += "• 대화 스타일: \(conversationStyle.description)\n"
        context += "• 감정 민감도: \(emotionalSensitivity.description)\n"
        context += "• AI 응답 길이: \(aiResponseLength.description)\n"
        context += "• AI 성격: \(aiPersonality.description)\n"
        
        if !musicPreferences.isEmpty {
            context += "• 선호 음악: \(musicPreferences.map { $0.description }.joined(separator: ", "))\n"
        }
        
        if !soundPreferences.isEmpty {
            context += "• 선호 소리: \(soundPreferences.map { $0.description }.joined(separator: ", "))\n"
        }
        
        return context
    }
}

// MARK: - Supporting Enums

enum MusicStyle: String, Codable, CaseIterable {
    case classical = "클래식"
    case lofi = "로파이"
    case jazz = "재즈"
    case pop = "팝"
    case electronic = "일렉트로닉"
    case nature = "자연소리"
    case ambient = "앰비언트"
    case whiteNoise = "백색소음"
    case meditation = "명상음악"
    case piano = "피아노"
    case other = "기타"
    
    var description: String {
        return self.rawValue
    }
}

enum SoundType: String, Codable, CaseIterable {
    case rain = "rain"
    case ocean = "ocean"
    case forest = "forest"
    case fire = "fire"
    case wind = "wind"
    case birds = "birds"
    case city = "city"
    case silence = "silence"
    
    var description: String {
        switch self {
        case .rain: return "비소리"
        case .ocean: return "파도소리"
        case .forest: return "숲소리"
        case .fire: return "불소리"
        case .wind: return "바람소리"
        case .birds: return "새소리"
        case .city: return "도시소음"
        case .silence: return "정적"
        }
    }
}

enum ConversationStyle: String, Codable, CaseIterable {
    case gentle = "gentle"
    case balanced = "balanced"
    case energetic = "energetic"
    case professional = "professional"
    case friendly = "friendly"
    
    var description: String {
        switch self {
        case .gentle: return "부드러운"
        case .balanced: return "균형잡힌"
        case .energetic: return "활발한"
        case .professional: return "전문적인"
        case .friendly: return "친근한"
        }
    }
}

enum EmotionalSensitivity: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case veryHigh = "very_high"
    
    var description: String {
        switch self {
        case .low: return "낮음"
        case .medium: return "보통"
        case .high: return "높음"
        case .veryHigh: return "매우 높음"
        }
    }
}


enum ResponseLength: String, Codable, CaseIterable {
    case short = "short"
    case medium = "medium"
    case long = "long"
    
    var description: String {
        switch self {
        case .short: return "간결한"
        case .medium: return "적당한"
        case .long: return "자세한"
        }
    }
}

enum AIPersonality: String, Codable, CaseIterable {
    case empathetic = "empathetic"
    case analytical = "analytical"
    case cheerful = "cheerful"
    case calm = "calm"
    case wise = "wise"
    
    var description: String {
        switch self {
        case .empathetic: return "공감적"
        case .analytical: return "분석적"
        case .cheerful: return "밝은"
        case .calm: return "차분한"
        case .wise: return "현명한"
        }
    }
}