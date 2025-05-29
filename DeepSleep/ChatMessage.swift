import Foundation

// MARK: - ChatMessage enum
enum ChatMessage {
    case user(String)
    case bot(String)
    case presetRecommendation(presetName: String, message: String, apply: () -> Void)

    func toDictionary() -> [String: String] {
        switch self {
        case .user(let msg):
            return ["type": "user", "text": msg]
        case .bot(let msg):
            return ["type": "bot", "text": msg]
        case .presetRecommendation(let presetName, let msg, _):
            return ["type": "preset", "text": msg, "presetName": presetName]
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
        default: return nil
        }
    }
}

// MARK: - PresetLimitManager
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
