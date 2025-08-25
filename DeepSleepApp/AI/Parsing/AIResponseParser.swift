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

        // 0) 코드펜스 제거(가벼운 전처리)
        let defenced = stripCodeFences(capped)

        // 1) 전체 JSON 시도
        if let data = defenced.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let common = self.parseCommon(obj) { return sanitize(common) }
            if let specific = self.parseByProvider(obj, provider: provider) { return sanitize(specific) }
        }

        // 2) 혼합 출력(텍스트 + JSON)에서 첫 JSON 객체만 추출 후 재시도
        if let jsonSlice = extractFirstJSONObjectString(defenced) {
            if let data = jsonSlice.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let common = self.parseCommon(obj) { return sanitize(common) }
                if let specific = self.parseByProvider(obj, provider: provider) { return sanitize(specific) }
            } else {
                print("❌ [AIResponseParser] JSON slice 파싱 실패")
            }
        } else {
            print("ℹ️ [AIResponseParser] JSON 객체 미검출 - 혼합 출력 아님")
        }

        // 3) 폴백: 코드펜스/마크다운 제거 후 반환
        return sanitize(defenced)
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

    // 혼합 출력에서 첫 번째 JSON 객체 서브스트링을 찾아 반환
    func extractFirstJSONObjectString(_ s: String) -> String? {
        let scalars = Array(s.unicodeScalars)
        guard let startIdx = scalars.firstIndex(where: { $0 == "{" }) else { return nil }
        var i = startIdx
        var depth = 0
        var inString = false
        var escaped = false
        while i < scalars.count {
            let ch = scalars[i]
            if inString {
                if escaped { escaped = false }
                else if ch == "\\" { escaped = true }
                else if ch == "\"" { inString = false }
            } else {
                if ch == "\"" { inString = true }
                else if ch == "{" { depth += 1 }
                else if ch == "}" {
                    depth -= 1
                    if depth == 0 {
                        let slice = String(String.UnicodeScalarView(scalars[startIdx...i]))
                        return slice
                    }
                }
            }
            i += 1
        }
        return nil
    }
}
