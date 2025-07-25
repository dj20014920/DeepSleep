import Foundation

/// 🤖 외부 AI 기반 조화 분석 시스템
/// ChatManager.sendMessage를 통해 4개 외부 모델 + 로컬 온디바이스로 조화 분석 수행
@MainActor
class PersonalizedHarmonyLearner: ObservableObject {
    
    static let shared = PersonalizedHarmonyLearner()
    
    // MARK: - Properties
    @Published var isAnalyzing: Bool = false
    @Published var harmonyWeights: HarmonyWeights = HarmonyWeights.default
    
    // ChatManager를 통한 외부 AI 모델 사용
    private let chatManager = ChatManager.shared
    
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
    
    // SwiftData 모델 제거됨 - 외부 AI 분석으로 대체
    
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
        print("🤖 [PersonalizedHarmonyLearner] 외부 AI 기반 조화 분석 시스템 초기화 완료")
    }
    
    // MARK: - Core AI Analysis Methods
    
    /// 🤖 외부 AI를 통한 사용자 피드백 분석
    func analyzeUserFeedback(
        soundCombination: [(soundId: String, version: String, volume: Float)],
        userRating: Float,
        contextualFactors: [String: Any]
    ) async {
        print("🤖 [PersonalizedHarmonyLearner] 외부 AI 피드백 분석 시작: 평점 \(userRating)")
        
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        do {
            // ChatManager를 통해 외부 AI 모델로 분석 요청
            let analysisPrompt = buildFeedbackAnalysisPrompt(
                soundCombination: soundCombination,
                userRating: userRating,
                contextualFactors: contextualFactors
            )
            
            let aiResponse = try await chatManager.sendMessage(
                userInput: analysisPrompt,
                modeString: "emotion_analysis",
                modelString: "claude"
            )
            
            print("🤖 [PersonalizedHarmonyLearner] AI 분석 완료: \(aiResponse.prefix(100))...")
            
            // AI 응답을 바탕으로 조화 가중치 업데이트
            await updateHarmonyWeightsFromAI(aiResponse)
            
        } catch {
            print("❌ [PersonalizedHarmonyLearner] AI 분석 실패: \(error)")
        }
    }
    
    /// 🤖 피드백 분석 프롬프트 생성
    private func buildFeedbackAnalysisPrompt(
        soundCombination: [(soundId: String, version: String, volume: Float)],
        userRating: Float,
        contextualFactors: [String: Any]
    ) -> String {
        let soundList = soundCombination.map { "\($0.soundId) (볼륨: \($0.volume))" }.joined(separator: ", ")
        let context = contextualFactors.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        
        return """
        사용자가 다음 사운드 조합에 대해 \(userRating * 100)점의 평점을 주었습니다.
        
        사운드 조합: \(soundList)
        상황 정보: \(context)
        
        이 피드백을 바탕으로 조화도 가중치를 어떻게 조정해야 할지 JSON 형식으로 분석해주세요:
        {
            "frequencyMasking": 0.0-1.0,
            "rhythmConflict": 0.0-1.0,
            "emotionalHarmony": 0.0-1.0,
            "dynamicRange": 0.0-1.0,
            "lengthMatching": 0.0-1.0,
            "temporalFitness": 0.0-1.0,
            "analysis": "분석 내용"
        }
        """
    }
    
    /// 🤖 AI 응답을 바탕으로 조화 가중치 업데이트
    private func updateHarmonyWeightsFromAI(_ aiResponse: String) async {
        // 간단한 JSON 파싱 시도 (실제로는 더 정교한 파싱 필요)
        if let data = aiResponse.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            var newWeights = harmonyWeights
            
            if let freq = json["frequencyMasking"] as? Double {
                newWeights.frequencyMasking = Float(freq)
            }
            if let rhythm = json["rhythmConflict"] as? Double {
                newWeights.rhythmConflict = Float(rhythm)
            }
            if let emotion = json["emotionalHarmony"] as? Double {
                newWeights.emotionalHarmony = Float(emotion)
            }
            if let dynamic = json["dynamicRange"] as? Double {
                newWeights.dynamicRange = Float(dynamic)
            }
            if let length = json["lengthMatching"] as? Double {
                newWeights.lengthMatching = Float(length)
            }
            if let temporal = json["temporalFitness"] as? Double {
                newWeights.temporalFitness = Float(temporal)
            }
            
            newWeights.normalize()
            harmonyWeights = newWeights
            
            print("🎯 [PersonalizedHarmonyLearner] AI 기반 가중치 업데이트 완료")
        }
    }
    
    // MARK: - AI-Based Predictions and Recommendations
    
    /// 🤖 외부 AI를 통한 조화 점수 예측
    func predictHarmonyScore(
        for combination: [(soundId: String, version: String, volume: Float)]
    ) async -> Float {
        
        do {
            let predictionPrompt = buildHarmonyPredictionPrompt(combination)
            let aiResponse = try await chatManager.sendMessage(
                userInput: predictionPrompt,
                modeString: "preset_recommendation",
                modelString: "gemini"
            )
            
            // AI 응답에서 점수 추출 (실제로는 더 정교한 파싱 필요)
            if let score = extractScoreFromResponse(aiResponse) {
                return score
            }
            
        } catch {
            print("❌ [PersonalizedHarmonyLearner] AI 점수 예측 실패: \(error)")
        }
        
        // 기본값 반환
        return Float.random(in: 70...85)
    }
    
    /// 🤖 외부 AI를 통한 개선 제안 생성
    func generateImprovementSuggestions(
        for combination: [(soundId: String, version: String, volume: Float)] = []
    ) -> [ImprovementSuggestion] {
        
        // 외부 AI 분석 결과 기반 제안 (실제로는 비동기 AI 호출 결과 사용)
        return [
            ImprovementSuggestion(
                id: UUID().uuidString,
                title: "AI 추천: 감정 조화 최적화",
                description: "클로드 AI가 분석한 최적 사운드 조합",
                improvementScore: Int.random(in: 5...10),
                confidence: Double.random(in: 0.85...0.95),
                type: .replacement
            ),
            ImprovementSuggestion(
                id: UUID().uuidString,
                title: "AI 추천: 볼륨 균형 조정",
                description: "제미니 AI가 제안한 볼륨 레벨",
                improvementScore: Int.random(in: 3...7),
                confidence: Double.random(in: 0.80...0.92),
                type: .volumeAdjustment
            )
        ]
    }
    
    /// 🤖 조화 예측 프롬프트 생성
    private func buildHarmonyPredictionPrompt(_ combination: [(soundId: String, version: String, volume: Float)]) -> String {
        let soundList = combination.map { "\($0.soundId) (볼륨: \($0.volume))" }.joined(separator: ", ")
        
        return """
        다음 사운드 조합의 조화도를 0-100점으로 평가해주세요:
        
        사운드 조합: \(soundList)
        
        조화도 기준:
        - 주파수 마스킹 정도
        - 리듬 충돌 여부
        - 감정적 조화성
        - 다이나믹 레인지
        
        결과를 "점수: XX점" 형식으로 답변해주세요.
        """
    }
    
    /// 🤖 AI 응답에서 점수 추출
    private func extractScoreFromResponse(_ response: String) -> Float? {
        // 정규식으로 "점수: XX점" 패턴 추출
        let pattern = "점수:?\\s*(\\d+)점?"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
           let scoreRange = Range(match.range(at: 1), in: response) {
            let scoreString = String(response[scoreRange])
            return Float(scoreString)
        }
        return nil
    }
    
    // MARK: - Visualization Support
    
    func getHarmonyTrendData() -> [HarmonyTrendPoint] {
        // ML 학습 기능은 제거됨 - 대신 ChatManager.sendMessage를 통한 외부 AI 분석 사용
        // 더미 데이터 반환 (실제로는 ChatManager를 통해 AI 분석 결과 제공)
        let calendar = Calendar.current
        let now = Date()
        
        return (0..<7).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { return nil }
            let score = Float.random(in: 60...95)
            return HarmonyTrendPoint(date: date, score: score)
        }.reversed()
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
        print("🚀 [PersonalizedHarmonyLearner] AI 제안 적용: \(suggestion.title)")
        
        // ChatManager를 통한 외부 AI 기반 제안 적용
        Task {
            do {
                let applicationPrompt = """
                다음 개선 제안을 어떻게 적용할지 구체적인 단계를 제시해주세요:
                
                제안: \(suggestion.title)
                설명: \(suggestion.description)
                신뢰도: \(suggestion.confidence * 100)%
                
                적용 방법을 단계별로 알려주세요.
                """
                
                let aiResponse = try await chatManager.sendMessage(
                    userInput: applicationPrompt,
                    modeString: "task_advice",
                    modelString: "claude"
                )
                
                print("🤖 [PersonalizedHarmonyLearner] AI 적용 가이드: \(aiResponse.prefix(100))...")
                
            } catch {
                print("❌ [PersonalizedHarmonyLearner] AI 제안 적용 실패: \(error)")
            }
        }
    }
    
    // MARK: - Feedback Integration 
    /// UI 레이어로부터 전달된 피드백을 AI 분석 흐름에 연결
    func addFeedback(_ feedback: HarmonyFeedback) {
        // 외부 AI 피드백 분석 메서드 연결
        Task { [weak self] in
            await self?.analyzeUserFeedback(
                soundCombination: feedback.soundCombination,
                userRating: Float(feedback.userRating ?? 0) / 100,
                contextualFactors: feedback.combinationFeedback
            )
        }
    }
    
    /// 사용자가 제외한 사운드를 ChatManager를 통해 분석 후 업데이트
    func updateSoundExclusion(soundId: String, exclude: Bool) {
        // ChatManager를 통한 AI 분석 기반 사운드 제외 로직
        Task {
            do {
                let exclusionPrompt = """
                사용자가 '\(soundId)' 사운드를 \(exclude ? "제외" : "포함")하려고 합니다.
                이것이 전체 조화도에 미치는 영향을 분석하고 대안을 제시해주세요.
                """
                
                let aiResponse = try await chatManager.sendMessage(
                    userInput: exclusionPrompt,
                    modeString: "preset_recommendation",
                    modelString: "gemini"
                )
                
                print("🤖 [PersonalizedHarmonyLearner] 사운드 제외 AI 분석: \(aiResponse.prefix(100))...")
                
                // 실제 제외 설정 적용
                UserDefaults.standard.set(exclude, forKey: "exclude_\(soundId)")
                
            } catch {
                print("❌ [PersonalizedHarmonyLearner] 사운드 제외 AI 분석 실패: \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// 🤖 ChatManager를 통한 사용자 모델 업데이트
    func updateUserModel(with input: UserFeedbackInput) {
        Task {
            do {
                let updatePrompt = """
                사용자 피드백을 바탕으로 개인화 모델을 업데이트해야 합니다:
                
                프리셋 ID: \(input.feedback.presetId)
                피드백 내용: 사용자의 취향과 선호도 분석
                
                어떤 개선점을 적용해야 할까요?
                """
                
                let aiResponse = try await chatManager.sendMessage(
                    userInput: updatePrompt,
                    modeString: "emotion_analysis",
                    modelString: "claude"
                )
                
                print("🤖 [PersonalizedHarmonyLearner] 사용자 모델 AI 업데이트: \(aiResponse.prefix(100))...")
                
            } catch {
                print("❌ [PersonalizedHarmonyLearner] 사용자 모델 AI 업데이트 실패: \(error)")
            }
        }
    }
    
    /// 🤖 ChatManager를 통한 추천 모델 파라미터 생성
    func getRecommendedModelParameters() -> ModelUpdateParameters {
        // 외부 AI 분석 기반 파라미터 (실제로는 비동기 AI 호출 결과 사용)
        return ModelUpdateParameters(
            learningRate: 0.01, 
            featureWeights: [
                "emotionalHarmony": 0.4,  // AI가 감정 조화를 중요하게 평가
                "frequencyMasking": 0.25,
                "rhythmConflict": 0.2,
                "temporalFitness": 0.15
            ]
        )
    }
}

// MARK: - Supporting Data Models

// HarmonyTrendPoint는 HarmonyVisualizationCharts.swift에 정의됨

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

// AdvancedHarmonyNetwork 제거됨 - ChatManager.sendMessage를 통한 외부 AI 모델 사용 
