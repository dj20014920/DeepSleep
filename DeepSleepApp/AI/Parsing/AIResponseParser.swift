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

    // MARK: - Typed parse hook: Preset Recommendation
    public func parsePresetRecommendation(_ raw: String) -> EnhancedRecommendationResponse? {
        let capped = String(raw.prefix(50_000))
        let defenced = stripCodeFences(capped)
        // 1) Try whole JSON
        if let data = defenced.data(using: .utf8), let result = try? decodePreset(from: data) {
            return result
        }
        // 2) Try slice extraction
        if let jsonSlice = extractFirstJSONObjectString(defenced), let data = jsonSlice.data(using: .utf8), let result = try? decodePreset(from: data) {
            return result
        }
        // 3) Try heuristic legacy formats for tolerance
        if let legacy = parseNewFormatPreset(from: raw) { return legacy }
        if let legacy12 = parseLegacyFormatPreset(from: raw) { return legacy12 }
        // 4) Fallback basic (emotion/time-based)
        return parseBasicFormatPreset()
    }

    private func decodePreset(from jsonData: Data) throws -> EnhancedRecommendationResponse? {
        let decoder = JSONDecoder()
        let dto = try decoder.decode(AIPresetRecommendationDTO.self, from: jsonData)
        var resolvedName = dto.presetName ?? "대나무숲 추천"
        var volumes: [Float] = dto.volumes ?? []
        var outVersions: [Int] = SoundPresetCatalog.defaultVersions
        // presetKey 우선
        if volumes.isEmpty, let key = dto.presetKey, let preset = SoundPresetCatalog.scientificPresets[key] {
            volumes = preset
            if resolvedName.isEmpty || resolvedName == "AI 추천" { resolvedName = key }
        }
        // 모델이 직접 versions 배열을 제공한 경우 우선 사용(경계검사 포함)
        if outVersions.count == SoundPresetCatalog.categoryCount, let dtoVersions = (try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any])?["versions"] as? [Int] {
            let counts = (0..<SoundPresetCatalog.categoryCount).map { idx in
                SoundManager.shared.getSoundCatalog(at: idx)?.versions.count ?? 1
            }
            var adjusted = outVersions
            for i in 0..<min(dtoVersions.count, adjusted.count) {
                let maxCount = max(1, counts[i])
                let v = dtoVersions[i]
                adjusted[i] = (v >= 0 && v < maxCount) ? v : (SoundPresetCatalog.defaultVersions[i])
            }
            outVersions = adjusted
        }

        // items 기반 매핑
        if volumes.isEmpty, let items = dto.items, !items.isEmpty {
            let count = SoundPresetCatalog.categoryCount
            var arr = Array(repeating: Float(0), count: count)
            var vers = SoundPresetCatalog.defaultVersions
            for it in items {
                guard let sName = it.soundName else { continue }
                let vol = min(max(it.volume ?? 0, 0), 100)
                if let (catIdx, verIdx) = mapItemToCategoryAndVersion(soundName: sName, versionName: it.versionName) {
                    arr[catIdx] = vol
                    vers[catIdx] = verIdx
                } else if let idx = SoundPresetCatalog.findCategoryIndex(by: sName) {
                    arr[idx] = vol
                }
            }
            volumes = arr
            outVersions = vers
        }
        guard !volumes.isEmpty else { return nil }
        let confidenceValue = dto.confidence ?? 0.8
        guard confidenceValue >= 0.0 && confidenceValue <= 1.0 else { return nil }
        // normalize length
        let targetCount = SoundPresetCatalog.categoryCount
        if volumes.count != targetCount {
            if volumes.count > targetCount { volumes = Array(volumes.prefix(targetCount)) }
            else if volumes.count > 0 { volumes.append(contentsOf: Array(repeating: 0, count: targetCount - volumes.count)) }
            else { return nil }
        }
        volumes = volumes.map { min(max($0, 0), 100) }
        let filtered = SoundPresetCatalog.applyCompatibilityFilter(to: volumes)
        return EnhancedRecommendationResponse(
            presetName: "🧠 " + resolvedName,
            volumes: filtered,
            versions: outVersions,
            reason: dto.reason ?? "AI 추천 프리셋"
        )
    }

    private func mapItemToCategoryAndVersion(soundName: String, versionName: String?) -> (Int, Int)? {
        let count = SoundPresetCatalog.categoryCount
        var targetCat: Int? = SoundPresetCatalog.findCategoryIndex(by: soundName)
        if targetCat == nil {
            for i in 0..<count {
                if let c = SoundManager.shared.getSoundCatalog(at: i) {
                    if c.baseName.contains(soundName) || soundName.contains(c.baseName) { targetCat = i; break }
                }
            }
        }
        guard let cat = targetCat, let catalog = SoundManager.shared.getSoundCatalog(at: cat) else { return nil }
        if let vName = versionName, !vName.isEmpty {
            if let idx = catalog.versions.firstIndex(where: { $0.displayName.contains(vName) || vName.contains($0.displayName) }) {
                return (cat, idx)
            }
        }
        let def = catalog.versions.firstIndex { $0.isDefault } ?? 0
        return (cat, def)
    }

    private func parseNewFormatPreset(from response: String) -> EnhancedRecommendationResponse? {
        let pattern = #"(\w+):(\d+)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let matches = regex?.matches(in: response, options: [], range: NSRange(location: 0, length: response.count)) ?? []
        if matches.count < 5 { return nil }
        var volumes: [Float] = Array(repeating: 0, count: SoundPresetCatalog.categoryCount)
        var versions: [Int] = SoundPresetCatalog.defaultVersions
        var presetName = "🎵 AI 추천"
        for match in matches where match.numberOfRanges == 3 {
            let categoryRange = Range(match.range(at: 1), in: response)!
            let volumeRange = Range(match.range(at: 2), in: response)!
            let category = String(response[categoryRange])
            let volumeStr = String(response[volumeRange])
            guard let volume = Float(volumeStr) else { continue }
            if let index = SoundPresetCatalog.findCategoryIndex(by: category) {
                volumes[index] = min(100, max(0, volume))
            }
        }
        if let nameMatch = response.range(of: #"\"([^\"]+)\""#, options: .regularExpression) {
            presetName = String(response[nameMatch]).replacingOccurrences(of: "\"", with: "")
        }
        versions = generateOptimalVersions(volumes: volumes)
        let filtered = SoundPresetCatalog.applyCompatibilityFilter(to: volumes)
        return EnhancedRecommendationResponse(
            presetName: safePresetName(presetName),
            volumes: filtered,
            versions: versions,
            reason: "새로운 11개 형식 추천"
        )
    }

    private func parseLegacyFormatPreset(from response: String) -> EnhancedRecommendationResponse? {
        let legacyCategories = ["Rain", "Thunder", "Ocean", "Fire", "Steam", "WindowRain", "Forest", "Wind", "Night", "Lullaby", "Fan", "WhiteNoise"]
        let pattern = #"(\w+):(\d+)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let matches = regex?.matches(in: response, options: [], range: NSRange(location: 0, length: response.count)) ?? []
        if matches.count < 5 { return nil }
        var legacyVolumes: [Float] = Array(repeating: 0, count: 12)
        let presetName = "🎵 AI 추천 (레거시)"
        for match in matches where match.numberOfRanges == 3 {
            let categoryRange = Range(match.range(at: 1), in: response)!
            let volumeRange = Range(match.range(at: 2), in: response)!
            let category = String(response[categoryRange])
            let volumeStr = String(response[volumeRange])
            guard let volume = Float(volumeStr) else { continue }
            if let index = legacyCategories.firstIndex(of: category) {
                legacyVolumes[index] = min(100, max(0, volume))
            }
        }
        var converted: [Float] = Array(repeating: 0, count: 13)
        for i in 0..<min(12, converted.count) { converted[i] = legacyVolumes[i] }
        let filtered = SoundPresetCatalog.applyCompatibilityFilter(to: converted)
        return EnhancedRecommendationResponse(
            presetName: safePresetName(presetName),
            volumes: filtered,
            versions: SoundPresetCatalog.defaultVersions,
            reason: "레거시 12개 형식 추천"
        )
    }

    private func parseBasicFormatPreset() -> EnhancedRecommendationResponse? {
        let emotion = "평온"
        let volumes: [Float] = [30, 70, 60, 10, 80, 90, 0, 70, 50, 0, 70, 0, 0]
        return EnhancedRecommendationResponse(
            presetName: safePresetName("🌊 마음 달래는 소리"),
            volumes: SoundPresetCatalog.applyCompatibilityFilter(to: volumes),
            versions: generateOptimalVersions(volumes: volumes),
            reason: "기본 감정별 추천"
        )
    }

    private func generateOptimalVersions(volumes: [Float]) -> [Int] {
        var versions = SoundPresetCatalog.defaultVersions
        for (index, volume) in volumes.enumerated() {
            if SoundPresetCatalog.hasMultipleVersions(at: index) {
                switch index {
                case 1: versions[index] = volume > 60 ? 1 : 0
                case 2: versions[index] = volume > 70 ? 1 : 0
                case 4: versions[index] = volume > 50 ? 1 : 0
                case 9: versions[index] = volume > 65 ? 1 : 0
                case 10: versions[index] = volume > 60 ? 1 : 0
                case 11: versions[index] = volume > 55 ? 1 : 0
                case 12: versions[index] = volume > 50 ? 1 : 0
                default: break
                }
            }
        }
        return versions
    }

    private func safePresetName(_ name: String) -> String {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "🎵 AI 추천" : cleaned
    }

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
            
        }

        // 3) 폴백: 코드펜스/마크다운 제거 후 반환
        return sanitize(defenced)
    }

    // 공통 키 우선
    private func parseCommon(_ json: [String: Any]) -> String? {
        // 1) 가장 흔한 키 우선
        let keys = ["message", "response", "text", "content", "answer", "output", "result", "reply"]
        for k in keys {
            if let v = json[k] as? String, v.isEmpty == false { return unescapeIfNeeded(v) }
        }
        // 2) 중첩 객체 내부에 위 키들이 있을 수 있음 → 1단계만 탐색 (KISS)
        for (_, value) in json {
            if let nested = value as? [String: Any] {
                for k in keys {
                    if let v = nested[k] as? String, v.isEmpty == false { return unescapeIfNeeded(v) }
                }
            }
        }
        return nil
    }
    
    /// JSON 문자열로 이스케이프된 값일 경우 원복(예: \"...\" → ")
    private func unescapeIfNeeded(_ s: String) -> String {
        // 양끝이 쌍따옴표로 둘러싸였고, 내부에 이스케이프가 많은 경우 간단 복원
        var out = s
        if (out.hasPrefix("\"") && out.hasSuffix("\"")) || out.contains("\\\"") || out.contains("\\n") || out.contains("\\t") {
            out = out.replacingOccurrences(of: "\\\"", with: "\"")
            out = out.replacingOccurrences(of: "\\n", with: "\n")
            out = out.replacingOccurrences(of: "\\t", with: "\t")
            // 바깥쪽 따옴표 제거
            if out.hasPrefix("\"") && out.hasSuffix("\"") {
                out.removeFirst()
                out.removeLast()
            }
        }
        return out
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
