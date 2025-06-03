import UIKit

// MARK: - ChatViewController Actions Extension
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
        // ✅ 일일 사용 제한 체크
        /*guard PresetLimitManager.shared.canUseToday() else {
            showPresetLimitAlert()
            return
        }*/
        
        appendChat(.user("🎵 지금 기분에 맞는 사운드 추천받기"))
        appendChat(.bot("🎶 당신의 감정에 맞는 완벽한 사운드 조합을 찾고 있어요... 잠시만 기다려주세요! ✨"))
        
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
        
        
        // 프리셋 파싱 시도
        if let recommendation = parsePresetRecommendation(from: response) {
            showPresetApplyButton(recommendation: recommendation)
        } else {
            // 파싱 실패 시 기본 프리셋 제공
            let defaultRecommendation = createDefaultRecommendation()
            showPresetApplyButton(recommendation: defaultRecommendation)
        }
        
        // ✅ 사용 횟수 증가
        PresetLimitManager.shared.incrementUsage()
    }
    
    // MARK: - ✅ 적용 버튼 표시 (수정됨)
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
        // 적용 완료 메시지
        appendChat(.bot("✅ '\(recommendation.presetName)' 프리셋이 적용되었습니다! 🎶\n\n새로운 사운드 조합을 즐겨보세요 ✨"))
        
        // 햅틱 피드백
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
        
        // 프리셋 저장 옵션 표시
        showSavePresetOption(recommendation: recommendation)
        
        // 콜백 호출 (메인 화면으로 프리셋 전달)
        onPresetApply?(recommendation)
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
    
    // MARK: - ✅ 프리셋 저장 옵션
    private func showSavePresetOption(recommendation: RecommendationResponse) {
        let alert = UIAlertController(
            title: "💾 프리셋 저장",
            message: "이 사운드 조합을 저장하시겠습니까?\n나중에 쉽게 다시 사용할 수 있어요!",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "저장 안함", style: .cancel))
        alert.addAction(UIAlertAction(title: "저장하기", style: .default) { [weak self] _ in
            self?.savePresetWithCustomName(recommendation)
        })
        
        present(alert, animated: true)
    }
    
    private func savePresetWithCustomName(_ recommendation: RecommendationResponse) {
        let alert = UIAlertController(
            title: "프리셋 이름",
            message: "저장할 프리셋의 이름을 입력하세요",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.text = recommendation.presetName
            textField.placeholder = "프리셋 이름"
        }
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "저장", style: .default) { [weak self] _ in
            guard let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { return }
            
            let preset = SoundPreset(
                name: name,
                volumes: recommendation.volumes,
                emotion: self?.getCurrentEmotion(),
                isAIGenerated: true,
                description: "AI가 추천한 맞춤 프리셋"
            )
            
            SettingsManager.shared.saveSoundPreset(preset)
            
            self?.appendChat(.bot("💾 '\(name)' 프리셋이 저장되었습니다! 언제든 다시 사용하실 수 있어요 😊"))
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - ✅ Helper Methods
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
    
    // ✅ 캐시 기반 감정 프롬프트 (수정됨)
    private func buildCachedEmotionalPrompt(currentEmotion: String, recentChat: String) -> String {
        return """
        현재 감정: \(currentEmotion)
        최근 대화: \(recentChat)
        
        위 맥락을 바탕으로 현재 감정에 맞는 12가지 사운드 볼륨을 추천해주세요.
        사운드: Rain,Thunder,Ocean,Fire,Steam,WindowRain,Forest,Wind,Night,Lullaby,Fan,WhiteNoise
        
        응답 형식: [프리셋명] Rain:값,Thunder:값,Ocean:값,Fire:값,Steam:값,WindowRain:값,Forest:값,Wind:값,Night:값,Lullaby:값,Fan:값,WhiteNoise:값
        """
    }
    
    // ✅ 일반 감정 프롬프트 (이름 변경)
    private func buildPresetEmotionalPrompt(emotion: String, recentChat: String) -> String {
        return """
        사용자 감정: \(emotion)
        대화 맥락: \(recentChat)
        
        현재 감정 상태에 최적화된 12가지 자연 사운드 조합을 추천해주세요.
        각 사운드별 볼륨(0-100)을 지정해주세요.
        
        사운드 종류: Rain,Thunder,Ocean,Fire,Steam,WindowRain,Forest,Wind,Night,Lullaby,Fan,WhiteNoise
        
        응답 형식: [프리셋명] Rain:값,Thunder:값,Ocean:값,Fire:값,Steam:값,WindowRain:값,Forest:값,Wind:값,Night:값,Lullaby:값,Fan:값,WhiteNoise:값
        """
    }
    
    // ✅ 프리셋 추천 파싱 (이름 변경)
    private func parsePresetRecommendation(from response: String) -> RecommendationResponse? {
        // [프리셋명] 형태로 프리셋명 추출
        let presetNamePattern = #"\[(.*?)\]"#
        let presetNameRegex = try? NSRegularExpression(pattern: presetNamePattern)
        let presetNameMatch = presetNameRegex?.firstMatch(in: response, range: NSRange(response.startIndex..., in: response))
        
        let presetName: String
        if let match = presetNameMatch,
           let range = Range(match.range(at: 1), in: response) {
            presetName = String(response[range])
        } else {
            presetName = "맞춤 프리셋"
        }
        
        // 볼륨 값들 추출
        let volumePattern = #"(Rain|Thunder|Ocean|Fire|Steam|WindowRain|Forest|Wind|Night|Lullaby|Fan|WhiteNoise):(\d+)"#
        let volumeRegex = try? NSRegularExpression(pattern: volumePattern)
        let matches = volumeRegex?.matches(in: response, range: NSRange(response.startIndex..., in: response)) ?? []
        
        var volumes: [String: Float] = [:]
        for match in matches {
            if let soundRange = Range(match.range(at: 1), in: response),
               let valueRange = Range(match.range(at: 2), in: response) {
                let sound = String(response[soundRange])
                let value = Float(String(response[valueRange])) ?? 50.0
                volumes[sound] = min(100, max(0, value))
            }
        }
        
        // 모든 사운드에 대한 볼륨 배열 생성
        let soundOrder = ["Rain", "Thunder", "Ocean", "Fire", "Steam", "WindowRain", "Forest", "Wind", "Night", "Lullaby", "Fan", "WhiteNoise"]
        let volumeArray = soundOrder.map { volumes[$0] ?? 50.0 }
        
        // 최소 8개 이상의 유효한 볼륨 값이 있어야 성공으로 간주
        if volumes.count >= 8 {
            return RecommendationResponse(volumes: volumeArray, presetName: presetName)
        }
        
        return nil
    }
    
    // ✅ 격려 메시지 생성 (이름 변경)
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
    
    private func createDefaultRecommendation() -> RecommendationResponse {
        let emotion = getCurrentEmotion()
        
        switch emotion {
        case let e where e.contains("😢") || e.contains("😞") || e.contains("😔"):
            return RecommendationResponse(
                volumes: [70, 5, 80, 15, 10, 60, 85, 25, 40, 75, 30, 50],
                presetName: "마음을 달래는 소리"
            )
        case let e where e.contains("😰") || e.contains("😱") || e.contains("😨"):
            return RecommendationResponse(
                volumes: [85, 0, 60, 5, 15, 40, 75, 20, 50, 70, 40, 80],
                presetName: "불안을 진정시키는 소리"
            )
        case let e where e.contains("😴") || e.contains("😪"):
            return RecommendationResponse(
                volumes: [40, 0, 30, 10, 20, 70, 30, 35, 60, 95, 60, 85],
                presetName: "깊은 잠을 위한 소리"
            )
        case let e where e.contains("😊") || e.contains("😄") || e.contains("🥰"):
            return RecommendationResponse(
                volumes: [60, 15, 70, 30, 25, 30, 80, 50, 55, 40, 25, 35],
                presetName: "기쁨을 더하는 소리"
            )
        case let e where e.contains("😡") || e.contains("😤"):
            return RecommendationResponse(
                volumes: [80, 20, 75, 10, 5, 50, 60, 70, 35, 40, 50, 65],
                presetName: "화를 가라앉히는 소리"
            )
        default:
            return RecommendationResponse(
                volumes: [65, 10, 55, 20, 15, 40, 70, 45, 50, 50, 35, 45],
                presetName: "평온한 마음의 소리"
            )
        }
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
