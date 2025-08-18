import Foundation

public enum AIProvider {
    case openAI
    case anthropic
    case google
    case naver
    case openrouter
    case unknown
}

public final class AIResponseParser {
    public static let shared = AIResponseParser()
    private init() {}

    public func parse(_ raw: String, from provider: AIProvider) -> String {
        // 50k 문자 상한 (보안/성능)
        let capped = String(raw.prefix(50_000))

        // 1) JSON 시도
        if let data = capped.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let common = self.parseCommon(obj) {
                return sanitize(common)
            }
            if let specific = self.parseByProvider(obj, provider: provider) {
                return sanitize(specific)
            }
        }

        // 2) 코드펜스/마크다운 제거 + 폴백
        return sanitize(stripCodeFences(capped))
    }

    // 공통 키 우선
    private func parseCommon(_ json: [String: Any]) -> String? {
        let keys = ["message", "response", "text", "content"]
        for k in keys {
            if let v = json[k] as? String, v.isEmpty == false { return v }
        }
        return nil
    }

    // 공급자별 경로
    private func parseByProvider(_ json: [String: Any], provider: AIProvider) -> String? {
        switch provider {
        case .openAI:
            // choices[0].message.content
            if let choices = json["choices"] as? [[String: Any]],
               let msg = choices.first?["message"] as? [String: Any],
               let content = msg["content"] as? String, !content.isEmpty {
                return content
            }
        case .anthropic:
            // content: [{type:"text", text:"..."}]
            if let contents = json["content"] as? [[String: Any]] {
                let texts = contents.compactMap { $0["text"] as? String }
                if let t = texts.first, !t.isEmpty { return t }
            }
        case .google:
            // candidates[0].content.parts[].text
            if let cands = json["candidates"] as? [[String: Any]],
               let content = cands.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]] {
                let text = parts.compactMap { $0["text"] as? String }.joined(separator: "\n")
                if !text.isEmpty { return text }
            }
        case .naver:
            // message.result or result.output (가정)
            if let msg = json["message"] as? [String: Any],
               let result = msg["result"] as? String, !result.isEmpty {
                return result
            }
            if let result = json["result"] as? [String: Any],
               let out = result["output"] as? String, !out.isEmpty {
                return out
            }
        case .openrouter:
            // OpenAI 호환인 경우가 많음
            if let choices = json["choices"] as? [[String: Any]],
               let msg = choices.first?["message"] as? [String: Any],
               let content = msg["content"] as? String, !content.isEmpty {
                return content
            }
        case .unknown:
            break
        }
        return nil
    }

    // 간단한 살균: 코드펜스/마크다운 제거, 위험 이스케이프 축약
    private func sanitize(_ s: String) -> String {
        var out = s.replacingOccurrences(of: "\r\n", with: "\n")
        out = out.replacingOccurrences(of: "\u{0000}", with: "")
        // 과도한 백틱/마크다운 제거
        out = stripCodeFences(out)
        // JSON 인젝션 가능성 낮추기 위해 leading/trailing 펜스나 BOM 제거
        out = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return out
    }

    private func stripCodeFences(_ s: String) -> String {
        var lines = s.components(separatedBy: "\n")
        if let first = lines.first, first.starts(with: "```") {
            lines.removeFirst()
        }
        if let last = lines.last, last.starts(with: "```") {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }
}