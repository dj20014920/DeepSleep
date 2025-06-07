// MARK: - ChatMessage.swift 수정 (기존 케이스에 새로운 케이스 추가)

import Foundation

/// 채팅 메시지 타입을 정의하는 열거형
enum ChatMessageType: String, Codable {
    case user
    case bot
    case aiResponse
    case presetRecommendation
    case recommendationSelector // 🆕 추천 방식 선택창 전용 타입
    case loading
    case error
    case presetOptions
    case postPresetOptions
}

/// 채팅 메시지를 나타내는 구조체
struct ChatMessage: Codable, Identifiable {
    let id = UUID()
    let type: ChatMessageType
    let text: String
    let presetName: String?
    
    // 코딩에 포함되지 않는 클로저 프로퍼티
    var onApplyPreset: (() -> Void)?
    var onSavePreset: (() -> Void)?
    var onFeedback: (() -> Void)?
    var onContinueChat: (() -> Void)?
    var onRetry: (() -> Void)?
    var quickActions: [(String, String)]?

    enum CodingKeys: String, CodingKey {
        case id, type, text, presetName
    }
    
    init(type: ChatMessageType, text: String, presetName: String? = nil) {
        self.type = type
        self.text = text
        self.presetName = presetName
    }
    
    // MARK: - Dictionary Conversion Methods
    
    /// ChatMessage를 딕셔너리로 변환
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": type.rawValue,
            "text": text
        ]
        if let presetName = presetName {
            dict["presetName"] = presetName
        }
        return dict
    }
    
    /// 딕셔너리에서 ChatMessage 생성
    static func from(dictionary: [String: Any]) -> ChatMessage? {
        guard let typeString = dictionary["type"] as? String,
              let type = ChatMessageType(rawValue: typeString),
              let text = dictionary["text"] as? String else {
            return nil
        }
        
        let presetName = dictionary["presetName"] as? String
        return ChatMessage(type: type, text: text, presetName: presetName)
    }
}

// MARK: - QuickActionButton 구조체 정의
struct QuickActionButton {
    let title: String
    let style: ButtonStyle
    let action: () -> Void
    
    enum ButtonStyle {
        case primary
        case secondary
        case accent
        case destructive
    }
}

// MARK: - PresetLimitManager (기존 유지)
class PresetLimitManager {
    static let shared = PresetLimitManager()
    private let key = "presetUsageHistory"

    func canUseToday() -> Bool {
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        let usage = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        return (usage[today] ?? 0) < 5
    }

    func incrementUsage() {
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        var usage = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        usage[today] = (usage[today] ?? 0) + 1
        UserDefaults.standard.set(usage, forKey: key)
    }
}
