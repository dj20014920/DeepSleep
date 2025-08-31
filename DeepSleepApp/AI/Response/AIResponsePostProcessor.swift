import Foundation

// MARK: - AIResponsePostProcessor
// Utility to normalize and lightly post-process AI model outputs.
// Current focus: prevent repetitive greetings like "안녕하세요 (동동님)" on every turn.
// - Keep greeting only on the first assistant turn of a session
// - If there were previous assistant messages, strip a leading greeting phrase
// - Be conservative: only remove an obvious leading greeting and its adjoining punctuation/nickname
public enum AIResponsePostProcessor {
    /// Common greeting prefixes observed across models (Korean-first, plus a few English fallbacks)
    private static let greetingPrefixes: [String] = [
        "안녕하세요", "안녕하세", "안녕", "반갑", "어서오세", "환영",
        "좋은 아침", "좋은 저녁", "좋은 밤", "하이", "hello", "hi"
    ]

    /// Strip a leading greeting if there has already been at least one assistant turn.
    /// - Parameters:
    ///   - response: Raw model response text
    ///   - history: Conversation history (assistant/user/system turns). If nil or no assistant turns, no stripping.
    ///   - nickname: Optional user nickname to recognize and strip like "동동님" directly after greeting.
    /// - Returns: (processed text, reason string if stripped)
    public static func stripRepetitiveGreetingIfNeeded(
        response: String,
        history: [AIConversationTurn]?,
        nickname: String?
    ) -> (String, String?) {
        let priorAssistantTurns = history?.filter { $0.role == .assistant }.count ?? 0
        guard priorAssistantTurns > 0 else {
            // First assistant turn in the session → allow greeting
            return (response, nil)
        }
        return stripLeadingGreeting(response, nickname: nickname)
    }

    // MARK: - Internals

    private static func stripLeadingGreeting(_ text: String, nickname: String?) -> (String, String?) {
        if text.isEmpty { return (text, nil) }

        // 1) Skip initial whitespace/newlines
        var start = text.startIndex
        while start < text.endIndex, text[start].isWhitespace || text[start] == "\n" || text[start] == "\r" {
            start = text.index(after: start)
        }
        if start >= text.endIndex { return (text, nil) }

        let remaining = String(text[start...])
        guard let matchedPrefix = matchGreetingPrefix(in: remaining) else {
            return (text, nil)
        }

        // 2) Cut greeting prefix
        var cursor = remaining.index(remaining.startIndex, offsetBy: matchedPrefix.count)

        // 3) Optionally skip punctuation/space directly after greeting
        while cursor < remaining.endIndex, isSkippable(remaining[cursor]) {
            cursor = remaining.index(after: cursor)
        }

        // 4) Optionally skip nickname mention like "동동님" just after greeting
        if let nn = nickname?.trimmingCharacters(in: .whitespacesAndNewlines), !nn.isEmpty {
            if let nickEnd = trySkipNickname(in: remaining, at: cursor, nickname: nn) {
                cursor = nickEnd
                // skip trailing punctuation/spaces again
                while cursor < remaining.endIndex, isSkippable(remaining[cursor]) {
                    cursor = remaining.index(after: cursor)
                }
            }
        }

        // Compute absolute index in original text
        let advance = remaining.distance(from: remaining.startIndex, to: cursor)
        let absoluteCut = text.index(start, offsetBy: advance)

        // Be conservative: ensure we don't drop the whole text
        if absoluteCut >= text.endIndex { return (text, nil) }

        // Only left-trim spaces/newlines after cut
        var out = String(text[absoluteCut...])
        while out.first?.isWhitespace == true || out.first == "\n" || out.first == "\r" {
            out.removeFirst()
        }

        // If stripping made the text too short or identical, abort
        if out.isEmpty { return (text, nil) }
        if out == text { return (text, nil) }

        return (out, "stripped_prefix:\(matchedPrefix)")
    }

    private static func isSkippable(_ c: Character) -> Bool {
        // Whitespace or light punctuation typically used around greetings/nicknames
        return c.isWhitespace || " ,.!?~…🙂🙃😂🤣💕❤️⭐️*・-—–()[]{}:;\"'、。！？”“’‘·•".contains(c)
    }

    private static func trySkipNickname(in s: String, at i: String.Index, nickname: String) -> String.Index? {
        var cursor = i
        // Optional space before nickname
        while cursor < s.endIndex, isSkippable(s[cursor]) {
            cursor = s.index(after: cursor)
        }
        // Try exact nickname or nickname+"님" (with/without space)
        let candidates = [nickname, nickname + "님", nickname + " 님"]
        for cand in candidates {
            if s[cursor...].hasPrefix(cand) {
                var end = s.index(cursor, offsetBy: cand.count)
                // If we matched base nickname and next token is "님", consume it
                if cand == nickname, end < s.endIndex {
                    // Consume optional whitespace then 님
                    var look = end
                    while look < s.endIndex, s[look].isWhitespace { look = s.index(after: look) }
                    if look < s.endIndex, s[look] == "님" {
                        end = s.index(after: look)
                    }
                }
                return end
            }
        }
        return nil
    }

    private static func matchGreetingPrefix(in s: String) -> String? {
        // We check both raw and lowercased for safety (English case-insensitive)
        let low = s.lowercased()
        for pre in greetingPrefixes {
            if s.hasPrefix(pre) { return pre }
            if low.hasPrefix(pre.lowercased()) { return pre }
        }
        return nil
    }
}

