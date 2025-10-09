import Foundation

// MARK: - AIResponsePostProcessor
// Minimal post-processor focused solely on artifact sanitization.
// - Removes surrounding code fences ```...``` when the whole response is fenced
// - Strips leading speaker labels such as "[AI 친구]:", "<AI>:", "AI:", "assistant:" using raw-regex
public enum AIResponsePostProcessor {

    /// Remove common artifacts: leading speaker labels (e.g., "[AI 친구]:"), and code fences.
    /// Returns (sanitized, reason)
    /// 
    /// ⚠️ IMPORTANT: 이 함수는 AI 출력 정화에만 사용합니다.
    /// 사용자 입력은 SpecialTokenSanitizer.sanitizeUserInput()을 사용하세요.
    public static func sanitizeArtifacts(
        _ text: String,
        modelID: OnDeviceModelID? = nil
    ) -> (String, String?) {
        var s = text
        var reasons: [String] = []

        // Fast path
        if s.isEmpty { return (s, nil) }
        
        // STEP 0: 특수 토큰 제거 (모델 ID가 있는 경우)
        if let id = modelID {
            let beforeTokenClean = s
            s = SpecialTokenSanitizer.cleanAIOutput(s, modelID: id)
            if s != beforeTokenClean { reasons.append("strip_special_tokens") }
        } else {
            // 모델 ID가 없는 경우 레거시 로직 사용 (하위 호환성)
            let beforeTemplates = s
            s = legacyStripTemplateMarkers(s)
            if s != beforeTemplates { reasons.append("strip_template_markers") }
        }

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

        // 3) 레거시 마커 제거는 이제 SpecialTokenSanitizer가 처리하므로 제거됨
        // (하위 호환성을 위해 legacyStripTemplateMarkers 함수는 유지)

        // 4) Clean up UTF-8 encoding issues and corrupted characters
        let beforeEncoding = s
        // Remove common UTF-8 replacement characters and broken sequences
        // 스트리밍 단계에서 U+FFFD는 보존되므로, 최종 단계에서도 무조건 제거하지 않음.
        // 최종 출력에서는 SpecialTokenSanitizer.cleanAIOutput가 U+FFFD를 안전하게 처리하므로 여기서는 중복 제거 금지.
        // (이중 제거로 인해 문맥 일부가 사라지거나 공백 정규화가 과하게 일어날 수 있음)
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

        // 6) Convert HTML line breaks to newlines (plain text only)
        //    - 일부 온디바이스/프록시 출력에서 <br>가 줄바꿈 용도로 사용됨 → UI에선 텍스트로 보이므로 변환
        //    - JSON 응답(프리셋 추천 등)은 변환 금지
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        var isLikelyJSON = false
        if (!t.isEmpty && ((t.first == "{" && t.last == "}") || (t.first == "[" && t.last == "]"))) {
            if let data = t.data(using: .utf8), (try? JSONSerialization.jsonObject(with: data)) != nil {
                isLikelyJSON = true
            }
        }
        if !isLikelyJSON {
            // 6.1) \n과 <br>가 중복 섞여 있을 때 하나의 개행으로 정규화
            // ex) "\n<br>\n" → "\n" , "<br>\n" → "\n" , "\n<br>" → "\n"
            let beforeNorm = s
            s = s.replacingOccurrences(
                of: #"(?is)(?:\r\n|\r|\n)?\s*<br\s*/?>\s*(?:\r\n|\r|\n)?"#,
                with: "\n",
                options: .regularExpression
            )
            if s != beforeNorm { reasons.append("normalize_br_with_newlines") }

            // 6.2) 남은 <br>를 개행으로 변환
            let beforeBR = s
            s = s.replacingOccurrences(
                of: #"(?i)<br\s*/?>"#,
                with: "\n",
                options: .regularExpression
            )
            if s != beforeBR { reasons.append("convert_br_to_newline") }

            // 6.3) 연속 개행 2개 이상 → 1개로 축약(시/문단 이중 간격 방지)
            let beforeCollapse = s
            s = s.replacingOccurrences(
                of: #"\n{2,}"#,
                with: "\n",
                options: .regularExpression
            )
            if s != beforeCollapse { reasons.append("collapse_newlines") }
        }

        // 7) Final trim
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
        var lastAssistantText: String?
        if let arr = history {
            for item in arr {
                if let dict = item as? [String: Any],
                   let role = dict["role"] as? String,
                   role.lowercased() == "assistant" {
                    hasAssistantBefore = true
                    if let c = dict["content"] as? String { lastAssistantText = c }
                } else {
                    // Fallback: try Mirror for struct-like objects (AIConversationTurn)
                    let m = Mirror(reflecting: item)
                    var roleValue: String?
                    var contentValue: String?
                    for child in m.children {
                        if child.label == "role" {
                            roleValue = String(describing: child.value).lowercased()
                        } else if child.label == "content" {
                            contentValue = String(describing: child.value)
                        }
                    }
                    if let r = roleValue, r.contains("assistant") {
                        hasAssistantBefore = true
                        if let c = contentValue { lastAssistantText = c }
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

        // 1) Strip greeting words at start
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

        var changed = false
        outer: for p in patterns {
            if let re = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) {
                let ns = s as NSString
                let range = NSRange(location: 0, length: ns.length)
                if let match = re.firstMatch(in: s, options: [], range: range) {
                    s = ns.replacingCharacters(in: match.range, with: "")
                    reasons.append("strip_greeting")
                    changed = true
                    break outer
                }
            }
        }

        // 2) Strip common self-intro lines (Korean persona preamble), only on later turns
        let selfIntroPatterns: [String] = [
            #"^\s*(?:저는|나는)\s*[^\n]{0,40}(?:AI\s*친구|도우미|파트너|비서)[^\n]{0,40}입니다[.!]?\s*$"#,
            #"^\s*(?:저는|나는)\s*[^\n]{0,80}(?:도와드리|도와줄|도와 드리)[^\n]*$"#,
            #"^\s*[^\n]{0,20}궁금한\s*점[^\n]{0,40}언제든지\s*물어보세요[^\n]*$"#,
        ]
        // Apply per line for the first 2 lines max
        var lines = s.components(separatedBy: "\n")
        let maxCheck = min(2, lines.count)
        var removedCount = 0
        if maxCheck > 0 {
            for i in 0..<maxCheck {
                let line = lines[i]
                for pat in selfIntroPatterns {
                    if let re = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]) {
                        let ns = line as NSString
                        let range = NSRange(location: 0, length: ns.length)
                        if re.firstMatch(in: line, options: [], range: range) != nil {
                            lines[i] = ""
                            removedCount += 1
                            changed = true
                            reasons.append("strip_self_intro")
                            break
                        }
                    }
                }
            }
        }
        if removedCount > 0 {
            s = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: "\n")
        }

        // 3) If the new reply starts with nearly the same prefix as the last assistant reply, drop that prefix line
        if let prev = lastAssistantText, !prev.isEmpty, !s.isEmpty {
            func normalize(_ t: String) -> String {
                // Keep letters, numbers, Hangul; lowercased, remove spaces/punct
                let lowered = t.lowercased()
                let allowed = lowered.unicodeScalars.filter { scalar in
                    CharacterSet.alphanumerics.contains(scalar)
                    || (scalar.value >= 0xAC00 && scalar.value <= 0xD7A3)  // Hangul syllables
                }
                return String(String.UnicodeScalarView(allowed))
            }
            let prevNorm = normalize(prev)
            let sNorm = normalize(s)
            let k = min(80, min(prevNorm.count, sNorm.count))
            if k >= 24 {
                let prevPrefix = String(prevNorm.prefix(k))
                let newPrefix = String(sNorm.prefix(k))
                if prevPrefix == newPrefix {
                    // Remove first line from the original s
                    if let range = s.range(of: "\n") {
                        s = String(s[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        changed = true
                        reasons.append("strip_duplicate_prefix")
                    } else {
                        // Single-line duplicate → return as-is (no content to preserve)
                    }
                }
            }
        }

        // 4) 한국어 말끝 짧은 호응 제거(옵션): 기본 비활성. 사용자가 명시적으로 켜는 경우에만 동작.
        var final = s
        if ConfigReader.bool("AI_STRIP_TAIL_INTERJECTION", default: false) ?? false {
            let minBodyLenForTailStrip = 30
            let tailCandidates: Set<String> = ["어", "응", "음", "흠", "허", "헉", "아", "엥", "어어", "응응", "음음"]
            do {
                let parts = final.components(separatedBy: "\n")
                if parts.count >= 1 {
                    let head = parts.dropLast().joined(separator: "\n")
                    let last = parts.last!.trimmingCharacters(in: .whitespacesAndNewlines)
                    // 허용된 매우 짧은 호응 + 선택적 구두점만 있는지 검사
                    let strippedPunct = last.replacingOccurrences(of: #"[?!.…\s]"#, with: "", options: .regularExpression)
                    if tailCandidates.contains(strippedPunct), head.trimmingCharacters(in: .whitespacesAndNewlines).count >= minBodyLenForTailStrip {
                        final = head
                        reasons.append("strip_tail_interjection")
                    }
                }
                // 같은 줄(개행 없음)에서도 문장 끝의 단독 호응을 제거
                if final.trimmingCharacters(in: .whitespacesAndNewlines).count >= minBodyLenForTailStrip {
                    if let r = final.range(of: #"(?:\s|\n)+(?:어|응|음|흠|허|헉|아|엥|어어|응응|음음)\s*[?!.…]?$"#, options: .regularExpression) {
                        final.removeSubrange(r)
                        reasons.append("strip_tail_interjection_inline")
                    }
                }
            }
        }
        let trimmed = final.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != final { reasons.append("trim_whitespace") }
        return (trimmed, reasons.isEmpty ? nil : reasons.joined(separator: ","))
    }
    
    // MARK: - Legacy Support
    
    /// 레거시 템플릿 마커 제거 (하위 호환성)
    /// - Parameter text: 입력 텍스트
    /// - Returns: 정화된 텍스트
    private static func legacyStripTemplateMarkers(_ text: String) -> String {
        var s = text
        
        // 기존 로직 유지 (하위 호환성)
        let templateMarkers: [String] = [
            "<|im_start|>assistant",
            "<|im_start|>user",
            "<|im_start|>system",
            "<|im_start|>",
            "<|im_end|>",
            "<|endofturn|>",
            "<|stop|>",
            "<start_of_turn>user",
            "<start_of_turn>model",
            "<start_of_turn>assistant",
            "<start_of_turn>",
            "<end_of_turn>",
            "<eos>",
            "</s>",
            "<|eot_id|>",
            "<|end_of_text|>",
            "<|im_",
            "<start_of_",
            "<end_of_",
        ]
        
        for marker in templateMarkers {
            s = s.replacingOccurrences(of: marker, with: "")
        }
        
        let templatePatterns: [String] = [
            #"<\|[^|]*\|>"#,
            #"<[^>]*_of_turn[^>]*>"#,
            #"<\|[^>]*$"#,
            #"^[^<]*\|>"#,
        ]
        
        for pattern in templatePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: s.count)
                s = regex.stringByReplacingMatches(
                    in: s, options: [], range: range, withTemplate: "")
            }
        }
        
        return s
    }
}
