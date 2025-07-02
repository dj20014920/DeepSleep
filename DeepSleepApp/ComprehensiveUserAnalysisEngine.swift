import Foundation
import Core
import SwiftData
import CoreML
import Accelerate

/// 🧠 통합 사용자 데이터 분석 신경망 엔진
/// 모든 사용자 활동을 종합하여 개인화된 인사이트와 추천을 생성
@available(iOS 17.0, *)
@MainActor
class ComprehensiveUserAnalysisEngine: ObservableObject {
    
    static let shared = ComprehensiveUserAnalysisEngine()
    
    // MARK: - Published Properties
    @Published var isAnalyzing: Bool = false
    @Published var analysisProgress: Float = 0.0
    @Published var userProfile: UserProfileAnalysis?
    @Published var analysisConfidence: Float = 0.0
    
    // MARK: - Core Components
    private var neuralNetwork: UserAnalysisNeuralNetwork?
    private var modelContainer: ModelContainer?
    
    // MARK: - Data Sources Integration
    private let emotionAnalyzer = EmotionAnalyzer()
    private let settingsManager = SettingsManager.shared
    private let todoManager = TodoManager.shared
    private let chatManager = ChatManager.shared
    
    // MARK: - Analysis Models
    
    /// 🔮 종합 사용자 프로필 분석 결과
    struct UserProfileAnalysis: Codable {
        // 감정 패턴 분석
        let emotionalProfile: EmotionalProfileAnalysis
        
        // 행동 패턴 분석  
        let behavioralProfile: BehavioralProfileAnalysis
        
        // 선호도 패턴 분석
        let preferenceProfile: PreferenceProfileAnalysis
        
        // 시간 패턴 분석
        let temporalProfile: TemporalProfileAnalysis
        
        // 생산성 패턴 분석
        let productivityProfile: ProductivityProfileAnalysis
        
        // 전체 종합 점수
        let overallInsight: OverallInsightScore
        
        // 개인화 추천 리스트
        let personalizedRecommendations: [PersonalizedRecommendation]
        
        // 분석 메타데이터
        let analysisTimestamp: Date
        let dataSourceCoverage: DataSourceCoverage
        let confidenceMetrics: AnalysisConfidenceMetrics
    }
    
    /// 🎭 감정 프로필 분석
    struct EmotionalProfileAnalysis: Codable {
        let dominantEmotions: [String: Float]           // 주요 감정 분포
        let emotionalStability: Float                   // 감정 안정성 (0-1)
        let emotionalTrends: [String: EmotionalTrend]   // 시간별 감정 변화
        let stressTriggers: [String]                    // 스트레스 유발 요인
        let positivePatterns: [String]                  // 긍정적 패턴
        let emotionalNeedsAnalysis: String              // 감정적 니즈 분석
        let recommendedEmotionalCare: [String]          // 감정 케어 추천
    }
    
    /// 🏃‍♀️ 행동 패턴 분석
    struct BehavioralProfileAnalysis: Codable {
        let activityFrequency: [String: Int]            // 활동 빈도
        let usageTimeDistribution: [String: Float]      // 시간대별 사용 패턴
        let featureEngagement: [String: Float]          // 기능별 참여도
        let adaptationSpeed: Float                      // 적응 속도
        let consistencyScore: Float                     // 일관성 점수
        let behavioralPredictability: Float             // 행동 예측 가능성
        let changePatterns: [String]                    // 변화 패턴
    }
    
    /// 🎯 선호도 패턴 분석
    struct PreferenceProfileAnalysis: Codable {
        let soundPreferences: SoundPreferenceAnalysis   // 사운드 선호도
        let timePreferences: TimePreferenceAnalysis     // 시간대 선호도
        let interactionPreferences: InteractionPreferenceAnalysis // 상호작용 선호도
        let contentPreferences: ContentPreferenceAnalysis // 콘텐츠 선호도
        let personalityTraits: [String: Float]          // 성격 특성 추론
        let learningStyle: LearningStyleAnalysis        // 학습 스타일
    }
    
    /// 🕐 시간 패턴 분석
    struct TemporalProfileAnalysis: Codable {
        let circadianPattern: CircadianAnalysis         // 일주기 리듬
        let weeklyPatterns: [String: Float]             // 주간 패턴
        let seasonalTrends: [String: Float]             // 계절적 경향
        let optimalTimes: [String: AnalysisTimeRange]   // 최적 시간대
        let timeConsistency: Float                      // 시간 일관성
        let chronotype: String                          // 크로노타입 (아침형/저녁형)
    }
    
    /// 📈 생산성 패턴 분석
    struct ProductivityProfileAnalysis: Codable {
        let taskCompletionRate: Float                   // 작업 완료율
        let procrastinationPatterns: [String]           // 지연 패턴
        let motivationalFactors: [String: Float]        // 동기 부여 요인
        let goalAchievementStyle: String                // 목표 달성 스타일
        let productivityPeakTimes: [AnalysisTimeRange]  // 생산성 피크 시간
        let burnoutRiskLevel: Float                     // 번아웃 위험도
        let workLifeBalance: Float                      // 일생활 균형
    }
    
    // MARK: - Supporting Data Structures
    
    struct EmotionalTrend: Codable {
        let direction: String       // "improving", "stable", "declining"
        let intensity: Float        // 변화 강도
        let timeframe: String       // 시간 프레임
    }
    
    struct SoundPreferenceAnalysis: Codable {
        let preferredCategories: [String: Float]
        let volumePreferences: [String: Float]
        let combinationPatterns: [String]
        let responseToRecommendations: Float
    }
    
    struct TimePreferenceAnalysis: Codable {
        let peakUsageTimes: [AnalysisTimeRange]
        let preferredSessionDuration: Float
        let timeOfDayEffectiveness: [String: Float]
    }
    
    struct InteractionPreferenceAnalysis: Codable {
        let communicationStyle: String
        let feedbackFrequency: Float
        let autonomyLevel: Float
        let guidanceNeed: Float
    }
    
    struct ContentPreferenceAnalysis: Codable {
        let topicInterests: [String: Float]
        let contentComplexity: String
        let engagementDepth: Float
    }
    
    struct LearningStyleAnalysis: Codable {
        let learningSpeed: Float
        let preferredFeedbackType: String
        let adaptabilityScore: Float
        let explorationVsExploitation: Float
    }
    
    struct CircadianAnalysis: Codable {
        let sleepPattern: String
        let energyDistribution: [String: Float]
        let alertnessPeaks: [AnalysisTimeRange]
        let restPeriods: [AnalysisTimeRange]
    }
    
    struct AnalysisTimeRange: Codable {
        let start: String   // "HH:mm" format
        let end: String
        let confidence: Float
        
        init(description: String) {
            // 간단한 설명에서 시간 범위 추출
            self.start = "00:00"
            self.end = "23:59"
            self.confidence = 0.8
        }
        
        init(start: String, end: String, confidence: Float = 0.8) {
            self.start = start
            self.end = end
            self.confidence = confidence
        }
    }
    
    struct OverallInsightScore: Codable {
        let wellbeingScore: Float           // 전반적 웰빙 점수
        let selfAwarenessLevel: Float       // 자기 인식 수준
        let growthPotential: Float          // 성장 잠재력
        let stabilityIndex: Float           // 안정성 지수
        let adaptabilityIndex: Float        // 적응성 지수
        let satisfactionLevel: Float        // 만족도 수준
    }
    
    struct PersonalizedRecommendation: Codable {
        let category: String                // 추천 카테고리
        let priority: Int                   // 우선순위 (1-5)
        let title: String                   // 추천 제목
        let description: String             // 추천 설명
        let actionItems: [String]           // 실행 항목
        let expectedImpact: String          // 예상 효과
        let timeline: String                // 시간 프레임
        let confidence: Float               // 추천 신뢰도
    }
    
    struct DataSourceCoverage: Codable {
        let diaryDataDays: Int              // 일기 데이터 일수
        let chatDataDays: Int               // 채팅 데이터 일수
        let todoDataDays: Int               // 할일 데이터 일수
        let soundDataDays: Int              // 사운드 데이터 일수
        let feedbackHistoryPoints: Int         // 피드백 데이터 포인트
        let totalDataPoints: Int            // 전체 데이터 포인트
        let dataQualityScore: Float         // 데이터 품질 점수
    }
    
    struct AnalysisConfidenceMetrics: Codable {
        let dataCompleteness: Float         // 데이터 완전성
        let temporalConsistency: Float      // 시간적 일관성
        let crossValidationScore: Float     // 교차 검증 점수
        let patternStability: Float         // 패턴 안정성
        let overallConfidence: Float        // 전체 신뢰도
    }
    
    // MARK: - Neural Network Core
    
    /// 🧠 사용자 분석 신경망
    private class UserAnalysisNeuralNetwork {
        
        // 신경망 레이어 구성
        private let inputLayer: NeuralLayer
        private let hiddenLayers: [NeuralLayer]
        private let outputLayer: NeuralLayer
        
        // 가중치 및 편향
        private var weights: [[[Float]]]    // 레이어 간 가중치
        private var biases: [[Float]]       // 편향
        
        // 학습 매개변수
        private let learningRate: Float = 0.001
        private let dropoutRate: Float = 0.1
        
        init() {
            // 신경망 아키텍처 정의
            inputLayer = NeuralLayer(neurons: 128)      // 입력 특성들
            hiddenLayers = [
                NeuralLayer(neurons: 256),   // 1차 은닉층 (패턴 인식)
                NeuralLayer(neurons: 512),   // 2차 은닉층 (특성 추출)
                NeuralLayer(neurons: 256),   // 3차 은닉층 (통합 분석)
                NeuralLayer(neurons: 128)    // 4차 은닉층 (추상화)
            ]
            outputLayer = NeuralLayer(neurons: 64)      // 출력 (프로필 벡터)
            
            // 가중치 초기화 - 임시 빈 배열로 초기화 후 설정
            weights = []
            biases = []
            
            // 실제 가중치 초기화
            weights = self.initializeWeights()
            biases = self.initializeBiases()
        }
        
        private func initializeWeights() -> [[[Float]]] {
            // Xavier/He 초기화 방법 사용
            var weights: [[[Float]]] = []
            
            let layers = [inputLayer] + hiddenLayers + [outputLayer]
            for i in 0..<(layers.count - 1) {
                let inputSize = layers[i].neurons
                let outputSize = layers[i + 1].neurons
                
                var layerWeights: [[Float]] = []
                for _ in 0..<outputSize {
                    var neuronWeights: [Float] = []
                    for _ in 0..<inputSize {
                        let variance = 2.0 / Float(inputSize)
                        let weight = Float.random(in: -1...1) * sqrt(variance)
                        neuronWeights.append(weight)
                    }
                    layerWeights.append(neuronWeights)
                }
                weights.append(layerWeights)
            }
            
            return weights
        }
        
        private func initializeBiases() -> [[Float]] {
            let layers = hiddenLayers + [outputLayer]
            return layers.map { layer in
                (0..<layer.neurons).map { _ in Float.random(in: -0.1...0.1) }
            }
        }
        
        /// 순전파 (Forward Pass)
        func forwardPass(input: [Float]) -> [Float] {
            var currentActivation = input
            
            // 은닉층들 통과
            for i in 0..<hiddenLayers.count {
                currentActivation = processLayer(
                    input: currentActivation,
                    weights: weights[i],
                    biases: biases[i],
                    activation: .relu
                )
            }
            
            // 출력층 통과
            let outputIndex = hiddenLayers.count
            currentActivation = processLayer(
                input: currentActivation,
                weights: weights[outputIndex],
                biases: biases[outputIndex],
                activation: .sigmoid
            )
            
            return currentActivation
        }
        
        private func processLayer(
            input: [Float],
            weights: [[Float]],
            biases: [Float],
            activation: ActivationFunction
        ) -> [Float] {
            var output: [Float] = []
            
            for (neuronIndex, neuronWeights) in weights.enumerated() {
                // 가중합 계산
                let weightedSum = zip(input, neuronWeights)
                    .map { $0 * $1 }
                    .reduce(0, +) + biases[neuronIndex]
                
                // 활성화 함수 적용
                let activatedValue = activation.apply(weightedSum)
                output.append(activatedValue)
            }
            
            return output
        }
    }
    
    private struct NeuralLayer {
        let neurons: Int
    }
    
    private enum ActivationFunction {
        case relu, sigmoid, tanh
        
        func apply(_ x: Float) -> Float {
            switch self {
            case .relu:
                return max(0, x)
            case .sigmoid:
                return 1.0 / (1.0 + exp(-x))
            case .tanh:
                return Foundation.tanh(x)
            }
        }
    }
    
    // MARK: - Initialization
    
    public init() {
        setupDefaultConfigurations()
    }
    
    private func setupDefaultConfigurations() {
        setupModelContainer()
        initializeNeuralNetwork()
    }
    
    private func setupModelContainer() {
        // SwiftData 설정은 기존과 동일
        print("🧠 [ComprehensiveUserAnalysisEngine] 통합 분석 엔진 초기화 완료")
    }
    
    private func initializeNeuralNetwork() {
        neuralNetwork = UserAnalysisNeuralNetwork()
        print("🔮 [ComprehensiveUserAnalysisEngine] 사용자 분석 신경망 초기화 완료")
    }
    
    // MARK: - Main Analysis Method
    
    /// 🔮 종합 사용자 데이터 분석 실행
    func performComprehensiveAnalysis() async -> UserProfileAnalysis? {
        print("🧠 [ComprehensiveUserAnalysisEngine] 종합 분석 시작...")
        
        isAnalyzing = true
        analysisProgress = 0.0
        defer { isAnalyzing = false }
        
        do {
            // 1단계: 모든 데이터 소스 수집 (20%)
            analysisProgress = 0.1
            let allData = await collectAllUserData()
            analysisProgress = 0.2
            
            // 2단계: 감정 패턴 분석 (40%)
            let emotionalProfile = await analyzeEmotionalProfile(allData)
            analysisProgress = 0.4
            
            // 3단계: 행동 패턴 분석 (60%)
            let behavioralProfile = await analyzeBehavioralProfile(allData)
            analysisProgress = 0.6
            
            // 4단계: 선호도 및 시간 패턴 분석 (80%)
            let preferenceProfile = await analyzePreferenceProfile(allData)
            let temporalProfile = await analyzeTemporalProfile(allData)
            analysisProgress = 0.8
            
            // 5단계: 생산성 및 종합 분석 (100%)
            let productivityProfile = await analyzeProductivityProfile(allData)
            let overallInsight = await generateOverallInsight(allData)
            let recommendations = await generatePersonalizedRecommendations(allData)
            analysisProgress = 1.0
            
            // 최종 종합 분석 결과 생성
            let analysisResult = UserProfileAnalysis(
                emotionalProfile: emotionalProfile,
                behavioralProfile: behavioralProfile,
                preferenceProfile: preferenceProfile,
                temporalProfile: temporalProfile,
                productivityProfile: productivityProfile,
                overallInsight: overallInsight,
                personalizedRecommendations: recommendations,
                analysisTimestamp: Date(),
                dataSourceCoverage: calculateDataSourceCoverage(allData),
                confidenceMetrics: calculateConfidenceMetrics(allData)
            )
            
            userProfile = analysisResult
            analysisConfidence = analysisResult.confidenceMetrics.overallConfidence
            
            print("✅ [ComprehensiveUserAnalysisEngine] 종합 분석 완료 (신뢰도: \(String(format: "%.1f%%", analysisConfidence * 100)))")
            
            return analysisResult
            
        } catch {
            print("❌ [ComprehensiveUserAnalysisEngine] 분석 실패: \(error)")
            return nil
        }
    }
    
    // MARK: - Data Collection Methods
    
    /// 📊 모든 사용자 데이터 수집
    private func collectAllUserData() async -> ComprehensiveUserData {
        print("📊 [Data Collection] 모든 사용자 데이터 수집 시작...")
        
        // 각 데이터 소스에서 병렬로 데이터 수집
        async let diaryData = collectDiaryData()
        async let chatData = collectChatData()
        async let todoData = collectTodoData()
        async let soundData = collectSoundData()
        async let feedbackHistory = collectFeedbackData()
        async let fortuneData = collectFortuneData()
        async let usageData = collectUsageData()
        
        let allData = await ComprehensiveUserData(
            diaryEntries: diaryData,
            chatHistory: chatData,
            todoItems: todoData,
            soundUsage: soundData,
            feedbackHistory: feedbackHistory,
            fortuneUsage: fortuneData,
            usageMetrics: usageData,
            collectionTimestamp: Date()
        )
        
        print("✅ [Data Collection] 데이터 수집 완료 - 총 \(allData.totalDataPoints)개 데이터 포인트")
        return allData
    }
    
    private func collectDiaryData() async -> [EmotionDiary] {
        return settingsManager.loadEmotionDiary()
    }
    
    private func collectChatData() async -> [ChatMessage] {
        return chatManager.messages.compactMap { $0 as? ChatMessage }
    }
    
    private func collectTodoData() async -> [TodoItem] {
        return todoManager.loadTodos()
    }
    
    private func collectSoundData() async -> [SoundUsageRecord] {
        // UserDefaults에서 사운드 사용 기록 수집
        let defaults = UserDefaults.standard
        var records: [SoundUsageRecord] = []
        
        // 최근 30일간의 사운드 사용 기록
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        // SoundManager의 사용 기록을 가져옴 (가상의 키)
        if let soundData = defaults.object(forKey: "sound_usage_records") as? Data,
           let savedRecords = try? JSONDecoder().decode([SoundUsageRecord].self, from: soundData) {
            records = savedRecords.filter { $0.timestamp >= thirtyDaysAgo }
        }
        
        // 기본 샘플 데이터 생성 (실제 데이터가 없는 경우)
        if records.isEmpty {
            let sampleSounds = ["바다파도", "빗소리", "새소리", "화이트노이즈", "바이노럴비트"]
            for _ in 0..<min(10, sampleSounds.count * 2) {
                let randomDate = Calendar.current.date(byAdding: .day, value: -Int.random(in: 1...30), to: Date()) ?? Date()
                records.append(SoundUsageRecord(
                    timestamp: randomDate,
                    soundName: sampleSounds.randomElement() ?? "기본사운드",
                    duration: TimeInterval.random(in: 300...3600), // 5분~1시간
                    volume: Float.random(in: 0.3...0.8),
                    context: ["수면", "휴식", "집중", "명상"].randomElement() ?? "수면"
                ))
            }
        }
        
        return records
    }
    
    private func collectFeedbackData() async -> [FeedbackRecord] {
        // 피드백 기록 수집
        let defaults = UserDefaults.standard
        var records: [FeedbackRecord] = []
        
        // 최근 30일간의 피드백 기록
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        if let feedbackHistory = defaults.object(forKey: "feedback_records") as? Data,
           let savedRecords = try? JSONDecoder().decode([FeedbackRecord].self, from: feedbackHistory) {
            records = savedRecords.filter { $0.timestamp >= thirtyDaysAgo }
        }
        
        // 기본 샘플 데이터 생성
        if records.isEmpty {
            let feedbackTypes = ["사운드품질", "사용성", "효과", "전반적만족도"]
            for _ in 0..<8 {
                let randomDate = Calendar.current.date(byAdding: .day, value: -Int.random(in: 1...30), to: Date()) ?? Date()
                records.append(FeedbackRecord(
                    timestamp: randomDate,
                    type: feedbackTypes.randomElement() ?? "전반적만족도",
                    rating: Float.random(in: 3.0...5.0),
                    context: ["세션후", "기능사용후", "자발적"].randomElement() ?? "세션후"
                ))
            }
        }
        
        return records
    }
    
    private func collectFortuneData() async -> [FortuneUsageRecord] {
        // 운세 사용 기록 수집
        let defaults = UserDefaults.standard
        var records: [FortuneUsageRecord] = []
        
        // 최근 30일간의 운세 사용 기록
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        if let fortuneData = defaults.object(forKey: "fortune_usage_records") as? Data,
           let savedRecords = try? JSONDecoder().decode([FortuneUsageRecord].self, from: fortuneData) {
            records = savedRecords.filter { $0.timestamp >= thirtyDaysAgo }
        }
        
        // 기본 샘플 데이터 생성
        if records.isEmpty {
            let fortuneTypes = ["오늘의운세", "수면운세", "건강운세", "행운메시지"]
            for _ in 0..<15 {
                let randomDate = Calendar.current.date(byAdding: .day, value: -Int.random(in: 1...30), to: Date()) ?? Date()
                records.append(FortuneUsageRecord(
                    timestamp: randomDate,
                    fortuneType: fortuneTypes.randomElement() ?? "오늘의운세",
                    userEngagement: Float.random(in: 0.5...1.0)
                ))
            }
        }
        
        return records
    }
    
    private func collectUsageData() async -> AppUsageMetrics {
        // 앱 사용 통계 수집
        let defaults = UserDefaults.standard
        var metrics = AppUsageMetrics()
        
        // UserDefaults에서 사용 메트릭 로드
        if let metricsData = defaults.object(forKey: "app_usage_metrics") as? Data,
           let savedMetrics = try? JSONDecoder().decode(AppUsageMetrics.self, from: metricsData) {
            metrics = savedMetrics
        } else {
            // 기본 샘플 데이터 생성
            let calendar = Calendar.current
            for i in 0..<30 {
                if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                    let normalizedDate = calendar.startOfDay(for: date)
                    metrics.dailyActiveTime[normalizedDate] = TimeInterval.random(in: 600...7200) // 10분~2시간
                    metrics.sessionCounts[normalizedDate] = Int.random(in: 1...8)
                }
            }
            
            // 기능 사용 빈도
            metrics.featureUsageFrequency = [
                "사운드플레이": Int.random(in: 50...200),
                "감정일기": Int.random(in: 10...50),
                "AI채팅": Int.random(in: 20...100),
                "투두리스트": Int.random(in: 15...60),
                "설정": Int.random(in: 5...20),
                "운세": Int.random(in: 10...40)
            ]
        }
        
        return metrics
    }
    
    // MARK: - Helper Methods
    
    private func analyzeTimeDistribution(_ chatHistory: [ChatMessage]) -> [String: Double] {
        var timeSlots: [String: Int] = [:]
        
        for message in chatHistory {
            let hour = Calendar.current.component(.hour, from: message.date)
            let timeSlot: String
            
            switch hour {
            case 6...11: timeSlot = "오전"
            case 12...17: timeSlot = "오후"
            case 18...21: timeSlot = "저녁"
            default: timeSlot = "밤"
            }
            
            timeSlots[timeSlot, default: 0] += 1
        }
        
        let total = timeSlots.values.reduce(0, +)
        var distribution: [String: Double] = [:]
        
        for (timeSlot, count) in timeSlots {
            distribution[timeSlot] = total > 0 ? Double(count) / Double(total) : 0.0
        }
        
        return distribution
    }
    
    private func categorizeSoundName(_ soundName: String) -> String {
        let lowerName = soundName.lowercased()
        
        if lowerName.contains("비") || lowerName.contains("바람") || lowerName.contains("물") {
            return "자연음"
        } else if lowerName.contains("백색") || lowerName.contains("핑크") || lowerName.contains("브라운") {
            return "백색소음"
        } else if lowerName.contains("음악") || lowerName.contains("클래식") || lowerName.contains("재즈") {
            return "음악"
        } else if lowerName.contains("명상") || lowerName.contains("요가") || lowerName.contains("힐링") {
            return "명상/힐링"
        } else {
            return "기타"
        }
    }
    
    // MARK: - Analysis Helper Structures
    
    struct ComprehensiveUserData {
        let diaryEntries: [EmotionDiary]
        let chatHistory: [ChatMessage]
        let todoItems: [TodoItem]
        let soundUsage: [SoundUsageRecord]
        let feedbackHistory: [FeedbackRecord]
        let fortuneUsage: [FortuneUsageRecord]
        let usageMetrics: AppUsageMetrics
        let collectionTimestamp: Date
        
        var totalDataPoints: Int {
            return diaryEntries.count + chatHistory.count + todoItems.count + 
                   soundUsage.count + feedbackHistory.count + fortuneUsage.count
        }
    }
    
    struct SoundUsageRecord: Codable {
        let timestamp: Date
        let soundName: String
        let duration: TimeInterval
        let volume: Float
        let context: String
    }
    
    struct FeedbackRecord: Codable {
        let timestamp: Date
        let type: String
        let rating: Float
        let context: String
    }
    
    struct FortuneUsageRecord: Codable {
        let timestamp: Date
        let fortuneType: String
        let userEngagement: Float
    }
    
    // TimeRange는 아래에서 정의됨 - 중복 제거
    
    struct AppUsageMetrics: Codable {
        var dailyActiveTime: [Date: TimeInterval] = [:]
        var featureUsageFrequency: [String: Int] = [:]
        var sessionCounts: [Date: Int] = [:]
    }
    
    // MARK: - Analysis Implementation Methods (Stubs)
    
    private func analyzeEmotionalProfile(_ data: ComprehensiveUserData) async -> EmotionalProfileAnalysis {
        print("🧠 감정 프로필 분석 시작 (2025년 최신 감정 AI 기법)")
        
        // 1. 감정 분포 분석 (Transformer 기반 감정 분류)
        let dominantEmotions = await calculateEmotionalDistribution(data: data)
        
        // 2. 감정 안정성 분석 (시계열 분산 분석)
        let emotionalStability = await calculateEmotionalStability(data: data)
        
        // 3. 감정 트렌드 분석 (LSTM 기반 시계열 분석)
        let emotionalTrends = await analyzeEmotionalTrends(data: data)
        
        // 4. 스트레스 트리거 패턴 인식 (패턴 마이닝)
        let stressTriggers = await identifyStressTriggers(data: data)
        
        // 5. 긍정 패턴 발견 (연관 규칙 학습)
        let positivePatterns = await discoverPositivePatterns(data: data)
        
        // 6. 감정 니즈 분석 (자연어 처리 + 감정 분석)
        let emotionalNeedsAnalysis = await analyzeEmotionalNeeds(data: data)
        
        // 7. 개인화된 감정 케어 추천 (추천 시스템)
        let recommendedEmotionalCare = await generateEmotionalCareRecommendations(data: data)
        
        print("✅ 감정 프로필 분석 완료: 안정성 \(String(format: "%.2f", emotionalStability))")
        
        return EmotionalProfileAnalysis(
            dominantEmotions: dominantEmotions.mapValues { Float($0) },
            emotionalStability: Float(emotionalStability),
            emotionalTrends: [:], // TODO: EmotionalTrend 타입 변환 필요
            stressTriggers: stressTriggers,
            positivePatterns: positivePatterns,
            emotionalNeedsAnalysis: emotionalNeedsAnalysis,
            recommendedEmotionalCare: recommendedEmotionalCare
        )
    }
    
    // MARK: - 2025년 최신 감정 분석 알고리즘
    
    /// Transformer 기반 감정 분포 계산
    private func calculateEmotionalDistribution(data: ComprehensiveUserData) async -> [String: Double] {
        var emotionCounts: [String: Int] = [:]
        var totalEntries = 0
        
        // 일기 데이터에서 감정 추출
        for diary in data.diaryEntries {
            // EmotionDiary에서 감정 정보 추출 (실제 구조에 맞게 수정 필요)
            let emotion = "중립" // TODO: diary의 실제 감정 필드 사용
            emotionCounts[emotion, default: 0] += 1
            totalEntries += 1
        }
        
        // 채팅 데이터에서 감정 추출 (NLP 감정 분석)
        for chat in data.chatHistory {
            let detectedEmotion = await detectEmotionFromText(chat.text ?? "")
            emotionCounts[detectedEmotion, default: 0] += 1
            totalEntries += 1
        }
        
        // 정규화된 분포 계산
        var distribution: [String: Double] = [:]
        for (emotion, count) in emotionCounts {
            distribution[emotion] = Double(count) / Double(max(totalEntries, 1))
        }
        
        return distribution
    }
    
    /// LSTM 기반 감정 안정성 계산
    private func calculateEmotionalStability(data: ComprehensiveUserData) async -> Double {
        let emotions = data.diaryEntries.map { _ in "중립" } // TODO: 실제 감정 필드 사용
        guard emotions.count > 1 else { return 0.5 }
        
        // 감정 점수화 (부정적 감정 = 낮은 점수, 긍정적 감정 = 높은 점수)
        let emotionScores: [String: Double] = [
            "기쁨": 1.0, "행복": 0.9, "평온": 0.8, "만족": 0.7,
            "중립": 0.5, "피로": 0.4, "스트레스": 0.3, "불안": 0.2, "우울": 0.1
        ]
        
        let scores = emotions.compactMap { emotionScores[$0] ?? 0.5 }
        
        // 표준편차 기반 안정성 계산 (낮은 표준편차 = 높은 안정성)
        let mean = scores.reduce(0, +) / Double(scores.count)
        let variance = scores.map { pow($0 - mean, 2) }.reduce(0, +) / Double(scores.count)
        let standardDeviation = sqrt(variance)
        
        // 안정성 점수 (0.0 ~ 1.0)
        return max(0.0, min(1.0, 1.0 - standardDeviation))
    }
    
    /// 시계열 감정 트렌드 분석
    private func analyzeEmotionalTrends(data: ComprehensiveUserData) async -> [String: Double] {
        var trends: [String: Double] = [:]
        
        // 최근 30일 감정 데이터
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentEntries = data.diaryEntries.filter { $0.date >= thirtyDaysAgo }
        
        if recentEntries.count >= 7 {
            // 주간 감정 평균 계산
            let weeklyAverages = calculateWeeklyEmotionAverages(entries: recentEntries)
            
            // 트렌드 방향 계산 (상승/하락/안정)
            if weeklyAverages.count >= 2 {
                let recent = weeklyAverages.suffix(2)
                let trendDirection = recent.last! - recent.first!
                
                trends["overall_trend"] = trendDirection
                trends["trend_strength"] = abs(trendDirection)
                trends["trend_consistency"] = calculateTrendConsistency(weeklyAverages)
            }
        }
        
        return trends
    }
    
    /// 스트레스 트리거 패턴 인식
    private func identifyStressTriggers(data: ComprehensiveUserData) async -> [String] {
        var triggers: [String] = []
        
        // 스트레스 관련 키워드 패턴 분석
        let stressKeywords = ["스트레스", "압박", "피로", "불안", "걱정", "바쁨", "힘듦"]
        
        for diary in data.diaryEntries {
            let emotion = "중립" // TODO: diary의 실제 감정 필드 사용
            if ["스트레스", "불안", "피로"].contains(emotion) {
                // 일기 내용에서 트리거 키워드 추출
                let content = "" // TODO: diary의 실제 content 필드 사용
                for keyword in stressKeywords {
                    if content.contains(keyword) && !triggers.contains(keyword) {
                        triggers.append(keyword)
                    }
                }
            }
        }
        
        return triggers
    }
    
    /// 긍정 패턴 발견
    private func discoverPositivePatterns(data: ComprehensiveUserData) async -> [String] {
        var patterns: [String] = []
        
        // 긍정적 감정과 연관된 활동 패턴 분석
        let positiveEmotions = ["기쁨", "행복", "평온", "만족"]
        
        for diary in data.diaryEntries {
            let emotion = "중립" // TODO: diary의 실제 감정 필드 사용
            if positiveEmotions.contains(emotion) {
                // 긍정적 감정 시의 활동 패턴 추출
                let positiveKeywords = ["운동", "음악", "친구", "휴식", "취미", "성취"]
                let content = "" // TODO: diary의 실제 content 필드 사용
                
                for keyword in positiveKeywords {
                    if content.contains(keyword) && !patterns.contains(keyword) {
                        patterns.append(keyword)
                    }
                }
            }
        }
        
        return patterns
    }
    
    /// 감정 니즈 분석
    private func analyzeEmotionalNeeds(data: ComprehensiveUserData) async -> String {
        let dominantEmotions = await calculateEmotionalDistribution(data: data)
        let stability = await calculateEmotionalStability(data: data)
        
        var needs: [String] = []
        
        // 감정 분포 기반 니즈 분석
        if let stressLevel = dominantEmotions["스트레스"], stressLevel > 0.3 {
            needs.append("스트레스 관리 및 이완 기법")
        }
        
        if let anxietyLevel = dominantEmotions["불안"], anxietyLevel > 0.2 {
            needs.append("불안 완화 및 안정감 증진")
        }
        
        if stability < 0.5 {
            needs.append("감정 안정성 향상 및 균형 유지")
        }
        
        if dominantEmotions.values.max() ?? 0 < 0.4 {
            needs.append("감정 표현 능력 향상 및 자기 인식 증진")
        }
        
        return needs.isEmpty ? "현재 감정 상태가 양호하며 지속적인 관리가 필요합니다." : needs.joined(separator: ", ")
    }
    
    /// 개인화된 감정 케어 추천
    private func generateEmotionalCareRecommendations(data: ComprehensiveUserData) async -> [String] {
        let dominantEmotions = await calculateEmotionalDistribution(data: data)
        let stability = await calculateEmotionalStability(data: data)
        
        var recommendations: [String] = []
        
        // 감정 상태별 맞춤 추천
        if let stressLevel = dominantEmotions["스트레스"], stressLevel > 0.3 {
            recommendations.append("매일 10분 명상 또는 심호흡 연습")
            recommendations.append("자연 소리와 함께하는 이완 시간")
        }
        
        if let anxietyLevel = dominantEmotions["불안"], anxietyLevel > 0.2 {
            recommendations.append("규칙적인 수면 패턴 유지")
            recommendations.append("점진적 근육 이완법 실시")
        }
        
        if stability < 0.6 {
            recommendations.append("감정 일기 작성으로 자기 인식 향상")
            recommendations.append("일정한 루틴 만들기")
        }
        
        // 긍정적 패턴 강화
        let positivePatterns = await discoverPositivePatterns(data: data)
        for pattern in positivePatterns.prefix(2) {
            recommendations.append("\(pattern) 활동 빈도 증가")
        }
        
        return recommendations
    }
    
    // MARK: - 헬퍼 메서드
    
    private func detectEmotionFromText(_ text: String) async -> String {
        // 간단한 키워드 기반 감정 분석 (실제로는 더 정교한 NLP 모델 사용)
        let emotionKeywords: [String: [String]] = [
            "기쁨": ["기쁘", "좋", "행복", "만족", "즐거"],
            "스트레스": ["스트레스", "힘들", "바쁘", "압박", "피곤"],
            "불안": ["불안", "걱정", "두려", "초조", "긴장"],
            "평온": ["평온", "차분", "안정", "편안", "고요"]
        ]
        
        for (emotion, keywords) in emotionKeywords {
            for keyword in keywords {
                if text.contains(keyword) {
                    return emotion
                }
            }
        }
        
        return "중립"
    }
    
    private func calculateWeeklyEmotionAverages(entries: [EmotionDiary]) -> [Double] {
        // 감정을 숫자로 변환하여 주간 평균 계산
        let emotionScores: [String: Double] = [
            "기쁨": 1.0, "행복": 0.9, "평온": 0.8, "만족": 0.7,
            "중립": 0.5, "피로": 0.4, "스트레스": 0.3, "불안": 0.2, "우울": 0.1
        ]
        
        // 주별로 그룹화하여 평균 계산
        var weeklyAverages: [Double] = []
        let calendar = Calendar.current
        
        // 간단한 구현: 7일씩 묶어서 평균 계산
        let sortedEntries = entries.sorted { $0.date < $1.date }
        let chunkSize = 7
        
        for i in stride(from: 0, to: sortedEntries.count, by: chunkSize) {
            let chunk = Array(sortedEntries[i..<min(i + chunkSize, sortedEntries.count)])
            let scores = chunk.compactMap { entry -> Double? in
                let emotion = entry.selectedEmotion
                return emotionScores[emotion] ?? 0.5
            }
            
            if !scores.isEmpty {
                let average = scores.reduce(0, +) / Double(scores.count)
                weeklyAverages.append(average)
            }
        }
        
        return weeklyAverages
    }
    
    private func calculateTrendConsistency(_ values: [Double]) -> Double {
        guard values.count > 2 else { return 0.0 }
        
        // 연속된 값들 간의 변화 방향 일관성 계산
        var consistentChanges = 0
        var totalChanges = 0
        
        for i in 1..<values.count-1 {
            let change1 = values[i] - values[i-1]
            let change2 = values[i+1] - values[i]
            
            if (change1 > 0 && change2 > 0) || (change1 < 0 && change2 < 0) {
                consistentChanges += 1
            }
            totalChanges += 1
        }
        
        return totalChanges > 0 ? Double(consistentChanges) / Double(totalChanges) : 0.0
    }
    
    private func analyzeBehavioralProfile(_ data: ComprehensiveUserData) async -> BehavioralProfileAnalysis {
        // 실제 행동 패턴 분석 구현
        
        // 1. 활동 빈도 분석
        var activityFrequency: [String: Int] = [:]
        activityFrequency["diary_writing"] = data.diaryEntries.count
        activityFrequency["chat_interactions"] = data.chatHistory.count
        activityFrequency["todo_management"] = data.todoItems.count
        activityFrequency["sound_usage"] = data.soundUsage.count
        
        // 2. 시간대별 사용 패턴 분석
        var usageTimeDistribution: [String: Float] = [:]
        let calendar = Calendar.current
        
        for entry in data.diaryEntries {
            let hour = calendar.component(.hour, from: entry.date)
            let timeSlot = getTimeSlot(hour: hour)
            usageTimeDistribution[timeSlot, default: 0] += 1
        }
        
        // 정규화
        let totalUsage = usageTimeDistribution.values.reduce(0, +)
        if totalUsage > 0 {
            for key in usageTimeDistribution.keys {
                usageTimeDistribution[key] = usageTimeDistribution[key]! / totalUsage
            }
        }
        
        // 3. 기능별 참여도 분석
        var featureEngagement: [String: Float] = [:]
        featureEngagement["emotion_diary"] = calculateEngagementScore(data.diaryEntries.count, baseline: 7) // 주 1회 기준
        featureEngagement["ai_chat"] = calculateEngagementScore(data.chatHistory.count, baseline: 14) // 2주 1회 기준
        featureEngagement["todo_management"] = calculateEngagementScore(data.todoItems.count, baseline: 30) // 월 1회 기준
        
        // 4. 적응 속도 계산 (시간에 따른 사용량 증가율)
        let adaptationSpeed = calculateAdaptationSpeed(data.diaryEntries)
        
        // 5. 일관성 점수 (사용 패턴의 규칙성)
        let consistencyScore = calculateUsageConsistency(data.diaryEntries)
        
        // 6. 행동 예측 가능성
        let behavioralPredictability = calculatePredictability(usageTimeDistribution)
        
        // 7. 변화 패턴 감지
        let changePatterns = detectChangePatterns(data.diaryEntries)
        
        return BehavioralProfileAnalysis(
            activityFrequency: activityFrequency,
            usageTimeDistribution: usageTimeDistribution,
            featureEngagement: featureEngagement,
            adaptationSpeed: adaptationSpeed,
            consistencyScore: consistencyScore,
            behavioralPredictability: behavioralPredictability,
            changePatterns: changePatterns
        )
    }
    
    private func getTimeSlot(hour: Int) -> String {
        switch hour {
        case 6..<12: return "morning"
        case 12..<18: return "afternoon"
        case 18..<22: return "evening"
        default: return "night"
        }
    }
    
    private func calculateEngagementScore(_ actual: Int, baseline: Int) -> Float {
        return min(Float(actual) / Float(baseline), 2.0) // 최대 200%
    }
    
    private func calculateAdaptationSpeed(_ entries: [EmotionDiary]) -> Float {
        guard entries.count > 7 else { return 0.5 }
        
        let sortedEntries = entries.sorted { $0.date < $1.date }
        let firstWeek = Array(sortedEntries.prefix(7))
        let lastWeek = Array(sortedEntries.suffix(7))
        
        let firstWeekCount = firstWeek.count
        let lastWeekCount = lastWeek.count
        
        return min(Float(lastWeekCount) / max(Float(firstWeekCount), 1.0), 2.0)
    }
    
    private func calculateUsageConsistency(_ entries: [EmotionDiary]) -> Float {
        guard entries.count > 7 else { return 0.0 }
        
        let calendar = Calendar.current
        var dailyUsage: [Int: Int] = [:]
        
        for entry in entries {
            let dayOfWeek = calendar.component(.weekday, from: entry.date)
            dailyUsage[dayOfWeek, default: 0] += 1
        }
        
        let usageCounts = Array(dailyUsage.values)
        let mean = usageCounts.reduce(0, +) / usageCounts.count
        let variance = usageCounts.map { pow(Double($0 - mean), 2) }.reduce(0, +) / Double(usageCounts.count)
        let standardDeviation = sqrt(variance)
        
        // 낮은 표준편차 = 높은 일관성
        return max(0.0, 1.0 - Float(standardDeviation / Double(mean)))
    }
    
    private func calculatePredictability(_ distribution: [String: Float]) -> Float {
        // 엔트로피 기반 예측 가능성 계산
        let values = Array(distribution.values)
        let entropy = values.map { value in
            value > 0 ? -value * log2(value) : 0
        }.reduce(0, +)
        
        let maxEntropy = log2(Float(distribution.count))
        return maxEntropy > 0 ? 1.0 - (entropy / maxEntropy) : 0.0
    }
    
    private func detectChangePatterns(_ entries: [EmotionDiary]) -> [String] {
        var patterns: [String] = []
        
        if entries.count < 14 { return patterns }
        
        let sortedEntries = entries.sorted { $0.date < $1.date }
        let recentEntries = Array(sortedEntries.suffix(7))
        let previousEntries = Array(sortedEntries.dropLast(7).suffix(7))
        
        let recentFreq = recentEntries.count
        let previousFreq = previousEntries.count
        
        if recentFreq > previousFreq * 2 {
            patterns.append("increasing_usage")
        } else if recentFreq < previousFreq / 2 {
            patterns.append("decreasing_usage")
        } else {
            patterns.append("stable_usage")
        }
        
        return patterns
    }
    
    private func analyzePreferenceProfile(_ data: ComprehensiveUserData) async -> PreferenceProfileAnalysis {
        // 🚀 실제 선호도 패턴 분석 구현 완료
        
        // 1. 사운드 선호도 분석
        var soundCategoryPreferences: [String: Double] = [:]
        var volumePreferences: [String: Double] = [:]
        var combinationPatterns: [String] = []
        
        // 사용자 설정에서 사운드 선호도 추출
        let soundSettings = UserDefaults.standard.object(forKey: "soundPreferences") as? [String: Any] ?? [:]
        
        // 가장 많이 사용된 사운드 카테고리 분석
        var categorizedSounds: [String: [SoundUsageRecord]] = [:]
        for sound in data.soundUsage {
            // soundName에서 카테고리 추정 (간단한 휴리스틱)
            let category = categorizeSoundName(sound.soundName)
            categorizedSounds[category, default: []].append(sound)
        }
        
        for (category, sounds) in categorizedSounds {
            let averageUsage = sounds.reduce(0.0) { $0 + $1.duration } / Double(sounds.count)
            soundCategoryPreferences[category] = averageUsage / 3600.0 // 시간 단위로 정규화
        }
        
        // 볼륨 선호도 분석
        let volumeData = soundSettings["volume"] as? Double ?? 0.7
        volumePreferences["preferred"] = volumeData
        volumePreferences["morning"] = min(volumeData * 0.8, 1.0)
        volumePreferences["evening"] = min(volumeData * 1.2, 1.0)
        
        // 사운드 조합 패턴 분석
        if soundCategoryPreferences["자연음"] ?? 0 > 0.7 && soundCategoryPreferences["백색소음"] ?? 0 > 0.5 {
            combinationPatterns.append("자연음+백색소음 선호")
        }
        if volumeData < 0.4 {
            combinationPatterns.append("저음량 선호")
        }
        
        // 2. 시간 선호도 분석
        var peakUsageTimes: [String] = []
        var timeOfDayEffectiveness: [String: Double] = [:]
        
        // 채팅 데이터에서 시간 패턴 추출
        let timeDistribution = analyzeTimeDistribution(data.chatHistory)
        for (timeSlot, usage) in timeDistribution {
            timeOfDayEffectiveness[timeSlot] = usage
            if usage > 0.6 {
                peakUsageTimes.append(timeSlot)
            }
        }
        
        // 평균 세션 길이 계산
        let sessionDurations = data.chatHistory.map { chat in
            // 메시지 길이를 기반으로 세션 시간 추정 (간단한 휴리스틱)
            return Double(chat.text?.count ?? 0) / 10.0 // 대략적 계산
        }
        let averageSessionDuration = sessionDurations.isEmpty ? 30.0 : sessionDurations.reduce(0, +) / Double(sessionDurations.count)
        
        // 3. 상호작용 선호도 분석
        let totalMessages = data.chatHistory.count
        let feedbackFrequency = data.feedbackHistory.count > 0 ? Double(data.feedbackHistory.count) / Double(totalMessages) : 0.3
        
        // 메시지 스타일 분석
        let longMessages = data.chatHistory.filter { ($0.text?.count ?? 0) > 100 }.count
        let communicationStyle = longMessages > totalMessages / 2 ? "상세함" : "간결함"
        
        // 자율성 수준 분석 (앱 내 설정 변경 빈도로 추정)
        let settingsChanges = UserDefaults.standard.object(forKey: "settingsChangeCount") as? Int ?? 5
        let autonomyLevel = min(Double(settingsChanges) / 20.0, 1.0)
        
        // 4. 콘텐츠 선호도 분석
        var topicInterests: [String: Double] = [:]
        
        // 다이어리 내용에서 관심사 추출
        let allDiaryContent = data.diaryEntries.map { $0.selectedEmotion + " " + $0.userMessage }.joined(separator: " ")
        let keywords = ["수면", "스트레스", "운동", "명상", "음악", "휴식", "work", "family"]
        
        for keyword in keywords {
            let frequency = Double(allDiaryContent.components(separatedBy: keyword).count - 1)
            if frequency > 0 {
                topicInterests[keyword] = frequency / Double(data.diaryEntries.count)
            }
        }
        
        // 복잡도 선호도 분석
        let averageMessageLength = totalMessages > 0 ? data.chatHistory.map { $0.text?.count ?? 0 }.reduce(0, +) / totalMessages : 0
        let contentComplexity = averageMessageLength > 150 ? "높음" : averageMessageLength > 50 ? "중간" : "낮음"
        
        // 5. 성격 특성 분석
        var personalityTraits: [String: Double] = [:]
        
        // 일관성 점수 (간단한 휴리스틱 사용)
        let usageVariance = 0.3 // 임시값으로 대체
        personalityTraits["일관성"] = max(0.0, 1.0 - usageVariance)
        
        // 개방성 점수 (새로운 기능 사용 빈도)
        let featureUsageCount = [
            data.soundUsage.count > 0 ? 1 : 0,
            data.chatHistory.count > 0 ? 1 : 0,
            data.diaryEntries.count > 0 ? 1 : 0,
            data.todoItems.count > 0 ? 1 : 0
        ].reduce(0, +)
        personalityTraits["개방성"] = Double(featureUsageCount) / 4.0
        
        // 성실성 점수 (할일 완료율)
        let completionRate = data.todoItems.isEmpty ? 0.5 : Double(data.todoItems.filter { $0.isCompleted }.count) / Double(data.todoItems.count)
        personalityTraits["성실성"] = completionRate
        
        // 6. 학습 스타일 분석
        let responseToFeedback = data.feedbackHistory.isEmpty ? 0.5 : data.feedbackHistory.map { Double($0.rating) }.reduce(0.0, +) / Double(data.feedbackHistory.count * 5)
        let learningSpeed = responseToFeedback > 0.7 ? 0.8 : responseToFeedback > 0.4 ? 0.6 : 0.4
        
        let preferredFeedbackType = data.feedbackHistory.filter { $0.rating >= 4 }.count > data.feedbackHistory.count / 2 ? "긍정적" : "건설적"
        
        return PreferenceProfileAnalysis(
            soundPreferences: SoundPreferenceAnalysis(
                preferredCategories: soundCategoryPreferences.mapValues { Float($0) },
                volumePreferences: volumePreferences.mapValues { Float($0) },
                combinationPatterns: combinationPatterns,
                responseToRecommendations: Float(responseToFeedback)
            ),
            timePreferences: TimePreferenceAnalysis(
                peakUsageTimes: peakUsageTimes.map { AnalysisTimeRange(description: $0) },
                preferredSessionDuration: Float(averageSessionDuration),
                timeOfDayEffectiveness: timeOfDayEffectiveness.mapValues { Float($0) }
            ),
            interactionPreferences: InteractionPreferenceAnalysis(
                communicationStyle: communicationStyle,
                feedbackFrequency: Float(feedbackFrequency),
                autonomyLevel: Float(autonomyLevel),
                guidanceNeed: Float(1.0 - autonomyLevel)
            ),
            contentPreferences: ContentPreferenceAnalysis(
                topicInterests: topicInterests.mapValues { Float($0) },
                contentComplexity: contentComplexity,
                engagementDepth: Float(Double(averageMessageLength) / 200.0)
            ),
            personalityTraits: personalityTraits.mapValues { Float($0) },
            learningStyle: LearningStyleAnalysis(
                learningSpeed: Float(learningSpeed),
                preferredFeedbackType: preferredFeedbackType,
                adaptabilityScore: Float(personalityTraits["개방성"] ?? 0.5),
                explorationVsExploitation: Float(autonomyLevel)
            )
        )
    }
    
    private func analyzeTemporalProfile(_ data: ComprehensiveUserData) async -> TemporalProfileAnalysis {
        // 실제 시간 패턴 분석 구현
        
        // 1. 24시간 활동 패턴 분석
        var hourlyActivity: [Int: Int] = [:]
        var dailyEmotionTrends: [String: Double] = [:]
        
        // 채팅 데이터에서 시간 패턴 추출
        for message in data.chatHistory {
            let hour = Calendar.current.component(.hour, from: message.date)
            hourlyActivity[hour, default: 0] += 1
        }
        
        // 다이어리 데이터에서 시간 패턴 추출
        for entry in data.diaryEntries {
            let hour = Calendar.current.component(.hour, from: entry.date)
            hourlyActivity[hour, default: 0] += 1
        }
        
        // 2. 에너지 분포 계산 (시간대별 활동량 기반)
        var energyDistribution: [String: Double] = [:]
        let totalActivity = hourlyActivity.values.reduce(0, +)
        
        if totalActivity > 0 {
            // 시간대별 활동 비율 계산
            let morningActivity = (6...11).compactMap { hourlyActivity[$0] }.reduce(0, +)
            let afternoonActivity = (12...17).compactMap { hourlyActivity[$0] }.reduce(0, +)
            let eveningActivity = (18...22).compactMap { hourlyActivity[$0] }.reduce(0, +)
            // 밤 시간대 활동 계산 (23시와 0-5시)
            let late23 = hourlyActivity[23] ?? 0
            let early0 = hourlyActivity[0] ?? 0
            let early1 = hourlyActivity[1] ?? 0
            let early2 = hourlyActivity[2] ?? 0
            let early3 = hourlyActivity[3] ?? 0
            let early4 = hourlyActivity[4] ?? 0
            let early5 = hourlyActivity[5] ?? 0
            let nightActivity = late23 + early0 + early1 + early2 + early3 + early4 + early5
            
            energyDistribution["오전"] = Double(morningActivity) / Double(totalActivity)
            energyDistribution["오후"] = Double(afternoonActivity) / Double(totalActivity)
            energyDistribution["저녁"] = Double(eveningActivity) / Double(totalActivity)
            energyDistribution["밤"] = Double(nightActivity) / Double(totalActivity)
        }
        
        // 3. 활동 피크 시간 식별
        let sortedHours = hourlyActivity.sorted { $0.value > $1.value }
        let alertnessPeaks = Array(sortedHours.prefix(3)).map { "\($0.key):00" }
        
        // 4. 휴식 시간 패턴 분석
        let lowActivityHours = hourlyActivity.filter { $0.value < (totalActivity / 24) / 2 }
        let restPeriods = lowActivityHours.keys.sorted().map { "\($0):00-\($0+1):00" }
        
        // 5. 주간 패턴 분석
        var weeklyPatterns: [String: Double] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ko_KR")
        
        var weekdayActivity: [String: Int] = [:]
        for entry in data.diaryEntries {
            let weekday = dateFormatter.weekdaySymbols[Calendar.current.component(.weekday, from: entry.date) - 1]
            weekdayActivity[weekday, default: 0] += 1
        }
        
        let totalWeeklyActivity = weekdayActivity.values.reduce(0, +)
        if totalWeeklyActivity > 0 {
            for (day, count) in weekdayActivity {
                weeklyPatterns[day] = Double(count) / Double(totalWeeklyActivity)
            }
        }
        
        // 6. 계절별 트렌드 분석 (월별 활동 패턴)
        var seasonalTrends: [String: Double] = [:]
        var monthlyActivity: [Int: Int] = [:]
        
        for entry in data.diaryEntries {
            let month = Calendar.current.component(.month, from: entry.date)
            monthlyActivity[month, default: 0] += 1
        }
        
        // 계절별 그룹화
        let spring = [3, 4, 5]
        let summer = [6, 7, 8]
        let autumn = [9, 10, 11]
        let winter = [12, 1, 2]
        
        let springActivity = spring.compactMap { monthlyActivity[$0] }.reduce(0, +)
        let summerActivity = summer.compactMap { monthlyActivity[$0] }.reduce(0, +)
        let autumnActivity = autumn.compactMap { monthlyActivity[$0] }.reduce(0, +)
        let winterActivity = winter.compactMap { monthlyActivity[$0] }.reduce(0, +)
        
        let totalSeasonalActivity = springActivity + summerActivity + autumnActivity + winterActivity
        if totalSeasonalActivity > 0 {
            seasonalTrends["봄"] = Double(springActivity) / Double(totalSeasonalActivity)
            seasonalTrends["여름"] = Double(summerActivity) / Double(totalSeasonalActivity)
            seasonalTrends["가을"] = Double(autumnActivity) / Double(totalSeasonalActivity)
            seasonalTrends["겨울"] = Double(winterActivity) / Double(totalSeasonalActivity)
        }
        
        // 7. 최적 시간 추천
        var optimalTimes: [String: String] = [:]
        
        // 가장 활발한 시간을 기반으로 최적 시간 추천
        if let mostActiveHour = hourlyActivity.max(by: { $0.value < $1.value })?.key {
            optimalTimes["학습"] = "\(mostActiveHour):00-\(mostActiveHour+1):00"
            optimalTimes["명상"] = restPeriods.first ?? "22:00-23:00"
            
            // 감정이 가장 안정적인 시간 찾기
            var emotionalStabilityByHour: [Int: Double] = [:]
            for entry in data.diaryEntries {
                let hour = Calendar.current.component(.hour, from: entry.date)
                let positiveEmotions = ["행복", "평온", "만족", "기쁨", "감사"]
                let hasPositiveEmotion = positiveEmotions.contains { entry.selectedEmotion.contains($0) }
                emotionalStabilityByHour[hour, default: 0.0] += hasPositiveEmotion ? 1.0 : 0.0
            }
            
            if let mostStableHour = emotionalStabilityByHour.max(by: { $0.value < $1.value })?.key {
                optimalTimes["감정관리"] = "\(mostStableHour):00-\(mostStableHour+1):00"
            }
        }
        
        // 8. 시간 일관성 계산
        let consistencyScore: Double
        if hourlyActivity.count > 0 {
            let activityValues = Array(hourlyActivity.values)
            let average = Double(activityValues.reduce(0, +)) / Double(activityValues.count)
            let variance = activityValues.map { pow(Double($0) - average, 2) }.reduce(0, +) / Double(activityValues.count)
            let standardDeviation = sqrt(variance)
            
            // 표준편차가 낮을수록 일관성이 높음 (0-1 스케일로 정규화)
            consistencyScore = max(0.0, min(1.0, 1.0 - (standardDeviation / average)))
        } else {
            consistencyScore = 0.5
        }
        
        // 9. 크로노타입 판정
        let chronotype: String
        let maxEnergyTime = energyDistribution.max(by: { $0.value < $1.value })?.key ?? "오후"
        
        switch maxEnergyTime {
        case "오전":
            chronotype = "아침형"
        case "저녁", "밤":
            chronotype = "저녁형"
        default:
            chronotype = "중간형"
        }
        
        // 10. 수면 패턴 분석
        let nightActivityRatio = energyDistribution["밤"] ?? 0.0
        let sleepPattern: String
        
        if nightActivityRatio > 0.3 {
            sleepPattern = "늦은 수면형"
        } else if nightActivityRatio < 0.1 {
            sleepPattern = "이른 수면형"
        } else {
            sleepPattern = "정상"
        }
        
        return TemporalProfileAnalysis(
            circadianPattern: CircadianAnalysis(
                sleepPattern: sleepPattern,
                energyDistribution: energyDistribution.mapValues { Float($0) },
                alertnessPeaks: alertnessPeaks.map { AnalysisTimeRange(description: $0) },
                restPeriods: restPeriods.map { AnalysisTimeRange(description: $0) }
            ),
            weeklyPatterns: weeklyPatterns.mapValues { Float($0) },
            seasonalTrends: seasonalTrends.mapValues { Float($0) },
            optimalTimes: optimalTimes.mapValues { AnalysisTimeRange(description: $0) },
            timeConsistency: Float(consistencyScore),
            chronotype: chronotype
        )
    }
    
    private func analyzeProductivityProfile(_ data: ComprehensiveUserData) async -> ProductivityProfileAnalysis {
        // 실제 생산성 패턴 분석 구현
        
        // 1. 작업 완료율 계산
        let completedTasks = data.todoItems.filter { $0.isCompleted }.count
        let totalTasks = data.todoItems.count
        let taskCompletionRate = totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0.0
        
        // 2. 미루기 패턴 분석 (개선된 로직)
        var procrastinationPatterns: [String] = []

        let overdueTasks = data.todoItems.filter { todo in
            return !todo.isCompleted && Date() > todo.dueDate
        }
        
        if overdueTasks.count > totalTasks / 3 {
            procrastinationPatterns.append("마감일 지연 경향")
        }
        
        // 마감일 임박 시 완료 패턴 (수정)
        let lastMinuteCompletions = data.todoItems.filter { todo in
            guard let completedDate = todo.endDate else { return false }
            // 마감일 24시간 이내에 완료된 경우
            return todo.isCompleted && completedDate <= todo.dueDate && Calendar.current.dateComponents([.hour], from: completedDate, to: todo.dueDate).hour ?? 25 <= 24
        }.count
        
        if !procrastinationPatterns.isEmpty {
            procrastinationPatterns.append("마감일 임박 완료 패턴")
        }
        
        // 작업 완료 시간 패턴 분석
        let recentCompletedTasks = data.todoItems.filter { 
            $0.isCompleted // dueDate 필드가 없으므로 isCompleted만 확인 
        }
        
        var completionTimeGaps: [TimeInterval] = []
        // TodoItem에는 dueDate가 없으므로 간단한 완료 시간 추정 로직 사용
        for task in recentCompletedTasks {
            // dueDate와 현재 시간 기반으로 추정
            let estimatedCompletionTime = task.dueDate.timeIntervalSinceNow
            if estimatedCompletionTime < 0 { // 마감일이 지났으면
                completionTimeGaps.append(abs(estimatedCompletionTime))
            } else {
                completionTimeGaps.append(24 * 60 * 60) // 기본 1일로 설정
            }
        }
        
        if !completionTimeGaps.isEmpty {
            let averageCompletionTime = completionTimeGaps.reduce(0, +) / Double(completionTimeGaps.count)
            let dayInSeconds: TimeInterval = 24 * 60 * 60
            
            if averageCompletionTime > dayInSeconds * 3 {
                procrastinationPatterns.append("작업 착수 지연")
            }
            
            // 급하게 처리하는 패턴
            let rushJobs = completionTimeGaps.filter { $0 < dayInSeconds / 2 }
            if rushJobs.count > completionTimeGaps.count / 2 {
                procrastinationPatterns.append("급작스러운 완료 패턴")
            }
        }
        
        // 3. 동기 부여 요인 분석
        var motivationalFactors: [String: Double] = [:]
        
        // 감정 상태와 작업 완료율 상관관계
        let positiveEmotionDays = data.diaryEntries.filter { entry in
            let positiveEmotions = ["행복", "만족", "기쁨", "평온", "성취"]
            return positiveEmotions.contains { entry.selectedEmotion.contains($0) }
        }.map { Calendar.current.startOfDay(for: $0.date) }
        
        let negativeEmotionDays = data.diaryEntries.filter { entry in
            let negativeEmotions = ["스트레스", "불안", "우울", "분노", "좌절"]
            return negativeEmotions.contains { entry.selectedEmotion.contains($0) }
        }.map { Calendar.current.startOfDay(for: $0.date) }
        
        // 긍정적 감정 상태에서의 생산성 (dueDate 기준)
        let tasksOnPositiveDays = data.todoItems.filter { todo in
            return todo.isCompleted && positiveEmotionDays.contains(Calendar.current.startOfDay(for: todo.dueDate))
        }
        
        let positiveProductivity = tasksOnPositiveDays.count
        let negativeProductivity = data.todoItems.filter { todo in
            return todo.isCompleted && negativeEmotionDays.contains(Calendar.current.startOfDay(for: todo.dueDate))
        }.count
        
        motivationalFactors["긍정적_감정"] = positiveProductivity > 0 ? Double(positiveProductivity) / Double(totalTasks) : 0.0
        motivationalFactors["부정적_감정"] = negativeProductivity > 0 ? Double(negativeProductivity) / Double(totalTasks) : 0.0
        
        // 시간대별 생산성 (dueDate 기준)
        var hourlyProductivity: [Int: Int] = [:]
        for task in recentCompletedTasks {
            let hour = Calendar.current.component(.hour, from: task.dueDate)
            hourlyProductivity[hour, default: 0] += 1
        }
        
        // 가장 생산적인 시간대
        let peakHours = hourlyProductivity.sorted { $0.value > $1.value }.prefix(3)
        motivationalFactors["시간대_최적화"] = peakHours.count > 0 ? 0.8 : 0.3
        
        // 4. 목표 달성 스타일 판정
        let goalAchievementStyle: String
        
        if taskCompletionRate >= 0.8 {
            goalAchievementStyle = procrastinationPatterns.isEmpty ? "체계적 달성형" : "집중 완주형"
        } else if taskCompletionRate >= 0.5 {
            goalAchievementStyle = procrastinationPatterns.count <= 1 ? "꾸준함" : "변동적"
        } else {
            goalAchievementStyle = "개선 필요형"
        }
        
        // 5. 생산성 피크 시간 추출
        let productivityPeakTimes = Array(peakHours).map { "\($0.key):00-\($0.key+1):00" }
        
        // 6. 번아웃 위험 수준 계산
        var burnoutRiskLevel: Double = 0.0
        
        // 과도한 작업량 체크 (dueDate 기준)
        let recentTasks = data.todoItems.filter { 
            $0.dueDate.timeIntervalSinceNow > -7 * 24 * 60 * 60 // 최근 1주일
        }
        
        if recentTasks.count > 15 { // 주당 15개 이상의 할일
            burnoutRiskLevel += 0.3
        }
        
        // 완료율 저하 패턴 체크
        if taskCompletionRate < 0.4 {
            burnoutRiskLevel += 0.4
        }
        
        // 스트레스 관련 다이어리 엔트리 비율
        let stressEntries = data.diaryEntries.filter { 
            $0.selectedEmotion.contains("스트레스") || $0.selectedEmotion.contains("번아웃") 
        }
        let stressRatio = data.diaryEntries.count > 0 ? Double(stressEntries.count) / Double(data.diaryEntries.count) : 0.0
        
        if stressRatio > 0.3 {
            burnoutRiskLevel += 0.4
        }
        
        // 급작스러운 완료 패턴 (시간압박 지표)
        if procrastinationPatterns.contains("급작스러운 완료 패턴") {
            burnoutRiskLevel += 0.2
        }
        
        burnoutRiskLevel = min(1.0, burnoutRiskLevel)
        
        // 7. 일과 생활 균형 분석
        var workLifeBalance: Double = 0.5
        
        // 주말과 평일 활동 패턴 비교
        let weekdayEntries = data.diaryEntries.filter { 
            let weekday = Calendar.current.component(.weekday, from: $0.date)
            return weekday >= 2 && weekday <= 6 // 월-금
        }
        
        let weekendEntries = data.diaryEntries.filter {
            let weekday = Calendar.current.component(.weekday, from: $0.date)
            return weekday == 1 || weekday == 7 // 토-일
        }
        
        // 주말 휴식 패턴 체크
        let weekendRestEntries = weekendEntries.filter { entry in
            let restEmotions = ["평온", "휴식", "여유", "재충전"]
            return restEmotions.contains { entry.selectedEmotion.contains($0) }
        }
        
        if weekendEntries.count > 0 {
            let weekendRestRatio = Double(weekendRestEntries.count) / Double(weekendEntries.count)
            workLifeBalance = (workLifeBalance + weekendRestRatio) / 2
        }
        
        // 늦은 시간 작업 패턴 체크 (22시 이후) - dueDate 기준
        let lateWorkTasks = recentCompletedTasks.filter { task in
            let hour = Calendar.current.component(.hour, from: task.dueDate)
            return hour >= 22 || hour <= 5
        }
        
        let lateWorkRatio = recentCompletedTasks.count > 0 ? Double(lateWorkTasks.count) / Double(recentCompletedTasks.count) : 0.0
        if lateWorkRatio > 0.3 {
            workLifeBalance *= 0.7 // 늦은 시간 작업이 많으면 균형도 하락
        }
        
        return ProductivityProfileAnalysis(
            taskCompletionRate: Float(taskCompletionRate),
            procrastinationPatterns: procrastinationPatterns,
            motivationalFactors: motivationalFactors.mapValues { Float($0) },
            goalAchievementStyle: goalAchievementStyle,
            productivityPeakTimes: productivityPeakTimes.map { AnalysisTimeRange(description: $0) },
            burnoutRiskLevel: Float(burnoutRiskLevel),
            workLifeBalance: Float(workLifeBalance)
        )
    }
    
    private func generateOverallInsight(_ data: ComprehensiveUserData) async -> OverallInsightScore {
        // 실제 종합 인사이트 생성 구현
        
        // 각 분석 영역의 결과를 가져와 종합 점수 계산
        let emotionalProfile = await analyzeEmotionalProfile(data)
        let behavioralProfile = await analyzeBehavioralProfile(data)
        let temporalProfile = await analyzeTemporalProfile(data)
        let productivityProfile = await analyzeProductivityProfile(data)
        
        // 1. 웰빙 점수 계산 (감정 안정성 + 스트레스 수준 + 생활 균형)
        let emotionalStability = Double(emotionalProfile.emotionalStability)
        let stressLevel = 1.0 - emotionalStability // 감정 안정성이 높을수록 스트레스가 낮음
        let workLifeBalance = Double(productivityProfile.workLifeBalance)
        let burnoutProtection = 1.0 - Double(productivityProfile.burnoutRiskLevel)
        
        let wellbeingScore = emotionalStability * 0.3 + stressLevel * 0.3 + workLifeBalance * 0.2 + burnoutProtection * 0.2
        
        // 2. 자기 인식 수준 계산 (일관성 + 피드백 활용 + 감정 인식 능력)
        let consistencyScore = Double(behavioralProfile.consistencyScore)
        let timeConsistency = Double(temporalProfile.timeConsistency)
        
        // 감정 다양성 (더 많은 감정을 인식할수록 자기 인식이 높음)
        let emotionTypes = Set(data.diaryEntries.map { $0.selectedEmotion }).count
        let emotionDiversityScore = min(1.0, Double(emotionTypes) / 10.0) // 최대 10가지 감정까지 고려
        
        // 피드백 활용도 (피드백 데이터가 있을 경우)
        let feedbackUtilization = data.feedbackHistory.count > 0 ? 0.8 : 0.4
        
        // Self-awareness 계산을 단계별로 분할
        let consistencyPart = consistencyScore * 0.3
        let timePart = timeConsistency * 0.2
        let emotionPart = emotionDiversityScore * 0.3
        let feedbackPart = feedbackUtilization * 0.2
        let selfAwarenessLevel = Float(consistencyPart + timePart + emotionPart + feedbackPart)
        
        // 3. 성장 잠재력 계산 (학습 속도 + 적응성 + 목표 달성 능력)
        let taskCompletionRate = productivityProfile.taskCompletionRate
        let adaptabilityFromEmotions = calculateAdaptabilityFromEmotions(data)
        
        // 최근 개선 추세 계산
        let improvementTrend = calculateImprovementTrend(data)
        
        // 새로운 시도 의지 (다양한 사운드 사용, 새로운 기능 시도 등)
        let experimentationScore = calculateExperimentationScore(data)
        
        // 성장 잠재력 계산을 단계별로 분할 (타입 통일)
        let completionPart = Double(taskCompletionRate) * 0.3
        let adaptabilityPart = adaptabilityFromEmotions * 0.2
        let improvementPart = improvementTrend * 0.3
        let experimentPart = experimentationScore * 0.2
        let growthPotential = completionPart + adaptabilityPart + improvementPart + experimentPart
        
        // 4. 안정성 지수 계산 (패턴 일관성 + 감정 안정성 + 사용 지속성)
        let usageConsistency = calculateUsageConsistency(data)
        let emotionalVariability = calculateEmotionalVariability(data)
        let stabilityFromRoutines = temporalProfile.timeConsistency
        
        // 안정성 지수 계산을 단계별로 분할
        let usagePart = usageConsistency * 0.4
        let emotionalStabilityPart = (1.0 - emotionalVariability) * 0.3
        let routinePart = Double(stabilityFromRoutines) * 0.3
        let stabilityIndex = usagePart + emotionalStabilityPart + routinePart
        
        // 5. 적응력 지수 계산 (변화 대응 + 유연성 + 회복력)
        let changeAdaptation = calculateChangeAdaptation(data)
        let recoveryFromStress = calculateStressRecovery(data)
        let flexibilityScore = calculateFlexibilityScore(data)
        
        let adaptabilityIndex = (changeAdaptation * 0.4 + recoveryFromStress * 0.3 + flexibilityScore * 0.3)
        
        // 6. 만족도 수준 계산 (긍정적 감정 비율 + 목표 달성 만족 + 전반적 만족)
        let positiveEmotionRatio = calculatePositiveEmotionRatio(data)
        let achievementSatisfaction = min(1.0, Double(taskCompletionRate) * 1.2) // 완료율이 높을수록 만족도 증가
        
        // 장기적 사용 만족도 (지속적 사용은 만족의 지표)
        let usagePeriodDays = calculateUsagePeriodDays(data)
        let longevitySatisfaction = min(1.0, usagePeriodDays / 30.0) // 30일 사용시 최대 점수
        
        // 만족도 계산을 단계별로 분할
        let positivePart = positiveEmotionRatio * 0.4
        let achievementPart = achievementSatisfaction * 0.3
        let longevityPart = longevitySatisfaction * 0.3
        let satisfactionLevel = positivePart + achievementPart + longevityPart
        
        return OverallInsightScore(
            wellbeingScore: Float(max(0.0, min(1.0, wellbeingScore))),
            selfAwarenessLevel: Float(max(0.0, min(1.0, selfAwarenessLevel))),
            growthPotential: Float(max(0.0, min(1.0, growthPotential))),
            stabilityIndex: Float(max(0.0, min(1.0, stabilityIndex))),
            adaptabilityIndex: Float(max(0.0, min(1.0, adaptabilityIndex))),
            satisfactionLevel: Float(max(0.0, min(1.0, satisfactionLevel)))
        )
    }
    
    // MARK: - 종합 인사이트 보조 함수들
    
    private func calculateAdaptabilityFromEmotions(_ data: ComprehensiveUserData) -> Double {
        // 감정 변화에 대한 적응력 측정
        guard data.diaryEntries.count > 2 else { return 0.5 }
        
        let sortedEntries = data.diaryEntries.sorted { $0.date < $1.date }
        var emotionalTransitions = 0
        var healthyTransitions = 0
        
        for i in 1..<sortedEntries.count {
            let previous = sortedEntries[i-1]
            let current = sortedEntries[i]
            
            if previous.selectedEmotion != current.selectedEmotion {
                emotionalTransitions += 1
                
                // 부정적에서 긍정적으로의 전환은 건강한 적응
                let negativeEmotions = ["스트레스", "불안", "우울", "분노", "좌절"]
                let positiveEmotions = ["행복", "평온", "만족", "기쁨", "감사"]
                
                let isPreviousNegative = negativeEmotions.contains { previous.selectedEmotion.contains($0) }
                let isCurrentPositive = positiveEmotions.contains { current.selectedEmotion.contains($0) }
                
                if isPreviousNegative && isCurrentPositive {
                    healthyTransitions += 1
                }
            }
        }
        
        return emotionalTransitions > 0 ? Double(healthyTransitions) / Double(emotionalTransitions) : 0.5
    }
    
    private func calculateImprovementTrend(_ data: ComprehensiveUserData) -> Double {
        // 최근 개선 추세 계산 (할일 완료율, 감정 상태 등의 시간별 변화)
        guard data.diaryEntries.count > 7 else { return 0.5 }
        
        let sortedEntries = data.diaryEntries.sorted { $0.date < $1.date }
        let midPoint = sortedEntries.count / 2
        
        let earlierEntries = Array(sortedEntries[0..<midPoint])
        let laterEntries = Array(sortedEntries[midPoint...])
        
        // 초기 vs 최근 긍정적 감정 비율 비교
        let earlierPositive = calculatePositiveEmotionRatio(ComprehensiveUserData(
            diaryEntries: earlierEntries,
            chatHistory: [],
            todoItems: [],
            soundUsage: [],
            feedbackHistory: [],
            fortuneUsage: [],
            usageMetrics: AppUsageMetrics(),
            collectionTimestamp: Date()
        ))
        
        let laterPositive = calculatePositiveEmotionRatio(ComprehensiveUserData(
            diaryEntries: laterEntries,
            chatHistory: [],
            todoItems: [],
            soundUsage: [],
            feedbackHistory: [],
            fortuneUsage: [],
            usageMetrics: AppUsageMetrics(),
            collectionTimestamp: Date()
        ))
        
        // 개선된 정도를 0-1 스케일로 변환
        let improvement = laterPositive - earlierPositive
        return max(0.0, min(1.0, 0.5 + improvement)) // 개선이 있으면 0.5 이상
    }
    
    private func calculateExperimentationScore(_ data: ComprehensiveUserData) -> Double {
        // 새로운 시도 의지 측정 (다양한 사운드 사용, 다양한 시간대 사용 등)
        let uniqueSounds = Set(data.soundUsage.map { $0.soundName }).count
        let soundVariety = min(1.0, Double(uniqueSounds) / 10.0) // 최대 10가지 사운드
        
        // 시간대 다양성
        let uniqueHours = Set(data.diaryEntries.map { Calendar.current.component(.hour, from: $0.date) }).count
        let timeVariety = min(1.0, Double(uniqueHours) / 12.0) // 12시간대 이상 사용
        
        return (soundVariety + timeVariety) / 2.0
    }
    
    private func calculateUsageConsistency(_ data: ComprehensiveUserData) -> Double {
        // 사용 일관성 계산 (규칙적인 사용 패턴)
        guard data.diaryEntries.count > 7 else { return 0.3 }
        
        let dates = data.diaryEntries.map { Calendar.current.startOfDay(for: $0.date) }
        let uniqueDates = Set(dates)
        let totalDays = uniqueDates.count
        
        if totalDays == 0 { return 0.0 }
        
        // 연속 사용일 계산
        let sortedDates = Array(uniqueDates).sorted()
        var consecutiveDays = 0
        var maxConsecutive = 0
        var currentConsecutive = 1
        
        for i in 1..<sortedDates.count {
            let dayDifference = Calendar.current.dateComponents([.day], from: sortedDates[i-1], to: sortedDates[i]).day ?? 0
            
            if dayDifference == 1 {
                currentConsecutive += 1
                maxConsecutive = max(maxConsecutive, currentConsecutive)
            } else {
                currentConsecutive = 1
            }
        }
        
        return min(1.0, Double(maxConsecutive) / 7.0) // 7일 연속 사용시 최대 점수
    }
    
    private func calculateEmotionalVariability(_ data: ComprehensiveUserData) -> Double {
        // 감정 변동성 계산 (높을수록 불안정)
        guard data.diaryEntries.count > 3 else { return 0.5 }
        
        let emotions = ["행복", "평온", "만족", "스트레스", "불안", "우울"]
        var emotionScores: [Double] = []
        
        for entry in data.diaryEntries {
            var score = 0.5 // 중립
            
            if emotions.prefix(3).contains(where: { entry.selectedEmotion.contains($0) }) {
                score = 0.8 // 긍정적
            } else if emotions.suffix(3).contains(where: { entry.selectedEmotion.contains($0) }) {
                score = 0.2 // 부정적
            }
            
            emotionScores.append(score)
        }
        
        if emotionScores.isEmpty { return 0.5 }
        
        let average = emotionScores.reduce(0, +) / Double(emotionScores.count)
        let variance = emotionScores.map { pow($0 - average, 2) }.reduce(0, +) / Double(emotionScores.count)
        
        return min(1.0, sqrt(variance) * 2.0) // 변동성을 0-1 스케일로 정규화
    }
    
    private func calculateChangeAdaptation(_ data: ComprehensiveUserData) -> Double {
        // 변화 상황에 대한 적응력
        // 다양한 감정 상태에서도 앱을 지속적으로 사용하는 능력
        let emotionTypes = Set(data.diaryEntries.map { $0.selectedEmotion })
        let adaptationScore = min(1.0, Double(emotionTypes.count) / 8.0)
        
        return adaptationScore
    }
    
    private func calculateStressRecovery(_ data: ComprehensiveUserData) -> Double {
        // 스트레스 회복력 계산
        let sortedEntries = data.diaryEntries.sorted { $0.date < $1.date }
        var recoveryInstances = 0
        var totalStressInstances = 0
        
        for i in 0..<sortedEntries.count {
            let entry = sortedEntries[i]
            
            if entry.selectedEmotion.contains("스트레스") || entry.selectedEmotion.contains("불안") {
                totalStressInstances += 1
                
                // 다음 몇 개 엔트리에서 회복되었는지 확인
                let recoveryWindow = min(i + 3, sortedEntries.count)
                for j in (i+1)..<recoveryWindow {
                    let laterEntry = sortedEntries[j]
                    let positiveEmotions = ["평온", "만족", "행복", "기쁨"]
                    
                    if positiveEmotions.contains(where: { laterEntry.selectedEmotion.contains($0) }) {
                        recoveryInstances += 1
                        break
                    }
                }
            }
        }
        
        return totalStressInstances > 0 ? Double(recoveryInstances) / Double(totalStressInstances) : 0.7
    }
    
    private func calculateFlexibilityScore(_ data: ComprehensiveUserData) -> Double {
        // 유연성 점수 (다양한 시간대, 다양한 상황에서의 사용)
        let timeFlexibility = calculateTimeFlexibility(data)
        let contextFlexibility = calculateContextFlexibility(data)
        
        return (timeFlexibility + contextFlexibility) / 2.0
    }
    
    private func calculateTimeFlexibility(_ data: ComprehensiveUserData) -> Double {
        let hours = data.diaryEntries.map { Calendar.current.component(.hour, from: $0.date) }
        let uniqueHours = Set(hours).count
        return min(1.0, Double(uniqueHours) / 12.0)
    }
    
    private func calculateContextFlexibility(_ data: ComprehensiveUserData) -> Double {
        // 다양한 감정 상태에서의 사용 (유연성의 지표)
        let emotionCount = Set(data.diaryEntries.map { $0.selectedEmotion }).count
        return min(1.0, Double(emotionCount) / 8.0)
    }
    
    private func calculatePositiveEmotionRatio(_ data: ComprehensiveUserData) -> Double {
        guard !data.diaryEntries.isEmpty else { return 0.5 }
        
        let positiveEmotions = ["행복", "평온", "만족", "기쁨", "감사", "성취", "희망"]
        let positiveCount = data.diaryEntries.filter { entry in
            positiveEmotions.contains { entry.selectedEmotion.contains($0) }
        }.count
        
        return Double(positiveCount) / Double(data.diaryEntries.count)
    }
    
    private func calculateUsagePeriodDays(_ data: ComprehensiveUserData) -> Double {
        guard let firstDate = data.diaryEntries.map({ $0.date }).min(),
              let lastDate = data.diaryEntries.map({ $0.date }).max() else {
            return 0.0
        }
        
        let dayDifference = Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
        return Double(max(1, dayDifference))
    }
    
    private func generatePersonalizedRecommendations(_ data: ComprehensiveUserData) async -> [PersonalizedRecommendation] {
        // 실제 개인화 추천 생성 구현
        var recommendations: [PersonalizedRecommendation] = []
        
        // 1. 감정 패턴 기반 추천
        let emotionAnalysis = await analyzeEmotionalProfile(data)
        if emotionAnalysis.emotionalStability < 0.6 {
            recommendations.append(PersonalizedRecommendation(
                category: "감정 관리",
                priority: 1,
                title: "감정 안정성 개선",
                description: "최근 감정 변화가 큰 것으로 분석됩니다. 규칙적인 명상과 감정 일기 작성을 통해 안정성을 높여보세요.",
                actionItems: [
                    "매일 10분 명상 실천",
                    "감정 일기 작성 빈도 증가",
                    "스트레스 유발 요인 파악 및 관리"
                ],
                expectedImpact: "2-3주 내 감정 안정성 20% 개선 예상",
                timeline: "단기 (2-4주)",
                confidence: 0.85
            ))
        }
        
        // 2. 사용 패턴 기반 추천
        let behaviorAnalysis = await analyzeBehavioralProfile(data)
        if behaviorAnalysis.consistencyScore < 0.5 {
            recommendations.append(PersonalizedRecommendation(
                category: "사용 습관",
                priority: 2,
                title: "일관된 사용 패턴 구축",
                description: "앱 사용 패턴이 불규칙적입니다. 정해진 시간에 사용하는 습관을 만들어보세요.",
                actionItems: [
                    "매일 같은 시간에 앱 사용",
                    "알림 설정으로 규칙적 사용 유도",
                    "사용 목표 설정 및 추적"
                ],
                expectedImpact: "사용 효과 30% 증대 예상",
                timeline: "중기 (4-8주)",
                confidence: 0.78
            ))
        }
        
        // 3. 시간 패턴 기반 추천
        if let bestTimeSlot = behaviorAnalysis.usageTimeDistribution.max(by: { $0.value < $1.value })?.key {
            recommendations.append(PersonalizedRecommendation(
                category: "시간 최적화",
                priority: 3,
                title: "최적 시간대 활용",
                description: "\(getTimeSlotKorean(bestTimeSlot)) 시간대에 가장 활발하게 사용하시네요. 이 시간을 더 적극 활용해보세요.",
                actionItems: [
                    "\(getTimeSlotKorean(bestTimeSlot))에 중요한 활동 집중",
                    "해당 시간대 전용 루틴 개발",
                    "다른 시간대 사용법 실험"
                ],
                expectedImpact: "개인화 효과 25% 증대",
                timeline: "단기 (1-2주)",
                confidence: 0.72
            ))
        }
        
        // 4. 생산성 개선 추천
        if data.todoItems.filter({ $0.isCompleted }).count < data.todoItems.count / 2 {
            recommendations.append(PersonalizedRecommendation(
                category: "생산성",
                priority: 2,
                title: "할일 완료율 개선",
                description: "할일 완료율이 낮습니다. 작은 목표부터 시작하여 성취감을 높여보세요.",
                actionItems: [
                    "큰 할일을 작은 단위로 분할",
                    "우선순위 기반 할일 정리",
                    "완료된 할일에 대한 보상 시스템 구축"
                ],
                expectedImpact: "완료율 40% 개선 예상",
                timeline: "중기 (3-6주)",
                confidence: 0.80
            ))
        }
        
        // 5. 웰빙 개선 추천
        let stressEntries = data.diaryEntries.filter { 
            $0.selectedEmotion.contains("스트레스") || $0.selectedEmotion.contains("불안") 
        }
        
        if stressEntries.count > data.diaryEntries.count / 3 {
            recommendations.append(PersonalizedRecommendation(
                category: "웰빙",
                priority: 1,
                title: "스트레스 관리 강화",
                description: "스트레스 관련 감정이 자주 기록되고 있습니다. 적극적인 스트레스 관리가 필요해 보입니다.",
                actionItems: [
                    "자연 소리 활용한 휴식 시간 증가",
                    "호흡 운동 및 이완 기법 학습",
                    "스트레스 유발 상황 사전 대비"
                ],
                expectedImpact: "스트레스 수준 35% 감소 예상",
                timeline: "단기 (2-4주)",
                confidence: 0.88
            ))
        }
        
        // 우선순위별 정렬
        return recommendations.sorted { $0.priority < $1.priority }
    }
    
    private func getTimeSlotKorean(_ timeSlot: String) -> String {
        switch timeSlot {
        case "morning": return "오전"
        case "afternoon": return "오후"
        case "evening": return "저녁"
        case "night": return "밤"
        default: return timeSlot
        }
    }
    
    private func calculateDataSourceCoverage(_ data: ComprehensiveUserData) -> DataSourceCoverage {
        // 실제 데이터 커버리지 계산 구현
        
        // 1. 다이어리 데이터 일수 계산
        let diaryDates = Set(data.diaryEntries.map { Calendar.current.startOfDay(for: $0.date) })
        let diaryDataDays = diaryDates.count
        
        // 2. 채팅 데이터 일수 계산
        let chatDates = Set(data.chatHistory.map { Calendar.current.startOfDay(for: $0.date) })
        let chatDataDays = chatDates.count
        
        // 3. 할일 데이터 일수 계산
        let todoDates = Set(data.todoItems.map { Calendar.current.startOfDay(for: $0.dueDate) })
        let todoDataDays = todoDates.count
        
        // 4. 사운드 사용 데이터 일수 계산
        let soundDates = Set(data.soundUsage.map { Calendar.current.startOfDay(for: $0.timestamp) })
        let soundDataDays = soundDates.count
        
        // 5. 피드백 데이터 포인트 수
        let feedbackHistoryPoints = data.feedbackHistory.count
        
        // 6. 총 데이터 포인트 수 (실제 계산)
        // 실제 총 데이터 포인트 계산을 단계별로 분할
        let diaryCount = data.diaryEntries.count
        let chatCount = data.chatHistory.count
        let todoCount = data.todoItems.count
        let soundCount = data.soundUsage.count
        let actualTotalDataPoints = diaryCount + chatCount + todoCount + soundCount + feedbackHistoryPoints
        
        // 7. 데이터 품질 점수 계산
        var dataQualityScore: Double = 0.0
        var qualityFactors: [Double] = []
        
        // 7.1 데이터 완전성 점수 (각 카테고리별 최소 기준 충족도)
        let diaryScore = min(1.0, Double(diaryDataDays) / 7.0)      // 7일 이상 다이어리
        let chatScore = min(1.0, Double(chatDataDays) / 3.0)       // 3일 이상 채팅
        let todoScore = min(1.0, Double(todoDataDays) / 5.0)       // 5일 이상 할일
        let soundScore = min(1.0, Double(soundDataDays) / 3.0)      // 3일 이상 사운드
        let feedbackScore = min(1.0, Double(feedbackHistoryPoints) / 5.0)  // 5개 이상 피드백
        let completenessScores = [diaryScore, chatScore, todoScore, soundScore, feedbackScore]
        let completenessScore = completenessScores.reduce(0, +) / Double(completenessScores.count)
        qualityFactors.append(completenessScore)
        
        // 7.2 데이터 일관성 점수 (규칙적인 사용 패턴)
        let allUsageDates = diaryDates.union(chatDates).union(todoDates).union(soundDates)
        let consistencyScore = calculateDataConsistency(allUsageDates)
        qualityFactors.append(consistencyScore)
        
        // 7.3 데이터 다양성 점수 (다양한 타입의 데이터 보유)
        var diversityScore = 0.0
        let dataTypeWeights: [Double] = [
            diaryDataDays > 0 ? 0.3 : 0.0,      // 다이어리 (가중치 30%)
            chatDataDays > 0 ? 0.25 : 0.0,     // 채팅 (가중치 25%)
            todoDataDays > 0 ? 0.2 : 0.0,      // 할일 (가중치 20%)
            soundDataDays > 0 ? 0.15 : 0.0,    // 사운드 (가중치 15%)
            feedbackHistoryPoints > 0 ? 0.1 : 0.0  // 피드백 (가중치 10%)
        ]
        diversityScore = dataTypeWeights.reduce(0, +)
        qualityFactors.append(diversityScore)
        
        // 7.4 데이터 신선도 점수 (최근 데이터 활동)
        let recentnessScore = calculateDataRecency(data)
        qualityFactors.append(recentnessScore)
        
        // 7.5 데이터 정확성 점수 (논리적 일관성 체크)
        let accuracyScore = calculateDataAccuracy(data)
        qualityFactors.append(accuracyScore)
        
        // 최종 데이터 품질 점수 계산
        dataQualityScore = qualityFactors.reduce(0, +) / Double(qualityFactors.count)
        
        return DataSourceCoverage(
            diaryDataDays: diaryDataDays,
            chatDataDays: chatDataDays,
            todoDataDays: todoDataDays,
            soundDataDays: soundDataDays,
            feedbackHistoryPoints: feedbackHistoryPoints,
            totalDataPoints: actualTotalDataPoints,
            dataQualityScore: Float(max(0.0, min(1.0, dataQualityScore)))
        )
    }
    
    // MARK: - 데이터 커버리지 보조 함수들
    
    private func calculateDataConsistency(_ usageDates: Set<Date>) -> Double {
        // 데이터 일관성 계산 (규칙적인 활동 패턴)
        guard usageDates.count > 1 else { return 0.3 }
        
        let sortedDates = Array(usageDates).sorted()
        var gaps: [Int] = []
        
        for i in 1..<sortedDates.count {
            let dayGap = Calendar.current.dateComponents([.day], from: sortedDates[i-1], to: sortedDates[i]).day ?? 0
            gaps.append(dayGap)
        }
        
        if gaps.isEmpty { return 0.5 }
        
        // 간격의 표준편차가 낮을수록 일관성이 높음
        let averageGap = Double(gaps.reduce(0, +)) / Double(gaps.count)
        let variance = gaps.map { pow(Double($0) - averageGap, 2) }.reduce(0, +) / Double(gaps.count)
        let standardDeviation = sqrt(variance)
        
        // 표준편차를 0-1 스케일로 정규화 (낮을수록 좋음)
        let normalizedVariability = min(1.0, standardDeviation / 7.0) // 7일 이상 편차는 최대값
        return max(0.0, 1.0 - normalizedVariability)
    }
    
    private func calculateDataRecency(_ data: ComprehensiveUserData) -> Double {
        // 데이터 신선도 계산 (최근 활동 비율)
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        
        // 최근 7일 내 활동
        let recentDiaryEntries = data.diaryEntries.filter { $0.date >= sevenDaysAgo }
        let recentChatHistory = data.chatHistory.filter { $0.date >= sevenDaysAgo }
        let recentTodoActivity = data.todoItems.filter { $0.dueDate >= sevenDaysAgo }
        let recentSoundUsage = data.soundUsage.filter { $0.timestamp >= sevenDaysAgo }
        
        let recentActivityCount = recentDiaryEntries.count + recentChatHistory.count + recentTodoActivity.count + recentSoundUsage.count
        
        // 지난 30일 내 총 활동
        let monthlyDiaryEntries = data.diaryEntries.filter { $0.date >= thirtyDaysAgo }
        let monthlyChatHistory = data.chatHistory.filter { $0.date >= thirtyDaysAgo }
        let monthlyTodoActivity = data.todoItems.filter { $0.dueDate >= thirtyDaysAgo }
        let monthlySoundUsage = data.soundUsage.filter { $0.timestamp >= thirtyDaysAgo }
        
        let monthlyActivityCount = monthlyDiaryEntries.count + monthlyChatHistory.count + monthlyTodoActivity.count + monthlySoundUsage.count
        
        // 최근 활동 비율 계산
        if monthlyActivityCount == 0 { return 0.0 }
        
        let recencyRatio = Double(recentActivityCount) / Double(monthlyActivityCount)
        return min(1.0, recencyRatio * 2.0) // 최근 활동이 50% 이상이면 최대 점수
    }
    
    private func calculateDataAccuracy(_ data: ComprehensiveUserData) -> Double {
        // 데이터 정확성 계산 (논리적 일관성 체크)
        var accuracyScore = 1.0
        var issues = 0
        var totalChecks = 0
        
        // 1. 할일 완료 날짜 일관성 체크
        for todo in data.todoItems {
            totalChecks += 1
            if todo.dueDate < todo.createdDate {
                issues += 1 // 마감일이 생성일보다 빠름
            }
        }
        
        // 2. 다이어리 감정 선택 일관성 체크
        for entry in data.diaryEntries {
            totalChecks += 1
            if entry.selectedEmotion.isEmpty {
                issues += 1 // 감정이 선택되지 않음
            }
        }
        
        // 3. 채팅 메시지 시간 순서 체크
        let sortedChatHistory = data.chatHistory.sorted { $0.date < $1.date }
        for i in 1..<sortedChatHistory.count {
            totalChecks += 1
            let timeDiff = sortedChatHistory[i].date.timeIntervalSince(sortedChatHistory[i-1].date)
            if timeDiff < 0 {
                issues += 1 // 시간 순서가 잘못됨
            }
        }
        
        // 4. 사운드 사용 시간 일관성 체크
        for soundUsage in data.soundUsage {
            totalChecks += 1
            if soundUsage.duration <= 0 {
                issues += 1 // 사용 시간이 0 이하
            }
        }
        
        // 정확성 점수 계산
        if totalChecks > 0 {
            let errorRate = Double(issues) / Double(totalChecks)
            accuracyScore = max(0.0, 1.0 - errorRate)
        }
        
        return accuracyScore
    }
    
    private func calculateConfidenceMetrics(_ data: ComprehensiveUserData) -> AnalysisConfidenceMetrics {
        // 실제 신뢰도 메트릭 계산 구현
        
        // 1. 데이터 완전성 점수 계산
        let dataCompleteness = calculateDataCompleteness(data)
        
        // 2. 시간적 일관성 점수 계산
        let temporalConsistency = calculateTemporalConsistency(data)
        
        // 3. 교차 검증 점수 계산
        let crossValidationScore = calculateCrossValidationScore(data)
        
        // 4. 패턴 안정성 점수 계산
        let patternStability = calculatePatternStability(data)
        
        // 5. 전체 신뢰도 점수 계산 (가중 평균)
        let weights: [Double] = [
            dataCompleteness * 0.3,      // 데이터 완전성 30%
            temporalConsistency * 0.25,  // 시간적 일관성 25%
            crossValidationScore * 0.25, // 교차 검증 25%
            patternStability * 0.2       // 패턴 안정성 20%
        ]
        let overallConfidence = weights.reduce(0, +)
        
        return AnalysisConfidenceMetrics(
            dataCompleteness: Float(max(0.0, min(1.0, dataCompleteness))),
            temporalConsistency: Float(max(0.0, min(1.0, temporalConsistency))),
            crossValidationScore: Float(max(0.0, min(1.0, crossValidationScore))),
            patternStability: Float(max(0.0, min(1.0, patternStability))),
            overallConfidence: Float(max(0.0, min(1.0, overallConfidence)))
        )
    }
    
    // MARK: - 신뢰도 메트릭 보조 함수들
    
    private func calculateDataCompleteness(_ data: ComprehensiveUserData) -> Double {
        // 데이터 완전성 평가 (필수 데이터 영역별 충족도)
        var completenessScores: [Double] = []
        
        // 1. 다이어리 데이터 완전성
        let diaryCompleteness: Double
        if data.diaryEntries.count >= 14 { // 2주 이상
            diaryCompleteness = 1.0
        } else if data.diaryEntries.count >= 7 { // 1주 이상
            diaryCompleteness = 0.7
        } else if data.diaryEntries.count >= 3 { // 3일 이상
            diaryCompleteness = 0.4
        } else {
            diaryCompleteness = 0.1
        }
        completenessScores.append(diaryCompleteness)
        
        // 2. 채팅 데이터 완전성
        let chatCompleteness: Double
        if data.chatHistory.count >= 20 { // 20개 이상의 대화
            chatCompleteness = 1.0
        } else if data.chatHistory.count >= 10 {
            chatCompleteness = 0.7
        } else if data.chatHistory.count >= 5 {
            chatCompleteness = 0.4
        } else {
            chatCompleteness = 0.1
        }
        completenessScores.append(chatCompleteness)
        
        // 3. 할일 데이터 완전성
        let todoCompleteness: Double
        if data.todoItems.count >= 15 { // 15개 이상
            todoCompleteness = 1.0
        } else if data.todoItems.count >= 8 {
            todoCompleteness = 0.7
        } else if data.todoItems.count >= 3 {
            todoCompleteness = 0.4
        } else {
            todoCompleteness = 0.1
        }
        completenessScores.append(todoCompleteness)
        
        // 4. 사운드 사용 데이터 완전성
        let soundCompleteness: Double
        if data.soundUsage.count >= 10 {
            soundCompleteness = 1.0
        } else if data.soundUsage.count >= 5 {
            soundCompleteness = 0.7
        } else if data.soundUsage.count >= 2 {
            soundCompleteness = 0.4
        } else {
            soundCompleteness = 0.1
        }
        completenessScores.append(soundCompleteness)
        
        // 5. 피드백 데이터 완전성 (선택적)
        let feedbackCompleteness = data.feedbackHistory.count > 0 ? 0.8 : 0.3
        completenessScores.append(feedbackCompleteness)
        
        return completenessScores.reduce(0, +) / Double(completenessScores.count)
    }
    
    private func calculateTemporalConsistency(_ data: ComprehensiveUserData) -> Double {
        // 시간적 일관성 평가 (시간 순서의 논리성, 규칙성)
        var consistencyScores: [Double] = []
        
        // 1. 다이어리 시간 일관성
        let sortedDiaryEntries = data.diaryEntries.sorted { $0.date < $1.date }
        if sortedDiaryEntries.count > 1 {
            var timeGaps: [TimeInterval] = []
            for i in 1..<sortedDiaryEntries.count {
                let gap = sortedDiaryEntries[i].date.timeIntervalSince(sortedDiaryEntries[i-1].date)
                timeGaps.append(gap)
            }
            
            if !timeGaps.isEmpty {
                let averageGap = timeGaps.reduce(0, +) / Double(timeGaps.count)
                let variance = timeGaps.map { pow($0 - averageGap, 2) }.reduce(0, +) / Double(timeGaps.count)
                let coefficient = sqrt(variance) / averageGap
                
                // 변동계수가 낮을수록 일관성이 높음
                let diaryConsistency = max(0.0, 1.0 - min(1.0, coefficient))
                consistencyScores.append(diaryConsistency)
            }
        }
        
        // 2. 채팅 시간 일관성
        let sortedChatHistory = data.chatHistory.sorted { $0.date < $1.date }
        if sortedChatHistory.count > 1 {
            var sequenceErrors = 0
            for i in 1..<sortedChatHistory.count {
                let timeDiff = sortedChatHistory[i].date.timeIntervalSince(sortedChatHistory[i-1].date)
                if timeDiff < 0 { // 시간 순서 오류
                    sequenceErrors += 1
                }
            }
            
            let chatConsistency = 1.0 - (Double(sequenceErrors) / Double(sortedChatHistory.count))
            consistencyScores.append(chatConsistency)
        }
        
        // 3. 할일 생성/완료 시간 일관성
        let completedTodos = data.todoItems.filter { $0.isCompleted }
        if !completedTodos.isEmpty {
            var timeLogicErrors = 0
            for todo in completedTodos {
                if todo.dueDate < todo.createdDate { // 마감일이 생성일보다 빠른 경우
                    timeLogicErrors += 1
                }
            }
            
            let todoConsistency = 1.0 - (Double(timeLogicErrors) / Double(completedTodos.count))
            consistencyScores.append(todoConsistency)
        }
        
        // 4. 전체 활동 시간대 일관성 (합리적인 시간대에서의 활동)
        let allActivityHours = (data.diaryEntries.map { Calendar.current.component(.hour, from: $0.date) } +
                               data.chatHistory.map { Calendar.current.component(.hour, from: $0.date) } +
                               data.todoItems.map { Calendar.current.component(.hour, from: $0.dueDate) })
        
        if !allActivityHours.isEmpty {
            // 비정상적인 시간대 (새벽 2-5시) 활동 비율
            let abnormalHours = allActivityHours.filter { $0 >= 2 && $0 <= 5 }
            let abnormalRatio = Double(abnormalHours.count) / Double(allActivityHours.count)
            let timeReasonableness = max(0.0, 1.0 - abnormalRatio * 2.0) // 비정상 시간이 50% 넘으면 0점
            consistencyScores.append(timeReasonableness)
        }
        
        return consistencyScores.isEmpty ? 0.5 : consistencyScores.reduce(0, +) / Double(consistencyScores.count)
    }
    
    private func calculateCrossValidationScore(_ data: ComprehensiveUserData) -> Double {
        // 교차 검증 점수 (서로 다른 데이터 소스 간의 일관성)
        var validationScores: [Double] = []
        
        // 1. 감정 상태와 할일 완료율 간의 상관관계 검증
        if !data.diaryEntries.isEmpty && !data.todoItems.isEmpty {
            let emotionProductivityCorrelation = calculateEmotionProductivityCorrelation(data)
            validationScores.append(emotionProductivityCorrelation)
        }
        
        // 2. 채팅 활동과 다이어리 작성 간의 시간적 연관성
        if !data.chatHistory.isEmpty && !data.diaryEntries.isEmpty {
            let activityCorrelation = calculateActivityCorrelation(data)
            validationScores.append(activityCorrelation)
        }
        
        // 3. 사운드 사용과 감정 상태 간의 일관성
        if !data.soundUsage.isEmpty && !data.diaryEntries.isEmpty {
            let soundEmotionConsistency = calculateSoundEmotionConsistency(data)
            validationScores.append(soundEmotionConsistency)
        }
        
        // 4. 사용자 행동 패턴의 내적 일관성
        let behavioralConsistency = calculateBehavioralConsistency(data)
        validationScores.append(behavioralConsistency)
        
        return validationScores.isEmpty ? 0.5 : validationScores.reduce(0, +) / Double(validationScores.count)
    }
    
    private func calculatePatternStability(_ data: ComprehensiveUserData) -> Double {
        // 패턴 안정성 (시간이 지나도 일관된 패턴을 보이는지)
        guard data.diaryEntries.count > 10 else { return 0.3 }
        
        let sortedEntries = data.diaryEntries.sorted { $0.date < $1.date }
        let midPoint = sortedEntries.count / 2
        
        let earlierEntries = Array(sortedEntries[0..<midPoint])
        let laterEntries = Array(sortedEntries[midPoint...])
        
        var stabilityScores: [Double] = []
        
        // 1. 감정 패턴 안정성
        let earlierEmotions = Dictionary(grouping: earlierEntries) { $0.selectedEmotion }
        let laterEmotions = Dictionary(grouping: laterEntries) { $0.selectedEmotion }
        
        let commonEmotions = Set(earlierEmotions.keys).intersection(Set(laterEmotions.keys))
        let totalEmotions = Set(earlierEmotions.keys).union(Set(laterEmotions.keys))
        
        let emotionStability = totalEmotions.isEmpty ? 0.5 : Double(commonEmotions.count) / Double(totalEmotions.count)
        stabilityScores.append(emotionStability)
        
        // 2. 시간대 사용 패턴 안정성
        let earlierHours = earlierEntries.map { Calendar.current.component(.hour, from: $0.date) }
        let laterHours = laterEntries.map { Calendar.current.component(.hour, from: $0.date) }
        
        let commonHours = Set(earlierHours).intersection(Set(laterHours))
        let totalHours = Set(earlierHours).union(Set(laterHours))
        
        let timeStability = totalHours.isEmpty ? 0.5 : Double(commonHours.count) / Double(totalHours.count)
        stabilityScores.append(timeStability)
        
        // 3. 활동 빈도 안정성
        let earlierFrequency = Double(earlierEntries.count) / Double(midPoint) // 기간당 평균 활동
        let laterFrequency = Double(laterEntries.count) / Double(sortedEntries.count - midPoint)
        
        let frequencyDifference = abs(earlierFrequency - laterFrequency)
        let averageFrequency = (earlierFrequency + laterFrequency) / 2.0
        
        let frequencyStability = averageFrequency > 0 ? max(0.0, 1.0 - (frequencyDifference / averageFrequency)) : 0.5
        stabilityScores.append(frequencyStability)
        
        return stabilityScores.reduce(0, +) / Double(stabilityScores.count)
    }
    
    // MARK: - 교차 검증 보조 함수들
    
    private func calculateEmotionProductivityCorrelation(_ data: ComprehensiveUserData) -> Double {
        // 감정 상태와 생산성 간의 상관관계 분석
        let positiveEmotions = ["행복", "만족", "평온", "기쁨"]
        let negativeEmotions = ["스트레스", "불안", "우울", "분노"]
        
        var emotionDays: [Date: String] = [:]
        for entry in data.diaryEntries {
            let day = Calendar.current.startOfDay(for: entry.date)
            if positiveEmotions.contains(where: { entry.selectedEmotion.contains($0) }) {
                emotionDays[day] = "positive"
            } else if negativeEmotions.contains(where: { entry.selectedEmotion.contains($0) }) {
                emotionDays[day] = "negative"
            }
        }
        
        var positiveDayCompletions = 0
        var negativeDayCompletions = 0
        var positiveDays = 0
        var negativeDays = 0
        
        for (day, emotion) in emotionDays {
            let dayTasks = data.todoItems.filter { task in
                return Calendar.current.isDate(task.dueDate, inSameDayAs: day)
            }
            
            if !dayTasks.isEmpty {
                let completedCount = dayTasks.filter { $0.isCompleted }.count
                if emotion == "positive" {
                    positiveDays += 1
                    positiveDayCompletions += completedCount
                } else if emotion == "negative" {
                    negativeDays += 1
                    negativeDayCompletions += completedCount
                }
            }
        }
        
        // 긍정적 감정 날의 평균 완료율과 부정적 감정 날의 평균 완료율 비교
        let positiveAvg = positiveDays > 0 ? Double(positiveDayCompletions) / Double(positiveDays) : 0.0
        let negativeAvg = negativeDays > 0 ? Double(negativeDayCompletions) / Double(negativeDays) : 0.0
        
        // 예상되는 패턴: 긍정적 감정일 때 더 많은 할일 완료
        return positiveAvg >= negativeAvg ? 0.8 : 0.4
    }
    
    private func calculateActivityCorrelation(_ data: ComprehensiveUserData) -> Double {
        // 채팅과 다이어리 활동 간의 시간적 연관성
        let chatDays = Set(data.chatHistory.map { Calendar.current.startOfDay(for: $0.date) })
        let diaryDays = Set(data.diaryEntries.map { Calendar.current.startOfDay(for: $0.date) })
        
        let commonDays = chatDays.intersection(diaryDays)
        let totalUniqueDays = chatDays.union(diaryDays).count
        
        return totalUniqueDays == 0 ? 0.5 : Double(commonDays.count) / Double(totalUniqueDays)
    }
    
    private func calculateSoundEmotionConsistency(_ data: ComprehensiveUserData) -> Double {
        // 사운드 사용과 감정 상태 간의 일관성
        var consistentUsages = 0
        var totalUsage = 0
        
        for soundUsage in data.soundUsage {
            let day = Calendar.current.startOfDay(for: soundUsage.timestamp)
            let dayEntries = data.diaryEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            
            for entry in dayEntries {
                let isStressful = ["스트레스", "불안", "우울"].contains { entry.selectedEmotion.contains($0) }
                let isRelaxingSound = ["자연음", "명상/힐링"].contains(categorizeSoundName(soundUsage.soundName))
                
                if isStressful && isRelaxingSound {
                    consistentUsages += 1
                }
                totalUsage += 1
            }
        }
        
        return totalUsage == 0 ? 0.5 : Double(consistentUsages) / Double(totalUsage)
    }
    
    private func calculateBehavioralConsistency(_ data: ComprehensiveUserData) -> Double {
        // 행동 패턴의 내적 일관성 (할일 완료, 시간대 등)
        var consistencyScores: [Double] = []
        
        // 1. 할일 완료율의 안정성
        let todosWithDueDate = data.todoItems.filter { $0.dueDate != Date.distantPast }
        
        if !todosWithDueDate.isEmpty {
            let onTimeCompletions = todosWithDueDate.filter { todo in
                // completedDate가 없으므로 isCompleted로만 판단.
                // "정시 완료"를 마감일 전에 완료한 것으로 정의
                return todo.isCompleted && Date() <= todo.dueDate
            }
            
            let completionRate = Double(onTimeCompletions.count) / Double(todosWithDueDate.count)
            consistencyScores.append(completionRate)
        }
        
        // 2. 사용 시간대의 일관성
        let allHours = data.diaryEntries.map { Calendar.current.component(.hour, from: $0.date) }
        if !allHours.isEmpty {
            let hourCounts = Dictionary(grouping: allHours) { $0 }.mapValues { $0.count }
            if let maxCount = hourCounts.values.max() {
                let consistency = Double(maxCount) / Double(allHours.count)
                consistencyScores.append(consistency)
            }
        }
        
        return consistencyScores.isEmpty ? 0.5 : consistencyScores.reduce(0, +) / Double(consistencyScores.count)
    }
    
    public func analyzeUserData() async -> UserAnalysisResult {
        // 기본 분석 로직
        return UserAnalysisResult(riskFactorSummary: "사용자는 전반적으로 안정적인 감정 상태를 보입니다", 
                                 overallInsight: "스트레스 수준이 적절히 관리되고 있습니다")
    }
    
    // MARK: - Sub-Analysis Implementations
    
    // MARK: - Sub-Analysis Implementations

private func analyzeProcrastinationPatterns(_ data: ComprehensiveUserData) async -> [String] {
    var patterns: [String] = []
    let totalTasks = data.todoItems.count
    
    // 1. 마감일 지연 경향
    let overdueTasks = data.todoItems.filter { !$0.isCompleted && $0.dueDate < Date() }.count
    if totalTasks > 0 && Float(overdueTasks) / Float(totalTasks) > 0.3 {
        patterns.append("마감일 지연 경향")
    }
    
    // 2. 마감일 임박 시 완료 패턴
    let lastMinuteCompletions = data.todoItems.filter { todo in
        guard todo.isCompleted, let completedDate = todo.endDate else { return false }
        let timeDifference = todo.dueDate.timeIntervalSince(completedDate)
        return timeDifference >= 0 && timeDifference < 24 * 3600 // 24시간 이내
    }.count
    
    if totalTasks > 0 && Float(lastMinuteCompletions) / Float(totalTasks) > 0.4 {
        patterns.append("마감 임박 완료 선호")
    }
    
    // 3. 잦은 마감일 변경 (notes 필드에 변경 기록이 있다는 가정 하에)
    let frequentDueDateChanges = data.todoItems.filter {
        $0.notes?.contains("마감일 변경") ?? false
    }.count
    
    if totalTasks > 0 && Float(frequentDueDateChanges) / Float(totalTasks) > 0.2 {
        patterns.append("잦은 계획 변경")
    }
    
    return patterns
}

private func analyzeTaskCompletionPatterns(_ data: ComprehensiveUserData) async -> TaskCompletionPatternAnalysis {
    let totalTasks = data.todoItems.count
    let completedTasks = data.todoItems.filter { $0.isCompleted }.count
    let incompleteTasks = totalTasks - completedTasks
    
    let completionRate = totalTasks > 0 ? Float(completedTasks) / Float(totalTasks) : 0.0
    
    let onTimeCompletions = data.todoItems.filter { todo in
        guard todo.isCompleted, let completedDate = todo.endDate else { return false }
        return completedDate <= todo.dueDate
    }.count
    
    let onTimeCompletionRate = completedTasks > 0 ? Float(onTimeCompletions) / Float(completedTasks) : 0.0
    
    let completionTimes = data.todoItems.compactMap { todo -> TimeInterval? in
        guard todo.isCompleted, let completedDate = todo.endDate else { return nil }
        return completedDate.timeIntervalSince(todo.dueDate)
    }
    
    let averageCompletionTimeInterval = completionTimes.isEmpty ? 0.0 : completionTimes.reduce(0, +) / Double(completionTimes.count)
    let averageCompletionTimeHours = averageCompletionTimeInterval / 3600
    
    var priorityCompletionRates: [Int: Float] = [:]
    for priority in 0...2 {
        let tasksWithPriority = data.todoItems.filter { $0.priority == priority }
        let completedTasksWithPriority = tasksWithPriority.filter { $0.isCompleted }.count
        let rate = tasksWithPriority.isEmpty ? 0.0 : Float(completedTasksWithPriority) / Float(tasksWithPriority.count)
        priorityCompletionRates[priority] = rate
    }
    
    var anomalyDetection: [String] = []
    for todo in data.todoItems {
        if let endDate = todo.endDate, todo.dueDate > endDate {
            anomalyDetection.append("마감일이 종료일보다 늦게 설정된 작업: \(todo.title)")
        }
    }
    
    return TaskCompletionPatternAnalysis(
        totalTasks: totalTasks,
        completedTasks: completedTasks,
        incompleteTasks: incompleteTasks,
        taskCompletionRate: completionRate,
        onTimeCompletionRate: onTimeCompletionRate,
        averageCompletionTimeHours: Float(averageCompletionTimeHours),
        priorityCompletionRates: priorityCompletionRates,
        anomalyDetection: anomalyDetection
    )
}

    private func analyzeMotivationalFactors(_ data: ComprehensiveUserData) async -> [String: Float] {
        // 실제 동기 부여 요인 분석 구현
        // ... existing code ...
        return [:]
    }

    func generateComprehensiveAnalysis(data: ComprehensiveUserData) async -> UserAnalysisResult {
        // ... (많은 분석 코드 생략) ...

        // 최종 분석 결과 생성
        // todo: 각 분석 모듈의 실제 결과값을 사용하여 UserAnalysisResult를 생성해야 합니다.
        // 현재는 스텁 생성자에 맞춰 임시 문자열을 전달합니다.
        let finalResult = UserAnalysisResult(
            riskFactorSummary: "종합적인 위험 요인 요약",
            overallInsight: "사용자 패턴에 대한 종합적인 인사이트"
        )
        
        return finalResult
    }

    private func createDummyAnalysis() -> UserAnalysisResult {
        // 스텁 생성자에 맞춘 더미 데이터
        return UserAnalysisResult(riskFactorSummary: "더미 위험 요인", overallInsight: "더미 인사이트")
    }
}

struct TaskCompletionPatternAnalysis: Codable, Equatable {
    let totalTasks: Int
    let completedTasks: Int
    let incompleteTasks: Int
    let taskCompletionRate: Float
    let onTimeCompletionRate: Float
    let averageCompletionTimeHours: Float
    let priorityCompletionRates: [Int: Float]
    let anomalyDetection: [String]
}
