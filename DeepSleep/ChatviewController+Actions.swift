import UIKit

// MARK: - ChatViewController Actions Extension
extension ChatViewController {
    
    // MARK: - Chat Actions
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
        
        let isDiary = text.count > 30 || text.contains("오늘") || text.contains("하루")
        let intent = isDiary ? "diary" : "chat"
        let emotionalPrompt = buildChatPrompt(userMessage: text, isDiary: isDiary)

        #if DEBUG
        let estimatedTokens = TokenTracker.shared.estimateTokens(for: emotionalPrompt)
        print("📤 [PRE-SEND] 예상 토큰: \(estimatedTokens) (\(intent))")
        #endif

        ReplicateChatService.shared.sendPrompt(message: emotionalPrompt, intent: intent) { [weak self] response in
            DispatchQueue.main.async {
                if let msg = response {
                    self?.appendChat(.bot(msg))
                    
                    TokenTracker.shared.logAndTrack(
                        prompt: emotionalPrompt,
                        intent: intent,
                        response: msg
                    )
                } else {
                    self?.appendChat(.bot("❌ 지금 응답을 불러올 수 없어요.\n잠시 후 다시 시도해주세요."))
                    
                    TokenTracker.shared.logAndTrack(
                        prompt: emotionalPrompt,
                        intent: "\(intent)_failed"
                    )
                }
            }
        }
        incrementDailyChatCount()
    }
    
    @objc func presetButtonTapped() {
        guard SettingsManager.shared.canUsePresetRecommendationToday() else {
            appendChat(.bot("❌ 오늘 프리셋 추천 횟수를 모두 사용했어요!\n내일 다시 만나요 😊"))
            return
        }

        let recentMessages = messages.suffix(5).compactMap { message in
            switch message {
            case .user(let text): return "사용자: \(text)"
            case .bot(let text): return "AI: \(text)"
            default: return nil
            }
        }.joined(separator: "\n")

        let emotionContext = initialUserText ?? "일반적인 기분"
        let systemPrompt = buildEmotionalPrompt(emotion: emotionContext, recentChat: recentMessages)
        
        appendChat(.user("지금 기분에 맞는 사운드 추천해줘! 🎵"))
        appendChat(.bot("AI가 당신의 마음을 읽고 있어요... 🔍\n완벽한 사운드 조합을 찾는 중이에요."))

        #if DEBUG
        let estimatedTokens = TokenTracker.shared.estimateTokens(for: systemPrompt)
        print("🎵 [PRESET-REQ] 예상 토큰: \(estimatedTokens)")
        #endif

        ReplicateChatService.shared.sendPrompt(message: systemPrompt, intent: "recommendPreset") { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let response = result,
                   let parsed = self.parseRecommendation(from: response) {
                    
                    let presetName = parsed.presetName
                    let encouragingMessage = self.getEncouragingMessage(for: emotionContext)
                    
                    self.appendChat(.presetRecommendation(
                        presetName: presetName,
                        message: "🎵 \(presetName)이 준비되었어요!\n\(encouragingMessage)",
                        apply: {
                            self.onPresetApply?(parsed)
                            self.navigationController?.popViewController(animated: true)
                        }
                    ))
                    
                    TokenTracker.shared.logAndTrack(
                        prompt: systemPrompt,
                        intent: "recommendPreset_success",
                        response: response
                    )
                    
                    SettingsManager.shared.incrementPresetRecommendationUsage()
                } else {
                    self.appendChat(.bot("❌ 추천 과정에서 문제가 생겼어요.\n잠시 후 다시 시도해주세요."))
                    
                    TokenTracker.shared.logAndTrack(
                        prompt: systemPrompt,
                        intent: "recommendPreset_failed"
                    )
                }
            }
        }
    }
    
    // MARK: - Memory Management
    func sendMessageWithMemoryManagement(_ text: String) {
        chatHistory.append((isUser: true, message: text))
        
        let totalLength = chatHistory.map { $0.message.count }.reduce(0, +)
        let memoryCheck = ReplicateChatService.shared.preemptiveMemoryCheck(conversationLength: totalLength)
        
        if memoryCheck.shouldReset {
            handleConversationReset()
            return
        }
        
        let recentHistory = Array(chatHistory.suffix(10).map { $0.message })
        
        ReplicateChatService.shared.sendPromptWithContextManagement(
            message: text,
            intent: determineIntent(from: text),
            conversationHistory: recentHistory
        ) { [weak self] response in
            DispatchQueue.main.async {
                if let response = response {
                    self?.chatHistory.append((isUser: false, message: response))
                } else {
                    self?.appendChat(.bot("죄송해요, 응답 중 문제가 발생했습니다."))
                }
            }
        }
    }
    
    private func handleConversationReset() {
        ReplicateChatService.shared.handleConversationReset { [weak self] resetMessage in
            DispatchQueue.main.async {
                self?.appendChat(.bot(resetMessage))
            }
        }
    }
    
    private func determineIntent(from message: String) -> String {
        let lowercased = message.lowercased()
        
        if lowercased.contains("분석") || lowercased.contains("패턴") {
            return "pattern_analysis"
        } else if lowercased.contains("일기") || lowercased.contains("오늘") {
            return "diary_analysis"
        } else if lowercased.contains("개선") || lowercased.contains("조언") {
            return "improvement"
        } else {
            return "chat"
        }
    }
}
