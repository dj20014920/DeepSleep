import UIKit

// MARK: - ChatViewController + 프리셋 관련 extension
extension ChatViewController {
    
    // MARK: - AI 응답 파싱
    func parsePresetRecommendation(from response: String) -> EnhancedRecommendationResponse? {
        print("🎵 프리셋 파싱 시작: \(response.prefix(100))...")
        
        // 1. 새로운 11개 형식 파싱 시도
        if let result = parseNewFormat(from: response) {
            print("✅ 새로운 11개 형식 파싱 성공")
            return result
        }
        
        // 2. 기존 12개 형식 파싱 시도
        if let result = parseLegacyFormat(from: response) {
            print("✅ 기존 12개 형식 파싱 성공")
            return result
        }
        
        // 3. 감정 기반 기본 프리셋 반환
        let fallbackResult = parseBasicFormat(from: response)
        print("⚠️ 파싱 실패, 기본 프리셋 사용")
        return fallbackResult
    }
    
    // MARK: - 새로운 11개 형식 파싱
    private func parseNewFormat(from response: String) -> EnhancedRecommendationResponse? {
        let pattern = #"(\w+):(\d+)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let matches = regex?.matches(in: response, options: [], range: NSRange(location: 0, length: response.count)) ?? []
        
        if matches.count < 5 { return nil }
        
        var volumes: [Float] = Array(repeating: 0, count: SoundPresetCatalog.categoryCount)
        var versions: [Int] = SoundPresetCatalog.defaultVersionSelection
        var presetName = "🎵 AI 추천"
        
        for match in matches {
            guard match.numberOfRanges == 3 else { continue }
            
            let categoryRange = Range(match.range(at: 1), in: response)!
            let volumeRange = Range(match.range(at: 2), in: response)!
            
            let category = String(response[categoryRange])
            let volumeStr = String(response[volumeRange])
            
            guard let volume = Float(volumeStr) else { continue }
            
            if let index = SoundPresetCatalog.getIndex(for: category) {
                volumes[index] = min(100, max(0, volume))
            }
        }
        
        // 프리셋 이름 추출
        if let nameMatch = response.range(of: #""([^"]+)""#, options: .regularExpression) {
            presetName = String(response[nameMatch]).replacingOccurrences(of: "\"", with: "")
        }
        
        // 조합 필터링 적용
        let filteredVolumes = SoundPresetCatalog.applyCompatibilityFilter(to: volumes)
        
        return EnhancedRecommendationResponse(
            volumes: filteredVolumes,
            presetName: presetName,
            selectedVersions: versions
        )
    }
    
    // MARK: - 기존 12개 형식 파싱
    private func parseLegacyFormat(from response: String) -> EnhancedRecommendationResponse? {
        let legacyCategories = ["Rain", "Thunder", "Ocean", "Fire", "Steam", "WindowRain", "Forest", "Wind", "Night", "Lullaby", "Fan", "WhiteNoise"]
        let pattern = #"(\w+):(\d+)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let matches = regex?.matches(in: response, options: [], range: NSRange(location: 0, length: response.count)) ?? []
        
        if matches.count < 5 { return nil }
        
        var legacyVolumes: [Float] = Array(repeating: 0, count: 12)
        var presetName = "🎵 AI 추천 (레거시)"
        
        for match in matches {
            guard match.numberOfRanges == 3 else { continue }
            
            let categoryRange = Range(match.range(at: 1), in: response)!
            let volumeRange = Range(match.range(at: 2), in: response)!
            
            let category = String(response[categoryRange])
            let volumeStr = String(response[volumeRange])
            
            guard let volume = Float(volumeStr) else { continue }
            
            if let index = legacyCategories.firstIndex(of: category) {
                legacyVolumes[index] = min(100, max(0, volume))
            }
        }
        
        // 12개 → 11개 변환
        let convertedVolumes = SoundPresetCatalog.convertLegacyVolumes(legacyVolumes)
        let filteredVolumes = SoundPresetCatalog.applyCompatibilityFilter(to: convertedVolumes)
        
        return EnhancedRecommendationResponse(
            volumes: filteredVolumes,
            presetName: presetName,
            selectedVersions: SoundPresetCatalog.defaultVersionSelection
        )
    }
    
    // MARK: - 감정별 기본 프리셋 (11개 카테고리)
    private func parseBasicFormat(from response: String) -> EnhancedRecommendationResponse? {
        let emotion = initialUserText ?? "😊"
        
        switch emotion {
        case "😢", "😞", "😔":  // 슬픔
            let volumes: [Float] = [40, 20, 70, 30, 60, 80, 0, 60, 20, 0, 50]
            return EnhancedRecommendationResponse(
                volumes: SoundPresetCatalog.applyCompatibilityFilter(to: volumes),
                presetName: "🌧️ 위로의 소리",
                selectedVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            )
            
        case "😰", "😱", "😨":  // 불안
            let volumes: [Float] = [60, 30, 50, 0, 70, 90, 0, 80, 40, 0, 60]
            return EnhancedRecommendationResponse(
                volumes: SoundPresetCatalog.applyCompatibilityFilter(to: volumes),
                presetName: "🌿 안정의 소리",
                selectedVersions: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0]
            )
            
        case "😴", "😪":  // 졸림/피곤
            let volumes: [Float] = [70, 40, 90, 20, 50, 60, 0, 80, 30, 0, 40]
            return EnhancedRecommendationResponse(
                volumes: SoundPresetCatalog.applyCompatibilityFilter(to: volumes),
                presetName: "🌙 깊은 잠의 소리",
                selectedVersions: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0]
            )
            
        case "😊", "😄", "🥰":  // 기쁨
            let volumes: [Float] = [80, 60, 40, 30, 20, 70, 40, 50, 20, 30, 80]
            return EnhancedRecommendationResponse(
                volumes: SoundPresetCatalog.applyCompatibilityFilter(to: volumes),
                presetName: "🌈 기쁨의 소리",
                selectedVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            )
            
        case "😡", "😤":  // 화남
            let volumes: [Float] = [30, 70, 60, 10, 80, 90, 0, 70, 50, 0, 70]
            return EnhancedRecommendationResponse(
                volumes: SoundPresetCatalog.applyCompatibilityFilter(to: volumes),
                presetName: "🌊 마음 달래는 소리",
                selectedVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            )
            
        case "😐", "🙂":  // 평온/무덤덤
            let volumes: [Float] = [50, 40, 60, 20, 40, 60, 60, 70, 40, 50, 50]
            return EnhancedRecommendationResponse(
                volumes: SoundPresetCatalog.applyCompatibilityFilter(to: volumes),
                presetName: "⚖️ 균형의 소리",
                selectedVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            )
            
        default:  // 기본값
            let volumes: [Float] = [40, 30, 50, 20, 30, 50, 40, 60, 30, 40, 40]
            return EnhancedRecommendationResponse(
                volumes: SoundPresetCatalog.applyCompatibilityFilter(to: volumes),
                presetName: "🎵 평온의 소리",
                selectedVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            )
        }
    }
}
