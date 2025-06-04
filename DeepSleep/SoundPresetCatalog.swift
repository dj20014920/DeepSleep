import Foundation

struct SoundPresetCatalog {
    
    // MARK: - 새로운 11개 카테고리 정의
    
    /// 카테고리별 이모지 (UI 표시용)
    static let categoryEmojis: [String] = [
        "🐱",  // 고양이
        "💨",  // 바람
        "🌙",  // 밤
        "🔥",  // 불
        "🌧️", // 비
        "🏞️", // 시냇물
        "✏️",  // 연필
        "🌌",  // 우주
        "🌀",  // 쿨링팬
        "⌨️",  // 키보드
        "🌊"   // 파도
    ]
    
    /// 카테고리별 이름
    static let categoryNames: [String] = [
        "고양이",
        "바람",
        "밤",
        "불",
        "비",
        "시냇물",
        "연필",
        "우주",
        "쿨링팬",
        "키보드",
        "파도"
    ]
    
    /// 이모지 + 이름 조합 (슬라이더 라벨용)
    static let displayLabels: [String] = [
        "🐱 고양이",
        "💨 바람",
        "🌙 밤",
        "🔥 불",
        "🌧️ 비",
        "🏞️ 시냇물",
        "✏️ 연필",
        "🌌 우주",
        "🌀 쿨링팬",
        "⌨️ 키보드",
        "🌊 파도"
    ]
    
    // MARK: - 카테고리별 파일 정보
    
    /// 각 카테고리의 사용 가능한 파일들
    static let categoryFiles: [[String]] = [
        ["고양이.mp3"],                    // 0: 🐱 고양이
        ["바람.mp3"],                      // 1: 💨 바람
        ["밤.mp3"],                        // 2: 🌙 밤
        ["불1.mp3"],                       // 3: 🔥 불
        ["비.mp3", "비-창문.mp3"],           // 4: 🌧️ 비 (2가지 버전)
        ["시냇물.mp3"],                    // 5: 🏞️ 시냇물
        ["연필.mp3"],                      // 6: ✏️ 연필
        ["우주.mp3"],                      // 7: 🌌 우주
        ["쿨링팬.mp3"],                    // 8: 🌀 쿨링팬
        ["키보드1.mp3", "키보드2.mp3"],     // 9: ⌨️ 키보드 (2가지 버전)
        ["파도.mp3"]                       // 10: 🌊 파도
    ]
    
    /// 각 카테고리의 기본 선택 파일 인덱스
    static let defaultVersions: [Int] = [
        0,  // 고양이: 고양이.mp3
        0,  // 바람: 바람.mp3
        0,  // 밤: 밤.mp3
        0,  // 불: 불1.mp3
        0,  // 비: 비.mp3 (기본), 비-창문.mp3는 버전2
        0,  // 시냇물: 시냇물.mp3
        0,  // 연필: 연필.mp3
        0,  // 우주: 우주.mp3
        0,  // 쿨링팬: 쿨링팬.mp3
        0,  // 키보드: 키보드1.mp3 (기본), 키보드2.mp3는 버전2
        0   // 파도: 파도.mp3
    ]
    
    // MARK: - 기존 호환성 (임시)
    
    /// 기존 A-L 라벨과의 호환성 유지 (Migration 용도)
    @available(*, deprecated, message: "Use displayLabels instead")
    static let labels: [String] = categoryNames
    
    // MARK: - 유틸리티 메서드
    
    /// 총 카테고리 개수
    static var categoryCount: Int {
        return categoryNames.count
    }
    
    /// 특정 인덱스의 완전한 정보
    static func getCategoryInfo(at index: Int) -> (emoji: String, name: String, files: [String], defaultIndex: Int)? {
        guard index >= 0, index < categoryCount else { return nil }
        
        return (
            emoji: categoryEmojis[index],
            name: categoryNames[index],
            files: categoryFiles[index],
            defaultIndex: defaultVersions[index]
        )
    }
    
    /// 카테고리에 여러 버전이 있는지 확인
    static func hasMultipleVersions(at index: Int) -> Bool {
        guard index >= 0, index < categoryFiles.count else { return false }
        return categoryFiles[index].count > 1
    }
    
    /// 특정 카테고리의 버전 개수
    static func getVersionCount(at index: Int) -> Int {
        guard index >= 0, index < categoryFiles.count else { return 0 }
        return categoryFiles[index].count
    }
    
    /// 버전 이름 생성 (예: "키보드1", "키보드2")
    static func getVersionName(categoryIndex: Int, versionIndex: Int) -> String {
        guard let info = getCategoryInfo(at: categoryIndex),
              versionIndex >= 0, versionIndex < info.files.count else {
            return "Unknown"
        }
        
        let fileName = info.files[versionIndex]
        return fileName.replacingOccurrences(of: ".mp3", with: "")
    }
    
    /// 카테고리명으로 인덱스 찾기
    static func findCategoryIndex(by name: String) -> Int? {
        if let index = categoryNames.firstIndex(of: name) {
            return index
        }
        
        // 이모지로도 찾기
        if let index = categoryEmojis.firstIndex(of: name) {
            return index
        }
        
        return nil
    }
    
    // MARK: - 프리셋 템플릿
    
    /// 기본 프리셋 (모든 볼륨 0)
    static let defaultPreset: [Float] = Array(repeating: 0.0, count: categoryCount)
    
    /// 샘플 프리셋들
    static let samplePresets: [String: [Float]] = [
        "🌧️ 빗소리 집중": [0, 0, 0, 0, 80, 0, 0, 0, 0, 0, 30],      // 비 + 파도
        "🔥 따뜻한 밤": [0, 20, 60, 70, 0, 0, 0, 40, 0, 0, 0],        // 바람 + 밤 + 불 + 우주
        "⌨️ 작업 집중": [0, 0, 0, 0, 0, 0, 50, 0, 40, 80, 0],        // 연필 + 쿨링팬 + 키보드
        "🌙 깊은 수면": [0, 30, 90, 20, 0, 40, 0, 70, 0, 0, 0],       // 바람 + 밤 + 불 + 시냇물 + 우주
        "🐱 평화로운 오후": [60, 0, 30, 0, 20, 60, 0, 0, 0, 0, 0],    // 고양이 + 밤 + 비 + 시냇물
        "🌊 자연의 소리": [40, 50, 0, 0, 30, 80, 0, 0, 0, 0, 70]     // 고양이 + 바람 + 비 + 시냇물 + 파도
    ]
    
    // MARK: - AI 추천을 위한 카테고리 설명
    
    /// AI가 프리셋 추천할 때 사용할 카테고리 설명
    static let categoryDescriptions: [String] = [
        "고양이: 부드러운 야옹 소리 (편안함, 따뜻함)",
        "바람: 자연스러운 바람 소리 (시원함, 청량함)",
        "밤: 고요한 밤의 소리 (평온, 수면)",
        "불: 타닥거리는 불소리 (따뜻함, 포근함)",
        "비: 빗소리와 창문 빗소리 (평온, 집중)",
        "시냇물: 흐르는 물소리 (자연, 휴식)",
        "연필: 종이에 쓰는 소리 (집중, 창작)",
        "우주: 신비로운 우주 소리 (명상, 깊은 사색)",
        "쿨링팬: 부드러운 팬 소리 (집중, 화이트노이즈)",
        "키보드: 타이핑 소리 (작업, 집중)",
        "파도: 파도치는 소리 (휴식, 자연)"
    ]
    
    /// AI 추천용 간단한 매핑 (기존 12개 → 11개 카테고리 매핑)
    static let aiRecommendationMapping: [String: Int] = [
        "Rain": 4,        // 🌧️ 비
        "Thunder": 4,     // 🌧️ 비 (천둥은 비로 매핑)
        "Ocean": 10,      // 🌊 파도
        "Fire": 3,        // 🔥 불
        "Steam": 5,       // 🏞️ 시냇물 (증기는 물소리로 매핑)
        "WindowRain": 4,  // 🌧️ 비 (창문 빗소리)
        "Forest": 0,      // 🐱 고양이 (자연 소리 대체)
        "Wind": 1,        // 💨 바람
        "Night": 2,       // 🌙 밤
        "Lullaby": 7,     // 🌌 우주 (자장가는 우주 소리로)
        "Fan": 8,         // 🌀 쿨링팬
        "WhiteNoise": 9   // ⌨️ 키보드 (화이트노이즈 대체)
    ]
    
    // MARK: - 기존 호환성 유지
    
    /// 기존 ChatViewController와의 호환성을 위한 표준 사운드 이름
    static let legacyStandardSoundNames = [
        "Rain", "Thunder", "Ocean", "Fire", "Steam", "WindowRain",
        "Forest", "Wind", "Night", "Lullaby", "Fan", "WhiteNoise"
    ]
    
    /// 새로운 표준 사운드 이름 (11개)
    static let newStandardSoundNames = [
        "고양이", "바람", "밤", "불", "비", "시냇물",
        "연필", "우주", "쿨링팬", "키보드", "파도"
    ]
    
    // MARK: - Migration 지원
    
    /// 기존 12개 볼륨 배열을 11개로 변환
    static func convertLegacyVolumes(_ legacyVolumes: [Float]) -> [Float] {
        guard legacyVolumes.count == 12 else {
            // 11개면 그대로 반환
            if legacyVolumes.count == 11 {
                return legacyVolumes
            }
            // 다른 크기면 기본값으로
            return defaultPreset
        }
        
        // 12개 → 11개 매핑 로직
        // 기존: Rain, Thunder, Ocean, Fire, Steam, WindowRain, Forest, Wind, Night, Lullaby, Fan, WhiteNoise
        // 새로운: 고양이, 바람, 밤, 불, 비, 시냇물, 연필, 우주, 쿨링팬, 키보드, 파도
        
        var newVolumes: [Float] = Array(repeating: 0, count: 11)
        
        // 매핑 규칙
        newVolumes[0] = legacyVolumes[6]   // Forest → 고양이
        newVolumes[1] = legacyVolumes[7]   // Wind → 바람
        newVolumes[2] = legacyVolumes[8]   // Night → 밤
        newVolumes[3] = legacyVolumes[3]   // Fire → 불
        newVolumes[4] = max(legacyVolumes[0], legacyVolumes[1], legacyVolumes[5]) // Rain+Thunder+WindowRain → 비
        newVolumes[5] = legacyVolumes[4]   // Steam → 시냇물
        newVolumes[6] = 0                  // 연필 (새로운 사운드)
        newVolumes[7] = legacyVolumes[9]   // Lullaby → 우주
        newVolumes[8] = legacyVolumes[10]  // Fan → 쿨링팬
        newVolumes[9] = legacyVolumes[11]  // WhiteNoise → 키보드
        newVolumes[10] = legacyVolumes[2]  // Ocean → 파도
        
        return newVolumes
    }
    
    /// 11개 볼륨 배열을 기존 12개 형식으로 변환 (AI 호환성)
    static func convertToLegacyVolumes(_ newVolumes: [Float]) -> [Float] {
        guard newVolumes.count == 11 else {
            return Array(repeating: 0, count: 12)
        }
        
        var legacyVolumes: [Float] = Array(repeating: 0, count: 12)
        
        legacyVolumes[0] = newVolumes[4]   // 비 → Rain
        legacyVolumes[1] = newVolumes[4] * 0.3  // 비 → Thunder (약하게)
        legacyVolumes[2] = newVolumes[10]  // 파도 → Ocean
        legacyVolumes[3] = newVolumes[3]   // 불 → Fire
        legacyVolumes[4] = newVolumes[5]   // 시냇물 → Steam
        legacyVolumes[5] = newVolumes[4] * 0.8  // 비 → WindowRain
        legacyVolumes[6] = newVolumes[0]   // 고양이 → Forest
        legacyVolumes[7] = newVolumes[1]   // 바람 → Wind
        legacyVolumes[8] = newVolumes[2]   // 밤 → Night
        legacyVolumes[9] = newVolumes[7]   // 우주 → Lullaby
        legacyVolumes[10] = newVolumes[8]  // 쿨링팬 → Fan
        legacyVolumes[11] = newVolumes[9]  // 키보드 → WhiteNoise
        
        return legacyVolumes
    }
    
    // MARK: - 버전 정보 관리
    
    /// 기본 버전 선택 (각 카테고리의 첫 번째 버전)
    static var defaultVersionSelection: [Int] {
        return defaultVersions
    }
    
    /// 다중 버전이 있는 카테고리 인덱스들
    static let multiVersionCategories: [Int] = [4, 9]  // 비(2개), 키보드(2개)
    
    /// 특정 카테고리의 버전 선택지 이름들
    static func getVersionNames(for categoryIndex: Int) -> [String] {
        guard categoryIndex >= 0, categoryIndex < categoryFiles.count else { return [] }
        
        return categoryFiles[categoryIndex].map { fileName in
            fileName.replacingOccurrences(of: ".mp3", with: "")
        }
    }
    
    // MARK: - 검증 및 디버그
    
    #if DEBUG
    /// 데이터 일관성 검증
    static func validateDataConsistency() -> Bool {
        let counts = [
            categoryEmojis.count,
            categoryNames.count,
            displayLabels.count,
            categoryFiles.count,
            defaultVersions.count,
            categoryDescriptions.count
        ]
        
        let expectedCount = categoryCount
        let isConsistent = counts.allSatisfy { $0 == expectedCount }
        
        if !isConsistent {
            print("⚠️ SoundPresetCatalog 데이터 불일치 감지:")
            print("  - categoryEmojis: \(categoryEmojis.count)")
            print("  - categoryNames: \(categoryNames.count)")
            print("  - displayLabels: \(displayLabels.count)")
            print("  - categoryFiles: \(categoryFiles.count)")
            print("  - defaultVersions: \(defaultVersions.count)")
            print("  - categoryDescriptions: \(categoryDescriptions.count)")
            print("  - 예상 개수: \(expectedCount)")
        }
        
        return isConsistent
    }
    
    /// 샘플 데이터 출력
    static func printSampleData() {
        print("=== SoundPresetCatalog 정보 ===")
        print("총 카테고리 수: \(categoryCount)")
        
        for i in 0..<categoryCount {
            let info = getCategoryInfo(at: i)!
            print("\(i): \(info.emoji) \(info.name)")
            print("   파일: \(info.files)")
            print("   기본: \(info.files[info.defaultIndex])")
            if info.files.count > 1 {
                print("   다중버전: ✅")
            }
        }
        
        print("\n=== 샘플 프리셋 ===")
        for (name, volumes) in samplePresets {
            print("\(name): \(volumes)")
        }
    }
    #endif
}
