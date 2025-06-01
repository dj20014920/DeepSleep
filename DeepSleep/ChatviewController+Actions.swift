import UIKit

// MARK: - ChatViewController Actions Extension
extension ChatViewController {
    
    // MARK: - ✅ 캐시 기반 메시지 전송
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
    
    // MARK: - ✅ 캐시 기반 프리셋 추천
    @objc func presetButtonTapped() {
        guard SettingsManager.shared.canUsePresetRecommendationToday() else {
            appendChat(.bot("❌ 오늘 프리셋 추천 횟수를 모두 사용했어요!\n내일 다시 만나요 😊"))
            return
        }
        
        appendChat(.user("지금 기분에 맞는 사운드 추천해줘! 🎵"))
        appendChat(.bot("AI가 당신의 마음을 읽고 있어요... 🔍\n완벽한 사운드 조합을 찾는 중이에요."))
        
        // ✅ 캐시된 대화 맥락과 함께 프리셋 요청 메시지 구성
        let presetRequestMessage = "지금 기분에 맞는 12가지 사운드 조합을 추천해주세요"
        
        let cachedPrompt = CachedConversationManager.shared.buildCachedPrompt(
            newMessage: presetRequestMessage,
            context: getCurrentChatContext()
        )
        
        #if DEBUG
        print("🎵 [CACHED-PRESET] 토큰: \(cachedPrompt.estimatedTokens), 캐시사용: \(cachedPrompt.useCache)")
        #endif
        
        // ✅ 캐시 기반 프리셋 추천 요청 (완성 보장)
        ReplicateChatService.shared.sendCachedPresetRecommendation(
            prompt: cachedPrompt.prompt,
            useCache: cachedPrompt.useCache,
            emotionContext: initialUserText ?? "일반적인 기분"
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let response = result, !response.isEmpty,
                   let parsed = self.parseRecommendation(from: response) {
                    
                    let presetName = parsed.presetName
                    let encouragingMessage = self.getEncouragingMessage(for: self.initialUserText ?? "😊")
                    
                    self.appendChat(.presetRecommendation(
                        presetName: presetName,
                        message: "🎵 \(presetName)이 준비되었어요!\n\(encouragingMessage)",
                        apply: {
                            self.onPresetApply?(parsed)
                            self.navigationController?.popViewController(animated: true)
                        }
                    ))
                    
                    // ✅ 성공 후 캐시 업데이트
                    CachedConversationManager.shared.updateCacheAfterResponse()
                    
                    TokenTracker.shared.logAndTrack(
                        prompt: cachedPrompt.prompt,
                        intent: "cached_preset_success",
                        response: response
                    )
                    
                    SettingsManager.shared.incrementPresetRecommendationUsage()
                } else {
                    // ✅ 실패 시 기본 프리셋 제공
                    let fallbackPreset = self.getFallbackPreset(for: self.initialUserText ?? "😊")
                    
                    self.appendChat(.presetRecommendation(
                        presetName: fallbackPreset.presetName,
                        message: "🎵 \(fallbackPreset.presetName)을 준비했어요!\n네트워크 상황으로 기본 추천을 드려요.",
                        apply: {
                            self.onPresetApply?(fallbackPreset)
                            self.navigationController?.popViewController(animated: true)
                        }
                    ))
                    
                    TokenTracker.shared.logAndTrack(
                        prompt: cachedPrompt.prompt,
                        intent: "cached_preset_fallback"
                    )
                    
                    SettingsManager.shared.incrementPresetRecommendationUsage()
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
    
    // MARK: - ✅ 스마트 대화 관리
    func sendMessageWithSmartCaching(_ text: String) {
        // 긴 대화 체크 및 처리
        handleLongConversationReset()
        
        chatHistory.append((isUser: true, message: text))
        
        // 캐시 기반 메시지 전송
        let cachedPrompt = CachedConversationManager.shared.buildCachedPrompt(
            newMessage: text,
            context: getCurrentChatContext()
        )
        
        ReplicateChatService.shared.sendCachedPrompt(
            prompt: cachedPrompt.prompt,
            useCache: cachedPrompt.useCache,
            estimatedTokens: cachedPrompt.estimatedTokens,
            intent: determineChatIntent(from: text)
        ) { [weak self] response in
            DispatchQueue.main.async {
                if let response = response, !response.isEmpty {
                    // ✅ 완성도 확인
                    let completeResponse = self?.ensureCompleteResponse(response, intent: self?.determineChatIntent(from: text) ?? "chat") ?? response
                    
                    self?.chatHistory.append((isUser: false, message: completeResponse))
                    self?.appendChat(.bot(completeResponse))
                    
                    // 캐시 업데이트
                    CachedConversationManager.shared.updateCacheAfterResponse()
                } else {
                    self?.appendChat(.bot("죄송해요, 응답 중 문제가 발생했습니다. 다시 시도해 주세요."))
                }
            }
        }
    }
    
    // MARK: - ✅ Helper Methods
    
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
    
    // ✅ 기존 의도 분석 (호환성 유지)
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
    
    // ✅ 폴백 프리셋 제공
    private func getFallbackPreset(for emotion: String) -> RecommendationResponse {
        switch emotion {
        case let e where e.contains("😢") || e.contains("😞") || e.contains("😔"):
            return RecommendationResponse(
                volumes: [60, 10, 70, 0, 0, 20, 80, 30, 25, 60, 20, 40],
                presetName: "위로의 소리"
            )
        case let e where e.contains("😰") || e.contains("😱") || e.contains("😨"):
            return RecommendationResponse(
                volumes: [80, 0, 40, 0, 0, 30, 70, 20, 30, 50, 30, 60],
                presetName: "안정의 소리"
            )
        case let e where e.contains("😴") || e.contains("😪"):
            return RecommendationResponse(
                volumes: [40, 0, 30, 0, 0, 60, 40, 40, 50, 90, 50, 70],
                presetName: "깊은 잠의 소리"
            )
        case let e where e.contains("😊") || e.contains("😄") || e.contains("🥰"):
            return RecommendationResponse(
                volumes: [50, 10, 50, 20, 20, 20, 70, 40, 40, 40, 20, 30],
                presetName: "기쁨의 소리"
            )
        case let e where e.contains("😡") || e.contains("😤"):
            return RecommendationResponse(
                volumes: [70, 30, 60, 10, 0, 40, 50, 60, 30, 30, 40, 50],
                presetName: "마음 달래는 소리"
            )
        default:
            return RecommendationResponse(
                volumes: [50, 10, 40, 10, 10, 30, 60, 40, 50, 40, 30, 40],
                presetName: "평온의 소리"
            )
        }
    }
    
    // MARK: - Conversation Management
    
    private func handleConversationReset() {
        ReplicateChatService.shared.handleConversationReset { [weak self] resetMessage in
            DispatchQueue.main.async {
                self?.appendChat(.bot(resetMessage))
            }
        }
    }
    
    // ✅ 캐시 무효화 (긴 대화 시)
    private func handleLongConversationReset() {
        let totalMessages = messages.count
        let totalLength = messages.compactMap { message -> String? in
            switch message {
            case .user(let text): return text
            case .bot(let text): return text
            default: return nil
            }
        }.joined(separator: " ").count
        
        // 대화가 너무 길어지면 캐시 무효화 및 새 대화 시작
        if totalMessages > 50 || totalLength > 5000 {
            CachedConversationManager.shared.invalidateCache()
            
            appendChat(.bot("""
            💾 대화가 길어져서 새로운 대화를 시작합니다.
            
            지금까지의 대화 맥락은 기억하고 있으니, 
            계속해서 개인화된 대화를 도와드릴게요! 😊
            """))
            
            #if DEBUG
            print("🗑️ 긴 대화로 인한 캐시 리셋: \(totalMessages)개 메시지, \(totalLength)자")
            #endif
        }
    }
    
    // MARK: - ✅ Debug Features
    #if DEBUG
    func showCacheDebugInfo() {
        let debugInfo = CachedConversationManager.shared.getDebugInfo()
        let alert = UIAlertController(title: "🗄️ 캐시 디버그 정보", message: debugInfo, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        alert.addAction(UIAlertAction(title: "캐시 무효화", style: .destructive) { _ in
            CachedConversationManager.shared.invalidateCache()
            self.appendChat(.bot("🗑️ 캐시가 무효화되었습니다. 새로운 대화가 시작됩니다."))
        })
        present(alert, animated: true)
    }
    
    func showMemoryDebugInfo() {
        let weeklyMemory = CachedConversationManager.shared.loadWeeklyMemory()
        let debugMessage = """
        🧠 주간 메모리 상태:
        
        📊 총 메시지: \(weeklyMemory.totalMessages)개
        🎭 감정 패턴: \(weeklyMemory.emotionalPattern)
        🎯 주요 주제: \(weeklyMemory.recurringThemes.prefix(3).joined(separator: ", "))
        💭 주요 고민: \(weeklyMemory.userConcerns.prefix(2).joined(separator: "; "))
        💡 효과적 조언: \(weeklyMemory.keyAdvice.prefix(2).joined(separator: "; "))
        """
        
        let alert = UIAlertController(title: "🧠 메모리 디버그", message: debugMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        alert.addAction(UIAlertAction(title: "메모리 업데이트", style: .default) { _ in
            CachedConversationManager.shared.updateWeeklyMemoryAsync()
            self.appendChat(.bot("🔄 주간 메모리가 업데이트되었습니다."))
        })
        present(alert, animated: true)
    }
    #endif
}
