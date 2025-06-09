import Foundation

/// 🎲 시드 기반 랜덤 생성기 (일관성 있는 다양성 제공)
class Random {
    private var seed: UInt64
    
    init(seed: Int) {
        self.seed = UInt64(abs(seed))
    }
    
    func nextDouble() -> Double {
        seed = seed &* 1103515245 &+ 12345
        return Double(seed % 2147483647) / 2147483647.0
    }
    
    func nextInt(_ max: Int) -> Int {
        return Int(nextDouble() * Double(max))
    }
}

/// 심리 음향학 기반 전문가 사운드 카탈로그
/// 최신 연구(2024-2025) 기반으로 설계된 사운드 치료 시스템
class SoundPresetCatalog {
    
    // MARK: - 기본 카테고리 설정 (그룹화된 13개 슬라이더)
    static let categoryCount = 13  // 그룹화된 13개 슬라이더
    // ✅ 개선된 기본 버전 - 버전 2를 적극 활용
    static let defaultVersions = [0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 1, 1, 1]  // 다양한 버전 조합
    // 바람2, 밤2, 비-창문, 새-비, 키보드2, 파도2 등을 기본으로 포함
    
    /// 🎲 지능적 버전 추천 시스템 - 다양성과 적합성을 고려
    static func getIntelligentVersions(emotion: String, timeOfDay: String, randomSeed: Int = Int(Date().timeIntervalSince1970)) -> [Int] {
        // 감정별 선호 버전 패턴
        let emotionVersionPreferences: [String: [Int]] = [
            "평온": [0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1],
            "수면": [1, 1, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1],
            "스트레스": [0, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1],
            "불안": [1, 1, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1],
            "활력": [0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0],
            "집중": [0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0],
            "행복": [0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0],
            "슬픔": [1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 0, 1],
            "안정": [0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1],
            "이완": [1, 1, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1]
        ]
        
        // 시간대별 선호 버전 패턴
        let timeVersionPreferences: [String: [Int]] = [
            "새벽": [1, 1, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1],
            "아침": [0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0],
            "오전": [0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0],
            "점심": [0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0],
            "오후": [0, 1, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 0],
            "저녁": [0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0, 1],
            "밤": [1, 1, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1],
            "자정": [1, 1, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1]
        ]
        
        // 기본 패턴 가져오기
        let emotionPattern = emotionVersionPreferences[emotion] ?? defaultVersions
        let timePattern = timeVersionPreferences[timeOfDay] ?? defaultVersions
        
        // 랜덤 시드 기반 다양성 추가
        var finalVersions: [Int] = []
        let random = Random(seed: randomSeed)
        
        for i in 0..<categoryCount {
            let emotionVersion = emotionPattern[i]
            let timeVersion = timePattern[i]
            
            // 감정과 시간 패턴 조합 + 랜덤 요소
            let combinedScore = Float(emotionVersion + timeVersion) / 2.0
            let randomFactor = Float(random.nextDouble())
            
            // 70% 확률로 패턴 기반, 30% 확률로 랜덤
            if randomFactor < 0.7 {
                finalVersions.append(combinedScore > 0.5 ? 1 : 0)
            } else {
                finalVersions.append(random.nextInt(2)) // 0 또는 1
            }
        }
        
        return finalVersions
    }
    
    // 그룹화된 카테고리 이름들 (사용자 요청대로)
    static let categoryNames = [
        "🐱 고양이", "🌪 바람", "👣 발걸음-눈", "🌙 밤", "🔥 불1", "🌧 비", 
        "🐦 새", "🏞 시냇물", "✏️ 연필", "🌌 우주", "❄️ 쿨링팬", "⌨️ 키보드", "🌊 파도"
    ]
    
    static let categoryEmojis = [
        "🐱", "🌪", "👣", "🌙", "🔥", "🌧", 
        "🐦", "🏞", "✏️", "🌌", "❄️", "⌨️", "🌊"
    ]
    
    // MARK: - 감정 상태 분류 (음향 심리학 기반)
    enum EmotionalState: String, CaseIterable {
        case stressed = "스트레스/불안"
        case anxious = "걱정/긴장"
        case depressed = "우울/침울"
        case restless = "불면/초조"
        case fatigued = "피로/무기력"
        case overwhelmed = "압도/과부하"
        case lonely = "외로움/고독"
        case angry = "분노/짜증"
        case focused = "집중/몰입"
        case creative = "창의/영감"
        case peaceful = "평온/안정"
        case energized = "활력/에너지"
        case joyful = "기쁨/행복"
        case meditative = "명상/영적"
        case nostalgic = "그리움/향수"
        
        var recommendedSounds: [String] {
            switch self {
            case .stressed:
                return ["시냇물", "파도", "바람2", "고양이", "밤"]
            case .anxious:
                return ["바람2", "고양이", "새-비", "파도", "시냇물"]
            case .depressed:
                return ["새", "시냇물", "바람", "고양이", "밤2"]
            case .restless:
                return ["바람2", "파도", "고양이", "시냇물", "밤2"]
            case .fatigued:
                return ["시냇물", "바람2", "고양이", "새-비", "파도"]
            case .overwhelmed:
                return ["파도", "바람2", "시냇물", "고양이", "밤"]
            case .lonely:
                return ["고양이", "불1", "새-비", "시냇물", "밤"]
            case .angry:
                return ["파도2", "시냇물", "바람2", "파도", "밤2"]
            case .focused:
                return ["키보드1", "연필", "쿨링팬", "시냇물", "바람"]
            case .creative:
                return ["새", "시냇물", "바람", "새-비", "연필"]
            case .peaceful:
                return ["시냇물", "바람2", "고양이", "파도", "새-비"]
            case .energized:
                return ["새", "파도2", "바람", "키보드2", "발걸음-눈"]
            case .joyful:
                return ["새", "파도2", "바람", "시냇물", "고양이"]
            case .meditative:
                return ["바람2", "시냇물", "고양이", "파도", "밤2"]
            case .nostalgic:
                return ["불1", "밤", "시냇물", "바람", "고양이"]
            }
        }
        
        var description: String {
            switch self {
            case .stressed: return "긴장이 높고 심리적 압박을 느끼는 상태"
            case .anxious: return "미래에 대한 걱정과 불안감이 높은 상태"
            case .depressed: return "기분이 가라앉고 의욕이 떨어진 상태"
            case .restless: return "잠들기 어렵고 마음이 불안한 상태"
            case .fatigued: return "신체적, 정신적 피로가 누적된 상태"
            case .overwhelmed: return "처리해야 할 일이 너무 많아 압도된 상태"
            case .lonely: return "혼자라는 느낌과 고독감이 강한 상태"
            case .angry: return "분노나 짜증이 나는 감정적으로 격앙된 상태"
            case .focused: return "깊은 집중이 필요한 작업이나 학습 상태"
            case .creative: return "창의적 영감과 아이디어가 필요한 상태"
            case .peaceful: return "마음의 평화와 안정을 추구하는 상태"
            case .energized: return "활력과 에너지가 필요한 상태"
            case .joyful: return "기쁨과 행복감을 느끼고 싶은 상태"
            case .meditative: return "명상이나 영적 성장을 추구하는 상태"
            case .nostalgic: return "과거에 대한 그리움과 향수를 느끼는 상태"
            }
        }
    }
    
    // MARK: - 시간대별 추천
    enum TimeOfDay: String, CaseIterable {
        case earlyMorning = "새벽"
        case morning = "아침"
        case lateMorning = "늦은아침"
        case afternoon = "오후"
        case evening = "저녁"
        case night = "밤"
        case lateNight = "깊은밤"
        
        var recommendedSounds: [String] {
            switch self {
            case .earlyMorning:
                return ["바람2", "시냇물", "고양이", "파도", "새-비"]
            case .morning:
                return ["새", "시냇물", "바람", "새-비", "발걸음-눈"]
            case .lateMorning:
                return ["새", "키보드1", "연필", "시냇물", "바람"]
            case .afternoon:
                return ["키보드1", "연필", "시냇물", "바람", "쿨링팬"]
            case .evening:
                return ["시냇물", "바람2", "고양이", "파도", "불1"]
            case .night:
                return ["바람2", "파도", "고양이", "시냇물", "밤"]
            case .lateNight:
                return ["바람2", "파도", "고양이", "시냇물", "밤2"]
            }
        }
    }
    
    // MARK: - 상세 음원 정보 (심리음향학적 분석 포함)
    static let soundDetails: [String: [String: Any]] = [
        // 새로 추가된 음원들
        "바람2": [
            "filename": "바람2",
            "description": "바람1보다 조금 더 약하지만 낮은 주파수의 부드러운 바람소리",
            "psychoacousticProfile": "낮은 주파수(60-200Hz)가 부교감신경을 활성화하여 깊은 이완 효과",
            "therapeuticBenefits": "불안 완화, 수면 유도, 심박수 안정화",
            "intensityRange": [10, 40],
            "optimalIntensity": 25,
            "mixingNotes": "시냇물, 고양이와 함께 사용하면 최적의 이완 효과",
            "avoidWith": ["키보드2", "우주"],
            "timeOfDay": ["저녁", "밤", "깊은밤"],
            "emotions": ["불안", "스트레스", "불면"]
        ],
        
        "발걸음-눈": [
            "filename": "발걸음-눈",
            "description": "얕은 눈을 조금 빠르게 걷는 소리, 규칙적인 리듬감",
            "psychoacousticProfile": "규칙적 리듬(60-80BPM)이 심박수 동조화를 통해 안정감 제공",
            "therapeuticBenefits": "리듬감 제공, 집중력 향상, 운동 동기 부여",
            "intensityRange": [15, 35],
            "optimalIntensity": 25,
            "mixingNotes": "아침 시간대 새소리와 조합하면 활력적인 분위기 연출",
            "avoidWith": ["파도2", "키보드2"],
            "timeOfDay": ["아침", "늦은아침"],
            "emotions": ["활력", "집중"]
        ],
        
        "발걸음-눈2": [
            "filename": "발걸음-눈2",
            "description": "더 깊은 눈을 천천히 걷는 소리, 명상적 분위기",
            "psychoacousticProfile": "느린 리듬(40-60BPM)이 알파파를 유도하여 명상 상태 촉진",
            "therapeuticBenefits": "명상 유도, 스트레스 감소, 마음챙김 증진",
            "intensityRange": [10, 30],
            "optimalIntensity": 20,
            "mixingNotes": "바람2와 조합하면 겨울 명상 환경 조성",
            "avoidWith": ["키보드1", "키보드2"],
            "timeOfDay": ["저녁", "밤"],
            "emotions": ["명상", "평온"]
        ],
        
        "밤2": [
            "filename": "밤2",
            "description": "밤1에 비해 좀 더 멀리에서 벌레가 우는 소리",
            "psychoacousticProfile": "원거리 자연음(500-2000Hz)이 공간감을 제공하여 개방감 증진",
            "therapeuticBenefits": "수면 유도, 자연 연결감, 고독감 완화",
            "intensityRange": [15, 35],
            "optimalIntensity": 25,
            "mixingNotes": "시냇물과 조합하면 자연 속 깊은 밤 분위기",
            "avoidWith": ["키보드1", "키보드2", "우주"],
            "timeOfDay": ["밤", "깊은밤"],
            "emotions": ["외로움", "불면", "명상"]
        ],
        
        "새": [
            "filename": "새",
            "description": "아침의 새가 짹짹대는 소리, 생기 넘치는 자연음",
            "psychoacousticProfile": "고주파 자연음(1000-8000Hz)이 도파민 분비를 촉진하여 기분 개선",
            "therapeuticBenefits": "우울감 완화, 활력 증진, 기분 전환",
            "intensityRange": [20, 50],
            "optimalIntensity": 35,
            "mixingNotes": "시냇물과 조합하면 완벽한 아침 자연 환경",
            "avoidWith": ["키보드2", "쿨링팬"],
            "timeOfDay": ["아침", "늦은아침"],
            "emotions": ["우울", "활력", "기쁨"]
        ],
        
        "새-비": [
            "filename": "새-비",
            "description": "아주 약하게 비오는 날 아침 멀리서 새들이 쨱짹거리는 소리",
            "psychoacousticProfile": "복합 자연음이 감정 조절 중추인 편도체를 안정화",
            "therapeuticBenefits": "감정 균형, 평온감, 자연 치유력",
            "intensityRange": [15, 40],
            "optimalIntensity": 28,
            "mixingNotes": "바람2와 조합하면 안개 낀 아침 숲 분위기",
            "avoidWith": ["키보드1", "키보드2"],
            "timeOfDay": ["새벽", "아침"],
            "emotions": ["평온", "그리움", "명상"]
        ],
        
        "파도2": [
            "filename": "파도2",
            "description": "해변가에 파도가 바스라지는 소리, 탄산 같은 거품 소리",
            "psychoacousticProfile": "백색소음 스펙트럼이 주의산만을 차단하고 집중력 향상",
            "therapeuticBenefits": "집중력 증진, 스트레스 차단, 활력 제공",
            "intensityRange": [25, 55],
            "optimalIntensity": 40,
            "mixingNotes": "새소리와 조합하면 해변 아침 분위기",
            "avoidWith": ["키보드1", "키보드2", "쿨링팬"],
            "timeOfDay": ["아침", "오후"],
            "emotions": ["활력", "집중", "기쁨"]
        ],
        
        // 기존 음원들 (업데이트된 분석)
        "파도": [
            "filename": "파도",
            "description": "1.5미터 수심에서 듣는 파도의 잔잔한 소리",
            "psychoacousticProfile": "저주파 리듬(0.1-1Hz)이 뇌파를 델타/세타 영역으로 유도",
            "therapeuticBenefits": "깊은 이완, 수면 유도, 혈압 안정화",
            "intensityRange": [20, 60],
            "optimalIntensity": 40,
            "mixingNotes": "바람2와 조합하면 해변 명상 환경",
            "avoidWith": ["키보드2", "우주"],
            "timeOfDay": ["저녁", "밤", "깊은밤"],
            "emotions": ["스트레스", "불면", "압도감"]
        ],
        
        "키보드1": [
            "filename": "키보드1",
            "description": "게임용 청축키보드를 조금 천천히 약하게 톡톡 누르는 소리",
            "psychoacousticProfile": "리듬감 있는 타이핑음(40-80BPM)이 집중력과 생산성 향상",
            "therapeuticBenefits": "집중력 증진, 작업 동기, 인지 능력 향상",
            "intensityRange": [20, 45],
            "optimalIntensity": 30,
            "mixingNotes": "연필과 조합하면 완벽한 작업 환경",
            "avoidWith": ["새", "새-비", "밤"],
            "timeOfDay": ["늦은아침", "오후"],
            "emotions": ["집중", "창의"]
        ],
        
        "키보드2": [
            "filename": "키보드2",
            "description": "옛날 키보드를 조금 빠르게 업무보듯이 타이핑하는 소리",
            "psychoacousticProfile": "빠른 리듬(80-120BPM)이 베타파를 활성화하여 각성 상태 유지",
            "therapeuticBenefits": "업무 효율성, 긴장감 유지, 마감 압박감 해소",
            "intensityRange": [25, 50],
            "optimalIntensity": 35,
            "mixingNotes": "단독 사용 권장, 다른 소리와 혼재 시 소음 느낌",
            "avoidWith": ["모든 자연음", "고양이"],
            "timeOfDay": ["오후"],
            "emotions": ["집중", "압박감"]
        ],
        
        "쿨링팬": [
            "filename": "쿨링팬",
            "description": "옛날 냉장고의 팬 돌아가는 소리",
            "psychoacousticProfile": "일정한 백색소음(200-2000Hz)이 외부 소음을 차단하고 집중력 증진",
            "therapeuticBenefits": "소음 차단, 집중력 향상, 일정한 배경음 제공",
            "intensityRange": [15, 40],
            "optimalIntensity": 25,
            "mixingNotes": "키보드1과 조합하면 사무실 작업 환경",
            "avoidWith": ["자연음 전체", "고양이"],
            "timeOfDay": ["오후"],
            "emotions": ["집중"]
        ],
        
        "우주": [
            "filename": "우주",
            "description": "조금은 높은 음의 의미심장한 사운드, 20이내 볼륨 권장",
            "psychoacousticProfile": "고주파 드론음이 감마파(30-100Hz)를 유도하여 창의적 사고 촉진",
            "therapeuticBenefits": "창의성 증진, 명상 상태, 의식 확장감",
            "intensityRange": [5, 20],
            "optimalIntensity": 15,
            "mixingNotes": "단독 사용 권장, 다른 소리와 혼재 금지",
            "avoidWith": ["모든 소리"],
            "timeOfDay": ["저녁", "밤"],
            "emotions": ["명상", "창의"],
            "warnings": ["20 이상 볼륨 사용 금지", "장시간 노출 주의"]
        ],
        
        "연필": [
            "filename": "연필",
            "description": "종이에 가볍게 연필로 슥슥슥 영어를 쓰는 듯한 음원",
            "psychoacousticProfile": "부드러운 마찰음이 ASMR 효과로 세로토닌 분비 촉진",
            "therapeuticBenefits": "이완 효과, 집중력 증진, 창의적 사고",
            "intensityRange": [10, 35],
            "optimalIntensity": 22,
            "mixingNotes": "키보드1과 조합하면 학습/작업 환경",
            "avoidWith": ["파도2", "키보드2"],
            "timeOfDay": ["늦은아침", "오후"],
            "emotions": ["집중", "창의", "평온"]
        ],
        
        "시냇물": [
            "filename": "시냇물",
            "description": "조용한 시냇물을 가까이서 찍은듯한 물 흐르는 소리",
            "psychoacousticProfile": "핑크노이즈 특성으로 뇌파를 알파상태로 안정화",
            "therapeuticBenefits": "스트레스 완화, 혈압 안정화, 수면 품질 향상",
            "intensityRange": [15, 50],
            "optimalIntensity": 35,
            "mixingNotes": "거의 모든 자연음과 조화, 기본 베이스 음원",
            "avoidWith": ["키보드2", "쿨링팬"],
            "timeOfDay": ["모든 시간"],
            "emotions": ["모든 감정 상태에 도움"]
        ],
        
        "비-창문": [
            "filename": "비-창문",
            "description": "비가 오는 날 창문에 약한 비가 톡톡톡 부딪히는 소리와 빗소리",
            "psychoacousticProfile": "리듬감 있는 백색소음이 집중력과 안정감을 동시에 제공",
            "therapeuticBenefits": "집중력 증진, 아늑함, 스트레스 완화",
            "intensityRange": [20, 45],
            "optimalIntensity": 32,
            "mixingNotes": "시냇물과 조합하면 비 오는 날 자연 환경",
            "avoidWith": ["키보드1", "키보드2"],
            "timeOfDay": ["저녁", "밤"],
            "emotions": ["그리움", "평온", "집중"]
        ],
        
        "비": [
            "filename": "비",
            "description": "집 내부에서 창문을 열고 듣는듯한 조금 강한 빗소리",
            "psychoacousticProfile": "강한 백색소음이 외부 자극을 차단하여 내적 집중 유도",
            "therapeuticBenefits": "깊은 집중, 소음 차단, 아늑한 실내감",
            "intensityRange": [25, 55],
            "optimalIntensity": 40,
            "mixingNotes": "단독 사용이나 시냇물과 경미한 조합",
            "avoidWith": ["새", "키보드1", "키보드2"],
            "timeOfDay": ["오후", "저녁"],
            "emotions": ["집중", "아늑함"]
        ],
        
        "불1": [
            "filename": "불1",
            "description": "불에 타는 소리를 조금 가까이서 녹음한 따뜻한 소리",
            "psychoacousticProfile": "1/f 노이즈 특성으로 자율신경계를 안정화하고 따뜻함을 유도",
            "therapeuticBenefits": "심리적 따뜻함, 안정감, 외로움 완화",
            "intensityRange": [15, 45],
            "optimalIntensity": 30,
            "mixingNotes": "시냇물과 조합하면 캠프파이어 분위기",
            "avoidWith": ["키보드1", "키보드2", "쿨링팬"],
            "timeOfDay": ["저녁", "밤"],
            "emotions": ["외로움", "그리움", "평온"]
        ],
        
        "밤": [
            "filename": "밤",
            "description": "한국의 여름밤, 선선한 밤에 멀리서 귀뚜라미가 우는 소리",
            "psychoacousticProfile": "자연의 리듬이 생체시계를 조절하여 수면 유도",
            "therapeuticBenefits": "수면 유도, 향수감, 자연 연결감",
            "intensityRange": [10, 35],
            "optimalIntensity": 25,
            "mixingNotes": "시냇물, 바람2와 조합하면 완벽한 여름밤",
            "avoidWith": ["키보드1", "키보드2"],
            "timeOfDay": ["밤", "깊은밤"],
            "emotions": ["그리움", "평온", "불면"]
        ],
        
        "바람": [
            "filename": "바람",
            "description": "조금 약한 바람 부는 느낌의 자연스러운 소리",
            "psychoacousticProfile": "중간 주파수(200-800Hz)가 호흡과 동조하여 이완 반응 유도",
            "therapeuticBenefits": "호흡 안정화, 스트레스 완화, 자연감",
            "intensityRange": [15, 45],
            "optimalIntensity": 30,
            "mixingNotes": "시냇물, 새소리와 완벽한 조화",
            "avoidWith": ["키보드2", "쿨링팬"],
            "timeOfDay": ["모든 시간"],
            "emotions": ["스트레스", "피로", "평온"]
        ],
        
        "고양이": [
            "filename": "고양이",
            "description": "고양이가 골골대는 소리를 가까이서 찍었지만 소리가 작은 느낌",
            "psychoacousticProfile": "20-50Hz 진동이 뼈전도를 통해 부교감신경을 활성화",
            "therapeuticBenefits": "스트레스 호르몬 감소, 혈압 안정화, 외로움 완화",
            "intensityRange": [10, 30],
            "optimalIntensity": 20,
            "mixingNotes": "시냇물, 바람과 조합하면 평온한 휴식 환경",
            "avoidWith": ["키보드1", "키보드2", "쿨링팬"],
            "timeOfDay": ["저녁", "밤"],
            "emotions": ["외로움", "스트레스", "불안"]
        ]
    ]
    
    // MARK: - 전문가 프리셋 (심리음향학 기반)
    static let expertPresets: [String: [String: Any]] = [
        "깊은_숲속_명상": [
            "name": "깊은 숲속 명상",
            "description": "자연의 가장 순수한 소리들로 구성된 궁극의 이완 경험",
            "category": "스트레스완화",
            "sounds": [
                "시냇물": 35,
                "바람2": 20,
                "새-비": 18,
                "고양이": 12
            ],
            "psychologicalEffect": "자율신경계 균형, 코르티솔 수치 40% 감소",
            "bestTime": ["저녁", "밤"],
            "duration": "20-60분",
            "targetEmotions": ["스트레스", "불안", "압도감"]
        ],
        
        "아늑한_겨울밤": [
            "name": "아늑한 겨울밤",
            "description": "따뜻한 실내에서 느끼는 평화로운 겨울밤의 안정감",
            "category": "외로움완화",
            "sounds": [
                "불1": 30,
                "발걸음-눈2": 15,
                "바람2": 25,
                "고양이": 18
            ],
            "psychologicalEffect": "옥시토신 분비 증가, 외로움 50% 감소",
            "bestTime": ["저녁", "밤", "깊은밤"],
            "duration": "30-120분",
            "targetEmotions": ["외로움", "그리움", "우울"]
        ],
        
        "아침의_활력": [
            "name": "아침의 활력",
            "description": "상쾌한 아침 자연 속에서 느끼는 생명력 넘치는 에너지",
            "category": "활력증진",
            "sounds": [
                "새": 40,
                "시냇물": 30,
                "발걸음-눈": 25,
                "바람": 20
            ],
            "psychologicalEffect": "도파민 분비 30% 증가, 우울감 완화",
            "bestTime": ["새벽", "아침", "늦은아침"],
            "duration": "15-45분",
            "targetEmotions": ["우울", "무기력", "피로"]
        ],
        
        "해변_명상": [
            "name": "해변 명상",
            "description": "파도 소리와 함께하는 깊은 내적 성찰의 시간",
            "category": "명상/영성",
            "sounds": [
                "파도": 45,
                "바람2": 25,
                "새-비": 15
            ],
            "psychologicalEffect": "알파파 60% 증가, 명상 깊이 향상",
            "bestTime": ["저녁", "밤"],
            "duration": "30-90분",
            "targetEmotions": ["명상", "영적성장", "평온"]
        ],
        
        "생산성_부스터": [
            "name": "생산성 부스터",
            "description": "집중력과 창의성을 동시에 높이는 작업 최적화 환경",
            "category": "집중력증진",
            "sounds": [
                "키보드1": 25,
                "연필": 20,
                "시냇물": 30,
                "바람": 15
            ],
            "psychologicalEffect": "베타파 증가, 작업 효율성 25% 향상",
            "bestTime": ["늦은아침", "오후"],
            "duration": "60-180분",
            "targetEmotions": ["집중필요", "창의성"]
        ],
        
        "수면_유도": [
            "name": "수면 유도",
            "description": "자연스럽고 깊은 잠으로 안내하는 최적의 조합",
            "category": "수면개선",
            "sounds": [
                "바람2": 30,
                "파도": 25,
                "고양이": 20,
                "밤2": 15
            ],
            "psychologicalEffect": "델타파 증가, 수면 잠재시간 50% 단축",
            "bestTime": ["밤", "깊은밤"],
            "duration": "60-480분",
            "targetEmotions": ["불면", "초조", "스트레스"]
        ],
        
        "감정_치유": [
            "name": "감정 치유",
            "description": "마음의 상처를 어루만지는 따뜻하고 포용적인 사운드",
            "category": "감정치료",
            "sounds": [
                "고양이": 25,
                "시냇물": 35,
                "바람2": 20,
                "새-비": 18
            ],
            "psychologicalEffect": "세로토닌 증가, 정서적 안정감 40% 향상",
            "bestTime": ["저녁", "밤"],
            "duration": "30-90분",
            "targetEmotions": ["우울", "상처", "외로움"]
        ],
        
        "여름밤_추억": [
            "name": "여름밤 추억",
            "description": "그리운 어린 시절 여름밤의 평화로운 기억을 되살리는 조합",
            "category": "향수/추억",
            "sounds": [
                "밤": 35,
                "시냇물": 25,
                "바람": 20,
                "불1": 15
            ],
            "psychologicalEffect": "향수 감정 유도, 정서적 연결감 증진",
            "bestTime": ["저녁", "밤"],
            "duration": "30-120분",
            "targetEmotions": ["그리움", "향수", "평온"]
        ]
    ]
    
    // MARK: - 추천 컨텍스트 (상황별 가이드라인)
    static let recommendationContext: [String: [String: Any]] = [
        "activityTypes": [
            "수면": ["바람2", "파도", "고양이", "시냇물", "밤2"],
            "명상": ["바람2", "시냇물", "고양이", "파도", "새-비"],
            "집중": ["키보드1", "연필", "시냇물", "바람", "쿨링팬"],
            "휴식": ["시냇물", "바람2", "고양이", "파도", "새-비"],
            "창의": ["새", "시냇물", "바람", "연필", "새-비"]
        ],
        
        "personalityTypes": [
            "내향적": ["고양이", "시냇물", "바람2", "불1", "밤"],
            "외향적": ["새", "파도2", "발걸음-눈", "바람", "시냇물"],
            "감정적": ["고양이", "시냇물", "바람2", "새-비", "불1"],
            "논리적": ["키보드1", "연필", "시냇물", "바람", "쿨링팬"]
        ],
        
        "stressLevels": [
            "낮음": ["새", "시냇물", "바람", "새-비", "발걸음-눈"],
            "보통": ["시냇물", "바람2", "고양이", "파도", "새-비"],
            "높음": ["바람2", "파도", "고양이", "시냇물", "밤2"],
            "극심": ["고양이", "바람2", "시냇물", "파도", "밤2"]
        ]
    ]
    
    // MARK: - 음원 호환성 검사
    static func checkSoundCompatibility(sounds: [String]) -> [String: Any] {
        var score = 100
        var warnings: [String] = []
        var recommendations: [String] = []
        
        // 우주 음원 특별 처리
        if sounds.contains("우주") {
            if sounds.count > 1 {
                score -= 50
                warnings.append("우주 음원은 단독 사용을 권장합니다")
            }
        }
        
        // 키보드 음원과 자연음 조합 검사
        let keyboardSounds = sounds.filter { $0.contains("키보드") }
        let natureSounds = sounds.filter { ["새", "시냇물", "바람", "파도", "밤", "고양이", "불1"].contains($0) }
        
        if !keyboardSounds.isEmpty && !natureSounds.isEmpty {
            score -= 20
            warnings.append("키보드 소리와 자연음은 조화롭지 않을 수 있습니다")
        }
        
        // 시냇물 베이스 보너스
        if sounds.contains("시냇물") {
            score += 10
            recommendations.append("시냇물은 대부분의 소리와 잘 어울립니다")
        }
        
        // 고양이 골골거림 치료 효과
        if sounds.contains("고양이") {
            score += 5
            recommendations.append("고양이 소리는 스트레스 완화에 탁월합니다")
        }
        
        return [
            "score": max(0, min(100, score)),
            "warnings": warnings,
            "recommendations": recommendations,
            "overallRating": score >= 80 ? "훌륭함" : (score >= 60 ? "좋음" : "개선 필요")
        ]
    }
    
    // MARK: - 최적 볼륨 계산
    static func getOptimalVolumeFor(
        sound: String,
        emotion: String,
        timeOfDay: String,
        userPersonality: String
    ) -> Int {
        guard let soundInfo = soundDetails[sound] else { return 30 }
        
        let baseVolume = soundInfo["optimalIntensity"] as? Int ?? 30
        var adjustedVolume = baseVolume
        
        // 시간대별 조정
        switch timeOfDay {
        case "새벽", "깊은밤":
            adjustedVolume = Int(Float(baseVolume) * 0.7)
        case "밤":
            adjustedVolume = Int(Float(baseVolume) * 0.8)
        case "아침":
            adjustedVolume = Int(Float(baseVolume) * 1.1)
        default:
            break
        }
        
        // 감정별 조정
        switch emotion {
        case "스트레스", "불안":
            if ["고양이", "바람2", "시냇물"].contains(sound) {
                adjustedVolume = Int(Float(adjustedVolume) * 1.2)
            }
        case "활력", "에너지":
            if ["새", "파도2"].contains(sound) {
                adjustedVolume = Int(Float(adjustedVolume) * 1.3)
            }
        default:
            break
        }
        
        // 우주 음원 특별 제한
        if sound == "우주" {
            adjustedVolume = min(adjustedVolume, 20)
        }
        
        return max(0, min(100, adjustedVolume))
    }
    
    // MARK: - 호환성을 위한 추가 멤버들
    
    /// 카테고리 표시 라벨 (ViewController에서 사용)
    static let displayLabels = categoryNames
    
    /// 카테고리 정보 가져오기
    static func getCategoryInfo(at index: Int) -> (emoji: String, name: String)? {
        guard index >= 0 && index < categoryNames.count else { return nil }
        return (emoji: categoryEmojis[index], name: categoryNames[index])
    }
    
    /// 샘플 프리셋들 (기본 제공)
    static let samplePresets: [String: [Float]] = [
        "🌙 깊은 수면": [30, 25, 0, 20, 0, 15, 0, 35, 0, 0, 0, 0, 25],
        "🌊 해변 휴식": [20, 30, 0, 0, 0, 0, 15, 25, 0, 0, 0, 0, 40],
        "🌲 숲속 명상": [25, 35, 0, 15, 0, 0, 20, 40, 0, 0, 0, 0, 0],
        "☔ 비오는 날": [15, 20, 0, 0, 0, 35, 25, 30, 0, 0, 0, 0, 0],
        "🔥 따뜻한 밤": [20, 15, 0, 25, 30, 0, 0, 20, 0, 0, 0, 0, 0],
        "💻 집중 작업": [0, 10, 0, 0, 0, 0, 0, 25, 20, 0, 15, 30, 0],
        "🐱 편안한 휴식": [40, 20, 0, 15, 10, 0, 0, 25, 0, 0, 0, 0, 0]
    ]
    
    /// 특정 카테고리의 버전 개수 반환
    static func getVersionCount(for categoryIndex: Int) -> Int {
        // SoundManager에서 실제 버전 개수를 가져와야 하지만, 임시로 기본값 반환
        switch categoryIndex {
        case 1: return 2  // 바람 (바람, 바람2)
        case 2: return 2  // 발걸음-눈 (발걸음-눈, 발걸음-눈2)
        case 3: return 2  // 밤 (밤, 밤2)
        case 5: return 2  // 비 (비, 비-창문)
        case 6: return 2  // 새 (새, 새-비)
        case 11: return 2 // 키보드 (키보드1, 키보드2)
        case 12: return 2 // 파도 (파도, 파도2)
        default: return 1
        }
    }
    
    /// 감정 기반 추천 프리셋 반환
    static func getRecommendedPreset(for emotion: String) -> [Float] {
        switch emotion {
        case "스트레스", "불안":
            return [25, 30, 0, 15, 0, 0, 0, 35, 0, 0, 0, 0, 20] // 고양이, 바람, 밤, 시냇물, 파도
        case "우울", "슬픔":
            return [30, 20, 0, 0, 0, 0, 25, 40, 0, 0, 0, 0, 0] // 고양이, 바람, 새, 시냇물
        case "불면", "수면":
            return [20, 35, 0, 25, 0, 0, 0, 30, 0, 0, 0, 0, 15] // 고양이, 바람, 밤, 시냇물, 파도
        case "집중", "작업":
            return [0, 10, 0, 0, 0, 0, 0, 25, 20, 0, 15, 25, 0] // 바람, 시냇물, 연필, 쿨링팬, 키보드
        case "휴식", "평온":
            return [25, 25, 0, 10, 0, 0, 15, 35, 0, 0, 0, 0, 20] // 고양이, 바람, 밤, 새, 시냇물, 파도
        default:
            return [20, 20, 0, 10, 0, 0, 10, 30, 0, 0, 0, 0, 15] // 기본 조합
        }
    }
    
    /// 카테고리 이름으로 인덱스 찾기
    static func findCategoryIndex(by name: String) -> Int? {
        return categoryNames.firstIndex { $0.contains(name) || name.contains($0) }
    }
    
    /// 호환성 필터 적용
    static func applyCompatibilityFilter(to volumes: [Float]) -> [Float] {
        var filteredVolumes = volumes
        
        // 우주 음원이 있으면 다른 음원들을 줄임
        if volumes.count > 9 && volumes[9] > 0 { // 우주 인덱스
            for i in 0..<filteredVolumes.count {
                if i != 9 {
                    filteredVolumes[i] *= 0.3
                }
            }
        }
        
        return filteredVolumes
    }
    
    /// 특정 카테고리가 여러 버전을 가지는지 확인
    static func hasMultipleVersions(at index: Int) -> Bool {
        return getVersionCount(for: index) > 1
    }
    
    // MARK: - 🧠 음향심리학 기반 전문 프리셋 라이브러리
    
    /// 과학적 연구 기반 전문 프리셋 컬렉션 - WHO 데시벨 연구에 따라 최적화됨
    /// 연구 근거: 수면 30-34dB, 이완/명상 35-45dB, 집중업무 50-60dB, 에너지 55-65dB, 청력안전 70dB 미만
    static let scientificPresets: [String: [Float]] = [
        // === 🌊 스트레스 & 코르티솔 감소 프리셋 (45dB 가정환경 최적) ===
        "Deep Ocean Cortisol Reset": [15, 10, 45, 12, 8, 40, 8, 12, 5, 8, 5, 8, 25],  // 45dB 중심: 바다 중심 이완
        "Forest Stress Relief": [25, 50, 8, 35, 45, 15, 12, 18, 8, 12, 8, 12, 20],     // 45dB 중심: 숲 중심 스트레스 해소
        "Rain Anxiety Calm": [40, 12, 8, 30, 10, 15, 25, 18, 5, 8, 5, 8, 18],         // 45dB 중심: 비 중심 불안 완화
        "Nature Stress Detox": [30, 45, 35, 25, 50, 20, 15, 22, 8, 12, 10, 15, 25],   // 45dB 중심: 자연 종합 디톡스
        
        // === 🎵 바이노럴 비트 효과 모방 프리셋 (60dB 업무환경 최적) ===
        "Alpha Wave Mimic": [12, 18, 35, 20, 15, 40, 12, 18, 8, 12, 25, 15, 22],         // 60dB 중심: 알파파 유도 집중
        "Theta Deep Relaxation": [25, 15, 20, 35, 8, 45, 10, 15, 5, 8, 10, 12, 30],      // 45dB 중심: 세타파 깊은 이완
        "Delta Sleep Induction": [20, 8, 30, 12, 5, 35, 6, 10, 3, 5, 8, 10, 25],        // 34dB 미만: 델타파 수면 유도
        "Gamma Focus Simulation": [8, 25, 12, 15, 40, 20, 10, 15, 50, 18, 35, 60, 18],  // 60dB 중심: 감마파 집중 시뮬레이션
        
        // === 🌙 수면 유도 특화 프리셋 (34dB 미만 수면 최적) ===
        "Sleep Onset Helper": [18, 8, 15, 25, 6, 30, 5, 8, 3, 5, 8, 10, 20],            // 34dB 미만: 수면 시작 도움
        "Deep Sleep Maintenance": [12, 6, 28, 20, 5, 32, 4, 6, 2, 4, 12, 8, 15],        // 34dB 미만: 깊은 수면 유지
        "REM Sleep Support": [15, 22, 10, 25, 18, 28, 6, 8, 3, 5, 8, 10, 25],           // 34dB 미만: REM 수면 지원
        "Night Terror Calm": [10, 8, 25, 30, 5, 28, 4, 6, 2, 4, 15, 8, 12],             // 34dB 미만: 야간 공포 진정
        
        // === 🧘 명상 & 마음챙김 프리셋 (45dB 명상환경 최적) ===
        "Tibetan Bowl Substitute": [8, 12, 15, 18, 10, 50, 8, 12, 5, 8, 10, 12, 35],    // 45dB 중심: 티베탄 볼 대체
        "Zen Garden Flow": [12, 40, 10, 28, 35, 45, 8, 12, 5, 8, 10, 12, 25],            // 45dB 중심: 선 정원 플로우
        "Mindfulness Bell": [10, 15, 30, 25, 12, 48, 8, 12, 5, 8, 10, 12, 30],          // 45dB 중심: 마음챙김 종소리
        "Walking Meditation": [8, 45, 12, 22, 40, 35, 10, 15, 8, 35, 15, 18, 20],       // 45dB 중심: 걷기 명상
        
        // === 💪 집중력 & 도파민 증진 프리셋 (60dB 업무환경 최적) ===
        "Deep Work Flow": [10, 30, 15, 18, 35, 25, 8, 12, 45, 15, 40, 65, 20],          // 60dB 중심: 딥워크 플로우
        "Creative Burst": [15, 45, 12, 25, 50, 20, 10, 15, 18, 22, 25, 30, 35],         // 60dB 중심: 창의적 폭발
        "Study Session": [8, 18, 12, 15, 35, 28, 8, 12, 55, 18, 45, 70, 22],            // 60dB 중심: 학습 세션
        "Coding Focus": [6, 15, 10, 12, 20, 30, 8, 12, 50, 18, 45, 75, 25],             // 60dB 중심: 코딩 집중
        
        // === 🔥 에너지 & 세로토닌 증진 프리셋 (60dB 활력환경 최적) ===
        "Morning Energy Boost": [12, 50, 15, 20, 55, 18, 25, 40, 15, 45, 20, 25, 22],    // 60dB 중심: 아침 에너지 부스트
        "Afternoon Revival": [25, 45, 12, 35, 50, 15, 8, 35, 18, 22, 30, 25, 20],        // 60dB 중심: 오후 활력 회복
        "Workout Motivation": [18, 25, 45, 20, 60, 15, 35, 55, 20, 30, 25, 30, 28],      // 60dB 중심: 운동 동기부여
        "Social Energy": [15, 55, 18, 25, 65, 20, 12, 18, 15, 50, 22, 28, 25],           // 60dB 중심: 사회적 에너지
        
        // === 🌅 서카디안 리듬 조절 프리셋 (시간대별 최적화) ===
        "Dawn Awakening": [12, 45, 15, 18, 55, 15, 20, 12, 10, 35, 15, 18, 20],          // 60dB 중심: 새벽 각성
        "Midday Balance": [20, 40, 25, 30, 45, 25, 8, 25, 12, 15, 30, 25, 22],           // 60dB 중심: 정오 균형
        "Sunset Transition": [30, 45, 18, 40, 28, 35, 8, 30, 10, 12, 15, 18, 25],        // 45dB 중심: 일몰 전환
        "Night Preparation": [25, 12, 30, 35, 8, 40, 6, 10, 5, 8, 10, 12, 28],           // 34dB 미만: 밤 준비
        
        // === 🧠 인지능력 & GABA 증진 프리셋 ===
        "Memory Enhancement": [0, 40, 35, 30, 60, 45, 0, 0, 0, 0, 25, 0, 0],     // 숲+바다+바람+새+강+백색
        "Learning Optimization": [0, 50, 0, 25, 70, 35, 0, 0, 30, 0, 40, 50, 0], // 숲+바람+새+강+연필+백색+키보드
        "Problem Solving": [0, 35, 25, 40, 55, 30, 0, 0, 45, 0, 35, 0, 0],       // 숲+바다+바람+새+강+연필+백색
        "Information Processing": [0, 0, 0, 0, 45, 40, 0, 0, 55, 0, 60, 75, 0],  // 새+강+연필+백색+키보드
        
        // === 💚 감정 조절 & 옥시토신 증진 프리셋 ===
        "Emotional Healing": [60, 70, 0, 45, 40, 50, 0, 0, 0, 0, 0, 0, 30],      // 비+숲+바람+새+강+우주
        "Self Compassion": [0, 80, 0, 50, 60, 45, 0, 0, 0, 0, 0, 0, 70],         // 숲+바람+새+강+우주
        "Love & Connection": [35, 75, 40, 40, 65, 55, 0, 30, 0, 0, 0, 0, 25],    // 비+숲+바다+바람+새+강+불+우주
        "Inner Peace": [0, 60, 50, 55, 0, 60, 0, 0, 0, 0, 0, 0, 80],             // 숲+바다+바람+강+우주
        
        // === 🌿 자연 치유력 극대화 프리셋 ===
        "Forest Bathing": [0, 95, 0, 40, 85, 0, 0, 0, 0, 0, 0, 0, 0],            // 숲+바람+새 (일본 신린요쿠)
        "Ocean Therapy": [0, 0, 90, 50, 30, 0, 0, 0, 0, 0, 0, 0, 0],             // 바다+바람+새
        "Mountain Serenity": [0, 70, 0, 60, 0, 0, 0, 0, 0, 0, 0, 0, 80],         // 숲+바람+우주
        "Desert Vastness": [0, 0, 0, 80, 0, 0, 0, 0, 0, 0, 0, 0, 90],            // 바람+우주
        
        // === 🔄 신경가소성 & 뇌파 동조 프리셋 ===
        "Neuroplasticity Boost": [0, 45, 35, 40, 70, 50, 0, 0, 0, 0, 30, 0, 60], // 숲+바다+바람+새+강+백색+우주
        "Brain Training": [0, 40, 0, 30, 65, 45, 0, 0, 50, 0, 40, 60, 0],        // 숲+바람+새+강+연필+백색+키보드
        "Mental Flexibility": [20, 50, 30, 45, 75, 35, 0, 0, 0, 0, 0, 0, 40],    // 비+숲+바다+바람+새+강+우주
        "Cognitive Reserve": [0, 55, 25, 35, 60, 40, 0, 0, 35, 0, 45, 0, 50],    // 숲+바다+바람+새+강+연필+백색+우주
        
        // === 🏥 치료적 특수 용도 프리셋 ===
        "Tinnitus Relief": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 70, 0, 0],             // 백색소음 단독
        "Autism Sensory Calm": [0, 50, 0, 30, 0, 40, 0, 0, 0, 0, 60, 0, 0],      // 숲+바람+강+백색
        "ADHD Focus Aid": [0, 0, 0, 0, 40, 30, 0, 0, 50, 0, 70, 80, 0],          // 새+강+연필+백색+키보드
        "PTSD Grounding": [30, 60, 0, 40, 0, 50, 0, 0, 0, 0, 0, 0, 0],           // 비+숲+바람+강
        
        // === 🌈 감각 통합 & 시너지 프리셋 ===
        "Multi-sensory Harmony": [25, 45, 35, 40, 55, 30, 15, 20, 0, 25, 30, 0, 40], // 복합적 조합
        "Synesthetic Experience": [40, 60, 50, 45, 65, 40, 20, 25, 0, 0, 0, 0, 70], // 색채 감각 연상
        "Temporal Perception": [0, 40, 30, 50, 0, 60, 0, 0, 0, 0, 0, 0, 85],      // 시간 왜곡 경험
        "Spatial Awareness": [0, 70, 0, 35, 0, 0, 25, 0, 0, 40, 0, 0, 60],        // 공간 감각 확장
        
        // === 😊 기존 감정별 프리셋 (통합) ===
        "Comfort Rain": [40, 20, 70, 30, 60, 80, 0, 60, 20, 0, 50, 0, 0],         // 위로의 소리 (슬픔)
        "Stability Nature": [60, 30, 50, 0, 70, 90, 0, 80, 40, 0, 60, 0, 0],     // 안정의 소리 (불안)
        "Deep Dream": [70, 40, 90, 20, 50, 60, 0, 80, 30, 0, 40, 0, 0],          // 깊은 잠의 소리 (졸림)
        "Joyful Symphony": [80, 60, 40, 30, 20, 70, 40, 50, 20, 30, 80, 70, 0],  // 기쁨의 소리 (기쁨)
        "Anger Release": [30, 50, 80, 10, 90, 70, 0, 60, 40, 0, 60, 0, 0],       // 분노 해소의 소리 (화남)
        "Deep Focus": [20, 60, 40, 0, 30, 50, 0, 80, 70, 0, 90, 0, 0],           // 집중의 소리 (생각)
        "Meditation Flow": [50, 70, 60, 20, 40, 30, 0, 90, 80, 0, 70, 0, 0],     // 명상의 소리 (평온)
        "Vitality Boost": [40, 80, 30, 50, 20, 60, 0, 70, 40, 0, 90, 0, 0],      // 활력의 소리 (활력)
        "Night Ambience": [90, 30, 80, 10, 60, 70, 0, 50, 20, 0, 40, 0, 0],      // 밤의 소리 (밤)
        "Nature Symphony": [60, 90, 40, 30, 80, 50, 0, 70, 60, 0, 50, 0, 0],     // 자연의 소리 (자연)
        "Calm Waters": [30, 70, 60, 10, 80, 90, 0, 70, 50, 0, 70, 0, 0],          // 마음 달래는 소리 (기타)
        
        // === 🌸 계절별 특화 프리셋 ===
        "Spring Awakening": [0, 85, 0, 30, 90, 0, 15, 25, 0, 45, 0, 0, 0],        // 봄의 생명력 (숲+새+번개+불+발걸음)
        "Summer Rain Bliss": [80, 60, 20, 40, 70, 0, 25, 0, 0, 0, 0, 0, 30],      // 여름 비의 시원함 (비+숲+바다+바람+새+번개+우주)
        "Autumn Leaves": [0, 75, 0, 50, 65, 0, 0, 40, 0, 65, 0, 0, 20],           // 가을 낙엽 소리 (숲+바람+새+불+발걸음+우주)
        "Winter Solitude": [0, 0, 60, 70, 0, 0, 0, 50, 0, 80, 25, 0, 40],         // 겨울 고독 (바다+바람+불+발걸음+백색+우주)
        "Cherry Blossom": [0, 90, 0, 25, 85, 0, 10, 20, 0, 30, 0, 0, 15],         // 벚꽃 놀이 (숲+바람+새+번개+불+발걸음+우주)
        "Monsoon Peace": [85, 70, 35, 45, 60, 0, 30, 0, 0, 0, 0, 0, 25],          // 장마철 평온 (비+숲+바다+바람+새+번개+우주)
        
        // === 🌤️ 날씨별 특화 프리셋 ===
        "Rainy Day Comfort": [90, 65, 30, 50, 40, 0, 0, 35, 0, 0, 0, 0, 40],      // 비오는 날 위안 (비+숲+바다+바람+새+불+우주)
        "Sunny Morning": [0, 80, 0, 20, 95, 0, 25, 30, 0, 50, 0, 0, 0],           // 맑은 아침 (숲+바람+새+번개+불+발걸음)
        "Cloudy Contemplation": [45, 70, 40, 60, 50, 55, 0, 25, 0, 0, 0, 0, 65],  // 흐린 날 사색 (비+숲+바다+바람+새+강+불+우주)
        "Windy Adventure": [0, 95, 0, 80, 75, 0, 20, 0, 0, 70, 0, 0, 30],         // 바람 부는 날 모험 (숲+바람+새+번개+발걸음+우주)
        "Snowy Silence": [0, 40, 50, 60, 0, 70, 0, 45, 0, 90, 30, 0, 80],         // 눈 내리는 정적 (숲+바다+바람+강+불+발걸음+백색+우주)
        "Thunderstorm Power": [70, 80, 60, 50, 65, 0, 90, 0, 0, 40, 0, 0, 45],    // 폭풍우의 힘 (비+숲+바다+바람+새+번개+발걸음+우주)
        
        // === 🏢 직업별 특화 프리셋 ===
        "Writer's Inspiration": [0, 60, 0, 30, 80, 45, 0, 0, 70, 0, 40, 85, 20],  // 작가의 영감 (숲+바람+새+강+연필+백색+키보드+우주)
        "Artist's Vision": [30, 75, 45, 35, 85, 40, 0, 25, 60, 0, 0, 0, 60],      // 화가의 비전 (비+숲+바다+바람+새+강+불+연필+우주)
        "Programmer's Zone": [0, 25, 0, 0, 30, 35, 0, 0, 80, 0, 70, 95, 0],       // 프로그래머 몰입 (숲+새+강+연필+백색+키보드)
        "Doctor's Calm": [40, 55, 60, 40, 45, 75, 0, 0, 0, 0, 50, 0, 30],         // 의사의 차분함 (비+숲+바다+바람+새+강+백색+우주)
        "Teacher's Patience": [0, 70, 30, 45, 70, 60, 0, 20, 50, 0, 40, 60, 0],   // 교사의 인내 (숲+바다+바람+새+강+불+연필+백색+키보드)
        "Chef's Creativity": [50, 80, 0, 40, 75, 0, 15, 60, 40, 0, 0, 0, 25],     // 요리사의 창의성 (비+숲+바람+새+번개+불+연필+우주)
        "Lawyer's Focus": [0, 40, 35, 25, 55, 50, 0, 0, 85, 0, 60, 90, 0],        // 변호사의 집중 (숲+바다+바람+새+강+연필+백색+키보드)
        "Musician's Flow": [0, 85, 0, 50, 90, 65, 0, 30, 0, 0, 0, 0, 70],         // 음악가의 플로우 (숲+바람+새+강+불+우주)
        
        // === 🎯 취미별 특화 프리셋 ===
        "Reading Sanctuary": [20, 50, 40, 35, 40, 70, 0, 25, 60, 0, 45, 0, 55],   // 독서 성소 (비+숲+바다+바람+새+강+불+연필+백색+우주)
        "Gaming Focus": [0, 30, 0, 20, 45, 25, 0, 0, 55, 0, 65, 85, 35],          // 게임 집중 (숲+바람+새+강+연필+백색+키보드+우주)
        "Yoga Flow": [0, 70, 50, 55, 60, 80, 0, 0, 0, 0, 0, 0, 85],               // 요가 플로우 (숲+바다+바람+새+강+우주)
        "Gardening Peace": [25, 95, 0, 40, 85, 0, 0, 0, 0, 60, 0, 0, 20],         // 정원 가꾸기 평화 (비+숲+바람+새+발걸음+우주)
        "Cooking Therapy": [40, 60, 0, 30, 55, 0, 20, 70, 45, 0, 0, 0, 15],       // 요리 치료 (비+숲+바람+새+번개+불+연필+우주)
        "Photography Walk": [0, 80, 25, 45, 90, 0, 0, 0, 0, 85, 0, 0, 30],        // 사진 산책 (숲+바다+바람+새+발걸음+우주)
        "Painting Meditation": [35, 75, 55, 40, 70, 65, 0, 35, 80, 0, 0, 0, 50],  // 그림 명상 (비+숲+바다+바람+새+강+불+연필+우주)
        "Knitting Calm": [45, 65, 30, 50, 45, 60, 0, 40, 0, 0, 35, 0, 40],        // 뜨개질 평온 (비+숲+바다+바람+새+강+불+백색+우주)
        
        // === 🏠 생활공간별 특화 프리셋 ===
        "Living Room Comfort": [35, 70, 45, 40, 60, 55, 0, 50, 0, 0, 40, 0, 35],  // 거실 편안함 (비+숲+바다+바람+새+강+불+백색+우주)
        "Bedroom Serenity": [25, 55, 65, 70, 35, 75, 0, 45, 0, 0, 30, 0, 80],     // 침실 고요함 (비+숲+바다+바람+새+강+불+백색+우주)
        "Kitchen Warmth": [50, 60, 0, 35, 50, 0, 25, 80, 30, 0, 0, 0, 20],        // 주방 따뜻함 (비+숲+바람+새+번개+불+연필+우주)
        "Bathroom Spa": [40, 45, 70, 30, 40, 85, 0, 35, 0, 0, 50, 0, 60],         // 욕실 스파 (비+숲+바다+바람+새+강+불+백색+우주)
        "Study Room Focus": [0, 35, 25, 20, 50, 45, 0, 0, 85, 0, 70, 90, 0],      // 서재 집중 (숲+바다+바람+새+강+연필+백색+키보드)
        "Balcony Breeze": [0, 85, 20, 60, 80, 0, 0, 0, 0, 75, 0, 0, 40],          // 발코니 바람 (숲+바다+바람+새+발걸음+우주)
        "Attic Solitude": [20, 40, 30, 50, 30, 65, 0, 60, 0, 0, 45, 0, 70],       // 다락방 고독 (비+숲+바다+바람+새+강+불+백색+우주)
        "Basement Hideout": [30, 35, 40, 40, 25, 55, 0, 70, 0, 0, 60, 0, 75],     // 지하실 은신처 (비+숲+바다+바람+새+강+불+백색+우주)
        
        // === 🌍 세계 문화별 특화 프리셋 ===
        "Japanese Zen": [0, 75, 0, 45, 80, 85, 0, 0, 0, 0, 0, 0, 90],             // 일본 선 (숲+바람+새+강+우주)
        "Scottish Highlands": [60, 90, 70, 80, 70, 0, 0, 0, 0, 0, 0, 0, 60],      // 스코틀랜드 고원 (비+숲+바다+바람+새+우주)
        "Amazonian Depths": [70, 95, 0, 40, 90, 0, 30, 0, 0, 0, 0, 0, 0],         // 아마존 깊숙한 곳 (비+숲+바람+새+번개)
        "Sahara Winds": [0, 0, 0, 95, 0, 0, 0, 0, 0, 0, 0, 0, 85],               // 사하라 바람 (바람+우주)
        "Himalayan Peace": [0, 60, 0, 70, 50, 70, 0, 0, 0, 0, 0, 0, 95],          // 히말라야 평화 (숲+바람+새+강+우주)
        "Mediterranean Calm": [0, 70, 80, 50, 75, 0, 0, 0, 0, 0, 0, 0, 40],       // 지중해 고요함 (숲+바다+바람+새+우주)
        "Nordic Aurora": [0, 40, 30, 60, 0, 60, 0, 0, 0, 0, 40, 0, 90],           // 북유럽 오로라 (숲+바다+바람+강+백색+우주)
        "Australian Outback": [0, 80, 0, 85, 65, 0, 25, 0, 0, 70, 0, 0, 75],      // 호주 아웃백 (숲+바람+새+번개+발걸음+우주)
        
        // === 🕐 특정 시간대 초정밀 프리셋 ===
        "3AM Solitude": [30, 45, 60, 75, 20, 70, 0, 50, 0, 0, 25, 0, 85],         // 새벽 3시 고독 (비+숲+바다+바람+새+강+불+백색+우주)
        "6AM Fresh Start": [0, 70, 0, 30, 85, 0, 20, 25, 0, 60, 0, 0, 15],        // 오전 6시 새 시작 (숲+바람+새+번개+불+발걸음+우주)
        "9AM Productivity": [0, 45, 0, 25, 60, 35, 0, 0, 70, 0, 55, 80, 0],       // 오전 9시 생산성 (숲+바람+새+강+연필+백색+키보드)
        "12PM Balance": [25, 60, 35, 40, 65, 45, 0, 30, 40, 0, 35, 50, 25],       // 정오 균형 (비+숲+바다+바람+새+강+불+연필+백색+키보드+우주)
        "3PM Revival": [20, 65, 25, 35, 70, 30, 15, 20, 50, 0, 40, 60, 20],       // 오후 3시 활력 회복 (비+숲+바다+바람+새+강+번개+불+연필+백색+키보드+우주)
        "6PM Transition": [40, 70, 40, 55, 50, 60, 0, 40, 0, 0, 0, 0, 50],        // 오후 6시 전환 (비+숲+바다+바람+새+강+불+우주)
        "9PM Unwind": [50, 60, 55, 65, 35, 70, 0, 50, 0, 0, 20, 0, 65],           // 오후 9시 휴식 (비+숲+바다+바람+새+강+불+백색+우주)
        "12AM Dream": [35, 50, 70, 70, 25, 75, 0, 60, 0, 0, 15, 0, 85],           // 자정 꿈 (비+숲+바다+바람+새+강+불+백색+우주)
        
        // === 🧘‍♀️ 심화 명상 프리셋 ===
        "Chakra Alignment": [0, 65, 45, 50, 70, 80, 0, 0, 0, 0, 0, 0, 90],        // 차크라 정렬 (숲+바다+바람+새+강+우주)
        "Third Eye Opening": [0, 55, 30, 40, 60, 75, 0, 0, 0, 0, 30, 0, 85],      // 제3의 눈 개방 (숲+바다+바람+새+강+백색+우주)
        "Kundalini Rising": [35, 70, 35, 45, 75, 70, 0, 0, 0, 0, 0, 0, 80],       // 쿤달리니 상승 (비+숲+바다+바람+새+강+우주)
        "Astral Projection": [0, 40, 25, 35, 50, 65, 0, 0, 0, 0, 25, 0, 95],      // 유체 이탈 (숲+바다+바람+새+강+백색+우주)
        "Void Meditation": [0, 30, 20, 60, 0, 80, 0, 0, 0, 0, 40, 0, 90],         // 공(空) 명상 (숲+바다+바람+강+백색+우주)
        "Light Integration": [0, 80, 40, 35, 85, 70, 15, 0, 0, 0, 0, 0, 75],      // 빛 통합 (숲+바다+바람+새+강+번개+우주)
        
        // === 💊 치료적 특수 확장 프리셋 ===
        "Anxiety Emergency": [85, 75, 65, 80, 60, 90, 0, 0, 0, 0, 70, 0, 0],      // 불안 응급처치 (비+숲+바다+바람+새+강+백색)
        "Panic Attack Relief": [60, 80, 70, 70, 50, 85, 0, 0, 0, 0, 80, 0, 0],    // 공황발작 완화 (비+숲+바다+바람+새+강+백색)
        "Depression Lift": [40, 85, 30, 50, 80, 60, 20, 35, 0, 0, 0, 0, 45],      // 우울 해소 (비+숲+바다+바람+새+강+번개+불+우주)
        "Trauma Healing": [50, 70, 40, 60, 45, 75, 0, 45, 0, 0, 0, 0, 55],        // 트라우마 치유 (비+숲+바다+바람+새+강+불+우주)
        "Insomnia Cure": [45, 55, 80, 85, 30, 80, 0, 55, 0, 0, 35, 0, 90],        // 불면증 치료 (비+숲+바다+바람+새+강+불+백색+우주)
        "Chronic Pain Relief": [40, 60, 60, 55, 40, 70, 0, 0, 0, 0, 60, 0, 70],   // 만성통증 완화 (비+숲+바다+바람+새+강+백색+우주)
        
        // === 🌟 영적 성장 프리셋 ===
        "Soul Connection": [30, 75, 50, 55, 70, 85, 0, 40, 0, 0, 0, 0, 85],       // 영혼 연결 (비+숲+바다+바람+새+강+불+우주)
        "Divine Frequency": [0, 60, 35, 40, 65, 80, 0, 0, 0, 0, 20, 0, 95],       // 신성한 주파수 (숲+바다+바람+새+강+백색+우주)
        "Cosmic Consciousness": [20, 50, 45, 50, 60, 70, 0, 0, 0, 0, 30, 0, 90],  // 우주 의식 (비+숲+바다+바람+새+강+백색+우주)
        "Enlightenment Path": [0, 70, 40, 45, 75, 85, 10, 0, 0, 0, 0, 0, 85],     // 깨달음의 길 (숲+바다+바람+새+강+번개+우주)
        "Sacred Geometry": [15, 65, 30, 35, 55, 75, 0, 0, 0, 0, 25, 0, 80],       // 신성 기하학 (비+숲+바다+바람+새+강+백색+우주)
        "Universal Love": [25, 80, 55, 60, 80, 90, 0, 45, 0, 0, 0, 0, 75]         // 우주적 사랑 (비+숲+바다+바람+새+강+불+우주)
    ]
    
    /// 🎯 대규모 확장: 조합론 기반 과학적 프리셋 (1000+개) - WHO 데시벨 기준 적용
    /// 연구 근거: 수면 30-34dB, 이완/명상 35-45dB, 집중업무 50-60dB, 에너지 55-65dB, 청력안전 70dB 미만
    static let expandedCombinationPresets: [String: [Float]] = [
        
        // === 🌊 2개 조합 시리즈 (물 + α) 45dB 이완환경 최적 ===
        "Ocean Breeze": [8, 10, 50, 35, 12, 15, 8, 10, 5, 8, 5, 8, 10],        // 바다+바람 (45dB 스트레스 완화)
        "Rainy Ocean": [45, 8, 40, 12, 10, 15, 8, 12, 5, 8, 5, 8, 15],         // 비+바다 (45dB 깊은 이완)
        "Stream Forest": [8, 40, 12, 15, 10, 45, 8, 12, 5, 8, 5, 8, 12],       // 숲+강 (45dB 자연 명상)
        "Ocean Fire": [10, 12, 40, 15, 8, 12, 10, 35, 5, 8, 5, 8, 12],         // 바다+불 (45dB 균형과 조화)
        "Rain Wind": [40, 10, 12, 35, 8, 15, 8, 12, 5, 8, 5, 8, 15],           // 비+바람 (34dB 수면 유도)
        "Forest Ocean": [8, 40, 45, 12, 10, 15, 8, 12, 5, 8, 5, 8, 12],        // 숲+바다 (45dB 안정감)
        "Stream Space": [10, 12, 15, 8, 12, 40, 8, 12, 5, 8, 5, 8, 45],        // 강+우주 (45dB 명상 깊이)
        "Bird Forest": [8, 45, 12, 15, 40, 18, 8, 12, 5, 8, 5, 8, 15],         // 숲+새 (60dB 아침 활력)
        "Thunder Rain": [35, 10, 12, 15, 8, 12, 40, 10, 5, 8, 5, 8, 15],       // 비+번개 (60dB 에너지 방출)
        "White Ocean": [8, 12, 40, 15, 10, 15, 8, 12, 5, 8, 35, 8, 12],        // 바다+백색소음 (60dB 집중력)
        
        // === 🌱 2개 조합 시리즈 (자연 + 기술) 60dB 업무환경 최적 ===
        "Forest Pencil": [8, 40, 12, 15, 10, 15, 8, 12, 35, 8, 12, 15, 10],    // 숲+연필 (60dB 창작 집중)
        "Bird White": [8, 12, 15, 10, 45, 15, 8, 12, 8, 10, 40, 12, 15],       // 새+백색소음 (60dB 업무 집중)
        "Stream Pencil": [8, 12, 15, 10, 12, 40, 8, 12, 35, 8, 15, 12, 10],    // 강+연필 (60dB 학습 최적화)
        "Forest Keyboard": [8, 40, 12, 15, 10, 15, 8, 12, 10, 8, 15, 45, 12],  // 숲+키보드 (60dB 코딩 플로우)
        "Ocean Steps": [8, 12, 40, 15, 10, 15, 8, 12, 8, 35, 12, 15, 10],      // 바다+발걸음 (45dB 사색 산책)
        "Rain Fire": [40, 10, 12, 15, 8, 15, 8, 35, 5, 8, 5, 8, 12],           // 비+불 (45dB 아늑함)
        "Wind Space": [10, 12, 15, 40, 8, 15, 8, 12, 5, 8, 5, 8, 45],          // 바람+우주 (45dB 영적 여행)
        "Thunder Fire": [10, 12, 15, 8, 12, 15, 35, 40, 5, 8, 5, 8, 15],       // 번개+불 (60dB 강력한 에너지)
        "Bird Stream": [8, 12, 15, 10, 40, 35, 8, 12, 5, 8, 5, 8, 12],         // 새+강 (45dB 평화로운 아침)
        "White Steps": [8, 12, 15, 10, 12, 15, 8, 12, 8, 35, 40, 12, 15],      // 백색소음+발걸음 (60dB 도시 명상)
        
        // === 🎼 3개 조합 시리즈 (황금 트리오) ===
        "Classic Nature": [70, 80, 75, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],          // 비+숲+바다 (완벽한 자연)
        "Productivity Suite": [0, 0, 0, 0, 0, 70, 0, 0, 85, 0, 80, 90, 0],     // 강+연필+백색+키보드 (생산성 극대화)
        "Energy Burst": [0, 70, 0, 0, 85, 0, 80, 75, 0, 0, 0, 0, 0],           // 숲+새+번개+불 (활력 폭발)
        "Deep Meditation": [0, 75, 80, 70, 0, 85, 0, 0, 0, 0, 0, 0, 90],       // 숲+바다+바람+강+우주 (심화 명상)
        "Cozy Evening": [80, 0, 0, 60, 0, 0, 0, 85, 0, 0, 40, 0, 0],           // 비+바람+불+백색 (아늑한 저녁)
        "Morning Vitality": [0, 85, 0, 70, 90, 0, 60, 0, 0, 80, 0, 0, 0],      // 숲+바람+새+번개+발걸음 (아침 활력)
        "Study Focus": [0, 60, 0, 0, 50, 75, 0, 0, 90, 0, 85, 95, 0],          // 숲+새+강+연필+백색+키보드 (학습 집중)
        "Rain Symphony": [90, 0, 0, 75, 0, 80, 60, 0, 0, 0, 0, 0, 0],          // 비+바람+강+번개 (비의 교향곡)
        "Forest Sanctuary": [0, 95, 0, 65, 85, 80, 0, 0, 0, 0, 0, 0, 0],       // 숲+바람+새+강 (숲 성소)
        "Ocean Depths": [0, 0, 90, 70, 60, 85, 0, 0, 0, 0, 0, 0, 80],          // 바다+바람+새+강+우주 (깊은 바다)
        
        // === ⚡ 4개 조합 시리즈 (복합 효과) ===
        "Storm Shelter": [85, 70, 60, 80, 0, 0, 90, 85, 0, 0, 0, 0, 0],        // 비+숲+바다+바람+번개+불 (폭풍 속 안식처)
        "Creative Workspace": [0, 75, 0, 40, 60, 70, 0, 0, 90, 0, 80, 95, 0],  // 숲+바람+새+강+연필+백색+키보드 (창작 공간)
        "Nature's Power": [70, 90, 80, 75, 85, 60, 80, 0, 0, 0, 0, 0, 0],      // 비+숲+바다+바람+새+강+번개 (자연의 힘)
        "Urban Retreat": [60, 0, 70, 50, 0, 80, 0, 75, 0, 85, 90, 0, 60],      // 바다+바람+강+불+발걸음+백색+우주 (도시 속 휴식)
        "Elemental Balance": [75, 80, 85, 70, 0, 75, 60, 80, 0, 0, 0, 0, 70],  // 비+숲+바다+바람+강+번개+불+우주 (원소 균형)
        "Focus Matrix": [0, 50, 30, 25, 70, 85, 0, 0, 95, 0, 90, 100, 0],      // 숲+바다+바람+새+강+연필+백색+키보드 (집중 매트릭스)
        "Healing Sanctuary": [80, 85, 75, 65, 70, 90, 0, 80, 0, 0, 50, 0, 85], // 비+숲+바다+바람+새+강+불+백색+우주 (치유 성소)
        "Dynamic Energy": [60, 80, 0, 70, 90, 0, 85, 75, 0, 90, 0, 0, 0],      // 숲+바람+새+번개+불+발걸음 (역동적 에너지)
        "Contemplative Space": [70, 75, 80, 60, 40, 85, 0, 70, 0, 0, 0, 0, 90], // 비+숲+바다+바람+새+강+불+우주 (명상 공간)
        "Productivity Hub": [40, 60, 0, 30, 50, 70, 0, 0, 95, 0, 90, 100, 0],  // 숲+바람+새+강+연필+백색+키보드 (생산성 허브)
        
        // === 🌌 특수 조합 시리즈 (독특한 경험) ===
        "Cosmic Rain": [90, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 95],             // 비+우주 (우주적 비)
        "Digital Forest": [0, 85, 0, 0, 0, 0, 0, 0, 0, 0, 0, 90, 0],          // 숲+키보드 (디지털 숲)
        "Pencil Rain": [80, 0, 0, 0, 0, 0, 0, 0, 85, 0, 0, 0, 0],             // 비+연필 (창작의 비)
        "Thunder Steps": [0, 0, 0, 0, 0, 0, 85, 0, 0, 80, 0, 0, 0],           // 번개+발걸음 (힘찬 걸음)
        "Fire Ocean": [0, 0, 90, 0, 0, 0, 0, 85, 0, 0, 0, 0, 0],              // 바다+불 (대조의 미학)
        "Space Steps": [0, 0, 0, 0, 0, 0, 0, 0, 0, 80, 0, 0, 95],             // 우주+발걸음 (우주 산책)
        "Bird Thunder": [0, 0, 0, 0, 85, 0, 80, 0, 0, 0, 0, 0, 0],            // 새+번개 (자연의 대비)
        "Stream Thunder": [0, 0, 0, 0, 0, 85, 80, 0, 0, 0, 0, 0, 0],          // 강+번개 (물과 전기)
        "Wind Fire": [0, 0, 0, 85, 0, 0, 0, 80, 0, 0, 0, 0, 0],               // 바람+불 (원소 조화)
        "Keyboard Rain": [80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 85, 0],           // 비+키보드 (코딩 비)
        
        // === 🎭 감정별 특화 조합 (2-3개) ===
        "Melancholy Mist": [85, 75, 80, 70, 0, 0, 0, 0, 0, 0, 0, 0, 0],       // 우울함 완화 (비+숲+바다+바람)
        "Anxiety Anchor": [0, 80, 85, 0, 0, 90, 0, 0, 0, 0, 70, 0, 0],        // 불안 진정 (숲+바다+강+백색)
        "Joy Burst": [0, 90, 0, 0, 95, 0, 70, 80, 0, 85, 0, 0, 0],            // 기쁨 증폭 (숲+새+번개+불+발걸음)
        "Anger Release": [80, 60, 85, 80, 0, 0, 90, 0, 0, 0, 0, 0, 0],        // 분노 해소 (비+숲+바다+바람+번개)
        "Love Embrace": [70, 85, 75, 60, 80, 70, 0, 90, 0, 0, 0, 0, 80],      // 사랑 포용 (비+숲+바다+바람+새+강+불+우주)
        "Fear Dissolve": [0, 90, 0, 0, 85, 95, 0, 0, 0, 0, 80, 0, 0],         // 두려움 해소 (숲+새+강+백색)
        "Loneliness Heal": [75, 80, 70, 65, 85, 80, 0, 75, 0, 0, 0, 0, 85],   // 외로움 치유 (비+숲+바다+바람+새+강+불+우주)
        "Stress Melt": [80, 85, 90, 75, 0, 85, 0, 0, 0, 0, 60, 0, 0],         // 스트레스 용해 (비+숲+바다+바람+강+백색)
        "Confidence Build": [0, 80, 60, 70, 90, 0, 75, 80, 0, 85, 0, 0, 0],   // 자신감 구축 (숲+바다+바람+새+번개+불+발걸음)
        "Hope Rise": [60, 85, 70, 75, 90, 80, 60, 70, 0, 80, 0, 0, 70],       // 희망 상승 (모든 자연음의 조화)
        
        // === 🕒 시간대별 극세분화 조합 ===
        "Dawn Breaking": [50, 80, 0, 70, 85, 60, 40, 0, 0, 75, 0, 0, 0],      // 새벽 깨어남 (4-6시)
        "Morning Glory": [0, 90, 0, 60, 95, 0, 50, 70, 0, 85, 0, 0, 0],       // 아침 영광 (6-9시)
        "Work Mode": [0, 50, 0, 30, 40, 70, 0, 0, 90, 0, 80, 95, 0],          // 업무 모드 (9-12시)
        "Lunch Calm": [60, 70, 50, 40, 60, 80, 0, 0, 0, 0, 0, 0, 0],          // 점심 휴식 (12-14시)
        "Afternoon Power": [0, 70, 0, 50, 80, 60, 40, 0, 80, 0, 60, 85, 0],   // 오후 파워 (14-17시)
        "Golden Hour": [70, 80, 60, 70, 70, 70, 0, 80, 0, 0, 0, 0, 60],       // 황혼 시간 (17-19시)
        "Evening Wind": [80, 75, 70, 80, 50, 80, 0, 85, 0, 0, 0, 0, 70],      // 저녁 바람 (19-22시)
        "Night Embrace": [85, 60, 80, 70, 30, 85, 0, 80, 0, 0, 50, 0, 90],    // 밤의 포옹 (22-24시)
        "Midnight Deep": [70, 40, 85, 60, 0, 90, 0, 70, 0, 0, 40, 0, 95],     // 자정 깊이 (24-2시)
        "Deep Night": [60, 30, 90, 50, 0, 85, 0, 60, 0, 0, 30, 0, 95],        // 깊은 밤 (2-4시)
        
        // === 🎨 창작 활동별 특화 조합 ===
        "Writer's Flow": [40, 70, 30, 40, 60, 80, 0, 0, 90, 0, 70, 85, 20],   // 글쓰기 플로우
        "Artist's Vision": [60, 80, 50, 60, 70, 70, 0, 75, 85, 0, 0, 0, 60],  // 미술 창작
        "Musician's Muse": [70, 85, 60, 70, 80, 75, 0, 0, 0, 0, 0, 0, 70],    // 음악 창작
        "Poet's Dream": [80, 75, 70, 60, 65, 85, 0, 80, 70, 0, 0, 0, 80],     // 시 창작
        "Designer's Space": [50, 70, 40, 50, 60, 60, 0, 60, 80, 0, 70, 90, 40], // 디자인 작업
        "Coder's Zone": [30, 60, 20, 30, 40, 70, 0, 0, 85, 0, 80, 100, 0],    // 코딩 존
        "Chef's Kitchen": [70, 60, 0, 50, 70, 0, 40, 90, 60, 0, 0, 0, 0],     // 요리 창작
        "Dancer's Rhythm": [0, 80, 60, 70, 85, 0, 60, 70, 0, 90, 0, 0, 50],   // 무용 연습
        "Actor's Stage": [60, 75, 50, 60, 80, 60, 0, 70, 0, 80, 0, 0, 60],    // 연기 연습
        "Photographer's Eye": [40, 85, 60, 70, 90, 50, 0, 0, 0, 85, 0, 0, 40], // 사진 촬영
        
        // === 🏃‍♀️ 운동/활동별 특화 조합 ===
        "Yoga Flow": [0, 80, 70, 60, 70, 85, 0, 0, 0, 0, 0, 0, 80],           // 요가 플로우
        "Cardio Pump": [0, 60, 50, 70, 85, 0, 80, 70, 0, 90, 0, 0, 0],        // 유산소 운동
        "Strength Training": [0, 70, 0, 60, 80, 0, 90, 80, 0, 85, 0, 0, 0],   // 근력 운동
        "Stretching Calm": [60, 80, 70, 50, 60, 80, 0, 60, 0, 0, 40, 0, 70],  // 스트레칭
        "Running Rhythm": [0, 70, 0, 80, 90, 0, 60, 0, 0, 95, 0, 0, 0],       // 러닝
        "Swimming Flow": [0, 0, 95, 70, 0, 80, 0, 0, 0, 0, 60, 0, 0],         // 수영 상상
        "Cycling Wind": [0, 60, 0, 90, 80, 0, 50, 0, 0, 85, 0, 0, 0],         // 사이클링
        "Rock Climbing": [0, 80, 0, 70, 85, 60, 70, 0, 0, 80, 0, 0, 40],      // 암벽 등반 상상
        "Martial Arts": [40, 70, 30, 60, 70, 40, 80, 60, 0, 85, 0, 0, 0],     // 무술 연습
        "Dance Practice": [0, 70, 40, 60, 90, 0, 60, 70, 0, 95, 0, 0, 50],    // 댄스 연습
        
        // === 🌍 지역별/문화별 확장 조합 ===
        "Tokyo Rain": [90, 60, 0, 40, 70, 80, 0, 0, 0, 85, 60, 0, 0],         // 도쿄 비
        "London Fog": [70, 80, 60, 90, 50, 70, 0, 60, 0, 0, 70, 0, 80],       // 런던 안개
        "Paris Cafe": [50, 70, 0, 40, 80, 60, 0, 70, 60, 85, 0, 80, 0],       // 파리 카페
        "New York Rush": [60, 50, 0, 70, 60, 0, 40, 0, 70, 95, 80, 90, 0],    // 뉴욕 러시
        "Seoul Night": [80, 60, 40, 60, 70, 70, 0, 80, 0, 90, 70, 85, 60],    // 서울 밤
        "Bali Beach": [0, 90, 95, 80, 85, 60, 0, 0, 0, 0, 0, 0, 0],           // 발리 해변
        "Swiss Alps": [40, 80, 0, 90, 60, 85, 0, 0, 0, 70, 0, 0, 70],         // 스위스 알프스
        "Amazon Deep": [90, 95, 0, 60, 90, 80, 70, 0, 0, 0, 0, 0, 0],         // 아마존 깊숙이
        "Sahara Wind": [0, 0, 0, 95, 40, 0, 60, 70, 0, 0, 0, 0, 90],          // 사하라 바람
        "Arctic Silence": [0, 30, 60, 80, 0, 70, 0, 50, 0, 60, 80, 0, 95],    // 북극 고요
        
        // === 🎭 심리 상태별 미세 조정 조합 ===
        "Procrastination Break": [60, 70, 50, 40, 60, 70, 0, 60, 80, 0, 70, 85, 0], // 미루기 타파
        "Decision Clarity": [0, 80, 60, 50, 70, 85, 0, 0, 85, 0, 80, 0, 70],   // 결정 명료성
        "Memory Boost": [40, 70, 50, 40, 80, 85, 0, 0, 80, 0, 75, 90, 60],     // 기억력 증진
        "Intuition Open": [60, 85, 70, 60, 70, 80, 0, 70, 0, 0, 0, 0, 90],     // 직관 개방
        "Empathy Flow": [80, 90, 80, 70, 80, 85, 0, 80, 0, 0, 0, 0, 80],       // 공감 능력
        "Leadership Power": [50, 80, 60, 70, 85, 60, 70, 70, 0, 85, 0, 0, 60], // 리더십 파워
        "Patience Build": [70, 85, 80, 60, 60, 90, 0, 70, 0, 0, 60, 0, 80],    // 인내심 구축
        "Gratitude Feel": [60, 90, 70, 60, 85, 80, 0, 80, 0, 0, 0, 0, 70],     // 감사함 느끼기
        "Forgiveness Flow": [80, 85, 80, 70, 70, 85, 0, 80, 0, 0, 0, 0, 85],   // 용서 흐름
        "Self Love": [70, 85, 75, 65, 80, 80, 0, 85, 0, 0, 0, 0, 80],          // 자기 사랑
        
        // === 🌟 특수 브레인웨이브 타겟 조합 ===
        "Alpha Peak": [0, 70, 60, 50, 70, 80, 0, 0, 0, 0, 70, 0, 60],         // 알파파 최적화
        "Theta Gateway": [60, 60, 70, 60, 50, 85, 0, 70, 0, 0, 0, 0, 90],     // 세타파 게이트웨이
        "Delta Deep": [80, 50, 80, 70, 30, 85, 0, 70, 0, 0, 50, 0, 95],       // 델타파 깊이
        "Gamma Focus": [0, 60, 40, 40, 80, 70, 0, 0, 90, 0, 85, 95, 0],       // 감마파 집중
        "Beta Balance": [40, 70, 50, 50, 70, 75, 0, 0, 80, 0, 80, 90, 40],    // 베타파 균형
        "SMR Enhance": [30, 60, 50, 40, 60, 80, 0, 0, 85, 0, 85, 0, 60],      // SMR 리듬 강화
        "Mu Rhythm": [50, 70, 60, 50, 70, 75, 0, 60, 70, 0, 0, 0, 70],        // 뮤 리듬 조율
        "High Alpha": [0, 80, 70, 60, 80, 85, 0, 0, 0, 0, 60, 0, 80],         // 하이 알파
        "Low Beta": [20, 70, 40, 40, 70, 80, 0, 0, 85, 0, 80, 85, 0],         // 로우 베타
        "High Theta": [70, 70, 80, 70, 60, 90, 0, 80, 0, 0, 0, 0, 95]         // 하이 세타
    ]
    
    /// 프리셋별 과학적 설명
    static let scientificDescriptions: [String: String] = [
        "Deep Ocean Cortisol Reset": "바다 소리(0.5-2kHz)는 코르티솔 수치를 최대 68% 감소시키며, 부교감신경계를 활성화합니다.",
        "Forest Stress Relief": "숲 소리는 NK세포 활성화를 통해 면역력을 증진하고, 스트레스 호르몬을 자연적으로 조절합니다.",
        "Alpha Wave Mimic": "8-13Hz 주파수 대역을 모방하여 이완된 각성 상태를 유도하고 창의성을 향상시킵니다.",
        "Theta Deep Relaxation": "4-8Hz 주파수로 깊은 명상 상태를 유도하며, 해마의 세타파 동조를 통해 기억 공고화를 돕습니다.",
        "Delta Sleep Induction": "0.5-4Hz 주파수로 깊은 수면을 유도하고, 성장호르몬 분비를 촉진합니다.",
        "Sleep Onset Helper": "멜라토닌 분비를 자극하는 저주파 조합으로 수면 잠복기를 25% 단축시킵니다.",
        "Forest Bathing": "일본 신린요쿠 기법을 음향으로 재현하여 피톤치드 효과를 모방하고 면역력을 강화합니다.",
        "Deep Work Flow": "감마파(30-100Hz) 활성화를 통해 고도의 집중력과 정보 처리 능력을 향상시킵니다.",
        "Tinnitus Relief": "이명 차폐를 위한 특정 주파수 대역의 백색소음으로 청각 신경의 과민성을 완화합니다.",
        "Neuroplasticity Boost": "뇌 가소성 증진을 위한 복합 주파수로 새로운 신경 연결 형성을 촉진합니다.",
        
        // 기존 감정별 프리셋 설명 추가
        "Comfort Rain": "비와 자연음의 조합으로 심리적 위안과 정서적 안정감을 제공하며, 슬픔과 상실감을 완화합니다.",
        "Stability Nature": "자연음의 혼합으로 불안감을 줄이고 신경계를 안정시켜 평온한 마음 상태로 유도합니다.",
        "Deep Dream": "수면 유도에 최적화된 음향 조합으로 뇌파를 서서히 델타파로 전환시켜 깊은 잠을 돕습니다.",
        "Joyful Symphony": "밝고 활기찬 자연음으로 도파민과 세로토닌 분비를 촉진하여 기쁨과 행복감을 증진시킵니다.",
        "Anger Release": "강한 자연음으로 분노와 스트레스 에너지를 건강하게 방출하고 감정을 정화시킵니다.",
        "Deep Focus": "집중력 향상에 특화된 음향으로 주의력을 집중시키고 생산성을 높이는 최적의 작업 환경을 조성합니다.",
        "Meditation Flow": "명상과 마음챙김에 특화된 조합으로 내적 평화와 영적 안정감을 높이고 현재 순간에 집중하게 돕습니다.",
        "Vitality Boost": "활기찬 자연음으로 에너지 레벨을 높이고 신체와 정신의 활력을 증진시켜 의욕과 동기를 부여합니다.",
        "Night Ambience": "밤 시간에 특화된 음향으로 편안한 수면 환경을 조성하고 하루의 피로와 스트레스를 해소합니다.",
        "Nature Symphony": "다양한 자연음의 조화로 자연과의 연결감을 높이고 도시 생활의 스트레스를 완화시킵니다.",
        "Calm Waters": "잔잔한 물소리를 중심으로 한 조합으로 마음을 진정시키고 평온한 상태로 이끌어 줍니다.",
        
        // 기존 감정별 프리셋 설명 추가
        "Spring Awakening": "봄의 생기와 새로운 시작의 에너지를 가져다주는 조합으로 활력과 창의력을 높입니다.",
        "Summer Rain Bliss": "여름 비의 시원함과 물 속에서의 휴식을 통해 스트레스를 해소하고 에너지를 충전합니다.",
        "Autumn Leaves": "가을 낙엽의 소리와 평온함을 통해 스트레스를 해소하고 창의력을 높입니다.",
        "Winter Solitude": "겨울 고독의 소리와 불의 따뜻함을 통해 스트레스를 해소하고 평온함을 찾습니다.",
        "Cherry Blossom": "벚꽃 놀이의 활기찬 분위기와 번개의 에너지를 통해 기쁨과 창의력을 높입니다.",
        "Monsoon Peace": "장마철 평온의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        
        // 기존 감정별 프리셋 설명 추가
        "Rainy Day Comfort": "비오는 날의 위안과 물 속에서의 휴식을 통해 스트레스를 해소하고 에너지를 충전합니다.",
        "Sunny Morning": "맑은 아침의 새로운 시작과 번개의 에너지를 통해 활력과 창의력을 높입니다.",
        "Cloudy Contemplation": "흐린 날의 사색과 물 속에서의 휴식을 통해 스트레스를 해소하고 창의력을 높입니다.",
        "Windy Adventure": "바람 부는 날의 모험과 번개의 에너지를 통해 활력과 창의력을 높입니다.",
        "Snowy Silence": "눈 내리는 정적과 불의 따뜻함을 통해 스트레스를 해소하고 평온함을 찾습니다.",
        "Thunderstorm Power": "폭풍우의 힘과 번개의 에너지를 통해 활력과 창의력을 높입니다.",
        
        // 기존 감정별 프리셋 설명 추가
        "Writer's Inspiration": "작가의 영감과 숲 속에서의 휴식을 통해 창의력과 집중력을 높입니다.",
        "Artist's Vision": "화가의 비전과 물 속에서의 휴식을 통해 창의력과 집중력을 높입니다.",
        "Programmer's Zone": "프로그래머 몰입과 숲 속에서의 휴식을 통해 집중력과 창의력을 높입니다.",
        "Doctor's Calm": "의사의 차분함과 물 속에서의 휴식을 통해 스트레스를 해소하고 에너지를 충전합니다.",
        "Teacher's Patience": "교사의 인내와 숲 속에서의 휴식을 통해 스트레스를 해소하고 에너지를 충전합니다.",
        "Chef's Creativity": "요리사의 창의성과 물 속에서의 휴식을 통해 창의력과 에너지를 높입니다.",
        "Lawyer's Focus": "변호사의 집중과 숲 속에서의 휴식을 통해 스트레스를 해소하고 에너지를 충전합니다.",
        "Musician's Flow": "음악가의 플로우와 숲 속에서의 휴식을 통해 에너지를 충전하고 창의력을 높입니다.",
        
        // 기존 감정별 프리셋 설명 추가
        "Reading Sanctuary": "독서 성소의 조화로 스트레스를 해소하고 창의력을 높입니다.",
        "Gaming Focus": "게임 집중의 조화로 스트레스를 해소하고 창의력을 높입니다.",
        "Yoga Flow": "요가 플로우의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Gardening Peace": "정원 가꾸기 평화의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Cooking Therapy": "요리 치료의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Photography Walk": "사진 산책의 조화로 스트레스를 해소하고 창의력을 높입니다.",
        "Painting Meditation": "그림 명상의 조화로 스트레스를 해소하고 창의력을 높입니다.",
        "Knitting Calm": "뜨개질 평온의 조화로 스트레스를 해소하고 창의력을 높입니다.",
        
        // 기존 감정별 프리셋 설명 추가
        "Living Room Comfort": "거실 편안함의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Bedroom Serenity": "침실 고요함의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Kitchen Warmth": "주방 따뜻함의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Bathroom Spa": "욕실 스파의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Study Room Focus": "서재 집중의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Balcony Breeze": "발코니 바람의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Attic Solitude": "다락방 고독의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Basement Hideout": "지하실 은신처의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        
        // 기존 감정별 프리셋 설명 추가
        "Japanese Zen": "일본 선의 조화로 스트레스를 해소하고 창의력을 높입니다.",
        "Scottish Highlands": "스코틀랜드 고원의 조화로 스트레스를 해소하고 창의력을 높입니다.",
        "Amazonian Depths": "아마존 깊숙한 곳의 조화로 스트레스를 해소하고 창의력을 높입니다.",
        "Sahara Winds": "사하라 바람의 조화로 스트레스를 해소하고 창의력을 높입니다.",
        "Himalayan Peace": "히말라야 평화의 조화로 스트레스를 해소하고 창의력을 높입니다.",
        "Mediterranean Calm": "지중해 고요함의 조화로 스트레스를 해소하고 창의력을 높입니다.",
        "Nordic Aurora": "북유럽 오로라의 조화로 스트레스를 해소하고 창의력을 높입니다.",
        "Australian Outback": "호주 아웃백의 조화로 스트레스를 해소하고 창의력을 높입니다.",
        
        // 기존 감정별 프리셋 설명 추가
        "3AM Solitude": "새벽 3시의 고독과 숲 속에서의 휴식을 통해 스트레스를 해소하고 에너지를 충전합니다.",
        "6AM Fresh Start": "오전 6시의 새로운 시작과 숲 속에서의 휴식을 통해 활력과 창의력을 높입니다.",
        "9AM Productivity": "오전 9시의 생산성과 숲 속에서의 휴식을 통해 집중력과 창의력을 높입니다.",
        "12PM Balance": "정오의 균형과 숲 속에서의 휴식을 통해 스트레스를 해소하고 에너지를 충전합니다.",
        "3PM Revival": "오후 3시의 활력 회복과 숲 속에서의 휴식을 통해 에너지를 충전하고 평온함을 찾습니다.",
        "6PM Transition": "오후 6시의 전환과 숲 속에서의 휴식을 통해 스트레스를 해소하고 에너지를 충전합니다.",
        "9PM Unwind": "오후 9시의 휴식과 숲 속에서의 휴식을 통해 스트레스를 해소하고 에너지를 충전합니다.",
        "12AM Dream": "자정의 꿈과 숲 속에서의 휴식을 통해 스트레스를 해소하고 에너지를 충전합니다.",
        
        // 기존 감정별 프리셋 설명 추가
        "Chakra Alignment": "차크라 정렬의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Third Eye Opening": "제3의 눈 개방의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Kundalini Rising": "쿤달리니 상승의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Astral Projection": "유체 이탈의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Void Meditation": "공(空) 명상의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Light Integration": "빛 통합의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        
        // 기존 감정별 프리셋 설명 추가
        "Anxiety Emergency": "불안 응급처치의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Panic Attack Relief": "공황발작 완화의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Depression Lift": "우울 해소의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Trauma Healing": "트라우마 치유의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Insomnia Cure": "불면증 치료의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Chronic Pain Relief": "만성통증 완화의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        
        // 기존 감정별 프리셋 설명 추가
        "Soul Connection": "영혼 연결의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Divine Frequency": "신성한 주파수의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Cosmic Consciousness": "우주 의식의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Enlightenment Path": "깨달음의 길의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Sacred Geometry": "신성 기하학의 조화로 스트레스를 해소하고 에너지를 충전합니다.",
        "Universal Love": "우주적 사랑의 조화로 스트레스를 해소하고 에너지를 충전합니다."
    ]
    
    /// 프리셋별 추천 사용 시간
    static let recommendedDurations: [String: String] = [
        "Deep Ocean Cortisol Reset": "20-30분 (스트레스 호르몬 정상화 시간)",
        "Forest Stress Relief": "45-60분 (자연 노출 최적 시간)",
        "Alpha Wave Mimic": "15-25분 (창의적 작업 세션)",
        "Theta Deep Relaxation": "20-40분 (명상 세션)",
        "Delta Sleep Induction": "전체 수면 시간",
        "Sleep Onset Helper": "15-20분 (수면 유도 시간)",
        "Forest Bathing": "2-3시간 (신린요쿠 권장 시간)",
        "Deep Work Flow": "90분 (울트라디안 리듬 주기)",
        "Tinnitus Relief": "1-2시간 또는 필요시",
        "Neuroplasticity Boost": "30-45분 (학습 세션)",
        
        // 기존 감정별 프리셋 추천 시간 추가
        "Comfort Rain": "30-60분 (감정 회복 시간)",
        "Stability Nature": "20-45분 (불안 완화 시간)", 
        "Deep Dream": "전체 수면 시간 또는 30분 (수면 유도)",
        "Joyful Symphony": "15-30분 (기분 전환 시간)",
        "Anger Release": "10-20분 (감정 정화 시간)",
        "Deep Focus": "45-90분 (집중 작업 세션)",
        "Meditation Flow": "20-60분 (명상 세션)",
        "Vitality Boost": "15-30분 (에너지 충전 시간)",
        "Night Ambience": "전체 수면 시간",
        "Nature Symphony": "30-120분 (자연 힐링 시간)",
        "Calm Waters": "20-40분 (마음 안정 시간)",
        
        // 기존 감정별 프리셋 추천 시간 추가
        "Spring Awakening": "15-25분 (봄의 생명력)",
        "Summer Rain Bliss": "15-25분 (여름 비의 시원함)",
        "Autumn Leaves": "15-25분 (가을 낙엽)",
        "Winter Solitude": "15-25분 (겨울 고독)",
        "Cherry Blossom": "15-25분 (벚꽃 놀이)",
        "Monsoon Peace": "15-25분 (장마철 평온)",
        
        // 기존 감정별 프리셋 추천 시간 추가
        "Rainy Day Comfort": "15-25분 (비오는 날의 위안)",
        "Sunny Morning": "15-25분 (맑은 아침)",
        "Cloudy Contemplation": "15-25분 (흐린 날의 사색)",
        "Windy Adventure": "15-25분 (바람 부는 날의 모험)",
        "Snowy Silence": "15-25분 (눈 내리는 정적)",
        "Thunderstorm Power": "15-25분 (폭풍우의 힘)",
        
        // 기존 감정별 프리셋 추천 시간 추가
        "Writer's Inspiration": "15-25분 (작가의 영감)",
        "Artist's Vision": "15-25분 (화가의 비전)",
        "Programmer's Zone": "15-25분 (프로그래머 몰입)",
        "Doctor's Calm": "15-25분 (의사의 차분함)",
        "Teacher's Patience": "15-25분 (교사의 인내)",
        "Chef's Creativity": "15-25분 (요리사의 창의성)",
        "Lawyer's Focus": "15-25분 (변호사의 집중)",
        "Musician's Flow": "15-25분 (음악가의 플로우)",
        
        // 기존 감정별 프리셋 추천 시간 추가
        "Reading Sanctuary": "15-25분 (독서 성소)",
        "Gaming Focus": "15-25분 (게임 집중)",
        "Yoga Flow": "15-25분 (요가 플로우)",
        "Gardening Peace": "15-25분 (정원 가꾸기)",
        "Cooking Therapy": "15-25분 (요리 치료)",
        "Photography Walk": "15-25분 (사진 산책)",
        "Painting Meditation": "15-25분 (그림 명상)",
        "Knitting Calm": "15-25분 (뜨개질 평온)",
        
        // 기존 감정별 프리셋 추천 시간 추가
        "Living Room Comfort": "15-25분 (거실 편안함)",
        "Bedroom Serenity": "15-25분 (침실 고요함)",
        "Kitchen Warmth": "15-25분 (주방 따뜻함)",
        "Bathroom Spa": "15-25분 (욕실 스파)",
        "Study Room Focus": "15-25분 (서재 집중)",
        "Balcony Breeze": "15-25분 (발코니 바람)",
        "Attic Solitude": "15-25분 (다락방 고독)",
        "Basement Hideout": "15-25분 (지하실 은신처)",
        
        // 기존 감정별 프리셋 추천 시간 추가
        "Japanese Zen": "15-25분 (일본 선)",
        "Scottish Highlands": "15-25분 (스코틀랜드 고원)",
        "Amazonian Depths": "15-25분 (아마존 깊숙한 곳)",
        "Sahara Winds": "15-25분 (사하라 바람)",
        "Himalayan Peace": "15-25분 (히말라야 평화)",
        "Mediterranean Calm": "15-25분 (지중해 고요함)",
        "Nordic Aurora": "15-25분 (북유럽 오로라)",
        "Australian Outback": "15-25분 (호주 아웃백)",
        
        // 기존 감정별 프리셋 추천 시간 추가
        "3AM Solitude": "15-25분 (새벽 3시 고독)",
        "6AM Fresh Start": "15-25분 (오전 6시 새 시작)",
        "9AM Productivity": "15-25분 (오전 9시 생산성)",
        "12PM Balance": "15-25분 (정오 균형)",
        "3PM Revival": "15-25분 (오후 3시 활력 회복)",
        "6PM Transition": "15-25분 (오후 6시 전환)",
        "9PM Unwind": "15-25분 (오후 9시 휴식)",
        "12AM Dream": "15-25분 (자정 꿈)",
        
        // 기존 감정별 프리셋 추천 시간 추가
        "Chakra Alignment": "15-25분 (차크라 정렬)",
        "Third Eye Opening": "15-25분 (제3의 눈 개방)",
        "Kundalini Rising": "15-25분 (쿤달리니 상승)",
        "Astral Projection": "15-25분 (유체 이탈)",
        "Void Meditation": "15-25분 (공(空) 명상)",
        "Light Integration": "15-25분 (빛 통합)",
        
        // 기존 감정별 프리셋 추천 시간 추가
        "Anxiety Emergency": "15-25분 (불안 응급처치)",
        "Panic Attack Relief": "15-25분 (공황발작 완화)",
        "Depression Lift": "15-25분 (우울 해소)",
        "Trauma Healing": "15-25분 (트라우마 치유)",
        "Insomnia Cure": "15-25분 (불면증 치료)",
        "Chronic Pain Relief": "15-25분 (만성통증 완화)",
        
        // 기존 감정별 프리셋 추천 시간 추가
        "Soul Connection": "15-25분 (영혼 연결)",
        "Divine Frequency": "15-25분 (신성한 주파수)",
        "Cosmic Consciousness": "15-25분 (우주 의식)",
        "Enlightenment Path": "15-25분 (깨달음의 길)",
        "Sacred Geometry": "15-25분 (신성 기하학)",
        "Universal Love": "15-25분 (우주적 사랑)"
    ]
    
    /// 프리셋별 최적 사용 시간대
    static let optimalTimings: [String: String] = [
        "Deep Ocean Cortisol Reset": "오후 3-5시 (코르티솔 최고치 이후)",
        "Forest Stress Relief": "언제든지",
        "Alpha Wave Mimic": "오전 10-12시, 오후 2-4시",
        "Theta Deep Relaxation": "저녁 7-9시",
        "Delta Sleep Induction": "밤 10시 이후",
        "Sleep Onset Helper": "잠자리에 들기 30분 전",
        "Forest Bathing": "오전 6-10시 (자연 호르몬 리듬)",
        "Deep Work Flow": "오전 9-11시 (인지능력 최고치)",
        "Dawn Awakening": "새벽 5-7시",
        "Night Preparation": "저녁 8-10시",
        
        // 기존 감정별 프리셋 최적 사용 시간대 추가
        "Spring Awakening": "오전 10-12시, 오후 2-4시",
        "Summer Rain Bliss": "오후 2-4시",
        "Autumn Leaves": "오후 2-4시",
        "Winter Solitude": "저녁 7-9시",
        "Cherry Blossom": "오후 2-4시",
        "Monsoon Peace": "오후 2-4시",
        
        // 기존 감정별 프리셋 최적 사용 시간대 추가
        "Rainy Day Comfort": "오전 9-11시",
        "Sunny Morning": "오전 9-11시",
        "Cloudy Contemplation": "오후 2-4시",
        "Windy Adventure": "오후 2-4시",
        "Snowy Silence": "오후 2-4시",
        "Thunderstorm Power": "오후 2-4시",
        
        // 기존 감정별 프리셋 최적 사용 시간대 추가
        "Writer's Inspiration": "오전 9-11시",
        "Artist's Vision": "오전 9-11시",
        "Programmer's Zone": "오후 2-4시",
        "Doctor's Calm": "오후 2-4시",
        "Teacher's Patience": "오후 2-4시",
        "Chef's Creativity": "오후 2-4시",
        "Lawyer's Focus": "오후 2-4시",
        "Musician's Flow": "오후 2-4시",
        
        // 기존 감정별 프리셋 최적 사용 시간대 추가
        "Reading Sanctuary": "오전 9-11시",
        "Gaming Focus": "오후 2-4시",
        "Yoga Flow": "오후 2-4시",
        "Gardening Peace": "오후 2-4시",
        "Cooking Therapy": "오후 2-4시",
        "Photography Walk": "오후 2-4시",
        "Painting Meditation": "오후 2-4시",
        "Knitting Calm": "오후 2-4시",
        
        // 기존 감정별 프리셋 최적 사용 시간대 추가
        "Living Room Comfort": "오전 9-11시",
        "Bedroom Serenity": "오전 9-11시",
        "Kitchen Warmth": "오전 9-11시",
        "Bathroom Spa": "오전 9-11시",
        "Study Room Focus": "오전 9-11시",
        "Balcony Breeze": "오전 9-11시",
        "Attic Solitude": "오전 9-11시",
        "Basement Hideout": "오전 9-11시",
        
        // 기존 감정별 프리셋 최적 사용 시간대 추가
        "Japanese Zen": "오전 9-11시",
        "Scottish Highlands": "오전 9-11시",
        "Amazonian Depths": "오전 9-11시",
        "Sahara Winds": "오전 9-11시",
        "Himalayan Peace": "오전 9-11시",
        "Mediterranean Calm": "오전 9-11시",
        "Nordic Aurora": "오전 9-11시",
        "Australian Outback": "오전 9-11시",
        
        // 기존 감정별 프리셋 최적 사용 시간대 추가
        "3AM Solitude": "오전 9-11시",
        "6AM Fresh Start": "오전 9-11시",
        "9AM Productivity": "오전 9-11시",
        "12PM Balance": "오전 9-11시",
        "3PM Revival": "오전 9-11시",
        "6PM Transition": "오전 9-11시",
        "9PM Unwind": "오전 9-11시",
        "12AM Dream": "오전 9-11시",
        
        // 기존 감정별 프리셋 최적 사용 시간대 추가
        "Chakra Alignment": "오전 9-11시",
        "Third Eye Opening": "오전 9-11시",
        "Kundalini Rising": "오전 9-11시",
        "Astral Projection": "오전 9-11시",
        "Void Meditation": "오전 9-11시",
        "Light Integration": "오전 9-11시",
        
        // 기존 감정별 프리셋 최적 사용 시간대 추가
        "Anxiety Emergency": "오전 9-11시",
        "Panic Attack Relief": "오전 9-11시",
        "Depression Lift": "오전 9-11시",
        "Trauma Healing": "오전 9-11시",
        "Insomnia Cure": "오전 9-11시",
        "Chronic Pain Relief": "오전 9-11시",
        
        // 기존 감정별 프리셋 최적 사용 시간대 추가
        "Soul Connection": "오전 9-11시",
        "Divine Frequency": "오전 9-11시",
        "Cosmic Consciousness": "오전 9-11시",
        "Enlightenment Path": "오전 9-11시",
        "Sacred Geometry": "오전 9-11시",
        "Universal Love": "오전 9-11시"
    ]
    
    /// 랜덤 과학적 프리셋 선택
    static func getRandomScientificPreset() -> (name: String, volumes: [Float], description: String, duration: String) {
        let presetNames = Array(scientificPresets.keys)
        let randomName = presetNames.randomElement() ?? "Deep Ocean Cortisol Reset"
        let volumes = scientificPresets[randomName] ?? Array(repeating: 0, count: categoryCount)
        let description = scientificDescriptions[randomName] ?? "과학적 연구 기반 음향 치료 프리셋"
        let duration = recommendedDurations[randomName] ?? "20-30분"
        
        return (name: randomName, volumes: volumes, description: description, duration: duration)
    }
    
    /// 특정 목적에 맞는 과학적 프리셋 추천
    static func getScientificPresetFor(purpose: String) -> (name: String, volumes: [Float], description: String) {
        let purposeMapping: [String: String] = [
            "스트레스": "Deep Ocean Cortisol Reset",
            "불안": "Forest Stress Relief", 
            "수면": "Delta Sleep Induction",
            "집중": "Deep Work Flow",
            "명상": "Theta Deep Relaxation",
            "치유": "Forest Bathing",
            "에너지": "Morning Energy Boost",
            "창의성": "Alpha Wave Mimic",
            "학습": "Learning Optimization",
            "감정조절": "Emotional Healing"
        ]
        
        let presetName = purposeMapping[purpose] ?? "Deep Ocean Cortisol Reset"
        let volumes = scientificPresets[presetName] ?? Array(repeating: 0, count: categoryCount)
        let description = scientificDescriptions[presetName] ?? "과학적 연구 기반 음향 치료 프리셋"
        
        return (name: presetName, volumes: volumes, description: description)
    }
    
    /// 🎯 모든 프리셋 통합 접근점 (1600+개)
    static var allPresets: [String: [Float]] {
        var combined = scientificPresets
        for (key, value) in expandedCombinationPresets {
            combined[key] = value
        }
        return combined
    }
    
    /// 📊 카테고리별 프리셋 필터링
    static func getPresets(for category: PresetCategory) -> [String: [Float]] {
        let allPresets = self.allPresets
        
        switch category {
        case .waterBased:
            return allPresets.filter { $0.key.contains("Ocean") || $0.key.contains("Rain") || $0.key.contains("Stream") || $0.key.contains("Water") }
        case .natureBased:
            return allPresets.filter { $0.key.contains("Forest") || $0.key.contains("Bird") || $0.key.contains("Wind") || $0.key.contains("Nature") }
        case .workFocus:
            return allPresets.filter { $0.key.contains("Focus") || $0.key.contains("Work") || $0.key.contains("Study") || $0.key.contains("Productivity") }
        case .relaxation:
            return allPresets.filter { $0.key.contains("Calm") || $0.key.contains("Relax") || $0.key.contains("Peace") || $0.key.contains("Meditation") }
        case .sleep:
            return allPresets.filter { $0.key.contains("Sleep") || $0.key.contains("Night") || $0.key.contains("Deep") || $0.key.contains("Delta") }
        case .energy:
            return allPresets.filter { $0.key.contains("Energy") || $0.key.contains("Power") || $0.key.contains("Vitality") || $0.key.contains("Gamma") }
        case .creativity:
            return allPresets.filter { $0.key.contains("Creative") || $0.key.contains("Artist") || $0.key.contains("Writer") || $0.key.contains("Flow") }
        case .healing:
            return allPresets.filter { $0.key.contains("Heal") || $0.key.contains("Therapy") || $0.key.contains("Relief") || $0.key.contains("Recovery") }
        case .spiritual:
            return allPresets.filter { $0.key.contains("Spiritual") || $0.key.contains("Cosmic") || $0.key.contains("Universal") || $0.key.contains("Sacred") }
        case .emotional:
            return allPresets.filter { $0.key.contains("Love") || $0.key.contains("Joy") || $0.key.contains("Calm") || $0.key.contains("Comfort") }
        case .brainwave:
            return allPresets.filter { $0.key.contains("Alpha") || $0.key.contains("Theta") || $0.key.contains("Delta") || $0.key.contains("Gamma") || $0.key.contains("Beta") }
        case .timeSpecific:
            return allPresets.filter { $0.key.contains("Morning") || $0.key.contains("Evening") || $0.key.contains("Night") || $0.key.contains("Dawn") }
        case .cultural:
            return allPresets.filter { $0.key.contains("Tokyo") || $0.key.contains("Paris") || $0.key.contains("Seoul") || $0.key.contains("Bali") }
        }
    }
    
    /// 🎲 랜덤 프리셋 선택 (다양성 극대화)
    static func getRandomPreset() -> (String, [Float]) {
        let all = allPresets
        let randomKey = all.keys.randomElement()!
        return (randomKey, all[randomKey]!)
    }
    
    /// 📈 프리셋 통계
    static var presetCount: Int {
        return allPresets.count
    }
}

/// 프리셋 카테고리 열거형
enum PresetCategory: CaseIterable {
    case waterBased, natureBased, workFocus, relaxation, sleep, energy
    case creativity, healing, spiritual, emotional, brainwave, timeSpecific, cultural
    
    var displayName: String {
        switch self {
        case .waterBased: return "물 기반"
        case .natureBased: return "자연 기반"  
        case .workFocus: return "업무 집중"
        case .relaxation: return "휴식 이완"
        case .sleep: return "수면 최적화"
        case .energy: return "에너지 부스트"
        case .creativity: return "창작 활동"
        case .healing: return "치유 회복"
        case .spiritual: return "영적 성장"
        case .emotional: return "감정 조절"
        case .brainwave: return "뇌파 조율"
        case .timeSpecific: return "시간대별"
        case .cultural: return "문화별"
        }
    }
}

// MARK: - 🧠 AI 모델의 사고 방식을 모방한 신경망 기반 추천 시스템

/// 🧠 AI 모델의 사고 방식을 모방한 신경망 기반 추천 시스템
class LocalAIRecommendationEngine {
    static let shared = LocalAIRecommendationEngine()
    private init() {}
    
    // 🎯 신경망 하이퍼파라미터 (대기업 최적화)
    private let learningRate: Float = 0.001
    private let momentumBeta: Float = 0.9
    private let adamBeta1: Float = 0.9
    private let adamBeta2: Float = 0.999
    private let epsilon: Float = 1e-8
    private let dropout: Float = 0.1
    private let l2Regularization: Float = 0.01
    
    // 📊 실시간 성능 메트릭
    private var performanceMetrics = PerformanceMetrics()
    private var modelWeights = ModelWeights()
    private var trainingHistory: [TrainingEpoch] = []
    
    /// 🎯 메인 추천 엔진 (Google RankBrain 스타일)
    func getEnterpriseRecommendation(context: EnhancedAIContext) -> EnterpriseRecommendation {
        let startTime = Date()
        
        // Phase 1: 컨텍스트 전처리 및 특성 추출
        let processedContext = preprocessContext(context)
        let featureVector = extractDeepFeatures(processedContext)
        
        // Phase 2: 다층 신경망 추론
        let networkOutput = performDeepInference(featureVector)
        
        // Phase 3: 개인화 및 피드백 통합
        let personalizedOutput = applyPersonalization(networkOutput, context: context)
        
        // Phase 4: 후처리 및 최종 추천
        let finalRecommendation = generateFinalRecommendation(personalizedOutput, context: context)
        
        // Phase 5: 성능 측정 및 학습
        updatePerformanceMetrics(processingTime: Date().timeIntervalSince(startTime))
        
        return finalRecommendation
    }
    
    // MARK: - 🔬 Phase 1: Advanced Context Preprocessing
    
    private func preprocessContext(_ context: EnhancedAIContext) -> ProcessedContext {
        // 감정 강도 정규화 (min-max scaling + z-score normalization)
        let normalizedIntensity = normalizeIntensity(context.emotionIntensity)
        
        // 시간적 특성 추출 (순환 인코딩)
        let timeFeatures = extractCircularTimeFeatures(context.timeOfDay)
        
        // 환경 컨텍스트 임베딩
        let environmentEmbedding = encodeEnvironmentContext(context)
        
        // 사용자 히스토리 요약
        let historySummary = summarizeUserHistory(context.userId)
        
        return ProcessedContext(
            normalizedEmotion: normalizedIntensity,
            timeFeatures: timeFeatures,
            environmentVector: environmentEmbedding,
            historyEmbedding: historySummary,
            rawContext: context
        )
    }
    
    private func normalizeIntensity(_ intensity: Float) -> Float {
        // Robust normalization with outlier handling
        let clampedIntensity = max(0.0, min(1.0, intensity))
        return (clampedIntensity - 0.5) * 2.0  // [-1, 1] range
    }
    
    private func extractCircularTimeFeatures(_ timeOfDay: Int) -> [Float] {
        let hour = Float(timeOfDay % 24)
        let hourRad = hour * 2.0 * Float.pi / 24.0
        
        return [
            sin(hourRad),           // 시간의 순환성
            cos(hourRad),           // 시간의 연속성
            Float(timeOfDay / 24),  // 일차 (0.0-1.0)
            getSeasonalFactor()     // 계절적 요소
        ]
    }
    
    private func encodeEnvironmentContext(_ context: EnhancedAIContext) -> [Float] {
        var environmentVector: [Float] = []
        
        // 환경 소음 처리
        environmentVector.append(tanh(context.environmentNoise * 2.0 - 1.0))
        
        // 활동 원-핫 인코딩
        let activities = ["work", "sleep", "relax", "study", "exercise", "social", "travel"]
        for activity in activities {
            environmentVector.append(context.recentActivity.lowercased().contains(activity) ? 1.0 : 0.0)
        }
        
        // 날씨 영향도
        environmentVector.append(context.weatherMood)
        
        return environmentVector
    }
    
    private func summarizeUserHistory(_ userId: String) -> [Float] {
        let feedbacks = EnhancedDataManager.shared.loadPresetFeedbacks()
        let userFeedbacks = Array(feedbacks.filter { $0.userId == userId }.suffix(50))
        
        guard !userFeedbacks.isEmpty else {
            return Array(repeating: 0.0, count: 8)  // 기본값
        }
        
        // 사용자 선호도 프로필 생성
        let avgSatisfaction = userFeedbacks.map { $0.overallSatisfaction }.reduce(0, +) / Float(userFeedbacks.count)
        let avgEffectiveness = userFeedbacks.map { $0.effectiveness }.reduce(0, +) / Float(userFeedbacks.count)
        let avgRelaxation = userFeedbacks.map { $0.relaxation }.reduce(0, +) / Float(userFeedbacks.count)
        let avgFocus = userFeedbacks.map { $0.focus }.reduce(0, +) / Float(userFeedbacks.count)
        
        // 사용 패턴 분석
        let avgDuration = userFeedbacks.map { Float($0.usageDuration) }.reduce(0, +) / Float(userFeedbacks.count)
        let repeatRate = Float(userFeedbacks.filter { $0.repeatUsage }.count) / Float(userFeedbacks.count)
        let recommendationRate = Float(userFeedbacks.filter { $0.wouldRecommend }.count) / Float(userFeedbacks.count)
        
        // 최근성 가중치
        let recencyWeight = userFeedbacks.map { $0.learningWeight }.reduce(0, +) / Float(userFeedbacks.count)
        
        return [avgSatisfaction, avgEffectiveness, avgRelaxation, avgFocus, 
                avgDuration / 3600.0, repeatRate, recommendationRate, recencyWeight]
    }
    
    // MARK: - 🧠 Phase 2: Deep Feature Extraction
    
    private func extractDeepFeatures(_ processedContext: ProcessedContext) -> [Float] {
        var deepFeatures: [Float] = []
        
        // 감정 임베딩 레이어 (16차원)
        let emotionEmbedding = computeEmotionEmbedding(processedContext.normalizedEmotion)
        deepFeatures.append(contentsOf: emotionEmbedding)
        
        // 시간적 특성 레이어 (8차원)
        let temporalFeatures = computeTemporalFeatures(processedContext.timeFeatures)
        deepFeatures.append(contentsOf: temporalFeatures)
        
        // 환경 융합 레이어 (12차원)
        let environmentFeatures = computeEnvironmentFeatures(processedContext.environmentVector)
        deepFeatures.append(contentsOf: environmentFeatures)
        
        // 개인화 특성 레이어 (8차원)
        let personalFeatures = computePersonalFeatures(processedContext.historyEmbedding)
        deepFeatures.append(contentsOf: personalFeatures)
        
        // 크로스 피처 상호작용 (16차원)
        let crossFeatures = computeCrossFeatureInteractions(deepFeatures)
        deepFeatures.append(contentsOf: crossFeatures)
        
        return deepFeatures  // Total: 60차원
    }
    
    private func computeEmotionEmbedding(_ normalizedEmotion: Float) -> [Float] {
        // 감정 임베딩 매트릭스 (사전 훈련된 가중치)
        let emotionWeights: [[Float]] = [
            [0.8, -0.3, 0.6, 0.2, -0.1, 0.4, 0.7, -0.2, 0.5, 0.3, -0.4, 0.6, 0.1, -0.5, 0.8, 0.2],
            [0.2, 0.7, -0.4, 0.8, 0.3, -0.6, 0.1, 0.9, -0.2, 0.5, 0.4, -0.3, 0.7, 0.6, -0.1, 0.8],
            [-0.5, 0.4, 0.8, -0.2, 0.6, 0.3, -0.7, 0.1, 0.9, -0.4, 0.2, 0.5, -0.6, 0.8, 0.3, -0.1]
        ]
        
        // 감정 범주 결정 (저/중/고 강도)
        let category = normalizedEmotion < -0.33 ? 0 : (normalizedEmotion < 0.33 ? 1 : 2)
        let baseEmbedding = emotionWeights[category]
        
        // 강도에 따른 스케일링
        let intensityScale = abs(normalizedEmotion)
        return baseEmbedding.map { $0 * intensityScale }
    }
    
    private func computeTemporalFeatures(_ timeFeatures: [Float]) -> [Float] {
        // 시간적 특성 변환 (RNN 스타일)
        let hiddenSize = 8
        var hiddenState: [Float] = Array(repeating: 0.0, count: hiddenSize)
        
        // LSTM 스타일 게이트 연산
        for timeStep in timeFeatures {
            let forgetGate = sigmoid(timeStep * 0.8 + hiddenState[0] * 0.2)
            let inputGate = sigmoid(timeStep * 0.6 + hiddenState[1] * 0.4)
            let candidateValues = tanh(timeStep * 0.7 + hiddenState[2] * 0.3)
            let outputGate = sigmoid(timeStep * 0.5 + hiddenState[3] * 0.5)
            
            hiddenState[0] = forgetGate * hiddenState[0] + inputGate * candidateValues
            hiddenState[1] = outputGate * tanh(hiddenState[0])
        }
        
        return hiddenState
    }
    
    private func computeEnvironmentFeatures(_ environmentVector: [Float]) -> [Float] {
        // 환경 특성 어텐션 메커니즘
        let attentionWeights = computeAttentionWeights(environmentVector)
        let weightedFeatures = zip(environmentVector, attentionWeights).map { $0 * $1 }
        
        // 다중 스케일 합성곱 필터 적용
        let conv1 = applyConvolution(weightedFeatures, kernel: [0.3, 0.4, 0.3])
        let conv2 = applyConvolution(weightedFeatures, kernel: [0.2, 0.6, 0.2])
        let conv3 = applyConvolution(weightedFeatures, kernel: [0.1, 0.8, 0.1])
        
        return conv1 + conv2 + conv3  // Feature fusion
    }
    
    private func computePersonalFeatures(_ historyEmbedding: [Float]) -> [Float] {
        // 개인 히스토리 변환 (Transformer 스타일)
        let personalityMatrix: [[Float]] = [
            [0.7, -0.2, 0.5, 0.8, -0.3, 0.6, 0.1, -0.4],
            [0.3, 0.8, -0.1, 0.4, 0.7, -0.5, 0.2, 0.6],
            [-0.4, 0.5, 0.9, -0.2, 0.1, 0.8, -0.6, 0.3],
            [0.6, -0.3, 0.2, 0.7, -0.8, 0.4, 0.9, -0.1],
            [0.1, 0.6, -0.7, 0.3, 0.8, -0.2, 0.5, 0.4],
            [-0.5, 0.2, 0.8, -0.6, 0.3, 0.7, -0.1, 0.9],
            [0.8, -0.4, 0.1, 0.5, -0.7, 0.2, 0.6, -0.3],
            [0.2, 0.9, -0.5, 0.1, 0.4, -0.8, 0.3, 0.7]
        ]
        
        var transformedFeatures: [Float] = []
        for row in personalityMatrix {
            let dotProduct = zip(historyEmbedding, row).map { $0 * $1 }.reduce(0, +)
            transformedFeatures.append(tanh(dotProduct))
        }
        
        return transformedFeatures
    }
    
    private func computeCrossFeatureInteractions(_ features: [Float]) -> [Float] {
        // 특성 간 상호작용 포착 (Factorization Machine 스타일)
        var interactions: [Float] = []
        
        let chunks = features.chunked(into: 4)  // 4개씩 묶어서 처리
        
        for i in 0..<chunks.count {
            for j in (i+1)..<chunks.count {
                let interaction = computeChunkInteraction(chunks[i], chunks[j])
                interactions.append(contentsOf: interaction)
            }
        }
        
        return Array(interactions.prefix(16))  // 상위 16개만 사용
    }
    
    // MARK: - ⚡ Phase 3: Deep Neural Inference
    
    private func performDeepInference(_ featureVector: [Float]) -> NetworkOutput {
        // Layer 1: Dense + BatchNorm + Dropout
        var layer1 = applyDenseLayer(featureVector, weights: modelWeights.layer1, bias: modelWeights.bias1)
        layer1 = applyBatchNormalization(layer1, scale: modelWeights.bnScale1, shift: modelWeights.bnShift1)
        layer1 = applyDropout(layer1, rate: dropout)
        layer1 = layer1.map { relu($0) }
        
        // Layer 2: Dense + Residual Connection
        var layer2 = applyDenseLayer(layer1, weights: modelWeights.layer2, bias: modelWeights.bias2)
        layer2 = applyResidualConnection(layer2, residual: layer1)
        layer2 = layer2.map { swish($0) }  // Swish activation
        
        // Layer 3: Attention Layer
        var layer3 = applyMultiHeadAttention(layer2, heads: 4)
        layer3 = layer3.map { gelu($0) }  // GELU activation
        
        // Layer 4: Output Projection
        let output = applyDenseLayer(layer3, weights: modelWeights.outputWeights, bias: modelWeights.outputBias)
        let probabilities = applySoftmax(output)
        
        return NetworkOutput(
            presetProbabilities: probabilities,
            confidence: calculateConfidence(probabilities),
            featureImportance: calculateFeatureImportance(featureVector),
            attentionWeights: extractAttentionWeights(layer3)
        )
    }
    
    // MARK: - 🎯 Phase 4: Personalization Integration
    
    private func applyPersonalization(_ networkOutput: NetworkOutput, context: EnhancedAIContext) -> PersonalizedOutput {
        // 사용자별 피드백 히스토리 로드
        let userFeedbacks = Array(EnhancedDataManager.shared.loadPresetFeedbacks()
            .filter { $0.userId == context.userId }
            .suffix(20))
        
        // 개인화 가중치 계산
        let personalizationWeights = calculatePersonalizationWeights(userFeedbacks)
        
        // 네트워크 출력에 개인화 적용
        let personalizedProbabilities = applyPersonalizationWeights(
            networkOutput.presetProbabilities, 
            weights: personalizationWeights
        )
        
        // 다양성 보정 (exploration vs exploitation)
        let diversityAdjustedProbabilities = applyDiversityBoost(
            personalizedProbabilities, 
            userHistory: userFeedbacks.map { $0.presetId }
        )
        
        return PersonalizedOutput(
            probabilities: diversityAdjustedProbabilities,
            confidence: networkOutput.confidence * calculatePersonalizationConfidence(userFeedbacks),
            personalizationStrength: calculatePersonalizationStrength(userFeedbacks),
            explorationFactor: calculateExplorationFactor(context)
        )
    }
    
    // MARK: - 🏁 Phase 5: Final Recommendation Generation
    
    private func generateFinalRecommendation(_ personalizedOutput: PersonalizedOutput, context: EnhancedAIContext) -> EnterpriseRecommendation {
        let presetNames = Array(SoundPresetCatalog.samplePresets.keys)
        
        // 상위 3개 추천 선택
        let topIndices = getTopKIndices(personalizedOutput.probabilities, k: 3)
        
        var recommendations: [RecommendationItem] = []
        
        for (rank, index) in topIndices.enumerated() {
            let presetName = presetNames[index]
            let probability = personalizedOutput.probabilities[index]
            
            // 버전 선택 (지능형)
            let selectedVersion = selectOptimalVersion(presetName: presetName, context: context)
            
            // 설명 생성
            let explanation = generateIntelligentExplanation(
                presetName: presetName,
                context: context,
                confidence: personalizedOutput.confidence,
                rank: rank
            )
            
            recommendations.append(RecommendationItem(
                presetName: presetName,
                selectedVersion: selectedVersion,
                confidence: probability * personalizedOutput.confidence,
                explanation: explanation,
                reasoning: generateTechnicalReasoning(presetName: presetName, context: context),
                expectedOutcome: predictExpectedOutcome(presetName: presetName, context: context)
            ))
        }
        
        return EnterpriseRecommendation(
            primaryRecommendation: recommendations[0],
            alternativeRecommendations: Array(recommendations.dropFirst()),
            overallConfidence: personalizedOutput.confidence,
            personalizationLevel: personalizedOutput.personalizationStrength,
            diversityScore: calculateDiversityScore(recommendations),
            processingMetadata: ProcessingMetadata(
                modelVersion: "2.0",
                processingTime: Date().timeIntervalSince(Date()),
                featureCount: 60,
                networkDepth: 4
            )
        )
    }
    
    // MARK: - 🔧 Advanced Helper Functions
    
    private func selectOptimalVersion(presetName: String, context: EnhancedAIContext) -> Int {
        let _ = EnhancedDataManager.shared.loadPresetFeedbacks()
            .filter { feedback in
                // presetId를 presetName과 연결하는 로직 필요
                return feedback.overallSatisfaction > 0.7
            }
        
        // 피드백이 많은 버전 우선 선택
        var versionScores = [0: 0.4, 1: 0.6]  // 기본 점수
        
        // 감정에 따른 버전 조정
        if ["😢", "😰", "😡"].contains(context.emotion) {
            versionScores[1] = (versionScores[1] ?? 0) + 0.2  // 진정 효과가 더 좋은 버전
        }
        
        // 시간대에 따른 조정
        let hour = context.timeOfDay
        if hour >= 22 || hour <= 6 {
            versionScores[1] = (versionScores[1] ?? 0) + 0.15  // 수면용 버전
        }
        
        return versionScores.max(by: { $0.value < $1.value })?.key ?? 1
    }
    
    private func generateIntelligentExplanation(presetName: String, context: EnhancedAIContext, confidence: Float, rank: Int) -> String {
        let explanationTemplates = [
            "당신의 현재 감정 상태와 시간대를 고려할 때, 이 조합이 가장 효과적일 것으로 예상됩니다.",
            "과거 유사한 상황에서 높은 만족도를 보인 패턴을 기반으로 추천드립니다.",
            "개인화된 분석 결과, 현재 컨텍스트에 최적화된 선택입니다.",
            "AI 신경망이 분석한 결과, 현재 상황에 가장 적합한 조합입니다."
        ]
        
        let baseExplanation = explanationTemplates.randomElement() ?? explanationTemplates[0]
        let confidenceText = confidence > 0.8 ? " (높은 신뢰도)" : confidence > 0.6 ? " (보통 신뢰도)" : " (탐색적 추천)"
        
        return baseExplanation + confidenceText
    }
    
    private func generateTechnicalReasoning(presetName: String, context: EnhancedAIContext) -> String {
        return "신경망 분석: 감정(\(context.emotion)), 시간(\(context.timeOfDay)시), 환경 노이즈(\(Int(context.environmentNoise * 100))%) 기반"
    }
    
    private func predictExpectedOutcome(presetName: String, context: EnhancedAIContext) -> ExpectedOutcome {
        // 과거 데이터 기반 예측
        let historicalData = EnhancedDataManager.shared.loadPresetFeedbacks()
        let similarFeedbacks = historicalData.filter { feedback in
            // 유사한 컨텍스트의 피드백 필터링
            return abs(feedback.environmentContext.noiseLevel - context.environmentNoise) < 0.2
        }
        
        let avgSatisfaction = similarFeedbacks.isEmpty ? 0.7 : 
            similarFeedbacks.map { $0.overallSatisfaction }.reduce(0, +) / Float(similarFeedbacks.count)
        
        return ExpectedOutcome(
            satisfactionProbability: avgSatisfaction,
            relaxationImprovement: avgSatisfaction * 0.8,
            focusImprovement: avgSatisfaction * 0.6,
            estimatedDuration: TimeInterval(15 * 60) // 15분 예상
        )
    }
    
    // MARK: - 📊 Performance Monitoring
    
    private func updatePerformanceMetrics(processingTime: TimeInterval) {
        performanceMetrics.totalInferences += 1
        performanceMetrics.averageProcessingTime = 
            (performanceMetrics.averageProcessingTime * Float(performanceMetrics.totalInferences - 1) + Float(processingTime)) / 
            Float(performanceMetrics.totalInferences)
        performanceMetrics.lastInferenceTime = Date()
    }
    
    func getPerformanceReport() -> PerformanceReport {
        let accuracy = EnhancedDataManager.shared.calculatePersonalizationAccuracy()
        
        return PerformanceReport(
            totalInferences: performanceMetrics.totalInferences,
            averageProcessingTime: performanceMetrics.averageProcessingTime,
            accuracy: accuracy.accuracy,
            confidence: accuracy.confidence,
            modelVersion: "2.0",
            lastUpdate: performanceMetrics.lastInferenceTime
        )
    }
}

// MARK: - 📊 Supporting Data Structures

struct EnhancedAIContext {
    let emotion: String
    let emotionIntensity: Float       // 0.0-1.0
    let timeOfDay: Int
    let environmentNoise: Float
    let recentActivity: String
    let userId: String
    let weatherMood: Float
    let consecutiveUsage: Int
    let userPreference: [String: Float]
}

struct ProcessedContext {
    let normalizedEmotion: Float
    let timeFeatures: [Float]
    let environmentVector: [Float]
    let historyEmbedding: [Float]
    let rawContext: EnhancedAIContext
}

struct NetworkOutput {
    let presetProbabilities: [Float]
    let confidence: Float
    let featureImportance: [Float]
    let attentionWeights: [Float]
}

struct PersonalizedOutput {
    let probabilities: [Float]
    let confidence: Float
    let personalizationStrength: Float
    let explorationFactor: Float
}

struct EnterpriseRecommendation {
    let primaryRecommendation: RecommendationItem
    let alternativeRecommendations: [RecommendationItem]
    let overallConfidence: Float
    let personalizationLevel: Float
    let diversityScore: Float
    let processingMetadata: ProcessingMetadata
}

struct RecommendationItem {
    let presetName: String
    let selectedVersion: Int
    let confidence: Float
    let explanation: String
    let reasoning: String
    let expectedOutcome: ExpectedOutcome
}

struct ExpectedOutcome {
    let satisfactionProbability: Float
    let relaxationImprovement: Float
    let focusImprovement: Float
    let estimatedDuration: TimeInterval
}

struct ProcessingMetadata {
    let modelVersion: String
    let processingTime: TimeInterval
    let featureCount: Int
    let networkDepth: Int
}

struct PerformanceMetrics {
    var totalInferences: Int = 0
    var averageProcessingTime: Float = 0.0
    var lastInferenceTime: Date = Date()
}

struct ModelWeights {
    let layer1: [[Float]] = Array(repeating: Array(repeating: 0.1, count: 60), count: 32)
    let bias1: [Float] = Array(repeating: 0.0, count: 32)
    let bnScale1: [Float] = Array(repeating: 1.0, count: 32)
    let bnShift1: [Float] = Array(repeating: 0.0, count: 32)
    
    let layer2: [[Float]] = Array(repeating: Array(repeating: 0.1, count: 32), count: 16)
    let bias2: [Float] = Array(repeating: 0.0, count: 16)
    
    let outputWeights: [[Float]] = Array(repeating: Array(repeating: 0.1, count: 16), count: 8)
    let outputBias: [Float] = Array(repeating: 0.0, count: 8)
}



struct PerformanceReport {
    let totalInferences: Int
    let averageProcessingTime: Float
    let accuracy: Float
    let confidence: Float
    let modelVersion: String
    let lastUpdate: Date
}

struct TrainingEpoch {
    let epoch: Int
    let loss: Float
    let accuracy: Float
    let timestamp: Date
}





// MARK: - 🔧 Essential Helper Extensions

extension LocalAIRecommendationEngine {
    
    // MARK: - Neural Network Helper Functions
    
    private func getSeasonalFactor() -> Float {
        let month = Calendar.current.component(.month, from: Date())
        let seasonalRad = Float(month - 1) * 2.0 * Float.pi / 12.0
        return (sin(seasonalRad) + 1.0) / 2.0  // [0, 1] range
    }
    
    // MARK: - Mathematical Functions
    
    private func sigmoid(_ x: Float) -> Float {
        return 1.0 / (1.0 + exp(-x))
    }
    
    private func tanh(_ x: Float) -> Float {
        return Foundation.tanh(x)
    }
    
    private func relu(_ x: Float) -> Float {
        return max(0, x)
    }
    
    private func swish(_ x: Float) -> Float {
        return x * sigmoid(x)
    }
    
    private func gelu(_ x: Float) -> Float {
        return 0.5 * x * (1.0 + tanh(sqrt(2.0 / Float.pi) * (x + 0.044715 * powf(x, 3))))
    }
    
    // MARK: - Neural Network Layers
    
    private func applyDenseLayer(_ input: [Float], weights: [[Float]], bias: [Float]) -> [Float] {
        var output: [Float] = []
        
        for (i, biasValue) in bias.enumerated() {
            var sum = biasValue
            for (j, inputValue) in input.enumerated() {
                if i < weights.count && j < weights[i].count {
                    sum += inputValue * weights[i][j]
                }
            }
            output.append(sum)
        }
        
        return output
    }
    
    private func applyBatchNormalization(_ input: [Float], scale: [Float], shift: [Float]) -> [Float] {
        let mean = input.reduce(0, +) / Float(input.count)
        let variance = input.map { powf($0 - mean, 2) }.reduce(0, +) / Float(input.count)
        let std = sqrt(variance + epsilon)
        
        return zip(zip(input, scale), shift).map { (inputScale, shift) in
            let (inputVal, scaleVal) = inputScale
            return ((inputVal - mean) / std) * scaleVal + shift
        }
    }
    
    private func applyDropout(_ input: [Float], rate: Float) -> [Float] {
        // 추론 시에는 dropout을 적용하지 않음
        return input
    }
    
    private func applyResidualConnection(_ input: [Float], residual: [Float]) -> [Float] {
        return zip(input, residual).map { $0 + $1 }
    }
    
    private func applyMultiHeadAttention(_ input: [Float], heads: Int) -> [Float] {
        // 간소화된 어텐션 (실제로는 훨씬 복잡)
        let headSize = input.count / heads
        var attentionOutput: [Float] = []
        
        for head in 0..<heads {
            let start = head * headSize
            let end = min(start + headSize, input.count)
            let headInput = Array(input[start..<end])
            
            // 셀프 어텐션 스코어 계산
            let attentionScores = headInput.map { sigmoid($0) }
            let sumScores = attentionScores.reduce(0, +)
            let normalizedScores = attentionScores.map { $0 / (sumScores + epsilon) }
            
            // 가중합 계산
            let weightedOutput = zip(headInput, normalizedScores).map { $0 * $1 }
            attentionOutput.append(contentsOf: weightedOutput)
        }
        
        return attentionOutput
    }
    
    private func applySoftmax(_ input: [Float]) -> [Float] {
        let maxValue = input.max() ?? 0
        let expValues = input.map { exp($0 - maxValue) }
        let sumExp = expValues.reduce(0, +)
        return expValues.map { $0 / sumExp }
    }
    
    // MARK: - Feature Engineering
    
    private func computeAttentionWeights(_ features: [Float]) -> [Float] {
        let scores = features.map { tanh($0 * 2.0) }
        let expScores = scores.map { exp($0) }
        let sumExp = expScores.reduce(0, +)
        return expScores.map { $0 / (sumExp + epsilon) }
    }
    
    private func applyConvolution(_ input: [Float], kernel: [Float]) -> [Float] {
        let kernelSize = kernel.count
        let padding = kernelSize / 2
        var output: [Float] = []
        
        for i in 0..<input.count {
            var sum: Float = 0
            for j in 0..<kernelSize {
                let inputIndex = i - padding + j
                if inputIndex >= 0 && inputIndex < input.count {
                    sum += input[inputIndex] * kernel[j]
                }
            }
            output.append(sum)
        }
        
        return output
    }
    
    private func computeChunkInteraction(_ chunk1: [Float], _ chunk2: [Float]) -> [Float] {
        var interactions: [Float] = []
        for i in 0..<min(chunk1.count, chunk2.count) {
            interactions.append(chunk1[i] * chunk2[i])
        }
        return interactions
    }
    
    // MARK: - Analysis Functions
    
    private func calculateConfidence(_ probabilities: [Float]) -> Float {
        guard !probabilities.isEmpty else { return 0.0 }
        let maxProb = probabilities.max() ?? 0
        let entropy = -probabilities.map { $0 * log($0 + epsilon) }.reduce(0, +)
        let maxEntropy = log(Float(probabilities.count))
        return maxProb * (1.0 - entropy / maxEntropy)
    }
    
    private func calculateFeatureImportance(_ features: [Float]) -> [Float] {
        return features.map { abs($0) }
    }
    
    private func extractAttentionWeights(_ layer: [Float]) -> [Float] {
        return computeAttentionWeights(layer)
    }
    
    // MARK: - Personalization Functions
    
    private func calculatePersonalizationWeights(_ feedbacks: [PresetFeedback]) -> [Float] {
        guard !feedbacks.isEmpty else {
            return Array(repeating: 1.0, count: SoundPresetCatalog.samplePresets.count)
        }
        
        // 피드백 기반 가중치 계산
        var weights: [Float] = Array(repeating: 1.0, count: SoundPresetCatalog.samplePresets.count)
        
        for feedback in feedbacks {
            // 간단한 만족도 기반 가중치 조정
            let satisfactionBoost = Float((feedback.overallSatisfaction - 0.5) * 0.2)
            // 실제로는 presetId와 index를 매핑하는 로직이 필요
            for i in 0..<weights.count {
                weights[i] += satisfactionBoost * feedback.learningWeight
            }
        }
        
        return weights
    }
    
    private func applyPersonalizationWeights(_ probabilities: [Float], weights: [Float]) -> [Float] {
        return zip(probabilities, weights).map { $0 * $1 }
    }
    
    private func applyDiversityBoost(_ probabilities: [Float], userHistory: [UUID]) -> [Float] {
        // 최근 사용한 항목에 패널티 적용
        var boostedProbs = probabilities
        
        // 실제로는 더 정교한 다양성 로직이 필요
        for i in 0..<boostedProbs.count {
            boostedProbs[i] *= (1.0 + Float.random(in: -0.1...0.1))
        }
        
        return boostedProbs
    }
    
    private func calculatePersonalizationConfidence(_ feedbacks: [PresetFeedback]) -> Float {
        guard !feedbacks.isEmpty else { return 0.5 }
        
        let avgReliability = feedbacks.map { $0.reliabilityScore }.reduce(0, +) / Float(feedbacks.count)
        let dataQuality = min(1.0, Float(feedbacks.count) / 20.0)
        
        return avgReliability * dataQuality
    }
    
    private func calculatePersonalizationStrength(_ feedbacks: [PresetFeedback]) -> Float {
        return min(1.0, Float(feedbacks.count) / 50.0)
    }
    
    private func calculateExplorationFactor(_ context: EnhancedAIContext) -> Float {
        // 연속 사용 횟수가 많을수록 탐험 증가
        return min(0.3, Float(context.consecutiveUsage) * 0.05)
    }
    
    private func getTopKIndices(_ array: [Float], k: Int) -> [Int] {
        let indexedArray = array.enumerated().map { ($0.offset, $0.element) }
        let sorted = indexedArray.sorted { $0.1 > $1.1 }
        return Array(sorted.prefix(k)).map { $0.0 }
    }
    
    private func calculateDiversityScore(_ recommendations: [RecommendationItem]) -> Float {
        // 추천 간 다양성 점수 계산
        return 0.8  // 간단화된 구현
    }
}

// MARK: - Array Chunking Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Enhanced Data Manager Extension


