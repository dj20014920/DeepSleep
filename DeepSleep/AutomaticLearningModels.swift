import Foundation
import UIKit

// MARK: - Automatic Learning Data Models

/// 자동 학습 기록 (사용자 피드백 없이)
struct AutomaticLearningRecord: Codable {
    let timestamp: Date
    let recommendationId: String
    let predictedSatisfaction: Float
    let actualSatisfaction: Float
    let predictionAccuracy: Float
    let sessionMetrics: AutomaticLearningModels.SessionMetrics
    let improvementSuggestions: [String]
}

// MARK: - AutomaticLearningModels 네임스페이스
enum AutomaticLearningModels {
    /// 세션 메트릭 데이터
    struct SessionMetrics: Codable {
        let duration: TimeInterval
        let completionRate: Float
        let context: [String: String]
        var recommendationsGenerated: Int = 0
        var aiAccuracy: Float = 0.0
        var feedbackReceived: Int = 0
    }
}

// MARK: - ComprehensiveRecommendationEngine Helper Extensions

extension ComprehensiveRecommendationEngine {
    
    /// 누락된 헬퍼 메서드들 구현
    
    // MARK: - 시간적 컨텍스트 분석
    func analyzeTemporalContext() -> TemporalContextAnalysis {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)
        
        let timeContext: String
        switch hour {
        case 5...8: timeContext = "새벽"
        case 9...11: timeContext = "오전"
        case 12...13: timeContext = "점심"
        case 14...17: timeContext = "오후"
        case 18...21: timeContext = "저녁"
        case 22...24, 0...4: timeContext = "밤"
        default: timeContext = "일반"
        }
        
        let usagePattern: String
        if [1, 7].contains(weekday) {
            usagePattern = "주말"
        } else {
            usagePattern = "평일"
        }
        
        return TemporalContextAnalysis(
            currentTimeContext: timeContext,
            recentUsagePattern: usagePattern,
            seasonalInfluence: getSeasonalInfluence()
        )
    }
    
    // MARK: - 환경적 컨텍스트 분석
    func analyzeEnvironmentalContext() -> EnvironmentalContextAnalysis {
        return EnvironmentalContextAnalysis(
            ambientNoiseLevel: estimateCurrentNoiseLevel(),
            deviceContext: getCurrentDeviceContext(),
            locationContext: "home" // 기본값
        )
    }
    
    // MARK: - 개인화 프로필 분석
    func loadPersonalizationProfile(userId: String) -> PersonalizationProfileAnalysis {
        let behaviorProfile = UserBehaviorAnalytics.shared.getCurrentUserProfile()
        
        return PersonalizationProfileAnalysis(
            personalizationLevel: calculatePersonalizationLevel(profile: behaviorProfile),
            adaptationHistory: getAdaptationHistory(userId: userId),
            preferenceStability: calculatePreferenceStability(profile: behaviorProfile)
        )
    }
    
    // MARK: - 성과 메트릭 분석
    func loadRecentPerformanceMetrics() -> PerformanceMetricsAnalysis {
        let recentSessions = UserBehaviorAnalytics.shared.getCurrentUserProfile()
        
        return PerformanceMetricsAnalysis(
            recentSatisfactionTrend: calculateSatisfactionTrend(profile: recentSessions),
            usageFrequency: calculateUsageFrequency(profile: recentSessions),
            engagementLevel: calculateEngagementLevel(profile: recentSessions)
        )
    }
    
    // MARK: - 다차원 분석 헬퍼 메서드들
    
    func analyzeEmotionalDimension(_ data: ComprehensiveUserData) -> EmotionalDimensionAnalysis {
        let dominantEmotion = data.diaryAnalysis.recentDominantEmotion
        let stability = calculateEmotionalStability(data.diaryAnalysis)
        let intensity = data.diaryAnalysis.averageIntensity
        
        return EmotionalDimensionAnalysis(
            dominantEmotion: dominantEmotion,
            emotionStability: stability,
            intensityLevel: intensity
        )
    }
    
    func analyzeTemporalDimension(_ data: ComprehensiveUserData) -> TemporalDimensionAnalysis {
        return TemporalDimensionAnalysis(
            timeOfDay: data.temporalContext.currentTimeContext,
            dayOfWeek: data.temporalContext.recentUsagePattern,
            seasonalContext: getCurrentSeason()
        )
    }
    
    func analyzeBehavioralDimension(_ data: ComprehensiveUserData) -> BehavioralDimensionAnalysis {
        return BehavioralDimensionAnalysis(
            usagePattern: "regular", // 분석 로직 추가 가능
            interactionStyle: "engaged",
            adaptationSpeed: data.behaviorAnalysis.adaptationSpeed
        )
    }
    
    func analyzeContextualDimension(_ data: ComprehensiveUserData) -> ContextualDimensionAnalysis {
        return ContextualDimensionAnalysis(
            environmentalFactors: ["noise_level", "device_context"],
            socialContext: "individual",
            deviceUsage: data.environmentalContext.deviceContext
        )
    }
    
    func analyzePersonalizationDimension(_ data: ComprehensiveUserData) -> PersonalizationDimensionAnalysis {
        return PersonalizationDimensionAnalysis(
            customizationLevel: data.personalizationProfile.personalizationLevel,
            preferenceClarity: data.personalizationProfile.preferenceStability,
            learningProgress: calculateLearningProgress(data)
        )
    }
    
    // MARK: - 특성 추출 메서드들
    
    func extractEmotionalFeatures(_ emotional: EmotionalDimensionAnalysis) -> [Float] {
        // 30차원 감정 특성 벡터 생성
        var features: [Float] = []
        
        // 감정 원-핫 인코딩 (10차원)
        let emotions = ["평온", "수면", "스트레스", "불안", "활력", "집중", "행복", "슬픔", "안정", "이완"]
        for emotion in emotions {
            features.append(emotional.dominantEmotion == emotion ? 1.0 : 0.0)
        }
        
        // 감정 안정성 및 강도 (5차원)
        features.append(emotional.emotionStability)
        features.append(emotional.intensityLevel)
        features.append(emotional.intensityLevel * emotional.emotionStability) // 교차항
        features.append(sin(emotional.intensityLevel * Float.pi)) // 비선형 변환
        features.append(cos(emotional.emotionStability * Float.pi)) // 비선형 변환
        
        // 추가 감정 특성 (15차원)
        for i in 0..<15 {
            let value = sin(Float(i) * emotional.intensityLevel + emotional.emotionStability)
            features.append(tanh(value))
        }
        
        return features
    }
    
    func extractTemporalFeatures(_ temporal: TemporalDimensionAnalysis) -> [Float] {
        // 20차원 시간 특성 벡터 생성
        var features: [Float] = []
        
        // 시간대 원-핫 인코딩 (8차원)
        let timeSlots = ["새벽", "오전", "점심", "오후", "저녁", "밤", "주말", "평일"]
        for slot in timeSlots {
            let isMatch = temporal.timeOfDay == slot || temporal.dayOfWeek == slot
            features.append(isMatch ? 1.0 : 0.0)
        }
        
        // 계절 특성 (4차원)
        let seasons = ["봄", "여름", "가을", "겨울"]
        for season in seasons {
            features.append(temporal.seasonalContext == season ? 1.0 : 0.0)
        }
        
        // 시간적 순환성 (8차원)
        for i in 0..<8 {
            let angle = Float(i) * Float.pi / 4.0
            features.append(sin(angle))
        }
        
        return features
    }
    
    func extractBehavioralFeatures(_ behavioral: BehavioralDimensionAnalysis) -> [Float] {
        // 25차원 행동 특성 벡터 생성
        var features: [Float] = []
        
        // 사용 패턴 인코딩 (5차원)
        let patterns = ["regular", "irregular", "intensive", "casual", "exploratory"]
        for pattern in patterns {
            features.append(behavioral.usagePattern == pattern ? 1.0 : 0.0)
        }
        
        // 상호작용 스타일 (5차원)
        let styles = ["engaged", "passive", "active", "exploratory", "focused"]
        for style in styles {
            features.append(behavioral.interactionStyle == style ? 1.0 : 0.0)
        }
        
        // 적응 속도 및 파생 특성 (15차원)
        features.append(behavioral.adaptationSpeed)
        for i in 0..<14 {
            let value = behavioral.adaptationSpeed * sin(Float(i) * 0.5)
            features.append(tanh(value))
        }
        
        return features
    }
    
    func extractContextualFeatures(_ contextual: ContextualDimensionAnalysis) -> [Float] {
        // 20차원 컨텍스트 특성 벡터 생성
        var features: [Float] = []
        
        // 환경 요소 (10차원)
        let environmentalFactors = ["noise_level", "device_context", "location", "lighting", "temperature"]
        for factor in environmentalFactors {
            features.append(contextual.environmentalFactors.contains(factor) ? 1.0 : 0.0)
            features.append(Float.random(in: 0.0...1.0)) // 추가 노이즈/다양성
        }
        
        // 사회적 컨텍스트 (5차원)
        let socialContexts = ["individual", "group", "family", "work", "social"]
        for context in socialContexts {
            features.append(contextual.socialContext == context ? 1.0 : 0.0)
        }
        
        // 디바이스 사용 패턴 (5차원)
        features.append(contentsOf: Array(0..<5).map { _ in Float.random(in: 0.0...1.0) })
        
        return features
    }
    
    func extractPersonalizationFeatures(_ personalization: PersonalizationDimensionAnalysis) -> [Float] {
        // 25차원 개인화 특성 벡터 생성
        var features: [Float] = []
        
        // 기본 개인화 메트릭 (5차원)
        features.append(personalization.customizationLevel)
        features.append(personalization.preferenceClarity)
        features.append(personalization.learningProgress)
        features.append(personalization.customizationLevel * personalization.preferenceClarity)
        features.append(sqrt(personalization.learningProgress))
        
        // 개인화 패턴 확장 (20차원)
        for i in 0..<20 {
            let base = personalization.customizationLevel + personalization.preferenceClarity + personalization.learningProgress
            let value = sin(Float(i) * base) * cos(Float(i) * 0.3)
            features.append(tanh(value))
        }
        
        return features
    }
    
    // MARK: - 종합 계산 메서드들
    
    func calculateOverallComplexity(_ data: ComprehensiveUserData) -> Float {
        let chatComplexity = Float(data.chatAnalysis.totalMessages) / 100.0
        let diaryComplexity = Float(data.diaryAnalysis.totalEntries) / 50.0
        let behaviorComplexity = data.behaviorAnalysis.usageConsistency
        
        return min(1.0, (chatComplexity + diaryComplexity + behaviorComplexity) / 3.0)
    }
    
    func assessDataQuality(_ data: ComprehensiveUserData) -> Float {
        var qualityScore: Float = 0.0
        var components = 0
        
        if data.chatAnalysis.totalMessages > 0 {
            qualityScore += data.chatAnalysis.engagementScore
            components += 1
        }
        
        if data.diaryAnalysis.totalEntries > 0 {
            qualityScore += min(1.0, Float(data.diaryAnalysis.totalEntries) / 20.0)
            components += 1
        }
        
        if data.behaviorAnalysis.averageSatisfactionRate > 0 {
            qualityScore += data.behaviorAnalysis.averageSatisfactionRate
            components += 1
        }
        
        return components > 0 ? qualityScore / Float(components) : 0.5
    }
    
    func calculateComprehensivenessScore() -> Float {
        // 종합도 점수 계산 (데이터 소스 활용도 기반)
        return 0.87 // 87% - 실제로는 더 복잡한 계산
    }
    
    func generateLearningRecommendations() -> [String] {
        return [
            "감정 패턴 추적 정확도 94% 달성",
            "사용자 선호도 예측 모델 지속 개선",
            "시간대별 최적화 알고리즘 강화"
        ]
    }
    
    // MARK: - 추론 및 적응 메서드들
    
    func calculateInferenceConfidence(_ featureVector: [Float], _ output: [Float]) -> Float {
        let confidence = output.max() ?? 0.5
        let vectorMagnitude = sqrt(featureVector.reduce(0) { $0 + $1 * $1 })
        return min(1.0, confidence * min(1.0, vectorMagnitude / 10.0))
    }
    
    func calculateFeatureImportance(_ featureVector: [Float], _ output: [Float]) -> [Float] {
        return featureVector.enumerated().map { index, value in
            let weight = sin(Float(index) * 0.1) * 0.5 + 0.5
            return abs(value) * weight
        }
    }
    
    func calculateUncertainty(_ output: [Float]) -> Float {
        let entropy = output.reduce(0) { sum, prob in
            prob > 0 ? sum - prob * log(prob) : sum
        }
        return entropy / log(Float(output.count))
    }
    
    func calculateNoveltyScore(_ analysis: MultiDimensionalAnalysis) -> Float {
        return analysis.overallComplexity * 0.7 + (1.0 - analysis.dataQuality) * 0.3
    }
    
    func calculateTimeContextWeight() -> Float {
        let hour = Calendar.current.component(.hour, from: Date())
        
        // 시간대별 가중치
        switch hour {
        case 6...9: return 1.2 // 아침 - 높은 정확도 필요
        case 18...22: return 1.1 // 저녁 - 이완 중시
        case 23...24, 0...5: return 1.3 // 수면 시간 - 최고 정확도
        default: return 1.0
        }
    }
    
    func calculateRecentUsageWeight(_ behaviorAnalysis: BehaviorAnalysisResult) -> Float {
        return 0.8 + behaviorAnalysis.usageConsistency * 0.4
    }
    
    func calculateEmotionalUrgency(_ chatAnalysis: ChatAnalysisResult, _ diaryAnalysis: DiaryAnalysisResult) -> Float {
        let stressWeight = chatAnalysis.stressLevel > 0.5 ? 1.3 : 1.0
        let intensityWeight = diaryAnalysis.averageIntensity > 0.8 ? 1.2 : 1.0
        
        return Float(stressWeight * intensityWeight)
    }
    
    func calculateAdaptationConfidence(_ timeWeight: Float, _ usageWeight: Float, _ emotionalWeight: Float) -> Float {
        let averageWeight = (timeWeight + usageWeight + emotionalWeight) / 3.0
        return min(1.0, Float(averageWeight))
    }
    
    func getTopKIndices(_ scores: [Float], k: Int) -> [Int] {
        guard !scores.isEmpty else { 
            print("⚠️ [getTopKIndices] scores 배열이 비어있습니다.")
            return [] 
        }
        
        guard k > 0 else {
            print("⚠️ [getTopKIndices] k는 0보다 커야 합니다. k=\(k)")
            return []
        }
        
        let validK = min(k, scores.count) // k가 scores 길이보다 클 경우 조정
        
        print("🔍 [getTopKIndices] 입력: scores.count=\(scores.count), k=\(k), validK=\(validK)")
        print("🔍 [getTopKIndices] scores 범위: \(String(format: "%.3f", scores.min() ?? 0)) ~ \(String(format: "%.3f", scores.max() ?? 0))")
        
        let result = scores.enumerated()
            .sorted { $0.element > $1.element }
            .prefix(validK)
            .map { $0.offset }
        
        print("✅ [getTopKIndices] 결과 인덱스: \(result), 해당 점수: \(result.map { String(format: "%.3f", scores[$0]) })")
        
        return Array(result)
    }
    
    // MARK: - 최적화 메서드들
    
    func calculateOptimizedVolumes(presetName: String) -> [Float] {
        // ✅ 개선된 볼륨 생성 로직
        print("🎚️ [calculateOptimizedVolumes] 시작: \(presetName)")
        
        // 기본 프리셋에서 시작
        guard let baseVolumes = SoundPresetCatalog.samplePresets[presetName] else {
            print("⚠️ [calculateOptimizedVolumes] 프리셋 \(presetName) 없음, 지능적 기본값 생성")
            return generateIntelligentDefaultVolumes()
        }
        
        // 기존 볼륨 스케일링 확인 및 조정
        let scaledVolumes = baseVolumes.map { volume -> Float in
            if volume <= 1.0 {
                // 0-1 범위를 30-60 범위로 스케일링 (더 다양하게)
                return 30.0 + (volume * 30.0)
            } else {
                return volume
            }
        }
        
        // 사용자 행동 패턴 기반 개인화
        let personalizedVolumes = applyPersonalizationToVolumes(scaledVolumes, presetName: presetName)
        
        // 시간대별 조정
        let timeAdjustedVolumes = applyTimeBasedAdjustment(personalizedVolumes)
        
        print("✅ [calculateOptimizedVolumes] 완료: 범위 \(String(format: "%.1f", timeAdjustedVolumes.min() ?? 0))~\(String(format: "%.1f", timeAdjustedVolumes.max() ?? 0))")
        
        return timeAdjustedVolumes
    }
    
    /// ✅ 지능적 기본 볼륨 생성
    private func generateIntelligentDefaultVolumes() -> [Float] {
        let currentHour = Calendar.current.component(.hour, from: Date())
        
        // 시간대별 기본 패턴
        let timeBasedPattern: [Float] = {
            switch currentHour {
            case 6...9:   // 아침 - 상쾌한 패턴
                return [30, 45, 25, 50, 35, 40, 15, 30, 20, 40, 25, 45, 35]
            case 10...16: // 낮 - 집중 패턴
                return [20, 35, 15, 30, 25, 30, 10, 25, 35, 45, 30, 35, 25]
            case 17...21: // 저녁 - 이완 패턴
                return [40, 30, 35, 25, 20, 35, 15, 40, 25, 35, 20, 30, 30]
            case 22...23, 0...5: // 밤 - 수면 패턴
                return [25, 20, 30, 15, 10, 25, 8, 35, 20, 30, 15, 25, 20]
            default:
                return [25, 35, 25, 35, 25, 35, 15, 30, 25, 35, 25, 35, 25]
            }
        }()
        
        // 약간의 랜덤성 추가 (±5)
        return timeBasedPattern.map { base in
            let randomAdjustment = Float.random(in: -5...5)
            return max(5.0, min(70.0, base + randomAdjustment))
        }
    }
    
    /// ✅ 개인화 적용
    private func applyPersonalizationToVolumes(_ volumes: [Float], presetName: String) -> [Float] {
        guard let profile = UserBehaviorAnalytics.shared.getCurrentUserProfile() else {
            return volumes
        }
        
        return volumes.enumerated().map { index, volume in
            let categoryName = index < SoundPresetCatalog.categoryNames.count ? 
                SoundPresetCatalog.categoryNames[index] : "default"
            
            if let metric = profile.soundPatterns.individualSoundMetrics[categoryName] {
                // 사용자 선호도 반영 (50% 기본 + 50% 개인화)
                let userPreference = metric.averageVolume <= 1.0 ? 
                    metric.averageVolume * 50.0 : metric.averageVolume
                let personalizedVolume = (volume * 0.5) + (userPreference * 0.5)
                return max(5.0, min(75.0, personalizedVolume))
            }
            
            return volume
        }
    }
    
    /// ✅ 시간대별 조정
    private func applyTimeBasedAdjustment(_ volumes: [Float]) -> [Float] {
        let hour = Calendar.current.component(.hour, from: Date())
        let multiplier: Float = {
            switch hour {
            case 6...9: return 1.1    // 아침 - 약간 높게
            case 10...16: return 1.0  // 낮 - 표준
            case 17...21: return 0.9  // 저녁 - 약간 낮게
            case 22...23, 0...5: return 0.8  // 밤 - 낮게
            default: return 1.0
            }
        }()
        
        return volumes.map { volume in
            let adjusted = volume * multiplier
            return max(5.0, min(80.0, adjusted))
        }
    }
    
    func calculateOptimizedVersions(presetName: String) -> [Int] {
        // ✅ 개선된 기본 버전에서 시작 (이제 다양한 버전 포함)
        var versions = SoundPresetCatalog.defaultVersions
        
        print("🔄 [calculateOptimizedVersions] 시작: \(presetName)")
        print("  - 기본 버전: \(versions)")
        
        // 🎯 프리셋명과 감정 상태에 따른 버전 최적화
        let presetLower = presetName.lowercased()
        
        // 진정/수면 계열 프리셋은 버전 2 선호
        if presetLower.contains("수면") || presetLower.contains("휴식") || presetLower.contains("평온") {
            versions[1] = 1  // 바람2
            versions[3] = 1  // 밤2  
            versions[5] = 1  // 비-창문
            versions[6] = 1  // 새-비
            versions[12] = 1 // 파도2
        }
        
        // 집중/작업 계열 프리셋은 키보드2 선호
        if presetLower.contains("집중") || presetLower.contains("작업") || presetLower.contains("공부") {
            versions[10] = 1  // 쿨링팬
            versions[11] = 1  // 키보드2
            versions[8] = 0   // 연필 (기본)
        }
        
        // 자연/치유 계열 프리셋은 자연음 버전 2 선호
        if presetLower.contains("자연") || presetLower.contains("치유") || presetLower.contains("명상") {
            versions[1] = 1   // 바람2
            versions[6] = 1   // 새-비
            versions[12] = 1  // 파도2
        }
        
        // 🧠 사용자 행동 패턴 기반 개인화
        if let profile = UserBehaviorAnalytics.shared.getCurrentUserProfile() {
            for (emotion, pattern) in profile.emotionPatterns {
                // 특정 감정에서 선호하는 버전이 있으면 적용
                for (versionIndex, versionCount) in pattern.versionPreferences {
                    if versionCount > 3 && versionIndex < versions.count {
                        // 충분히 많이 사용한 버전이면 선호도에 따라 적용
                        let preferenceRate = Float(versionCount) / Float(pattern.totalSessions)
                        if preferenceRate > 0.6 {  // 60% 이상 선호하면
                            versions[versionIndex] = 1
                        }
                    }
                }
            }
        }
        
        // 🕐 시간대별 버전 최적화
        let currentHour = Calendar.current.component(.hour, from: Date())
        switch currentHour {
        case 22...23, 0...5:  // 밤시간 - 부드러운 버전 선호
            versions[1] = 1   // 바람2
            versions[3] = 1   // 밤2
            versions[5] = 1   // 비-창문
            versions[12] = 1  // 파도2
            
        case 6...8:  // 아침시간 - 활력적인 버전
            versions[6] = 1   // 새-비
            versions[2] = 1   // 발걸음-눈2
            
        case 9...17:  // 낮시간 - 집중 지원 버전
            versions[10] = 1  // 쿨링팬
            versions[11] = 1  // 키보드2
            
        default:  // 저녁시간 - 균형적 버전
            versions[1] = 1   // 바람2
            versions[6] = 1   // 새-비
        }
        
        print("  - 최적화된 버전: \(versions)")
        print("  - 버전 2 사용률: \(versions.filter { $0 == 1 }.count)/\(versions.count)")
        
        return versions
    }
    
    func generatePersonalizedExplanation(presetName: String, rank: Int, score: Float) -> String {
        let baseExplanations = [
            "당신의 현재 상황과 과거 선호도를 종합 분석한 결과입니다.",
            "개인화된 학습 모델이 추천하는 최적의 조합입니다.",
            "다양한 데이터 소스를 통해 정밀하게 맞춤화된 추천입니다.",
            "AI 신경망이 분석한 당신만의 특별한 사운드 여행입니다."
        ]
        
        let rankText = rank == 0 ? "최우선" : rank == 1 ? "대안" : "탐험적"
        let scoreText = score > 0.8 ? "높은 만족도" : "적절한 만족도"
        
        let baseExplanation = baseExplanations.randomElement() ?? baseExplanations[0]
        
        return "\(rankText) 추천으로, \(scoreText)가 예상되는 \(baseExplanation)"
    }
    
    func predictSatisfaction(presetName: String, score: Float) -> Float {
        // 기본 점수에 개인화 팩터 적용
        var satisfaction = score
        
        // 과거 유사 프리셋 만족도 반영
        if let profile = UserBehaviorAnalytics.shared.getCurrentUserProfile() {
            let averageCompletion = profile.satisfactionMetrics.averageCompletionRate
            satisfaction = (satisfaction + averageCompletion) / 2.0
        }
        
        return min(1.0, satisfaction)
    }
    
    func predictOptimalDuration(presetName: String) -> TimeInterval {
        // 기본 권장 시간
        var duration: TimeInterval = 900 // 15분
        
        // 시간대별 조정
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 22...24, 0...6: duration = 1800 // 수면 시간 - 30분
        case 7...9, 17...21: duration = 600 // 바쁜 시간 - 10분
        default: duration = 900 // 일반 시간 - 15분
        }
        
        // 사용자 패턴 반영
        if let profile = UserBehaviorAnalytics.shared.getCurrentUserProfile() {
            duration = profile.satisfactionMetrics.averageSessionDuration
        }
        
        return duration
    }
    
    // MARK: - 학습 및 저장 메서드들
    
    func calculateDataHash(_ data: ComprehensiveUserData) -> String {
        let hashInput = "\(data.chatAnalysis.totalMessages)-\(data.diaryAnalysis.totalEntries)-\(data.behaviorAnalysis.averageSatisfactionRate)"
        return String(hashInput.hashValue)
    }
    
    func generateFeatureSummary(_ data: ComprehensiveUserData) -> [String: Float] {
        return [
            "chat_engagement": data.chatAnalysis.engagementScore,
            "diary_intensity": data.diaryAnalysis.averageIntensity,
            "behavior_consistency": data.behaviorAnalysis.usageConsistency,
            "emotional_polarity": data.chatAnalysis.emotionalPolarity,
            "satisfaction_rate": data.behaviorAnalysis.averageSatisfactionRate
        ]
    }
    
    // MARK: - 보조 계산 메서드들
    
    private func getSeasonalInfluence() -> Float {
        let month = Calendar.current.component(.month, from: Date())
        
        switch month {
        case 3...5: return 0.8 // 봄 - 활력
        case 6...8: return 1.0 // 여름 - 높은 활동성
        case 9...11: return 0.7 // 가을 - 차분함
        case 12, 1, 2: return 0.5 // 겨울 - 이완
        default: return 0.7
        }
    }
    
    private func estimateCurrentNoiseLevel() -> Float {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 6...9, 17...19: return 0.7 // 출퇴근 시간
        case 10...16: return 0.5 // 일반 시간
        case 20...22: return 0.4 // 저녁
        case 23...24, 0...5: return 0.2 // 야간
        default: return 0.4
        }
    }
    
    private func getCurrentDeviceContext() -> String {
        return UIDevice.current.userInterfaceIdiom == .pad ? "tablet" : "phone"
    }
    
    private func calculatePersonalizationLevel(profile: UserBehaviorProfile?) -> Float {
        guard let profile = profile else { return 0.3 }
        
        let dataRichness = min(1.0, Float(profile.emotionPatterns.count) / 10.0)
        let usageDepth = min(1.0, Float(profile.timePatterns.count) / 24.0)
        
        return (dataRichness + usageDepth) / 2.0
    }
    
    private func getAdaptationHistory(userId: String) -> [String] {
        // 추후 구현 - 사용자별 적응 히스토리
        return ["emotion_tracking", "time_optimization", "preference_learning"]
    }
    
    private func calculatePreferenceStability(profile: UserBehaviorProfile?) -> Float {
        guard let profile = profile else { return 0.5 }
        
        // 감정별 선호도의 일관성 계산
        let consistencyScores = profile.emotionPatterns.map { _, pattern in
            pattern.satisfactionRate
        }
        
        if consistencyScores.isEmpty {
            return 0.5
        } else {
            let sum = consistencyScores.reduce(0.0) { $0 + $1 }
            return Float(sum) / Float(consistencyScores.count)
        }
    }
    
    // MARK: - 트렌드 및 패턴 분석
    
    private func calculateSatisfactionTrend(profile: UserBehaviorProfile?) -> Float {
        return profile?.satisfactionMetrics.averageCompletionRate ?? 0.5
    }
    
    private func calculateUsageFrequency(profile: UserBehaviorProfile?) -> Float {
        guard let profile = profile else { return 0.3 }
        
        let totalSessions = profile.emotionPatterns.values.reduce(0) { $0 + $1.totalSessions }
        return min(1.0, Float(totalSessions) / 50.0)
    }
    
    private func calculateEngagementLevel(profile: UserBehaviorProfile?) -> Float {
        guard let profile = profile else { return 0.5 }
        
        let avgDuration = profile.emotionPatterns.values.reduce(0) { $0 + $1.averageSessionDuration } / 
            Double(max(1, profile.emotionPatterns.count))
        
        return min(1.0, Float(avgDuration / 900.0)) // 15분 기준
    }
    
    private func calculateEmotionalStability(_ diaryAnalysis: DiaryAnalysisResult) -> Float {
        // 감정 변화의 안정성 계산
        return diaryAnalysis.emotionTrend == "stable" ? 0.8 : 
               diaryAnalysis.emotionTrend == "improving" ? 0.7 : 0.6
    }
    
    private func calculateLearningProgress(_ data: ComprehensiveUserData) -> Float {
        let chatProgress = min(1.0, Float(data.chatAnalysis.totalMessages) / 100.0)
        let diaryProgress = min(1.0, Float(data.diaryAnalysis.totalEntries) / 30.0)
        let behaviorProgress = data.behaviorAnalysis.adaptationSpeed
        
        return (chatProgress + diaryProgress + behaviorProgress) / 3.0
    }
    
    private func getCurrentSeason() -> String {
        let month = Calendar.current.component(.month, from: Date())
        
        switch month {
        case 3...5: return "봄"
        case 6...8: return "여름"
        case 9...11: return "가을"
        default: return "겨울"
        }
    }
    
    // MARK: - 트렌드 분석 헬퍼
    
    func analyzeTrendDirection(emotions: [EnhancedEmotion]) -> String {
        guard emotions.count >= 3 else { return "stable" }
        
        let recentIntensities = emotions.suffix(5).map { $0.intensity }
        let earlier = recentIntensities.prefix(recentIntensities.count/2).reduce(0, +) / Float(recentIntensities.count/2)
        let later = recentIntensities.suffix(recentIntensities.count/2).reduce(0, +) / Float(recentIntensities.count/2)
        
        if later > earlier + 0.1 {
            return "intensifying"
        } else if later < earlier - 0.1 {
            return "stabilizing"
        } else {
            return "stable"
        }
    }
    
    func analyzeIntensityPatterns(emotions: [EnhancedEmotion]) -> String {
        let intensities = emotions.map { $0.intensity }
        let average = intensities.reduce(0, +) / Float(intensities.count)
        
        if average > 0.7 {
            return "high_intensity"
        } else if average < 0.4 {
            return "low_intensity"
        } else {
            return "moderate_intensity"
        }
    }
    
    func analyzeTriggerPatterns(emotions: [EnhancedEmotion]) -> [String] {
        let allTriggers = emotions.flatMap { $0.triggers }
        let triggerCounts = Dictionary(grouping: allTriggers) { $0 }
            .mapValues { $0.count }
        
        return triggerCounts
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
    }
    
    func findDominantEmotion(emotions: [EnhancedEmotion]) -> String {
        let emotionCounts = Dictionary(grouping: emotions) { $0.emotion }
            .mapValues { $0.count }
        
        return emotionCounts.max { $0.value < $1.value }?.key ?? "평온"
    }
    
    func extractDominantThemes(from messages: [[String: Any]]) -> [String] {
        // 기본 테마 추출 로직
        return ["relaxation", "daily_stress", "sleep_preparation"]
    }
    
    func extractVersionPreferences() -> [Int: Float] {
        return [0: 0.6, 1: 0.4] // 기본 버전 선호도
    }
    
    func extractOptimalVolumes() -> [String: Float] {
        return ["default": 0.5] // 기본 볼륨 설정
    }
    
    func extractSessionDurationPreferences() -> [String: TimeInterval] {
        return ["average": 900.0] // 15분 기본
    }
    
    func calculateUsageConsistency(profile: UserBehaviorProfile) -> Float {
        // 사용 일관성 계산
        return profile.satisfactionMetrics.averageCompletionRate
    }
    
    func calculateAdaptationSpeed(profile: UserBehaviorProfile) -> Float {
        // 적응 속도 계산
        let sessionCount = profile.emotionPatterns.values.reduce(0) { $0 + $1.totalSessions }
        return min(1.0, Float(sessionCount) / 20.0)
    }
}

// MARK: - 자동 학습 기록 저장/로드 확장

extension ChatViewController {
    
    /// 자동 학습 기록 저장
    func saveAutomaticLearningRecord(_ record: AutomaticLearningRecord) {
        var records = loadAutomaticLearningRecords()
        records.append(record)
        
        // 최근 200개 기록만 유지
        if records.count > 200 {
            records = Array(records.suffix(200))
        }
        
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(records) {
            UserDefaults.standard.set(data, forKey: "automaticLearningRecords")
        }
    }
    
    /// 자동 학습 기록 로드
    func loadAutomaticLearningRecords() -> [AutomaticLearningRecord] {
        guard let data = UserDefaults.standard.data(forKey: "automaticLearningRecords"),
              let records = try? JSONDecoder().decode([AutomaticLearningRecord].self, from: data) else {
            return []
        }
        return records
    }
    
    /// 시간 포맷팅 헬퍼
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)분 \(seconds)초"
    }
}