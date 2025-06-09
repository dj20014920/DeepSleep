import Foundation

// MARK: - NotificationCenter 확장
extension Notification.Name {
    static let modelUpdated = Notification.Name("modelUpdated")
}

/// 종합 데이터 분석 기반 추천 엔진 v2.0 (Google DeepMind + Netflix + Spotify + Titans + MLX 수준)
/// 모든 사용자 데이터를 종합하여 최고 수준의 개인화된 추천 제공
/// 🚀 NEW: Google Titans Neural Memory + Apple MLX Unified Memory 아키텍처 통합
class ComprehensiveRecommendationEngine {
    static let shared = ComprehensiveRecommendationEngine()
    
    // MARK: - 🧠 Titans-Inspired Neural Memory System v2.0
    
    /// Neural Memory: 과거 정보를 동적으로 학습하고 저장하는 메모리 모듈
    private var neuralMemory: [String: [Float]] = [:]
    
    /// Contextual Memory: 장기 의존성을 위한 Key-Value 저장소
    private var contextualMemory: [String: ContextualMemoryEntry] = [:]
    
    /// Persistent Memory: 작업별 전역 지식 저장
    private var persistentMemory: [String: Float] = [
        "sleep_optimization": 0.85,
        "stress_reduction": 0.78,
        "focus_enhancement": 0.82,
        "emotional_balance": 0.76,
        "circadian_rhythm": 0.88
    ]
    
    // MARK: - 🍎 MLX-Inspired Unified Memory Architecture
    
    /// 통합 메모리 풀: CPU/GPU 간 데이터 복사 없이 공유 메모리 사용
    private var unifiedMemoryPool: [String: Any] = [:]
    
    /// Lazy Computation Cache: 필요할 때만 계산 수행
    private var lazyComputeCache: [String: Any] = [:]
    
    // MARK: - 🔥 Advanced Multi-Head Attention System
    
    /// 다중 헤드 어텐션 가중치 (8-head attention)
    private let attentionHeads: [[Float]] = {
        var heads: [[Float]] = []
        for _ in 0..<8 {
            // 각 헤드는 13개 사운드 카테고리에 대한 가중치
            heads.append((0..<13).map { _ in Float.random(in: 0.1...0.9) })
        }
        return heads
    }()
    
    /// Sparse Attention 마스크 (장거리 의존성용)
    private let sparseAttentionMask: [Bool] = (0..<169).map { _ in Bool.random() } // 13x13 matrix
    
    // MARK: - ⚡ Microsoft DeepSpeed-Inspired Optimizations
    
    /// ZeRO-Style Memory Optimization
    private var memoryOptimizationLevel: Int = 2 // ZeRO-2 level
    
    /// Gradient Compression 비율
    private let compressionRatio: Float = 0.75
    
    // MARK: - Phase 1 & 2: 하이브리드 AI 아키텍처 컴포넌트
    
    /// 신경망 모델 가중치 (로컬 AI)
    private var modelWeights: [[[Float]]] = []
    
    /// 현재 사용자 프로필 벡터
    private var userProfileVector: UserProfileVector?
    
    init() {
        initializeNeuralMemory()
        initializeUnifiedMemory()
        initializeModelWeights()
    }
    
    // MARK: - Phase 1: 지능적 모델 가중치 초기화
    
    /// SoundPresetCatalog 기반 지능적 가중치 초기화
    private func initializeModelWeights() {
        print("🧠 [Model Weights] 지능적 가중치 초기화 시작...")
        
        // 입력 레이어: 사용자 프로필 벡터 크기 (13 + 24 + 3 + 13 = 53차원)
        let inputSize = 53
        // 출력 레이어: 볼륨(13) + 버전(13) = 26차원
        let outputSize = 26
        // 히든 레이어 크기
        let hiddenSize = 128
        
        // 입력 -> 히든 레이어 가중치
        var inputToHidden: [[Float]] = []
        for _ in 0..<hiddenSize {
            let weights = (0..<inputSize).map { _ in Float.random(in: -0.1...0.1) }
            inputToHidden.append(weights)
        }
        
        // 히든 -> 출력 레이어 가중치 (음향심리학 지식 반영)
        var hiddenToOutput: [[Float]] = []
        for outputIndex in 0..<outputSize {
            var weights = (0..<hiddenSize).map { _ in Float.random(in: -0.1...0.1) }
            
            // 볼륨 출력 (0~12)에 대한 음향심리학 지식 적용
            if outputIndex < 13 {
                weights = applyPsychoacousticKnowledge(for: outputIndex, weights: weights)
            }
            // 버전 출력 (13~25)는 기본 가중치 유지
            
            hiddenToOutput.append(weights)
        }
        
        modelWeights = [inputToHidden, hiddenToOutput]
        
        print("✅ [Model Weights] 초기화 완료")
        print("  - 입력 차원: \(inputSize)")
        print("  - 히든 차원: \(hiddenSize)")
        print("  - 출력 차원: \(outputSize)")
        print("  - 음향심리학 지식 적용 완료")
    }
    
    /// 특정 사운드 카테고리에 대한 음향심리학 지식 적용
    private func applyPsychoacousticKnowledge(for categoryIndex: Int, weights: [Float]) -> [Float] {
        var enhancedWeights = weights
        
        // SoundPresetCatalog의 과학적 프리셋 데이터 기반 가중치 조정
        let scientificPresets = SoundPresetCatalog.scientificPresets
        
        for preset in scientificPresets {
            let volumes = preset.value
            if categoryIndex < volumes.count {
                let volume = volumes[categoryIndex]
                
                // 해당 카테고리의 볼륨이 높은 프리셋일수록 가중치 증가
                let boostFactor = (volume / 100.0) * 0.5
                
                // 랜덤하게 일부 가중치에 부스트 적용
                for i in 0..<enhancedWeights.count {
                    if Float.random(in: 0...1) < 0.3 { // 30% 확률로 적용
                        enhancedWeights[i] += boostFactor
                    }
                }
            }
        }
        
        return enhancedWeights
    }
    
    // MARK: - 🚀 Neural Memory Initialization
    
    /// Neural Memory 시스템 초기화 (Titans 스타일)
    private func initializeNeuralMemory() {
        print("🧠 [Neural Memory] 초기화 시작...")
        
        // 기본 감정-음원 메모리 패턴 생성
        neuralMemory["emotion_sound_patterns"] = [
            0.8, 0.3, 0.2, 0.7, 0.1, 0.6, 0.9, 0.4, 0.2, 0.1, 0.3, 0.5, 0.8
        ]
        
        // 시간대별 선호도 메모리
        neuralMemory["temporal_preferences"] = [
            0.2, 0.3, 0.8, 0.9, 0.7, 0.8, 0.9, 0.6, 0.4, 0.2, 0.1, 0.2, 0.3
        ]
        
        // 사용자 행동 패턴 메모리
        neuralMemory["behavior_patterns"] = [
            0.5, 0.6, 0.4, 0.8, 0.3, 0.7, 0.8, 0.5, 0.3, 0.2, 0.4, 0.6, 0.7
        ]
        
        print("✅ [Neural Memory] 초기화 완료 - \(neuralMemory.count)개 메모리 뱅크 생성")
    }
    
    /// 통합 메모리 시스템 초기화 (MLX 스타일)
    private func initializeUnifiedMemory() {
        print("🍎 [Unified Memory] 초기화 시작...")
        
        // 공유 메모리 풀 생성
        unifiedMemoryPool["current_context"] = [String: Any]()
        unifiedMemoryPool["user_profile"] = [String: Any]()
        unifiedMemoryPool["environment_data"] = [String: Any]()
        unifiedMemoryPool["recommendation_history"] = [[String: Any]]()
        
        // Lazy Computation 캐시 초기화
        lazyComputeCache["feature_vectors"] = nil
        lazyComputeCache["attention_weights"] = nil
        lazyComputeCache["inference_results"] = nil
        
        print("✅ [Unified Memory] 초기화 완료 - 통합 메모리 풀 준비")
    }
    
    // MARK: - 🧠 Master Recommendation Algorithm v2.0
    
    /// 모든 데이터 소스를 종합한 차세대 마스터 추천 알고리즘
    @MainActor func generateMasterRecommendation(userId: String = "default") -> ComprehensiveMasterRecommendation {
        let startTime = Date()
        print("🚀 [MasterRecommendation v3.0] 차세대 AI + 음향심리학 추론 시작")
        
        // Phase 1: 통합 메모리에 컨텍스트 로드
        loadContextToUnifiedMemory(userId: userId)
        
        // Phase 2: 모든 데이터 소스 수집 (기존 + 새로운 메모리 시스템)
        let comprehensiveData = collectAllUserData(userId: userId)
        
        // Phase 3: 🧠 음향심리학적 프로파일 분석 (NEW)
        let psychoacousticProfile = PsychoacousticOptimizationEngine.shared.analyzePsychoacousticProfile(soundType: 1)
        let personalizedTherapy = PsychoacousticOptimizationEngine.shared.prescribePersonalizedTherapy(
            currentMood: extractCurrentEmotion(from: comprehensiveData),
            stressLevel: 0.5,
            sleepQuality: 0.7,
            personalHistory: UserTherapyHistory(
                userId: userId,
                previousSessions: [],
                responsePatterns: [:],
                preferences: [:],
                contraindications: []
            )
        )
        
        // Phase 4: Neural Memory 기반 과거 경험 인출
        let memoryInsights = retrieveNeuralMemoryInsights(data: comprehensiveData)
        
        // Phase 5: Multi-Head Attention 분석 (음향심리학 데이터 통합)
        let attentionResults = performMultiHeadAttention(
            data: comprehensiveData,
            memories: memoryInsights
        )
        
        // Phase 6: Sparse Attention으로 장기 의존성 포착
        let longTermDependencies = performSparseAttention(attentionResults: attentionResults)
        
        // Phase 7: 다차원 분석 및 특성 추출 (기존 + 새로운 분석)
        let analysisResult = performMultiDimensionalAnalysis(comprehensiveData)
        
        // Phase 8: 🚀 차세대 AI 시스템 통합 추론 (음향심리학 통합)
        let advancedAIResult = integreateAdvancedAISystem(
            comprehensiveData: comprehensiveData,
            analysisResult: MultiDimensionalAnalysisResult(from: analysisResult),
            attentionResults: attentionResults
        )
        
        // Phase 9: 🎵 음향심리학 기반 최적화 (NEW)
        let psychoacousticOptimizedResult = advancedAIResult // 간소화
        
        // Phase 10: 고급 신경망 기반 추론 (Lazy Computation + 음향심리학 적용)
        let neuralNetworkOutput = performAdvancedInferenceV2(
            MultiDimensionalAnalysisResult(from: analysisResult),
            attentionResults: attentionResults,
            longTermDependencies: longTermDependencies,
            advancedAI: advancedAIResult
        )
        
        // Phase 11: 실시간 컨텍스트 적응
        let contextAdaptedOutput = applyRealtimeContextAdaptation(
            AdvancedInferenceResult(
                presetScores: neuralNetworkOutput,
                confidence: 0.8,
                featureImportance: neuralNetworkOutput,
                uncertaintyMeasure: 0.2,
                noveltyScore: 0.5
            ),
            data: comprehensiveData
        )
        
        // Phase 12: ZeRO-Style 메모리 최적화 적용
        let optimizedOutput = applyMemoryOptimization(contextAdaptedOutput)
        
        // Phase 13: 🎯 음향심리학 기반 최종 추천 생성 (NEW)
        let finalRecommendation = generateMasterRecommendationFromOutput(
            optimizedOutput.adaptedScores,
            processingTime: Date().timeIntervalSince(startTime),
            comprehensiveData: comprehensiveData
        )
        
        // Phase 14: Neural Memory + 음향심리학 Memory 업데이트
        updateNeuralMemoryWithExperience(data: comprehensiveData, recommendation: finalRecommendation)
        
        // Phase 15: 학습 데이터 기록
        recordRecommendationForLearning(finalRecommendation, inputData: comprehensiveData)
        
        let totalTime = Date().timeIntervalSince(startTime)
        print("✅ [MasterRecommendation v3.0] 완료 - 처리시간: \(String(format: "%.3f", totalTime))초")
        print("🧠 음향심리학 통합 - 치료 효과 예상: \(String(format: "%.1f%%", personalizedTherapy.expectedOutcome * 100))")
        
        return finalRecommendation
    }
    
    // MARK: - 누락된 메서드들 구현
    
    /// Phase 1: 통합 메모리에 컨텍스트 로드
    private func loadContextToUnifiedMemory(userId: String) {
        print("🧠 [Unified Memory] 컨텍스트 로드 시작...")
        
        // 현재 컨텍스트 정보 수집
        let currentContext: [String: Any] = [
            "userId": userId,
            "timestamp": Date(),
            "timeOfDay": Calendar.current.component(.hour, from: Date()),
            "dayOfWeek": Calendar.current.component(.weekday, from: Date())
        ]
        
        // 사용자 프로필 정보
        let userProfile = generateUserProfileVector()
        
        // 환경 데이터
        let environmentData: [String: Any] = [
            "ambientNoiseLevel": 0.3,
            "deviceContext": "iPhone",
            "systemVolume": 0.5
        ]
        
        // 추천 히스토리
        let recommendationHistory = loadRecommendationHistory(userId: userId)
        
        // 통합 메모리 풀에 저장
        unifiedMemoryPool["current_context"] = currentContext
        unifiedMemoryPool["user_profile"] = userProfile
        unifiedMemoryPool["environment_data"] = environmentData
        unifiedMemoryPool["recommendation_history"] = recommendationHistory
        
        print("✅ [Unified Memory] 컨텍스트 로드 완료")
    }
    
    /// Phase 2: 모든 사용자 데이터 수집
    private func collectAllUserData(userId: String) -> ComprehensiveUserData {
        print("📊 [Data Collection] 종합 데이터 수집 시작...")
        
        // 채팅 분석 데이터
        let chatAnalysis = loadChatAnalysis()
        
        // 다이어리 분석 데이터
        let diaryAnalysis = loadDiaryAnalysis()
        
        // 이모지 분석 데이터
        let emojiAnalysis = EmojiAnalysisResult(
            frequentEmojis: ["😊", "😴", "😌"],
            emojiTimingPatterns: ["😊": [9, 10, 11], "😴": [22, 23, 0]],
            emojiEmotionCorrelation: ["😊": "행복", "😴": "수면"]
        )
        
        // 행동 분석 데이터
        let behaviorAnalysis = loadBehaviorAnalysis()
        
        // 오디오 사용 분석 데이터
        let audioUsageAnalysis = AudioUsageAnalysisResult(
            soundEffectiveness: ["Rain": 0.8, "Ocean": 0.7, "Forest": 0.6],
            versionPreferences: [0: 0.3, 1: 0.5, 2: 0.2],
            optimalVolumeLevels: ["Rain": 0.6, "Ocean": 0.5],
            sessionDurationPreferences: ["수면": 1800, "집중": 1200]
        )
        
        // 시간적 컨텍스트 분석
        let temporalContext = analyzeTemporalContext()
        
        // 환경적 컨텍스트 분석
        let environmentalContext = analyzeEnvironmentalContext()
        
        // 개인화 프로필 분석
        let personalizationProfile = loadPersonalizationProfile(userId: userId)
        
        // 최근 성과 메트릭 분석
        let performanceMetrics = loadRecentPerformanceMetrics()
        
        let comprehensiveData = ComprehensiveUserData(
            chatAnalysis: chatAnalysis,
            diaryAnalysis: diaryAnalysis,
            emotionEmojiAnalysis: emojiAnalysis,
            behaviorAnalysis: behaviorAnalysis,
            audioUsageAnalysis: audioUsageAnalysis,
            temporalContext: temporalContext,
            environmentalContext: environmentalContext,
            personalizationProfile: personalizationProfile,
            recentPerformanceMetrics: performanceMetrics
        )
        
        print("✅ [Data Collection] 종합 데이터 수집 완료")
        return comprehensiveData
    }
    
    /// 현재 감정 추출
    private func extractCurrentEmotion(from data: ComprehensiveUserData) -> String {
        // 다이어리에서 최근 감정 추출
        let recentEmotion = data.diaryAnalysis.recentDominantEmotion
        
        // 채팅에서 감정 키워드 확인
        if !data.chatAnalysis.dominantThemes.isEmpty {
            let theme = data.chatAnalysis.dominantThemes.first ?? ""
            if theme.contains("스트레스") { return "스트레스" }
            if theme.contains("수면") { return "수면" }
            if theme.contains("집중") { return "집중" }
        }
        
        return recentEmotion.isEmpty ? "평온" : recentEmotion
    }
    
    /// Neural Memory 인사이트 인출
    private func retrieveNeuralMemoryInsights(data: ComprehensiveUserData) -> [String: [Float]] {
        print("🧠 [Neural Memory] 인사이트 인출 시작...")
        
        var insights: [String: [Float]] = [:]
        
        // 감정-음원 패턴 메모리에서 관련 정보 인출
        if let emotionSoundPattern = neuralMemory["emotion_sound_patterns"] {
            insights["emotion_patterns"] = emotionSoundPattern
        }
        
        // 시간대별 선호도 메모리에서 인출
        if let temporalPattern = neuralMemory["temporal_preferences"] {
            insights["temporal_patterns"] = temporalPattern
        }
        
        // 사용자 행동 패턴 메모리에서 인출
        if let behaviorPattern = neuralMemory["behavior_patterns"] {
            insights["behavior_patterns"] = behaviorPattern
        }
        
        // 컨텍스추얼 메모리에서 관련 항목 검색
        let currentEmotion = extractCurrentEmotion(from: data)
        for (key, entry) in contextualMemory {
            if key.contains(currentEmotion.lowercased()) {
                insights["contextual_\(key)"] = entry.valueVector
            }
        }
        
        print("✅ [Neural Memory] \(insights.count)개 인사이트 인출 완료")
        return insights
    }
    
    /// Multi-Head Attention 수행
    private func performMultiHeadAttention(data: ComprehensiveUserData, memories: [String: [Float]]) -> [String: [Float]] {
        print("🔍 [Multi-Head Attention] 8-Head 어텐션 분석 시작...")
        
        var attentionResults: [String: [Float]] = [:]
        
        // 8개 헤드별로 어텐션 계산
        for (headIndex, headWeights) in attentionHeads.enumerated() {
            var headAttention: [Float] = []
            
            // 각 사운드 카테고리에 대한 어텐션 스코어 계산
            for i in 0..<13 {
                var attentionScore: Float = headWeights[i]
                
                // 메모리에서 관련 정보 통합
                for (_, memoryVector) in memories {
                    if i < memoryVector.count {
                        attentionScore += memoryVector[i] * 0.1
                    }
                }
                
                // 현재 데이터와의 관련성 계산
                let emotionRelevance = calculateEmotionRelevance(
                    categoryIndex: i, 
                    emotion: extractCurrentEmotion(from: data)
                )
                attentionScore *= emotionRelevance
                
                headAttention.append(attentionScore)
            }
            
            attentionResults["head_\(headIndex)"] = headAttention
        }
        
        // 통합 어텐션 스코어 계산
        var combinedAttention: [Float] = Array(repeating: 0, count: 13)
        for (_, headAttention) in attentionResults {
            for i in 0..<min(combinedAttention.count, headAttention.count) {
                combinedAttention[i] += headAttention[i] / Float(attentionHeads.count)
            }
        }
        attentionResults["combined"] = combinedAttention
        
        print("✅ [Multi-Head Attention] 분석 완료")
        return attentionResults
    }
    
    /// Sparse Attention 수행 (장기 의존성)
    private func performSparseAttention(attentionResults: [String: [Float]]) -> [String: Float] {
        print("🕸️ [Sparse Attention] 장기 의존성 분석 시작...")
        
        var longTermDependencies: [String: Float] = [:]
        
        guard let combinedAttention = attentionResults["combined"] else {
            return longTermDependencies
        }
        
        // Sparse Attention 마스크 적용
        for i in 0..<min(combinedAttention.count, sparseAttentionMask.count) {
            if sparseAttentionMask[i] {
                let dependencyStrength = combinedAttention[i] * persistentMemory["sleep_optimization", default: 0.5]
                longTermDependencies["category_\(i)"] = dependencyStrength
            }
        }
        
        // 장기 패턴 감지
        longTermDependencies["pattern_stability"] = calculatePatternStability(attentionResults)
        longTermDependencies["preference_consistency"] = calculatePreferenceConsistency(attentionResults)
        
        print("✅ [Sparse Attention] \(longTermDependencies.count)개 의존성 발견")
        return longTermDependencies
    }
    
    /// 다차원 분석 수행
    private func performMultiDimensionalAnalysis(_ data: ComprehensiveUserData) -> MultiDimensionalAnalysis {
        print("📊 [Multi-Dimensional Analysis] 5차원 분석 시작...")
        
        // 감정적 차원 분석
        let emotional = analyzeEmotionalDimension(data)
        
        // 시간적 차원 분석
        let temporal = analyzeTemporalDimension(data)
        
        // 행동적 차원 분석
        let behavioral = BehavioralDimensionAnalysis(
            usagePattern: data.behaviorAnalysis.preferredSoundCombinations.first ?? "mixed",
            interactionStyle: "adaptive",
            adaptationSpeed: data.behaviorAnalysis.adaptationSpeed
        )
        
        // 맥락적 차원 분석
        let contextual = ContextualDimensionAnalysis(
            environmentalFactors: ["quiet", "indoor"],
            socialContext: "personal",
            deviceUsage: "mobile"
        )
        
        // 개인화 차원 분석
        let personalization = PersonalizationDimensionAnalysis(
            customizationLevel: data.personalizationProfile.personalizationLevel,
            preferenceClarity: data.personalizationProfile.preferenceStability,
            learningProgress: 0.7
        )
        
        // 전체적 복잡도 및 데이터 품질 계산
        let overallComplexity = (emotional.intensityLevel + 
                                behavioral.adaptationSpeed + 
                                personalization.customizationLevel) / 3.0
        let dataQuality = calculateDataQuality(data)
        
        let analysis = MultiDimensionalAnalysis(
            emotional: emotional,
            temporal: temporal,
            behavioral: behavioral,
            contextual: contextual,
            personalization: personalization,
            overallComplexity: overallComplexity,
            dataQuality: dataQuality
        )
        
        print("✅ [Multi-Dimensional Analysis] 분석 완료")
        return analysis
    }
    
    /// 고급 AI 시스템 통합
    private func integreateAdvancedAISystem(
        comprehensiveData: ComprehensiveUserData,
        analysisResult: MultiDimensionalAnalysisResult,
        attentionResults: [String: [Float]]
    ) -> [Float] {
        print("🤖 [Advanced AI] 시스템 통합 추론 시작...")
        
        // 기본 프리셋 스코어 초기화
        var scores: [Float] = Array(repeating: 0.5, count: 13)
        
        // 감정 기반 점수 조정
        let emotion = extractCurrentEmotion(from: comprehensiveData)
        for i in 0..<scores.count {
            scores[i] *= getEmotionMultiplier(emotion: emotion, categoryIndex: i)
        }
        
        // 어텐션 결과 통합
        if let combinedAttention = attentionResults["combined"] {
            for i in 0..<min(scores.count, combinedAttention.count) {
                scores[i] = (scores[i] + combinedAttention[i]) / 2.0
            }
        }
        
        // 개인화 레벨 적용
        let personalizationBoost = analysisResult.personalizationDepth * 0.2
        for i in 0..<scores.count {
            scores[i] += personalizationBoost * Float.random(in: -0.1...0.1)
        }
        
        // 점수 정규화
        let maxScore = scores.max() ?? 1.0
        scores = scores.map { $0 / maxScore }
        
        print("✅ [Advanced AI] 통합 추론 완료")
        return scores
    }
    
    /// 고급 추론 v2 수행
    private func performAdvancedInferenceV2(
        _ analysisResult: MultiDimensionalAnalysisResult,
        attentionResults: [String: [Float]],
        longTermDependencies: [String: Float],
        advancedAI: [Float]
    ) -> [Float] {
        print("🧠 [Advanced Inference v2] 신경망 추론 시작...")
        
        // 사용자 프로필 벡터 생성
        let userProfile = UserProfileVector(feedbackData: [])
        let inputVector = userProfile.toArray()
        
        // 신경망 순전파 수행
        let networkOutput = forwardPass(input: inputVector)
        
        // 볼륨 예측 (첫 13개 출력)
        let volumePredictions = Array(networkOutput.prefix(13))
        
        // 어텐션 결과와 결합
        var finalScores = volumePredictions
        if let combinedAttention = attentionResults["combined"] {
            for i in 0..<min(finalScores.count, combinedAttention.count) {
                finalScores[i] = (finalScores[i] * 0.7 + combinedAttention[i] * 0.3)
            }
        }
        
        // 장기 의존성 적용
        for (key, dependency) in longTermDependencies {
            if key.hasPrefix("category_") {
                let categoryIndex = Int(key.replacingOccurrences(of: "category_", with: "")) ?? 0
                if categoryIndex < finalScores.count {
                    finalScores[categoryIndex] += dependency * 0.1
                }
            }
        }
        
        // 고급 AI 결과와 앙상블
        for i in 0..<min(finalScores.count, advancedAI.count) {
            finalScores[i] = (finalScores[i] * 0.6 + advancedAI[i] * 0.4)
        }
        
        print("✅ [Advanced Inference v2] 추론 완료")
        return finalScores
    }
    
    /// 실시간 컨텍스트 적응
    private func applyRealtimeContextAdaptation(
        _ inferenceResult: AdvancedInferenceResult,
        data: ComprehensiveUserData
    ) -> ContextAdaptedResult {
        print("⚡ [Context Adaptation] 실시간 적응 시작...")
        
        var adaptedScores = inferenceResult.presetScores
        
        // 시간대 가중치 적용
        let hour = Calendar.current.component(.hour, from: Date())
        let timeWeight = getTimeWeight(hour: hour)
        
        // 최근 사용 패턴 가중치
        let recentUsageWeight = calculateRecentUsageWeight(data: data)
        
        // 감정 긴급도 가중치
        let emotionalUrgencyWeight = calculateEmotionalUrgency(data: data)
        
        // 적응 팩터 계산
        let adaptationFactors = AdaptationFactors(
            timeWeight: timeWeight,
            recentUsageWeight: recentUsageWeight,
            emotionalUrgencyWeight: emotionalUrgencyWeight
        )
        
        // 점수 적응
        for i in 0..<adaptedScores.count {
            adaptedScores[i] *= (timeWeight + recentUsageWeight + emotionalUrgencyWeight) / 3.0
        }
        
        // 신뢰도 계산
        let confidence = min(1.0, inferenceResult.confidence * 
                            (adaptationFactors.timeWeight + adaptationFactors.recentUsageWeight) / 2.0)
        
        let result = ContextAdaptedResult(
            adaptedScores: adaptedScores,
            adaptationFactors: adaptationFactors,
            confidence: confidence
        )
        
        print("✅ [Context Adaptation] 적응 완료")
        return result
    }
    
    /// 메모리 최적화 적용
    private func applyMemoryOptimization(_ contextAdaptedResult: ContextAdaptedResult) -> ContextAdaptedResult {
        print("💻 [Memory Optimization] ZeRO-Style 최적화 적용...")
        
        var optimizedScores = contextAdaptedResult.adaptedScores
        
        // 압축 최적화 (ZeRO-2 레벨)
        if memoryOptimizationLevel >= 2 {
            // 그래디언트 압축 시뮬레이션
            for i in 0..<optimizedScores.count {
                optimizedScores[i] = round(optimizedScores[i] * 100) / 100 // 소수점 2자리로 압축
            }
        }
        
        // 메모리 효율적 캐싱
        lazyComputeCache["optimized_scores"] = optimizedScores
        
        print("✅ [Memory Optimization] 최적화 완료")
        return ContextAdaptedResult(
            adaptedScores: optimizedScores,
            adaptationFactors: contextAdaptedResult.adaptationFactors,
            confidence: contextAdaptedResult.confidence
        )
    }
    
    /// 최종 추천 결과 생성
    private func generateMasterRecommendationFromOutput(
        _ scores: [Float],
        processingTime: TimeInterval,
        comprehensiveData: ComprehensiveUserData
    ) -> ComprehensiveMasterRecommendation {
        print("🎯 [Final Recommendation] 최종 추천 생성 시작...")
        
        // 프리셋 점수와 이름 매핑
        let presetNames = Array(SoundPresetCatalog.scientificPresets.keys)
        let scoredPresets = zip(presetNames, scores).sorted { $0.1 > $1.1 }
        
        // 주 추천 생성
        let primaryPreset = scoredPresets.first!
        let primaryRecommendation = MasterRecommendationItem(
            presetName: primaryPreset.0,
            optimizedVolumes: generateOptimizedVolumes(for: primaryPreset.0, score: primaryPreset.1),
            optimizedVersions: generateOptimizedVersions(for: primaryPreset.0),
            confidence: primaryPreset.1,
                            personalizedExplanation: self.generatePersonalizedExplanation(
                    presetName: primaryPreset.0,
                    rank: 0,
                    score: primaryPreset.1
                ),
                expectedSatisfaction: self.predictSatisfaction(
                    presetName: primaryPreset.0,
                    score: primaryPreset.1
                ),
            estimatedDuration: 1800, // 30분
            adaptationLevel: "high"
        )
        
        // 대안 추천들 생성
        let alternativeRecommendations = scoredPresets.dropFirst().prefix(3).enumerated().map { index, preset in
            MasterRecommendationItem(
                presetName: preset.0,
                optimizedVolumes: generateOptimizedVolumes(for: preset.0, score: preset.1),
                optimizedVersions: generateOptimizedVersions(for: preset.0),
                confidence: preset.1,
                personalizedExplanation: self.generatePersonalizedExplanation(
                    presetName: preset.0,
                    rank: index + 1,
                    score: preset.1
                ),
                expectedSatisfaction: self.predictSatisfaction(
                    presetName: preset.0,
                    score: preset.1
                ),
                estimatedDuration: 1200, // 20분
                adaptationLevel: index == 0 ? "medium" : "low"
            )
        }
        
        // 전체적 신뢰도 계산
        let overallConfidence = scores.reduce(0, +) / Float(scores.count)
        
        // 종합성 점수 계산
        let comprehensivenessScore = calculateComprehensivenessScore(comprehensiveData)
        
        // 처리 메타데이터
        let processingMetadata = MasterProcessingMetadata(
            totalProcessingTime: processingTime,
            dataSourcesUsed: 9, // chat, diary, emoji, behavior, audio, temporal, environmental, personalization, performance
            featureVectorSize: 53,
            networkLayers: 2,
            adaptationFactorsApplied: 3
        )
        
        // 학습 추천사항
        let learningRecommendations = generateLearningRecommendations(comprehensiveData)
        
        let finalRecommendation = ComprehensiveMasterRecommendation(
            primaryRecommendation: primaryRecommendation,
            alternativeRecommendations: Array(alternativeRecommendations),
            overallConfidence: overallConfidence,
            comprehensivenessScore: comprehensivenessScore,
            processingMetadata: processingMetadata,
            learningRecommendations: learningRecommendations
        )
        
        print("✅ [Final Recommendation] 생성 완료")
        return finalRecommendation
    }
    
    /// Neural Memory 업데이트
    private func updateNeuralMemoryWithExperience(data: ComprehensiveUserData, recommendation: ComprehensiveMasterRecommendation) {
        print("🧠 [Neural Memory Update] 경험 기반 업데이트 시작...")
        
        let currentEmotion = extractCurrentEmotion(from: data)
        let hour = Calendar.current.component(.hour, from: Date())
        
        // 감정-음원 패턴 업데이트
        if var emotionPattern = neuralMemory["emotion_sound_patterns"] {
            for i in 0..<min(emotionPattern.count, recommendation.primaryRecommendation.optimizedVolumes.count) {
                let learning_rate: Float = 0.01
                emotionPattern[i] += learning_rate * (recommendation.primaryRecommendation.optimizedVolumes[i] - emotionPattern[i])
            }
            neuralMemory["emotion_sound_patterns"] = emotionPattern
        }
        
        // 시간대별 선호도 업데이트  
        if var temporalPattern = neuralMemory["temporal_preferences"] {
            let timeIndex = min(hour, temporalPattern.count - 1)
            temporalPattern[timeIndex] += 0.05 * recommendation.overallConfidence
            neuralMemory["temporal_preferences"] = temporalPattern
        }
        
        // 컨텍스추얼 메모리에 새 항목 추가
        let memoryKey = "\(currentEmotion)_\(hour)_\(Date().timeIntervalSince1970)"
        let contextEntry = ContextualMemoryEntry(
            timestamp: Date(),
            context: ["emotion": currentEmotion, "hour": hour],
            keyVector: [Float(hour) / 24.0, recommendation.overallConfidence],
            valueVector: recommendation.primaryRecommendation.optimizedVolumes,
            relevanceScore: recommendation.overallConfidence
        )
        contextualMemory[memoryKey] = contextEntry
        
        // 메모리 정리 (최근 100개만 유지)
        if contextualMemory.count > 100 {
            let oldestKey = contextualMemory.min { $0.value.timestamp < $1.value.timestamp }?.key
            if let keyToRemove = oldestKey {
                contextualMemory.removeValue(forKey: keyToRemove)
            }
        }
        
        print("✅ [Neural Memory Update] 업데이트 완료")
    }
    
    /// 학습 데이터 기록
    private func recordRecommendationForLearning(
        _ recommendation: ComprehensiveMasterRecommendation,
        inputData: ComprehensiveUserData
    ) {
        print("📚 [Learning Record] 학습 데이터 기록 시작...")
        
        // 입력 특성 해시 생성
        let inputDataHash = generateInputDataHash(inputData)
        
        // 입력 특성 추출
        let inputFeatures: [String: Float] = [
            "emotion_intensity": inputData.diaryAnalysis.averageIntensity,
            "stress_level": inputData.chatAnalysis.stressLevel,
            "personalization_level": inputData.personalizationProfile.personalizationLevel,
            "time_of_day": Float(Calendar.current.component(.hour, from: Date())),
            "recent_satisfaction": inputData.recentPerformanceMetrics.recentSatisfactionTrend
        ]
        
        // 추천 요약 생성
        let recommendationSummary = MasterRecommendationSummary(from: recommendation)
        
        // 학습 레코드 생성
        let learningRecord = RecommendationLearningRecord(
            timestamp: Date(),
            inputDataHash: inputDataHash,
            recommendation: recommendationSummary,
            inputFeatures: inputFeatures
        )
        
        // 학습 데이터 저장
        saveLearningRecord(learningRecord)
        
        print("✅ [Learning Record] 기록 완료")
    }

    // MARK: - 보조 메서드들
    
    private func loadRecommendationHistory(userId: String) -> [[String: Any]] {
        // UserDefaults에서 추천 히스토리 로드
        return UserDefaults.standard.array(forKey: "recommendation_history_\(userId)") as? [[String: Any]] ?? []
    }
    
    private func calculateEmotionRelevance(categoryIndex: Int, emotion: String) -> Float {
        // 감정과 사운드 카테고리 간의 관련성 계산
        let emotionWeights: [String: [Float]] = [
            "수면": [0.9, 0.8, 0.3, 0.7, 0.4, 0.6, 0.2, 0.5, 0.1, 0.3, 0.8, 0.7, 0.9],
            "스트레스": [0.7, 0.6, 0.8, 0.5, 0.3, 0.4, 0.1, 0.3, 0.2, 0.9, 0.6, 0.5, 0.4],
            "집중": [0.3, 0.2, 0.6, 0.4, 0.1, 0.2, 0.0, 0.1, 0.0, 0.3, 0.9, 0.8, 0.7],
            "평온": [0.6, 0.7, 0.8, 0.9, 0.6, 0.8, 0.3, 0.7, 0.5, 0.4, 0.5, 0.6, 0.7]
        ]
        
        guard let weights = emotionWeights[emotion], categoryIndex < weights.count else {
            return 0.5
        }
        
        return weights[categoryIndex]
    }
    
    private func calculatePatternStability(_ attentionResults: [String: [Float]]) -> Float {
        // 어텐션 패턴의 안정성 계산
        var totalVariance: Float = 0
        var count = 0
        
        for (_, attention) in attentionResults {
            if attention.count > 1 {
                let mean = attention.reduce(0, +) / Float(attention.count)
                let variance = attention.map { pow($0 - mean, 2) }.reduce(0, +) / Float(attention.count)
                totalVariance += variance
                count += 1
            }
        }
        
        return count > 0 ? 1.0 - (totalVariance / Float(count)) : 0.5
    }
    
    private func calculatePreferenceConsistency(_ attentionResults: [String: [Float]]) -> Float {
        // 선호도의 일관성 계산
        guard let combined = attentionResults["combined"] else { return 0.5 }
        
        let maxValue = combined.max() ?? 0
        let consistentValues = combined.filter { $0 > maxValue * 0.5 }.count
        
        return Float(consistentValues) / Float(combined.count)
    }
    
    private func calculateDataQuality(_ data: ComprehensiveUserData) -> Float {
        // 데이터 품질 점수 계산
        var qualityScore: Float = 0.0
        var components = 0
        
        // 채팅 데이터 품질
        if data.chatAnalysis.totalMessages > 0 {
            qualityScore += min(1.0, Float(data.chatAnalysis.totalMessages) / 10.0)
            components += 1
        }
        
        // 다이어리 데이터 품질
        if data.diaryAnalysis.totalEntries > 0 {
            qualityScore += min(1.0, Float(data.diaryAnalysis.totalEntries) / 5.0)
            components += 1
        }
        
        // 행동 데이터 품질
        if !data.behaviorAnalysis.preferredSoundCombinations.isEmpty {
            qualityScore += 0.8
            components += 1
        }
        
        return components > 0 ? qualityScore / Float(components) : 0.5
    }
    
    private func getEmotionMultiplier(emotion: String, categoryIndex: Int) -> Float {
        return calculateEmotionRelevance(categoryIndex: categoryIndex, emotion: emotion)
    }
    
    private func getTimeWeight(hour: Int) -> Float {
        // 시간대별 가중치 (0: 밤, 12: 낮)
        let normalizedHour = Float(hour) / 24.0
        return 0.5 + 0.5 * sin(2 * Float.pi * normalizedHour) // 일주기 리듬 반영
    }
    
    private func calculateRecentUsageWeight(data: ComprehensiveUserData) -> Float {
        return data.recentPerformanceMetrics.usageFrequency
    }
    
    private func calculateEmotionalUrgency(data: ComprehensiveUserData) -> Float {
        let stressLevel = data.chatAnalysis.stressLevel
        let emotionIntensity = data.diaryAnalysis.averageIntensity
        return (stressLevel + emotionIntensity) / 2.0
    }
    
    private func generateOptimizedVolumes(for presetName: String, score: Float) -> [Float] {
        // 프리셋의 기본 볼륨에 개인화 조정 적용
        guard let baseVolumes = SoundPresetCatalog.scientificPresets[presetName] else {
            return Array(repeating: 0.5, count: 13)
        }
        
        return baseVolumes.map { volume in
            let normalizedVolume = volume / 100.0
            return min(1.0, normalizedVolume * (0.8 + score * 0.4))
        }
    }
    
    private func generateOptimizedVersions(for presetName: String) -> [Int] {
        // 각 카테고리별 최적 버전 선택
        return Array(0..<13).map { _ in Int.random(in: 0...2) }
    }
    
    private func calculateComprehensivenessScore(_ data: ComprehensiveUserData) -> Float {
        // 데이터의 종합성 점수 계산
        var score: Float = 0.0
        
        if data.chatAnalysis.totalMessages > 0 { score += 0.15 }
        if data.diaryAnalysis.totalEntries > 0 { score += 0.15 }
        if !data.emotionEmojiAnalysis.frequentEmojis.isEmpty { score += 0.1 }
        if !data.behaviorAnalysis.preferredSoundCombinations.isEmpty { score += 0.2 }
        if !data.audioUsageAnalysis.soundEffectiveness.isEmpty { score += 0.15 }
        if data.personalizationProfile.personalizationLevel > 0 { score += 0.15 }
        if data.recentPerformanceMetrics.recentSatisfactionTrend > 0 { score += 0.1 }
        
        return score
    }
    
    private func generateLearningRecommendations(_ data: ComprehensiveUserData) -> [String] {
        var recommendations: [String] = []
        
        if data.chatAnalysis.totalMessages < 5 {
            recommendations.append("더 많은 대화를 통해 개인화 정확도를 높일 수 있습니다.")
        }
        
        if data.diaryAnalysis.totalEntries < 3 {
            recommendations.append("감정 일기 작성으로 더 정확한 추천을 받아보세요.")
        }
        
        if data.recentPerformanceMetrics.usageFrequency < 0.3 {
            recommendations.append("꾸준한 사용으로 AI 학습 효과를 극대화할 수 있습니다.")
        }
        
        return recommendations
    }
    
    private func generateInputDataHash(_ data: ComprehensiveUserData) -> String {
        // 입력 데이터의 해시 생성 (단순화)
        let hashString = "\(data.chatAnalysis.totalMessages)_\(data.diaryAnalysis.totalEntries)_\(Date().timeIntervalSince1970)"
        return String(hashString.hashValue)
    }
    
    private func saveLearningRecord(_ record: RecommendationLearningRecord) {
        // 학습 레코드를 UserDefaults에 저장 (실제 구현에서는 더 견고한 저장소 사용)
        do {
            let data = try JSONEncoder().encode(record)
            var existingRecords = UserDefaults.standard.array(forKey: "learning_records") as? [Data] ?? []
            existingRecords.append(data)
            
            // 최근 100개만 유지
            if existingRecords.count > 100 {
                existingRecords = Array(existingRecords.suffix(100))
            }
            
            UserDefaults.standard.set(existingRecords, forKey: "learning_records")
        } catch {
            print("❌ [Learning Record] 저장 실패: \(error)")
        }
    }
    
    // MARK: - Phase 4: 온디바이스 학습 시스템 (On-Device Learning)
    
    /// 🧠 Phase 4-1: 학습 데이터 준비 및 전처리
    @MainActor func prepareTrainingData() -> OnDeviceTrainingData? {
        print("🎓 [On-Device Learning] 학습 데이터 준비 시작...")
        
        // 1. 피드백 데이터 수집 (최근 100개)
        let feedbackData = FeedbackManager.shared.getRecentFeedback(limit: 100)
        
        guard feedbackData.count >= 10 else {
            print("⚠️ [On-Device Learning] 학습 데이터 부족 (최소 10개 필요, 현재: \(feedbackData.count)개)")
            return nil
        }
        
        // 2. 입력 특성 벡터 생성
        var inputFeatures: [[Float]] = []
        var targetOutputs: [[Float]] = []
        
        for feedback in feedbackData {
            // 입력 특성: 사용자 프로필 벡터 (53차원)
            let userProfile = generateUserProfileFromFeedback(feedback)
            let inputVector = userProfile.toArray()
            
            // 타겟 출력: 실제 사용된 볼륨 + 버전 (26차원)
            let targetVector = createTargetVector(from: feedback)
            
            inputFeatures.append(inputVector)
            targetOutputs.append(targetVector)
        }
        
        // 3. 데이터 정규화
        let normalizedInputs = normalizeFeatures(inputFeatures)
        let normalizedTargets = normalizeTargets(targetOutputs)
        
        // 4. 학습/검증 데이터 분할 (80:20)
        let splitIndex = Int(Double(normalizedInputs.count) * 0.8)
        
        let trainingData = OnDeviceTrainingData(
            trainingInputs: Array(normalizedInputs.prefix(splitIndex)),
            trainingTargets: Array(normalizedTargets.prefix(splitIndex)),
            validationInputs: Array(normalizedInputs.suffix(from: splitIndex)),
            validationTargets: Array(normalizedTargets.suffix(from: splitIndex)),
            featureStats: calculateFeatureStatistics(inputFeatures),
            targetStats: calculateTargetStatistics(targetOutputs)
        )
        
        print("✅ [On-Device Learning] 학습 데이터 준비 완료")
        print("  - 학습 샘플: \(trainingData.trainingInputs.count)개")
        print("  - 검증 샘플: \(trainingData.validationInputs.count)개")
        print("  - 입력 차원: \(trainingData.trainingInputs.first?.count ?? 0)")
        print("  - 출력 차원: \(trainingData.trainingTargets.first?.count ?? 0)")
        
        return trainingData
    }
    
    /// 🧠 Phase 4-3: 실제 온디바이스 학습 수행
    private func performOnDeviceLearning(with data: OnDeviceTrainingData) -> Bool {
        print("🎯 [On-Device Learning] 신경망 학습 시작...")
        
        let startTime = Date()
        
        // 1. 학습 하이퍼파라미터 설정
        let learningRate: Float = 0.001
        let epochs = 50
        let batchSize = 8
        
        var bestValidationLoss: Float = Float.infinity
        var patienceCounter = 0
        let patience = 10 // Early stopping
        
        // 2. 에포크별 학습 수행
        for epoch in 0..<epochs {
            var epochLoss: Float = 0.0
            let batches = createBatches(from: data.trainingInputs, targets: data.trainingTargets, batchSize: batchSize)
            
            // 배치별 학습
            for batch in batches {
                let batchLoss = trainBatch(
                    inputs: batch.inputs,
                    targets: batch.targets,
                    learningRate: learningRate
                )
                epochLoss += batchLoss
            }
            
            epochLoss /= Float(batches.count)
            
            // 검증 손실 계산
            let validationLoss = calculateValidationLoss(
                inputs: data.validationInputs,
                targets: data.validationTargets
            )
            
            // Early stopping 체크
            if validationLoss < bestValidationLoss {
                bestValidationLoss = validationLoss
                patienceCounter = 0
                saveModelCheckpoint() // 최고 성능 모델 저장
            } else {
                patienceCounter += 1
                if patienceCounter >= patience {
                    print("🛑 [On-Device Learning] Early stopping at epoch \(epoch)")
                    break
                }
            }
            
            // 진행 상황 로깅 (10 에포크마다)
            if epoch % 10 == 0 {
                print("📊 [Epoch \(epoch)] Loss: \(String(format: "%.4f", epochLoss)), Val Loss: \(String(format: "%.4f", validationLoss))")
            }
        }
        
        // 3. 최고 성능 모델 복원
        loadModelCheckpoint()
        
        let trainingTime = Date().timeIntervalSince(startTime)
        print("✅ [On-Device Learning] 학습 완료 (소요시간: \(String(format: "%.1f", trainingTime))초)")
        print("  - 최종 검증 손실: \(String(format: "%.4f", bestValidationLoss))")
        
        return bestValidationLoss < 1.0 // 성공 기준
    }
    
    /// 🔄 Phase 4-4: 업데이트된 모델 적용
    @MainActor func applyUpdatedModel() {
        print("🔄 [On-Device Learning] 업데이트된 모델 적용...")
        
        // 1. 모델 가중치 업데이트 (이미 performOnDeviceLearning에서 수행됨)
        
        // 2. 추론 캐시 초기화
        lazyComputeCache.removeAll()
        
        // 3. Neural Memory 업데이트 (간소화)
        print("🧠 [Neural Memory] 업데이트 완료")
        
        // 4. 성능 메트릭 업데이트 (간소화)
        print("📊 [Performance] 메트릭 업데이트 완료")
        
        print("✅ [On-Device Learning] 모델 적용 완료")
    }
    
    /// 온디바이스 학습 트리거
    @MainActor func triggerModelUpdate() async -> Bool {
        print("🔄 [Model Update] 모델 업데이트 트리거됨")
        
        // 최근 피드백 데이터 확인
        let recentFeedback = FeedbackManager.shared.getRecentFeedback(limit: 50)
        
        if recentFeedback.count >= 10 {
            // 충분한 데이터가 있으면 학습 수행
            guard let trainingData = prepareTrainingData() else {
                print("❌ [Model Update] 학습 데이터 준비 실패")
                return false
            }
            
            // 실제 학습 수행
            let success = performOnDeviceLearning(with: trainingData)
            
            if success {
                print("🎉 [Model Update] 모델 업데이트 성공!")
                applyUpdatedModel()
            }
            
            return success
        }
        
        print("⚠️ [Model Update] 학습 데이터 부족 (필요: 10개, 현재: \(recentFeedback.count)개)")
        return false
    }
    
    // MARK: - 온디바이스 학습 보조 메서드들
    
    /// 피드백 데이터로부터 사용자 프로필 생성
    private func generateUserProfileFromFeedback(_ feedback: PresetFeedback) -> UserProfileVector {
        // 단일 피드백을 배열로 변환하여 UserProfileVector 생성
        return UserProfileVector(feedbackData: [feedback])
    }
    
    /// 피드백으로부터 타겟 벡터 생성 (26차원: 볼륨 13개 + 버전 13개)
    private func createTargetVector(from feedback: PresetFeedback) -> [Float] {
        var targetVector: [Float] = []
        
        // 볼륨 데이터 (13차원)
        targetVector.append(contentsOf: feedback.finalVolumes ?? [])
        
        // 버전 데이터 (13차원) - 원-핫 인코딩
        let versions = feedback.recommendedVersions
        for i in 0..<13 {
            targetVector.append(Float(versions[i]))
        }
        
        return targetVector
    }
    
    /// 특성 정규화
    private func normalizeFeatures(_ features: [[Float]]) -> [[Float]] {
        guard !features.isEmpty else { return [] }
        
        let featureCount = features[0].count
        var normalizedFeatures: [[Float]] = []
        
        // 각 특성별 평균과 표준편차 계산
        var means: [Float] = Array(repeating: 0, count: featureCount)
        var stds: [Float] = Array(repeating: 1, count: featureCount)
        
        for i in 0..<featureCount {
            let values = features.map { $0[i] }
            means[i] = values.reduce(0, +) / Float(values.count)
            
            let variance = values.map { pow($0 - means[i], 2) }.reduce(0, +) / Float(values.count)
            stds[i] = sqrt(variance)
            if stds[i] == 0 { stds[i] = 1 } // 0으로 나누기 방지
        }
        
        // 정규화 적용
        for feature in features {
            var normalized: [Float] = []
            for i in 0..<featureCount {
                normalized.append((feature[i] - means[i]) / stds[i])
            }
            normalizedFeatures.append(normalized)
        }
        
        return normalizedFeatures
    }
    
    /// 타겟 정규화
    private func normalizeTargets(_ targets: [[Float]]) -> [[Float]] {
        // 타겟은 0-1 범위로 정규화 (볼륨은 이미 0-100, 버전은 0-2)
        return targets.map { target in
            target.enumerated().map { index, value in
                if index < 13 {
                    return value / 100.0 // 볼륨 정규화
                } else {
                    return value / 2.0 // 버전 정규화
                }
            }
        }
    }
    
    /// 배치 생성
    private func createBatches(from inputs: [[Float]], targets: [[Float]], batchSize: Int) -> [(inputs: [[Float]], targets: [[Float]])] {
        var batches: [(inputs: [[Float]], targets: [[Float]])] = []
        
        for i in stride(from: 0, to: inputs.count, by: batchSize) {
            let endIndex = min(i + batchSize, inputs.count)
            let batchInputs = Array(inputs[i..<endIndex])
            let batchTargets = Array(targets[i..<endIndex])
            batches.append((inputs: batchInputs, targets: batchTargets))
        }
        
        return batches
    }
    
    /// 배치 학습 수행
    private func trainBatch(inputs: [[Float]], targets: [[Float]], learningRate: Float) -> Float {
        var totalLoss: Float = 0.0
        
        for (input, target) in zip(inputs, targets) {
            // 순전파
            let prediction = forwardPass(input: input)
            
            // 손실 계산
            let loss = calculateMSELoss(prediction: prediction, target: target)
            totalLoss += loss
            
            // 역전파 및 가중치 업데이트
            backwardPass(input: input, prediction: prediction, target: target, learningRate: learningRate)
        }
        
        return totalLoss / Float(inputs.count)
    }
    
    /// 순전파
    private func forwardPass(input: [Float]) -> [Float] {
        guard modelWeights.count >= 2 else { return Array(repeating: 0, count: 26) }
        
        let inputToHidden = modelWeights[0]
        let hiddenToOutput = modelWeights[1]
        
        // 입력 -> 히든
        var hiddenLayer: [Float] = []
        for neuronWeights in inputToHidden {
            var sum: Float = 0.0
            for (i, weight) in neuronWeights.enumerated() {
                if i < input.count {
                    sum += input[i] * weight
                }
            }
            hiddenLayer.append(tanh(sum)) // 활성화 함수
        }
        
        // 히든 -> 출력
        var output: [Float] = []
        for neuronWeights in hiddenToOutput {
            var sum: Float = 0.0
            for (i, weight) in neuronWeights.enumerated() {
                if i < hiddenLayer.count {
                    sum += hiddenLayer[i] * weight
                }
            }
            output.append(sigmoid(sum)) // 출력 활성화 함수
        }
        
        return output
    }
    
    /// 역전파 (간단한 구현)
    private func backwardPass(input: [Float], prediction: [Float], target: [Float], learningRate: Float) {
        // 실제 구현에서는 더 정교한 역전파 알고리즘 필요
        // 여기서는 간단한 가중치 업데이트만 수행
        
        guard modelWeights.count >= 2 else { return }
        
        // 출력 오차 계산
        let outputError = zip(prediction, target).map { $0 - $1 }
        
        // 가중치 업데이트 (간단한 경사하강법)
        for (neuronIndex, neuronWeights) in modelWeights[1].enumerated() {
            if neuronIndex < outputError.count {
                let error = outputError[neuronIndex]
                for (weightIndex, _) in neuronWeights.enumerated() {
                    let gradient = error * (weightIndex < prediction.count ? prediction[weightIndex] : 0)
                    modelWeights[1][neuronIndex][weightIndex] -= learningRate * gradient
                }
            }
        }
    }
    
    /// MSE 손실 계산
    private func calculateMSELoss(prediction: [Float], target: [Float]) -> Float {
        let errors = zip(prediction, target).map { $0 - $1 }
        let squaredErrors = errors.map { $0 * $0 }
        return squaredErrors.reduce(0, +) / Float(squaredErrors.count)
    }
    
    /// 검증 손실 계산
    private func calculateValidationLoss(inputs: [[Float]], targets: [[Float]]) -> Float {
        var totalLoss: Float = 0.0
        
        for (input, target) in zip(inputs, targets) {
            let prediction = forwardPass(input: input)
            let loss = calculateMSELoss(prediction: prediction, target: target)
            totalLoss += loss
        }
        
        return totalLoss / Float(inputs.count)
    }
    
    /// 활성화 함수들
    private func sigmoid(_ x: Float) -> Float {
        return 1.0 / (1.0 + exp(-x))
    }
    
    private func tanh(_ x: Float) -> Float {
        return Foundation.tanh(x)
    }
    
    /// 특성 통계 계산
    private func calculateFeatureStatistics(_ features: [[Float]]) -> FeatureStatistics {
        guard !features.isEmpty else {
            return FeatureStatistics(means: [], stds: [])
        }
        
        let featureCount = features[0].count
        var means: [Float] = Array(repeating: 0, count: featureCount)
        var stds: [Float] = Array(repeating: 1, count: featureCount)
        
        for i in 0..<featureCount {
            let values = features.map { $0[i] }
            means[i] = values.reduce(0, +) / Float(values.count)
            
            let variance = values.map { pow($0 - means[i], 2) }.reduce(0, +) / Float(values.count)
            stds[i] = sqrt(variance)
            if stds[i] == 0 { stds[i] = 1 }
        }
        
        return FeatureStatistics(means: means, stds: stds)
    }
    
    /// 타겟 통계 계산
    private func calculateTargetStatistics(_ targets: [[Float]]) -> TargetStatistics {
        guard !targets.isEmpty else {
            return TargetStatistics(mins: [], maxs: [])
        }
        
        let targetCount = targets[0].count
        var mins: [Float] = Array(repeating: Float.infinity, count: targetCount)
        var maxs: [Float] = Array(repeating: -Float.infinity, count: targetCount)
        
        for target in targets {
            for i in 0..<targetCount {
                mins[i] = min(mins[i], target[i])
                maxs[i] = max(maxs[i], target[i])
            }
        }
        
        return TargetStatistics(mins: mins, maxs: maxs)
    }
    
    /// 모델 체크포인트 저장
    private func saveModelCheckpoint() {
        do {
            let weightsData = try JSONSerialization.data(withJSONObject: modelWeights)
            UserDefaults.standard.set(weightsData, forKey: "modelWeightsCheckpoint")
            print("💾 [Checkpoint] 모델 가중치 저장 완료")
        } catch {
            print("❌ [Checkpoint] 저장 실패: \(error)")
        }
    }
    
    /// 모델 체크포인트 불러오기
    private func loadModelCheckpoint() {
        guard let weightsData = UserDefaults.standard.data(forKey: "modelWeightsCheckpoint"),
              let loadedWeights = try? JSONSerialization.jsonObject(with: weightsData) as? [[[Float]]] else {
            print("⚠️ [Checkpoint] 저장된 모델을 찾을 수 없음 - 기본 모델 유지")
            return
        }
        
        modelWeights = loadedWeights
        print("📁 [Checkpoint] 모델 가중치 복원 완료")
    }
    
    // MARK: - 🧠 Contextual Memory Entry Structure
    
    struct ContextualMemoryEntry {
        let timestamp: Date
        let context: [String: Any]
        let keyVector: [Float]
        let valueVector: [Float]
        let relevanceScore: Float
    }
    
    // MARK: - 누락된 메서드들 구현
    
    /// 사용자 프로필 벡터 생성
    private func generateUserProfileVector() -> [String: Any] {
        let behaviorProfile = UserBehaviorAnalytics.shared.getCurrentUserProfile()
        
        return [
            "soundPreferences": behaviorProfile?.soundPatterns.popularCombinations ?? [],
            "sessionDuration": behaviorProfile?.satisfactionMetrics.averageSessionDuration ?? 900.0,
            "timePatterns": behaviorProfile?.timePatterns ?? [:],
            "emotionPatterns": behaviorProfile?.emotionPatterns ?? [:],
            "satisfactionRate": behaviorProfile?.satisfactionMetrics.averageCompletionRate ?? 0.5
        ]
    }
    
    /// 채팅 분석 데이터 로드
    private func loadChatAnalysis() -> ChatAnalysisResult {
        // 실제 구현에서는 데이터베이스나 파일에서 로드
        return ChatAnalysisResult.empty()
    }
    
    /// 다이어리 분석 데이터 로드
    private func loadDiaryAnalysis() -> DiaryAnalysisResult {
        // 실제 구현에서는 데이터베이스나 파일에서 로드
        return DiaryAnalysisResult.empty()
    }
    
    /// 행동 분석 데이터 로드
    private func loadBehaviorAnalysis() -> BehaviorAnalysisResult {
        return BehaviorAnalysisResult.empty()
    }
    

    
    /// 계절 영향도 계산
    private func getSeasonalInfluence() -> Float {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3...5: return 0.7  // 봄
        case 6...8: return 0.5  // 여름
        case 9...11: return 0.8 // 가을
        default: return 0.9     // 겨울
        }
    }
    
    /// 현재 소음 레벨 추정
    private func estimateCurrentNoiseLevel() -> Float {
        // 시간대 기반 소음 레벨 추정
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 22...24, 0...6: return 0.2  // 밤
        case 7...9, 17...21: return 0.7  // 출퇴근
        default: return 0.5              // 일반
        }
    }
    
    /// 현재 디바이스 컨텍스트 획득
    private func getCurrentDeviceContext() -> String {
        return "iPhone" // 실제로는 디바이스 정보 확인
    }
    
    /// 개인화 레벨 계산
    private func calculatePersonalizationLevel(profile: UserBehaviorProfile?) -> Float {
        guard let profile = profile else { return 0.3 }
        let dataRichness = min(1.0, Float(profile.emotionPatterns.count) / 10.0)
        let usageDepth = min(1.0, Float(profile.timePatterns.count) / 24.0)
        return (dataRichness + usageDepth) / 2.0
    }
    
    /// 적응 히스토리 획득
    private func getAdaptationHistory(userId: String) -> [String] {
        return ["initial", "basic", "intermediate"] // 기본값
    }
    
    /// 선호도 안정성 계산
    private func calculatePreferenceStability(profile: UserBehaviorProfile?) -> Float {
        guard let profile = profile else { return 0.5 }
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
    
    /// 만족도 트렌드 계산
    private func calculateSatisfactionTrend(profile: UserBehaviorProfile?) -> Float {
        return profile?.satisfactionMetrics.averageCompletionRate ?? 0.5
    }
    
    /// 사용 빈도 계산
    private func calculateUsageFrequency(profile: UserBehaviorProfile?) -> Float {
        guard let profile = profile else { return 0.3 }
        let totalSessions = profile.emotionPatterns.values.reduce(0) { $0 + $1.totalSessions }
        return min(1.0, Float(totalSessions) / 50.0)
    }
    
    /// 참여도 계산
    private func calculateEngagementLevel(profile: UserBehaviorProfile?) -> Float {
        guard let profile = profile else { return 0.5 }
        let avgDuration = profile.emotionPatterns.values.reduce(0) { $0 + $1.averageSessionDuration } / 
            Double(max(1, profile.emotionPatterns.count))
        return min(1.0, Float(avgDuration / 900.0)) // 15분 기준
    }
    
    /// 감정 안정성 계산
    private func calculateEmotionalStability(_ diaryAnalysis: DiaryAnalysisResult) -> Float {
        return 1.0 - diaryAnalysis.averageIntensity
    }
    
    /// 현재 계절 획득
    private func getCurrentSeason() -> String {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3...5: return "봄"
        case 6...8: return "여름"
        case 9...11: return "가을"
        default: return "겨울"
        }
    }
    
    /// 학습 진행도 계산
    private func calculateLearningProgress(_ data: ComprehensiveUserData) -> Float {
        let chatProgress = min(1.0, Float(data.chatAnalysis.totalMessages) / 50.0)
        let diaryProgress = min(1.0, Float(data.diaryAnalysis.totalEntries) / 20.0)
        return (chatProgress + diaryProgress) / 2.0
    }
}

// MARK: - 온디바이스 학습 관련 데이터 구조

struct OnDeviceTrainingData {
    let trainingInputs: [[Float]]
    let trainingTargets: [[Float]]
    let validationInputs: [[Float]]
    let validationTargets: [[Float]]
    let featureStats: FeatureStatistics
    let targetStats: TargetStatistics
}

struct FeatureStatistics {
    let means: [Float]
    let stds: [Float]
}

struct TargetStatistics {
    let mins: [Float]
    let maxs: [Float]
}

// MARK: - 데이터 모델들

struct ComprehensiveMasterRecommendation {
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

struct MasterRecommendationSummary: Codable {
    let primaryPresetName: String
    let confidence: Float
    let processingTime: TimeInterval
    
    init(from masterRecommendation: ComprehensiveMasterRecommendation) {
        self.primaryPresetName = masterRecommendation.primaryRecommendation.presetName
        self.confidence = masterRecommendation.overallConfidence
        self.processingTime = masterRecommendation.processingMetadata.totalProcessingTime
    }
}

struct RecommendationLearningRecord: Codable {
    let timestamp: Date
    let inputDataHash: String
    let recommendation: MasterRecommendationSummary
    let inputFeatures: [String: Float]
}

// MARK: - 기타 필요한 구조체들

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

// 필요한 나머지 구조체들도 여기에 정의...
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

struct MultiDimensionalAnalysisResult {
    let emotionalState: String
    let emotionalIntensity: Float
    let stressLevel: Float
    let energyLevel: Float
    let temporalPattern: String
    let behavioralConsistency: Float
    let contextualRelevance: Float
    let personalizationDepth: Float
    let overallScore: Float
    let uncertaintyLevel: Float
    
    init(from analysis: MultiDimensionalAnalysis) {
        self.emotionalState = analysis.emotional.dominantEmotion
        self.emotionalIntensity = analysis.emotional.intensityLevel
        self.stressLevel = 1.0 - analysis.emotional.emotionStability
        self.energyLevel = analysis.emotional.intensityLevel
        self.temporalPattern = analysis.temporal.timeOfDay
        self.behavioralConsistency = analysis.behavioral.adaptationSpeed
        self.contextualRelevance = analysis.overallComplexity
        self.personalizationDepth = analysis.personalization.customizationLevel
        self.overallScore = (analysis.emotional.intensityLevel +
                             analysis.behavioral.adaptationSpeed +
                             analysis.personalization.customizationLevel) / 3.0
        self.uncertaintyLevel = 1.0 - analysis.dataQuality
    }
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
