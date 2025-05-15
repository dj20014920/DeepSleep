import Foundation
import NaturalLanguage

/// 감정 카테고리
enum EmotionType: String {
    case happy, sad, angry, anxious, tired, neutral
}

struct EmotionAnalyzer {

    /// 자유 텍스트로 입력된 문장을 NLTagger로 분석해 감정 카테고리로 매핑
    static func analyze(text: String) -> EmotionType {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text

        let (sentimentTag, _) = tagger.tag(
            at: text.startIndex,
            unit: .paragraph,
            scheme: .sentimentScore
        )
        guard let scoreStr = sentimentTag?.rawValue,
              let score = Double(scoreStr) else {
            return .neutral
        }

        switch score {
        case let x where x > 0.3:
            return .happy
        case let x where x < -0.3:
            return .sad
        default:
            return .neutral
        }
    }

    /// 이모지 선택 시 간단 매핑
    static func mapEmojiToEmotion(_ emoji: String) -> EmotionType {
        switch emoji {
        case "😊": return .happy
        case "😢": return .sad
        case "😠": return .angry
        case "😰": return .anxious
        case "😴": return .tired
        default:    return .neutral
        }
    }
}
