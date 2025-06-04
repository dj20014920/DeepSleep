// MARK: - ChatMessage.swift 수정 (기존 케이스에 새로운 케이스 추가)

import Foundation

// MARK: - ChatMessage enum (기존 + 새로운 케이스 추가)
enum ChatMessage {
    case user(String)
    case bot(String)
    case presetRecommendation(presetName: String, message: String, apply: () -> Void)
    case postPresetOptions(
        presetName: String,
        onSave: () -> Void,
        onFeedback: () -> Void,
        onGoToMain: () -> Void,
        onContinueChat: () -> Void
    )

    func toDictionary() -> [String: String] {
        switch self {
        case .user(let msg):
            return ["type": "user", "text": msg]
        case .bot(let msg):
            return ["type": "bot", "text": msg]
        case .presetRecommendation(let presetName, let msg, _):
            return ["type": "preset", "text": msg, "presetName": presetName]
        case .postPresetOptions(let presetName, _, _, _, _):
            return ["type": "postPresetOptions", "text": "프리셋 옵션", "presetName": presetName]
        }
    }

    static func from(dictionary: [String: String]) -> ChatMessage? {
        guard let type = dictionary["type"], let text = dictionary["text"] else { return nil }
        switch type {
        case "user": return .user(text)
        case "bot": return .bot(text)
        case "preset":
            let name = dictionary["presetName"] ?? "추천 프리셋"
            return .presetRecommendation(presetName: name, message: text, apply: {})
        case "postPresetOptions":
            let name = dictionary["presetName"] ?? "적용된 프리셋"
            return .postPresetOptions(
                presetName: name,
                onSave: {},
                onFeedback: {},
                onGoToMain: {},
                onContinueChat: {}
            )
        default: return nil
        }
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
        return (usage[today] ?? 0) < 3
    }

    func incrementUsage() {
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        var usage = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        usage[today] = (usage[today] ?? 0) + 1
        UserDefaults.standard.set(usage, forKey: key)
    }
}
