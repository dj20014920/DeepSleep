import Foundation

public enum PresetInteractionSummarizer {
    // 개인정보(이메일/전화) 제거용 간단 필터
    private static func sanitizePII(_ s: String) -> String {
        var out = s
        // email
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        out = out.replacingOccurrences(of: emailPattern, with: "[이메일제거]", options: .regularExpression)

        // phone (간단 패턴)
        let phonePattern = "(\\+?\\d{1,3}[ -]?)?(\\d{2,4}[ -]?){2,3}\\d{2,4}"
        out = out.replacingOccurrences(of: phonePattern, with: "[전화번호제거]", options: .regularExpression)

        return out
    }

    public static func summarizeUserRequest(_ userText: String) -> String {
        let cleaned = sanitizePII(userText)
        // 불필요한 본문은 저장하지 않고, 요청 사실만 기록
        return "사용자: 프리셋을 요청했습니다."
    }

    public static func summarizeAIResponse(presetName: String?) -> String {
        if let name = presetName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "AI: 프리셋을 추천했습니다: [\(name)]."
        }
        return "AI: 프리셋을 추천했습니다."
    }
}
