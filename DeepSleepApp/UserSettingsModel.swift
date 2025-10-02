import Foundation

/// 👤 사용자 설정 정보 모델
/// AI가 더 나은 추천을 위해 알아야 할 사용자 정보들을 관리
struct UserSettingsModel: Codable {
    
    // MARK: - 기본 정보 (ChatGPT 스타일 페르소나)
    var nickname: String = ""
    var age: Int?
    var personalityDescription: String = "" // 자유로운 자기소개
    var personalityTraits: [String] = [] // 빠른 선택 성격 특성들
    var conversationTones: [String] = [] // 선호하는 대화 스타일들(문자열)
    // 새 친구 톤 프리셋(멀티 선택)
    var preferredFriendTones: [FriendTonePreset] = []
    // MBTI 다이얼(부분 선택 허용)
    var mbti: MBTISelection = MBTISelection()
    
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
    
    /// AI에게 전달할 컨텍스트 문자열 생성(선택/입력된 항목만 포함)
    func generateAIContext() -> String {
        var personaLines: [String] = []
        var preferenceLines: [String] = []

        // 기본 정보 (사용자 정보임을 명시)
        if !nickname.isEmpty {
            personaLines.append("• 대화 상대방(사용자) 이름: \(nickname)")
        }
        if let age = age {
            personaLines.append("• 나이: \(age)세")
        }
        if !personalityDescription.isEmpty {
            personaLines.append("• 자기소개: \(personalityDescription)")
        }
        if !personalityTraits.isEmpty {
            personaLines.append("• 성격 특성: \(personalityTraits.joined(separator: ", "))")
        }
        if !conversationTones.isEmpty {
            personaLines.append("• 선호 대화 스타일: \(conversationTones.joined(separator: ", "))")
        }
        if !preferredFriendTones.isEmpty {
            let tones = preferredFriendTones.map { $0.displayName }.joined(separator: ", ")
            personaLines.append("• 친구 말투 프리셋: \(tones)")
        }

        // MBTI: 축별로 선택된 경우에만 자연어로 해석하여 전달(문자 라벨 I/E/N/S/T/F/P/J는 사용하지 않음)
        var mbtiDescriptors: [String] = []
        if mbti.ie.isSpecified {
            mbtiDescriptors.append(mbti.ie == .i ? "내성적(조용·사려 깊음)" : "외향적(에너제틱·격려적)")
        }
        if mbti.ns.isSpecified {
            mbtiDescriptors.append(mbti.ns == .n ? "직관적(큰그림·비유)" : "현실적(구체·사실 중심)")
        }
        if mbti.tf.isSpecified {
            mbtiDescriptors.append(mbti.tf == .t ? "사고형(논리 중심)" : "감정형(공감 중심)")
        }
        if mbti.pj.isSpecified {
            mbtiDescriptors.append(mbti.pj == .p ? "유연한/탐색형" : "계획형/결정형")
        }
        if !mbtiDescriptors.isEmpty {
            personaLines.append("• (AI 친구) 성향 선호: \(mbtiDescriptors.joined(separator: ", "))")
            let guide = mbti.guidelineSnippet().trimmingCharacters(in: .whitespacesAndNewlines)
            if !guide.isEmpty {
                // 가이드를 '(AI 친구) 응답 스타일 가이드'로 명확화
                personaLines.append("• (AI 친구) 응답 스타일 가이드:\n\(guide)")
            }
        }

        // 선호도: 기본값과 다른 경우에만 포함
        // 기본값 가정: conversationStyle=.balanced, emotionalSensitivity=.medium, aiResponseLength=.medium, aiPersonality=.empathetic
        if conversationStyle != .balanced {
            preferenceLines.append("• 대화 스타일: \(conversationStyle.description)")
        }
        if emotionalSensitivity != .medium {
            preferenceLines.append("• 감정 민감도: \(emotionalSensitivity.description)")
        }
        if aiResponseLength != .medium {
            preferenceLines.append("• AI 응답 길이: \(aiResponseLength.description)")
        }
        if aiPersonality != .empathetic {
            preferenceLines.append("• AI 성격: \(aiPersonality.description)")
        }
        if !musicPreferences.isEmpty {
            preferenceLines.append("• 선호 음악: \(musicPreferences.map { $0.description }.joined(separator: ", "))")
        }
        if !soundPreferences.isEmpty {
            preferenceLines.append("• 선호 소리: \(soundPreferences.map { $0.description }.joined(separator: ", "))")
        }

        // 섹션 조립: 내용이 있을 때만 섹션 헤더를 추가
        var sections: [String] = []
        if !personaLines.isEmpty {
            sections.append("[사용자 페르소나]\n" + personaLines.joined(separator: "\n"))
        }
        if !preferenceLines.isEmpty {
            sections.append("[선호도]\n" + preferenceLines.joined(separator: "\n"))
        }
        return sections.joined(separator: "\n")
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

// MARK: - FriendTonePreset & MBTI

extension UserSettingsModel {
    enum FriendTonePreset: String, Codable, CaseIterable {
        case friendly
        case professional
        case calm
        case playful
        case humorous
        case concise
        case supportive
        case analytical
        case coaching

        var displayName: String {
            switch self {
            case .friendly: return "친근한"
            case .professional: return "전문적인"
            case .calm: return "차분한"
            case .playful: return "장난스러운"
            case .humorous: return "유머러스한"
            case .concise: return "간결한"
            case .supportive: return "격려하는"
            case .analytical: return "분석적인"
            case .coaching: return "코칭형"
            }
        }
    }

    /// MBTI 4축 선택(각각 미정 허용)
    struct MBTISelection: Codable {
        var ie: MBTITraitOption = .unspecifiedIE
        var ns: MBTITraitOption = .unspecifiedNS
        var tf: MBTITraitOption = .unspecifiedTF
        var pj: MBTITraitOption = .unspecifiedPJ

        func briefString() -> String {
            var parts: [String] = []
            if ie.isSpecified { parts.append(ie.shortLabel) }
            if ns.isSpecified { parts.append(ns.shortLabel) }
            if tf.isSpecified { parts.append(tf.shortLabel) }
            if pj.isSpecified { parts.append(pj.shortLabel) }
            return parts.joined(separator: " ")
        }

        /// 톤/추론/상담 가이드 라인의 짧은 스니펫(선택된 축만)
        func guidelineSnippet() -> String {
            var lines: [String] = []
            // I/E: 말투 에너지
            if ie.isSpecified {
                switch ie {
                case .i: lines.append("• 말투: 조용하고 사려 깊게, 과장/과한 감탄사 최소화")
                case .e: lines.append("• 말투: 에너제틱하고 격려적으로, 따뜻한 리액션 포함")
                default: break
                }
            }
            // N/S: 설명 스타일
            if ns.isSpecified {
                switch ns {
                case .n: lines.append("• 설명: 직관/비유/큰그림 강조, 새로운 관점 1개 제시")
                case .s: lines.append("• 설명: 구체/사실/사례 중심, 바로 적용 팁 포함")
                default: break
                }
            }
            // T/F: 문제 해결/상담 접근
            if tf.isSpecified {
                switch tf {
                case .t: lines.append("• 접근: 논리적 근거/단계/장단점 정리")
                case .f: lines.append("• 접근: 감정 공감→안심→작은 행동 제안")
                default: break
                }
            }
            // P/J: 구조/결론 스타일
            if pj.isSpecified {
                switch pj {
                case .p: lines.append("• 스타일: 선택지/여지 남기기, 탐색형 제안")
                case .j: lines.append("• 스타일: 명확한 결론/체크리스트/마감 제시")
                default: break
                }
            }
            return lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
        }
    }

    enum MBTITraitOption: String, Codable {
        // 각 축별 미정 구분(서명/직렬화 안정성)
        case unspecifiedIE, i, e
        case unspecifiedNS, n, s
        case unspecifiedTF, t, f
        case unspecifiedPJ, p, j

        var isSpecified: Bool {
            switch self {
            case .unspecifiedIE, .unspecifiedNS, .unspecifiedTF, .unspecifiedPJ: return false
            default: return true
            }
        }
        var shortLabel: String {
            switch self {
            case .i: return "I"
            case .e: return "E"
            case .n: return "N"
            case .s: return "S"
            case .t: return "T"
            case .f: return "F"
            case .p: return "P"
            case .j: return "J"
            default: return ""
            }
        }
        var segmentIndex: Int {
            // 0/1/2 = 좌/기본/우 (중앙=기본=미정)
            switch self {
            case .i, .n, .t, .p: return 0
            case .e, .s, .f, .j: return 2
            default: return 1
            }
        }
        enum Pair { case ie, ns, tf, pj }
        static func fromSegmentIndex(_ idx: Int, pair: Pair) -> MBTITraitOption {
            // 중앙(1) = 미정
            switch pair {
            case .ie:
                return idx == 0 ? .i : (idx == 2 ? .e : .unspecifiedIE)
            case .ns:
                return idx == 0 ? .n : (idx == 2 ? .s : .unspecifiedNS)
            case .tf:
                return idx == 0 ? .t : (idx == 2 ? .f : .unspecifiedTF)
            case .pj:
                return idx == 0 ? .p : (idx == 2 ? .j : .unspecifiedPJ)
            }
        }
    }
}
