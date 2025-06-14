import Foundation

/// 사운드 조합 필터링 관리자
/// 사운드 간의 호환성을 관리하고 최적의 조합을 추천하는 모듈
class SoundFilterManager {
    
    // MARK: - 호환성 규칙 정의
    
    /// 강한 비호환성 조합 (자동으로 0으로 설정)
    private static let strongIncompatibilities: [(Int, Int)] = [
        (0, 9),   // 고양이 + 키보드
        (3, 8),   // 불 + 쿨링팬
    ]
    
    /// 일반 비호환성 조합 (경고 표시)
    private static let generalIncompatibilities: [(Int, Int)] = [
        (7, 9),   // 연필 + 키보드 (업무 소음)
        (7, 0),   // 연필 + 고양이 (집중 방해)
    ]
    
    /// 조화로운 조합 패턴
    private static let harmoniousGroups: [[Int]] = [
        [4, 5, 10],     // 물 소리 그룹: 비, 시냇물, 파도
        [1, 2, 7],      // 자연 + 집중: 바람, 밤, 우주
        [7, 9],         // 업무 소음: 연필, 키보드
    ]
    
    // MARK: - 필터링 메소드
    
    /// 강한 비호환성 체크 및 자동 조정
    /// - Parameter volumes: 현재 볼륨 배열 (inout으로 수정됨)
    static func applyStrongFiltering(volumes: inout [Float]) {
        for (index1, index2) in strongIncompatibilities {
            guard index1 < volumes.count && index2 < volumes.count else { continue }
            
            if volumes[index1] > 0 && volumes[index2] > 0 {
                // 나중에 설정된 것을 우선하여 이전 것을 0으로
                volumes[index1] = 0
                print("🚫 [Filter] 강한 비호환성: \(index1)번 사운드 자동 해제")
            }
        }
    }
    
    /// 일반 비호환성 경고 체크
    /// - Parameter volumes: 현재 볼륨 배열
    /// - Returns: 경고 메시지 배열
    static func checkGeneralIncompatibilities(volumes: [Float]) -> [String] {
        var warnings: [String] = []
        
        for (index1, index2) in generalIncompatibilities {
            guard index1 < volumes.count && index2 < volumes.count else { continue }
            
            if volumes[index1] > 0 && volumes[index2] > 0 {
                warnings.append("⚠️ \(index1)번과 \(index2)번 사운드는 함께 사용 시 효과가 떨어질 수 있습니다.")
            }
        }
        
        return warnings
    }
    
    /// 조화로운 조합 추천
    /// - Parameter currentVolumes: 현재 볼륨 배열
    /// - Returns: 추천 메시지 배열
    static func getHarmoniousRecommendations(currentVolumes: [Float]) -> [String] {
        var recommendations: [String] = []
        
        let activeIndices = currentVolumes.enumerated()
            .compactMap { $0.element > 0 ? $0.offset : nil }
        
        for group in harmoniousGroups {
            let groupActive = group.filter { activeIndices.contains($0) }
            if groupActive.count == 1 {
                let remaining = group.filter { !activeIndices.contains($0) }
                if !remaining.isEmpty {
                    recommendations.append("💡 추천: \(remaining.map { "\($0)번" }.joined(separator: ", ")) 사운드와 조화롭습니다")
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
    
    /// 특정 사운드와 호환되는 사운드 인덱스 반환
    /// - Parameter soundIndex: 대상 사운드 인덱스
    /// - Returns: 호환되는 사운드 인덱스 배열
    static func getCompatibleSounds(for soundIndex: Int) -> [Int] {
        var compatible: [Int] = []
        
        // 강한 비호환성 제외
        let stronglyIncompatible = strongIncompatibilities
            .filter { $0.0 == soundIndex || $0.1 == soundIndex }
            .flatMap { [$0.0, $0.1] }
            .filter { $0 != soundIndex }
        
        for i in 0..<11 { // 총 11개 사운드
            if i != soundIndex && !stronglyIncompatible.contains(i) {
                compatible.append(i)
            }
        }
        
        return compatible
    }
    
    /// 호환성 점수 계산 (0-100)
    /// - Parameter volumes: 현재 볼륨 배열
    /// - Returns: 호환성 점수
    static func calculateCompatibilityScore(volumes: [Float]) -> Int {
        let activeIndices = volumes.enumerated()
            .compactMap { $0.element > 0 ? $0.offset : nil }
        
        if activeIndices.count <= 1 {
            return 100 // 단일 사운드는 완벽한 호환성
        }
        
        var score = 100
        var conflicts = 0
        
        // 강한 비호환성 페널티
        for (index1, index2) in strongIncompatibilities {
            if activeIndices.contains(index1) && activeIndices.contains(index2) {
                conflicts += 30
            }
        }
        
        // 일반 비호환성 페널티
        for (index1, index2) in generalIncompatibilities {
            if activeIndices.contains(index1) && activeIndices.contains(index2) {
                conflicts += 15
            }
        }
        
        // 조화로운 조합 보너스
        for group in harmoniousGroups {
            let groupActive = group.filter { activeIndices.contains($0) }
            if groupActive.count >= 2 {
                score += min(10, groupActive.count * 3) // 최대 10점 보너스
            }
        }
        
        return max(0, min(100, score - conflicts))
    }
} 