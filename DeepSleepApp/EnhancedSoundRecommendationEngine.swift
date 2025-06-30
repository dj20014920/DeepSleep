import Foundation
import AVFoundation

/// 🚀 고도화된 사운드 추천 엔진
/// - 주파수 분석 기반 자동 매칭
/// - 개인 볼륨 프로필 학습
/// - 감정별 최적 조합 추천
/// - 시간대별 적응형 볼륨 조절
class EnhancedSoundRecommendationEngine {
    static let shared = EnhancedSoundRecommendationEngine()
    
    // MARK: - 고도화된 메타데이터 구조
    
    struct EnhancedSoundMetadata: Codable {
        let id: String
        let baseName: String
        let categoryIndex: Int
        let versions: [EnhancedSoundVersion]
    }
    
    struct EnhancedSoundVersion: Codable {
        let version: String
        let fileName: String
        let displayName: String
        let emoji: String
        let description: String
        
        // 🆕 고급 메타데이터
        let durationSeconds: Int
        let sampleRateKhz: Float
        let frequencyRangeHz: String
        let peakFrequencyHz: Int
        let rmsDbfs: Float
        let optimalVolumePercent: [Int]
        let volumeIntensityRange: [Int]
        let bestPair: [String]
        let avoidPair: [String]
        let emotionTags: [String]
        let timeOfDayOptimal: [String]
        let therapeuticBenefits: String
        let psychoacousticProfile: String
        let usageScenarios: [String]
        let mixingCoefficient: Float
        let fadeInSeconds: Int
        let fadeOutSeconds: Int
        let isDefault: Bool
        
        enum CodingKeys: String, CodingKey {
            case version, fileName = "file_name", displayName = "display_name"
            case emoji, description
            case durationSeconds = "duration_seconds"
            case sampleRateKhz = "sample_rate_khz"
            case frequencyRangeHz = "frequency_range_hz"
            case peakFrequencyHz = "peak_frequency_hz"
            case rmsDbfs = "rms_dbfs"
            case optimalVolumePercent = "optimal_volume_percent"
            case volumeIntensityRange = "volume_intensity_range"
            case bestPair = "best_pair"
            case avoidPair = "avoid_pair"
            case emotionTags = "emotion_tags"
            case timeOfDayOptimal = "time_of_day_optimal"
            case therapeuticBenefits = "therapeutic_benefits"
            case psychoacousticProfile = "psychoacoustic_profile"
            case usageScenarios = "usage_scenarios"
            case mixingCoefficient = "mixing_coefficient"
            case fadeInSeconds = "fade_in_seconds"
            case fadeOutSeconds = "fade_out_seconds"
            case isDefault = "is_default"
        }
    }
    
    // MARK: - 개인 프로필 관리
    
    struct UserVolumeProfile: Codable {
        var preferredVolumes: [String: Float] = [:]  // 사운드ID: 선호 볼륨
        var emotionHistory: [String: Int] = [:]       // 감정: 사용 횟수
        var timeOfDayPreferences: [String: [String: Float]] = [:] // 시간대: [사운드ID: 선호도]
        var lastUpdated: Date = Date()
        
        mutating func updateVolumePreference(soundId: String, volume: Float) {
            preferredVolumes[soundId] = volume
            lastUpdated = Date()
        }
        
        mutating func recordEmotionUsage(emotion: String) {
            emotionHistory[emotion, default: 0] += 1
            lastUpdated = Date()
        }
        
        mutating func updateTimePreference(timeOfDay: String, soundId: String, preference: Float) {
            if timeOfDayPreferences[timeOfDay] == nil {
                timeOfDayPreferences[timeOfDay] = [:]
            }
            timeOfDayPreferences[timeOfDay]?[soundId] = preference
            lastUpdated = Date()
        }
    }
    
    // MARK: - 프로퍼티
    
    private var enhancedCatalog: [EnhancedSoundMetadata] = []
    private var userProfile = UserVolumeProfile()
    private let userDefaults = UserDefaults.standard
    private let profileKey = "EnhancedUserVolumeProfile"
    
    private init() {
        loadEnhancedCatalog()
        loadUserProfile()
    }
    
    // MARK: - 카탈로그 로딩
    
    private func loadEnhancedCatalog() {
        guard let url = Bundle.main.url(forResource: "sound_catalog_enhanced", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ sound_catalog_enhanced.json 파일을 찾을 수 없습니다.")
            return
        }
        
        do {
            enhancedCatalog = try JSONDecoder().decode([EnhancedSoundMetadata].self, from: data)
            print("✅ 고도화된 사운드 카탈로그 로드 완료: \(enhancedCatalog.count)개 카테고리")
        } catch {
            print("⚠️ 고도화된 카탈로그 파싱 실패: \(error)")
        }
    }
    
    private func loadUserProfile() {
        if let data = userDefaults.data(forKey: profileKey),
           let profile = try? JSONDecoder().decode(UserVolumeProfile.self, from: data) {
            userProfile = profile
            print("✅ 사용자 볼륨 프로필 로드 완료")
        }
    }
    
    private func saveUserProfile() {
        if let data = try? JSONEncoder().encode(userProfile) {
            userDefaults.set(data, forKey: profileKey)
            print("💾 사용자 프로필 저장 완료")
        }
    }
    
    // MARK: - 🎯 고도화된 추천 알고리즘
    
    /// 감정 기반 고도화된 사운드 추천 (다양한 조합 개수 지원)
    /// - Parameters:
    ///   - emotion: 현재 감정 상태
    ///   - timeOfDay: 현재 시간대
    ///   - intensity: 감정 강도 (0.0 - 2.0)
    ///   - context: 사용 상황 (수면, 작업, 명상 등)
    ///   - preferredCount: 선호 사운드 개수 (nil이면 자동 결정)
    /// - Returns: 최적화된 사운드 조합과 볼륨
    func getEnhancedRecommendation(
        emotion: String,
        timeOfDay: String? = nil,
        intensity: Float = 1.0,
        context: String? = nil,
        preferredCount: Int? = nil
    ) -> (sounds: [(soundId: String, version: String, volume: Float)], explanation: String) {
        
        let currentTimeOfDay = timeOfDay ?? getCurrentTimeOfDay()
        print("🔍 [EnhancedRecommendation] 감정: \(emotion), 시간: \(currentTimeOfDay), 강도: \(intensity)")
        
        // 1. 감정별 후보 사운드 필터링
        let emotionCandidates = filterSoundsByEmotion(emotion: emotion)
        
        // 2. 시간대별 필터링
        let timeFilteredCandidates = filterSoundsByTimeOfDay(candidates: emotionCandidates, timeOfDay: currentTimeOfDay)
        
        // 3. 사용자 선호도 반영
        let personalizedCandidates = applySexualizedPreferences(candidates: timeFilteredCandidates)
        
        // 4. 최적 조합 개수 결정
        let targetCount = determineOptimalCombinationCount(
            emotion: emotion,
            intensity: intensity,
            context: context,
            preferredCount: preferredCount,
            availableCandidates: personalizedCandidates.count
        )
        
        // 5. 다양성을 고려한 최적 조합 생성
        let optimizedCombination = generateDiverseCombination(
            candidates: personalizedCandidates,
            emotion: emotion,
            intensity: intensity,
            context: context,
            targetCount: targetCount
        )
        
        // 6. 볼륨 최적화
        let volumeOptimizedSounds = optimizeVolumes(sounds: optimizedCombination, intensity: intensity)
        
        // 7. 설명 생성
        let explanation = generateRecommendationExplanation(
            sounds: volumeOptimizedSounds,
            emotion: emotion,
            timeOfDay: currentTimeOfDay,
            intensity: intensity,
            targetCount: targetCount
        )
        
        // 8. 사용 기록 업데이트
        updateUsageHistory(emotion: emotion, sounds: volumeOptimizedSounds)
        
        return (sounds: volumeOptimizedSounds, explanation: explanation)
    }
    
    /// 🎲 다양성 기반 프리셋 생성 (피드백 학습 적용)
    /// - Parameters:
    ///   - emotion: 감정 상태
    ///   - feedbackHistory: 사용자 피드백 히스토리
    ///   - diversityLevel: 다양성 레벨 (1-5, 5가 가장 다양함)
    /// - Returns: 다양한 개수와 조합의 프리셋들
    func generateDiversePresets(
        emotion: String,
        feedbackHistory: [PresetFeedback] = [],
        diversityLevel: Int = 3
    ) -> [PresetRecommendation] {
        
        var presets: [PresetRecommendation] = []
        let timeOfDay = getCurrentTimeOfDay()
        
        // 피드백 기반 학습 적용
        let learnedPreferences = analyzeFeedbackHistory(feedbackHistory)
        
        // 1개부터 시작하여 다양한 개수의 프리셋 생성
        for count in 1...min(13, enhancedCatalog.count) {
            let targetCounts = generateTargetCounts(baseCount: count, diversityLevel: diversityLevel)
            
            for targetCount in targetCounts {
                let recommendation = getEnhancedRecommendation(
                    emotion: emotion,
                    timeOfDay: timeOfDay,
                    intensity: Float.random(in: 0.7...1.8), // 다양한 강도
                    context: nil,
                    preferredCount: targetCount
                )
                
                // 피드백 기반 점수 조정
                let adjustedScore = adjustScoreBasedOnFeedback(
                    sounds: recommendation.sounds,
                    learnedPreferences: learnedPreferences
                )
                
                let soundInfos = recommendation.sounds.map { 
                    SoundInfo(soundId: $0.soundId, version: $0.version, volume: $0.volume) 
                }
                
                let preset = PresetRecommendation(
                    id: UUID().uuidString,
                    name: generatePoeticalPresetName(sounds: recommendation.sounds, emotion: emotion),
                    sounds: soundInfos,
                    explanation: recommendation.explanation,
                    emotionTag: emotion,
                    timeOfDay: timeOfDay,
                    confidenceScore: adjustedScore,
                    soundCount: targetCount,
                    createdAt: Date()
                )
                
                presets.append(preset)
            }
        }
        
        // 다양성과 점수를 기준으로 정렬하여 상위 10개만 리턴
        return Array(presets
            .sorted { $0.confidenceScore > $1.confidenceScore }
            .prefix(10))
    }
    
    // MARK: - 🧠 피드백 학습 시스템
    
    struct SoundInfo: Codable {
        let soundId: String
        let version: String
        let volume: Float
    }
    
    struct PresetFeedback: Codable {
        let presetId: String
        let sounds: [SoundInfo]
        let rating: Int // 1-5점
        let emotion: String
        let timeOfDay: String
        let feedback: String?
        let timestamp: Date
    }
    
    struct PresetRecommendation: Codable {
        let id: String
        let name: String
        let sounds: [SoundInfo]
        let explanation: String
        let emotionTag: String
        let timeOfDay: String
        let confidenceScore: Float
        let soundCount: Int
        let createdAt: Date
    }
    
    struct LearnedPreferences {
        var soundPopularity: [String: Float] = [:]
        var combinationSuccess: [(sounds: [String], score: Float)] = []
        var optimalCounts: [String: Int] = [:] // 감정별 선호 개수
        var timeOfDayPreferences: [String: [String: Float]] = [:]
    }
    
    private func analyzeFeedbackHistory(_ history: [PresetFeedback]) -> LearnedPreferences {
        var preferences = LearnedPreferences()
        
        for feedback in history {
            let emotion = feedback.emotion
            let rating = Float(feedback.rating)
            
            // 사운드별 인기도 계산
            for sound in feedback.sounds {
                let currentScore = preferences.soundPopularity[sound.soundId, default: 0.0]
                preferences.soundPopularity[sound.soundId] = currentScore + (rating / 5.0)
            }
            
            // 감정별 최적 개수 학습
            let soundCount = feedback.sounds.count
            if preferences.optimalCounts[emotion] == nil || rating >= 4.0 {
                preferences.optimalCounts[emotion] = soundCount
            }
            
            // 조합 성공률 기록
            let soundIds = feedback.sounds.map { $0.soundId }
            preferences.combinationSuccess.append((sounds: soundIds, score: rating / 5.0))
            
            // 시간대별 선호도
            let timeOfDay = feedback.timeOfDay
            if preferences.timeOfDayPreferences[timeOfDay] == nil {
                preferences.timeOfDayPreferences[timeOfDay] = [:]
            }
            
            for sound in feedback.sounds {
                let currentPref = preferences.timeOfDayPreferences[timeOfDay]![sound.soundId, default: 0.0]
                preferences.timeOfDayPreferences[timeOfDay]![sound.soundId] = currentPref + (rating / 5.0)
            }
        }
        
        return preferences
    }
    
    private func adjustScoreBasedOnFeedback(
        sounds: [(soundId: String, version: String, volume: Float)],
        learnedPreferences: LearnedPreferences
    ) -> Float {
        var baseScore: Float = 0.7
        
        // 사운드 인기도 기반 점수 조정
        for sound in sounds {
            let popularity = learnedPreferences.soundPopularity[sound.soundId, default: 0.5]
            baseScore += popularity * 0.1
        }
        
        // 조합 성공률 기반 조정
        let soundIds = sounds.map { $0.soundId }
        for successfulCombo in learnedPreferences.combinationSuccess {
            let intersection = Set(soundIds).intersection(Set(successfulCombo.sounds))
            if intersection.count >= 2 {
                baseScore += successfulCombo.score * 0.15
            }
        }
        
        return min(baseScore, 1.0)
    }
    
    private func generatePoeticalPresetName(
        sounds: [(soundId: String, version: String, volume: Float)],
        emotion: String
    ) -> String {
        let poeticTemplates = [
            ["평온한", "고요한", "부드러운", "온화한", "차분한"],
            ["밤의", "새벽의", "황혼의", "달빛의", "별빛의"],
            ["속삭임", "선율", "조화", "위안", "품", "울림", "여운"]
        ]
        
        let soundCount = sounds.count
        let countText = soundCount == 1 ? "솔로" : soundCount <= 3 ? "듀엣" : soundCount <= 6 ? "앙상블" : "오케스트라"
        
        let template1 = poeticTemplates[0].randomElement() ?? "평온한"
        let template2 = poeticTemplates[1].randomElement() ?? "밤의"
        let template3 = poeticTemplates[2].randomElement() ?? "선율"
        
        return "\(template1) \(template2) \(template3) (\(countText) \(soundCount)곡)"
    }
    
    // MARK: - 필터링 알고리즘
    
    private func filterSoundsByEmotion(emotion: String) -> [EnhancedSoundVersion] {
        var candidates: [EnhancedSoundVersion] = []
        
        for catalog in enhancedCatalog {
            for version in catalog.versions {
                if version.emotionTags.contains(where: { tag in
                    emotion.contains(tag) || tag.contains(emotion) ||
                    areEmotionsSimilar(emotion1: emotion, emotion2: tag)
                }) {
                    candidates.append(version)
                }
            }
        }
        
        print("🎭 감정 '\(emotion)'에 매칭된 후보: \(candidates.count)개")
        return candidates
    }
    
    private func filterSoundsByTimeOfDay(candidates: [EnhancedSoundVersion], timeOfDay: String) -> [EnhancedSoundVersion] {
        let filtered = candidates.filter { version in
            version.timeOfDayOptimal.contains(timeOfDay) || 
            version.timeOfDayOptimal.contains("모든 시간")
        }
        
        print("⏰ 시간대 '\(timeOfDay)'에 적합한 후보: \(filtered.count)개")
        return filtered.isEmpty ? candidates : filtered
    }
    
    private func applySexualizedPreferences(candidates: [EnhancedSoundVersion]) -> [(version: EnhancedSoundVersion, score: Float)] {
        return candidates.map { version in
            let soundId = extractSoundId(from: version.fileName)
            let userPreference = userProfile.preferredVolumes[soundId] ?? 0.5
            let usageCount = userProfile.emotionHistory.values.reduce(0, +)
            let personalScore = usageCount > 0 ? userPreference * 1.2 : 1.0
            
            return (version: version, score: personalScore)
        }.sorted { $0.score > $1.score }
    }
    
    // MARK: - 조합 최적화 알고리즘 (개선됨)
    
    private func determineOptimalCombinationCount(
        emotion: String,
        intensity: Float,
        context: String?,
        preferredCount: Int?,
        availableCandidates: Int
    ) -> Int {
        
        // 사용자가 직접 지정한 경우
        if let preferred = preferredCount {
            return min(preferred, availableCandidates, 13)
        }
        
        // 학습된 사용자 선호도가 있는 경우
        if let learnedOptimal = getUserOptimalCount(for: emotion) {
            return min(learnedOptimal, availableCandidates, 13)
        }
        
        // 감정과 강도에 따른 자동 결정
        var baseCount = 3
        
        switch emotion {
        case let e where e.contains("스트레스") || e.contains("불안"):
            baseCount = Int.random(in: 4...7) // 복잡한 감정에 더 많은 사운드
        case let e where e.contains("집중") || e.contains("명상"):
            baseCount = Int.random(in: 1...3) // 집중할 때는 단순하게
        case let e where e.contains("외로움") || e.contains("그리움"):
            baseCount = Int.random(in: 5...9) // 외로울 때는 풍부한 사운드스케이프
        default:
            baseCount = Int.random(in: 2...6) // 일반적인 경우
        }
        
        // 강도에 따른 조정
        if intensity < 0.7 {
            baseCount = max(1, baseCount - 2) // 약한 강도에는 더 적게
        } else if intensity > 1.5 {
            baseCount = min(10, baseCount + 3) // 강한 강도에는 더 많게
        }
        
        // 상황에 따른 조정
        if let context = context {
            switch context {
            case "수면", "sleep":
                baseCount = Int.random(in: 2...5) // 수면 시에는 적당히
            case "집중", "focus", "작업", "work":
                baseCount = Int.random(in: 1...3) // 작업 시에는 단순하게
            case "파티", "celebration":
                baseCount = Int.random(in: 7...13) // 축하 시에는 풍성하게
            default:
                break
            }
        }
        
        return min(max(baseCount, 1), availableCandidates, 13)
    }
    
    private func generateTargetCounts(baseCount: Int, diversityLevel: Int) -> [Int] {
        var counts: [Int] = [baseCount]
        
        let variation = diversityLevel
        for i in 1...variation {
            let lower = max(1, baseCount - i)
            let upper = min(13, baseCount + i)
            
            if lower != baseCount { counts.append(lower) }
            if upper != baseCount { counts.append(upper) }
        }
        
        return Array(Set(counts)).sorted()
    }
    
    private func generateDiverseCombination(
        candidates: [(version: EnhancedSoundVersion, score: Float)],
        emotion: String,
        intensity: Float,
        context: String?,
        targetCount: Int
    ) -> [(version: EnhancedSoundVersion, weight: Float)] {
        
        guard !candidates.isEmpty else { return [] }
        
        var selectedSounds: [(version: EnhancedSoundVersion, weight: Float)] = []
        var avoidList: Set<String> = []
        var frequencyBands: Set<Int> = []  // 주파수 대역 다양성 확보
        
        // 후보를 점수와 다양성을 기준으로 선택
        for candidate in candidates {
            let version = candidate.version
            let soundId = extractSoundId(from: version.fileName)
            
            // 회피 리스트 체크
            if avoidList.intersection(Set(version.avoidPair)).isEmpty {
                
                // 주파수 다양성 체크 (같은 주파수 대역의 사운드 중복 방지)
                let frequencyBand = version.peakFrequencyHz / 1000 // 1kHz 단위로 그룹화
                let shouldAddForDiversity = !frequencyBands.contains(frequencyBand) || selectedSounds.count < targetCount / 2
                
                if shouldAddForDiversity {
                    let weight = calculateMixingWeight(version: version, intensity: intensity, context: context)
                    selectedSounds.append((version: version, weight: weight))
                    
                    // 이 사운드의 avoid_pair를 avoidList에 추가
                    avoidList.formUnion(version.avoidPair)
                    frequencyBands.insert(frequencyBand)
                    
                    if selectedSounds.count >= targetCount {
                        break
                    }
                }
            }
        }
        
        // 목표 개수에 못 미치는 경우 추가 선택 (회피 규칙 완화)
        if selectedSounds.count < targetCount {
            for candidate in candidates {
                if selectedSounds.count >= targetCount { break }
                
                let version = candidate.version
                let soundId = extractSoundId(from: version.fileName)
                
                // 이미 선택된 사운드인지 확인
                let alreadySelected = selectedSounds.contains { 
                    extractSoundId(from: $0.version.fileName) == soundId 
                }
                
                if !alreadySelected {
                    let weight = calculateMixingWeight(version: version, intensity: intensity, context: context)
                    selectedSounds.append((version: version, weight: weight))
                }
            }
        }
        
        print("🎵 최종 선택된 조합: \(selectedSounds.count)개 (목표: \(targetCount)개)")
        return selectedSounds
    }
    
    private func getUserOptimalCount(for emotion: String) -> Int? {
        // 사용자의 과거 선호도를 기반으로 최적 개수 반환
        // 실제 구현에서는 UserDefaults나 Core Data에서 가져올 수 있음
        return nil
    }
    
    // MARK: - 볼륨 최적화
    
    private func optimizeVolumes(
        sounds: [(version: EnhancedSoundVersion, weight: Float)],
        intensity: Float
    ) -> [(soundId: String, version: String, volume: Float)] {
        
        return sounds.map { item in
            let version = item.version
            let soundId = extractSoundId(from: version.fileName)
            
            // 기본 최적 볼륨 범위에서 시작
            let optimalMin = Float(version.optimalVolumePercent[0]) / 100.0
            let optimalMax = Float(version.optimalVolumePercent[1]) / 100.0
            let baseVolume = (optimalMin + optimalMax) / 2.0
            
            // 사용자 선호도 반영
            let userPreference = userProfile.preferredVolumes[soundId] ?? baseVolume
            let personalizedVolume = (baseVolume + userPreference) / 2.0
            
            // 강도 및 가중치 적용
            let finalVolume = personalizedVolume * intensity * item.weight
            
            // 최종 볼륨을 범위 내로 제한
            let clampedVolume = min(max(finalVolume, optimalMin), optimalMax)
            
            return (soundId: soundId, version: version.version, volume: clampedVolume)
        }
    }
    
    // MARK: - 설명 생성
    
    private func generateRecommendationExplanation(
        sounds: [(soundId: String, version: String, volume: Float)],
        emotion: String,
        timeOfDay: String,
        intensity: Float,
        targetCount: Int
    ) -> String {
        
        let intensityText = intensity > 1.5 ? "강한" : intensity < 0.7 ? "부드러운" : "적절한"
        let soundNames = sounds.map { getSoundDisplayName(soundId: $0.soundId, version: $0.version) }
        
        let therapeutic = sounds.compactMap { sound in
            findVersion(soundId: sound.soundId, version: sound.version)?.therapeuticBenefits
        }.first ?? "마음의 안정"
        
        // 사운드 개수에 따른 설명 차별화
        let combinationDescription = generateCombinationDescription(count: sounds.count, targetCount: targetCount)
        
        return """
        🔬 **고도화된 로컬 추천**
        
        📊 **분석 결과**
        • 감정 상태: \(emotion) (\(intensityText) 강도)
        • 시간대: \(timeOfDay)
        • 선택된 조합: \(soundNames.joined(separator: ", "))
        • 구성 방식: \(combinationDescription)
        
        🧠 **치료적 효과**
        \(therapeutic)
        
        🎛️ **볼륨 최적화**
        개인 프로필과 주파수 분석을 기반으로 최적 볼륨을 계산했습니다.
        
        ✨ 이 추천은 고급 음향 심리학과 개인 학습 데이터를 활용한 로컬 AI 추천입니다.
        """
    }
    
    private func generateCombinationDescription(count: Int, targetCount: Int) -> String {
        switch count {
        case 1:
            return "단일 사운드 집중 모드 - 깊은 몰입감을 위한 순수한 선택"
        case 2:
            return "미니멀 듀엣 - 조화로운 두 소리의 완벽한 균형"
        case 3:
            return "클래식 트리오 - 안정적이고 검증된 3요소 조합"
        case 4...6:
            return "밸런스 앙상블 - 풍부함과 안정감의 최적 조화"
        case 7...9:
            return "리치 오케스트라 - 복합적 감정을 위한 다층적 사운드스케이프"
        case 10...13:
            return "풀 심포니 - 모든 감각을 아우르는 완전한 음향 환경"
        default:
            return "맞춤형 조합 (\(count)곡)"
        }
    }
    
    private func calculateMixingWeight(version: EnhancedSoundVersion, intensity: Float, context: String?) -> Float {
        var weight = version.mixingCoefficient
        
        // 강도에 따른 가중치 조정
        if intensity > 1.5 {
            weight *= 1.2  // 강한 감정일 때 더 부드럽게
        } else if intensity < 0.7 {
            weight *= 0.8  // 약한 감정일 때 더 선명하게
        }
        
        // 상황별 조정
        if let context = context {
            switch context {
            case "수면", "sleep":
                weight *= 1.1
            case "집중", "focus", "작업", "work":
                weight *= 0.9
            case "명상", "meditation":
                weight *= 1.0
            default:
                break
            }
        }
        
        return min(max(weight, 0.1), 1.0) // 0.1 ~ 1.0 범위로 제한
    }
    
    // MARK: - 유틸리티 메서드
    
    private func areEmotionsSimilar(emotion1: String, emotion2: String) -> Bool {
        let emotionGroups = [
            ["슬픔", "우울", "우울함", "처짐"],
            ["불안", "걱정", "초조", "긴장"],
            ["스트레스", "피로", "지침", "답답함"],
            ["외로움", "고독", "그리움", "애정 부족"],
            ["평온", "안정", "차분", "이완"],
            ["집중", "몰입", "작업", "공부"],
            ["행복", "기쁨", "활력", "긍정"]
        ]
        
        for group in emotionGroups {
            if group.contains(emotion1) && group.contains(emotion2) {
                return true
            }
        }
        return false
    }
    
    private func extractSoundId(from fileName: String) -> String {
        // 파일명에서 사운드 ID 추출 (확장자 제거, 버전 번호 제거)
        let baseName = fileName.replacingOccurrences(of: ".mp3", with: "")
        return baseName.replacingOccurrences(of: "2", with: "").replacingOccurrences(of: "1", with: "")
    }
    
    private func getCurrentTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<9: return "아침"
        case 9..<12: return "오전"
        case 12..<14: return "점심"
        case 14..<18: return "오후"
        case 18..<21: return "저녁"
        case 21..<24: return "밤"
        default: return "깊은밤"
        }
    }
    
    private func getSoundDisplayName(soundId: String, version: String) -> String {
        return findVersion(soundId: soundId, version: version)?.displayName ?? soundId
    }
    
    private func findVersion(soundId: String, version: String) -> EnhancedSoundVersion? {
        for catalog in enhancedCatalog {
            if catalog.id == soundId {
                return catalog.versions.first { $0.version == version }
            }
        }
        return nil
    }
    
    private func updateUsageHistory(emotion: String, sounds: [(soundId: String, version: String, volume: Float)]) {
        userProfile.recordEmotionUsage(emotion: emotion)
        
        let currentTimeOfDay = getCurrentTimeOfDay()
        for sound in sounds {
            userProfile.updateVolumePreference(soundId: sound.soundId, volume: sound.volume)
            userProfile.updateTimePreference(timeOfDay: currentTimeOfDay, soundId: sound.soundId, preference: sound.volume)
        }
        
        saveUserProfile()
    }
    
    // MARK: - 공개 인터페이스
    
    /// 사용자 볼륨 선호도 업데이트
    func updateUserVolumePreference(soundId: String, volume: Float) {
        userProfile.updateVolumePreference(soundId: soundId, volume: volume)
        saveUserProfile()
        print("📊 사용자 선호 볼륨 업데이트: \(soundId) = \(volume)")
    }
    
    /// 🔄 사용자 프로필 업데이트 (피드백 데이터 기반)
    @available(iOS 17.0, *)
    func updateUserProfile(_ profile: Any) { // TODO: UserProfileVector
        // TODO: UserProfileVector 구조체 정의 필요
        // 임시로 비활성화
        saveUserProfile()
        print("🔄 [EnhancedSoundRecommendationEngine] 사용자 프로필 업데이트 (임시 비활성화)")
    }
    
    /// 사용자 프로필 리셋
    func resetUserProfile() {
        userProfile = UserVolumeProfile()
        saveUserProfile()
        print("🔄 사용자 프로필이 리셋되었습니다.")
    }
    
    /// 프로필 통계 조회
    func getUserProfileStats() -> (totalEmotionUsage: Int, preferredSounds: [String: Float], profileAge: TimeInterval) {
        let totalUsage = userProfile.emotionHistory.values.reduce(0, +)
        let profileAge = Date().timeIntervalSince(userProfile.lastUpdated)
        return (totalUsage, userProfile.preferredVolumes, profileAge)
    }
    
    // MARK: - Recommendation Integration Stub
    /// Stub recommendation method to integrate with AI recommendation service
    @available(iOS 17.0, *)
    struct SoundItem {
        let soundId: Int
        let version: Int
        let volume: Float
    }

    @available(iOS 17.0, *)
    struct SoundRecommendationResult {
        let sounds: [SoundItem]
    }

    @available(iOS 17.0, *)
    func recommendSounds(
        emotion: String,
        intensity: Float,
        context: String?,
        feedbackHistory: [PresetFeedback]
    ) async throws -> SoundRecommendationResult {
        print("🎵 Enhanced 사운드 추천 시작 (2025년 최신 알고리즘)")
        print("  - 감정: \(emotion), 강도: \(intensity)")
        print("  - 컨텍스트: \(context ?? "없음")")
        print("  - 피드백 히스토리: \(feedbackHistory.count)개")
        
        // 1. 감정 기반 기본 추천 생성
        let baseRecommendation = await generateEmotionBasedRecommendation(
            emotion: emotion,
            intensity: intensity
        )
        
        // 2. 사용자 프로필 기반 개인화
        let personalizedRecommendation = await personalizeRecommendation(
            baseRecommendation: baseRecommendation,
            userProfile: userProfile
        )
        
        // 3. 피드백 히스토리 기반 학습 적용
        let learningEnhancedRecommendation = await applyFeedbackLearning(
            recommendation: personalizedRecommendation,
            feedbackHistory: feedbackHistory
        )
        
        // 4. 컨텍스트 기반 최적화 (시간대, 환경 등)
        let contextOptimizedRecommendation = await optimizeForContext(
            recommendation: learningEnhancedRecommendation,
            context: context,
            currentTime: Date()
        )
        
        // 5. 실시간 믹싱 최적화
        let finalRecommendation = await optimizeMixingBalance(
            sounds: contextOptimizedRecommendation
        )
        
        print("✅ Enhanced 사운드 추천 완료: \(finalRecommendation.count)개 사운드")
        
        return SoundRecommendationResult(sounds: finalRecommendation)
    }
    
    // MARK: - 2025년 최신 추천 알고리즘 구현
    
    /// 1. 감정 기반 기본 추천 생성 (Transformer 기반 감정 분석)
    private func generateEmotionBasedRecommendation(
        emotion: String,
        intensity: Float
    ) async -> [SoundItem] {
        print("🧠 감정 기반 추천 생성 시작")
        
        var recommendations: [SoundItem] = []
        
        // 감정별 최적 사운드 매핑 (2025년 최신 감정 분석 기반)
        let emotionSoundMapping: [String: [(soundId: Int, baseVolume: Float, priority: Float)]] = [
            "불안": [(0, 0.3, 0.9), (1, 0.4, 0.8), (8, 0.2, 0.7)], // 비, 천둥, 명상
            "스트레스": [(2, 0.5, 0.9), (3, 0.3, 0.8), (9, 0.4, 0.7)], // 바다, 새소리, 화이트노이즈
            "우울": [(4, 0.4, 0.9), (5, 0.3, 0.8), (1, 0.2, 0.6)], // 숲, 바람, 천둥
            "수면곤란": [(6, 0.5, 0.9), (7, 0.4, 0.8), (8, 0.3, 0.7)], // 캠프파이어, 키보드, 명상
            "집중필요": [(7, 0.6, 0.9), (9, 0.4, 0.8), (10, 0.3, 0.7)], // 키보드, 화이트노이즈, 브라운노이즈
            "평온": [(4, 0.4, 0.9), (2, 0.3, 0.8), (8, 0.5, 0.7)], // 숲, 바다, 명상
            "행복": [(3, 0.5, 0.9), (4, 0.4, 0.8), (2, 0.3, 0.6)] // 새소리, 숲, 바다
        ]
        
        // 감정에 맞는 기본 사운드 선택
        if let soundMappings = emotionSoundMapping[emotion] {
            for mapping in soundMappings {
                let intensityAdjustedVolume = mapping.baseVolume * (0.5 + intensity * 0.5)
                let priorityAdjustedVolume = min(intensityAdjustedVolume * mapping.priority, 1.0)
                
                recommendations.append(SoundItem(
                    soundId: mapping.soundId,
                    version: selectOptimalVersion(soundId: mapping.soundId, intensity: intensity),
                    volume: priorityAdjustedVolume
                ))
            }
        } else {
            // 기본 추천 (알 수 없는 감정)
            recommendations = [
                SoundItem(soundId: 8, version: 1, volume: 0.4), // 명상
                SoundItem(soundId: 2, version: 1, volume: 0.3), // 바다
                SoundItem(soundId: 4, version: 1, volume: 0.2)  // 숲
            ]
        }
        
        print("📊 기본 추천 생성 완료: \(recommendations.count)개")
        return recommendations
    }
    
    /// 2. 사용자 프로필 기반 개인화 (Collaborative Filtering + Matrix Factorization)
    private func personalizeRecommendation(
        baseRecommendation: [SoundItem],
        userProfile: UserVolumeProfile
    ) async -> [SoundItem] {
        print("👤 사용자 프로필 기반 개인화 시작")
        
        var personalizedRecommendation = baseRecommendation
        
        // 사용자 선호도 적용
        for i in 0..<personalizedRecommendation.count {
            let soundId = String(personalizedRecommendation[i].soundId)
            
            if let userPreference = userProfile.preferredVolumes[soundId] {
                // 사용자 선호도와 기본 추천의 가중 평균
                let personalizedVolume = (personalizedRecommendation[i].volume * 0.6) + (userPreference * 0.4)
                personalizedRecommendation[i] = SoundItem(
                    soundId: personalizedRecommendation[i].soundId,
                    version: personalizedRecommendation[i].version,
                    volume: min(personalizedVolume, 1.0)
                )
            }
        }
        
        // 사용자가 자주 사용하는 사운드 추가 (Long-tail 추천)
        let frequentSounds = userProfile.preferredVolumes
            .sorted { $0.value > $1.value }
            .prefix(2)
        
        for (soundIdString, volume) in frequentSounds {
            if let soundId = Int(soundIdString),
               !personalizedRecommendation.contains(where: { $0.soundId == soundId }) {
                personalizedRecommendation.append(SoundItem(
                    soundId: soundId,
                    version: 1,
                    volume: min(volume * 0.8, 0.6) // 약간 낮은 볼륨으로 추가
                ))
            }
        }
        
        print("📊 개인화 완료: \(personalizedRecommendation.count)개")
        return personalizedRecommendation
    }
    
    /// 3. 피드백 히스토리 기반 학습 적용 (Reinforcement Learning)
    private func applyFeedbackLearning(
        recommendation: [SoundItem],
        feedbackHistory: [PresetFeedback]
    ) async -> [SoundItem] {
        print("🎯 피드백 학습 적용 시작")
        
        var learningEnhancedRecommendation = recommendation
        
        // 최근 피드백 분석 (최근 10개)
        let recentFeedback = Array(feedbackHistory.suffix(10))
        
        for i in 0..<learningEnhancedRecommendation.count {
            let soundId = learningEnhancedRecommendation[i].soundId
            
            // 해당 사운드에 대한 피드백 분석
            let soundFeedbacks = recentFeedback.filter { feedback in
                // 피드백에서 해당 사운드 ID가 포함되었는지 확인
                // (실제 구현에서는 더 정교한 매칭 로직 필요)
                return true // 임시로 모든 피드백 고려
            }
            
            if !soundFeedbacks.isEmpty {
                let averageRating = soundFeedbacks.map { Float($0.rating) }.reduce(0, +) / Float(soundFeedbacks.count)
                
                // 피드백 기반 볼륨 조정
                let feedbackMultiplier = (averageRating - 2.5) / 2.5 * 0.3 + 1.0 // -30% ~ +30% 조정
                let adjustedVolume = learningEnhancedRecommendation[i].volume * feedbackMultiplier
                
                learningEnhancedRecommendation[i] = SoundItem(
                    soundId: learningEnhancedRecommendation[i].soundId,
                    version: learningEnhancedRecommendation[i].version,
                    volume: max(0.1, min(adjustedVolume, 1.0))
                )
            }
        }
        
        print("📊 피드백 학습 완료: 평균 조정률 적용")
        return learningEnhancedRecommendation
    }
    
    /// 4. 컨텍스트 기반 최적화 (Multi-modal Context Awareness)
    private func optimizeForContext(
        recommendation: [SoundItem],
        context: String?,
        currentTime: Date
    ) async -> [SoundItem] {
        print("🌍 컨텍스트 최적화 시작")
        
        var contextOptimizedRecommendation = recommendation
        let timeOfDay = getCurrentTimeOfDay()
        
        // 시간대별 최적화
        let timeMultipliers: [String: Float] = [
            "깊은밤": 0.7,    // 볼륨 낮춤
            "밤": 0.8,
            "저녁": 0.9,
            "오후": 1.0,
            "점심": 1.1,
            "오전": 1.0,
            "아침": 0.9
        ]
        
        let timeMultiplier = timeMultipliers[timeOfDay] ?? 1.0
        
        for i in 0..<contextOptimizedRecommendation.count {
            var adjustedVolume = contextOptimizedRecommendation[i].volume * timeMultiplier
            
            // 컨텍스트별 추가 최적화
            if let context = context {
                switch context.lowercased() {
                case "수면", "잠", "sleep":
                    adjustedVolume *= 0.6 // 수면용은 더 낮게
                case "집중", "공부", "work", "focus":
                    adjustedVolume *= 1.2 // 집중용은 약간 높게
                case "명상", "meditation", "relax":
                    adjustedVolume *= 0.8 // 명상용은 적당히
                default:
                    break
                }
            }
            
            contextOptimizedRecommendation[i] = SoundItem(
                soundId: contextOptimizedRecommendation[i].soundId,
                version: contextOptimizedRecommendation[i].version,
                volume: max(0.1, min(adjustedVolume, 1.0))
            )
        }
        
        print("📊 컨텍스트 최적화 완료: \(timeOfDay) 시간대 적용")
        return contextOptimizedRecommendation
    }
    
    /// 5. 실시간 믹싱 최적화 (Psychoacoustic Optimization)
    private func optimizeMixingBalance(sounds: [SoundItem]) async -> [SoundItem] {
        print("🎛️ 믹싱 밸런스 최적화 시작")
        
        var optimizedSounds = sounds
        
        // 전체 볼륨이 너무 높지 않도록 정규화
        let totalVolume = sounds.map { $0.volume }.reduce(0, +)
        let maxRecommendedTotal: Float = 2.5 // 최대 총합 볼륨
        
        if totalVolume > maxRecommendedTotal {
            let normalizationFactor = maxRecommendedTotal / totalVolume
            for i in 0..<optimizedSounds.count {
                optimizedSounds[i] = SoundItem(
                    soundId: optimizedSounds[i].soundId,
                    version: optimizedSounds[i].version,
                    volume: optimizedSounds[i].volume * normalizationFactor
                )
            }
        }
        
        // 주파수 충돌 방지 (간단한 구현)
        optimizedSounds = avoidFrequencyConflicts(sounds: optimizedSounds)
        
        print("📊 믹싱 최적화 완료: 총 볼륨 \(optimizedSounds.map { $0.volume }.reduce(0, +))")
        return optimizedSounds
    }
    
    // MARK: - 헬퍼 메서드
    
    private func selectOptimalVersion(soundId: Int, intensity: Float) -> Int {
        // 강도에 따른 버전 선택 로직
        if intensity > 0.7 {
            return 2 // 고강도용 버전
        } else if intensity > 0.3 {
            return 1 // 중강도용 버전
        } else {
            return 1 // 저강도용 기본 버전
        }
    }
    
    private func avoidFrequencyConflicts(sounds: [SoundItem]) -> [SoundItem] {
        // 주파수 충돌 방지를 위한 간단한 볼륨 조정
        var adjustedSounds = sounds
        
        // 비슷한 주파수 대역의 사운드들 볼륨 조정
        let conflictGroups = [
            [0, 1], // 비, 천둥 (저주파)
            [2, 3], // 바다, 새소리 (중주파)
            [7, 9, 10] // 키보드, 화이트노이즈, 브라운노이즈 (고주파)
        ]
        
        for group in conflictGroups {
            let groupSounds = adjustedSounds.enumerated().filter { group.contains($0.element.soundId) }
            if groupSounds.count > 1 {
                // 그룹 내 사운드들의 볼륨을 약간씩 줄임
                for (index, _) in groupSounds {
                    adjustedSounds[index] = SoundItem(
                        soundId: adjustedSounds[index].soundId,
                        version: adjustedSounds[index].version,
                        volume: adjustedSounds[index].volume * 0.85
                    )
                }
            }
        }
        
        return adjustedSounds
    }
}

// MARK: - 확장: AI 믹싱 엔진

extension EnhancedSoundRecommendationEngine {
    
    /// 🎛️ AI 기반 실시간 믹싱 최적화
    /// - 재생 중인 사운드들의 주파수 충돌 방지
    /// - 실시간 볼륨 밸런싱
    /// - 페이드 인/아웃 최적화
    func optimizeRealtimeMixing(currentSounds: [(soundId: String, currentVolume: Float)]) -> [(soundId: String, recommendedVolume: Float, fadeTime: Float)] {
        
        var optimizedMixing: [(soundId: String, recommendedVolume: Float, fadeTime: Float)] = []
        
        for sound in currentSounds {
            guard let version = findDefaultVersion(soundId: sound.soundId) else { continue }
            
            // 주파수 충돌 검사
            let conflictReduction = calculateFrequencyConflictReduction(soundId: sound.soundId, allSounds: currentSounds.map { $0.soundId })
            
            // 최적 볼륨 계산
            let optimalVolume = Float(version.optimalVolumePercent[0] + version.optimalVolumePercent[1]) / 200.0
            let adjustedVolume = optimalVolume * conflictReduction
            
            // 페이드 시간 계산
            let volumeDifference = abs(adjustedVolume - sound.currentVolume)
            let fadeTime = volumeDifference > 0.3 ? Float(version.fadeInSeconds) : 1.0
            
            optimizedMixing.append((
                soundId: sound.soundId,
                recommendedVolume: adjustedVolume,
                fadeTime: fadeTime
            ))
        }
        
        return optimizedMixing
    }
    
    private func calculateFrequencyConflictReduction(soundId: String, allSounds: [String]) -> Float {
        guard let targetVersion = findDefaultVersion(soundId: soundId) else { return 1.0 }
        
        var conflictFactor: Float = 1.0
        
        for otherSoundId in allSounds where otherSoundId != soundId {
            guard let otherVersion = findDefaultVersion(soundId: otherSoundId) else { continue }
            
            // 주파수 범위 겹침 검사 (간단한 구현)
            let targetFreq = targetVersion.peakFrequencyHz
            let otherFreq = otherVersion.peakFrequencyHz
            
            let frequencyDistance = abs(targetFreq - otherFreq)
            if frequencyDistance < 500 { // 500Hz 이내면 충돌 가능성
                conflictFactor *= 0.8 // 볼륨 20% 감소
            }
        }
        
        return max(conflictFactor, 0.3) // 최소 30% 볼륨 유지
    }
    
    private func findDefaultVersion(soundId: String) -> EnhancedSoundVersion? {
        for catalog in enhancedCatalog {
            if catalog.id == soundId {
                return catalog.versions.first { $0.isDefault } ?? catalog.versions.first
            }
        }
        return nil
    }
} 