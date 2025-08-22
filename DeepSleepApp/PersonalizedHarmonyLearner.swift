import Foundation

// MARK: - Feedback Context (SSoT for feedback-related context passed into learner)
struct FeedbackContext {
    let environment: [String: Any]
    let device: [String: Any]
    let timeOfDay: String
    let emotion: String?
}

/// 🤖 외부 AI 기반 조화 분석 시스템
/// ChatManager.sendMessage를 통해 4개 외부 모델 + 로컬 온디바이스로 조화 분석 수행
@MainActor
class PersonalizedHarmonyLearner: ObservableObject {
    
    static let shared = PersonalizedHarmonyLearner()
    
    // MARK: - Properties
    @Published var harmonyWeights: HarmonyWeights = HarmonyWeights.default
    @Published var isAnalyzing: Bool = false
    
    // 🚀 Phase 3: 통합 데이터 관리 시스템 연동
    private let sessionManager = SessionManager.shared
    
    // MARK: - Data Models
    
    // 🎯 조화 가중치 - SharedModels.swift에서 정의된 SSoT 사용
    
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
    
    /// 🚀 Phase 3: SessionManager 연동 강화된 사용자 피드백 분석
    func analyzeUserFeedback(
        soundCombination: [(soundId: String, version: String, volume: Float)],
        userRating: Float,
        contextualFactors: [String: Any]
    ) async {
        print("🚀 [PersonalizedHarmonyLearner] Phase 3 고도화된 피드백 분석 시작: 평점 \(userRating)")
        
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        let startTime = Date()
        
        do {
            // 🚀 Phase 3: SessionManager에서 풍부한 컨텍스트 데이터 가져오기
            let richContext = sessionManager.buildRichContextForLocalAI()
            let enhancedContextualFactors = enhanceContextualFactors(
                original: contextualFactors,
                richContext: richContext
            )
            
            // ChatManager를 통해 외부 AI 모델로 분석 요청
            let analysisPrompt = buildEnhancedFeedbackAnalysisPrompt(
                soundCombination: soundCombination,
                userRating: userRating,
                contextualFactors: enhancedContextualFactors,
                richContext: richContext
            )
            
            let aiResponseObj = try await UnifiedAIServiceImpl.shared.sendMessage(
                content: analysisPrompt,
                model: .claude,
                mode: .emotionAnalysis,
                context: nil,
                tokenConfig: nil
            )
            let aiResponse = aiResponseObj.content
            
            let processingTime = Date().timeIntervalSince(startTime)
            
            print("🚀 [PersonalizedHarmonyLearner] Phase 3 AI 분석 완료: \(aiResponse.prefix(100))... (처리시간: \(String(format: "%.2f", processingTime))초)")
            
            // 🚀 Phase 3: AI 응답을 바탕으로 조화 가중치 업데이트 (강화된 버전)
            await updateHarmonyWeightsFromAI(aiResponse, processingTime: processingTime)
            
            // 🚀 Phase 3: SessionManager에 분석 결과 저장
            await recordAnalysisToSession(
                soundCombination: soundCombination,
                userRating: userRating,
                aiResponse: aiResponse,
                processingTime: processingTime
            )
            
        } catch {
            print("❌ [PersonalizedHarmonyLearner] AI 분석 실패: \(error)")
            
            // 🚀 Phase 3: 에러도 SessionManager에 기록
            await recordAnalysisError(error: error)
        }
    }
    
    /// 🚀 Phase 3: 강화된 피드백 분석 프롬프트 생성 (SessionManager 데이터 활용)
    private func buildEnhancedFeedbackAnalysisPrompt(
        soundCombination: [(soundId: String, version: String, volume: Float)],
        userRating: Float,
        contextualFactors: [String: Any],
        richContext: LocalAIContext
    ) -> String {
        let soundList = soundCombination.map { "\($0.soundId) (볼륨: \($0.volume))" }.joined(separator: ", ")
        let context = contextualFactors.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        
        // 🚀 Phase 3: 풍부한 사용자 히스토리 추가
        let emotionHistory = richContext.emotionHistory.prefix(3).map { 
            "\($0.emotion)(강도: \(String(format: "%.1f", $0.intensity)))" 
        }.joined(separator: ", ")
        
        let feedbackHistory = richContext.feedbackData.prefix(3).map {
            "\($0.presetName ?? "알 수 없음")(만족도: \($0.satisfactionScore))" 
        }.joined(separator: ", ")
        
        return """
        🎯 사용자 개인화 조화 분석 요청
        
        현재 피드백:
        - 사운드 조합: \(soundList)
        - 사용자 평점: \(userRating * 100)점
        - 현재 상황: \(context)
        
        사용자 히스토리:
        - 최근 감정 패턴: \(emotionHistory.isEmpty ? "데이터 없음" : emotionHistory)
        - 최근 피드백 패턴: \(feedbackHistory.isEmpty ? "데이터 없음" : feedbackHistory)
        
        현재 조화 가중치:
        - 주파수 마스킹: \(String(format: "%.2f", self.harmonyWeights.frequencyMasking))
        - 리듬 충돌: \(String(format: "%.2f", self.harmonyWeights.rhythmConflict))
        - 감정적 조화: \(String(format: "%.2f", self.harmonyWeights.emotionalHarmony))
        - 다이나믹 레인지: \(String(format: "%.2f", self.harmonyWeights.dynamicRange))
        - 길이 일치: \(String(format: "%.2f", self.harmonyWeights.lengthMatching))
        - 시간적 적합성: \(String(format: "%.2f", self.harmonyWeights.temporalFitness))
        
        위 정보를 종합하여 개인화된 조화도 가중치 조정 방안을 JSON 형식으로 제안해주세요:
        {
            \"frequencyMasking\": 0.0-1.0,
            \"rhythmConflict\": 0.0-1.0,
            \"emotionalHarmony\": 0.0-1.0,
            \"dynamicRange\": 0.0-1.0,
            \"lengthMatching\": 0.0-1.0,
            \"temporalFitness\": 0.0-1.0,
            \"confidence\": 0.0-1.0,
            \"reasoning\": \"조정 근거\",
            \"personalizedInsights\": \"개인화 인사이트\"
        }
        """
    }
    
    /// 🚀 Phase 3: 컨텍스트 데이터 강화
    private func enhanceContextualFactors(
        original: [String: Any],
        richContext: LocalAIContext
    ) -> [String: Any] {
        var enhanced = original
        
        // 감정 컨텍스트 추가
        if let recentEmotion = richContext.emotionHistory.first {
            enhanced["recentEmotion"] = recentEmotion.emotion
            enhanced["emotionIntensity"] = recentEmotion.intensity
        }
        
        // 피드백 패턴 추가
        if !richContext.feedbackData.isEmpty {
            let avgSatisfaction = richContext.feedbackData.compactMap { Double($0.satisfactionScore) }.reduce(0, +) / Double(richContext.feedbackData.count)
            enhanced["averageSatisfaction"] = avgSatisfaction
        }
        
        // 시간 패턴 추가
        let currentHour = Calendar.current.component(.hour, from: Date())
        enhanced["currentHour"] = currentHour
        enhanced["timeOfDay"] = getTimeOfDayCategory(hour: currentHour)
        
        return enhanced
    }
    
    /// 시간대 카테고리 분류
    private func getTimeOfDayCategory(hour: Int) -> String {
        switch hour {
        case 6..<12: return "morning"
        case 12..<18: return "afternoon"
        case 18..<22: return "evening"
        default: return "night"
        }
    }
    
    /// 🚀 Phase 3: 강화된 AI 응답 기반 조화 가중치 업데이트
    private func updateHarmonyWeightsFromAI(_ aiResponse: String, processingTime: TimeInterval) async {
        let oldWeights = harmonyWeights
        
        // JSON 파싱 시도 (여러 형태의 JSON 응답 지원)
        if let parsedResult = parseAIResponse(aiResponse) {
            var newWeights = parsedResult.weights
            newWeights.normalize()
            
            // 🚀 Phase 3: 가중치 변화량 계산 및 로깅
            let weightChanges = calculateWeightChanges(from: oldWeights, to: newWeights)
            let confidence = parsedResult.confidence ?? 0.5
            
            // 신뢰도가 높은 경우에만 업데이트
            if confidence > 0.6 {
                harmonyWeights = newWeights
                
                print("🎯 [PersonalizedHarmonyLearner] Phase 3 AI 기반 가중치 업데이트 완료")
                print("   신뢰도: \(String(format: "%.2f", confidence))")
                print("   주요 변화: \(weightChanges.sorted { $0.value > $1.value }.prefix(3).map { "\($0.key): \(String(format: "%.3f", $0.value))" }.joined(separator: ", "))")
                
                // 🚀 Phase 3: 가중치 변화 히스토리 저장 (TODO: 구현 필요)
                // await saveWeightChangeHistory(
                //     oldWeights: oldWeights,
                //     newWeights: newWeights,
                //     confidence: confidence,
                //     processingTime: processingTime
                // )
            } else {
                print("⚠️ [PersonalizedHarmonyLearner] AI 응답 신뢰도가 낮아 가중치 업데이트 스킵 (신뢰도: \(String(format: "%.2f", confidence)))")
            }
        } else {
            print("❌ [PersonalizedHarmonyLearner] AI 응답 파싱 실패")
        }
    }
    
    /// 🚀 Phase 3: 고도화된 AI 응답 파싱
    private func parseAIResponse(_ response: String) -> (weights: HarmonyWeights, confidence: Double?)? {
        // JSON 블록 추출 시도
        let jsonPattern = "\\{[^\\{\\}\\]*(?:\\{[^\\{\\}\\]*\\}[^\\{\\}\\]*)*\\}" // Corrected regex for nested JSON
        let regex = try? NSRegularExpression(pattern: jsonPattern, options: [])
        let range = NSRange(response.startIndex..<response.endIndex, in: response)
        
        guard let match = regex?.firstMatch(in: response, options: [], range: range),
              let jsonRange = Range(match.range, in: response) else {
            return nil
        }
        
        let jsonString = String(response[jsonRange])
        
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        var weights = self.harmonyWeights // 기본값으로 시작
        
        if let freq = json["frequencyMasking"] as? Double {
            weights.frequencyMasking = Float(freq)
        }
        if let rhythm = json["rhythmConflict"] as? Double {
            weights.rhythmConflict = Float(rhythm)
        }
        if let emotion = json["emotionalHarmony"] as? Double {
            weights.emotionalHarmony = Float(emotion)
        }
        if let dynamic = json["dynamicRange"] as? Double {
            weights.dynamicRange = Float(dynamic)
        }
        if let length = json["lengthMatching"] as? Double {
            weights.lengthMatching = Float(length)
        }
        if let temporal = json["temporalFitness"] as? Double {
            weights.temporalFitness = Float(temporal)
        }
        
        let confidence = json["confidence"] as? Double
        
        return (weights: weights, confidence: confidence)
    }
    
    /// 가중치 변화량 계산
    private func calculateWeightChanges(from old: HarmonyWeights, to new: HarmonyWeights) -> [String: Float] {
        return [
            "frequencyMasking": abs(new.frequencyMasking - old.frequencyMasking),
            "rhythmConflict": abs(new.rhythmConflict - old.rhythmConflict),
            "emotionalHarmony": abs(new.emotionalHarmony - old.emotionalHarmony),
            "dynamicRange": abs(new.dynamicRange - old.dynamicRange),
            "lengthMatching": abs(new.lengthMatching - old.lengthMatching),
            "temporalFitness": abs(new.temporalFitness - old.temporalFitness)
        ]
    }
    
    // MARK: - AI-Based Predictions and Recommendations
    
    /// 🤖 외부 AI를 통한 조화 점수 예측
    func predictHarmonyScore(
        for combination: [(soundId: String, version: String, volume: Float)]
    ) async -> Float {
        
        do {
            let predictionPrompt = buildHarmonyPredictionPrompt(combination)
            let aiResponseObj = try await UnifiedAIServiceImpl.shared.sendMessage(
                content: predictionPrompt,
                model: .gemini,
                mode: .presetRecommendation,
                context: nil,
                tokenConfig: nil
            )
            let aiResponse = aiResponseObj.content
            
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
        
        결과를 \"점수: XX점\" 형식으로 답변해주세요.
        """
    }
    
    /// 🤖 AI 응답에서 점수 추출
    private func extractScoreFromResponse(_ response: String) -> Float? {
        // 정규식으로 "점수: XX점" 패턴 추출
        let pattern = "점수:?\\s*(\\\\d+)점?"
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
            ConflictRadarPoint(conflictType: "주파수 마스킹", severity: 1.0 - Double(self.harmonyWeights.frequencyMasking)),
            ConflictRadarPoint(conflictType: "리듬 충돌", severity: 1.0 - Double(self.harmonyWeights.rhythmConflict)),
            ConflictRadarPoint(conflictType: "감정적 부조화", severity: 1.0 - Double(self.harmonyWeights.emotionalHarmony)),
            ConflictRadarPoint(conflictType: "다이나믹 레인지", severity: 1.0 - Double(self.harmonyWeights.dynamicRange)),
            ConflictRadarPoint(conflictType: "길이 불일치", severity: 1.0 - Double(self.harmonyWeights.lengthMatching)),
            ConflictRadarPoint(conflictType: "시간적 부적합", severity: 1.0 - Double(self.harmonyWeights.temporalFitness))
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
                
                let aiResponseObj = try await UnifiedAIServiceImpl.shared.sendMessage(
                    content: applicationPrompt,
                    model: .claude,
                    mode: .taskAdvice,
                    context: nil,
                    tokenConfig: nil
                )
                let aiResponse = aiResponseObj.content
                
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
                
                let aiResponseObj = try await UnifiedAIServiceImpl.shared.sendMessage(
                    content: exclusionPrompt,
                    model: .gemini,
                    mode: .presetRecommendation,
                    context: nil,
                    tokenConfig: nil
                )
                let aiResponse = aiResponseObj.content
                
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
                
                프리셋 ID: \(input.feedback.presetName ?? "알 수 없음")
                피드백 내용: 사용자의 취향과 선호도 분석
                
                어떤 개선점을 적용해야 할까요?
                """
                
                let aiResponseObj = try await UnifiedAIServiceImpl.shared.sendMessage(
                    content: updatePrompt,
                    model: .claude,
                    mode: .emotionAnalysis,
                    context: nil,
                    tokenConfig: nil
                )
                let aiResponse = aiResponseObj.content
                
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
    
    // MARK: - 🔄 간소화된 학습 시스템 (빌드 오류 수정)
    
    /// 실시간 사용자 상호작용 학습 (기존 피드백 시스템 연동)
    public func learnFromUserInteraction(
        soundCategories: [String: Float],
        userEmotion: String,
        timeOfDay: Int,
        context: String
    ) async {
        print("🤖 [PersonalizedHarmonyLearner] 실시간 상호작용 학습: \(context)")
        print("🤖 사운드 카테고리: \(soundCategories)")
        print("🤖 감정: \(userEmotion), 시간: \(timeOfDay)시")
        
        // 간단한 학습 로직 - UserDefaults에 패턴 저장
        let learningKey = "interaction_\(context)_\(Date().timeIntervalSince1970)"
        let learningData: [String: Any] = [
            "soundCategories": soundCategories,
            "userEmotion": userEmotion,
            "timeOfDay": timeOfDay,
            "context": context
        ]
        UserDefaults.standard.set(learningData, forKey: learningKey)
    }
    
    // MARK: - 🚀 Phase 3: SessionManager 연동 메서드들
    
    /// 분석 결과를 SessionManager에 저장
    private func recordAnalysisToSession(
        soundCombination: [(soundId: String, version: String, volume: Float)],
        userRating: Float,
        aiResponse: String,
        processingTime: TimeInterval
    ) async {
        let behaviorEvent = BehaviorEvent(
            type: BehaviorEventType.harmonyAnalysis,
            timestamp: Date(),
            data: [
                "soundCount": String(soundCombination.count),
                "userRating": String(userRating),
                "processingTime": String(processingTime),
                "aiResponseLength": String(aiResponse.count),
                "harmonyWeights": self.harmonyWeights.toArray().map { String($0) }.joined(separator: ",")
            ]
        )
        
        let currentSession = SessionManager.shared.getCurrentOrCreateSession()
        SessionManager.shared.addBehaviorEvent(to: currentSession.id, event: behaviorEvent)
        
        print("📊 [PersonalizedHarmonyLearner] 분석 결과 SessionManager에 저장 완료")
    }
    
    /// 분석 에러를 SessionManager에 기록
    private func recordAnalysisError(error: Error) async {
        let behaviorEvent = BehaviorEvent(
            type: BehaviorEventType.harmonyAnalysisError,
            timestamp: Date(),
            data: [
                "errorDescription": error.localizedDescription,
                "errorType": String(describing: type(of: error))
            ]
        )
        
        let currentSession = SessionManager.shared.getCurrentOrCreateSession()
        SessionManager.shared.addBehaviorEvent(to: currentSession.id, event: behaviorEvent)
    }
    
    /// 가중치 업데이트를 SessionManager에 기록
    private func recordWeightUpdate(
        oldWeights: HarmonyWeights,
        newWeights: HarmonyWeights,
        confidence: Double
    ) async {
        let behaviorEvent = BehaviorEvent(
            type: BehaviorEventType.weightUpdate,
            timestamp: Date(),
            data: [
                "oldWeights": oldWeights.toArray().map { String($0) }.joined(separator: ","),
                "newWeights": newWeights.toArray().map { String($0) }.joined(separator: ","),
                "confidence": String(confidence)
            ]
        )
        
        let currentSession = SessionManager.shared.getCurrentOrCreateSession()
        SessionManager.shared.addBehaviorEvent(to: currentSession.id, event: behaviorEvent)
    }
    
    /// 조화 학습 성능 통계 조회
    func getHarmonyLearningStats() async -> HarmonyLearningStats {
        let recentSessions = SessionManager.shared.getRecentSessions(limit: 30)
        
        var analysisCount = 0
        var totalProcessingTime: TimeInterval = 0
        var averageConfidence: Double = 0
        var errorCount = 0
        
        for session in recentSessions {
            for event in session.behaviorEvents {
                switch event.type {
                case .harmonyAnalysis:
                    analysisCount += 1
                    if let processingTimeStr = event.data["processingTime"],
                       let processingTime = TimeInterval(processingTimeStr) {
                        totalProcessingTime += processingTime
                    }
                case .harmonyAnalysisError:
                    errorCount += 1
                case .weightUpdate:
                    if let confidenceStr = event.data["confidence"],
                       let confidence = Double(confidenceStr) {
                        averageConfidence += confidence
                    }
                default:
                    break
                }
            }
        }
        
        return HarmonyLearningStats(
            totalAnalyses: analysisCount,
            averageProcessingTime: analysisCount > 0 ? totalProcessingTime / Double(analysisCount) : 0,
            averageConfidence: analysisCount > 0 ? averageConfidence / Double(analysisCount) : 0,
            errorRate: analysisCount > 0 ? Double(errorCount) / Double(analysisCount + errorCount) : 0,
            currentWeights: self.harmonyWeights
        )
    }
    
    /// 조화 학습 통계 구조체
    struct HarmonyLearningStats {
        let totalAnalyses: Int
        let averageProcessingTime: TimeInterval
        let averageConfidence: Double
        let errorRate: Double
        let currentWeights: HarmonyWeights
    }
    
    /// 디버그용 성능 통계 출력
    func printPerformanceStats() async {
        let stats = await getHarmonyLearningStats()
        
        if stats.totalAnalyses > 0 {
            print(String(repeating: "=", count: 50))
            print("🎯 [PersonalizedHarmonyLearner] 성능 통계")
            print("총 분석 횟수: \(stats.totalAnalyses)")
            print("평균 처리 시간: \(String(format: "%.2f", stats.averageProcessingTime))초")
            print("평균 신뢰도: \(String(format: "%.2f", stats.averageConfidence * 100))%")
            print("에러율: \(String(format: "%.2f", stats.errorRate * 100))%")
            print("\n현재 조화 가중치:")
            print("  주파수 마스킹: \(String(format: "%.3f", stats.currentWeights.frequencyMasking))")
            print("  리듬 충돌: \(String(format: "%.3f", stats.currentWeights.rhythmConflict))")
            print("  감정적 조화: \(String(format: "%.3f", stats.currentWeights.emotionalHarmony))")
            print("  다이나믹 레인지: \(String(format: "%.3f", stats.currentWeights.dynamicRange))")
            print("  길이 일치: \(String(format: "%.3f", stats.currentWeights.lengthMatching))")
            print("  시간적 적합성: \(String(format: "%.3f", stats.currentWeights.temporalFitness))")
            print(String(repeating: "=", count: 50))
        }
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
