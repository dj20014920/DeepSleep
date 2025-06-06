import UIKit

// MARK: - ChatViewController Actions Extension (수정됨)
extension ChatViewController {
    
    // MARK: - ✅ 기존 sendButtonTapped 유지
    @objc func sendButtonTapped() {
        guard let text = inputTextField.text, !text.isEmpty else { return }
        inputTextField.text = ""
        appendChat(.user(text))
        
        if !SettingsManager.shared.canUseChatToday() {
            appendChat(.bot("❌ 오늘의 채팅 횟수를 모두 사용하셨어요.\n내일 다시 만나요! 😊"))
            return
        } else if SettingsManager.shared.getTodayStats().chatCount >= 40 {
            appendChat(.bot("⚠️ 오늘 채팅 횟수가 10회 남았어요.\n소중한 시간이니 천천히 대화해요 💝"))
        }
        
        // ✅ 로딩 메시지 표시
        appendChat(.loading)
        
        // ✅ 캐시 매니저를 통한 최적화된 프롬프트 생성
        let cachedPrompt = CachedConversationManager.shared.buildCachedPrompt(
            newMessage: text,
            context: getCurrentChatContext()
        )
        
        #if DEBUG
        print("📤 [CACHED-SEND] 토큰: \(cachedPrompt.estimatedTokens), 캐시사용: \(cachedPrompt.useCache)")
        #endif
        
        // ✅ 캐시 정보와 함께 AI 서비스 호출 (완성 보장)
        ReplicateChatService.shared.sendCachedPrompt(
            prompt: cachedPrompt.prompt,
            useCache: cachedPrompt.useCache,
            estimatedTokens: cachedPrompt.estimatedTokens,
            intent: determineChatIntent(from: text)
        ) { [weak self] response in
            DispatchQueue.main.async {
                // ✅ 로딩 메시지 제거
                self?.removeLastLoadingMessage()
                
                if let msg = response, !msg.isEmpty {
                    let completeResponse = self?.ensureCompleteResponse(msg, intent: self?.determineChatIntent(from: text) ?? "chat") ?? msg
                    
                    self?.appendChat(.bot(completeResponse))
                    CachedConversationManager.shared.updateCacheAfterResponse()
                    
                    TokenTracker.shared.logAndTrack(
                        prompt: cachedPrompt.prompt,
                        intent: "cached_chat_success",
                        response: completeResponse
                    )
                } else {
                    self?.appendChat(.bot("❌ 지금 응답을 불러올 수 없어요.\n잠시 후 다시 시도해주세요."))
                    
                    TokenTracker.shared.logAndTrack(
                        prompt: cachedPrompt.prompt,
                        intent: "cached_chat_failed"
                    )
                }
            }
        }
        
        incrementDailyChatCount()
    }
    
    // MARK: - ✅ 수정된 presetButtonTapped
    @objc func presetButtonTapped() {
        // ✅ 일일 사용 제한 체크 (일단 주석처리하고 나중에 활성화)
        /*guard PresetLimitManager.shared.canUseToday() else {
            showPresetLimitAlert()
            return
        }*/
        
        appendChat(.user("🎵 지금 기분에 맞는 사운드 추천받기"))
        
        // ✅ 로딩 메시지 표시
        appendChat(.loading)
        
        // 최근 대화 내용 수집
        let recentChat = getRecentChatForPreset()
        let currentEmotion = getCurrentEmotion()
        
        // ✅ 캐시 기반 프리셋 추천 요청 (수정됨)
        let hasValidCache = CachedConversationManager.shared.currentCache != nil
        let emotionalPrompt: String
        
        if hasValidCache {
            // 캐시가 있을 때 간단한 프롬프트 사용
            emotionalPrompt = buildCachedEmotionalPrompt(
                currentEmotion: currentEmotion,
                recentChat: recentChat
            )
        } else {
            emotionalPrompt = buildPresetEmotionalPrompt(emotion: currentEmotion, recentChat: recentChat)
        }
        
        // AI에게 프리셋 추천 요청
        ReplicateChatService.shared.sendCachedPresetRecommendation(
            prompt: emotionalPrompt,
            useCache: hasValidCache,
            emotionContext: currentEmotion
        ) { [weak self] response in
            DispatchQueue.main.async {
                // ✅ 로딩 메시지 제거
                self?.removeLastLoadingMessage()
                
                self?.handlePresetRecommendationResponse(response)
            }
        }
    }
    
    // MARK: - ✅ 프리셋 추천 응답 처리
    private func handlePresetRecommendationResponse(_ response: String?) {
        guard let response = response else {
            appendChat(.bot("죄송해요, 프리셋 추천 중 문제가 발생했습니다 😅 네트워크 연결을 확인해주세요."))
            return
        }

        // 프리셋 파싱 시도 (self.parseRecommendation은 EnhancedRecommendationResponse? 반환)
        if let enhancedRecommendation = self.parsePresetRecommendation(from: response) {
            // EnhancedRecommendationResponse를 RecommendationResponse로 변환
            let recommendationToApply = RecommendationResponse(
                volumes: enhancedRecommendation.volumes,
                presetName: enhancedRecommendation.presetName,
                selectedVersions: enhancedRecommendation.selectedVersions ?? SoundPresetCatalog.defaultVersionSelection
            )
            showPresetApplyButton(recommendation: recommendationToApply)
        } else {
            // 파싱 실패 시 기본 프리셋 제공
            let defaultRecommendation = createDefaultRecommendation()
            showPresetApplyButton(recommendation: defaultRecommendation)
        }

        // ✅ 사용 횟수 증가
        PresetLimitManager.shared.incrementUsage()
    }
    
    
    
    // MARK: - 프리셋 적용 프로세스
    private func showPresetApplyButton(recommendation: RecommendationResponse) {
            let encouragingMessage = getPresetEncouragingMessage(for: recommendation.presetName)
            let displayMessage = """
            🎵 완벽한 사운드 조합을 찾았어요!
            
            📀 프리셋: \(recommendation.presetName)
            
            \(encouragingMessage)
            """
            
            let applyMessage = ChatMessage.presetRecommendation(
                presetName: recommendation.presetName,
                message: displayMessage,
                apply: { [weak self] in
                    self?.applyPresetRecommendation(recommendation)
                }
            )
            
            // ✅ appendChat 메서드를 사용하여 UI 업데이트 처리
            appendChat(applyMessage)
        }
        
        // MARK: - ✅ 프리셋 적용
        private func applyPresetRecommendation(_ recommendation: RecommendationResponse) {
            // 햅틱 피드백
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
            
            // MARK: - 디버깅 코드 추가
            if onPresetApply == nil {
                print("🚨 [DEBUG] onPresetApply is nil. This is likely the cause of the issue: 메인 화면으로 돌아가고 프리셋을 재생하는 콜백이 설정되지 않았습니다.")
                // 사용자에게도 간단한 문제 상황 알림 (개발자 확인 필요 메시지)
                appendChat(.bot("⚠️ 프리셋 적용 후 다음 단계로 진행하는 과정에 문제가 발생했어요. (개발자 확인 필요)"))
                return
            } else {
                print("✅ [DEBUG] onPresetApply is NOT nil. Recommendation to apply: \(recommendation)")
            }
            // MARK: - 디버깅 코드 끝
                
            // 콜백 호출 (메인 화면으로 프리셋 전달)
            onPresetApply?(recommendation)

            // ChatViewController 자신을 닫습니다.
            // UI 변경은 메인 스레드에서 수행합니다.
            DispatchQueue.main.async {
                self.closeButtonTapped()
            }
        }
    
    // MARK: - ✅ 프리셋 조정 요청 처리
    private func handlePresetAdjustmentRequest(_ userMessage: String, currentRecommendation: RecommendationResponse) {
        // 사용자의 피드백을 바탕으로 프리셋 조정
        if userMessage.contains("더 조용") || userMessage.contains("볼륨 낮춰") {
            adjustPresetVolumes(currentRecommendation, adjustment: -20)
        } else if userMessage.contains("더 크게") || userMessage.contains("볼륨 높여") {
            adjustPresetVolumes(currentRecommendation, adjustment: 20)
        } else if userMessage.contains("다른 스타일") || userMessage.contains("다른 추천") {
            requestNewPresetStyle()
        } else {
            // 일반적인 피드백 처리
            appendChat(.bot("소중한 피드백 감사해요! 😊 더 나은 추천을 위해 참고하겠습니다."))
        }
    }
    
    private func adjustPresetVolumes(_ recommendation: RecommendationResponse, adjustment: Int) {
        let adjustedVolumes = recommendation.volumes.map { volume in
            max(0, min(100, volume + Float(adjustment)))
        }
        
        let adjustedRecommendation = RecommendationResponse(
            volumes: adjustedVolumes,
            presetName: recommendation.presetName + " (조정됨)",
            selectedVersions: recommendation.selectedVersions
        )
        
        // 조정된 프리셋 적용
        onPresetApply?(adjustedRecommendation)
        
        appendChat(.bot("🔧 볼륨을 조정해드렸어요! 이제 어떠신가요?"))
    }
    
    private func requestNewPresetStyle() {
        appendChat(.bot("""
        🎨 다른 스타일의 사운드 조합을 원하시는군요!
        
        어떤 느낌을 원하시나요?
        • 더 활기찬 느낌
        • 더 차분한 느낌  
        • 자연의 소리 위주
        • 도시적인 느낌
        • 완전히 새로운 스타일
        
        원하시는 스타일을 알려주시면 새로운 조합을 추천해드릴게요! ✨
        """))
    }
    
    // MARK: - ✅ 프리셋 제한 알림
    private func showPresetLimitAlert() {
        let alert = UIAlertController(
            title: "🎵 프리셋 추천 제한",
            message: """
            하루 3회 프리셋 추천을 이미 사용하셨습니다.
            
            깊이 있는 상담을 위해 하루 3회로 제한하고 있어요.
            대신 충분한 시간 동안 AI와 깊이 있게 대화할 수 있습니다.
            
            내일 다시 이용해보세요! 😊
            """,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - ✅ Helper Methods (누락된 메서드들 추가)
    
    private func getRecentChatForPreset() -> String {
        let recentMessages = messages.suffix(6)
        
        let chatText = recentMessages.compactMap { message -> String? in
            switch message {
            case .user(let text):
                return "사용자: \(text)"
            case .bot(let text):
                return "AI: \(text)"
            default:
                return nil
            }
        }.joined(separator: "\n")
        
        return chatText.isEmpty ? "일반적인 대화" : chatText
    }
    
    // MARK: - getCurrentEmotion 메서드 추가
    private func getCurrentEmotion() -> String {
        if let diary = diaryContext {
            return diary.emotion
        }
        
        if let initialText = initialUserText,
           initialText.contains("😊") || initialText.contains("😢") ||
           initialText.contains("😠") || initialText.contains("😰") {
            return initialText
        }
        
        let recentUserMessages = messages.suffix(5).compactMap { message -> String? in
            if case .user(let text) = message { return text }
            return nil
        }
        
        for message in recentUserMessages.reversed() {
            if message.contains("😊") { return "😊 기쁜" }
            if message.contains("😢") { return "😢 슬픈" }
            if message.contains("😠") { return "😠 화난" }
            if message.contains("😰") { return "😰 불안한" }
            if message.contains("😴") { return "😴 피곤한" }
        }
        
        return "😊 평온한"
    }
    
    // MARK: - getPresetEncouragingMessage 메서드 추가
    private func getPresetEncouragingMessage(for presetName: String) -> String {
        let encouragingMessages = [
            "이 조합이 마음에 평안을 가져다줄 거예요 🌙",
            "지금 당신에게 꼭 필요한 소리입니다 ✨",
            "깊은 휴식과 치유의 시간을 만끽하세요 🌿",
            "마음의 안정을 찾는 완벽한 선택이에요 💙",
            "당신만을 위한 특별한 사운드 조합입니다 🎵"
        ]
        
        return encouragingMessages.randomElement() ?? encouragingMessages[0]
    }
    
    // MARK: - createDefaultRecommendation 메서드 추가
    private func createDefaultRecommendation() -> RecommendationResponse {
        let emotion = getCurrentEmotion()
        
        // 11개 카테고리 기준으로 볼륨 설정
        switch emotion {
        case let e where e.contains("😢") || e.contains("😞") || e.contains("😔"):
            return RecommendationResponse(
                volumes: [70, 5, 80, 15, 60, 85, 25, 40, 75, 30, 50],
                presetName: "마음을 달래는 소리",
                selectedVersions: SoundPresetCatalog.defaultVersionSelection
            )
        case let e where e.contains("😰") || e.contains("😱") || e.contains("😨"):
            return RecommendationResponse(
                volumes: [85, 0, 60, 5, 40, 75, 20, 50, 70, 40, 80],
                presetName: "불안을 진정시키는 소리",
                selectedVersions: SoundPresetCatalog.defaultVersionSelection
            )
        case let e where e.contains("😴") || e.contains("😪"):
            return RecommendationResponse(
                volumes: [40, 0, 30, 10, 70, 30, 35, 60, 95, 60, 85],
                presetName: "깊은 잠을 위한 소리",
                selectedVersions: SoundPresetCatalog.defaultVersionSelection
            )
        case let e where e.contains("😊") || e.contains("😄") || e.contains("🥰"):
            return RecommendationResponse(
                volumes: [60, 15, 70, 30, 30, 80, 50, 55, 40, 25, 35],
                presetName: "기쁨을 더하는 소리",
                selectedVersions: SoundPresetCatalog.defaultVersionSelection
            )
        case let e where e.contains("😡") || e.contains("😤"):
            return RecommendationResponse(
                volumes: [80, 20, 75, 10, 50, 60, 70, 35, 40, 50, 65],
                presetName: "화를 가라앉히는 소리",
                selectedVersions: SoundPresetCatalog.defaultVersionSelection
            )
        default:
            return RecommendationResponse(
                volumes: [65, 10, 55, 20, 40, 70, 45, 50, 50, 35, 45],
                presetName: "평온한 마음의 소리",
                selectedVersions: SoundPresetCatalog.defaultVersionSelection
            )
        }
    }
    
    // ✅ 캐시 기반 감정 프롬프트 (11개 카테고리, 한글 이름 및 설명 사용으로 수정)
    private func buildCachedEmotionalPrompt(currentEmotion: String, recentChat: String) -> String {
        let soundCategories = SoundPresetCatalog.categoryNames.joined(separator: ",")
        let categoryDetails = SoundPresetCatalog.categoryDescriptions.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        
        return """
        현재 사용자의 감정: \(currentEmotion)
        최근 사용자와의 대화:
        \(recentChat)

        당신은 사용자의 감정에 깊이 공감하고, 가장 적절한 사운드 테라피를 제안하는 사운드 큐레이터입니다.
        아래 제공된 사운드 카테고리 목록과 각 카테고리에 대한 설명을 참고하여, 현재 사용자의 감정 상태에 가장 도움이 될 만한 11가지 사운드의 볼륨(0~100 사이 정수) 조합을 추천해주세요.
        사용자가 편안함을 느끼고 감정을 조절하는 데 도움이 되는 조합을 만드는 것이 중요합니다. 너무 자극적이거나 불쾌한 조합은 피해주세요.

        사용 가능한 사운드 카테고리 (총 11개):
        \(categoryDetails)

        프리셋 이름은 사용자의 감정과 추천된 사운드 조합의 특징을 잘 나타내는 창의적이고 감성적인 이름으로 지어주세요. (예: "고요한 새벽의 위로", "따스한 햇살 한 스푼")

        응답 형식은 반드시 다음 형식을 따라야 합니다:
        [프리셋명] \(SoundPresetCatalog.categoryNames[0]):값,\(SoundPresetCatalog.categoryNames[1]):값,\(SoundPresetCatalog.categoryNames[2]):값,\(SoundPresetCatalog.categoryNames[3]):값,\(SoundPresetCatalog.categoryNames[4]):값,\(SoundPresetCatalog.categoryNames[5]):값,\(SoundPresetCatalog.categoryNames[6]):값,\(SoundPresetCatalog.categoryNames[7]):값,\(SoundPresetCatalog.categoryNames[8]):값,\(SoundPresetCatalog.categoryNames[9]):값,\(SoundPresetCatalog.categoryNames[10]):값
        """
    }
    
    // ✅ 일반 감정 프롬프트 (11개 카테고리, 한글 이름 및 설명 사용으로 수정)
    private func buildPresetEmotionalPrompt(emotion: String, recentChat: String) -> String {
        let soundCategories = SoundPresetCatalog.categoryNames.joined(separator: ",")
        let categoryDetails = SoundPresetCatalog.categoryDescriptions.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")

        return """
        현재 사용자의 감정: \(emotion)
        최근 사용자와의 대화:
        \(recentChat)

        당신은 사용자의 감정에 깊이 공감하고, 가장 적절한 사운드 테라피를 제안하는 사운드 큐레이터입니다.
        아래 제공된 사운드 카테고리 목록과 각 카테고리에 대한 설명을 참고하여, 현재 사용자의 감정 상태에 가장 도움이 될 만한 11가지 사운드의 볼륨(0~100 사이 정수) 조합을 추천해주세요.
        사용자가 편안함을 느끼고 감정을 조절하는 데 도움이 되는 조합을 만드는 것이 중요합니다. 너무 자극적이거나 불쾌한 조합은 피해주세요.

        사용 가능한 사운드 카테고리 (총 11개):
        \(categoryDetails)

        프리셋 이름은 사용자의 감정과 추천된 사운드 조합의 특징을 잘 나타내는 창의적이고 감성적인 이름으로 지어주세요. (예: "고요한 새벽의 위로", "따스한 햇살 한 스푼")

        응답 형식은 반드시 다음 형식을 따라야 합니다:
        [프리셋명] \(SoundPresetCatalog.categoryNames[0]):값,\(SoundPresetCatalog.categoryNames[1]):값,\(SoundPresetCatalog.categoryNames[2]):값,\(SoundPresetCatalog.categoryNames[3]):값,\(SoundPresetCatalog.categoryNames[4]):값,\(SoundPresetCatalog.categoryNames[5]):값,\(SoundPresetCatalog.categoryNames[6]):값,\(SoundPresetCatalog.categoryNames[7]):값,\(SoundPresetCatalog.categoryNames[8]):값,\(SoundPresetCatalog.categoryNames[9]):값,\(SoundPresetCatalog.categoryNames[10]):값
        """
    }
    
    // MARK: - ✅ 기존 Helper Methods 유지
    
    // ✅ 응답 완성도 확인 및 보완
    private func ensureCompleteResponse(_ response: String, intent: String) -> String {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 응답이 너무 짧거나 완료되지 않은 것 같으면 보완
        if trimmed.count < 10 {
            switch intent {
            case "diary_analysis", "diary":
                return trimmed + "\n\n더 자세한 이야기가 있으시면 언제든 말씀해 주세요. 😊"
            case "casual_chat":
                return trimmed + " 더 궁금한 것이 있으시면 말씀해 주세요!"
            default:
                return trimmed + "\n\n도움이 더 필요하시면 언제든 말씀해 주세요."
            }
        }
        
        // 문장이 중간에 끊어진 것 같으면 자연스럽게 마무리
        if !trimmed.hasSuffix(".") && !trimmed.hasSuffix("!") && !trimmed.hasSuffix("?") &&
           !trimmed.hasSuffix("😊") && !trimmed.hasSuffix("💝") && !trimmed.hasSuffix("🌟") {
            
            switch intent {
            case "diary_analysis":
                return trimmed + ". 더 자세한 감정 분석이 필요하시면 언제든 말씀해 주세요."
            case "pattern_analysis":
                return trimmed + ". 이 분석이 도움이 되길 바라며, 더 궁금한 점이 있으시면 언제든 문의해 주세요."
            case "diary":
                return trimmed + ". 언제든 마음 편히 이야기해 주세요. 😊"
            default:
                return trimmed + ". 더 도움이 필요하시면 말씀해 주세요!"
            }
        }
        
        return trimmed
    }
    
    // ✅ 현재 대화 컨텍스트 결정
    private func getCurrentChatContext() -> ChatContext? {
        if let diary = diaryContext {
            return .diaryAnalysis(diary)
        } else if let patternData = emotionPatternData {
            return .patternAnalysis(patternData)
        } else if let emotion = initialUserText {
            return .emotionChat(emotion)
        }
        return nil
    }
    
    // ✅ 채팅 의도 분석 (캐시 최적화용)
    private func determineChatIntent(from message: String) -> String {
        let lowercased = message.lowercased()
        
        if message.count > 100 || lowercased.contains("오늘") || lowercased.contains("하루") {
            return "diary"  // 일기형 대화
        } else if lowercased.contains("분석") || lowercased.contains("패턴") {
            return "analysis_chat"  // 분석 관련 대화
        } else if lowercased.contains("추천") || lowercased.contains("조언") {
            return "advice_chat"  // 조언 요청
        } else {
            return "casual_chat"  // 일반 대화
        }
    }
}
