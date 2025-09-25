import Foundation

// MARK: - AIResponsePostProcessor
// Minimal post-processor focused solely on artifact sanitization.
// - Removes surrounding code fences ```...``` when the whole response is fenced
// - Strips leading speaker labels such as "[AI 친구]:", "<AI>:", "AI:", "assistant:" using raw-regex
public enum AIResponsePostProcessor {

    /// Remove common artifacts: leading speaker labels (e.g., "[AI 친구]:"), and code fences.
    /// Returns (sanitized, reason)
    public static func sanitizeArtifacts(_ text: String) -> (String, String?) {
        var s = text
        var reasons: [String] = []

        // Fast path
        if s.isEmpty { return (s, nil) }

        // 1) Remove surrounding code fences ```...``` (if the entire response is fenced)
        // Handles optional language tag after the opening fence (e.g., ```json)
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            if let firstFence = trimmed.range(of: "```") {
                let afterFirstFence = trimmed[firstFence.upperBound...]
                // Skip an optional language tag up to the first newline (non-strict)
                let bodyStart = afterFirstFence.firstIndex(of: "\n") ?? afterFirstFence.startIndex
                let candidateBody = afterFirstFence[bodyStart...]
                if let lastFence = candidateBody.range(of: "```", options: .backwards) {
                    let inner = candidateBody[..<lastFence.lowerBound]
                    s = String(inner).trimmingCharacters(in: .whitespacesAndNewlines)
                    reasons.append("strip_code_fence")
                }
            }
        }

        // 2) Strip leading speaker labels like "[AI 친구]:", "<AI>:", "AI:" etc.
        // Use Raw String Literal patterns to avoid invalid escape issues in Swift string literals.
        // NOTE: Keep the two patterns exactly as specified to fix "Invalid escape sequence" compile errors.
        let speakerPatterns: [String] = [
            #"^\s*(?:\[|<)?\s*(?:AI\s*친구|AI|assistant|봇|bot|ai|assistant)\s*(?:\]|>)?\s*[:：\-]\s*"#,
            #"^\s*(?:AI\s*친구|AI|assistant|봇|bot|ai)\s*[:：\-]\s*"#,
        ]

        let beforeSpeaker = s
        for p in speakerPatterns {
            if let re = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) {
                let ns = s as NSString
                let range = NSRange(location: 0, length: ns.length)
                // Replace only the first match at the beginning (pattern is anchored ^)
                if let match = re.firstMatch(in: s, options: [], range: range) {
                    s = ns.replacingCharacters(in: match.range, with: "")
                }
            }
        }
        if s != beforeSpeaker { reasons.append("strip_speaker_label") }

        // 3) Strip leaked chat-template markers (Qwen/Gemma style + extended patterns)
        // Remove any occurrences to avoid leaking prompt delimiters into UI
        let templateMarkers: [String] = [
            // Qwen/HyperCLOVA X style
            "<|im_start|>assistant",
            "<|im_start|>user",
            "<|im_start|>system",
            "<|im_start|>",
            "<|im_end|>",
            "<|endofturn|>",
            "<|stop|>",
            // Gemma style
            "<start_of_turn>user",
            "<start_of_turn>model",
            "<start_of_turn>assistant",
            "<start_of_turn>",
            "<end_of_turn>",
            // Common stop tokens that might leak
            "<eos>",
            "</s>",
            "<|eot_id|>",
            "<|end_of_text|>",
            // Partial/broken tokens that appear in logs
            "<|im_",
            "<start_of_",
            "<end_of_",
        ]

        var beforeTemplates = s

        // First pass: exact string replacements
        for marker in templateMarkers {
            s = s.replacingOccurrences(of: marker, with: "")
        }

        // Second pass: regex-based cleanup for more complex patterns
        let templatePatterns: [String] = [
            // Any <|something|> pattern (Qwen-style)
            #"<\|[^|]*\|>"#,
            // Any <something_of_turn> pattern (Gemma-style)
            #"<[^>]*_of_turn[^>]*>"#,
            // Broken template fragments
            #"<\|[^>]*$"#,  // incomplete opening
            #"^[^<]*\|>"#,  // incomplete closing
        ]

        for pattern in templatePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: s.count)
                s = regex.stringByReplacingMatches(
                    in: s, options: [], range: range, withTemplate: "")
            }
        }

        if s != beforeTemplates { reasons.append("strip_template_markers") }

        // 4) Clean up UTF-8 encoding issues and corrupted characters
        let beforeEncoding = s
        // Remove common UTF-8 replacement characters and broken sequences
        s = s.replacingOccurrences(of: "���", with: "")  // UTF-8 replacement character
        s = s.replacingOccurrences(of: "\u{FFFD}", with: "")  // Unicode replacement character
        if s != beforeEncoding { reasons.append("fix_encoding") }

        // 5) Remove duplicate content patterns (like repeated responses)
        let beforeDuplicate = s
        // Pattern: "text<template>text" -> "text"
        let duplicatePatterns = [
            #"(.+?)(?:<[^>]*>)+\1"#,  // text followed by template markers then same text
            #"(.{10,}?)\1{2,}"#,  // text repeated 3+ times (min 10 chars to avoid false positives)
        ]

        for pattern in duplicatePatterns {
            if let regex = try? NSRegularExpression(
                pattern: pattern, options: [.dotMatchesLineSeparators])
            {
                let range = NSRange(location: 0, length: s.count)
                s = regex.stringByReplacingMatches(
                    in: s, options: [], range: range, withTemplate: "$1")
            }
        }
        if s != beforeDuplicate { reasons.append("remove_duplicates") }

        // 6) Final trim
        let beforeTrim = s
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if s != beforeTrim { reasons.append("trim_whitespace") }

        return (s, reasons.isEmpty ? nil : reasons.joined(separator: ","))
    }

    /// Reduce repeated greetings on subsequent assistant turns.
    /// If history already contains an assistant role, strip a simple greeting prefix from response.
    /// Returns (processed, reason)
    public static func stripRepetitiveGreetingIfNeeded(
        response: String,
        history: [Any]?,
        nickname: String?
    ) -> (String, String?) {
        // Keep as-is when no prior assistant turn
        // Conservatively detect previous assistant turn if history items resemble our AIConversationTurn { role: String }
        var hasAssistantBefore = false
        if let arr = history {
            for item in arr {
                if let dict = item as? [String: Any], let role = dict["role"] as? String,
                    role.lowercased() == "assistant"
                {
                    hasAssistantBefore = true
                    break
                }
                // Fallback: try Mirror for struct-like objects
                let m = Mirror(reflecting: item)
                if let roleChild = m.children.first(where: { $0.label == "role" }) {
                    let roleValue = String(describing: roleChild.value).lowercased()
                    if roleValue.contains("assistant") {
                        hasAssistantBefore = true
                        break
                    }
                }
            }
        }
        if !hasAssistantBefore { return (response, nil) }
        // Reuse artifact cleanup first (idempotent)
        let (sanitized, artReason) = sanitizeArtifacts(response)
        var s = sanitized
        var reasons: [String] = []
        if let r = artReason, !r.isEmpty { reasons.append(r) }

        // Build greeting patterns (raw regex, anchored at start)
        let base = #"^\s*(?:안녕하세요|안녕|반가워요|반갑습니다|하이|헬로|헬로우|hello|hi)\s*"#
        var patterns: [String] = []
        if let name = nickname, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let esc = NSRegularExpression.escapedPattern(for: name)
            patterns.append(base + #"(?:\(?\s*"# + esc + #"(?:님)?\s*\)?)?\s*[,，、:：!~\-]*\s+"#)
        }
        // Generic (no nickname)
        patterns.append(
            base
                + #"(?:\([^)]{0,20}\)|\<[^>]{0,20}\>|\[[^\]]{0,20}\]|\"[^\"]{0,20}\")?\s*[,，、:：!~\-]*\s+"#
        )

        let before = s
        outer: for p in patterns {
            if let re = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) {
                let ns = s as NSString
                let range = NSRange(location: 0, length: ns.length)
                if let match = re.firstMatch(in: s, options: [], range: range) {
                    s = ns.replacingCharacters(in: match.range, with: "")
                    reasons.append("strip_greeting")
                    break outer
                }
            }
        }
        if s == before { return (s, reasons.isEmpty ? nil : reasons.joined(separator: ",")) }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != s { reasons.append("trim_whitespace") }
        return (trimmed, reasons.isEmpty ? nil : reasons.joined(separator: ","))
    }
}
