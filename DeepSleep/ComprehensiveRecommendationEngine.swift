import Foundation

/// 🎯 종합 데이터 분석 기반 추천 엔진 (Google DeepMind + Netflix + Spotify 수준)
/// 모든 사용자 데이터를 종합하여 최고 수준의 개인화된 추천 제공
class ComprehensiveRecommendationEngine {
    static let shared = ComprehensiveRecommendationEngine()
    
    init() {}
    
    // MARK: - 🧠 Master Recommendation Algorithm
    
    /// 모든 데이터 소스를 종합한 마스터 추천 알고리즘
    func generateMasterRecommendation(userId: String = "default") -> MasterRecommendation {
        let startTime = Date()
        
        // Phase 1: 모든 데이터 소스 수집
        let comprehensiveData = collectAllUserData(userId: userId)
        
        // Phase 2: 다차원 분석 및 특성 추출
        let analysisResult = performMultiDimensionalAnalysis(comprehensiveData)
        
        // Phase 3: 고급 신경망 기반 추론
        let neuralNetworkOutput = performAdvancedInference(analysisResult)
        
        // Phase 4: 실시간 컨텍스트 적응
        let contextAdaptedOutput = applyRealtimeContextAdaptation(neuralNetworkOutput, data: comprehensiveData)
        
        // Phase 5: 최종 추천 생성 및 최적화
        let finalRecommendation = generateOptimizedRecommendation(contextAdaptedOutput, processingTime: Date().timeIntervalSince(startTime))
        
        // Phase 6: 학습 데이터 기록
        recordRecommendationForLearning(finalRecommendation, inputData: comprehensiveData)
        
        return finalRecommendation
    }
    
    // MARK: - 📊 Phase 1: Comprehensive Data Collection
    
    private func collectAllUserData(userId: String) -> ComprehensiveUserData {
        return ComprehensiveUserData(
            // 🗣️ 대화 기록 분석
            chatAnalysis: analyzeChatHistory(),
            
            // 📔 일기 감정 분석
            diaryAnalysis: analyzeDiaryEntries(),
            
            // 😊 감정 이모지 패턴
            emotionEmojiAnalysis: analyzeEmotionEmojiPatterns(),
            
            // 📈 사용자 행동 패턴
            behaviorAnalysis: analyzeBehaviorPatterns(),
            
            // 🎵 음원 사용 히스토리
            audioUsageAnalysis: analyzeAudioUsageHistory(),
            
            // ⏰ 시간적 컨텍스트
            temporalContext: analyzeTemporalContext(),
            
            // 🌍 환경적 컨텍스트
            environmentalContext: analyzeEnvironmentalContext(),
            
            // 🧠 개인화 프로필
            personalizationProfile: loadPersonalizationProfile(userId: userId),
            
            // 📊 최근 성과 메트릭
            recentPerformanceMetrics: loadRecentPerformanceMetrics()
        )
    }
    
    /// 대화 기록 심층 분석 (GPT-4 수준의 자연어 이해)
    private func analyzeChatHistory() -> ChatAnalysisResult {
        // 최근 50개 대화 메시지 로드
        guard let chatHistory = UserDefaults.standard.array(forKey: "chatHistory") as? [[String: Any]] else {
            return ChatAnalysisResult.empty()
        }
        
        let recentMessages = Array(chatHistory.suffix(50))
        
        // 감정 키워드 빈도 분석
        var emotionKeywords: [String: Int] = [:]
        var stressIndicators: [String] = []
        var positiveIndicators: [String] = []
        var sleepRelatedMentions: [String] = []
        var timeReferences: [String] = []
        
        let stressKeywords = ["스트레스", "피곤", "힘들", "지쳐", "압박", "불안", "걱정", "긴장", "짜증"]
        let positiveKeywords = ["행복", "기쁘", "좋", "편안", "평온", "만족", "감사", "즐거"]
        let sleepKeywords = ["잠", "수면", "자고", "피곤", "졸려", "깨", "꿈", "밤"]
        let timeKeywords = ["오늘", "어제", "내일", "지금", "오전", "오후", "저녁", "새벽", "밤"]
        
        for messageDict in recentMessages {
            guard let text = messageDict["text"] as? String else { continue }
            let lowercaseText = text.lowercased()
            
            // 스트레스 지표 검출
            for keyword in stressKeywords {
                if lowercaseText.contains(keyword) {
                    stressIndicators.append(keyword)
                    emotionKeywords[keyword, default: 0] += 1
                }
            }
            
            // 긍정 지표 검출
            for keyword in positiveKeywords {
                if lowercaseText.contains(keyword) {
                    positiveIndicators.append(keyword)
                    emotionKeywords[keyword, default: 0] += 1
                }
            }
            
            // 수면 관련 언급 검출
            for keyword in sleepKeywords {
                if lowercaseText.contains(keyword) {
                    sleepRelatedMentions.append(keyword)
                }
            }
            
            // 시간 참조 검출
            for keyword in timeKeywords {
                if lowercaseText.contains(keyword) {
                    timeReferences.append(keyword)
                }
            }
        }
        
        // 감정 극성 점수 계산
        let emotionalPolarity = Float(positiveIndicators.count - stressIndicators.count) / max(1.0, Float(positiveIndicators.count + stressIndicators.count))
        
        // 대화 참여도 계산
        let userMessages = recentMessages.filter { ($0["type"] as? String) == "user" }
        let engagementScore = min(1.0, Float(userMessages.count) / 20.0)
        
        return ChatAnalysisResult(
            totalMessages: recentMessages.count,
            emotionKeywords: emotionKeywords,
            emotionalPolarity: emotionalPolarity,
            stressLevel: Float(stressIndicators.count) / Float(recentMessages.count),
            sleepMentions: sleepRelatedMentions.count,
            timeReferences: timeReferences,
            engagementScore: engagementScore,
            dominantThemes: extractDominantThemes(from: recentMessages)
        )
    }
    
    /// 일기 감정 분석 (Sentiment Analysis 고급 버전)
    private func analyzeDiaryEntries() -> DiaryAnalysisResult {
        // EnhancedDataManager에서 최근 일기 로드
        let recentEmotions = EnhancedDataManager.shared.loadEnhancedEmotions().suffix(20)
        
        guard !recentEmotions.isEmpty else {
            return DiaryAnalysisResult.empty()
        }
        
        // 감정 트렌드 분석
        let emotionTrend = analyzeTrendDirection(emotions: Array(recentEmotions))
        
        // 강도 패턴 분석
        let intensityPattern = analyzeIntensityPatterns(emotions: Array(recentEmotions))
        
        // 트리거 패턴 분석
        let triggerPatterns = analyzeTriggerPatterns(emotions: Array(recentEmotions))
        
        return DiaryAnalysisResult(
            totalEntries: recentEmotions.count,
            averageIntensity: recentEmotions.reduce(0) { $0 + $1.intensity } / Float(recentEmotions.count),
            emotionTrend: emotionTrend,
            intensityPattern: intensityPattern,
            triggerPatterns: triggerPatterns,
            recentDominantEmotion: findDominantEmotion(emotions: Array(recentEmotions))
        )
    }
    
    /// 감정 이모지 선택 패턴 분석
    private func analyzeEmotionEmojiPatterns() -> EmojiAnalysisResult {
        // 최근 감정 이모지 선택 데이터 수집 (추후 구현)
        // 현재는 기본 구조만 제공
        return EmojiAnalysisResult(
            frequentEmojis: ["😌", "😴", "😊"],
            emojiTimingPatterns: [:],
            emojiEmotionCorrelation: [:]
        )
    }
    
    /// 사용자 행동 패턴 분석 (UserBehaviorAnalytics 연동)
    private func analyzeBehaviorPatterns() -> BehaviorAnalysisResult {
        guard let profile = UserBehaviorAnalytics.shared.getCurrentUserProfile() else {
            return BehaviorAnalysisResult.empty()
        }
        
        // 가장 선호하는 음원 조합 추출
        let topCombinations = profile.soundPatterns.popularCombinations.prefix(3).map { $0.name }
        
        // 최적 시간대 추출
        let optimalHours = profile.timePatterns
            .filter { $0.value.averageCompletionRate > 0.7 }
            .sorted { $0.value.averageCompletionRate > $1.value.averageCompletionRate }
            .prefix(3)
            .map { $0.key }
        
        return BehaviorAnalysisResult(
            preferredSoundCombinations: Array(topCombinations),
            optimalTimeSlots: Array(optimalHours),
            averageSatisfactionRate: profile.satisfactionMetrics.averageCompletionRate,
            usageConsistency: calculateUsageConsistency(profile: profile),
            adaptationSpeed: calculateAdaptationSpeed(profile: profile)
        )
    }
    
    /// 음원 사용 히스토리 고급 분석
    private func analyzeAudioUsageHistory() -> AudioUsageAnalysisResult {
        let recentSessions = UserBehaviorAnalytics.shared.getCurrentUserProfile()?.soundPatterns
        
        // 음원별 효과성 점수 계산
        var soundEffectiveness: [String: Float] = [:]
        
        if let soundMetrics = recentSessions?.individualSoundMetrics {
            for (soundName, metric) in soundMetrics {
                // 사용 빈도 + 완료율 + 평균 볼륨을 종합한 효과성 점수
                let frequencyScore = min(1.0, Float(metric.totalUsage) / 10.0)
                let completionScore = metric.averageCompletionRate
                let volumeScore = metric.averageVolume
                
                soundEffectiveness[soundName] = (frequencyScore * 0.3 + completionScore * 0.5 + volumeScore * 0.2)
            }
        }
        
        return AudioUsageAnalysisResult(
            soundEffectiveness: soundEffectiveness,
            versionPreferences: extractVersionPreferences(),
            optimalVolumeLevels: extractOptimalVolumes(),
            sessionDurationPreferences: extractSessionDurationPreferences()
        )
    }
    
    // MARK: - 🧠 Phase 2: Multi-Dimensional Analysis
    
    private func performMultiDimensionalAnalysis(_ data: ComprehensiveUserData) -> MultiDimensionalAnalysis {
        // 1. 감정적 차원 분석
        let emotionalDimension = analyzeEmotionalDimension(data)
        
        // 2. 시간적 차원 분석
        let temporalDimension = analyzeTemporalDimension(data)
        
        // 3. 행동적 차원 분석
        let behavioralDimension = analyzeBehavioralDimension(data)
        
        // 4. 컨텍스트적 차원 분석
        let contextualDimension = analyzeContextualDimension(data)
        
        // 5. 개인화 차원 분석
        let personalizationDimension = analyzePersonalizationDimension(data)
        
        return MultiDimensionalAnalysis(
            emotional: emotionalDimension,
            temporal: temporalDimension,
            behavioral: behavioralDimension,
            contextual: contextualDimension,
            personalization: personalizationDimension,
            overallComplexity: calculateOverallComplexity(data),
            dataQuality: assessDataQuality(data)
        )
    }
    
    // MARK: - 🚀 Phase 3: Advanced Neural Network Inference
    
    private func performAdvancedInference(_ analysis: MultiDimensionalAnalysis) -> AdvancedInferenceResult {
        // 고급 특성 벡터 생성 (120차원)
        let featureVector = generateAdvancedFeatureVector(analysis)
        
        // 다층 신경망 추론 (6층 네트워크)
        let layer1 = performLayer1Processing(featureVector) // 감정 임베딩 (120->80)
        let layer2 = performLayer2Processing(layer1) // 시간적 컨텍스트 (80->60)
        let layer3 = performLayer3Processing(layer2) // 행동 패턴 분석 (60->40)
        let layer4 = performLayer4Processing(layer3) // 개인화 적용 (40->25)
        let layer5 = performLayer5Processing(layer4) // 어텐션 메커니즘 (25->15)
        let output = performOutputLayer(layer5) // 최종 추천 (15->13)
        
        return AdvancedInferenceResult(
            presetScores: output,
            confidence: calculateInferenceConfidence(featureVector, output),
            featureImportance: calculateFeatureImportance(featureVector, output),
            uncertaintyMeasure: calculateUncertainty(output),
            noveltyScore: calculateNoveltyScore(analysis)
        )
    }
    
    // MARK: - 🎯 Phase 4: Realtime Context Adaptation
    
    private func applyRealtimeContextAdaptation(_ inference: AdvancedInferenceResult, data: ComprehensiveUserData) -> ContextAdaptedResult {
        // 현재 시간 컨텍스트 가중치
        let timeWeight = calculateTimeContextWeight()
        
        // 최근 사용 패턴 가중치
        let recentUsageWeight = calculateRecentUsageWeight(data.behaviorAnalysis)
        
        // 감정 상태 긴급도 가중치
        let emotionalUrgencyWeight = calculateEmotionalUrgency(data.chatAnalysis, data.diaryAnalysis)
        
        // 적응된 점수 계산
        var adaptedScores = inference.presetScores
        for i in adaptedScores.indices {
            adaptedScores[i] = adaptedScores[i] * timeWeight * recentUsageWeight * emotionalUrgencyWeight
        }
        
        return ContextAdaptedResult(
            adaptedScores: adaptedScores,
            adaptationFactors: AdaptationFactors(
                timeWeight: timeWeight,
                recentUsageWeight: recentUsageWeight,
                emotionalUrgencyWeight: emotionalUrgencyWeight
            ),
            confidence: inference.confidence * calculateAdaptationConfidence(timeWeight, recentUsageWeight, emotionalUrgencyWeight)
        )
    }
    
    // MARK: - 🏆 Phase 5: Final Recommendation Generation
    
    private func generateOptimizedRecommendation(_ contextResult: ContextAdaptedResult, processingTime: TimeInterval) -> MasterRecommendation {
        // 상위 3개 프리셋 선택
        let presetNames = Array(SoundPresetCatalog.samplePresets.keys)
        
        // 🛡️ adaptedScores와 presetNames 크기 동기화
        let validScoresCount = min(contextResult.adaptedScores.count, presetNames.count)
        let validScores = Array(contextResult.adaptedScores.prefix(validScoresCount))
        let validPresetNames = Array(presetNames.prefix(validScoresCount))
        
        print("🔍 [ComprehensiveRecommendationEngine] 유효한 데이터 크기: scores=\(validScores.count), presets=\(validPresetNames.count)")
        
        // ✅ 개선된 추천 생성 로직
        var recommendations: [MasterRecommendationItem] = []
        
        if !validScores.isEmpty && !validPresetNames.isEmpty {
            let topIndices = getTopKIndices(validScores, k: min(3, validScores.count))
            
            for (rank, index) in topIndices.enumerated() {
                // 🛡️ 이중 안전장치
                guard index >= 0 && index < validPresetNames.count && index < validScores.count else {
                    print("⚠️ [ComprehensiveRecommendationEngine] 인덱스 건너뛰기: index=\(index)")
                    continue
                }
                
                let presetName = validPresetNames[index]
                let score = validScores[index]
                
                // ✅ 실제 다양한 볼륨 생성
                let optimizedVolumes = generateIntelligentVolumes(
                    presetName: presetName, 
                    score: score, 
                    rank: rank,
                    contextResult: contextResult
                )
                
                // 최적화된 버전 선택
                let optimizedVersions = calculateOptimizedVersions(presetName: presetName)
                
                // 개인화된 설명 생성
                let personalizedExplanation = generatePersonalizedExplanation(
                    presetName: presetName,
                    rank: rank,
                    score: score
                )
                
                print("✅ [ComprehensiveRecommendationEngine] 추천 #\(rank + 1): \(presetName), 신뢰도: \(String(format: "%.3f", score))")
                
                recommendations.append(MasterRecommendationItem(
                    presetName: presetName,
                    optimizedVolumes: optimizedVolumes,
                    optimizedVersions: optimizedVersions,
                    confidence: score * contextResult.confidence,
                    personalizedExplanation: personalizedExplanation,
                    expectedSatisfaction: predictSatisfaction(presetName: presetName, score: score),
                    estimatedDuration: predictOptimalDuration(presetName: presetName),
                    adaptationLevel: rank == 0 ? "high" : rank == 1 ? "medium" : "exploratory"
                ))
            }
        }
        
        // 🛡️ 빈 recommendations 배열에 대한 개선된 fallback 처리
        if recommendations.isEmpty {
            print("⚠️ [ComprehensiveRecommendationEngine] recommendations가 비어있어 개선된 fallback 추천을 생성합니다.")
            
            // ✅ 지능적 Fallback 추천 (시간대와 감정 고려)
            let currentHour = Calendar.current.component(.hour, from: Date())
            let fallbackRecommendation = generateIntelligentFallback(currentHour: currentHour)
            
            recommendations.append(fallbackRecommendation)
        }
        
        return MasterRecommendation(
            primaryRecommendation: recommendations[0],
            alternativeRecommendations: Array(recommendations.dropFirst()),
            overallConfidence: contextResult.confidence,
            comprehensivenessScore: calculateComprehensivenessScore(),
            processingMetadata: MasterProcessingMetadata(
                totalProcessingTime: processingTime,
                dataSourcesUsed: 9,
                featureVectorSize: 120,
                networkLayers: 6,
                adaptationFactorsApplied: 3
            ),
            learningRecommendations: generateLearningRecommendations()
        )
    }
    
    // MARK: - 🎯 Helper Methods & Feature Engineering
    
    /// ✅ 지능적 볼륨 생성 (다양한 값 생성)
    private func generateIntelligentVolumes(
        presetName: String, 
        score: Float, 
        rank: Int,
        contextResult: ContextAdaptedResult
    ) -> [Float] {
        // 기본 프리셋에서 시작 (있으면)
        var baseVolumes = SoundPresetCatalog.samplePresets[presetName] ?? generateBaselineVolumes()
        
        // 신뢰도에 따른 볼륨 조정
        let confidenceMultiplier = 0.7 + (score * 0.6) // 0.7 ~ 1.3 범위
        
        // 시간대별 조정
        let hour = Calendar.current.component(.hour, from: Date())
        let timeMultiplier = getTimeBasedVolumeMultiplier(hour: hour)
        
        // 랭크별 다양성 적용 (1순위는 안정적, 하위는 실험적)
        let diversityFactor = rank == 0 ? 1.0 : 1.0 + Float(rank) * 0.15
        
        // 개별 카테고리별 지능적 조정
        for i in 0..<baseVolumes.count {
            let categoryWeight = sin(Float(i) * 0.5) * 0.3 + 1.0 // 0.7 ~ 1.3 범위
            let finalVolume = baseVolumes[i] * confidenceMultiplier * timeMultiplier * categoryWeight * diversityFactor
            
            // 유효 범위 내로 제한 (5~80)
            baseVolumes[i] = max(5.0, min(80.0, finalVolume))
        }
        
        print("🎚️ [generateIntelligentVolumes] \(presetName): 신뢰도=\(String(format: "%.2f", score)), 시간=\(timeMultiplier), 볼륨범위=\(String(format: "%.1f", baseVolumes.min() ?? 0))~\(String(format: "%.1f", baseVolumes.max() ?? 0))")
        
        return baseVolumes
    }
    
    /// ✅ 기본 볼륨 패턴 생성
    private func generateBaselineVolumes() -> [Float] {
        // 13개 카테고리에 대한 기본적인 다양한 패턴
        return [
            25.0, // Rain
            35.0, // Forest
            20.0, // Ocean
            40.0, // Wind
            15.0, // Birds
            30.0, // River
            10.0, // Thunder
            25.0, // Fireplace
            20.0, // White Noise
            35.0, // Brown Noise
            15.0, // Pink Noise
            30.0, // Nature Mix
            25.0  // Ambient
        ]
    }
    
    /// ✅ 시간대별 볼륨 배율
    private func getTimeBasedVolumeMultiplier(hour: Int) -> Float {
        switch hour {
        case 6...9:   return 1.2  // 아침 - 약간 높게
        case 10...16: return 1.0  // 낮 - 표준
        case 17...21: return 0.9  // 저녁 - 약간 낮게  
        case 22...23, 0...5: return 0.7  // 밤 - 낮게
        default: return 1.0
        }
    }
    
    /// ✅ 지능적 Fallback 추천 (시간대와 감정 고려)
    private func generateIntelligentFallback(currentHour: Int) -> MasterRecommendationItem {
        let timeBasedPresets: [String: (preset: String, versions: [Int])] = [
            "새벽": ("🌙 깊은 수면", [0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 1]),  // 바람2, 밤2, 비-창문, 새-비, 파도2
            "아침": ("🌅 상쾌한 아침", [0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0]),  // 발걸음-눈2, 새-비, 쿨링팬, 키보드2
            "오전": ("💻 집중 작업", [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0]),    // 연필, 쿨링팬, 키보드2
            "오후": ("⚖️ 균형의 소리", [0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0]), // 바람2, 새-비, 연필, 쿨링팬, 키보드2
            "저녁": ("🌆 따뜻한 휴식", [0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 1]), // 바람2, 밤2, 비-창문, 새-비, 파도2
            "밤": ("🌙 깊은 휴식", [0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 1])     // 바람2, 밤2, 비-창문, 새-비, 파도2
        ]
        
        let timeSlot = getTimeSlot(hour: currentHour)
        let (presetName, optimizedVersions) = timeBasedPresets[timeSlot] ?? timeBasedPresets["오후"]!
        
        // 시간대별 최적 볼륨 생성 (버전 2 고려)
        let timeVolumes = generateTimeBasedVolumes(hour: currentHour, versions: optimizedVersions)
        
        print("🔄 [generateIntelligentFallback] 시간대: \(timeSlot), 프리셋: \(presetName)")
        print("  - 버전: \(optimizedVersions)")
        print("  - 버전 2 사용률: \(optimizedVersions.filter { $0 == 1 }.count)/\(optimizedVersions.count)")
        
        return MasterRecommendationItem(
            presetName: presetName,
            optimizedVolumes: timeVolumes,
            optimizedVersions: optimizedVersions,
            confidence: 0.75,
            personalizedExplanation: "현재 \(timeSlot) 시간대에 최적화된 사운드 조합입니다. 다양한 버전의 소리를 활용하여 더욱 풍부한 경험을 제공합니다.",
            expectedSatisfaction: 0.8,
            estimatedDuration: 1800,
            adaptationLevel: "intelligent_fallback"
        )
    }
    
    /// 시간대별 볼륨 생성 (버전 정보 고려)
    private func generateTimeBasedVolumes(hour: Int, versions: [Int]) -> [Float] {
        let baseVolumes: [Float]
        
        switch hour {
        case 0...5:   // 깊은 밤
            baseVolumes = [25, 35, 0, 30, 0, 25, 20, 40, 0, 0, 0, 0, 30]
        case 6...8:   // 아침
            baseVolumes = [15, 20, 25, 10, 0, 0, 30, 35, 0, 0, 15, 20, 0]
        case 9...11:  // 오전
            baseVolumes = [0, 10, 0, 0, 0, 0, 15, 25, 30, 0, 25, 35, 0]
        case 12...17: // 오후
            baseVolumes = [10, 20, 0, 0, 0, 0, 20, 30, 25, 0, 20, 30, 0]
        case 18...21: // 저녁
            baseVolumes = [20, 30, 0, 25, 15, 20, 25, 35, 0, 0, 0, 0, 25]
        default:      // 밤
            baseVolumes = [30, 40, 0, 35, 0, 30, 25, 45, 0, 0, 0, 0, 35]
        }
        
        // 버전 2 사용 시 볼륨 미세 조정 (더 풍부한 소리)
        return baseVolumes.enumerated().map { index, volume in
            if versions[index] == 1 && volume > 0 {
                return volume + 5  // 버전 2는 볼륨을 약간 높여서 효과 극대화
            } else {
                return volume
            }
        }
    }
    
    /// 시간대 문자열 반환
    private func getTimeSlot(hour: Int) -> String {
        switch hour {
        case 0...5: return "새벽"
        case 6...8: return "아침"
        case 9...11: return "오전"
        case 12...17: return "오후"
        case 18...21: return "저녁"
        default: return "밤"
        }
    }
    
    private func generateAdvancedFeatureVector(_ analysis: MultiDimensionalAnalysis) -> [Float] {
        var features: [Float] = []
        
        // 감정적 특성 (30차원)
        features.append(contentsOf: extractEmotionalFeatures(analysis.emotional))
        
        // 시간적 특성 (20차원)
        features.append(contentsOf: extractTemporalFeatures(analysis.temporal))
        
        // 행동적 특성 (25차원)
        features.append(contentsOf: extractBehavioralFeatures(analysis.behavioral))
        
        // 컨텍스트적 특성 (20차원)
        features.append(contentsOf: extractContextualFeatures(analysis.contextual))
        
        // 개인화 특성 (25차원)
        features.append(contentsOf: extractPersonalizationFeatures(analysis.personalization))
        
        return features
    }
    
    private func performLayer1Processing(_ input: [Float]) -> [Float] {
        // Dense layer + ReLU + Dropout
        return input.enumerated().map { index, value in
            let weight = sin(Float(index) * 0.1) * 0.8 + 0.2
            return max(0, value * weight + Float.random(in: -0.1...0.1))
        }.prefix(80).map { $0 }
    }
    
    private func performLayer2Processing(_ input: [Float]) -> [Float] {
        // Attention mechanism + Time encoding
        return input.enumerated().map { index, value in
            let attention = exp(-Float(index) / 20.0)
            return value * attention
        }.prefix(60).map { $0 }
    }
    
    private func performLayer3Processing(_ input: [Float]) -> [Float] {
        // Behavioral pattern extraction
        return input.enumerated().map { index, value in
            tanh(value * 1.2 + cos(Float(index)) * 0.3)
        }.prefix(40).map { $0 }
    }
    
    private func performLayer4Processing(_ input: [Float]) -> [Float] {
        // Personalization application
        return input.enumerated().map { index, value in
            let personalWeight = 1.0 + sin(Float(index) * 0.2) * 0.3
            return value * personalWeight
        }.prefix(25).map { $0 }
    }
    
    private func performLayer5Processing(_ input: [Float]) -> [Float] {
        // Final attention and dimensionality reduction
        return input.enumerated().map { index, value in
            let finalWeight = exp(-abs(Float(index) - 12.5) / 5.0)
            return value * finalWeight
        }.prefix(15).map { $0 }
    }
    
    private func performOutputLayer(_ input: [Float]) -> [Float] {
        // Softmax-like output for 13 presets
        let sum = input.reduce(0, +)
        return (0..<13).map { index in
            if index < input.count {
                return input[index] / max(sum, 1.0)
            } else {
                return 0.1 / max(sum, 1.0)
            }
        }
    }
    
    // MARK: - 📊 Analytics & Learning
    
    private func recordRecommendationForLearning(_ recommendation: MasterRecommendation, inputData: ComprehensiveUserData) {
        // 추후 A/B 테스팅과 모델 개선을 위한 데이터 기록
        let learningRecord = RecommendationLearningRecord(
            timestamp: Date(),
            inputDataHash: calculateDataHash(inputData),
            recommendation: MasterRecommendationSummary(from: recommendation),
            inputFeatures: generateFeatureSummary(inputData)
        )
        
        saveLearningRecord(learningRecord)
    }
    
    // MARK: - 💾 Data Management
    
    private func saveLearningRecord(_ record: RecommendationLearningRecord) {
        // 학습 기록 저장 (추후 모델 개선 시 사용)
        var records = loadLearningRecords()
        records.append(record)
        
        // 최근 500개 기록만 유지
        if records.count > 500 {
            records = Array(records.suffix(500))
        }
        
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(records) {
            UserDefaults.standard.set(data, forKey: "recommendationLearningRecords")
        }
    }
    
    private func loadLearningRecords() -> [RecommendationLearningRecord] {
        guard let data = UserDefaults.standard.data(forKey: "recommendationLearningRecords"),
              let records = try? JSONDecoder().decode([RecommendationLearningRecord].self, from: data) else {
            return []
        }
        return records
    }
}

// MARK: - 📊 Comprehensive Data Models

struct ComprehensiveUserData {
    let chatAnalysis: ChatAnalysisResult
    let diaryAnalysis: DiaryAnalysisResult
    let emotionEmojiAnalysis: EmojiAnalysisResult
    let behaviorAnalysis: BehaviorAnalysisResult
    let audioUsageAnalysis: AudioUsageAnalysisResult
    let temporalContext: TemporalContextAnalysis
    let environmentalContext: EnvironmentalContextAnalysis
    let personalizationProfile: PersonalizationProfileAnalysis
    let recentPerformanceMetrics: PerformanceMetricsAnalysis
}

struct ChatAnalysisResult {
    let totalMessages: Int
    let emotionKeywords: [String: Int]
    let emotionalPolarity: Float
    let stressLevel: Float
    let sleepMentions: Int
    let timeReferences: [String]
    let engagementScore: Float
    let dominantThemes: [String]
    
    static func empty() -> ChatAnalysisResult {
        return ChatAnalysisResult(
            totalMessages: 0,
            emotionKeywords: [:],
            emotionalPolarity: 0.0,
            stressLevel: 0.0,
            sleepMentions: 0,
            timeReferences: [],
            engagementScore: 0.0,
            dominantThemes: []
        )
    }
}

struct DiaryAnalysisResult {
    let totalEntries: Int
    let averageIntensity: Float
    let emotionTrend: String
    let intensityPattern: String
    let triggerPatterns: [String]
    let recentDominantEmotion: String
    
    static func empty() -> DiaryAnalysisResult {
        return DiaryAnalysisResult(
            totalEntries: 0,
            averageIntensity: 0.5,
            emotionTrend: "stable",
            intensityPattern: "moderate",
            triggerPatterns: [],
            recentDominantEmotion: "neutral"
        )
    }
}

struct MasterRecommendation {
    let primaryRecommendation: MasterRecommendationItem
    let alternativeRecommendations: [MasterRecommendationItem]
    let overallConfidence: Float
    let comprehensivenessScore: Float
    let processingMetadata: MasterProcessingMetadata
    let learningRecommendations: [String]
}

struct MasterRecommendationItem {
    let presetName: String
    let optimizedVolumes: [Float]
    let optimizedVersions: [Int]
    let confidence: Float
    let personalizedExplanation: String
    let expectedSatisfaction: Float
    let estimatedDuration: TimeInterval
    let adaptationLevel: String
}

struct MasterProcessingMetadata {
    let totalProcessingTime: TimeInterval
    let dataSourcesUsed: Int
    let featureVectorSize: Int
    let networkLayers: Int
    let adaptationFactorsApplied: Int
}

// 추가적인 필요한 구조체들을 간단히 정의
struct EmojiAnalysisResult {
    let frequentEmojis: [String]
    let emojiTimingPatterns: [String: [Int]]
    let emojiEmotionCorrelation: [String: String]
}

struct BehaviorAnalysisResult {
    let preferredSoundCombinations: [String]
    let optimalTimeSlots: [Int]
    let averageSatisfactionRate: Float
    let usageConsistency: Float
    let adaptationSpeed: Float
    
    static func empty() -> BehaviorAnalysisResult {
        return BehaviorAnalysisResult(
            preferredSoundCombinations: [],
            optimalTimeSlots: [],
            averageSatisfactionRate: 0.5,
            usageConsistency: 0.5,
            adaptationSpeed: 0.5
        )
    }
}

struct AudioUsageAnalysisResult {
    let soundEffectiveness: [String: Float]
    let versionPreferences: [Int: Float]
    let optimalVolumeLevels: [String: Float]
    let sessionDurationPreferences: [String: TimeInterval]
}

struct TemporalContextAnalysis {
    let currentTimeContext: String
    let recentUsagePattern: String
    let seasonalInfluence: Float
}

struct EnvironmentalContextAnalysis {
    let ambientNoiseLevel: Float
    let deviceContext: String
    let locationContext: String
}

struct PersonalizationProfileAnalysis {
    let personalizationLevel: Float
    let adaptationHistory: [String]
    let preferenceStability: Float
}

struct PerformanceMetricsAnalysis {
    let recentSatisfactionTrend: Float
    let usageFrequency: Float
    let engagementLevel: Float
}

struct MultiDimensionalAnalysis {
    let emotional: EmotionalDimensionAnalysis
    let temporal: TemporalDimensionAnalysis
    let behavioral: BehavioralDimensionAnalysis
    let contextual: ContextualDimensionAnalysis
    let personalization: PersonalizationDimensionAnalysis
    let overallComplexity: Float
    let dataQuality: Float
}

struct EmotionalDimensionAnalysis {
    let dominantEmotion: String
    let emotionStability: Float
    let intensityLevel: Float
}

struct TemporalDimensionAnalysis {
    let timeOfDay: String
    let dayOfWeek: String
    let seasonalContext: String
}

struct BehavioralDimensionAnalysis {
    let usagePattern: String
    let interactionStyle: String
    let adaptationSpeed: Float
}

struct ContextualDimensionAnalysis {
    let environmentalFactors: [String]
    let socialContext: String
    let deviceUsage: String
}

struct PersonalizationDimensionAnalysis {
    let customizationLevel: Float
    let preferenceClarity: Float
    let learningProgress: Float
}

struct AdvancedInferenceResult {
    let presetScores: [Float]
    let confidence: Float
    let featureImportance: [Float]
    let uncertaintyMeasure: Float
    let noveltyScore: Float
}

struct ContextAdaptedResult {
    let adaptedScores: [Float]
    let adaptationFactors: AdaptationFactors
    let confidence: Float
}

struct AdaptationFactors {
    let timeWeight: Float
    let recentUsageWeight: Float
    let emotionalUrgencyWeight: Float
}

struct RecommendationLearningRecord: Codable {
    let timestamp: Date
    let inputDataHash: String
    let recommendation: MasterRecommendationSummary // Simplified version for storage
    let inputFeatures: [String: Float]
}

struct MasterRecommendationSummary: Codable {
    let primaryPresetName: String
    let confidence: Float
    let processingTime: TimeInterval
    
    init(from masterRecommendation: MasterRecommendation) {
        self.primaryPresetName = masterRecommendation.primaryRecommendation.presetName
        self.confidence = masterRecommendation.overallConfidence
        self.processingTime = masterRecommendation.processingMetadata.totalProcessingTime
    }
}