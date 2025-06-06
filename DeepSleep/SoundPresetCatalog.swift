import Foundation

struct SoundPresetCatalog {
    
    // MARK: - 13개 카테고리 정의 (기존 11개 + 새로 추가 2개)
    
    /// 카테고리별 이모지 (UI 표시용)
    static let categoryEmojis: [String] = [
        "🐱",  // 고양이
        "💨",  // 바람
        "🌙",  // 밤
        "🔥",  // 불1
        "🌧️", // 비
        "🏞️", // 시냇물
        "✏️",  // 연필
        "🌌",  // 우주
        "🌀",  // 쿨링팬
        "⌨️",  // 키보드
        "🌊",  // 파도
        "🐦",  // 새 (새로 추가)
        "❄️"   // 발걸음-눈 (새로 추가)
    ]
    
    /// 카테고리별 이름
    static let categoryNames: [String] = [
        "고양이",
        "바람",
        "밤",
        "불1",
        "비",
        "시냇물",
        "연필",
        "우주",
        "쿨링팬",
        "키보드",
        "파도",
        "새",
        "발걸음-눈"
    ]
    
    /// 이모지 + 이름 조합 (슬라이더 라벨용)
    static let displayLabels: [String] = [
        "🐱 고양이",
        "💨 바람",
        "🌙 밤",
        "🔥 불1",
        "🌧️ 비",
        "🏞️ 시냇물",
        "✏️ 연필",
        "🌌 우주",
        "🌀 쿨링팬",
        "⌨️ 키보드",
        "🌊 파도",
        "🐦 새",
        "❄️ 발걸음-눈"
    ]
    
    // MARK: - 카테고리별 파일 정보
    
    /// 각 카테고리의 사용 가능한 파일들
    static let categoryFiles: [[String]] = [
        ["고양이.mp3"],                        // 0: 🐱 고양이 (1개)
        ["바람.mp3", "바람2.mp3"],              // 1: 💨 바람 (2개 버전)
        ["밤.mp3", "밤2.mp3"],                  // 2: 🌙 밤 (2개 버전)
        ["불1.mp3"],                           // 3: 🔥 불1 (1개)
        ["비.mp3", "비-창문.mp3"],               // 4: 🌧️ 비 (2개 버전)
        ["시냇물.mp3"],                        // 5: 🏞️ 시냇물 (1개)
        ["연필.mp3"],                          // 6: ✏️ 연필 (1개)
        ["우주.mp3"],                          // 7: 🌌 우주 (1개)
        ["쿨링팬.mp3"],                        // 8: 🌀 쿨링팬 (1개)
        ["키보드1.mp3", "키보드2.mp3"],         // 9: ⌨️ 키보드 (2개 버전)
        ["파도.mp3", "파도2.mp3"],              // 10: 🌊 파도 (2개 버전)
        ["새.mp3", "새-비.mp3"],                // 11: 🐦 새 (2개 버전)
        ["발걸음-눈.mp3", "발걸음-눈2.mp3"]      // 12: ❄️ 발걸음-눈 (2개 버전)
    ]
    
    /// 각 카테고리의 기본 선택 파일 인덱스
    static let defaultVersions: [Int] = [
        0,  // 고양이: 고양이.mp3
        0,  // 바람: 바람.mp3 (기본), 바람2.mp3는 버전2
        0,  // 밤: 밤.mp3 (기본), 밤2.mp3는 버전2
        0,  // 불1: 불1.mp3
        0,  // 비: 비.mp3 (기본), 비-창문.mp3는 버전2
        0,  // 시냇물: 시냇물.mp3
        0,  // 연필: 연필.mp3
        0,  // 우주: 우주.mp3
        0,  // 쿨링팬: 쿨링팬.mp3
        0,  // 키보드: 키보드1.mp3 (기본), 키보드2.mp3는 버전2
        0,  // 파도: 파도.mp3 (기본), 파도2.mp3는 버전2
        0,  // 새: 새.mp3 (기본), 새-비.mp3는 버전2
        0   // 발걸음-눈: 발걸음-눈.mp3 (기본), 발걸음-눈2.mp3는 버전2
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
        "🌧️ 빗소리 집중": [0, 0, 0, 0, 80, 0, 0, 0, 0, 0, 30, 0, 0],      // 비 + 파도
        "🔥 따뜻한 밤": [0, 20, 60, 70, 0, 0, 0, 40, 0, 0, 0, 0, 0],        // 바람 + 밤 + 불1 + 우주
        "⌨️ 작업 집중": [0, 0, 0, 0, 0, 0, 50, 0, 40, 80, 0, 0, 0],        // 연필 + 쿨링팬 + 키보드
        "🌙 깊은 수면": [0, 30, 90, 20, 0, 40, 0, 70, 0, 0, 0, 0, 0],       // 바람 + 밤 + 불1 + 시냇물 + 우주
        "🐱 평화로운 오후": [60, 0, 30, 0, 20, 60, 0, 0, 0, 0, 0, 0, 0],    // 고양이 + 밤 + 비 + 시냇물
        "🌊 자연의 소리": [40, 50, 0, 0, 30, 80, 0, 0, 0, 0, 70, 40, 0]     // 고양이 + 바람 + 비 + 시냇물 + 파도 + 새
    ]
    
    // MARK: - AI 추천을 위한 카테고리 설명 (심리학적 효과 포함)
    
    /// AI가 프리셋 추천할 때 사용할 카테고리 설명 (심리학적 효과 포함)
    static let categoryDescriptions: [String] = [
        "고양이: 가까이서 골골대는 작은 소리. 옥시토신 분비 촉진으로 애착감과 편안함 제공",
        "바람: 자연스러운 바람 소리 (V1), 더 약하고 낮은 음의 바람 (V2). 자율신경계 안정화와 스트레스 호르몬 감소 효과",
        "밤: 한국의 여름밤 귀뚜라미 소리 (V1), 더 멀리서 벌레 우는 소리 (V2). 수면 호르몬 멜라토닌 분비 촉진",
        "불1: 불 타는 소리를 가까이서 녹음. 1/f 잡음으로 뇌파 알파파 증가와 깊은 이완",
        "비: 집 내부에서 창문 열고 듣는 강한 비소리 (V1)와 창문 톡톡 소리 (V2). 도파민 조절과 집중력 향상",
        "시냇물: 조용한 시냇물을 가까이서 찍은 물 흐르는 소리. 부교감신경 활성화로 스트레스 완화",
        "연필: 종이에 가볍게 영어 쓰는 슥슥 소리. ASMR 효과로 집중력과 창의성 증진",
        "우주: 높은 음의 의미심장한 사운드 (20초 이내 권장). 신경가소성 촉진과 깊은 명상 유도",
        "쿨링팬: 옛날 냉장고 팬 소리. 일정한 주파수로 인지 부하 감소와 배경 차음 효과",
        "키보드: 청축키보드 천천히 (V1), 옛날키보드 빠른 업무용 (V2). 작업 리듬감과 집중 상태 유지",
        "파도: 1.5미터 수심 잔잔한 파도 (V1), 해변가 파도 바스라지는 탄산 소리 (V2). 백색소음 효과로 신경 안정과 수면 유도",
        "새: 아침 새가 짹짹대는 소리 (V1), 약한 비오는 날 아침 멀리서 새들 소리 (V2). 세로토닌 분비로 기분 개선과 활력 증진",
        "발걸음-눈: 얕은 눈을 빠르게 걷는 소리 (V1), 깊은 눈을 천천히 걷는 소리 (V2). 리듬감 있는 자연음으로 주의력 향상과 깊은 이완"
    ]
    
    // MARK: - 감정별 최적 사운드 매칭 시스템
    
    /// 감정 상태별 권장 사운드 조합 (심리학 연구 기반)
    static let emotionBasedRecommendations: [String: [Int: Float]] = [
        "불안": [1: 40, 5: 70, 10: 50, 7: 30],           // 바람 + 시냇물 + 파도 + 우주
        "스트레스": [0: 50, 4: 80, 5: 60, 8: 40],        // 고양이 + 비 + 시냇물 + 쿨링팬
        "우울": [11: 70, 3: 50, 0: 60, 1: 40],           // 새 + 불1 + 고양이 + 바람
        "수면곤란": [2: 80, 1: 50, 10: 70, 5: 40],        // 밤 + 바람 + 파도 + 시냇물
        "집중필요": [6: 60, 9: 70, 8: 50, 1: 30],         // 연필 + 키보드 + 쿨링팬 + 바람
        "창의성": [6: 80, 11: 50, 5: 40, 7: 25],         // 연필 + 새 + 시냇물 + 우주
        "분노": [5: 90, 10: 80, 1: 60, 0: 40],           // 시냇물 + 파도 + 바람 + 고양이
        "외로움": [0: 80, 11: 60, 3: 50, 4: 40],         // 고양이 + 새 + 불1 + 비
        "피로": [2: 70, 5: 60, 10: 80, 0: 50],           // 밤 + 시냇물 + 파도 + 고양이
        "기쁨": [11: 80, 1: 50, 10: 70, 5: 60]           // 새 + 바람 + 파도 + 시냇물
    ]
    
    // MARK: - 시간대별 권장 사운드
    
    /// 시간대별 최적 사운드 (일주기 리듬 고려)
    static let timeBasedRecommendations: [String: [Int: Float]] = [
        "새벽": [2: 60, 1: 50, 5: 30, 12: 40],           // 밤 + 바람 + 시냇물 + 발걸음-눈
        "아침": [11: 80, 1: 40, 5: 50, 0: 30],           // 새 + 바람 + 시냇물 + 고양이
        "오전": [6: 70, 9: 60, 8: 40, 1: 30],            // 연필 + 키보드 + 쿨링팬 + 바람
        "점심": [0: 50, 4: 40, 5: 60, 1: 30],            // 고양이 + 비 + 시냇물 + 바람
        "오후": [6: 60, 8: 50, 9: 70, 10: 40],           // 연필 + 쿨링팬 + 키보드 + 파도
        "저녁": [3: 70, 0: 60, 5: 50, 10: 40],           // 불1 + 고양이 + 시냇물 + 파도
        "밤": [2: 80, 1: 40, 10: 70, 5: 50],             // 밤 + 바람 + 파도 + 시냇물
        "자정": [2: 90, 10: 80, 5: 60, 1: 50]            // 밤 + 파도 + 시냇물 + 바람
    ]
    
    // MARK: - AI 추천 다양성 시스템
    
    /// 추천 패턴의 다양성을 위한 변형 버전들
    static let variationPatterns: [String: [[Int: Float]]] = [
        "불안": [
            [1: 40, 5: 70, 10: 50, 7: 30],  // 기본 - 바람V1
            [0: 30, 5: 80, 10: 60, 1: 40],  // 고양이 추가 버전
            [1: 30, 5: 90, 10: 60, 7: 20]   // 시냇물 강화 버전
        ],
        "스트레스": [
            [0: 50, 4: 80, 5: 60, 8: 40],   // 기본 - 비V1
            [0: 70, 5: 80, 10: 50, 1: 30],  // 자연음 중심 - 파도V2
            [4: 60, 5: 70, 8: 50, 3: 40]    // 불 추가
        ],
        "수면곤란": [
            [2: 80, 1: 50, 10: 70, 5: 40],  // 기본 - 밤V1
            [2: 90, 10: 80, 5: 50, 0: 30],  // 밤V2 + 파도V2
            [2: 70, 5: 80, 10: 60, 1: 40]   // 시냇물 강화
        ],
        "집중필요": [
            [6: 60, 9: 70, 8: 50, 1: 30],   // 기본 - 키보드V1
            [6: 80, 8: 60, 1: 50, 4: 40],   // 키보드V2 + 비V1
            [9: 80, 8: 70, 6: 40, 5: 30]    // 키보드V2 강화
        ]
    ]
    
    /// 추천 패턴의 버전 다양성을 위한 변형 버전들
    static let variationVersions: [String: [[Int]]] = [
        "불안": [
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],  // 기본 V1들
            [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0],  // 바람V2 + 파도V2
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0]   // 새V2
        ],
        "스트레스": [
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],  // 기본 V1들
            [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0],  // 비V2 사용
            [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0]   // 바람V2 + 파도V2
        ],
        "수면곤란": [
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],  // 기본 V1들
            [0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0],  // 밤V2 + 파도V2
            [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]   // 바람V2 + 발걸음-눈V2
        ],
        "집중필요": [
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],  // 기본 V1들
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],  // 키보드V2
            [0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0]   // 비V2 + 키보드V2
        ]
    ]
    
    /// 상황별 세부 추천 (시간대 + 감정 조합)
    static let contextualRecommendations: [String: [Int: Float]] = [
        "아침_불안": [11: 60, 5: 70, 1: 30, 0: 40],      // 새 + 시냇물 + 바람 + 고양이
        "밤_스트레스": [2: 70, 0: 60, 5: 80, 10: 50],    // 밤 + 고양이 + 시냇물 + 파도
        "오후_집중": [6: 70, 8: 60, 9: 50, 1: 30],       // 연필 + 쿨링팬 + 키보드 + 바람
        "저녁_피로": [3: 80, 0: 70, 5: 60, 10: 50],      // 불1 + 고양이 + 시냇물 + 파도
        "새벽_수면": [2: 90, 1: 40, 5: 30, 12: 50]       // 밤 + 바람 + 시냇물 + 발걸음-눈
    ]
    
    /// 상황별 세부 추천의 버전 설정
    static let contextualVersions: [String: [Int]] = [
        "아침_불안": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0],   // 새V2
        "밤_스트레스": [0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0], // 바람V2 + 밤V2 + 파도V2
        "오후_집중": [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],   // 키보드V2
        "저녁_피로": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0],   // 파도V2
        "새벽_수면": [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]    // 바람V2 + 발걸음-눈V2
    ]
    
    // MARK: - 사운드 조합 필터링 시스템
    
    /// 어울리지 않는 사운드 조합들 (인덱스 쌍)
    private static let incompatiblePairs: [(Int, Int)] = [
        (6, 9),   // 연필 + 키보드 (둘 다 작업 소리여서 겹침)
        (3, 8),   // 불1 + 쿨링팬 (따뜻함 vs 차가움의 대조)
        (0, 9),   // 고양이 + 키보드 (자연 vs 인공의 극명한 대조)
        (7, 6),   // 우주 + 연필 (명상 vs 집중 작업의 충돌)
        (7, 9)    // 우주 + 키보드 (명상 vs 인공 소리의 충돌)
    ]
    
    /// 강력하게 어울리지 않는 조합 (완전히 차단)
    private static let stronglyIncompatiblePairs: [(Int, Int)] = [
        (0, 9),   // 고양이 + 키보드 (자연 vs 기계음의 극명한 대조)
        (3, 8)    // 불1 + 쿨링팬 (따뜻함 vs 시원함의 정반대)
    ]
    
    /// 시너지 효과가 있는 음원 조합들
    static let synergyPairs: [(Int, Int, Float)] = [
        (5, 10, 1.2),  // 시냇물 + 파도 (물 소리 시너지)
        (0, 3, 1.3),   // 고양이 + 불1 (편안함의 완벽한 조합)
        (6, 8, 1.2),   // 연필 + 쿨링팬 (집중 작업 환경)
        (4, 5, 1.15),  // 비 + 시냇물 (물 소리 조합)
        (1, 5, 1.1),   // 바람 + 시냇물 (자연 조합)
        (11, 12, 1.1)  // 새 + 발걸음-눈 (자연 환경음)
    ]
    
    /// 볼륨 배열에 조합 필터링 적용
    static func applyCompatibilityFilter(to volumes: [Float]) -> [Float] {
        var filteredVolumes = volumes
        
        // 강력한 비호환 조합 체크 (한 쪽을 0으로 만듦)
        for (index1, index2) in stronglyIncompatiblePairs {
            if filteredVolumes[index1] > 0 && filteredVolumes[index2] > 0 {
                // 더 작은 볼륨을 0으로 만듦
                if filteredVolumes[index1] < filteredVolumes[index2] {
                    filteredVolumes[index1] = 0
                } else {
                    filteredVolumes[index2] = 0
                }
            }
        }
        
        // 일반 비호환 조합 체크 (볼륨을 줄임)
        for (index1, index2) in incompatiblePairs {
            if filteredVolumes[index1] > 0 && filteredVolumes[index2] > 0 {
                filteredVolumes[index1] *= 0.7
                filteredVolumes[index2] *= 0.7
            }
        }
        
        // 시너지 효과 적용
        for (index1, index2, multiplier) in synergyPairs {
            if filteredVolumes[index1] > 0 && filteredVolumes[index2] > 0 {
                filteredVolumes[index1] = min(100, filteredVolumes[index1] * multiplier)
                filteredVolumes[index2] = min(100, filteredVolumes[index2] * multiplier)
            }
        }
        
        return filteredVolumes
    }
    
    // MARK: - 개선된 프리셋 추천 시스템
    
    /// 감정별 다양한 프리셋 패턴들 (더욱 세분화)
    static let emotionBasedPresets: [String: [(name: String, volumes: [Float], description: String, versions: [Int])]] = [
        "불안": [
            (
                name: "고요한 바람의 포옹",
                volumes: [30, 60, 20, 0, 0, 70, 0, 15, 0, 0, 40, 0, 0], // 고양이, 바람V2, 시냇물, 우주, 파도
                description: "부드러운 바람과 자연음이 마음을 안정시켜줍니다. 불안한 마음을 차분하게 달래주는 조합이에요.",
                versions: [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] // 바람V2
            ),
            (
                name: "새벽 고양이의 위로",
                volumes: [60, 40, 0, 0, 0, 50, 0, 10, 0, 0, 30, 20, 0], // 고양이, 바람V1, 시냇물, 새V1, 파도V1
                description: "고양이의 따뜻한 골골거림과 새벽 새소리가 불안을 달래줍니다.",
                versions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] // 모두 V1
            )
        ],
        "스트레스": [
            (
                name: "비내리는 창가의 평온",
                volumes: [40, 30, 0, 20, 70, 60, 0, 0, 30, 0, 0, 0, 0], // 고양이, 바람, 불1, 비V2, 시냇물, 쿨링팬
                description: "창문에 떨어지는 빗방울 소리와 따뜻한 불소리가 스트레스를 녹여줍니다.",
                versions: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0] // 비V2
            ),
            (
                name: "숲속 오후의 휴식",
                volumes: [50, 40, 0, 30, 0, 80, 0, 0, 0, 0, 50, 40, 20], // 고양이, 바람, 불1, 시냇물, 파도, 새, 발걸음-눈
                description: "깊은 숲에서 느끼는 완전한 이완감. 모든 스트레스가 자연 속으로 사라집니다.",
                versions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1] // 새V2, 발걸음-눈V2
            )
        ],
        "수면곤란": [
            (
                name: "자정의 깊은 고요",
                volumes: [20, 50, 80, 0, 30, 40, 0, 0, 0, 0, 60, 0, 30], // 고양이, 바람V2, 밤V2, 비V1, 시냇물, 파도V2, 발걸음-눈V2
                description: "밤의 고요함과 멀리서 들리는 자연음이 깊은 잠으로 이끌어줍니다.",
                versions: [0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1] // 바람V2, 밤V2, 파도V2, 발걸음-눈V2
            ),
            (
                name: "파도가 들려오는 밤",
                volumes: [30, 60, 70, 0, 0, 50, 0, 0, 0, 0, 80, 0, 0], // 고양이, 바람V2, 밤V1, 시냇물, 파도V2
                description: "해변의 파도소리와 밤 귀뚜라미가 만드는 완벽한 수면 환경입니다.",
                versions: [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0] // 바람V2, 파도V2
            )
        ],
        "집중필요": [
            (
                name: "서재의 집중 모드",
                volumes: [0, 20, 0, 0, 0, 30, 60, 0, 40, 70, 0, 0, 0], // 바람V2, 시냇물, 연필, 쿨링팬, 키보드V1
                description: "조용한 서재 분위기로 집중력을 극대화하는 사운드 조합입니다.",
                versions: [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] // 바람V2, 키보드V1
            ),
            (
                name: "현대적 작업 공간",
                volumes: [0, 30, 0, 0, 0, 0, 50, 0, 60, 80, 0, 0, 0], // 바람V1, 연필, 쿨링팬, 키보드V2
                description: "빠른 업무 처리를 위한 리듬감 있는 현대적 작업 환경음입니다.",
                versions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0] // 키보드V2
            )
        ],
        "우울": [
            (
                name: "따뜻한 아침의 시작",
                volumes: [60, 40, 0, 40, 0, 30, 0, 0, 0, 0, 0, 70, 50], // 고양이, 바람V1, 불1, 시냇물, 새V1, 발걸음-눈V1
                description: "밝은 새소리와 활기찬 자연음이 우울한 기분을 밝게 전화해줍니다.",
                versions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] // 모두 V1 (활기찬 버전)
            ),
            (
                name: "햇살 가득한 숲길",
                volumes: [50, 50, 0, 30, 0, 60, 20, 0, 0, 0, 40, 80, 60], // 고양이, 바람, 불1, 시냇물, 연필, 파도, 새V1, 발걸음-눈V1
                description: "숲길을 걸으며 듣는 생동감 넘치는 자연음들이 희망을 불어넣어줍니다.",
                versions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] // 모두 V1
            )
        ],
        "평온": [
            (
                name: "균형잡힌 하루",
                volumes: [40, 40, 30, 20, 20, 50, 20, 5, 20, 20, 30, 30, 20], // 모든 요소 균형있게
                description: "모든 사운드가 조화롭게 어우러진 완벽한 균형감을 제공합니다.",
                versions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] // 기본 버전들
            ),
            (
                name: "자연의 완전한 조화",
                volumes: [30, 50, 40, 25, 35, 60, 0, 8, 0, 0, 45, 40, 35], // 자연음 중심
                description: "순수한 자연음들만으로 구성된 완벽한 평온감을 선사합니다.",
                versions: [0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1] // 자연음은 V2로 (더 부드럽게)
            )
        ]
    ]

    /// 시간대별 추천 수정자
    static let timeBasedModifiers: [String: (volumeMultiplier: Float, preferredVersions: [Int])] = [
        "새벽": (volumeMultiplier: 0.7, preferredVersions: [0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1]), // 부드러운 버전들
        "아침": (volumeMultiplier: 1.0, preferredVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]), // 활기찬 V1들
        "오전": (volumeMultiplier: 0.9, preferredVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        "점심": (volumeMultiplier: 0.8, preferredVersions: [0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0]),
        "오후": (volumeMultiplier: 1.0, preferredVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0]), // 키보드V2로 집중력
        "저녁": (volumeMultiplier: 0.9, preferredVersions: [0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1]),
        "밤": (volumeMultiplier: 0.8, preferredVersions: [0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1]), // 부드러운 버전들
        "자정": (volumeMultiplier: 0.6, preferredVersions: [0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1])
    ]

    /// 개선된 추천 시스템
    static func getRecommendedPreset(
        emotion: String? = nil,
        timeOfDay: String? = nil,
        previousRecommendations: [String] = [],
        intensity: Float = 1.0
    ) -> (name: String, volumes: [Float], description: String, versions: [Int]) {
        
        let targetEmotion = emotion ?? "평온"
        let currentTime = timeOfDay ?? "오후"
        
        // 1. 해당 감정의 프리셋들 가져오기
        let availablePresets = emotionBasedPresets[targetEmotion] ?? emotionBasedPresets["평온"]!
        
        // 2. 이전에 추천하지 않은 것 중에서 선택 (다양성 보장)
        let unusedPresets = availablePresets.filter { preset in
            !previousRecommendations.contains(preset.name)
        }
        
        let selectedPresets = unusedPresets.isEmpty ? availablePresets : unusedPresets
        let basePreset = selectedPresets.randomElement()!
        
        // 3. 시간대에 따른 조정
        var adjustedVolumes = basePreset.volumes
        var adjustedVersions = basePreset.versions
        
        if let timeModifier = timeBasedModifiers[currentTime] {
            // 볼륨 조정
            adjustedVolumes = adjustedVolumes.map { $0 * timeModifier.volumeMultiplier * intensity }
            
            // 버전 조정 (시간대에 맞는 버전으로)
            for (index, preferredVersion) in timeModifier.preferredVersions.enumerated() {
                if index < adjustedVersions.count {
                    adjustedVersions[index] = preferredVersion
                }
            }
        }
        
        // 4. 최종 이름에 시간대 정보 추가
        let timePrefixes: [String: String] = [
            "새벽": "새벽의 ",
            "아침": "아침의 ",
            "밤": "밤의 ",
            "자정": "자정의 "
        ]
        
        let finalName = (timePrefixes[currentTime] ?? "") + basePreset.name
        
        return (
            name: finalName,
            volumes: adjustedVolumes,
            description: basePreset.description,
            versions: adjustedVersions
        )
    }
}
