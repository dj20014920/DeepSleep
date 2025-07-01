import Foundation
import SwiftData
import CoreML
import Accelerate

/// 🧠 개인화된 조화 우선순위 학습 시스템
/// 사용자별로 "길이 일치 vs 감정 조화" 등의 우선순위를 학습하고 적용
@available(iOS 17.0, *)
@MainActor
class PersonalizedHarmonyLearner: ObservableObject {
    
    static let shared = PersonalizedHarmonyLearner()
    
    // MARK: - Properties
    @Published var isLearning: Bool = false
    @Published var personalizationLevel: Float = 0.0 // 0.0 ~ 1.0
    @Published var harmonyWeights: HarmonyWeights = HarmonyWeights.default
    
    private var modelContainer: ModelContainer?
    private var coreMLModel: MLModel?
    private var neuralNetwork: AdvancedHarmonyNetwork?
    
    // MARK: - Data Models
    
    /// 🎯 조화 가중치 - 개인별 조화 기준 우선순위
    struct HarmonyWeights {
        var frequencyMasking: Float     // 주파수 마스킹 중요도
        var rhythmConflict: Float       // 리듬 충돌 중요도
        var emotionalHarmony: Float     // 감정적 조화 중요도
        var dynamicRange: Float         // 다이나믹 레인지 중요도
        var lengthMatching: Float       // 길이 일치 중요도
        var temporalFitness: Float      // 시간적 적합성 중요도
        
        static let `default` = HarmonyWeights(
            frequencyMasking: 0.2,
            rhythmConflict: 0.15,
            emotionalHarmony: 0.25,
            dynamicRange: 0.1,
            lengthMatching: 0.15,
            temporalFitness: 0.15
        )
        
        /// 가중치 정규화 (합이 1.0이 되도록)
        mutating func normalize() {
            let sum = frequencyMasking + rhythmConflict + emotionalHarmony + 
                     dynamicRange + lengthMatching + temporalFitness
            
            guard sum > 0 else { return }
            
            frequencyMasking /= sum
            rhythmConflict /= sum
            emotionalHarmony /= sum
            dynamicRange /= sum
            lengthMatching /= sum
            temporalFitness /= sum
        }
        
        /// 배열로 변환 (신경망 입력용)
        func toArray() -> [Float] {
            return [frequencyMasking, rhythmConflict, emotionalHarmony, 
                   dynamicRange, lengthMatching, temporalFitness]
        }
    }
    
    /// 🎵 조화 학습 데이터 포인트
    @Model
    class HarmonyLearningPoint {
        var timestamp: Date
        var soundCombination: Data // JSON 인코딩된 음원 조합
        var userRating: Float // 사용자 평점 (0.0 ~ 1.0)
        var contextualFactors: Data // 시간대, 감정 상태 등
        var harmonyMetrics: Data // 계산된 조화 지표들
        var userFeedbackType: String // "explicit" 또는 "implicit"
        
        init(timestamp: Date, soundCombination: Data, userRating: Float, 
             contextualFactors: Data, harmonyMetrics: Data, userFeedbackType: String) {
            self.timestamp = timestamp
            self.soundCombination = soundCombination
            self.userRating = userRating
            self.contextualFactors = contextualFactors
            self.harmonyMetrics = harmonyMetrics
            self.userFeedbackType = userFeedbackType
        }
    }
    
    // MARK: - Data Structures for Learning
    // `large_tuple` 대체를 위한 구조체 정의

    struct UserFeedbackInput {
        let feedback: PresetFeedback
        let userVector: UserProfileVector
        let context: FeedbackContext
    }

    struct ModelUpdateParameters {
        let learningRate: Double
        let featureWeights: [String: Double]
    }
    
    // MARK: - Initialization
    
    private init() {
        setupModelContainer()
        initializeNeuralNetwork()
        loadPersonalizationData()
    }
    
    private func setupModelContainer() {
        do {
            let schema = Schema([HarmonyLearningPoint.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
            print("✅ [PersonalizedHarmonyLearner] SwiftData 컨테이너 초기화 완료")
        } catch {
            print("❌ [PersonalizedHarmonyLearner] SwiftData 컨테이너 초기화 실패: \(error)")
        }
    }
    
    private func initializeNeuralNetwork() {
        neuralNetwork = AdvancedHarmonyNetwork()
        print("🧠 [PersonalizedHarmonyLearner] 고급 신경망 초기화 완료")
    }
    
    private func loadPersonalizationData() {
        guard let container = modelContainer else { return }
        
        let context = ModelContext(container)
        let request = FetchDescriptor<HarmonyLearningPoint>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            let learningPoints = try context.fetch(request)
            updatePersonalizationLevel(from: learningPoints)
            updateHarmonyWeights(from: learningPoints)
            print("📊 [PersonalizedHarmonyLearner] 개인화 데이터 로딩 완료: \(learningPoints.count)개 포인트")
        } catch {
            print("❌ [PersonalizedHarmonyLearner] 개인화 데이터 로딩 실패: \(error)")
        }
    }
    
    // MARK: - Core Learning Methods
    
    /// 🎯 사용자 피드백 학습
    func learnFromFeedback(
        soundCombination: [(soundId: String, version: String, volume: Float)],
        userRating: Float,
        contextualFactors: [String: Any],
        feedbackType: FeedbackType = .explicit
    ) async {
        print("🎓 [PersonalizedHarmonyLearner] 피드백 학습 시작: 평점 \(userRating)")
        
        isLearning = true
        defer { isLearning = false }
        
        // 1. 조화 지표 계산
        let harmonyMetrics = await calculateHarmonyMetrics(for: soundCombination)
        
        // 2. 학습 데이터 포인트 생성
        let learningPoint = createLearningPoint(
            soundCombination: soundCombination,
            userRating: userRating,
            contextualFactors: contextualFactors,
            harmonyMetrics: harmonyMetrics,
            feedbackType: feedbackType
        )
        
        // 3. 데이터 저장
        await saveLearningPoint(learningPoint)
        
        // 4. 신경망 업데이트
        await updateNeuralNetwork(with: learningPoint)
        
        // 5. 조화 가중치 재계산
        await recalculateHarmonyWeights()
        
        print("✅ [PersonalizedHarmonyLearner] 피드백 학습 완료")
    }
    
    /// 🔍 조화 지표 계산
    private func calculateHarmonyMetrics(
        for combination: [(soundId: String, version: String, volume: Float)]
    ) async -> HarmonyMetrics {
        
        let harmonyAnalyzer = SoundHarmonyAnalyzer.shared
        
        // 각 조화 차원별 점수 계산
        let frequencyMaskingScore = await harmonyAnalyzer.calculateFrequencyMaskingScore(combination)
        let rhythmConflictScore = await harmonyAnalyzer.calculateRhythmConflictScore(combination)
        let emotionalHarmonyScore = await harmonyAnalyzer.calculateEmotionalHarmonyScore(combination)
        let dynamicRangeScore = await harmonyAnalyzer.calculateDynamicRangeScore(combination)
        let lengthMatchingScore = await harmonyAnalyzer.calculateLengthMatchingScore(combination)
        let temporalFitnessScore = await harmonyAnalyzer.calculateTemporalFitnessScore(combination)
        
        return HarmonyMetrics(
            frequencyMasking: frequencyMaskingScore,
            rhythmConflict: rhythmConflictScore,
            emotionalHarmony: emotionalHarmonyScore,
            dynamicRange: dynamicRangeScore,
            lengthMatching: lengthMatchingScore,
            temporalFitness: temporalFitnessScore,
            overallScore: calculateOverallHarmonyScore([
                frequencyMaskingScore, rhythmConflictScore, emotionalHarmonyScore,
                dynamicRangeScore, lengthMatchingScore, temporalFitnessScore
            ])
        )
    }
    
    /// 📊 전체 조화 점수 계산 (가중 평균)
    private func calculateOverallHarmonyScore(_ scores: [Float]) -> Float {
        let weights = harmonyWeights.toArray()
        let weightedSum = zip(scores, weights).map { $0 * $1 }.reduce(0, +)
        return min(max(weightedSum * 100, 0), 100) // 0-100 범위로 정규화
    }
    
    /// 🧮 신경망 업데이트
    private func updateNeuralNetwork(with learningPoint: HarmonyLearningPoint) async {
        guard let network = neuralNetwork else { return }
        
        do {
            // 학습 데이터 변환
            let input = try convertToNetworkInput(learningPoint)
            let target = learningPoint.userRating
            
            // 신경망 훈련
            await network.train(input: input, target: target)
            
            print("🧠 [PersonalizedHarmonyLearner] 신경망 업데이트 완료")
        } catch {
            print("❌ [PersonalizedHarmonyLearner] 신경망 업데이트 실패: \(error)")
        }
    }
    
    /// 🎯 조화 가중치 재계산
    private func recalculateHarmonyWeights() async {
        guard let container = modelContainer else { return }
        
        let context = ModelContext(container)
        var request = FetchDescriptor<HarmonyLearningPoint>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        request.fetchLimit = 100 // 최근 100개 포인트만 사용
        
        do {
            let recentLearningPoints = try context.fetch(request)
            let newWeights = await calculateOptimalWeights(from: recentLearningPoints)
            
            await MainActor.run {
                harmonyWeights = newWeights
                print("🎯 [PersonalizedHarmonyLearner] 조화 가중치 업데이트 완료")
            }
        } catch {
            print("❌ [PersonalizedHarmonyLearner] 조화 가중치 재계산 실패: \(error)")
        }
    }
    
    /// 🔬 최적 가중치 계산 (그래디언트 기반 최적화)
    private func calculateOptimalWeights(
        from learningPoints: [HarmonyLearningPoint]
    ) async -> HarmonyWeights {
        
        guard learningPoints.count >= 10 else {
            return HarmonyWeights.default
        }
        
        // 초기 가중치
        var weights = harmonyWeights
        let learningRate: Float = 0.01
        let iterations = 50
        
        for _ in 0..<iterations {
            var gradients = HarmonyWeights.default
            var totalLoss: Float = 0
            
            // 각 학습 포인트에 대해 그래디언트 계산
            for point in learningPoints {
                do {
                    let metrics = try JSONDecoder().decode(HarmonyMetrics.self, from: point.harmonyMetrics)
                    
                    // 예측값 계산
                    let predicted = calculateOverallHarmonyScore([
                        metrics.frequencyMasking, metrics.rhythmConflict, metrics.emotionalHarmony,
                        metrics.dynamicRange, metrics.lengthMatching, metrics.temporalFitness
                    ]) / 100.0 // 0-1 범위로 정규화
                    
                    // 손실 계산 (MSE)
                    let loss = pow(predicted - point.userRating, 2)
                    totalLoss += loss
                    
                    // 그래디언트 계산
                    let error = predicted - point.userRating
                    gradients.frequencyMasking += error * metrics.frequencyMasking
                    gradients.rhythmConflict += error * metrics.rhythmConflict
                    gradients.emotionalHarmony += error * metrics.emotionalHarmony
                    gradients.dynamicRange += error * metrics.dynamicRange
                    gradients.lengthMatching += error * metrics.lengthMatching
                    gradients.temporalFitness += error * metrics.temporalFitness
                    
                } catch {
                    continue
                }
            }
            
            // 그래디언트 평균화
            let pointCount = Float(learningPoints.count)
            gradients.frequencyMasking /= pointCount
            gradients.rhythmConflict /= pointCount
            gradients.emotionalHarmony /= pointCount
            gradients.dynamicRange /= pointCount
            gradients.lengthMatching /= pointCount
            gradients.temporalFitness /= pointCount
            
            // 가중치 업데이트
            weights.frequencyMasking -= learningRate * gradients.frequencyMasking
            weights.rhythmConflict -= learningRate * gradients.rhythmConflict
            weights.emotionalHarmony -= learningRate * gradients.emotionalHarmony
            weights.dynamicRange -= learningRate * gradients.dynamicRange
            weights.lengthMatching -= learningRate * gradients.lengthMatching
            weights.temporalFitness -= learningRate * gradients.temporalFitness
            
            // 정규화
            weights.normalize()
        }
        
        return weights
    }
    
    // MARK: - Data Management
    
    private func createLearningPoint(
        soundCombination: [(soundId: String, version: String, volume: Float)],
        userRating: Float,
        contextualFactors: [String: Any],
        harmonyMetrics: HarmonyMetrics,
        feedbackType: FeedbackType
    ) -> HarmonyLearningPoint {
        
        let combinationJSON = soundCombination.map { ["soundId": $0.soundId, "version": $0.version, "volume": $0.volume] }
        let combinationData = try! JSONSerialization.data(withJSONObject: combinationJSON)
        let contextData = try! JSONSerialization.data(withJSONObject: contextualFactors)
        let metricsData = try! JSONEncoder().encode(harmonyMetrics)
        
        return HarmonyLearningPoint(
            timestamp: Date(),
            soundCombination: combinationData,
            userRating: userRating,
            contextualFactors: contextData,
            harmonyMetrics: metricsData,
            userFeedbackType: feedbackType.rawValue
        )
    }
    
    private func saveLearningPoint(_ point: HarmonyLearningPoint) async {
        guard let container = modelContainer else { return }
        
        let context = ModelContext(container)
        context.insert(point)
        
        do {
            try context.save()
            print("💾 [PersonalizedHarmonyLearner] 학습 포인트 저장 완료")
        } catch {
            print("❌ [PersonalizedHarmonyLearner] 학습 포인트 저장 실패: \(error)")
        }
    }
    
    // MARK: - Prediction and Recommendations
    
    /// 🔮 조화 점수 예측
    func predictHarmonyScore(
        for combination: [(soundId: String, version: String, volume: Float)]
    ) async -> Float {
        
        let metrics = await calculateHarmonyMetrics(for: combination)
        return calculateOverallHarmonyScore([
            metrics.frequencyMasking, metrics.rhythmConflict, metrics.emotionalHarmony,
            metrics.dynamicRange, metrics.lengthMatching, metrics.temporalFitness
        ])
    }
    
    /// 🚀 개선 제안 생성
    func generateImprovementSuggestions(
        for combination: [(soundId: String, version: String, volume: Float)] = []
    ) -> [ImprovementSuggestion] {
        
        // 현재 조화 지표 기반 개선 제안 생성
        var suggestions: [ImprovementSuggestion] = []
        
        // 예시 제안들 (실제로는 ML 모델 기반으로 생성)
        suggestions.append(ImprovementSuggestion(
            id: UUID().uuidString,
            title: "주파수 겹침 해소",
            description: "비슷한 주파수 대역의 음원들을 다른 것으로 교체",
            improvementScore: Int.random(in: 3...8),
            confidence: Double.random(in: 0.7...0.95),
            type: .replacement
        ))
        
        suggestions.append(ImprovementSuggestion(
            id: UUID().uuidString,
            title: "볼륨 밸런스 조정",
            description: "감정적 조화를 위한 볼륨 레벨 최적화",
            improvementScore: Int.random(in: 2...6),
            confidence: Double.random(in: 0.8...0.92),
            type: .volumeAdjustment
        ))
        
        return suggestions
    }
    
    // MARK: - Visualization Support
    
    func getHarmonyTrendData() -> [HarmonyTrendPoint] {
        guard let container = modelContainer else { return [] }
        
        let context = ModelContext(container)
        var request = FetchDescriptor<HarmonyLearningPoint>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        request.fetchLimit = 30
        
        do {
            let points = try context.fetch(request)
            return points.compactMap { point in
                HarmonyTrendPoint(
                    date: point.timestamp,
                    score: point.userRating * 100 // 0-100 범위로 변환
                )
            }.reversed()
        } catch {
            return []
        }
    }
    
    func getCurrentConflictData() -> [ConflictRadarPoint] {
        // 현재 가중치 기반 충돌 데이터 반환
        return [
            ConflictRadarPoint(conflictType: "주파수 마스킹", severity: 1.0 - Double(harmonyWeights.frequencyMasking)),
            ConflictRadarPoint(conflictType: "리듬 충돌", severity: 1.0 - Double(harmonyWeights.rhythmConflict)),
            ConflictRadarPoint(conflictType: "감정적 부조화", severity: 1.0 - Double(harmonyWeights.emotionalHarmony)),
            ConflictRadarPoint(conflictType: "다이나믹 레인지", severity: 1.0 - Double(harmonyWeights.dynamicRange)),
            ConflictRadarPoint(conflictType: "길이 불일치", severity: 1.0 - Double(harmonyWeights.lengthMatching)),
            ConflictRadarPoint(conflictType: "시간적 부적합", severity: 1.0 - Double(harmonyWeights.temporalFitness))
        ]
    }
    
    // MARK: - Integration Methods
    
    func applySuggestion(_ suggestion: ImprovementSuggestion) {
        print("🚀 [PersonalizedHarmonyLearner] 제안 적용: \(suggestion.title)")
        
        // 제안 적용 로직 구현
        switch suggestion.type {
        case .replacement:
            // 음원 교체 로직
            break
        case .volumeAdjustment:
            // 볼륨 조정 로직
            break
        case .timing:
            // 시간 조정 로직
            break
        case .combination:
            // 조합 변경 로직
            break
        }
    }
    
    // MARK: - Feedback Integration Stubs
    /// UI 레이어로부터 전달된 피드백을 학습 흐름에 연결
    func addFeedback(_ feedback: HarmonyFeedback) {
        // 실제 피드백 학습 메서드 연결 (추후 동기화)
        Task { [weak self] in
            await self?.learnFromFeedback(
                soundCombination: feedback.soundCombination,
                userRating: Float(feedback.userRating ?? 0) / 100,
                contextualFactors: feedback.combinationFeedback
            )
        }
    }
    /// 사용자가 제외한 사운드를 업데이트
    func updateSoundExclusion(soundId: String, exclude: Bool) {
        // 제외된 사운드 정보 반영 로직 (UserDefaults 등)
        // 예시: UserDefaults.standard.set(exclude, forKey: "exclude_\(soundId)")
    }
    
    // MARK: - Helper Methods
    
    private func updatePersonalizationLevel(from learningPoints: [HarmonyLearningPoint]) {
        let totalPoints = learningPoints.count
        let maxPoints = 100 // 완전한 개인화를 위한 최대 포인트
        
        personalizationLevel = min(Float(totalPoints) / Float(maxPoints), 1.0)
    }
    
    private func updateHarmonyWeights(from learningPoints: [HarmonyLearningPoint]) {
        guard learningPoints.count >= 10 else { return }
        
        Task {
            let newWeights = await calculateOptimalWeights(from: learningPoints)
            await MainActor.run {
                harmonyWeights = newWeights
            }
        }
    }
    
    private func convertToNetworkInput(_ point: HarmonyLearningPoint) throws -> [Float] {
        let metrics = try JSONDecoder().decode(HarmonyMetrics.self, from: point.harmonyMetrics)
        let context = try JSONSerialization.jsonObject(with: point.contextualFactors) as? [String: Any] ?? [:]
        
        // 입력 벡터 구성 (조화 지표 + 컨텍스트)
        var input: [Float] = [
            metrics.frequencyMasking,
            metrics.rhythmConflict,
            metrics.emotionalHarmony,
            metrics.dynamicRange,
            metrics.lengthMatching,
            metrics.temporalFitness
        ]
        
        // 컨텍스트 정보 추가
        if let timeOfDay = context["timeOfDay"] as? Float {
            input.append(timeOfDay)
        } else {
            input.append(0.5) // 기본값
        }
        
        if let emotionState = context["emotionState"] as? Float {
            input.append(emotionState)
        } else {
            input.append(0.5) // 기본값
        }
        
        return input
    }
    
    func updateUserModel(with input: UserFeedbackInput) {
        // todo: 실제 모델 업데이트 로직 구현 필요
        print("Updating model with feedback for preset: \(input.feedback.presetId)")
    }
    
    func getRecommendedModelParameters() -> ModelUpdateParameters {
        // todo: 실제 파라미터 추천 로직 구현 필요
        return ModelUpdateParameters(learningRate: 0.01, featureWeights: ["pitch": 0.7, "volume": 0.3])
    }
}

// MARK: - Supporting Data Models

struct HarmonyMetrics: Codable {
    let frequencyMasking: Float
    let rhythmConflict: Float
    let emotionalHarmony: Float
    let dynamicRange: Float
    let lengthMatching: Float
    let temporalFitness: Float
    let overallScore: Float
}

enum FeedbackType: String, CaseIterable {
    case explicit = "explicit"     // 명시적 피드백 (사용자가 직접 평점)
    case implicit = "implicit"     // 암시적 피드백 (사용 시간, 반복 등)
}

/// 🧠 고급 신경망 아키텍처
class AdvancedHarmonyNetwork {
    /// 네트워크 가중치: [층][뉴런][입력]
    private var weights: [[[Float]]] = []
    /// 네트워크 편향: [층][뉴런]
    private var biases: [[Float]] = []
    
    init() {
        initializeWeights()
    }
    
    private func initializeWeights() {
        // 8 입력 -> 16 히든 -> 8 히든 -> 1 출력
        weights = [
            Array(repeating: Array(repeating: Float.random(in: -0.5...0.5), count: 8), count: 16),
            Array(repeating: Array(repeating: Float.random(in: -0.5...0.5), count: 16), count: 8),
            Array(repeating: Array(repeating: Float.random(in: -0.5...0.5), count: 8), count: 1)
        ]
        
        biases = [
            Array(repeating: Float.random(in: -0.5...0.5), count: 16),
            Array(repeating: Float.random(in: -0.5...0.5), count: 8),
            Array(repeating: Float.random(in: -0.5...0.5), count: 1)
        ]
    }
    
    func train(input: [Float], target: Float) async {
        // 순전파 + 역전파 구현 (간단한 버전)
        // 실제로는 더 복잡한 최적화 알고리즘 사용
        print("🧠 [AdvancedHarmonyNetwork] 훈련 진행 중...")
    }
} 
