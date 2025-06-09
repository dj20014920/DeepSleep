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
        var versions: [Int] = SoundPresetCatalog.defaultVersions
        var presetName = "🎵 AI 추천"
        
        for match in matches {
            guard match.numberOfRanges == 3 else { continue }
            
            let categoryRange = Range(match.range(at: 1), in: response)!
            let volumeRange = Range(match.range(at: 2), in: response)!
            
            let category = String(response[categoryRange])
            let volumeStr = String(response[volumeRange])
            
            guard let volume = Float(volumeStr) else { continue }
            
            if let index = SoundPresetCatalog.findCategoryIndex(by: category) {
                volumes[index] = min(100, max(0, volume))
            }
        }
        
        // 프리셋 이름 추출
        if let nameMatch = response.range(of: #""([^"]+)""#, options: .regularExpression) {
            presetName = String(response[nameMatch]).replacingOccurrences(of: "\"", with: "")
        }
        
        // AI가 추천한 볼륨에 따라 적절한 버전 선택
        versions = generateOptimalVersions(volumes: volumes)
        
        // 조합 필터링 적용
        let filteredVolumes = SoundPresetCatalog.applyCompatibilityFilter(to: volumes)
        
        return EnhancedRecommendationResponse(
            volumes: filteredVolumes,
            presetName: presetName,
            selectedVersions: versions
        )
    }
    
    // MARK: - 볼륨에 따른 최적 버전 선택
    private func generateOptimalVersions(volumes: [Float]) -> [Int] {
        var versions = SoundPresetCatalog.defaultVersions
        
        // 볼륨이 높은 카테고리에 더 적합한 버전 선택
        for (index, volume) in volumes.enumerated() {
            if SoundPresetCatalog.hasMultipleVersions(at: index) {
                switch index {
                case 1:  // 바람 - 볼륨 높으면 바람2 (더 강한 바람)
                    versions[index] = volume > 60 ? 1 : 0
                case 2:  // 밤 - 볼륨 높으면 밤2 (더 깊은 밤)
                    versions[index] = volume > 70 ? 1 : 0
                case 4:  // 비 - 볼륨 중간 이상이면 창문비 (더 부드러운)
                    versions[index] = volume > 50 ? 1 : 0
                case 9:  // 키보드 - 볼륨 높으면 키보드2 (더 리드미컬)
                    versions[index] = volume > 65 ? 1 : 0
                case 10: // 파도 - 볼륨 높으면 파도2 (더 강한 파도)
                    versions[index] = volume > 60 ? 1 : 0
                case 11: // 새 - 볼륨 높으면 새-비 (비와 새 조합)
                    versions[index] = volume > 55 ? 1 : 0
                case 12: // 발걸음-눈 - 볼륨 높으면 발걸음-눈2 (더 선명한 소리)
                    versions[index] = volume > 50 ? 1 : 0
                default:
                    break
                }
            }
        }
        
        return versions
    }
    
    // MARK: - 기존 12개 형식 파싱
    private func parseLegacyFormat(from response: String) -> EnhancedRecommendationResponse? {
        let legacyCategories = ["Rain", "Thunder", "Ocean", "Fire", "Steam", "WindowRain", "Forest", "Wind", "Night", "Lullaby", "Fan", "WhiteNoise"]
        let pattern = #"(\w+):(\d+)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let matches = regex?.matches(in: response, options: [], range: NSRange(location: 0, length: response.count)) ?? []
        
        if matches.count < 5 { return nil }
        
        var legacyVolumes: [Float] = Array(repeating: 0, count: 12)
        let presetName = "🎵 AI 추천 (레거시)"
        
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
        let convertedVolumes = legacyVolumes.count == 13 ? legacyVolumes : Array(repeating: 0.0, count: 13)
        let filteredVolumes = SoundPresetCatalog.applyCompatibilityFilter(to: convertedVolumes)
        
        return EnhancedRecommendationResponse(
            volumes: filteredVolumes,
            presetName: presetName,
            selectedVersions: SoundPresetCatalog.defaultVersions
        )
    }
    
    // MARK: - 감정별 기본 프리셋 (11개 카테고리)
    private func parseBasicFormat(from response: String) -> EnhancedRecommendationResponse? {
        let emotion = initialUserText ?? "😊"
        
        // 🌈 모든 프리셋에서 동등하게 선택 (우선순위 없음)
        // 감정과 시간대 기반으로 통합된 추천 시스템 사용
        let scientificRecommendation = getScientificRecommendationFor(emotion: emotion)
        if let scientificPreset = scientificRecommendation {
            return scientificPreset
        }
        
        // 만약 과학적 프리셋 선택에 실패한 경우 (거의 없음) 기본 프리셋 반환
        let volumes: [Float] = [30, 70, 60, 10, 80, 90, 0, 70, 50, 0, 70, 0, 0]
        return EnhancedRecommendationResponse(
            volumes: SoundPresetCatalog.applyCompatibilityFilter(to: volumes),
            presetName: "🌊 마음 달래는 소리",
            selectedVersions: generateOptimalVersions(volumes: volumes)
        )
    }
    
    // MARK: - 🧠 과학적 프리셋 추천 시스템
    
    /// 감정과 시간대를 기반으로 과학적 프리셋 추천
    private func getScientificRecommendationFor(emotion: String) -> EnhancedRecommendationResponse? {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let timeOfDay = getTimeOfDay(from: currentHour)
        
        // 감정과 시간대에 따른 추천 매핑
        let emotionMapping: [String: [String]] = [
            "😢": ["Emotional Healing", "Self Compassion", "Inner Peace", "Comfort Rain"],
            "😞": ["Forest Stress Relief", "Emotional Healing", "PTSD Grounding", "Comfort Rain"],
            "😔": ["Deep Ocean Cortisol Reset", "Emotional Healing", "Nature Stress Detox", "Comfort Rain"],
            "😰": ["Forest Stress Relief", "Rain Anxiety Calm", "Deep Ocean Cortisol Reset", "Stability Nature"],
            "😱": ["PTSD Grounding", "Forest Stress Relief", "Autism Sensory Calm", "Stability Nature"],
            "😨": ["Rain Anxiety Calm", "Deep Ocean Cortisol Reset", "Forest Stress Relief", "Stability Nature"],
            "😴": ["Sleep Onset Helper", "Delta Sleep Induction", "Night Preparation", "Deep Dream"],
            "😪": ["Sleep Onset Helper", "Theta Deep Relaxation", "REM Sleep Support", "Deep Dream"],
            "😊": ["Alpha Wave Mimic", "Creative Burst", "Morning Energy Boost", "Joyful Symphony"],
            "😄": ["Morning Energy Boost", "Social Energy", "Workout Motivation", "Joyful Symphony"],
            "🥰": ["Love & Connection", "Self Compassion", "Emotional Healing", "Joyful Symphony"],
            "😤": ["Deep Ocean Cortisol Reset", "Forest Stress Relief", "Rain Anxiety Calm", "Anger Release"],
            "😠": ["PTSD Grounding", "Deep Ocean Cortisol Reset", "Forest Stress Relief", "Anger Release"],
            "🤔": ["Deep Work Flow", "Problem Solving", "Brain Training", "Deep Focus"],
            "😌": ["Inner Peace", "Zen Garden Flow", "Mindfulness Bell", "Meditation Flow"],
            "🧘": ["Theta Deep Relaxation", "Zen Garden Flow", "Tibetan Bowl Substitute", "Meditation Flow"],
            "💪": ["Deep Work Flow", "Gamma Focus Simulation", "Morning Energy Boost", "Vitality Boost"],
            "🎯": ["Study Session", "Learning Optimization", "Information Processing", "Deep Focus"],
            "💡": ["Creative Burst", "Alpha Wave Mimic", "Neuroplasticity Boost", "Deep Focus"],
            "🌙": ["Delta Sleep Induction", "Night Preparation", "Sleep Onset Helper", "Night Ambience"],
            "🌅": ["Dawn Awakening", "Morning Energy Boost", "Midday Balance", "Vitality Boost"],
            "🌿": ["Forest Bathing", "Ocean Therapy", "Mountain Serenity", "Nature Symphony"],
            "🏥": ["Tinnitus Relief", "Autism Sensory Calm", "ADHD Focus Aid", "Calm Waters"]
        ]
        
        // 시간대 기반 후보군 선택
        let timeCandidates: [String]
        switch currentHour {
        case 5...7:
            timeCandidates = ["Dawn Awakening", "Morning Energy Boost", "Social Energy", "Vitality Boost"]
        case 8...11:
            timeCandidates = ["Deep Work Flow", "Study Session", "Creative Burst", "Deep Focus"]
        case 12...14:
            timeCandidates = ["Midday Balance", "Alpha Wave Mimic", "Problem Solving", "Deep Focus"]
        case 15...17:
            timeCandidates = ["Afternoon Revival", "Learning Optimization", "Brain Training", "Deep Focus"]
        case 18...21:
            timeCandidates = ["Sunset Transition", "Emotional Healing", "Inner Peace", "Meditation Flow"]
        case 22...23:
            timeCandidates = ["Night Preparation", "Sleep Onset Helper", "Theta Deep Relaxation", "Night Ambience"]
        case 0...4:
            timeCandidates = ["Delta Sleep Induction", "Deep Sleep Maintenance", "REM Sleep Support", "Deep Dream"]
        default:
            timeCandidates = ["Alpha Wave Mimic", "Inner Peace", "Deep Ocean Cortisol Reset", "Calm Waters"]
        }
        
        // 1. 감정 기반 후보군 선택
        let emotionCandidates = emotionMapping[emotion] ?? ["Deep Ocean Cortisol Reset", "Alpha Wave Mimic", "Inner Peace"]
        
        // 3. 교집합 또는 가중 선택
        let intersectionCandidates = Set(emotionCandidates).intersection(Set(timeCandidates))
        
        let finalPresetName: String
        if !intersectionCandidates.isEmpty {
            // 교집합이 있으면 그 중에서 선택
            finalPresetName = intersectionCandidates.randomElement() ?? emotionCandidates.first!
        } else {
            // 교집합이 없으면 감정 우선 선택 (70%) 또는 시간대 선택 (30%)
            if Float.random(in: 0...1) < 0.7 {
                finalPresetName = emotionCandidates.randomElement() ?? "Deep Ocean Cortisol Reset"
            } else {
                finalPresetName = timeCandidates.randomElement() ?? "Alpha Wave Mimic"
            }
        }
        
        // 4. 선택된 프리셋 반환
        guard let volumes = SoundPresetCatalog.scientificPresets[finalPresetName] else {
            return nil
        }
        
        let description = SoundPresetCatalog.scientificDescriptions[finalPresetName] ?? "과학적 연구 기반 음향 치료"
        let duration = SoundPresetCatalog.recommendedDurations[finalPresetName] ?? "20-30분"
        let timing = SoundPresetCatalog.optimalTimings[finalPresetName] ?? "언제든지"
        
        // 프리셋 이름을 한국어와 이모지로 변환
        let koreanName = convertToKoreanPresetName(finalPresetName)
        
        print("🧠 [getScientificRecommendationFor] 감정: \(emotion), 시간: \(timeOfDay)")
        print("  - 감정 후보: \(emotionCandidates)")
        print("  - 시간 후보: \(timeCandidates)")
        print("  - 최종 선택: \(finalPresetName)")
        print("  - 설명: \(description)")
        
        return EnhancedRecommendationResponse(
            volumes: volumes,
            presetName: koreanName,
            selectedVersions: generateOptimalVersions(volumes: volumes),
            scientificDescription: description,
            recommendedDuration: duration,
            optimalTiming: timing
        )
    }
    
    /// 시간대 문자열 반환
    private func getTimeOfDay(from hour: Int) -> String {
        switch hour {
        case 5..<8: return "새벽"
        case 8..<12: return "오전"
        case 12..<14: return "점심"
        case 14..<18: return "오후"
        case 18..<22: return "저녁"
        case 22..<24, 0..<5: return "밤"
        default: return "하루"
        }
    }
    
    /// 영어 프리셋 이름을 한국어로 변환
    private func convertToKoreanPresetName(_ englishName: String) -> String {
        let nameMapping: [String: String] = [
            "Deep Ocean Cortisol Reset": "🌊 깊은 바다 코르티솔 리셋",
            "Forest Stress Relief": "🌲 숲속 스트레스 완화",
            "Rain Anxiety Calm": "🌧️ 빗소리 불안 진정",
            "Nature Stress Detox": "🍃 자연 스트레스 해독",
            "Alpha Wave Mimic": "🧠 알파파 모방 집중",
            "Theta Deep Relaxation": "🌀 세타파 깊은 이완",
            "Delta Sleep Induction": "😴 델타파 수면 유도",
            "Gamma Focus Simulation": "⚡ 감마파 집중 시뮬레이션",
            "Sleep Onset Helper": "🌙 수면 시작 도우미",
            "Deep Sleep Maintenance": "💤 깊은 수면 유지",
            "REM Sleep Support": "👁️ 렘수면 지원",
            "Night Terror Calm": "🌃 야간 공포 진정",
            "Tibetan Bowl Substitute": "🎵 티베트 보울 대체",
            "Zen Garden Flow": "🧘 선 정원 흐름",
            "Mindfulness Bell": "🔔 마음챙김 종소리",
            "Walking Meditation": "🚶 걸으며 명상",
            "Deep Work Flow": "💻 몰입 작업 플로우",
            "Creative Burst": "💡 창의성 폭발",
            "Study Session": "📚 학습 세션",
            "Coding Focus": "⌨️ 코딩 집중",
            "Morning Energy Boost": "🌅 아침 에너지 부스터",
            "Afternoon Revival": "☀️ 오후 활력 회복",
            "Workout Motivation": "💪 운동 동기 부여",
            "Social Energy": "👥 사회적 에너지",
            "Dawn Awakening": "🌄 새벽 깨어남",
            "Midday Balance": "⚖️ 한낮 균형",
            "Sunset Transition": "🌅 석양 전환",
            "Night Preparation": "🌙 밤 준비",
            "Memory Enhancement": "🧠 기억력 향상",
            "Learning Optimization": "📖 학습 최적화",
            "Problem Solving": "🧩 문제 해결",
            "Information Processing": "🔍 정보 처리",
            "Emotional Healing": "💚 감정 치유",
            "Self Compassion": "🤗 자기 연민",
            "Love & Connection": "💕 사랑과 연결",
            "Inner Peace": "☮️ 내면의 평화",
            "Forest Bathing": "🌲 산림욕 (신린요쿠)",
            "Ocean Therapy": "🌊 바다 치료",
            "Mountain Serenity": "🏔️ 산의 고요함",
            "Desert Vastness": "🏜️ 사막의 광활함",
            "Neuroplasticity Boost": "🧠 신경가소성 부스터",
            "Brain Training": "🎯 뇌 훈련",
            "Mental Flexibility": "🤸 정신적 유연성",
            "Cognitive Reserve": "🧠 인지 예비능력",
            "Tinnitus Relief": "👂 이명 완화",
            "Autism Sensory Calm": "🧩 자폐 감각 진정",
            "ADHD Focus Aid": "🎯 ADHD 집중 보조",
            "PTSD Grounding": "🌍 PTSD 그라운딩",
            "Multi-sensory Harmony": "🌈 다감각 조화",
            "Synesthetic Experience": "🎨 공감각적 경험",
            "Temporal Perception": "⏰ 시간 지각",
            "Spatial Awareness": "📐 공간 인식",
            
            // 기존 감정별 프리셋 한국어 매핑 추가
            "Comfort Rain": "🌧️ 위로의 소리",
            "Stability Nature": "🌿 안정의 소리", 
            "Deep Dream": "🌙 깊은 잠의 소리",
            "Joyful Symphony": "🌈 기쁨의 소리",
            "Anger Release": "🔥 분노 해소의 소리",
            "Deep Focus": "🧠 집중의 소리",
            "Meditation Flow": "🕯️ 명상의 소리",
            "Vitality Boost": "⚡ 활력의 소리",
            "Night Ambience": "🌌 밤의 소리",
            "Nature Symphony": "🌳 자연의 소리",
            "Calm Waters": "🌊 마음 달래는 소리"
        ]
        
        return nameMapping[englishName] ?? "🎵 \(englishName)"
    }
}
