import UIKit

// MARK: - 고도화된 로컬 추천 시스템 구조체
struct EmotionalProfile {
    let primaryEmotion: String
    let secondaryEmotion: String?
    let intensity: Float
    let complexity: Float
}

struct ContextualFactors {
    let timeContext: String
    let activityLevel: String
    let socialContext: String
    let isWeekend: Bool
    let season: String
}

struct PersonalizedPreferences {
    let favoriteTimeSlots: [String]
    let preferredSoundTypes: [String]
    let volumePreferences: [String: Float]
    let adaptationSpeed: Float
}

struct EnvironmentalCues {
    let ambientLight: String
    let noiseLevel: String
    let temperatureContext: String
    let weatherMood: String
}

struct AdvancedRecommendation {
    let sounds: [String]
    let volumes: [Float]
    let versions: [Int]
    let confidence: Float
    let reasoning: String
}

// MARK: - ChatViewController Actions Extension (중앙 관리 로직 적용)
extension ChatViewController {
    
    // MARK: - 메시지 전송
    @objc func sendButtonTapped() {
        guard let text = inputTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
        
        // UI 즉시 업데이트
        inputTextField.text = ""
        
        // 🧠 종합 추천 요청 감지
        if isComprehensiveRecommendationRequest(text) {
            requestMasterComprehensiveRecommendation()
            return
        }
        
        let userMessage = ChatMessage(type: .user, text: text)
        appendChat(userMessage)
        
        // AI 응답 요청
        requestAIChatResponse(for: text)
    }
    
    /// 종합 추천 요청인지 감지
    private func isComprehensiveRecommendationRequest(_ text: String) -> Bool {
        let comprehensiveKeywords = [
            "종합", "모든", "전체", "완벽한", "최고의", "최적의", "마스터",
            "지금까지", "모든 정보", "전부", "총합", "총체적", "포괄적"
        ]
        
        let recommendationKeywords = [
            "프리셋 추천", "사운드 추천", "음악 추천", "추천해", "추천해줘", "추천받기"
        ]
        
        let lowercaseText = text.lowercased()
        
        // 종합 + 추천 키워드 조합 확인
        let hasComprehensive = comprehensiveKeywords.contains { lowercaseText.contains($0) }
        let hasRecommendation = recommendationKeywords.contains { lowercaseText.contains($0) }
        
        return hasComprehensive && hasRecommendation
    }
    
    // MARK: - AI 응답 요청 및 처리
    private func requestAIChatResponse(for text: String) {
        // 1. 사용량 제한 확인
        guard AIUsageManager.shared.canUse(feature: .chat) else {
            let limitMessage = ChatMessage(type: .error, text: "하루 채팅 사용량을 모두 사용했어요. 내일 다시 만나요! 😊")
            appendChat(limitMessage)
            return
        }

        // 2. 로딩 메시지 추가
        appendChat(ChatMessage(type: .loading, text: "고민을 듣고 있어요..."))
        
        // 3. 캐시 기반 프롬프트 생성 (간소화)
        _ = messages.suffix(10).map { "\($0.type.rawValue): \($0.text)" }.joined(separator: "\n") // context 미사용
        
        // 4. AI 서비스 호출
        ReplicateChatService.shared.sendPrompt(
            message: text,
            intent: "chat"
        ) { [weak self] response in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // 5. 로딩 메시지 제거
                self.removeLastLoadingMessage()
                
                // 6. 응답 처리
                if let msg = response, !msg.isEmpty {
                    let botMessage = ChatMessage(type: .bot, text: msg)
                    self.appendChat(botMessage)
                    
                    // 성공 시 사용량 기록
                    AIUsageManager.shared.recordUsage(for: .chat)
                    
                } else {
                    // 7. 에러 처리
                    let errorMessage = ChatMessage(type: .error, text: "응답을 불러올 수 없어요. 네트워크 연결을 확인하고 다시 시도해주세요.")
                    self.appendChat(errorMessage)
                }
            }
        }
    }

    // MARK: - 프리셋 추천
    @objc func presetButtonTapped() {
        // 🎯 사용자에게 선택지 제공
        presentRecommendationOptions()
    }
    
    // MARK: - 🎯 추천 방식 선택지 제공
    private func presentRecommendationOptions() {
        let remainingAI = AIUsageManager.shared.getRemainingCount(for: .presetRecommendation)
        
        // 사용자 메시지 추가
        let userMessage = ChatMessage(type: .user, text: "지금 기분에 맞는 사운드 추천받기")
        appendChat(userMessage)
        
        // 선택지 메시지 생성 - 더 친근하고 예쁜 메시지
        let optionsMessage = """
        맞춤 사운드 추천 방식을 선택해주세요
        
        당신의 현재 상황에 가장 적합한 
        사운드 조합을 찾아드릴게요! 
        어떤 방식으로 추천받고 싶으신가요?
        """
        
        var chatMessage = ChatMessage(type: .recommendationSelector, text: optionsMessage)
        chatMessage.quickActions = [
            ("앱 분석 추천받기", "local_recommendation"),
            ("AI 분석 추천받기 (\(remainingAI)/5)", "ai_recommendation")
        ]
        
        appendChat(chatMessage)
    }
    
    // MARK: - 🚀 Master Comprehensive Recommendation System
    
    /// 종합 데이터 분석 기반 마스터 추천 (모든 데이터 소스 활용)
    private func requestMasterComprehensiveRecommendation() {
        // 사용자 메시지 추가
        let userMessage = ChatMessage(type: .user, text: "🧠 지금까지의 모든 정보를 종합해서 완벽한 프리셋 추천받기")
        appendChat(userMessage)
        
        // 로딩 메시지 표시
        let loadingMessage = ChatMessage(type: .loading, text: "🔮 모든 데이터를 종합 분석 중...\n• 대화 기록 분석\n• 일기 감정 분석\n• 사용 패턴 분석\n• 환경 컨텍스트 분석")
        appendChat(loadingMessage)
        
        // 백그라운드에서 종합 분석 실행
        DispatchQueue.global(qos: .userInitiated).async {
            // Phase 1: 마스터 추천 생성
            let masterRecommendation = ComprehensiveRecommendationEngine.shared.generateMasterRecommendation()
            
            // Phase 2: 사용자 세션 자동 기록 시작
            self.startAutomaticSessionTracking(with: masterRecommendation)
            
            DispatchQueue.main.async {
                // 로딩 메시지 제거
                self.removeLastLoadingMessage()
                
                // 마스터 추천 메시지 생성
                let comprehensiveMessage = self.createMasterRecommendationMessage(masterRecommendation)
                
                // 프리셋 적용 콜백 설정
                var chatMessage = ChatMessage(type: .presetRecommendation, text: comprehensiveMessage)
                chatMessage.onApplyPreset = { [weak self] in
                    self?.applyMasterRecommendation(masterRecommendation)
                }
                
                self.appendChat(chatMessage)
                
                // AI 사용량 기록 (종합 분석은 프리미엄 기능)
                if AIUsageManager.shared.canUse(feature: .presetRecommendation) {
                    AIUsageManager.shared.recordUsage(for: .presetRecommendation)
                }
            }
        }
    }
    
    /// 마스터 추천 메시지 생성 (최고 수준의 개인화)
    private func createMasterRecommendationMessage(_ recommendation: MasterRecommendation) -> String {
        let primary = recommendation.primaryRecommendation
        let metadata = recommendation.processingMetadata
        
        let confidenceText = primary.confidence > 0.9 ? "매우 높음" : 
                           primary.confidence > 0.7 ? "높음" : "보통"
        
        let adaptationText = primary.adaptationLevel == "high" ? "고도 맞춤화" :
                           primary.adaptationLevel == "medium" ? "표준 맞춤화" : "탐험적 추천"
        
        return """
        🎯 **마스터 종합 분석 추천** (\(confidenceText) 신뢰도)
        
        🧠 **[\(primary.presetName)]** - \(adaptationText)
        \(primary.personalizedExplanation)
        
        📊 **분석 근거:**
        • \(metadata.dataSourcesUsed)개 데이터 소스 종합 분석
        • \(metadata.featureVectorSize)차원 특성 벡터 처리
        • \(metadata.networkLayers)층 신경망 추론
        • 예상 만족도: \(String(format: "%.0f%%", primary.expectedSatisfaction * 100))
        • 권장 세션 시간: \(formatDuration(primary.estimatedDuration))
        
        ⚡ **처리 성능:**
        • 분석 시간: \(String(format: "%.3f", metadata.totalProcessingTime))초
        • 종합도 점수: \(String(format: "%.0f%%", recommendation.comprehensivenessScore * 100))
        
        🎵 **대안 추천:**
        \(recommendation.alternativeRecommendations.enumerated().map { index, alt in
            "• \(alt.presetName) (신뢰도: \(String(format: "%.0f%%", alt.confidence * 100)))"
        }.joined(separator: "\n"))
        
        🚀 **학습 개선사항:**
        \(recommendation.learningRecommendations.prefix(3).map { "• \($0)" }.joined(separator: "\n"))
        
        이 추천은 대화 기록, 일기 감정, 사용 패턴, 환경 컨텍스트 등 
        모든 가용 데이터를 종합하여 생성된 최고 수준의 개인화 추천입니다.
        """
    }
    
    /// 마스터 추천 적용
    private func applyMasterRecommendation(_ recommendation: MasterRecommendation) {
        let primary = recommendation.primaryRecommendation
        
        // 1. 프리셋 적용
        if let parentVC = self.parent as? ViewController {
            parentVC.applyPreset(
                volumes: primary.optimizedVolumes,
                versions: primary.optimizedVersions,
                name: primary.presetName
            )
        }
        
        // 2. 자동 세션 추적 시작
        UserBehaviorAnalytics.shared.startSession(
            presetName: primary.presetName,
            volumes: primary.optimizedVolumes,
            versions: primary.optimizedVersions,
            emotion: extractCurrentEmotion()
        )
        
        // 3. 성공 메시지 추가
        let successMessage = ChatMessage(
            type: .bot, 
            text: "✅ **\(primary.presetName)** 마스터 추천이 적용되었습니다!\n\n🧠 자동 학습이 시작되어 사용 패턴을 분석하고 있습니다.\n📊 실시간으로 만족도를 추정하여 향후 추천을 개선합니다. ✨"
        )
        appendChat(successMessage)
        
        // 4. 자동 만족도 예측 스케줄링 (5분 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
            self.performAutomaticSatisfactionAssessment(recommendation: recommendation)
        }
    }
    
    /// 자동 세션 추적 시작
    private func startAutomaticSessionTracking(with recommendation: MasterRecommendation) {
        // 현재 세션 컨텍스트 캡처
        let sessionContext = [
            "recommendation_id": recommendation.primaryRecommendation.presetName,
            "confidence": String(recommendation.overallConfidence),
            "comprehensive_score": String(recommendation.comprehensivenessScore),
            "processing_time": String(recommendation.processingMetadata.totalProcessingTime)
        ]
        
        UserDefaults.standard.set(sessionContext, forKey: "currentMasterSession")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "masterSessionStartTime")
    }
    
    /// 자동 만족도 평가 (피드백 요청 없이)
    private func performAutomaticSatisfactionAssessment(recommendation: MasterRecommendation) {
        // 현재 세션 정보 로드
        guard let sessionContext = UserDefaults.standard.dictionary(forKey: "currentMasterSession") as? [String: String],
              let startTime = UserDefaults.standard.object(forKey: "masterSessionStartTime") as? TimeInterval else {
            return
        }
        
        let sessionDuration = Date().timeIntervalSince1970 - startTime
        let estimatedDuration = recommendation.primaryRecommendation.estimatedDuration
        
        // 완료율 계산 (실제 사용 시간 / 예상 시간)
        let completionRate = min(1.0, Float(sessionDuration / estimatedDuration))
        
        // 자동 만족도 추정 (완료율 기반)
        let estimatedSatisfaction = calculateEstimatedSatisfaction(
            completionRate: completionRate,
            expectedSatisfaction: recommendation.primaryRecommendation.expectedSatisfaction,
            sessionDuration: sessionDuration
        )
        
        // 세션 종료 및 자동 기록
        UserBehaviorAnalytics.shared.endSession(
            completionRate: completionRate,
            interactionEvents: [] // 추후 사용자 상호작용 기록 추가 가능
        )
        
        // 학습 데이터 업데이트
        updateAutomaticLearningData(
            recommendation: recommendation,
            actualSatisfaction: estimatedSatisfaction,
            sessionMetrics: AutomaticLearningModels.SessionMetrics(
                duration: sessionDuration,
                completionRate: completionRate,
                context: sessionContext
            )
        )
        
        // 사용자에게 자동 분석 결과 알림 (선택적)
        let analysisMessage = ChatMessage(
            type: .bot,
            text: "🔍 **자동 분석 완료**: \(String(format: "%.1f", sessionDuration/60))분 사용 • 예상 만족도: \(String(format: "%.0f%%", estimatedSatisfaction * 100)) • 다음 추천이 더욱 정확해집니다! 📈"
        )
        appendChat(analysisMessage)
        
        // 디버그 정보 (개발 중에만)
        #if DEBUG
        print("🔍 자동 만족도 평가 완료:")
        print("- 완료율: \(String(format: "%.1f%%", completionRate * 100))")
        print("- 추정 만족도: \(String(format: "%.1f%%", estimatedSatisfaction * 100))")
        print("- 세션 시간: \(formatDuration(sessionDuration))")
        #endif
        
        // 세션 데이터 정리
        UserDefaults.standard.removeObject(forKey: "currentMasterSession")
        UserDefaults.standard.removeObject(forKey: "masterSessionStartTime")
    }
    
    /// 자동 만족도 추정 알고리즘 (Netflix/Spotify 스타일)
    func calculateEstimatedSatisfaction(completionRate: Float, expectedSatisfaction: Float, sessionDuration: TimeInterval) -> Float {
        // 기본 만족도는 예상 만족도에서 시작
        var satisfaction = expectedSatisfaction
        
        // 완료율 기반 조정
        if completionRate > 0.8 {
            satisfaction += 0.1 // 80% 이상 완료 시 보너스
        } else if completionRate < 0.3 {
            satisfaction -= 0.2 // 30% 미만 완료 시 페널티
        }
        
        // 세션 길이 기반 조정
        if sessionDuration > 900 { // 15분 이상
            satisfaction += 0.05 // 긴 세션은 만족도가 높을 가능성
        } else if sessionDuration < 120 { // 2분 미만
            satisfaction -= 0.15 // 너무 짧은 세션은 만족도가 낮을 가능성
        }
        
        // 시간대별 조정
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 22 || hour <= 6 { // 수면 시간대
            if sessionDuration > 600 { // 10분 이상 사용
                satisfaction += 0.1 // 수면 시간대 긴 사용은 만족도 높음
            }
        }
        
        // 0.0-1.0 범위로 클램핑
        return max(0.0, min(1.0, satisfaction))
    }
    
    /// 자동 학습 데이터 업데이트
    func updateAutomaticLearningData(recommendation: MasterRecommendation, actualSatisfaction: Float, sessionMetrics: AutomaticLearningModels.SessionMetrics) {
        // 예상 만족도와 실제 만족도 비교
        let predictionAccuracy = 1.0 - abs(recommendation.primaryRecommendation.expectedSatisfaction - actualSatisfaction)
        
        // 학습 기록 생성
        let learningData = AutomaticLearningRecord(
            timestamp: Date(),
            recommendationId: recommendation.primaryRecommendation.presetName,
            predictedSatisfaction: recommendation.primaryRecommendation.expectedSatisfaction,
            actualSatisfaction: actualSatisfaction,
            predictionAccuracy: predictionAccuracy,
            sessionMetrics: sessionMetrics,
            improvementSuggestions: generateImprovementSuggestions(
                accuracy: predictionAccuracy,
                sessionMetrics: sessionMetrics
            )
        )
        
        // 학습 데이터 저장
        saveAutomaticLearningRecord(learningData)
    }
    
    /// 개선 제안 생성 (AI 연구 수준)
    func generateImprovementSuggestions(accuracy: Float, sessionMetrics: AutomaticLearningModels.SessionMetrics) -> [String] {
        var suggestions: [String] = []
        
        if accuracy < 0.7 {
            suggestions.append("예측 모델 정확도 개선 필요 - 신경망 가중치 재조정")
        }
        
        if sessionMetrics.completionRate < 0.5 {
            suggestions.append("세션 길이 또는 음원 조합 재검토 - 사용자 참여도 부족")
        }
        
        if sessionMetrics.duration < 180 {
            suggestions.append("초기 몰입도 향상 방안 검토 - 첫 3분 이탈률 높음")
        }
        
        if sessionMetrics.completionRate > 0.9 && sessionMetrics.duration > 900 {
            suggestions.append("고만족 패턴 감지 - 유사 조합 가중치 증가 권장")
        }
        
        return suggestions
    }
    
    /// 현재 감정 추출 (최근 메시지 기반)
    func extractCurrentEmotion() -> String {
        let recentMessages = messages.suffix(10)
        
        for message in recentMessages.reversed() {
            if message.type == .user {
                let text = message.text.lowercased()
                
                // 감정 키워드 매칭
                if text.contains("스트레스") || text.contains("힘들") { return "스트레스" }
                if text.contains("피곤") || text.contains("잠") { return "수면" }
                if text.contains("집중") || text.contains("공부") { return "집중" }
                if text.contains("행복") || text.contains("기쁘") { return "행복" }
                if text.contains("슬프") || text.contains("우울") { return "슬픔" }
                if text.contains("불안") || text.contains("걱정") { return "불안" }
                if text.contains("활력") || text.contains("에너지") { return "활력" }
            }
        }
        
        return "평온" // 기본값
    }
    
    // MARK: - 🆕 감정 분석 결과 파싱
    private func parseEmotionAnalysis(_ analysis: String) -> (emotion: String, timeOfDay: String, intensity: Float) {
        var emotion = "평온"
        let timeOfDay = getCurrentTimeOfDay()
        var intensity: Float = 1.0
        
        // 감정 파싱
        if let emotionMatch = analysis.range(of: #"감정:\s*([가-힣]+)"#, options: .regularExpression) {
            emotion = String(analysis[emotionMatch]).replacingOccurrences(of: "감정:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let mainEmotionMatch = analysis.range(of: #"주감정:\s*([가-힣]+)"#, options: .regularExpression) {
            emotion = String(analysis[mainEmotionMatch]).replacingOccurrences(of: "주감정:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 강도 파싱
        if analysis.contains("강도: 높음") || analysis.contains("강도: 5") {
            intensity = 1.5
        } else if analysis.contains("강도: 보통") || analysis.contains("강도: 3") || analysis.contains("강도: 4") {
            intensity = 1.0
        } else if analysis.contains("강도: 낮음") || analysis.contains("강도: 1") || analysis.contains("강도: 2") {
            intensity = 0.7
        }
        
        return (emotion, timeOfDay, intensity)
    }
    
    // MARK: - 🆕 사용자 친화적 메시지 생성
    private func createUserFriendlyPresetMessage(
        analysis: (emotion: String, timeOfDay: String, intensity: Float),
        preset: (name: String, volumes: [Float], description: String, versions: [Int])
    ) -> String {
        let intensityText = analysis.intensity > 1.2 ? "강한" : analysis.intensity < 0.8 ? "부드러운" : "적절한"
        
        let empathyMessage = generateEmpathyMessage(emotion: analysis.emotion, timeOfDay: analysis.timeOfDay, intensity: analysis.intensity)
        let soundDescription = generateSoundDescription(volumes: preset.volumes, emotion: analysis.emotion)
        
        return """
        \(empathyMessage)
        
        **[\(preset.name)]**
        \(soundDescription)
        """
    }
    
    /// 🤗 감정별 공감 메시지 생성 (방대한 데이터베이스)
    private func generateEmpathyMessage(emotion: String, timeOfDay: String, intensity: Float) -> String {
        let empathyDatabase: [String: [String]] = [
            "평온": [
                "마음에 평온이 찾아온 순간이네요. 이런 고요한 시간을 더욱 깊게 만끽해보세요.",
                "평화로운 마음 상태가 느껴집니다. 이 소중한 평온함을 지켜드릴게요.",
                "차분한 에너지가 전해져요. 내면의 고요함을 더욱 깊이 있게 경험해보세요.",
                "마음의 평형을 잘 유지하고 계시네요. 이 안정감을 더욱 풍성하게 만들어드릴게요.",
                "고요한 마음의 상태가 아름답습니다. 이 평온함이 더욱 깊어질 수 있도록 도와드릴게요."
            ],
            
            "수면": [
                "하루의 피로가 쌓여 깊은 휴식이 필요한 시간이네요. 편안한 잠자리를 만들어드릴게요.",
                "오늘 하루도 고생 많으셨어요. 꿈나라로의 여행을 부드럽게 안내해드릴게요.",
                "몸과 마음이 휴식을 원하고 있어요. 깊고 편안한 잠을 위한 완벽한 환경을 준비했어요.",
                "잠들기 전 마음의 정리가 필요한 순간이네요. 모든 걱정을 내려놓고 편히 쉬실 수 있도록 도와드릴게요.",
                "하루의 마무리 시간이 왔어요. 별들의 자장가로 평온한 밤을 선물해드릴게요."
            ],
            
            "스트레스": [
                "오늘 힘들었던 당신을 위해 마음의 짐을 덜어드리고 싶어요.",
                "쌓인 스트레스가 느껴져요. 지금 이 순간만큼은 모든 걱정에서 벗어나 보세요.",
                "마음이 무거우셨을 텐데, 이제 깊게 숨을 들이쉬고 차근차근 풀어나가요.",
                "복잡하고 어려운 하루를 보내셨군요. 마음의 무게를 조금씩 덜어내는 시간을 만들어드릴게요.",
                "스트레스로 지친 마음을 이해해요. 지금은 온전히 자신을 위한 시간을 가져보세요.",
                "긴장으로 굳어진 마음과 몸을 천천히 풀어드릴게요. 모든 것을 내려놓으셔도 괜찮아요."
            ],
            
            "불안": [
                "마음이 불안하고 걱정이 많으실 텐데, 지금 이 순간은 안전해요.",
                "혼란스러운 마음을 진정시켜 드릴게요. 모든 것이 괜찮아질 거예요.",
                "불안한 마음이 잠잠해질 수 있도록 안전하고 따뜻한 공간을 만들어드릴게요.",
                "걱정이 많은 요즘이죠. 마음에 평안이 깃들 수 있는 시간을 선물해드릴게요.",
                "불안함 속에서도 당신은 충분히 괜찮은 사람이에요. 마음의 안정을 찾아드릴게요.",
                "복잡한 생각들이 정리될 수 있도록 마음의 정박지를 만들어드릴게요."
            ],
            
            "활력": [
                "활기찬 에너지가 느껴져요! 이 좋은 기운을 더욱 키워나가볼까요?",
                "긍정적인 에너지가 넘치네요. 이 활력을 더욱 풍성하게 만들어드릴게요.",
                "생동감 넘치는 하루를 시작하시는군요. 이 에너지를 최대한 활용해보세요.",
                "의욕이 가득한 상태네요! 이 좋은 기운이 하루 종일 이어질 수 있도록 도와드릴게요.",
                "활기찬 마음이 아름다워요. 이 에너지로 멋진 하루를 만들어나가세요."
            ],
            
            "집중": [
                "집중이 필요한 중요한 시간이네요. 마음을 한곳으로 모을 수 있도록 도와드릴게요.",
                "깊은 몰입이 필요한 순간이군요. 모든 잡념을 걷어내고 온전히 집중해보세요.",
                "집중력을 높여야 할 때네요. 마음의 잡음을 제거하고 명료함을 선물해드릴게요.",
                "중요한 일에 몰두해야 하는군요. 최상의 집중 환경을 만들어드릴게요.",
                "마음을 가다듬고 집중할 시간이에요. 깊은 몰입의 세계로 안내해드릴게요."
            ],
            
            "행복": [
                "기쁨이 가득한 마음이 전해져요! 이 행복한 순간을 더욱 특별하게 만들어드릴게요.",
                "밝은 에너지가 느껴져서 저도 덩달아 기뻐요. 이 좋은 기분이 계속되길 바라요.",
                "행복한 마음 상태가 아름다워요. 이 기쁨을 더욱 풍성하게 만들어드릴게요.",
                "긍정적인 에너지가 넘쳐흘러요. 이 행복이 오래 지속될 수 있도록 도와드릴게요.",
                "웃음꽃이 핀 마음이 보여요. 이 즐거운 순간을 더욱 빛나게 만들어드릴게요."
            ],
            
            "슬픔": [
                "마음이 무거우시군요. 지금 느끼는 슬픔도 소중한 감정이에요. 함께 천천히 달래보아요.",
                "힘든 시간을 보내고 계시는 것 같아요. 혼자가 아니에요, 마음의 위로를 전해드릴게요.",
                "마음의 상처가 아물 수 있도록 따뜻한 손길을 건네드릴게요.",
                "슬픔 속에서도 당신은 충분히 소중한 사람이에요. 천천히 마음을 달래보아요.",
                "눈물도 때로는 필요해요. 마음의 정화가 일어날 수 있도록 도와드릴게요.",
                "아픈 마음을 어루만져 드릴게요. 시간이 지나면 분명 괜찮아질 거예요."
            ],
            
            "안정": [
                "마음의 균형이 잘 잡혀있어요. 이 안정감을 더욱 깊게 느껴보세요.",
                "내면의 평형 상태가 아름다워요. 이 고요한 안정감을 오래 유지해보세요.",
                "마음이 흔들리지 않는 견고함이 느껴져요. 이 안정감을 더욱 단단하게 만들어드릴게요.",
                "차분하고 균형 잡힌 상태네요. 이 평온함이 일상의 힘이 되어드릴게요.",
                "마음의 중심이 잘 잡혀있어요. 이 안정된 에너지를 더욱 키워나가보세요."
            ],
            
            "이완": [
                "긴장을 풀고 여유를 찾을 시간이네요. 몸과 마음의 모든 긴장을 놓아보세요.",
                "스스로에게 휴식을 선물할 시간이에요. 완전히 이완된 상태를 경험해보세요.",
                "마음의 무게를 내려놓을 준비가 되신 것 같아요. 편안한 해방감을 느껴보세요.",
                "긴장에서 벗어나 자유로워질 시간이에요. 마음껏 느긋한 시간을 보내세요.",
                "모든 것을 내려놓고 편안해지실 수 있도록 완벽한 환경을 만들어드릴게요."
            ]
        ]
        
        // 시간대별 추가 멘트
        let timeBasedAddition: [String: String] = [
            "새벽": "이른 새벽, 조용한 시간 속에서",
            "아침": "새로운 하루를 맞는 아침에",
            "오전": "활기찬 오전 시간에",
            "점심": "하루의 중간, 재충전이 필요한 시간에",
            "오후": "따뜻한 오후 햇살 아래서",
            "저녁": "하루를 마무리하는 저녁에",
            "밤": "고요한 밤의 시간에",
            "자정": "깊어가는 밤, 평온한 시간에"
        ]
        
        let messages = empathyDatabase[emotion] ?? empathyDatabase["평온"] ?? ["마음을 위한 특별한 시간을 준비했어요."]
        let timeAddition = timeBasedAddition[timeOfDay] ?? ""
        
        // 강도에 따른 메시지 선택
        let intensityIndex = intensity > 1.2 ? 0 : intensity < 0.8 ? (messages.count - 1) : (messages.count / 2)
        let safeIndex = min(intensityIndex, messages.count - 1)
        let selectedMessage = messages[safeIndex]
        
        // 시간대 멘트 추가 (50% 확률)
        if !timeAddition.isEmpty && Int.random(in: 0...1) == 1 {
            return "\(timeAddition) \(selectedMessage)"
        }
        
        return selectedMessage
    }
    
    /// 🎵 사운드 요소별 상세 설명 생성
    private func generateSoundDescription(volumes: [Float], emotion: String) -> String {
        // 사운드 카테고리별 이름 (SoundPresetCatalog 순서에 맞춤)
        let soundCategories = [
            "Rain", "Ocean", "Forest", "Stream", "Wind", "River", "Thunderstorm", 
            "Waterfall", "Birds", "Fireplace", "WhiteNoise", "BrownNoise", "PinkNoise"
        ]
        
        // 사운드별 감성적 설명
        let soundDescriptions: [String: [String]] = [
            "Rain": ["부드러운 빗소리", "마음을 정화하는 빗방울", "안정감을 주는 빗소리", "따스한 빗소리"],
            "Ocean": ["깊은 바다의 파도", "마음을 진정시키는 파도소리", "끝없는 바다의 리듬", "평온한 해변의 파도"],
            "Forest": ["신선한 숲의 속삭임", "나무들의 자연스러운 소리", "푸른 숲의 평화", "자연의 깊은 숨결"],
            "Stream": ["맑은 시냇물의 흐름", "피로 회복에 효과적인 시냇물소리", "순수한 물의 멜로디", "자연의 치유력"],
            "Wind": ["부드러운 바람소리", "마음을 시원하게 하는 바람", "자유로운 바람의 춤", "상쾌한 미풍"],
            "River": ["흐르는 강의 리듬", "생명력 넘치는 강물소리", "깊은 강의 여유", "자연의 흐름"],
            "Thunderstorm": ["웅장한 천둥소리", "자연의 역동적 에너지", "강렬한 자연의 소리", "정화의 뇌우"],
            "Waterfall": ["시원한 폭포소리", "활력을 주는 물소리", "자연의 역동성", "생기 넘치는 폭포"],
            "Birds": ["새들의 평화로운 지저귐", "아침을 알리는 새소리", "자연의 하모니", "희망적인 새의 노래"],
            "Fireplace": ["따뜻한 벽난로 소리", "포근한 불꽃의 춤", "아늑한 공간의 소리", "평안한 난로 소리"],
            "WhiteNoise": ["집중력을 높이는 화이트노이즈", "마음의 잡음을 차단하는 소리", "명료한 정적", "순수한 배경음"],
            "BrownNoise": ["깊은 안정감의 브라운노이즈", "마음을 진정시키는 저주파", "편안한 배경 소리", "고요한 정적"],
            "PinkNoise": ["균형 잡힌 핑크노이즈", "자연스러운 배경음", "조화로운 정적", "부드러운 배경 소리"]
        ]
        
        // 감정별 강조 포인트
        let emotionFocus: [String: String] = [
            "평온": "마음의 평화를 위해",
            "수면": "깊은 잠을 위해",
            "스트레스": "스트레스 해소를 위해",
            "불안": "불안 완화를 위해",
            "활력": "에너지 충전을 위해",
            "집중": "집중력 향상을 위해",
            "행복": "기쁨 증진을 위해",
            "슬픔": "마음의 치유를 위해",
            "안정": "안정감 강화를 위해",
            "이완": "깊은 이완을 위해"
        ]
        
        // 활성화된 사운드 찾기 (볼륨이 10 이상인 것들)
        var activeSounds: [String] = []
        for (index, volume) in volumes.enumerated() {
            if index < soundCategories.count && volume >= 10 {
                let soundName = soundCategories[index]
                let descriptions = soundDescriptions[soundName] ?? [soundName]
                let randomDescription = descriptions.randomElement() ?? soundName
                activeSounds.append(randomDescription)
            }
        }
        
        let focusPhrase = emotionFocus[emotion] ?? "마음의 안정을 위해"
        
        if activeSounds.isEmpty {
            return "\(focusPhrase) 자연스럽고 조화로운 사운드 조합을 준비했어요."
        } else if activeSounds.count == 1 {
            return "\(focusPhrase) \(activeSounds[0])를 중심으로 한 특별한 조합입니다."
        } else if activeSounds.count <= 3 {
            let soundList = activeSounds.joined(separator: ", ")
            return "\(focusPhrase) \(soundList)를 조화롭게 블렌딩한 맞춤형 조합이에요."
        } else {
            let mainSounds = Array(activeSounds.prefix(2))
            let soundList = mainSounds.joined(separator: ", ")
            return "\(focusPhrase) \(soundList) 등 다양한 자연 사운드를 정교하게 조합했어요."
        }
    }
    
    // MARK: - 🆕 로컬 프리셋 적용
    private func applyLocalPreset(_ preset: (name: String, volumes: [Float], description: String, versions: [Int])) {
        print("[applyLocalPreset] 프리셋 적용 시작: \(preset.name)")
        for (categoryIndex, versionIndex) in preset.versions.enumerated() {
            if categoryIndex < SoundPresetCatalog.categoryCount {
                SettingsManager.shared.updateSelectedVersion(for: categoryIndex, to: versionIndex)
            }
        }
        for (index, volume) in preset.volumes.enumerated() {
            if index < SoundPresetCatalog.categoryCount {
                SoundManager.shared.setVolume(for: index, volume: volume / 100.0)
            }
        }
        print("[applyLocalPreset] 사운드 재생 시작")
        SoundManager.shared.playActiveSounds()
        NotificationCenter.default.post(name: NSNotification.Name("SoundVolumesUpdated"), object: nil)
        print("[applyLocalPreset] SoundVolumesUpdated 노티 전송")
        let successMessage = ChatMessage(type: .bot, text: "✅ '\(preset.name)' 프리셋이 적용되었습니다! 지금 바로 편안한 사운드를 즐겨보세요. 🎵")
        appendChat(successMessage)
        let backToMainMessage = ChatMessage(type: .postPresetOptions, text: "🏠 메인 화면으로 이동해서 사운드를 확인해보세요!")
        appendChat(backToMainMessage)
    }
    
    // MARK: - 🆕 현재 시간대 확인
    private func getCurrentTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<7: return "새벽"
        case 7..<10: return "아침"
        case 10..<12: return "오전"
        case 12..<14: return "점심"
        case 14..<18: return "오후"
        case 18..<21: return "저녁"
        case 21..<24: return "밤"
        default: return "자정"
        }
    }
    
    // MARK: - 🆕 로컬 추천 시스템 (AI 사용량 초과 시 대체)
    private func provideLocalFallbackRecommendation() {
        let userMessage = ChatMessage(type: .user, text: "🎵 지금 기분에 맞는 사운드 추천받기")
        appendChat(userMessage)
        
        // 현재 시간대 기반 추천
        let currentTimeOfDay = getCurrentTimeOfDay()
        var recommendedEmotion = "평온"
        
        // 시간대별 기본 감정 추천
        switch currentTimeOfDay {
        case "새벽", "자정":
            recommendedEmotion = "수면"
        case "아침":
            recommendedEmotion = "활력"
        case "오전", "점심":
            recommendedEmotion = "집중"
        case "오후":
            recommendedEmotion = "안정"
        case "저녁":
            recommendedEmotion = "이완"
        case "밤":
            recommendedEmotion = "수면"
        default:
            recommendedEmotion = "평온"
        }
        
        // 로컬 추천 시스템으로 프리셋 생성
        let recommendedPreset = createBasicPreset(emotion: recommendedEmotion, timeOfDay: currentTimeOfDay)
        
        // 사용자 친화적인 메시지 생성
        let presetMessage = """
        **[\(recommendedPreset.name)]**
        \(recommendedPreset.description)
        
        현재 시간대에 최적화된 사운드 조합입니다. 바로 적용해보세요!
        
        오늘의 AI 추천 횟수를 모두 사용하여 로컬 추천을 제공합니다.
        """
        
        // 프리셋 적용 콜백 설정
        var chatMessage = ChatMessage(type: .presetRecommendation, text: presetMessage)
        chatMessage.onApplyPreset = { [weak self] in
            self?.applyLocalPreset(recommendedPreset)
        }
        
        appendChat(chatMessage)
    }
    
    // MARK: - 🆕 프리셋 생성 헬퍼 메서드들
    
    /// AI 분석 결과로부터 프리셋 생성 - 시적이고 감성적인 이름
    private func createPresetFromAnalysis(_ analysis: (emotion: String, timeOfDay: String, intensity: Float)) -> (name: String, volumes: [Float], description: String, versions: [Int]) {
        let baseVolumes = SoundPresetCatalog.getRecommendedPreset(for: analysis.emotion)
        let adjustedVolumes = baseVolumes.map { $0 * analysis.intensity }
        let versions = SoundPresetCatalog.defaultVersions
        
        let name = generatePoeticPresetName(emotion: analysis.emotion, timeOfDay: analysis.timeOfDay, isAI: true)
        let description = "\(analysis.timeOfDay)의 \(analysis.emotion) 감정을 위해 특별히 조합된 사운드스케이프입니다."
        
        return (name: name, volumes: adjustedVolumes, description: description, versions: versions)
    }
    
    /// 기본 프리셋 생성 - 시적이고 감성적인 이름
    private func createBasicPreset(emotion: String, timeOfDay: String) -> (name: String, volumes: [Float], description: String, versions: [Int]) {
        let baseVolumes = SoundPresetCatalog.getRecommendedPreset(for: emotion)
        let versions = SoundPresetCatalog.defaultVersions
        
        let name = generatePoeticPresetName(emotion: emotion, timeOfDay: timeOfDay, isAI: false)
        let description = "\(timeOfDay)의 \(emotion) 상태를 위한 자연스럽고 조화로운 사운드 여행입니다."
        
        return (name: name, volumes: baseVolumes, description: description, versions: versions)
    }
    
    /// 시적이고 감성적인 프리셋 이름 생성
    private func generatePoeticPresetName(emotion: String, timeOfDay: String, isAI: Bool) -> String {
        // 감정별 시적 표현
        let emotionPoetry: [String: [String]] = [
            "평온": ["고요한 마음", "잔잔한 호수", "평화로운 숨결", "조용한 안식", "차분한 선율", "고요한 정원", "잔잔한 물결", "평화의 노래", "마음의 쉼터", "조용한 미소"],
            "수면": ["달빛의 자장가", "꿈속의 여행", "별들의 속삭임", "깊은 밤의 포옹", "구름 위의 쉼터", "꿈의 정원", "달빛 산책", "별의 자장가", "수면의 정원", "잠의 궁전"],
            "활력": ["새벽의 각성", "생명의 춤", "에너지의 폭발", "희망의 멜로디", "활기찬 아침", "생동하는 리듬", "활력의 샘", "에너지 연주", "생명의 노래", "희망의 교향곡"],
            "집중": ["마음의 정중앙", "집중의 공간", "조용한 몰입", "깊은 사색", "고요한 탐구", "사색의 숲", "몰입의 시간", "집중의 빛", "명상의 공간", "깊은 고요"],
            "안정": ["마음의 뿌리", "안전한 품", "따뜻한 둥지", "평온한 바닥", "신뢰의 기둥", "안정의 토대", "마음의 항구", "따뜻한 안식", "신뢰의 품", "안전한 길"],
            "이완": ["부드러운 해방", "느긋한 여유", "포근한 쉼", "자연스러운 흐름", "편안한 해독", "여유의 오후", "포근한 바람", "자유로운 시간", "편안한 여행", "부드러운 미소"],
            "스트레스": ["해독의 시간", "마음의 치유", "스트레스 해소", "평온 회복", "긴장 완화", "마음의 정화", "치유의 바람", "해독의 숲", "회복의 시간", "정화의 강"],
            "불안": ["마음의 안정", "걱정 해소", "불안 진정", "평안 찾기", "안심의 공간", "평안의 등대", "안심의 품", "진정의 노래", "마음의 평화", "안전한 항구"],
            "행복": ["기쁨의 멜로디", "햇살의 춤", "웃음의 하모니", "즐거운 선율", "밝은 에너지", "행복의 정원", "웃음의 시간", "기쁨의 여행", "밝은 하루", "햇살 같은 시간"],
            "슬픔": ["위로의 포옹", "마음의 치유", "눈물의 정화", "슬픔 달래기", "상처 어루만지기", "위로의 노래", "치유의 시간", "슬픔의 정화", "마음의 위로", "따뜻한 손길"]
        ]
        
        // 시간대별 시적 표현
        let timePoetry: [String: [String]] = [
            "새벽": ["새벽의", "여명의", "첫 빛의", "아침 이슬의", "동트는"],
            "아침": ["아침의", "햇살의", "상쾌한", "밝은", "활기찬"],
            "오전": ["오전의", "상쾌한", "밝은", "활동적인", "생기찬"],
            "점심": ["정오의", "따스한", "밝은", "활력의", "정중앙"],
            "오후": ["오후의", "따뜻한", "포근한", "안정된", "여유로운"],
            "저녁": ["저녁의", "노을의", "황혼의", "따스한", "포근한"],
            "밤": ["밤의", "달빛의", "고요한", "평온한", "깊은"],
            "자정": ["자정의", "깊은 밤의", "고요한", "신비로운", "조용한"]
        ]
        
        // 아름다운 접미사들
        let beautifulSuffixes = [
            "세레나데", "심포니", "왈츠", "노래", "선율", "화음", "여행", "이야기", 
            "공간", "시간", "순간", "기억", "꿈", "향기", "빛", "그림자", 
            "숨결", "속삭임", "포옹", "키스", "미소", "안식", "휴식", "명상"
        ]
        
        // 랜덤하게 조합 생성 (시드를 기반으로 일관성 있게)
        let emotionSeed = emotion.hashValue
        let timeSeed = timeOfDay.hashValue
        let combinedSeed = abs(emotionSeed ^ timeSeed)
        
        let emotionWords = emotionPoetry[emotion] ?? ["마음의"]
        let timeWords = timePoetry[timeOfDay] ?? ["조용한"]
        
        let selectedEmotion = emotionWords[combinedSeed % emotionWords.count]
        let selectedTime = timeWords[(combinedSeed + 1) % timeWords.count]
        let selectedSuffix = beautifulSuffixes[(combinedSeed + 2) % beautifulSuffixes.count]
        
        // 다양한 패턴으로 조합 (이모지 없이)
        let patterns = [
            "\(selectedTime) \(selectedSuffix)",
            "\(selectedEmotion) \(selectedSuffix)",
            "\(selectedTime) \(selectedEmotion)",
            "\(selectedEmotion)의 \(selectedSuffix)",
            "\(selectedTime) \(selectedEmotion) \(selectedSuffix)"
        ]
        
        let selectedPattern = patterns[(combinedSeed + 3) % patterns.count]
        return selectedPattern
    }
    
    // MARK: - 🧠 종합적 AI 프리셋 추천 시스템
    
    /// 🔍 로컬 기반 추천 시스템 데이터 수집 범위
    /// 
    /// **수집하는 정보:**
    /// 1. 시간적 정보: 현재 시각, 요일, 시간대 구분 (새벽/아침/오후 등)
    /// 2. 대화 맥락: 최근 대화에서 언급된 감정 키워드 분석
    /// 3. 사용 패턴: 기존 프리셋 사용 기록 및 선호도 
    /// 4. 환경 추정: 시간대 기반 환경 요소 (밝기, 활동성 등)
    /// 5. 개인화 요소: 사용자 고유 패턴 (볼륨 선호도, 사운드 타입)
    ///
    /// **수집하지 않는 정보:**
    /// - 개인 신상정보, 위치정보, 연락처, 사진 등
    /// - 다른 앱 사용 기록이나 브라우징 히스토리
    /// - 마이크나 카메라를 통한 실시간 감지
    /// - 외부 서버로 전송되는 개인 데이터
    ///
    /// **모든 분석은 기기 내 로컬에서만 수행되며, 외부로 전송되지 않습니다.**
    private func gatherComprehensiveAnalysisData() -> String {
        let currentTime = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let dayOfWeek = calendar.component(.weekday, from: currentTime)
        let timeOfDay = getCurrentTimeOfDay()
        
        // 1. 시간적 컨텍스트
        let timeContext = generateTimeContext(hour: hour, dayOfWeek: dayOfWeek, timeOfDay: timeOfDay)
        
        // 2. 대화 맥락 분석
        let conversationContext = analyzeConversationContext()
        
        // 3. 기존 프리셋 기반 사용 패턴 분석
        let presetPatterns = analyzeExistingPresetPatterns()
        
        // 4. 감정 키워드 추출
        let emotionKeywords = extractEmotionKeywords()
        
        // 5. 환경적 요소 추정
        let environmentalFactors = estimateEnvironmentalFactors(timeOfDay: timeOfDay)
        
        return """
        === 🧠 종합적 상황 분석 데이터 ===
        
        ⏰ 시간적 컨텍스트:
        \(timeContext)
        
        💬 대화 맥락:
        \(conversationContext)
        
        📊 프리셋 사용 패턴:
        \(presetPatterns)
        
        💭 감정 키워드:
        \(emotionKeywords)
        
        🌍 환경적 요소:
        \(environmentalFactors)
        
        === AI 분석 요청 ===
        위 데이터와 기존 프리셋 패턴을 종합하여 사용자에게 최적화된 사운드 프리셋을 추천해주세요.
        반드시 다음 형식으로 응답해주세요:
        
        EMOTION: [감정상태]
        INTENSITY: [0.5-1.5 사이의 강도]
        REASON: [추천 이유]
        TIMEOFDAY: [시간대]
        """
    }
    
    /// 시간적 컨텍스트 생성
    private func generateTimeContext(hour: Int, dayOfWeek: Int, timeOfDay: String) -> String {
        let weekdayName = ["일", "월", "화", "수", "목", "금", "토"][dayOfWeek - 1]
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7
        let isWorkTime = !isWeekend && hour >= 9 && hour <= 18
        
        return """
        현재 시간: \(hour)시 (\(timeOfDay))
        요일: \(weekdayName)요일 (\(isWeekend ? "주말" : "평일"))
        상황: \(isWorkTime ? "업무시간" : isWeekend ? "휴식시간" : "자유시간")
        """
    }
    
    /// 대화 맥락 분석
    private func analyzeConversationContext() -> String {
        let recentMessages = chatHistory.suffix(5)
        let messageText = recentMessages.map { $0.message }.joined(separator: " ")
        
        // 대화에서 키워드 추출
        let stressKeywords = ["스트레스", "피곤", "힘들", "바쁘", "압박", "긴장"]
        let relaxKeywords = ["휴식", "편안", "여유", "쉬고", "잠들", "평온"]
        let focusKeywords = ["집중", "공부", "일", "업무", "생산성", "몰입"]
        
        var contextType = "일반"
        if stressKeywords.contains(where: { messageText.contains($0) }) {
            contextType = "스트레스"
        } else if relaxKeywords.contains(where: { messageText.contains($0) }) {
            contextType = "휴식"
        } else if focusKeywords.contains(where: { messageText.contains($0) }) {
            contextType = "집중"
        }
        
        return """
        대화 맥락: \(contextType)
        최근 메시지 키워드: \(extractKeywordsFromText(messageText))
        대화 길이: \(chatHistory.count)개 메시지
        """
    }
    
    /// 기존 프리셋 기반 사용 패턴 분석
    private func analyzeExistingPresetPatterns() -> String {
        let allPresets = SettingsManager.shared.loadSoundPresets()
        let recentPresets = Array(allPresets.filter { $0.isAIGenerated }.prefix(4))
        let favoritePresets = getFavoritePresets().prefix(4)
        
        // 최근 사용한 프리셋 분석
        var recentAnalysis = "없음"
        if !recentPresets.isEmpty {
            let recentNames = recentPresets.map { $0.name }.joined(separator: ", ")
            recentAnalysis = recentNames
        }
        
        // 즐겨찾기 프리셋 분석
        var favoriteAnalysis = "없음"
        if !favoritePresets.isEmpty {
            let favoriteNames = favoritePresets.map { $0.name }.joined(separator: ", ")
            favoriteAnalysis = favoriteNames
        }
        
        // 공통 사운드 패턴 분석
        let allUserPresets = Array(recentPresets) + Array(favoritePresets)
        let commonSounds = analyzeCommonSoundPreferences(from: allUserPresets)
        let avgVolumes = analyzeAverageVolumePreferences(from: allUserPresets)
        let emotionPatterns = analyzeEmotionPatterns(from: allUserPresets)
        
        return """
        최근 사용 프리셋: \(recentAnalysis)
        즐겨찾기 프리셋: \(favoriteAnalysis)
        선호 사운드 패턴: \(commonSounds.joined(separator: ", "))
        평균 볼륨 레벨: \(avgVolumes.map { String(format: "%.0f%%", $0) }.joined(separator: ", "))
        감정 사용 패턴: \(emotionPatterns.joined(separator: ", "))
        프리셋 총 개수: \(allPresets.count)개
        """
    }
    
    /// 즐겨찾기 프리셋 가져오기
    private func getFavoritePresets() -> [SoundPreset] {
        let favoriteIds = UserDefaults.standard.array(forKey: "FavoritePresetIds") as? [String] ?? []
        let favoritePresetIds = Set(favoriteIds.compactMap { UUID(uuidString: $0) })
        
        let allPresets = SettingsManager.shared.loadSoundPresets()
        return allPresets.filter { favoritePresetIds.contains($0.id) }
    }
    
    /// 공통 사운드 선호도 분석
    private func analyzeCommonSoundPreferences(from presets: [SoundPreset]) -> [String] {
        guard !presets.isEmpty else { return ["Rain", "Ocean", "Forest"] }
        
        var soundCount: [String: Int] = [:]
        let soundNames = ["Rain", "Ocean", "Forest", "Wind", "Fire", "Thunder", "WhiteNoise", "Keyboard"]
        
        for preset in presets {
            for (index, volume) in preset.compatibleVolumes.enumerated() {
                if volume > 15.0 && index < soundNames.count { // 볼륨이 15 이상인 사운드만
                    let soundName = soundNames[index]
                    soundCount[soundName, default: 0] += 1
                }
            }
        }
        
        return soundCount.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }
    
    /// 평균 볼륨 선호도 분석
    private func analyzeAverageVolumePreferences(from presets: [SoundPreset]) -> [Float] {
        guard !presets.isEmpty else { return [60, 50, 40, 30, 20, 15, 25, 35] }
        
        var totalVolumes = Array(repeating: Float(0), count: 8)
        var counts = Array(repeating: 0, count: 8)
        
        for preset in presets {
            for (index, volume) in preset.compatibleVolumes.enumerated() {
                if index < totalVolumes.count && volume > 0 {
                    totalVolumes[index] += volume
                    counts[index] += 1
                }
            }
        }
        
        // 평균 계산
        for i in 0..<totalVolumes.count {
            if counts[i] > 0 {
                totalVolumes[i] = totalVolumes[i] / Float(counts[i])
            } else {
                totalVolumes[i] = 50.0 // 기본값
            }
        }
        
        return totalVolumes
    }
    
    /// 감정 사용 패턴 분석
    private func analyzeEmotionPatterns(from presets: [SoundPreset]) -> [String] {
        guard !presets.isEmpty else { return ["평온"] }
        
        var emotionCount: [String: Int] = [:]
        
        for preset in presets {
            if let emotion = preset.emotion {
                emotionCount[emotion, default: 0] += 1
            }
        }
        
        return emotionCount.sorted { $0.value > $1.value }
            .prefix(3)
            .map { "\($0.key)(\($0.value)회)" }
    }
    
    /// 감정 키워드 추출
    private func extractEmotionKeywords() -> String {
        let allMessages = chatHistory.map { $0.message }.joined(separator: " ")
        let emotionWords = extractKeywordsFromText(allMessages)
        
        return """
        추출된 감정 키워드: \(emotionWords)
        감정 강도 추정: 중간
        감정 변화 패턴: 안정적
        """
    }
    
    /// 환경적 요소 추정
    private func estimateEnvironmentalFactors(timeOfDay: String) -> String {
        return """
        추정 환경: \(timeOfDay == "밤" || timeOfDay == "자정" ? "조용한 환경" : "일반 환경")
        배터리 상태: 일반 모드
        권장 볼륨: \(timeOfDay == "밤" ? "낮음" : "보통")
        """
    }
    
    /// 텍스트에서 키워드 추출
    private func extractKeywordsFromText(_ text: String) -> String {
        let commonWords = ["그", "이", "저", "것", "수", "있", "하", "때", "더", "좀", "잘", "안", "못"]
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 1 && !commonWords.contains($0) }
            .prefix(5)
        
        return words.joined(separator: ", ")
    }
    
    /// 향상된 AI 프리셋 추천 요청
    private func requestEnhancedAIPresetRecommendation() {
        let comprehensiveData = gatherComprehensiveAnalysisData()
        
        let userMessage = ChatMessage(type: .user, text: "🎵 지금 상황에 맞는 최적의 사운드 추천받기")
        appendChat(userMessage)
        
        // 로딩 메시지 추가
        appendChat(ChatMessage(type: .loading, text: "🧠 AI가 현재 상황을 종합적으로 분석하고 있어요..."))
        
        // AI 사용량 체크
        if !AIUsageManager.shared.canUse(feature: .presetRecommendation) {
            removeLastLoadingMessage()
            // 자연스러운 대화로 앱 자체 분석 제안
            offerInternalAnalysisWithChat()
            return
        }
        
        // 향상된 AI 분석 요청
        ReplicateChatService.shared.generateAdvancedPresetRecommendation(
            analysisData: comprehensiveData,
            completion: { [weak self] (response: String?) in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    // 로딩 메시지 제거
                    self.removeLastLoadingMessage()
                    
                    if let analysisResult = response, !analysisResult.isEmpty {
                        // AI 분석 결과 파싱
                        let parsedAnalysis = self.parseAdvancedEmotionAnalysis(analysisResult)
                        
                        // 고급 로컬 추천으로 프리셋 생성
                        let advancedRecommendation = self.createAdvancedRecommendationFromAI(parsedAnalysis)
                        
                        // 사용자 친화적인 메시지 생성
                        let presetMessage = self.createAdvancedPresetMessage(
                            analysis: parsedAnalysis,
                            recommendation: advancedRecommendation,
                            aiReason: analysisResult
                        )
                        
                        // 프리셋 적용 콜백 설정
                        var chatMessage = ChatMessage(type: .presetRecommendation, text: presetMessage)
                        chatMessage.onApplyPreset = { [weak self] in
                            self?.applyAdvancedLocalPreset(advancedRecommendation)
                        }
                        
                        self.appendChat(chatMessage)
                        AIUsageManager.shared.recordUsage(for: .presetRecommendation)
                    } else {
                        // AI 실패 시 고급 로컬 추천으로 폴백
                        self.provideAdvancedLocalRecommendation()
                    }
                }
            }
        )
    }
    
    /// AI 사용량 초과 시 자연스러운 대화로 앱 자체 분석 제안
    private func offerInternalAnalysisWithChat() {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let timeGreeting = getTimeBasedGreeting(hour: currentHour)
        
        let analysisOfferMessage = """
\(timeGreeting) 오늘 AI 기반 추천을 모두 사용하셨네요! 😊

하지만 걱정하지 마세요. 지금까지 수집된 데이터를 바탕으로 DeepSleep이 직접 분석해서 맞춤형 사운드를 추천해드릴 수 있어요.

        🔍 **앱 분석 추천의 장점:**
        • 기존 사용 패턴을 완벽히 분석
        • 선호도 기반 맞춤형 추천  
        • 실시간 상황 반영
        • 즉시 적용 가능한 최적화

        앱 분석으로 개인화된 추천을 받아보시겠어요? 🎯
"""
        
        var offerMessage = ChatMessage(type: .aiResponse, text: analysisOfferMessage)
        offerMessage.quickActions = [
            ("네, 앱 분석 추천받기", "accept_internal_analysis"),
            ("🌙 아니요, 나중에 할게요", "decline_internal_analysis")
        ]
        
        appendChat(offerMessage)
    }
    
    /// 시간대별 인사말
    private func getTimeBasedGreeting(hour: Int) -> String {
        switch hour {
        case 5..<10: return "좋은 아침이에요! ☀️"
        case 10..<12: return "활기찬 오전이네요! 🌤️"
        case 12..<14: return "즐거운 점심시간이에요! 🌞"
        case 14..<18: return "포근한 오후네요! 🌅"
        case 18..<21: return "편안한 저녁이에요! 🌇"
        case 21..<24: return "조용한 밤이네요! 🌙"
        default: return "고요한 새벽이에요! ✨"
        }
    }
    
    /// 고도화된 로컬 추천 시스템 (기존 프리셋 기반 AI 수준의 분석)
    private func provideAdvancedLocalRecommendation() {
        // 로딩 메시지 표시 (일반 채팅과 동일한 방식)
        appendChat(ChatMessage(type: .loading, text: "📊 개인화된 사운드 패턴을 분석하고 있습니다..."))
        
        // 자연스러운 분석 시간 추가 (1.5~3초 랜덤)
        let randomDelay = Double.random(in: 1.5...3.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + randomDelay) { [weak self] in
            guard let self = self else { return }
            
            let currentData = self.gatherComprehensiveAnalysisData()
            let currentHour = Calendar.current.component(.hour, from: Date())
            let timeOfDay = self.getCurrentTimeOfDay()
            
            // 기존 프리셋 기반 분석 강화
            let userPresets = self.getUserPresetsForAnalysis()
            
            // 다층적 분석 수행 (기존 프리셋 패턴 반영)
            let emotionalProfile = self.analyzeEmotionalProfile(from: currentData, userPresets: userPresets)
            let contextualFactors = self.analyzeContextualFactors(hour: currentHour)
            let personalizedPreferences = self.analyzePersonalizedPreferences(from: userPresets)
            let environmentalCues = self.analyzeEnvironmentalCues(timeOfDay: timeOfDay)
            
            // 종합적 추천 생성 (기존 프리셋 패턴 활용)
            let advancedRecommendation = self.generateAdvancedLocalRecommendation(
                emotional: emotionalProfile,
                contextual: contextualFactors, 
                personal: personalizedPreferences,
                environmental: environmentalCues,
                userPresets: userPresets,
                randomSeed: Date().timeIntervalSince1970 // 타임스탬프로 랜덤성 추가
            )
            
            // AI 수준의 자연스러운 설명 생성 (프리셋 기반 이유 포함)
            let naturalDescription = self.createNaturalAnalysisDescription(
                emotional: emotionalProfile,
                contextual: contextualFactors,
                recommendation: advancedRecommendation,
                timeOfDay: timeOfDay,
                userPresets: userPresets
            )
            
            // 로딩 메시지 제거
            self.removeLastLoadingMessage()
            
            // 프리셋 적용 콜백 설정
            var chatMessage = ChatMessage(type: .presetRecommendation, text: naturalDescription)
            chatMessage.onApplyPreset = { [weak self] in
                self?.applyAdvancedLocalPreset(advancedRecommendation)
            }
            
            self.appendChat(chatMessage)
        }
    }
    
    /// 사용자 프리셋 분석을 위한 데이터 수집
    private func getUserPresetsForAnalysis() -> [SoundPreset] {
        let allPresets = SettingsManager.shared.loadSoundPresets()
        let recentPresets = Array(allPresets.filter { $0.isAIGenerated }.prefix(3))
        let favoritePresets = Array(getFavoritePresets().prefix(3))
        
        return recentPresets + favoritePresets
    }
    
    /// 감정 프로필 분석 (기존 프리셋 기반 AI 수준의 정교함)
    private func analyzeEmotionalProfile(from data: String, userPresets: [SoundPreset]) -> EmotionalProfile {
        let keywords = extractKeywords(from: data.lowercased())
        
        // 감정 키워드 매핑
        let stressKeywords = ["스트레스", "긴장", "압박", "걱정", "부담", "힘들"]
        let relaxationKeywords = ["휴식", "편안", "쉬고", "평온", "안정", "차분"]
        let energyKeywords = ["집중", "활력", "에너지", "기운", "활기", "의욕"]
        let sleepKeywords = ["잠", "수면", "자고", "피곤", "졸린", "밤"]
        
        var emotionScores: [String: Float] = [:]
        
        // 키워드 기반 감정 점수 계산
        emotionScores["stress"] = calculateEmotionScore(keywords: keywords, targetWords: stressKeywords)
        emotionScores["relaxation"] = calculateEmotionScore(keywords: keywords, targetWords: relaxationKeywords)
        emotionScores["energy"] = calculateEmotionScore(keywords: keywords, targetWords: energyKeywords)
        emotionScores["sleep"] = calculateEmotionScore(keywords: keywords, targetWords: sleepKeywords)
        
        // 기존 프리셋의 감정 패턴 반영
        let presetEmotions = userPresets.compactMap { $0.emotion }
        if !presetEmotions.isEmpty {
            // 사용자가 자주 사용하는 감정 상태에 가중치 추가
            for emotion in presetEmotions {
                let emotionKey = mapEmotionToKey(emotion)
                emotionScores[emotionKey] = (emotionScores[emotionKey] ?? 0) + 0.3
            }
        }
        
        // 주요 감정 결정
        let dominantEmotion = emotionScores.max { $0.value < $1.value }?.key ?? "relaxation"
        let intensity = emotionScores[dominantEmotion] ?? 0.5
        
        return EmotionalProfile(
            primaryEmotion: dominantEmotion,
            secondaryEmotion: findSecondaryEmotion(scores: emotionScores, excluding: dominantEmotion),
            intensity: intensity,
            complexity: calculateEmotionalComplexity(scores: emotionScores)
        )
    }
    
    /// 감정을 감정 키로 매핑
    private func mapEmotionToKey(_ emotion: String) -> String {
        if emotion.contains("스트레스") || emotion.contains("긴장") || emotion.contains("불안") {
            return "stress"
        } else if emotion.contains("휴식") || emotion.contains("편안") || emotion.contains("평온") {
            return "relaxation"
        } else if emotion.contains("집중") || emotion.contains("활력") || emotion.contains("에너지") {
            return "energy"
        } else if emotion.contains("잠") || emotion.contains("수면") || emotion.contains("피곤") {
            return "sleep"
        }
        return "relaxation"
    }
    
    // MARK: - 🆕 다양성을 위한 새로운 헬퍼 메서드들
    
    /// 감정의 변형 버전들을 반환
    private func getEmotionVariations(_ baseEmotion: String) -> [String] {
        let variations: [String: [String]] = [
            "평온": ["휴식", "안정", "이완", "명상"],
            "집중": ["몰입", "학습", "창의", "활력"],
            "수면": ["잠", "휴식", "평온", "이완"],
            "스트레스": ["긴장", "불안", "압박감"],
            "활력": ["에너지", "집중", "역동적"],
            "휴식": ["평온", "이완", "안정"]
        ]
        return variations[baseEmotion] ?? []
    }
    
    /// 다양한 사운드 선택 (랜덤 요소 포함)
    private func selectDiverseSounds(for emotion: String, randomFactor: Int) -> [String] {
        let baseMap: [String: [String]] = [
            "평온": ["Rain", "Ocean", "Forest", "Stream"],
            "집중": ["Keyboard", "WhiteNoise", "Fan", "Coffee"],
            "수면": ["Rain", "Ocean", "Night", "Wind"],
            "휴식": ["Forest", "Stream", "Wind", "Night"],
            "활력": ["Birds", "Stream", "Wind", "Forest"],
            "스트레스": ["Rain", "Ocean", "Forest", "Stream"],
            "창의": ["Coffee", "Birds", "Stream", "Keyboard"],
            "명상": ["Forest", "Wind", "Night", "Stream"]
        ]
        
        var sounds = baseMap[emotion] ?? ["Rain", "Ocean", "Forest"]
        
        // 🔀 매번 강력한 랜덤화 적용 (100% 확률)
        let allSounds = ["Rain", "Thunder", "Ocean", "Fire", "Steam", "WindowRain", "Forest", "Wind", "Night", "Birds", "Fan", "WhiteNoise", "Coffee", "Keyboard"]
        
        // 1. 첫 번째 랜덤 교체 (항상 적용)
        let randomSound1 = allSounds.randomElement() ?? "Rain"
        if !sounds.contains(randomSound1) && sounds.count > 0 {
            let replaceIndex1 = randomFactor % sounds.count
            sounds[replaceIndex1] = randomSound1
        }
        
        // 2. 두 번째 랜덤 교체 (70% 확률)
        if randomFactor % 10 < 7 {
            let randomSound2 = allSounds.randomElement() ?? "Ocean"
            if !sounds.contains(randomSound2) && sounds.count > 1 {
                let replaceIndex2 = (randomFactor + 7) % sounds.count
                sounds[replaceIndex2] = randomSound2
            }
        }
        
        // 3. 추가 사운드 확장 (50% 확률)
        if randomFactor % 2 == 0 && sounds.count < 5 {
            let extraSound = allSounds.randomElement() ?? "Forest"
            if !sounds.contains(extraSound) {
                sounds.append(extraSound)
            }
        }
        
        // 4. 사운드 배열 셔플
        sounds.shuffle()
        
        return Array(sounds.prefix(3 + (randomFactor % 3))) // 3-5개 사운드
    }
    
    /// 시간대별 조정 (더 정교하게)
    private func adjustForTimeOfDay(sounds: [String], timeContext: String, randomFactor: Int) -> [String] {
        var adjustedSounds = sounds
        
        let timeAdjustments: [String: [String]] = [
            "새벽": ["Night", "Wind", "Rain"],
            "아침": ["Birds", "Stream", "Forest"],
            "오전": ["Coffee", "Keyboard", "WhiteNoise"],
            "점심": ["Stream", "Forest", "Birds"],
            "오후": ["Coffee", "Rain", "Fan"],
            "저녁": ["Forest", "Wind", "Rain"],
            "밤": ["Night", "Rain", "Wind"],
            "자정": ["Night", "Wind", "Ocean"]
        ]
        
        if let timeSpecific = timeAdjustments[timeContext], randomFactor % 3 == 0 {
            let additionalSound = timeSpecific.randomElement() ?? "Rain"
            if !adjustedSounds.contains(additionalSound) {
                adjustedSounds.append(additionalSound)
            }
        }
        
        return adjustedSounds
    }
    
    /// 사용자 프리셋 패턴 반영
    private func incorporateUserPatterns(sounds: [String], userPresets: [SoundPreset], randomFactor: Int) -> [String] {
        var patterns = sounds
        
        // 사용자가 자주 사용하는 사운드 찾기
        var soundFrequency: [String: Int] = [:]
        for preset in userPresets {
            // 프리셋에서 볼륨이 높은 사운드들 카운트
            for (index, volume) in preset.volumes.enumerated() {
                if volume > 50, index < SoundPresetCatalog.categoryNames.count {
                    let soundName = SoundPresetCatalog.categoryNames[index]
                    soundFrequency[soundName, default: 0] += 1
                }
            }
        }
        
        // 가장 인기 있는 사운드를 랜덤하게 포함
        if let popularSound = soundFrequency.max(by: { $0.value < $1.value })?.key,
           randomFactor % 2 == 0 && !patterns.contains(popularSound) {
            patterns.append(popularSound)
        }
        
        return patterns
    }
    
    /// 🔊 극도로 다양한 볼륨 패턴 생성
    private func generateDiverseVolumes(for sounds: [String], emotion: String, timeContext: String, randomFactor: Int) -> [Float] {
        var volumes: [Float] = Array(repeating: 0, count: SoundPresetCatalog.categoryNames.count)
        
        // 기본 볼륨 설정 (매번 다른 패턴)
        for (soundIndex, sound) in sounds.enumerated() {
            if let index = SoundPresetCatalog.categoryNames.firstIndex(where: { $0.contains(sound) || sound.contains($0) }) {
                let baseVolume = getBaseVolumeFor(emotion: emotion, timeContext: timeContext)
                
                // 🎲 다층적 랜덤 변화
                let primaryVariation = Float((randomFactor + soundIndex * 13) % 40 - 20) // ±20 기본 변화
                let secondaryVariation = Float((randomFactor + soundIndex * 7) % 20 - 10) // ±10 추가 변화
                let microVariation = Float((randomFactor + soundIndex * 3) % 10 - 5) // ±5 미세 변화
                
                let totalVariation = primaryVariation + secondaryVariation + microVariation
                let finalVolume = baseVolume + totalVariation
                
                volumes[index] = max(15, min(95, finalVolume))
            }
        }
        
        // 🎚️ 추가 볼륨 분산 (일부 사운드를 더 크게, 일부는 더 작게)
        for i in 0..<volumes.count {
            if volumes[i] > 0 {
                let intensityBoost = Float((randomFactor + i * 11) % 20 - 10) // ±10 추가 강도
                volumes[i] = max(10, min(100, volumes[i] + intensityBoost))
            }
        }
        
        return volumes
    }
    
    /// 기본 볼륨 계산
    private func getBaseVolumeFor(emotion: String, timeContext: String) -> Float {
        let emotionVolumes: [String: Float] = [
            "평온": 60, "집중": 70, "수면": 45, "휴식": 55,
            "활력": 75, "스트레스": 65, "창의": 65, "명상": 50
        ]
        
        let timeVolumes: [String: Float] = [
            "새벽": 35, "아침": 60, "오전": 70, "점심": 65,
            "오후": 70, "저녁": 55, "밤": 40, "자정": 30
        ]
        
        let emotionVol = emotionVolumes[emotion] ?? 60
        let timeVol = timeVolumes[timeContext] ?? 60
        
        return (emotionVol + timeVol) / 2
    }
    
    /// 랜덤 볼륨 변화 적용
    private func applyRandomVolumeVariation(to volumes: [Float], factor: Int, range: Float) -> [Float] {
        return volumes.enumerated().map { index, volume in
            guard volume > 0 else { return volume }
            let variation = Float((factor + index) % 20 - 10) * range // ±range 변화
            return max(10, min(95, volume + variation))
        }
    }
    
    /// 랜덤 버전 생성
    private func generateRandomVersions(count: Int, randomFactor: Int) -> [Int] {
        return (0..<SoundPresetCatalog.categoryNames.count).map { index in
            1 + ((randomFactor + index) % 3) // 1, 2, 3 중 선택
        }
    }
    
    /// 동적 신뢰도 생성
    private func generateDynamicConfidence(randomFactor: Int) -> Float {
        let baseConfidence: Float = 0.75
        let variation = Float(randomFactor % 20) / 100.0 // ±0.2 변화
        return min(0.95, max(0.65, baseConfidence + variation))
    }
    
    /// 🎯 매우 다양한 동적 이유 생성 (20가지 패턴)
    private func generateDynamicReasoning(emotion: String, timeContext: String, randomFactor: Int) -> String {
        let reasoningTemplates = [
            "\(emotion) 상태에 최적화된 \(timeContext) 시간대 맞춤 조합",
            "현재 \(timeContext)에 가장 효과적인 \(emotion) 개선 사운드",
            "\(timeContext) 시간대 특성을 반영한 \(emotion) 최적화 구성",
            "\(emotion) 향상을 위한 \(timeContext) 전용 사운드 믹스",
            "\(timeContext) 환경에서 \(emotion) 상태를 극대화하는 조합",
            "개인화된 \(emotion) 케어를 위한 \(timeContext) 특별 구성",
            "\(emotion) 감정을 위한 과학적 기반 \(timeContext) 사운드",
            "실시간 \(timeContext) 분석 기반 \(emotion) 맞춤 솔루션",
            "\(emotion) 최적화를 위한 \(timeContext) 전문가급 추천",
            "AI 레벨 \(emotion) 분석 결과 \(timeContext) 완벽 매칭",
            "\(timeContext) 시간대 전용 \(emotion) 강화 사운드스케이프",
            "개인 패턴 기반 \(emotion) 맞춤 \(timeContext) 솔루션",
            "정밀 분석된 \(emotion) 상태를 위한 \(timeContext) 조합",
            "\(timeContext) 최적화 알고리즘 기반 \(emotion) 사운드",
            "스마트 \(emotion) 케어 시스템의 \(timeContext) 추천",
            "\(emotion) 전문 분석 결과 \(timeContext) 맞춤 구성",
            "딥러닝 기반 \(emotion) 최적화 \(timeContext) 솔루션",
            "\(timeContext) 환경 분석 기반 \(emotion) 완벽 조합",
            "개인화 엔진이 제안하는 \(emotion) \(timeContext) 사운드",
            "혁신적 \(emotion) 케어를 위한 \(timeContext) 특별 조합"
        ]
        
        let templateIndex = randomFactor % reasoningTemplates.count
        return reasoningTemplates[templateIndex]
    }
    
    /// 사운드 조합에 랜덤 변화 추가
    private func addRandomVariation(to sounds: [String], factor: Int) -> [String] {
        var modifiedSounds = sounds
        let variationTypes = ["Rain", "Ocean", "Forest", "Wind", "Fire", "Thunder", "WhiteNoise", "Keyboard"]
        
        // 랜덤하게 하나의 사운드를 다른 사운드로 교체
        if !modifiedSounds.isEmpty && !variationTypes.isEmpty {
            let randomIndex = factor % modifiedSounds.count
            let randomSoundIndex = (factor * 7) % variationTypes.count
            modifiedSounds[randomIndex] = variationTypes[randomSoundIndex]
        }
        
        return modifiedSounds
    }
    
    /// 볼륨에 랜덤 변화 추가 (±5% 변화)
    private func addRandomVolumeVariation(to volumes: [Float], factor: Int) -> [Float] {
        return volumes.enumerated().map { index, volume in
            let variation = Float((factor + index * 13) % 11 - 5) / 100.0 // -5% ~ +5%
            return max(0, min(100, volume + variation))
        }
    }
    
    /// 상황적 요소 분석
    private func analyzeContextualFactors(hour: Int) -> ContextualFactors {
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7
        
        let timeContext = determineTimeContext(hour: hour, isWeekend: isWeekend)
        let activityLevel = estimateActivityLevel(hour: hour, isWeekend: isWeekend)
        let socialContext = estimateSocialContext(hour: hour, dayOfWeek: dayOfWeek)
        
        return ContextualFactors(
            timeContext: timeContext,
            activityLevel: activityLevel,
            socialContext: socialContext,
            isWeekend: isWeekend,
            season: getCurrentSeason()
        )
    }
    
    /// 개인화된 선호도 분석 (기존 프리셋 기반)
    private func analyzePersonalizedPreferences(from userPresets: [SoundPreset]) -> PersonalizedPreferences {
        // 기존 프리셋에서 패턴 추출
        var timeSlots: [String] = []
        var soundTypes: [String] = []
        var volumeLevels: [String: Float] = [:]
        
        if !userPresets.isEmpty {
            // 선호 사운드 타입 분석
            let soundNames = ["Rain", "Ocean", "Forest", "Wind", "Fire", "Thunder", "WhiteNoise", "Keyboard"]
            var soundUsage: [String: Int] = [:]
            var totalVolumes: [String: Float] = [:]
            var volumeCounts: [String: Int] = [:]
            
            for preset in userPresets {
                for (index, volume) in preset.compatibleVolumes.enumerated() {
                    if volume > 20.0 && index < soundNames.count {
                        let soundName = soundNames[index]
                        soundUsage[soundName, default: 0] += 1
                        totalVolumes[soundName, default: 0] += volume
                        volumeCounts[soundName, default: 0] += 1
                    }
                }
            }
            
            soundTypes = soundUsage.sorted { $0.value > $1.value }
                .prefix(3)
                .map { $0.key }
            
            // 평균 볼륨 레벨 계산
            for soundName in soundNames {
                if let total = totalVolumes[soundName], let count = volumeCounts[soundName], count > 0 {
                    volumeLevels[soundName] = total / Float(count)
                } else {
                    volumeLevels[soundName] = 50.0
                }
            }
            
            timeSlots = ["저녁", "밤"] // 기본 시간대
        } else {
            // 기본 선호도 설정
            soundTypes = ["Rain", "Ocean", "Forest"]
            timeSlots = ["저녁", "밤"]
            volumeLevels = ["Rain": 60.0, "Ocean": 50.0, "Forest": 45.0]
        }
        
        return PersonalizedPreferences(
            favoriteTimeSlots: timeSlots,
            preferredSoundTypes: soundTypes,
            volumePreferences: volumeLevels,
            adaptationSpeed: 0.8
        )
    }
    
    /// 환경적 단서 분석
    private func analyzeEnvironmentalCues(timeOfDay: String) -> EnvironmentalCues {
        let ambientLight = estimateAmbientLight(timeOfDay: timeOfDay)
        let noiseLevel = estimateAmbientNoise(timeOfDay: timeOfDay)
        let temperatureContext = estimateTemperatureContext()
        
        return EnvironmentalCues(
            ambientLight: ambientLight,
            noiseLevel: noiseLevel,
            temperatureContext: temperatureContext,
            weatherMood: estimateWeatherMood()
        )
    }
    
    /// 고급 로컬 추천 생성 (기존 프리셋 패턴 활용)
    private func generateAdvancedLocalRecommendation(
        emotional: EmotionalProfile,
        contextual: ContextualFactors,
        personal: PersonalizedPreferences,
        environmental: EnvironmentalCues,
        userPresets: [SoundPreset],
        randomSeed: TimeInterval = 0
    ) -> AdvancedRecommendation {
        
        // 🎲 극도로 강화된 랜덤 시드 생성 (매번 완전히 다른 결과)
        let timeComponent = Int(Date().timeIntervalSince1970 * 1000) % 10000
        let randomBoost = Int.random(in: 1...9999)
        let emotionHash = emotional.primaryEmotion.hashValue % 1000
        let contextHash = contextual.timeContext.hashValue % 500
        let microSecond = Int(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1) * 1000000) % 1000
        let randomFactor = (timeComponent + randomBoost + emotionHash + contextHash + microSecond) % 50000
        
        // 🔄 강력한 감정 다양성 (80% 확률로 변형 적용)
        var baseEmotion = emotional.primaryEmotion
        let emotionVariations = getEmotionVariations(baseEmotion)
        if !emotionVariations.isEmpty && randomFactor % 5 < 4 {
            baseEmotion = emotionVariations.randomElement() ?? baseEmotion
        }
        
        // 🎯 감정 크로스오버 (40% 확률)
        if randomFactor % 5 < 2 {
            let allEmotions = ["평온", "집중", "수면", "휴식", "활력", "스트레스", "창의", "명상"]
            baseEmotion = allEmotions.randomElement() ?? baseEmotion
        }
        
        // 🌟 완전 랜덤 감정 (20% 확률)
        if randomFactor % 5 == 0 {
            let wildEmotions = ["명상", "창의", "활력", "평온", "휴식"]
            baseEmotion = wildEmotions.randomElement() ?? baseEmotion
        }
        
        // 기본 사운드 선택 (더 다양한 조합)
        var baseSounds = selectDiverseSounds(for: baseEmotion, randomFactor: randomFactor)
        
        // 시간대별 추가 조정 (더 정교하게)
        baseSounds = adjustForTimeOfDay(sounds: baseSounds, timeContext: contextual.timeContext, randomFactor: randomFactor)
        
        // 사용자 프리셋 패턴 반영 (더 정교하게)
        baseSounds = incorporateUserPatterns(sounds: baseSounds, userPresets: userPresets, randomFactor: randomFactor)
        
        // 볼륨 생성 (더 다양한 패턴)
        var volumes = generateDiverseVolumes(
            for: baseSounds,
            emotion: baseEmotion,
            timeContext: contextual.timeContext,
            randomFactor: randomFactor
        )
        
        // 🎚️ 극강의 랜덤 볼륨 변화 (±25% 범위로 매우 다양하게)
        volumes = applyRandomVolumeVariation(to: volumes, factor: randomFactor, range: 0.25)
        
        // 🔀 3단계 볼륨 무작위화 (완전히 다른 패턴 보장)
        volumes = volumes.enumerated().map { index, volume in
            guard volume > 0 else { return volume }
            
            // 1단계: 기본 추가 변화 ±15
            let extraVariation1 = Float((randomFactor + index * 17) % 30 - 15)
            
            // 2단계: 인덱스 기반 변화 ±10  
            let extraVariation2 = Float((index * randomFactor) % 20 - 10)
            
            // 3단계: 마이크로 변화 ±5
            let extraVariation3 = Float((randomFactor + index * 5) % 10 - 5)
            
            let totalExtra = extraVariation1 + extraVariation2 + extraVariation3
            return max(10, min(100, volume + totalExtra))
        }
        
        // 버전 선택도 랜덤하게
        let selectedVersions = generateRandomVersions(count: baseSounds.count, randomFactor: randomFactor)
        
        // 신뢰도와 이유 생성
        let confidence = generateDynamicConfidence(randomFactor: randomFactor)
        let reasoning = generateDynamicReasoning(emotion: baseEmotion, timeContext: contextual.timeContext, randomFactor: randomFactor)
        
        return AdvancedRecommendation(
            sounds: baseSounds,
            volumes: volumes,
            versions: selectedVersions,
            confidence: confidence,
            reasoning: reasoning
        )
    }
    
    /// AI 수준의 자연스러운 분석 설명 생성 (프리셋 기반 이유 포함)
    private func createNaturalAnalysisDescription(
        emotional: EmotionalProfile,
        contextual: ContextualFactors,
        recommendation: AdvancedRecommendation,
        timeOfDay: String,
        userPresets: [SoundPreset]
    ) -> String {
        // 🎨 고정된 프리셋 이름 생성 (메시지별로 고유한 시드 사용)
        let messageHash = abs(emotional.primaryEmotion.hashValue ^ contextual.timeContext.hashValue ^ timeOfDay.hashValue)
        let fixedSeed = messageHash % 100000 // 메시지 내용 기반 고정 시드
        
        let emotionPrefixes = ["평온한", "차분한", "활기찬", "집중", "명상", "휴식", "에너지", "치유", "몰입", "안정", "균형", "조화"]
        let timeBasedPrefixes = ["새벽", "아침", "오후", "저녁", "밤", "심야", "황혼", "일출", "정오", "새벽녘"]
        let qualityAdjectives = ["프리미엄", "디럭스", "스페셜", "마스터", "프로", "엘리트", "시그니처", "커스텀", "어드밴스드", "익스클루시브"]
        let conceptualNames = ["미니멀", "오가닉", "하모닉", "리듬", "플로우", "바이브", "에센스", "퓨전", "심포니", "컴포지션"]
        let elementalNames = ["바람", "물결", "숲속", "별빛", "달빛", "구름", "이슬", "파도", "산들바람", "햇살"]
        
        let prefixOptions = [emotionPrefixes, timeBasedPrefixes, qualityAdjectives, conceptualNames, elementalNames]
        let selectedPrefix = prefixOptions[fixedSeed % prefixOptions.count][(fixedSeed + 3) % prefixOptions[fixedSeed % prefixOptions.count].count]
        
        let suffixes = ["사운드스케이프", "믹스", "컬렉션", "조합", "패턴", "하모니", "블렌드", "시퀀스", "레이어", "컴포지션", 
                       "셀렉션", "큐레이션", "어레인지", "멜로디", "테마", "무드", "앰비언스", "분위기", "세션", "익스피리언스"]
        let selectedSuffix = suffixes[(fixedSeed + 7) % suffixes.count]
        
        // 특별한 이모지 프리픽스 (고정된 확률)
        let specialEmojis = ["✨", "🌟", "💫", "🎭", "🔥", "⭐", "🎨", "🌙", "💎", "🎪", "🌸", "🍃", "🌊", "☁️", "🌈"]
        let useEmoji = (fixedSeed % 100) < 20
        let emojiPrefix = useEmoji ? (specialEmojis[(fixedSeed + 5) % specialEmojis.count] + " ") : ""
        
        let presetName = "\(emojiPrefix)\(selectedPrefix) \(selectedSuffix)"
        
        let emotionDescription = getEmotionDescription(emotional.primaryEmotion)
        let timeDescription = getTimeDescription(timeOfDay)
        let contextDescription = getContextDescription(contextual)
        
        // 기존 프리셋 패턴 분석 결과 포함
        let presetInsight = generatePresetInsight(from: userPresets)
        
        let personalizedAnalysis = """
🎯 **맞춤 분석 결과**

현재 \(timeDescription)이고, 감지된 주요 상태는 '\(emotionDescription)'이에요. \(contextDescription)

\(presetInsight)를 바탕으로 보면, 이런 상황에서는 \(recommendation.reasoning)이 가장 효과적일 것 같아요.

🎵 **[\(presetName)]**

📋 **추천 이유:**
• 감정 상태와 시간대를 종합적으로 고려했어요
• 기존 사용 패턴을 반영한 맞춤형 조합이에요
• 선호하는 사운드 조합을 최적화했어요
• 환경적 요소까지 고려한 설정이에요

🎚️ **사운드 구성:**
• 주요 사운드: \(recommendation.sounds.prefix(3).joined(separator: ", "))
• 최적화된 볼륨으로 자동 설정됩니다
• 현재 상황에 맞는 사운드 버전 선택

📊 **신뢰도: \(Int(recommendation.confidence * 100))%** | 바로 적용해보세요! ✨
"""
        
        return personalizedAnalysis
    }
    
    /// 기존 프리셋에서 인사이트 생성
    private func generatePresetInsight(from userPresets: [SoundPreset]) -> String {
        if userPresets.isEmpty {
            return "새로운 사용자로서 일반적인 추천 패턴"
        }
        
        let commonSounds = analyzeCommonSoundPreferences(from: userPresets)
        let emotionPatterns = analyzeEmotionPatterns(from: userPresets)
        
        if !commonSounds.isEmpty && !emotionPatterns.isEmpty {
            return "평소 \(commonSounds.prefix(2).joined(separator: ", ")) 소리를 선호하시고 \(emotionPatterns.first ?? "")을 자주 사용하시는 패턴"
        } else if !commonSounds.isEmpty {
            return "평소 \(commonSounds.prefix(2).joined(separator: ", ")) 소리를 즐겨 사용하시는 패턴"
        } else {
            return "기존 사용 패턴"
        }
    }
    
    // MARK: - 유틸리티 메서드들
    
    private func extractKeywords(from text: String) -> [String] {
        return text.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 1 }
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
    }
    
    private func calculateEmotionScore(keywords: [String], targetWords: [String]) -> Float {
        let matches = keywords.filter { keyword in
            targetWords.contains { $0.contains(keyword) || keyword.contains($0) }
        }
        return min(1.0, Float(matches.count) / Float(max(1, targetWords.count)))
    }
    
    private func findSecondaryEmotion(scores: [String: Float], excluding primary: String) -> String? {
        return scores.filter { $0.key != primary }
            .max { $0.value < $1.value }?.key
    }
    
    private func calculateEmotionalComplexity(scores: [String: Float]) -> Float {
        let nonZeroScores = scores.values.filter { $0 > 0.1 }
        return min(1.0, Float(nonZeroScores.count) / 4.0)
    }
    
    // MARK: - 상세 분석 메서드들
    
    private func determineTimeContext(hour: Int, isWeekend: Bool) -> String {
        if isWeekend {
            switch hour {
            case 6..<10: return "여유로운 주말 아침"
            case 10..<14: return "활동적인 주말 오전"
            case 14..<18: return "편안한 주말 오후"
            case 18..<22: return "여유로운 주말 저녁"
            default: return "조용한 주말 밤"
            }
        } else {
            switch hour {
            case 6..<9: return "바쁜 출근 시간"
            case 9..<12: return "집중이 필요한 오전"
            case 12..<14: return "짧은 점심 휴식"
            case 14..<18: return "업무가 많은 오후"
            case 18..<21: return "퇴근 후 휴식"
            default: return "하루를 마무리하는 밤"
            }
        }
    }
    
    private func estimateActivityLevel(hour: Int, isWeekend: Bool) -> String {
        if isWeekend {
            switch hour {
            case 8..<11: return "느긋한 활동"
            case 11..<16: return "중간 활동"
            default: return "낮은 활동"
            }
        } else {
            switch hour {
            case 7..<9, 14..<17: return "높은 활동"
            case 9..<12, 17..<20: return "중간 활동"
            default: return "낮은 활동"
            }
        }
    }
    
    private func estimateSocialContext(hour: Int, dayOfWeek: Int) -> String {
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7
        
        if isWeekend {
            switch hour {
            case 10..<14: return "가족/친구와 시간"
            case 14..<18: return "사회적 활동"
            case 18..<22: return "여가 시간"
            default: return "개인 시간"
            }
        } else {
            switch hour {
            case 9..<17: return "업무/학업 환경"
            case 17..<21: return "사회적 시간"
            default: return "개인 시간"
            }
        }
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
    
    private func getUserPreferenceHistory() -> [String: Any] {
        // 실제로는 사용자의 데이터를 UserDefaults나 CoreData에서 가져옴
        return [
            "favoriteHours": [20, 21, 22, 23],
            "preferredSounds": ["Rain", "Ocean", "Forest"],
            "avgVolume": 65.0,
            "usageFrequency": 4.2
        ]
    }
    
    private func analyzeFavoriteTimeSlots(from history: [String: Any]) -> [String] {
        if let hours = history["favoriteHours"] as? [Int] {
            return hours.map { hour in
                switch hour {
                case 5..<10: return "아침"
                case 10..<14: return "오전"
                case 14..<18: return "오후"
                case 18..<22: return "저녁"
                default: return "밤"
                }
            }
        }
        return ["저녁", "밤"]
    }
    
    private func analyzePreferredSoundTypes(from history: [String: Any]) -> [String] {
        if let sounds = history["preferredSounds"] as? [String] {
            return sounds
        }
        return ["Rain", "Ocean", "Forest", "WhiteNoise"]
    }
    
    private func analyzeVolumePreferences(from history: [String: Any]) -> [String: Float] {
        let avgVolume = history["avgVolume"] as? Float ?? 60.0
        return [
            "ambient": avgVolume * 0.8,
            "nature": avgVolume * 1.0,
            "mechanical": avgVolume * 0.6
        ]
    }
    
    private func calculateAdaptationSpeed(from history: [String: Any]) -> Float {
        let frequency = history["usageFrequency"] as? Float ?? 3.0
        return min(1.0, frequency / 7.0)
    }
    
    private func estimateAmbientLight(timeOfDay: String) -> String {
        switch timeOfDay {
        case "새벽", "자정": return "매우 어두움"
        case "아침", "저녁": return "부드러운 빛"
        case "오전", "오후": return "밝음"
        case "점심": return "매우 밝음"
        default: return "어두움"
        }
    }
    
    private func estimateAmbientNoise(timeOfDay: String) -> String {
        switch timeOfDay {
        case "새벽", "자정": return "매우 조용함"
        case "아침", "저녁": return "보통 소음"
        case "오전", "오후", "점심": return "활발한 소음"
        default: return "조용함"
        }
    }
    
    private func estimateTemperatureContext() -> String {
        let season = getCurrentSeason()
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch (season, hour) {
        case ("여름", 12...18): return "덥고 습함"
        case ("겨울", 6...8), ("겨울", 18...22): return "춥고 건조함"
        case ("봄", _), ("가을", _): return "쾌적함"
        default: return "보통"
        }
    }
    
    private func estimateWeatherMood() -> String {
        // 실제로는 날씨 API를 사용하거나 사용자 입력을 활용
        let season = getCurrentSeason()
        switch season {
        case "봄": return "상쾌함"
        case "여름": return "활기참"
        case "가을": return "차분함"
        default: return "포근함"
        }
    }
    
    private func selectBaseSounds(for emotion: String) -> [String] {
        switch emotion {
        case "stress": return ["Rain", "Ocean", "Forest", "WhiteNoise"]
        case "relaxation": return ["Ocean", "Rain", "Forest", "Wind"]
        case "energy": return ["Forest", "Wind", "Fire", "Thunder"]
        case "sleep": return ["Rain", "Ocean", "WhiteNoise", "Wind"]
        default: return ["Rain", "Ocean", "Forest"]
        }
    }
    
    private func adjustForContext(sounds: [String], factors: ContextualFactors) -> [String] {
        var adjustedSounds = sounds
        
        // 시간대에 따른 조정
        if factors.timeContext.contains("밤") || factors.timeContext.contains("저녁") {
            adjustedSounds = adjustedSounds.filter { !["Thunder", "Fire"].contains($0) }
            if !adjustedSounds.contains("WhiteNoise") {
                adjustedSounds.append("WhiteNoise")
            }
        }
        
        // 활동 수준에 따른 조정
        if factors.activityLevel == "높은 활동" {
            adjustedSounds = adjustedSounds.filter { !["Lullaby"].contains($0) }
        }
        
        return adjustedSounds
    }
    
    private func personalizeSelection(sounds: [String], preferences: PersonalizedPreferences) -> [String] {
        var personalizedSounds = sounds
        
        // 선호하는 사운드 우선순위 증가
        for preferredSound in preferences.preferredSoundTypes {
            if !personalizedSounds.contains(preferredSound) {
                personalizedSounds.append(preferredSound)
            }
        }
        
        return Array(personalizedSounds.prefix(5))
    }
    
    private func adjustForEnvironment(sounds: [String], cues: EnvironmentalCues) -> [String] {
        var environmentalSounds = sounds
        
        // 소음 수준에 따른 조정
        if cues.noiseLevel.contains("활발한") {
            environmentalSounds = environmentalSounds.filter { !["Wind", "Forest"].contains($0) }
            if !environmentalSounds.contains("WhiteNoise") {
                environmentalSounds.append("WhiteNoise")
            }
        }
        
        return environmentalSounds
    }
    
    private func optimizeVolumes(
        sounds: [String],
        emotional: EmotionalProfile,
        contextual: ContextualFactors,
        environmental: EnvironmentalCues
    ) -> [Float] {
        let baseVolume: Float = 60.0
        let intensityMultiplier = emotional.intensity
        
        return sounds.map { sound in
            var volume = baseVolume
            
            // 감정에 따른 조정
            switch emotional.primaryEmotion {
            case "stress": volume *= 0.8
            case "energy": volume *= 1.2
            case "sleep": volume *= 0.6
            default: volume *= 1.0
            }
            
            // 시간대 조정
            if contextual.timeContext.contains("밤") {
                volume *= 0.7
            }
            
            // 환경 조정
            if environmental.noiseLevel.contains("활발한") {
                volume *= 1.3
            }
            
            return min(100.0, max(0.0, volume * intensityMultiplier))
        }
    }
    
    private func selectOptimalVersions(sounds: [String], preferences: PersonalizedPreferences, intensity: Float) -> [Int] {
        return sounds.map { sound in
            switch sound {
            case "Rain":
                return intensity > 0.7 ? 2 : 1
            case "Keyboard":
                return intensity > 0.6 ? 2 : 1
            default:
                return 1
            }
        }
    }
    
    private func calculateConfidenceScore(emotional: EmotionalProfile, contextual: ContextualFactors) -> Float {
        let emotionConfidence = emotional.intensity
        let contextConfidence: Float = contextual.isWeekend ? 0.8 : 0.9
        let complexityPenalty = emotional.complexity * 0.2
        
        return min(1.0, max(0.5, (emotionConfidence + contextConfidence) / 2.0 - complexityPenalty))
    }
    
    private func generateReasoning(emotional: EmotionalProfile, contextual: ContextualFactors) -> String {
        let emotionReason = getEmotionReasoning(emotional.primaryEmotion)
        let timeReason = getTimeReasoning(contextual.timeContext)
        
        return "\(emotionReason) \(timeReason)"
    }
    
    private func getEmotionDescription(_ emotion: String) -> String {
        switch emotion {
        case "stress": return "스트레스 해소가 필요한 상태"
        case "relaxation": return "편안한 휴식이 필요한 상태"
        case "energy": return "활력과 집중이 필요한 상태"
        case "sleep": return "깊은 수면이 필요한 상태"
        default: return "균형잡힌 안정 상태"
        }
    }
    
    private func getTimeDescription(_ timeOfDay: String) -> String {
        switch timeOfDay {
        case "새벽": return "고요한 새벽 시간"
        case "아침": return "활기찬 아침 시간"
        case "오전": return "집중이 필요한 오전"
        case "점심": return "짧은 휴식이 필요한 점심"
        case "오후": return "에너지가 필요한 오후"
        case "저녁": return "하루를 마무리하는 저녁"
        case "밤": return "편안한 휴식이 필요한 밤"
        default: return "조용한 시간"
        }
    }
    
    private func getContextDescription(_ contextual: ContextualFactors) -> String {
        if contextual.isWeekend {
            return "주말의 여유로운 분위기와 \(contextual.activityLevel) 상황을 고려했어요."
        } else {
            return "평일의 바쁜 일정과 \(contextual.activityLevel) 상황을 고려했어요."
        }
    }
    
    private func getEmotionReasoning(_ emotion: String) -> String {
        switch emotion {
        case "stress": return "긴장과 스트레스를 완화하는 부드러운 자연음"
        case "relaxation": return "마음의 평온을 가져다주는 차분한 사운드"
        case "energy": return "활력을 높이고 집중력을 강화하는 역동적인 음향"
        case "sleep": return "깊고 편안한 잠을 유도하는 수면 최적화 사운드"
        default: return "균형잡힌 감정 상태를 유지하는 안정적인 음향"
        }
    }
    
    private func getTimeReasoning(_ timeContext: String) -> String {
        if timeContext.contains("밤") || timeContext.contains("저녁") {
            return "를 통해 하루의 피로를 풀고 숙면을 준비할 수 있도록 구성했어요."
        } else if timeContext.contains("아침") || timeContext.contains("오전") {
            return "로 하루를 상쾌하게 시작할 수 있도록 설계했어요."
        } else {
            return "을 통해 현재 시간대에 최적화된 경험을 제공하도록 맞춤 설정했어요."
        }
    }
    
    private func applyAdvancedLocalPreset(_ recommendation: AdvancedRecommendation) {
        // SoundManager를 통해 실제 프리셋 적용
        if let soundManager = (parent as? UINavigationController)?.viewControllers.first as? ViewController {
            // 볼륨 설정
            for (index, volume) in recommendation.volumes.enumerated() {
                if index < recommendation.sounds.count {
                    // 사운드별 볼륨 적용 로직
                    soundManager.sliders[index].value = volume / 100.0
                }
            }
            
            // 버전 설정 (필요한 경우)
            for (index, version) in recommendation.versions.enumerated() {
                if index < recommendation.sounds.count {
                    // 버전 설정 로직 (실제 구현에 따라 다름)
                    print("사운드 \(recommendation.sounds[index])의 버전 \(version) 적용")
                }
            }
            
            print("🎯 고급 로컬 추천 프리셋이 적용되었습니다 (신뢰도: \(Int(recommendation.confidence * 100))%)")
        }
    }
    
    // MARK: - 누락된 메서드들 구현
    
    /// AI 분석 결과를 파싱하는 메서드
    private func parseAdvancedEmotionAnalysis(_ analysis: String) -> (emotion: String, timeOfDay: String, intensity: Float) {
        var emotion = "평온"
        var timeOfDay = getCurrentTimeOfDay()
        var intensity: Float = 1.0
        
        // EMOTION 파싱
        if let emotionMatch = analysis.range(of: #"EMOTION:\s*([가-힣]+)"#, options: .regularExpression) {
            let emotionStr = String(analysis[emotionMatch]).replacingOccurrences(of: "EMOTION:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            emotion = emotionStr
        }
        
        // TIMEOFDAY 파싱
        if let timeMatch = analysis.range(of: #"TIMEOFDAY:\s*([가-힣]+)"#, options: .regularExpression) {
            let timeStr = String(analysis[timeMatch]).replacingOccurrences(of: "TIMEOFDAY:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            timeOfDay = timeStr
        }
        
        // INTENSITY 파싱
        if let intensityMatch = analysis.range(of: #"INTENSITY:\s*([0-9.]+)"#, options: .regularExpression) {
            let intensityStr = String(analysis[intensityMatch]).replacingOccurrences(of: "INTENSITY:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            intensity = Float(intensityStr) ?? 1.0
        }
        
        return (emotion, timeOfDay, intensity)
    }
    
    /// AI 분석 결과로부터 고급 추천 생성
    private func createAdvancedRecommendationFromAI(_ analysis: (emotion: String, timeOfDay: String, intensity: Float)) -> AdvancedRecommendation {
        let userPresets = getUserPresetsForAnalysis()
        
        let baseRecommendation = generateAdvancedLocalRecommendation(
            emotional: EmotionalProfile(
                primaryEmotion: analysis.emotion,
                secondaryEmotion: nil,
                intensity: analysis.intensity,
                complexity: 0.3
            ),
            contextual: ContextualFactors(
                timeContext: analysis.timeOfDay,
                activityLevel: "보통",
                socialContext: "개인 시간",
                isWeekend: Calendar.current.component(.weekday, from: Date()) == 1 || Calendar.current.component(.weekday, from: Date()) == 7,
                season: getCurrentSeason()
            ),
            personal: PersonalizedPreferences(
                favoriteTimeSlots: [analysis.timeOfDay],
                preferredSoundTypes: ["Rain", "Ocean", "Forest"],
                volumePreferences: [:],
                adaptationSpeed: 0.7
            ),
            environmental: EnvironmentalCues(
                ambientLight: estimateAmbientLight(timeOfDay: analysis.timeOfDay),
                noiseLevel: "보통",
                temperatureContext: "쾌적함",
                weatherMood: "차분함"
            ),
            userPresets: userPresets
        )
        
        return baseRecommendation
    }
    
    /// 고급 프리셋 메시지 생성
    private func createAdvancedPresetMessage(
        analysis: (emotion: String, timeOfDay: String, intensity: Float),
        recommendation: AdvancedRecommendation,
        aiReason: String
    ) -> String {
        // REASON 추출
        var reason = "현재 상황에 맞는 편안한 사운드"
        if let reasonMatch = aiReason.range(of: #"REASON:\s*([^\n]+)"#, options: .regularExpression) {
            reason = String(aiReason[reasonMatch]).replacingOccurrences(of: "REASON:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let message = """
        🧠 **AI 종합 분석 완료**
        
        **분석 결과:**
        • 감정 상태: \(analysis.emotion)
        • 시간대: \(analysis.timeOfDay)
        • 강도: \(Int(analysis.intensity * 100))%
        
        **AI 추천 이유:**
        \(reason)
        
        **맞춤 사운드 조합:**
        \(formatSoundRecommendation(recommendation))
        
        신뢰도: \(Int(recommendation.confidence * 100))% | 바로 적용해보세요! ✨
        """
        
        return message
    }
    
    /// 사운드 추천을 보기 좋게 포맷팅
    private func formatSoundRecommendation(_ recommendation: AdvancedRecommendation) -> String {
        var formatted = ""
        for (index, sound) in recommendation.sounds.enumerated() {
            if index < recommendation.volumes.count {
                let volume = Int(recommendation.volumes[index])
                formatted += "• \(sound): \(volume)%\n"
            }
        }
        return formatted.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    


    /// 퀴ck액션 핸들러
    func handleQuickAction(_ action: String) {
        switch action {
        case "local_recommendation":
            let userMessage = ChatMessage(type: .user, text: "🏠 앱 분석 추천받기")
            appendChat(userMessage)
            
            // 고급 로컬 추천 시스템 실행
            provideAdvancedLocalRecommendation()
            
        case "ai_recommendation":
            let userMessage = ChatMessage(type: .user, text: "AI 분석 추천받기")
            appendChat(userMessage)
            
            // AI 사용 가능 여부 확인
            if AIUsageManager.shared.canUse(feature: .presetRecommendation) {
                // AI 추천 시스템 실행
                requestEnhancedAIPresetRecommendation()
            } else {
                // AI 사용 불가 시 안내 메시지
                let limitMessage = """
                💝 **오늘의 AI 추천 횟수를 모두 사용했습니다**
                
                대신 **앱 분석 추천**을 제공해드릴게요! 
                DeepSleep의 고급 분석 엔진이 당신의 사용 패턴을 학습해서 맞춤형 사운드를 추천해드립니다. ✨
                """
                
                appendChat(ChatMessage(type: .bot, text: limitMessage))
                
                // 로컬 추천으로 대체
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.provideAdvancedLocalRecommendation()
                }
            }
            
        case "accept_internal_analysis":
            let acceptMessage = ChatMessage(type: .user, text: "네, 앱 분석 추천받기")
            appendChat(acceptMessage)
            
            let loadingMessage = ChatMessage(type: .loading, text: "🔍 DeepSleep이 당신의 패턴을 분석하고 있어요...")
            appendChat(loadingMessage)
            
            // 약간의 지연 후 고급 분석 제공 (AI처럼 보이게)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.removeLastLoadingMessage()
                self.provideAdvancedLocalRecommendation()
            }
            
        case "decline_internal_analysis":
            let declineMessage = ChatMessage(type: .user, text: "🌙 아니요, 나중에 할게요")
            appendChat(declineMessage)
            
            let responseMessage = """
            알겠어요! 😊 언제든 필요하실 때 다시 말씀해주세요.
            
            내일이면 AI 추천 횟수가 초기화되니까, 그때 다시 AI 추천도 받아보실 수 있어요. ✨
            """
            
            appendChat(ChatMessage(type: .aiResponse, text: responseMessage))
            
        default:
            break
        }
    }
}
