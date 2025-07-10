//
//  UserSettings.swift
//  DeepSleep
//
//  Created by AI on 2025/07/10.
//

import Foundation
import SwiftUI

/// 사용자 개인 설정
public struct UserSettings: Codable {
    
    // MARK: - AI 모델 설정
    
    /// 기본 AI 모델 선택
    public var preferredAIModel: LLMServiceType
    
    /// 상황별 AI 모델 우선순위
    public var modelPriority: [LLMServiceType]
    
    // MARK: - 개인화 설정
    
    /// 사용자 페르소나 (성격, 성향, 특징)
    public var userPersona: String
    
    /// AI가 기억해야 할 개인 정보
    public var personalInfo: String
    
    /// 커스텀 시스템 프롬프트
    public var customSystemPrompt: String
    
    // MARK: - 대화 설정
    
    /// 대화 톤 설정
    public var conversationTone: ConversationTone
    
    /// 기억 범위 설정 (일 단위)
    public var memoryDays: Int
    
    /// 개인화 수준
    public var personalizationLevel: PersonalizationLevel
    
    // MARK: - 수면 관련 설정
    
    /// 수면 목표 시간
    public var targetSleepHours: Double
    
    /// 평소 취침 시간
    public var usualBedtime: String
    
    /// 평소 기상 시간
    public var usualWakeTime: String
    
    /// 주요 수면 고민
    public var mainSleepConcerns: [String]
    
    // MARK: - 초기값
    
    public init(
        preferredAIModel: LLMServiceType = .claude,
        modelPriority: [LLMServiceType] = [.claude, .openAI, .gemini, .naver],
        userPersona: String = "",
        personalInfo: String = "",
        customSystemPrompt: String = "",
        conversationTone: ConversationTone = .friendly,
        memoryDays: Int = 7,
        personalizationLevel: PersonalizationLevel = .medium,
        targetSleepHours: Double = 8.0,
        usualBedtime: String = "23:00",
        usualWakeTime: String = "07:00",
        mainSleepConcerns: [String] = []
    ) {
        self.preferredAIModel = preferredAIModel
        self.modelPriority = modelPriority
        self.userPersona = userPersona
        self.personalInfo = personalInfo
        self.customSystemPrompt = customSystemPrompt
        self.conversationTone = conversationTone
        self.memoryDays = memoryDays
        self.personalizationLevel = personalizationLevel
        self.targetSleepHours = targetSleepHours
        self.usualBedtime = usualBedtime
        self.usualWakeTime = usualWakeTime
        self.mainSleepConcerns = mainSleepConcerns
    }
}

/// 대화 톤 설정
public enum ConversationTone: String, CaseIterable, Codable {
    case formal = "formal"           // 정중하고 전문적인 톤
    case friendly = "friendly"       // 친근하고 따뜻한 톤
    case casual = "casual"          // 편안하고 자연스러운 톤
    case professional = "professional" // 의료진처럼 전문적인 톤
    
    public var displayName: String {
        switch self {
        case .formal: return "정중한 톤"
        case .friendly: return "친근한 톤"
        case .casual: return "편안한 톤"
        case .professional: return "전문가 톤"
        }
    }
    
    public var systemPromptAddition: String {
        switch self {
        case .formal:
            return "정중하고 예의 바른 말투로 대화해주세요."
        case .friendly:
            return "친근하고 따뜻한 말투로, 친구처럼 편안하게 대화해주세요."
        case .casual:
            return "편안하고 자연스러운 말투로 대화해주세요."
        case .professional:
            return "수면 전문가처럼 전문적이고 신뢰할 수 있는 톤으로 조언해주세요."
        }
    }
}

/// 개인화 수준
public enum PersonalizationLevel: String, CaseIterable, Codable {
    case minimal = "minimal"     // 최소한의 개인화
    case medium = "medium"       // 적당한 개인화
    case high = "high"          // 높은 개인화
    
    public var displayName: String {
        switch self {
        case .minimal: return "기본적"
        case .medium: return "개인화"
        case .high: return "고도화"
        }
    }
    
    public var description: String {
        switch self {
        case .minimal: return "기본적인 수면 정보만 기억"
        case .medium: return "개인 패턴과 선호도 기억"
        case .high: return "모든 대화와 맥락을 상세히 기억"
        }
    }
    
    public var cacheTokenBudget: Int {
        switch self {
        case .minimal: return 1000
        case .medium: return 3000
        case .high: return 6000
        }
    }
}

/// 수면 고민 카테고리
public enum SleepConcern: String, CaseIterable, Codable {
    case fallAsleep = "fall_asleep"         // 잠들기 어려움
    case stayAsleep = "stay_asleep"         // 잠 유지 어려움
    case earlyWaking = "early_waking"       // 새벽에 깸
    case nightmares = "nightmares"          // 악몽
    case snoring = "snoring"               // 코골이
    case restless = "restless"             // 뒤척임
    case daytimeTired = "daytime_tired"     // 낮에 피곤함
    case irregularSchedule = "irregular"    // 불규칙한 수면
    
    public var displayName: String {
        switch self {
        case .fallAsleep: return "잠들기 어려움"
        case .stayAsleep: return "잠 유지 어려움"
        case .earlyWaking: return "새벽에 깸"
        case .nightmares: return "악몽"
        case .snoring: return "코골이"
        case .restless: return "뒤척임"
        case .daytimeTired: return "낮에 피곤함"
        case .irregularSchedule: return "불규칙한 수면"
        }
    }
}

/// 사용자 설정 관리자
public final class UserSettingsManager: ObservableObject {
    
    // MARK: - Properties
    
    public static let shared = UserSettingsManager()
    @Published public var settings: UserSettings
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "user_settings_v1"
    
    // MARK: - Initialization
    
    private init() {
        // 저장된 설정 로드
        if let data = userDefaults.data(forKey: settingsKey),
           let savedSettings = try? JSONDecoder().decode(UserSettings.self, from: data) {
            self.settings = savedSettings
        } else {
            // 기본 설정
            self.settings = UserSettings()
        }
    }
    
    // MARK: - Public Methods
    
    /// 설정 저장
    public func saveSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: settingsKey)
        } catch {
            print("Failed to save user settings: \(error)")
        }
    }
    
    /// 개인화된 시스템 프롬프트 생성
    public func generateSystemPrompt() -> String {
        var prompt = "당신은 DeepSleep의 수면 상담 AI입니다. "
        
        // 기본 역할
        prompt += "사용자의 수면 건강을 개선하기 위해 개인맞춤형 조언과 도움을 제공합니다. "
        
        // 대화 톤 적용
        prompt += settings.conversationTone.systemPromptAddition + " "
        
        // 사용자 개인 정보 추가
        if !settings.personalInfo.isEmpty {
            prompt += "\n\n[사용자 정보]\n\(settings.personalInfo)\n"
        }
        
        // 사용자 페르소나 추가
        if !settings.userPersona.isEmpty {
            prompt += "\n[사용자 성향]\n\(settings.userPersona)\n"
        }
        
        // 수면 정보 추가
        if settings.targetSleepHours > 0 {
            prompt += "\n[수면 목표]\n"
            prompt += "- 목표 수면시간: \(settings.targetSleepHours)시간\n"
            prompt += "- 평소 취침: \(settings.usualBedtime)\n"
            prompt += "- 평소 기상: \(settings.usualWakeTime)\n"
        }
        
        // 주요 고민 추가
        if !settings.mainSleepConcerns.isEmpty {
            prompt += "\n[주요 수면 고민]\n"
            prompt += settings.mainSleepConcerns.joined(separator: ", ")
            prompt += "\n"
        }
        
        // 커스텀 프롬프트 추가
        if !settings.customSystemPrompt.isEmpty {
            prompt += "\n[추가 지침]\n\(settings.customSystemPrompt)\n"
        }
        
        // 개인화 수준에 따른 메모리 지침
        switch settings.personalizationLevel {
        case .minimal:
            prompt += "\n기본적인 수면 정보만 참고하여 일반적인 조언을 제공하세요."
        case .medium:
            prompt += "\n사용자의 개인 패턴과 선호도를 고려하여 개인화된 조언을 제공하세요."
        case .high:
            prompt += "\n모든 대화 맥락과 개인 정보를 종합적으로 고려하여 매우 개인화된 조언을 제공하세요."
        }
        
        return prompt
    }
    
    /// 설정 초기화
    public func resetSettings() {
        settings = UserSettings()
        saveSettings()
    }
    
    /// 내보내기용 설정 문자열
    public func exportSettings() -> String {
        do {
            let data = try JSONEncoder().encode(settings)
            return data.base64EncodedString()
        } catch {
            return ""
        }
    }
    
    /// 설정 가져오기
    public func importSettings(from base64String: String) -> Bool {
        guard let data = Data(base64Encoded: base64String),
              let importedSettings = try? JSONDecoder().decode(UserSettings.self, from: data) else {
            return false
        }
        
        settings = importedSettings
        saveSettings()
        return true
    }
}