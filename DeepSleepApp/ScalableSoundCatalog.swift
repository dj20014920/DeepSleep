import Foundation

/// 🚀 확장 가능한 사운드 카탈로그 시스템 (Enterprise급 확장성)
/// 새로운 음원 카테고리와 버전 추가를 위한 동적 관리 시스템
class ScalableSoundCatalog {
    static let shared = ScalableSoundCatalog()
    private init() {}
    
    // MARK: - 동적 카테고리 관리
    
    private var categoryRegistry: [String: SoundCategoryDefinition] = [:]
    private var versionRegistry: [String: [Int: SoundVersionInfo]] = [:]
    private var categoryMetadata: [String: CategoryMetadata] = [:]
    
    /// 사운드 카테고리 정의
    struct SoundCategoryDefinition {
        let id: String
        let displayName: String
        let emoji: String
        let psychoacousticProfile: PsychoacousticProfile
        var availableVersions: [Int]
        let defaultVersion: Int
        let emotionalTargets: [String]
        let timeOptimization: [String]
        let creationDate: Date
        var isActive: Bool
    }
    
    /// 음향 심리학적 프로필
    struct PsychoacousticProfile {
        let frequency: FrequencyProfile
        let amplitude: AmplitudeProfile
        let binaural: BinauralProfile
        let spatial: SpatialProfile
        let therapeuticEffects: [TherapeuticEffect]
    }
    
    struct FrequencyProfile {
        let dominantRange: ClosedRange<Float> // Hz
        let harmonics: [Float]
        let resonancePoints: [Float]
        let filterCharacteristics: FilterType
    }
    
    struct AmplitudeProfile {
        let dynamicRange: Float // dB
        let peakLevels: [Float]
        let compressionRatio: Float
        let fadingCharacteristics: FadingType
    }
    
    struct BinauralProfile {
        let isEnabled: Bool
        let beatFrequency: Float? // Hz
        let carrierFrequency: Float? // Hz
        let brainwaveTarget: BrainwaveType?
    }
    
    struct SpatialProfile {
        let is3D: Bool
        let panningBehavior: PanningType
        let reverbLevel: Float
        let spatialWidth: Float
    }
    
    /// 치료적 효과 정의
    enum TherapeuticEffect: String, CaseIterable {
        case stressReduction = "stress_reduction"
        case sleepInduction = "sleep_induction"
        case focusEnhancement = "focus_enhancement"
        case anxietyRelief = "anxiety_relief"
        case moodElevation = "mood_elevation"
        case painReduction = "pain_reduction"
        case memoryEnhancement = "memory_enhancement"
        case creativityBoost = "creativity_boost"
        case meditativeState = "meditative_state"
        case energyBoost = "energy_boost"
    }
    
    enum FilterType: String {
        case lowpass, highpass, bandpass, notch, allpass
    }
    
    enum FadingType: String {
        case linear, exponential, logarithmic, custom
    }
    
    enum BrainwaveType: String {
        case delta, theta, alpha, beta, gamma
    }
    
    enum PanningType: String {
        case `static`, dynamic, circular, random
    }
    
    /// 버전별 사운드 정보
    struct SoundVersionInfo {
        let versionNumber: Int
        let displayName: String
        let description: String
        let audioFilePath: String
        let duration: TimeInterval
        let psychoacousticModifications: [String: Any]
        let targetEmotions: [String]
        let effectivenessRating: Float
        let releaseDate: Date
        let isExperimental: Bool
    }
    
    /// 카테고리 메타데이터
    struct CategoryMetadata {
        var usageStatistics: UsageStatistics
        var userFeedback: AggregatedFeedback
        let algorithmicPerformance: AlgorithmPerformance
        var lastUpdated: Date
    }
    
    struct UsageStatistics {
        var totalSessions: Int
        var averageSessionDuration: TimeInterval
        var popularTimeSlots: [Int: Int] // hour: count
        var emotionDistribution: [String: Int]
        var completionRates: [Float]
    }
    
    struct AggregatedFeedback {
        var averageRating: Float
        var satisfactionScore: Float
        var effectivenessRatings: [TherapeuticEffect: Float]
        let commonComplaints: [String]
        let positiveAspects: [String]
    }
    
    struct AlgorithmPerformance {
        let predictionAccuracy: Float
        let recommendationSuccess: Float
        let personalizationEffectiveness: Float
        let versionPreferenceDistribution: [Int: Float]
    }
    
    // MARK: - 초기화 및 등록
    
    /// 기본 카테고리들을 동적으로 등록
    func initializeDefaultCategories() {
        // 기존 13개 카테고리를 새로운 시스템으로 마이그레이션
        registerBasicCategories()
        
        // 확장성 테스트를 위한 새로운 카테고리들
        registerAdvancedCategories()
        
        // 메타데이터 초기화
        initializeCategoryMetadata()
    }
    
    private func registerBasicCategories() {
        let basicCategories = [
            ("cat", "🐱 고양이", createCatPsychoacousticProfile()),
            ("wind", "🌪 바람", createWindPsychoacousticProfile()),
            ("footsteps", "👣 발걸음-눈", createFootstepsPsychoacousticProfile()),
            ("night", "🌙 밤", createNightPsychoacousticProfile()),
            ("fire", "🔥 불1", createFirePsychoacousticProfile()),
            ("rain", "🌧 비", createRainPsychoacousticProfile()),
            ("birds", "🐦 새", createBirdsPsychoacousticProfile()),
            ("stream", "🏞 시냇물", createStreamPsychoacousticProfile()),
            ("pencil", "✏️ 연필", createPencilPsychoacousticProfile()),
            ("space", "🌌 우주", createSpacePsychoacousticProfile()),
            ("fan", "❄️ 쿨링팬", createFanPsychoacousticProfile()),
            ("keyboard", "⌨️ 키보드", createKeyboardPsychoacousticProfile()),
            ("waves", "🌊 파도", createWavesPsychoacousticProfile())
        ]
        
        for (id, name, profile) in basicCategories {
            let emoji = String(name.prefix(2))
            let definition = SoundCategoryDefinition(
                id: id,
                displayName: name,
                emoji: emoji,
                psychoacousticProfile: profile,
                availableVersions: [0, 1], // 기본: 버전 1, 2
                defaultVersion: 0,
                emotionalTargets: determineEmotionalTargets(for: id),
                timeOptimization: determineTimeOptimization(for: id),
                creationDate: Date(),
                isActive: true
            )
            
            categoryRegistry[id] = definition
            
            // 버전 정보 등록
            registerVersionsForCategory(id)
        }
    }
    
    private func registerAdvancedCategories() {
        // 🆕 미래 확장을 위한 고급 카테고리들
        let advancedCategories = [
            ("thunder", "⛈️ 천둥", createThunderPsychoacousticProfile(), ["스트레스", "활력"]),
            ("whale", "🐋 고래", createWhalePsychoacousticProfile(), ["명상", "깊은휴식"]),
            ("forest", "🌲 숲속", createForestPsychoacousticProfile(), ["자연치유", "집중"]),
            ("cafe", "☕ 카페", createCafePsychoacousticProfile(), ["사회적집중", "창의성"]),
            ("library", "📚 도서관", createLibraryPsychoacousticProfile(), ["학습", "정적집중"]),
            ("workshop", "🔨 작업실", createWorkshopPsychoacousticProfile(), ["창작", "몰입"]),
            ("temple", "🏛️ 사원", createTemplePsychoacousticProfile(), ["영성", "명상"]),
            ("subway", "🚇 지하철", createSubwayPsychoacousticProfile(), ["도시적응", "이동명상"])
        ]
        
        for (id, name, profile, emotions) in advancedCategories {
            let emoji = String(name.prefix(2))
            let definition = SoundCategoryDefinition(
                id: id,
                displayName: name,
                emoji: emoji,
                psychoacousticProfile: profile,
                availableVersions: [0, 1, 2], // 고급 카테고리는 3개 버전
                defaultVersion: 0,
                emotionalTargets: emotions,
                timeOptimization: ["전시간대"], // 새로운 카테고리는 시간 제약 없음
                creationDate: Date(),
                isActive: false // 초기에는 비활성화 (실험적)
            )
            
            categoryRegistry[id] = definition
            registerVersionsForCategory(id, versions: [0, 1, 2])
        }
    }
    
    // MARK: - 동적 카테고리 관리 API
    
    /// 새로운 사운드 카테고리 등록
    func registerSoundCategory(
        id: String,
        displayName: String,
        emoji: String,
        psychoacousticProfile: PsychoacousticProfile,
        emotionalTargets: [String],
        timeOptimization: [String],
        versions: [Int] = [0, 1]
    ) -> Bool {
        
        // 중복 ID 검사
        guard categoryRegistry[id] == nil else {
            print("⚠️ Category ID '\(id)' already exists")
            return false
        }
        
        let definition = SoundCategoryDefinition(
            id: id,
            displayName: displayName,
            emoji: emoji,
            psychoacousticProfile: psychoacousticProfile,
            availableVersions: versions,
            defaultVersion: versions.first ?? 0,
            emotionalTargets: emotionalTargets,
            timeOptimization: timeOptimization,
            creationDate: Date(),
            isActive: true
        )
        
        categoryRegistry[id] = definition
        registerVersionsForCategory(id, versions: versions)
        initializeMetadataForCategory(id)
        
        print("✅ New sound category registered: \(displayName)")
        return true
    }
    
    /// 새로운 버전 추가
    func addVersionToCategory(
        categoryId: String,
        versionNumber: Int,
        displayName: String,
        description: String,
        audioFilePath: String,
        modifications: [String: Any] = [:],
        targetEmotions: [String] = [],
        isExperimental: Bool = false
    ) -> Bool {
        
        guard var category = categoryRegistry[categoryId] else {
            print("⚠️ Category '\(categoryId)' not found")
            return false
        }
        
        // 중복 버전 검사
        guard !category.availableVersions.contains(versionNumber) else {
            print("⚠️ Version \(versionNumber) already exists for category '\(categoryId)'")
            return false
        }
        
        let versionInfo = SoundVersionInfo(
            versionNumber: versionNumber,
            displayName: displayName,
            description: description,
            audioFilePath: audioFilePath,
            duration: estimateDuration(from: audioFilePath),
            psychoacousticModifications: modifications,
            targetEmotions: targetEmotions,
            effectivenessRating: 0.0, // 초기값
            releaseDate: Date(),
            isExperimental: isExperimental
        )
        
        // 카테고리 업데이트
        category.availableVersions.append(versionNumber)
        categoryRegistry[categoryId] = category
        
        // 버전 레지스트리 업데이트
        if versionRegistry[categoryId] == nil {
            versionRegistry[categoryId] = [:]
        }
        versionRegistry[categoryId]?[versionNumber] = versionInfo
        
        print("✅ New version \(versionNumber) added to category '\(categoryId)'")
        return true
    }
    
    /// 카테고리 비활성화/활성화
    func toggleCategoryActive(categoryId: String, isActive: Bool) -> Bool {
        guard var category = categoryRegistry[categoryId] else { return false }
        
        category.isActive = isActive
        categoryRegistry[categoryId] = category
        
        print("🔄 Category '\(categoryId)' \(isActive ? "activated" : "deactivated")")
        return true
    }
    
    // MARK: - 지능형 추천 시스템 통합
    
    /// 현재 등록된 모든 활성 카테고리 가져오기
    func getActiveCategories() -> [SoundCategoryDefinition] {
        return categoryRegistry.values.filter { $0.isActive }
    }
    
    /// 감정별 최적 카테고리 추천
    func recommendCategoriesForEmotion(_ emotion: String, timeOfDay: Int) -> [String] {
        let activeCategories = getActiveCategories()
        
        let relevantCategories = activeCategories.filter { category in
            category.emotionalTargets.contains { target in
                target.lowercased().contains(emotion.lowercased()) ||
                emotion.lowercased().contains(target.lowercased())
            }
        }
        
        // 시간대별 최적화 적용
        let timeOptimizedCategories = relevantCategories.filter { category in
            category.timeOptimization.contains("전시간대") ||
            isTimeOptimal(category: category, hour: timeOfDay)
        }
        
        return timeOptimizedCategories.isEmpty ? 
            relevantCategories.map { $0.id } : 
            timeOptimizedCategories.map { $0.id }
    }
    
    /// 치료적 효과별 카테고리 추천
    func recommendCategoriesForTherapeuticEffect(_ effect: TherapeuticEffect) -> [String] {
        let activeCategories = getActiveCategories()
        
        return activeCategories.filter { category in
            category.psychoacousticProfile.therapeuticEffects.contains(effect)
        }.map { $0.id }
    }
    
    /// 동적 버전 선택 (확장된 로직)
    func selectOptimalVersion(
        for categoryId: String,
        context: ScalableRecommendationContext,
        userProfile: UserBehaviorProfile?
    ) -> Int {
        
        guard let category = categoryRegistry[categoryId],
              let versions = versionRegistry[categoryId] else {
            return 0
        }
        
        var versionScores: [Int: Float] = [:]
        
        for versionNumber in category.availableVersions {
            var score: Float = 0.5 // 기본 점수
            
            // 1. 사용자 피드백 기반 점수
            if let profile = userProfile,
               let pattern = profile.emotionPatterns[context.emotion] {
                let versionUsage = pattern.versionPreferences[versionNumber] ?? 0
                score += Float(versionUsage) * 0.1
            }
            
            // 2. 시간대별 최적화
            score += getTimeOptimizationScore(version: versionNumber, hour: context.timeOfDay)
            
            // 3. 감정 매칭 점수
            if let versionInfo = versions[versionNumber] {
                if versionInfo.targetEmotions.contains(context.emotion) {
                    score += 0.2
                }
                
                // 4. 효과성 등급 반영
                score += versionInfo.effectivenessRating * 0.3
                
                // 5. 실험적 버전 페널티 (신뢰성 중시)
                if versionInfo.isExperimental && context.requiresStability {
                    score -= 0.1
                }
            }
            
            // 6. 다양성 보너스 (최근에 사용하지 않은 버전)
            if let metadata = categoryMetadata[categoryId] {
                let recentUsage = metadata.algorithmicPerformance.versionPreferenceDistribution[versionNumber] ?? 0.0
                if recentUsage < 0.3 {
                    score += 0.05 // 다양성 보너스
                }
            }
            
            versionScores[versionNumber] = score
        }
        
        // 최고 점수 버전 선택
        return versionScores.max { $0.value < $1.value }?.key ?? category.defaultVersion
    }
    
    // MARK: - 성능 분석 및 최적화
    
    /// 카테고리별 성능 분석
    func analyzeCategoryPerformance() -> [String: Float] {
        var performanceScores: [String: Float] = [:]
        
        for (categoryId, metadata) in categoryMetadata {
            let usageScore = min(1.0, Float(metadata.usageStatistics.totalSessions) / 1000.0)
            let satisfactionScore = metadata.userFeedback.satisfactionScore
            let algorithmScore = metadata.algorithmicPerformance.predictionAccuracy
            
            let overallScore = (usageScore * 0.3 + satisfactionScore * 0.4 + algorithmScore * 0.3)
            performanceScores[categoryId] = overallScore
        }
        
        return performanceScores
    }
    
    /// 자동 카테고리 최적화
    func optimizeCatalog() {
        let performanceScores = analyzeCategoryPerformance()
        
        for (categoryId, score) in performanceScores {
            // 성능이 낮은 카테고리 비활성화 검토
            if score < 0.3 && categoryRegistry[categoryId]?.isActive == true {
                print("📊 Low performance detected for category '\(categoryId)' (score: \(score))")
                
                // 실험적 카테고리만 자동 비활성화
                if let category = categoryRegistry[categoryId],
                   category.creationDate.timeIntervalSinceNow > -30*24*3600 { // 30일 이내 신규
                    let _ = toggleCategoryActive(categoryId: categoryId, isActive: false)
                    print("🔄 Experimental category '\(categoryId)' auto-deactivated")
                }
            }
            
            // 고성능 카테고리 우선순위 상승
            if score > 0.8 {
                print("⭐ High performance category: '\(categoryId)' (score: \(score))")
            }
        }
    }
    
    // MARK: - 레거시 시스템 호환성
    
    /// 기존 SoundPresetCatalog와 호환성 유지
    func getLegacyCategoryNames() -> [String] {
        return getActiveCategories()
            .sorted { $0.creationDate < $1.creationDate }
            .map { $0.displayName }
    }
    
    func getLegacyCategoryEmojis() -> [String] {
        return getActiveCategories()
            .sorted { $0.creationDate < $1.creationDate }
            .map { $0.emoji }
    }
    
    func getLegacyDefaultVersions() -> [Int] {
        return getActiveCategories()
            .sorted { $0.creationDate < $1.creationDate }
            .map { $0.defaultVersion }
    }
    
    /// 동적 버전 배열 생성
    func generateIntelligentVersions(
        emotion: String,
        timeOfDay: Int,
        userProfile: UserBehaviorProfile?,
        randomSeed: Int = Int(Date().timeIntervalSince1970)
    ) -> [Int] {
        
        let activeCategories = getActiveCategories().sorted { $0.creationDate < $1.creationDate }
        let context = ScalableRecommendationContext(
            emotion: emotion,
            timeOfDay: timeOfDay,
            requiresStability: true
        )
        
        return activeCategories.map { category in
            selectOptimalVersion(
                for: category.id,
                context: context,
                userProfile: userProfile
            )
        }
    }
    
    // MARK: - 프리셋 통합 지원
    
    /// 동적 프리셋 생성
    func generateDynamicPreset(
        for emotion: String,
        timeOfDay: Int,
        userProfile: UserBehaviorProfile?
    ) -> DynamicSoundPreset {
        
        let recommendedCategories = recommendCategoriesForEmotion(emotion, timeOfDay: timeOfDay)
        let activeCategories = getActiveCategories()
        
        var volumes: [Float] = []
        var versions: [Int] = []
        var categoryNames: [String] = []
        
        for category in activeCategories.sorted(by: { $0.creationDate < $1.creationDate }) {
            let isRecommended = recommendedCategories.contains(category.id)
            let baseVolume: Float = isRecommended ? 0.6 : 0.2
            
            // 개인화 조정
            let personalizedVolume = applyPersonalization(
                baseVolume: baseVolume,
                categoryId: category.id,
                userProfile: userProfile
            )
            
                         let optimalVersion = selectOptimalVersion(
                 for: category.id,
                 context: ScalableRecommendationContext(emotion: emotion, timeOfDay: timeOfDay, requiresStability: true),
                 userProfile: userProfile
             )
            
            volumes.append(personalizedVolume)
            versions.append(optimalVersion)
            categoryNames.append(category.displayName)
        }
        
        return DynamicSoundPreset(
            categoryNames: categoryNames,
            volumes: volumes,
            versions: versions,
            generationContext: DynamicPresetContext(
                emotion: emotion,
                timeOfDay: timeOfDay,
                generationTime: Date(),
                activeCategories: activeCategories.count,
                personalizationApplied: userProfile != nil
            )
        )
    }
    
    // MARK: - 업데이트 및 확장 메서드들
    
    /// 사용 통계 업데이트
    func updateUsageStatistics(
        categoryId: String,
        sessionDuration: TimeInterval,
        emotion: String,
        timeOfDay: Int,
        completionRate: Float
    ) {
        guard var metadata = categoryMetadata[categoryId] else { return }
        
        var stats = metadata.usageStatistics
        stats.totalSessions += 1
        stats.averageSessionDuration = (stats.averageSessionDuration * Double(stats.totalSessions - 1) + sessionDuration) / Double(stats.totalSessions)
        stats.popularTimeSlots[timeOfDay, default: 0] += 1
        stats.emotionDistribution[emotion, default: 0] += 1
        stats.completionRates.append(completionRate)
        
        // 최근 100개 완료율만 유지
        if stats.completionRates.count > 100 {
            stats.completionRates.removeFirst()
        }
        
        metadata.usageStatistics = stats
        metadata.lastUpdated = Date()
        categoryMetadata[categoryId] = metadata
    }
    
    /// 피드백 통합
    func integrateFeedback(
        categoryId: String,
        rating: Float,
        satisfactionScore: Float,
        effectivenessRatings: [TherapeuticEffect: Float]
    ) {
        guard var metadata = categoryMetadata[categoryId] else { return }
        
        var feedback = metadata.userFeedback
        
        // 평균 계산 (가중 평균)
        let weight: Float = 0.1
        feedback.averageRating = feedback.averageRating * (1 - weight) + rating * weight
        feedback.satisfactionScore = feedback.satisfactionScore * (1 - weight) + satisfactionScore * weight
        
        for (effect, rating) in effectivenessRatings {
            let currentRating = feedback.effectivenessRatings[effect] ?? 0.5
            feedback.effectivenessRatings[effect] = currentRating * (1 - weight) + rating * weight
        }
        
        metadata.userFeedback = feedback
        metadata.lastUpdated = Date()
        categoryMetadata[categoryId] = metadata
    }
    
    // MARK: - 내부 헬퍼 메서드들
    
    private func registerVersionsForCategory(_ categoryId: String, versions: [Int] = [0, 1]) {
        versionRegistry[categoryId] = [:]
        
        for version in versions {
            let versionInfo = SoundVersionInfo(
                versionNumber: version,
                displayName: "Version \(version + 1)",
                description: generateVersionDescription(for: categoryId, version: version),
                audioFilePath: "\(categoryId)_v\(version).mp3",
                duration: 1800, // 30분 기본
                psychoacousticModifications: [:],
                targetEmotions: determineEmotionalTargets(for: categoryId),
                effectivenessRating: 0.7, // 기본 효과성
                releaseDate: Date(),
                isExperimental: false
            )
            
            versionRegistry[categoryId]?[version] = versionInfo
        }
    }
    
    private func initializeCategoryMetadata() {
        for categoryId in categoryRegistry.keys {
            initializeMetadataForCategory(categoryId)
        }
    }
    
    private func initializeMetadataForCategory(_ categoryId: String) {
        let metadata = CategoryMetadata(
            usageStatistics: UsageStatistics(
                totalSessions: 0,
                averageSessionDuration: 0,
                popularTimeSlots: [:],
                emotionDistribution: [:],
                completionRates: []
            ),
            userFeedback: AggregatedFeedback(
                averageRating: 0.5,
                satisfactionScore: 0.5,
                effectivenessRatings: [:],
                commonComplaints: [],
                positiveAspects: []
            ),
            algorithmicPerformance: AlgorithmPerformance(
                predictionAccuracy: 0.5,
                recommendationSuccess: 0.5,
                personalizationEffectiveness: 0.5,
                versionPreferenceDistribution: [:]
            ),
            lastUpdated: Date()
        )
        
        categoryMetadata[categoryId] = metadata
    }
    
    // MARK: - 음향 심리학적 프로필 생성 메서드들 (샘플)
    
    private func createCatPsychoacousticProfile() -> PsychoacousticProfile {
        return PsychoacousticProfile(
            frequency: FrequencyProfile(
                dominantRange: 20...2000,
                harmonics: [40, 80, 160],
                resonancePoints: [25, 50, 100],
                filterCharacteristics: .lowpass
            ),
            amplitude: AmplitudeProfile(
                dynamicRange: 20,
                peakLevels: [0.3, 0.6, 0.4],
                compressionRatio: 2.0,
                fadingCharacteristics: .exponential
            ),
            binaural: BinauralProfile(
                isEnabled: false,
                beatFrequency: nil,
                carrierFrequency: nil,
                brainwaveTarget: nil
            ),
            spatial: SpatialProfile(
                is3D: false,
                panningBehavior: .`static`,
                reverbLevel: 0.2,
                spatialWidth: 0.5
            ),
            therapeuticEffects: [.stressReduction, .sleepInduction, .anxietyRelief]
        )
    }
    
    // 나머지 프로필 생성 메서드들도 유사하게 구현...
    private func createWindPsychoacousticProfile() -> PsychoacousticProfile {
        return PsychoacousticProfile(
            frequency: FrequencyProfile(dominantRange: 50...3000, harmonics: [100, 200], resonancePoints: [75, 150], filterCharacteristics: .bandpass),
            amplitude: AmplitudeProfile(dynamicRange: 15, peakLevels: [0.4, 0.7], compressionRatio: 1.5, fadingCharacteristics: .linear),
            binaural: BinauralProfile(isEnabled: true, beatFrequency: 8.0, carrierFrequency: 200, brainwaveTarget: .alpha),
            spatial: SpatialProfile(is3D: true, panningBehavior: .dynamic, reverbLevel: 0.4, spatialWidth: 0.8),
            therapeuticEffects: [.stressReduction, .meditativeState]
        )
    }
    
    // 기타 프로필들은 간단하게 구현 (실제로는 더 정교하게)
    private func createFootstepsPsychoacousticProfile() -> PsychoacousticProfile { return createBasicProfile() }
    private func createNightPsychoacousticProfile() -> PsychoacousticProfile { return createBasicProfile() }
    private func createFirePsychoacousticProfile() -> PsychoacousticProfile { return createBasicProfile() }
    private func createRainPsychoacousticProfile() -> PsychoacousticProfile { return createBasicProfile() }
    private func createBirdsPsychoacousticProfile() -> PsychoacousticProfile { return createBasicProfile() }
    private func createStreamPsychoacousticProfile() -> PsychoacousticProfile { return createBasicProfile() }
    private func createPencilPsychoacousticProfile() -> PsychoacousticProfile { return createBasicProfile() }
    private func createSpacePsychoacousticProfile() -> PsychoacousticProfile { return createBasicProfile() }
    private func createFanPsychoacousticProfile() -> PsychoacousticProfile { return createBasicProfile() }
    private func createKeyboardPsychoacousticProfile() -> PsychoacousticProfile { return createBasicProfile() }
    private func createWavesPsychoacousticProfile() -> PsychoacousticProfile { return createBasicProfile() }
    
    // 새로운 카테고리들
    private func createThunderPsychoacousticProfile() -> PsychoacousticProfile { return createBasicProfile() }
    private func createWhalePsychoacousticProfile() -> PsychoacousticProfile { return createBasicProfile() }
    private func createForestPsychoacousticProfile() -> PsychoacousticProfile { return createBasicProfile() }
    private func createCafePsychoacousticProfile() -> PsychoacousticProfile { return createBasicProfile() }
    private func createLibraryPsychoacousticProfile() -> PsychoacousticProfile { return createBasicProfile() }
    private func createWorkshopPsychoacousticProfile() -> PsychoacousticProfile { return createBasicProfile() }
    private func createTemplePsychoacousticProfile() -> PsychoacousticProfile { return createBasicProfile() }
    private func createSubwayPsychoacousticProfile() -> PsychoacousticProfile { return createBasicProfile() }
    
    private func createBasicProfile() -> PsychoacousticProfile {
        return PsychoacousticProfile(
            frequency: FrequencyProfile(dominantRange: 20...4000, harmonics: [], resonancePoints: [], filterCharacteristics: .allpass),
            amplitude: AmplitudeProfile(dynamicRange: 10, peakLevels: [0.5], compressionRatio: 1.0, fadingCharacteristics: .linear),
            binaural: BinauralProfile(isEnabled: false, beatFrequency: nil, carrierFrequency: nil, brainwaveTarget: nil),
            spatial: SpatialProfile(is3D: false, panningBehavior: .`static`, reverbLevel: 0.1, spatialWidth: 0.5),
            therapeuticEffects: [.stressReduction]
        )
    }
    
    private func determineEmotionalTargets(for categoryId: String) -> [String] {
        let emotionalMapping: [String: [String]] = [
            "cat": ["편안", "수면", "안정"],
            "rain": ["이완", "수면", "명상"],
            "wind": ["평온", "명상", "집중"],
            "fire": ["따뜻함", "안정", "명상"],
            "waves": ["이완", "수면", "평온"],
            "birds": ["활력", "자연", "기쁨"],
            "stream": ["평온", "집중", "이완"],
            "space": ["명상", "깊은사고", "우주적"],
            "keyboard": ["집중", "작업", "생산성"],
            "thunder": ["스트레스", "활력", "강렬함"],
            "whale": ["명상", "깊은휴식", "신비"],
            "forest": ["자연치유", "집중", "활력"]
        ]
        
        return emotionalMapping[categoryId] ?? ["일반"]
    }
    
    private func determineTimeOptimization(for categoryId: String) -> [String] {
        let timeMapping: [String: [String]] = [
            "cat": ["저녁", "밤"],
            "rain": ["저녁", "밤", "오후"],
            "birds": ["아침", "오전"],
            "keyboard": ["오전", "오후"],
            "waves": ["저녁", "밤"],
            "thunder": ["오후", "저녁"],
            "forest": ["오전", "오후"]
        ]
        
        return timeMapping[categoryId] ?? ["전시간대"]
    }
    
    private func generateVersionDescription(for categoryId: String, version: Int) -> String {
        return version == 0 ? "기본 버전 - 균형잡힌 사운드" : "향상된 버전 - 더욱 정교한 음향 처리"
    }
    
    private func estimateDuration(from filePath: String) -> TimeInterval {
        return 1800 // 30분 기본값
    }
    
    private func isTimeOptimal(category: SoundCategoryDefinition, hour: Int) -> Bool {
        let timeSlot = getTimeSlot(for: hour)
        return category.timeOptimization.contains(timeSlot)
    }
    
    private func getTimeSlot(for hour: Int) -> String {
        switch hour {
        case 5...8: return "새벽"
        case 9...11: return "오전"
        case 12...13: return "점심"
        case 14...17: return "오후"
        case 18...21: return "저녁"
        case 22...24, 0...4: return "밤"
        default: return "일반"
        }
    }
    
    private func getTimeOptimizationScore(version: Int, hour: Int) -> Float {
        // 시간대별 버전 최적화 점수
        let nightHours = [22, 23, 0, 1, 2, 3, 4, 5]
        
        if nightHours.contains(hour) && version == 1 {
            return 0.1 // 밤에는 버전 2가 더 효과적
        }
        
        return 0.0
    }
    
    private func applyPersonalization(
        baseVolume: Float,
        categoryId: String,
        userProfile: UserBehaviorProfile?
    ) -> Float {
        
        guard let profile = userProfile,
              let metric = profile.soundPatterns.individualSoundMetrics.first(where: { 
                  $0.key.lowercased().contains(categoryId) 
              })?.value else {
            return baseVolume
        }
        
        // 개인 선호도와 기본 볼륨의 가중 평균
        return (baseVolume * 0.7 + metric.averageVolume * 0.3)
    }
}

// MARK: - 추가 데이터 모델들

struct ScalableRecommendationContext {
    let emotion: String
    let timeOfDay: Int
    let requiresStability: Bool
}

struct DynamicSoundPreset {
    let categoryNames: [String]
    let volumes: [Float]
    let versions: [Int]
    let generationContext: DynamicPresetContext
}

struct DynamicPresetContext {
    let emotion: String
    let timeOfDay: Int
    let generationTime: Date
    let activeCategories: Int
    let personalizationApplied: Bool
}

// MARK: - ScalableSoundCatalog Integration Extension

extension SoundPresetCatalog {
    
    /// 확장 가능한 카탈로그와 통합
    static func initializeScalableSystem() {
        ScalableSoundCatalog.shared.initializeDefaultCategories()
        print("🚀 Scalable Sound Catalog System Initialized")
    }
    
    /// 동적 카테고리 이름 가져오기
    static var dynamicCategoryNames: [String] {
        return ScalableSoundCatalog.shared.getLegacyCategoryNames()
    }
    
    /// 동적 카테고리 이모지 가져오기
    static var dynamicCategoryEmojis: [String] {
        return ScalableSoundCatalog.shared.getLegacyCategoryEmojis()
    }
    
    /// 지능형 버전 선택 (확장 버전)
    static func getEnhancedIntelligentVersions(
        emotion: String,
        timeOfDay: String,
        userProfile: UserBehaviorProfile?,
        randomSeed: Int = Int(Date().timeIntervalSince1970)
    ) -> [Int] {
        
        let timeHour = getTimeHour(from: timeOfDay)
        
        return ScalableSoundCatalog.shared.generateIntelligentVersions(
            emotion: emotion,
            timeOfDay: timeHour,
            userProfile: userProfile,
            randomSeed: randomSeed
        )
    }
    
    /// 동적 프리셋 생성
    static func generateDynamicRecommendation(
        emotion: String,
        timeOfDay: String,
        userProfile: UserBehaviorProfile?
    ) -> (name: String, volumes: [Float], description: String, versions: [Int]) {
        
        let timeHour = getTimeHour(from: timeOfDay)
        let dynamicPreset = ScalableSoundCatalog.shared.generateDynamicPreset(
            for: emotion,
            timeOfDay: timeHour,
            userProfile: userProfile
        )
        
        let presetName = generateDynamicPresetName(
            emotion: emotion,
            timeOfDay: timeOfDay,
            context: dynamicPreset.generationContext
        )
        
        let description = generateDynamicDescription(
            emotion: emotion,
            activeCategories: dynamicPreset.generationContext.activeCategories,
            personalized: dynamicPreset.generationContext.personalizationApplied
        )
        
        return (
            name: presetName,
            volumes: dynamicPreset.volumes,
            description: description,
            versions: dynamicPreset.versions
        )
    }
    
    private static func getTimeHour(from timeOfDay: String) -> Int {
        let timeMapping: [String: Int] = [
            "새벽": 5, "아침": 8, "오전": 10, "점심": 12,
            "오후": 15, "저녁": 19, "밤": 22, "자정": 0
        ]
        
        return timeMapping[timeOfDay] ?? 12
    }
    
    private static func generateDynamicPresetName(
        emotion: String,
        timeOfDay: String,
        context: DynamicPresetContext
    ) -> String {
        
        let poeticAdjectives = ["조화로운", "균형잡힌", "신비로운", "평온한", "깊은", "부드러운", "따뜻한"]
        let timeAdjectives = ["새벽의", "아침의", "오후의", "저녁의", "밤의"]
        let emotionAdjectives = ["평화로운", "안정적인", "활기찬", "차분한", "집중된"]
        
        let adjective = poeticAdjectives.randomElement() ?? "조화로운"
        let timeAdj = timeAdjectives.randomElement() ?? "평온한"
        let emotionAdj = emotionAdjectives.randomElement() ?? "균형잡힌"
        
        return "\(adjective) \(timeAdj) \(emotionAdj) 여행"
    }
    
    private static func generateDynamicDescription(
        emotion: String,
        activeCategories: Int,
        personalized: Bool
    ) -> String {
        
        let baseDescription = "\(emotion) 상태에 최적화된 \(activeCategories)개 음원의 조화로운 블렌딩"
        let personalizationNote = personalized ? "개인 맞춤형 " : ""
        
        return "\(personalizationNote)\(baseDescription)으로 깊은 이완과 집중을 선사합니다."
    }
}
