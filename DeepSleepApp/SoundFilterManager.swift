import Foundation

/// 🆕 확장 가능한 사운드 조합 필터링 관리자
/// 사운드 간의 호환성을 관리하고 최적의 조합을 추천하는 모듈
class SoundFilterManager {
    
    // MARK: - 🆕 동적 호환성 규칙 정의
    
    /// 강한 비호환성 조합 (ID 기반)
    private static let strongIncompatibilities: [(String, String)] = [
        ("cat", "keyboard"),   // 고양이 + 키보드
        ("fire", "fan"),       // 불 + 쿨링팬
    ]
    
    /// 일반 비호환성 조합 (ID 기반)
    private static let generalIncompatibilities: [(String, String)] = [
        ("pencil", "keyboard"), // 연필 + 키보드 (업무 소음)
        ("pencil", "cat"),      // 연필 + 고양이 (집중 방해)
    ]
    
    /// 조화로운 조합 패턴 (ID 기반)
    private static let harmoniousGroups: [[String]] = [
        ["rain", "stream", "waves"],     // 물 소리 그룹
        ["wind", "night", "space"],      // 자연 + 집중
        ["pencil", "keyboard"],          // 업무 소음
        ["cat", "fire", "night"],        // 편안함 그룹
        ["birds", "stream", "wind"]      // 자연 소리 그룹
    ]
    
    // MARK: - 🆕 동적 필터링 메소드
    
    /// 🆕 ID를 인덱스로 변환하는 헬퍼 메서드
    private static func getIndex(for soundId: String) -> Int? {
        return SoundManager.shared.getSoundIndex(for: soundId)
    }
    
    /// 🆕 인덱스를 ID로 변환하는 헬퍼 메서드
    private static func getId(for index: Int) -> String? {
        return SoundManager.shared.getSoundCatalog(at: index)?.id
    }
    
    /// 강한 비호환성 체크 및 자동 조정 (동적)
    /// - Parameter volumes: 현재 볼륨 배열 (inout으로 수정됨)
    static func applyStrongFiltering(volumes: inout [Float]) {
        for (id1, id2) in strongIncompatibilities {
            guard let index1 = getIndex(for: id1),
                  let index2 = getIndex(for: id2),
                  index1 < volumes.count && index2 < volumes.count else { continue }
            
            if volumes[index1] > 0 && volumes[index2] > 0 {
                // 나중에 설정된 것을 우선하여 이전 것을 0으로
                volumes[index1] = 0
                print("🚫 [Filter] 강한 비호환성: \(id1)(\(index1)번) 사운드 자동 해제")
            }
        }
    }
    
    /// 일반 비호환성 경고 체크 (동적)
    /// - Parameter volumes: 현재 볼륨 배열
    /// - Returns: 경고 메시지 배열
    static func checkGeneralIncompatibilities(volumes: [Float]) -> [String] {
        var warnings: [String] = []
        
        for (id1, id2) in generalIncompatibilities {
            guard let index1 = getIndex(for: id1),
                  let index2 = getIndex(for: id2),
                  index1 < volumes.count && index2 < volumes.count else { continue }
            
            if volumes[index1] > 0 && volumes[index2] > 0 {
                let name1 = SoundManager.shared.getSoundCatalog(at: index1)?.baseName ?? id1
                let name2 = SoundManager.shared.getSoundCatalog(at: index2)?.baseName ?? id2
                warnings.append("⚠️ \(name1)과 \(name2)는 함께 사용 시 효과가 떨어질 수 있습니다.")
            }
        }
        
        return warnings
    }
    
    /// 조화로운 조합 추천 (동적)
    /// - Parameter currentVolumes: 현재 볼륨 배열
    /// - Returns: 추천 메시지 배열
    static func getHarmoniousRecommendations(currentVolumes: [Float]) -> [String] {
        var recommendations: [String] = []
        
        let activeIds = currentVolumes.enumerated()
            .compactMap { index, volume in
                volume > 0 ? getId(for: index) : nil
            }
        
        for group in harmoniousGroups {
            let groupActive = group.filter { activeIds.contains($0) }
            if groupActive.count == 1 {
                let remaining = group.filter { !activeIds.contains($0) }
                let remainingNames: [String] = remaining.compactMap { id in
                    guard let index = getIndex(for: id) else { return nil }
                    return SoundManager.shared.getSoundCatalog(at: index)?.baseName
                }
                
                if !remainingNames.isEmpty {
                    recommendations.append("💡 추천: \(remainingNames.joined(separator: ", ")) 사운드와 조화롭습니다")
                }
            }
        }
        
        return recommendations
    }
    
    // MARK: - 통합 필터링 메소드
    
    /// 모든 필터링 규칙을 한번에 적용
    /// - Parameter volumes: 현재 볼륨 배열
    /// - Returns: (수정된 볼륨 배열, 경고 메시지, 추천 메시지)
    static func applyAllFilters(volumes: [Float]) -> (filteredVolumes: [Float], warnings: [String], recommendations: [String]) {
        var filteredVolumes = volumes
        
        // 1. 강한 비호환성 자동 필터링
        applyStrongFiltering(volumes: &filteredVolumes)
        
        // 2. 일반 비호환성 경고 수집
        let warnings = checkGeneralIncompatibilities(volumes: filteredVolumes)
        
        // 3. 조화로운 조합 추천
        let recommendations = getHarmoniousRecommendations(currentVolumes: filteredVolumes)
        
        return (filteredVolumes, warnings, recommendations)
    }
    
    // MARK: - 호환성 분석
    
    /// 특정 사운드와 호환되는 사운드 인덱스 반환 (동적)
    /// - Parameter soundIndex: 대상 사운드 인덱스
    /// - Returns: 호환되는 사운드 인덱스 배열
    static func getCompatibleSounds(for soundIndex: Int) -> [Int] {
        guard let targetId = getId(for: soundIndex) else { return [] }
        
        var compatible: [Int] = []
        
        // 강한 비호환성 ID 수집
        let stronglyIncompatibleIds = strongIncompatibilities
            .filter { $0.0 == targetId || $0.1 == targetId }
            .flatMap { [$0.0, $0.1] }
            .filter { $0 != targetId }
        
        // 모든 카테고리 확인
        let categoryCount = SoundManager.shared.categoryCount
        for i in 0..<categoryCount {
            if i != soundIndex,
               let currentId = getId(for: i),
               !stronglyIncompatibleIds.contains(currentId) {
                compatible.append(i)
            }
        }
        
        return compatible
    }
    
    /// 호환성 점수 계산 (0-100) (동적)
    /// - Parameter volumes: 현재 볼륨 배열
    /// - Returns: 호환성 점수
    static func calculateCompatibilityScore(volumes: [Float]) -> Int {
        let activeIds = volumes.enumerated()
            .compactMap { index, volume in
                volume > 0 ? getId(for: index) : nil
            }
        
        if activeIds.count <= 1 {
            return 100 // 단일 사운드는 완벽한 호환성
        }
        
        var score = 100
        var conflicts = 0
        
        // 강한 비호환성 페널티
        for (id1, id2) in strongIncompatibilities {
            if activeIds.contains(id1) && activeIds.contains(id2) {
                conflicts += 30
            }
        }
        
        // 일반 비호환성 페널티
        for (id1, id2) in generalIncompatibilities {
            if activeIds.contains(id1) && activeIds.contains(id2) {
                conflicts += 15
            }
        }
        
        // 조화로운 조합 보너스
        for group in harmoniousGroups {
            let groupActive = group.filter { activeIds.contains($0) }
            if groupActive.count >= 2 {
                score += min(10, groupActive.count * 3) // 최대 10점 보너스
            }
        }
        
        return max(0, min(100, score - conflicts))
    }
    
    // MARK: - 🆕 확장성 지원 메서드
    
    /// 새로운 사운드 추가 시 호환성 규칙 동적 생성
    /// - Parameter newSoundId: 새로 추가된 사운드 ID
    /// - Returns: 추천 호환성 규칙
    static func generateCompatibilityRulesForNewSound(_ newSoundId: String) -> [String: [String]] {
        // 사운드 특성 기반 자동 분류
        let soundCharacteristics = analyzeSoundCharacteristics(newSoundId)
        
        var rules: [String: [String]] = [:]
        
        // 기존 조화로운 그룹과의 매칭
        for group in harmoniousGroups {
            let compatibility = calculateGroupCompatibility(newSoundId, with: group, characteristics: soundCharacteristics)
            if compatibility > 0.7 {
                rules["harmonious"] = (rules["harmonious"] ?? []) + group
            }
        }
        
        return rules
    }
    
    /// 사운드 특성 분석 (확장 가능)
    private static func analyzeSoundCharacteristics(_ soundId: String) -> [String: Double] {
        // 기본 특성 분석 (추후 ML 모델로 확장 가능)
        var characteristics: [String: Double] = [:]
        
        switch soundId.lowercased() {
        case let id where id.contains("water") || id.contains("rain") || id.contains("stream"):
            characteristics["water"] = 1.0
            characteristics["natural"] = 1.0
            characteristics["calming"] = 0.9
        case let id where id.contains("wind") || id.contains("air"):
            characteristics["air"] = 1.0
            characteristics["natural"] = 1.0
            characteristics["calming"] = 0.8
        case let id where id.contains("fire"):
            characteristics["fire"] = 1.0
            characteristics["warm"] = 1.0
            characteristics["calming"] = 0.7
        case let id where id.contains("keyboard") || id.contains("pencil"):
            characteristics["work"] = 1.0
            characteristics["focus"] = 0.9
            characteristics["artificial"] = 1.0
        default:
            characteristics["neutral"] = 1.0
        }
        
        return characteristics
    }
    
    /// 그룹 호환성 계산
    private static func calculateGroupCompatibility(_ soundId: String, with group: [String], characteristics: [String: Double]) -> Double {
        // 간단한 호환성 계산 (추후 정교화 가능)
        let groupCharacteristics = group.compactMap { analyzeSoundCharacteristics($0) }
        
        // 특성 유사도 계산
        var totalSimilarity = 0.0
        var count = 0
        
        for groupChar in groupCharacteristics {
            for (key, value) in characteristics {
                if let groupValue = groupChar[key] {
                    totalSimilarity += min(value, groupValue)
                    count += 1
                }
            }
        }
        
        return count > 0 ? totalSimilarity / Double(count) : 0.0
    }
} 

// MARK: - Data Structures for Filtering
// `large_tuple` 대체를 위한 구조체 정의

struct FilteredSoundResult {
    let presets: [SoundPreset]
    let filteredCount: Int
    let totalCount: Int
}

extension SoundFilterManager {
    
    func filterSounds(by keyword: String, in category: String?) -> FilteredSoundResult {
        // todo: 실제 필터링 로직 구현 필요
        let allPresets = SoundPresetCatalog.shared.presets
        let filtered = allPresets.filter { $0.name.contains(keyword) }
        
        return FilteredSoundResult(
            presets: filtered,
            filteredCount: filtered.count,
            totalCount: allPresets.count
        )
    }
} 
