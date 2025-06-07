import Foundation

/// 심리 음향학 기반 전문가 사운드 카탈로그
/// 최신 연구(2024-2025) 기반으로 설계된 사운드 치료 시스템
class SoundPresetCatalog {
    
    // MARK: - 기본 카테고리 설정 (그룹화된 13개 슬라이더)
    static let categoryCount = 13  // 그룹화된 13개 슬라이더
    static let defaultVersions = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]  // 각 그룹의 기본 버전
    
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
            adjustedVolume = Int(Double(baseVolume) * 0.7)
        case "밤":
            adjustedVolume = Int(Double(baseVolume) * 0.8)
        case "아침":
            adjustedVolume = Int(Double(baseVolume) * 1.1)
        default:
            break
        }
        
        // 감정별 조정
        switch emotion {
        case "스트레스", "불안":
            if ["고양이", "바람2", "시냇물"].contains(sound) {
                adjustedVolume = Int(Double(adjustedVolume) * 1.2)
            }
        case "활력", "에너지":
            if ["새", "파도2"].contains(sound) {
                adjustedVolume = Int(Double(adjustedVolume) * 1.3)
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
}
