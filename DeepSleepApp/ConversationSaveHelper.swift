import Foundation
import Core

/// 💾 대화 저장 도우미 클래스
/// ChatViewController와 DailyConversationManager 사이의 브리지 역할
final class ConversationSaveHelper {
    static let shared = ConversationSaveHelper()
    
    private var currentConversation: DailyConversation?
    private var pendingMessages: [ConversationMessage] = []
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 🆕 새로운 대화 세션 시작
    func startNewConversation(emotionContext: EmotionContext) {
        currentConversation = DailyConversation(emotionContext: emotionContext)
        pendingMessages.removeAll()
        
        print("🆕 [ConversationSaveHelper] 새로운 대화 세션 시작: \(emotionContext.primaryEmotion)")
    }
    
    /// 📝 메시지 추가 (실시간 저장 대신 배치 저장)
    func addMessage(content: String, isFromUser: Bool, emotionIntensity: Double? = nil) {
        let messageType: ConversationMessageType = determineMessageType(content: content, isFromUser: isFromUser)
        
        let message = ConversationMessage(
            content: content,
            isFromUser: isFromUser,
            emotionIntensity: emotionIntensity,
            messageType: messageType
        )
        
        pendingMessages.append(message)
        
        // 메시지가 10개 이상 쌓이면 자동 저장
        if pendingMessages.count >= 10 {
            Task {
                await saveCurrentConversation()
            }
        }
        
        print("📝 [ConversationSaveHelper] 메시지 추가됨: \(messageType.rawValue) - \(content.prefix(50))")
    }
    
    /// 💾 현재 대화 저장
    func saveCurrentConversation() async {
        guard var conversation = currentConversation else {
            print("⚠️ [ConversationSaveHelper] 저장할 대화가 없습니다")
            return
        }
        
        // 대기 중인 메시지들을 대화에 추가
        conversation = DailyConversation(
            emotionContext: conversation.emotionContext,
            messages: conversation.messages + pendingMessages
        )
        
        do {
            try await DailyConversationManager.shared.saveTodaysConversation(conversation)
            
            // 성공 시 대기 메시지 초기화
            pendingMessages.removeAll()
            currentConversation = conversation
            
            print("✅ [ConversationSaveHelper] 대화 저장 완료: \(conversation.messages.count)개 메시지")
            
        } catch {
            print("❌ [ConversationSaveHelper] 대화 저장 실패: \(error)")
        }
    }
    
    /// 🔚 대화 세션 종료 및 최종 저장
    func endCurrentConversation() async {
        await saveCurrentConversation()
        currentConversation = nil
        pendingMessages.removeAll()
        
        print("🔚 [ConversationSaveHelper] 대화 세션 종료됨")
    }
    
    /// 📊 현재 대화 통계
    func getCurrentConversationStats() -> (messageCount: Int, duration: TimeInterval?) {
        let totalMessages = (currentConversation?.messages.count ?? 0) + pendingMessages.count
        let duration = currentConversation?.startTime.timeIntervalSinceNow
        
        return (messageCount: totalMessages, duration: duration)
    }
    
    // MARK: - Private Methods
    
    /// 메시지 타입 자동 판단
    private func determineMessageType(content: String, isFromUser: Bool) -> ConversationMessageType {
        let lowerContent = content.lowercased()
        
        if !isFromUser {
            return .systemResponse
        }
        
        // 감정 표현 감지
        let emotionKeywords = ["기분", "감정", "마음", "슬프", "우울", "행복", "스트레스", "불안", "걱정"]
        for keyword in emotionKeywords {
            if lowerContent.contains(keyword) {
                return .emotional
            }
        }
        
        // 목표 설정 감지
        let goalKeywords = ["목표", "계획", "하고 싶", "원해", "달성", "개선"]
        for keyword in goalKeywords {
            if lowerContent.contains(keyword) {
                return .goal
            }
        }
        
        // 피드백 감지
        let feedbackKeywords = ["좋았", "별로", "만족", "추천", "도움", "효과"]
        for keyword in feedbackKeywords {
            if lowerContent.contains(keyword) {
                return .feedback
            }
        }
        
        return .normal
    }
}

// MARK: - ChatViewController Integration Extension

extension ConversationSaveHelper {
    
    /// 📱 ChatViewController에서 호출할 편의 메서드
    func handleNewUserMessage(_ message: String, currentEmotion: String? = nil) {
        // 첫 메시지인 경우 새 대화 시작
        if currentConversation == nil {
            let emotionContext = EmotionContext(
                primaryEmotion: currentEmotion ?? "중립",
                intensity: 0.5,
                secondaryEmotions: [],
                userGoal: nil
            )
            startNewConversation(emotionContext: emotionContext)
        }
        
        // 감정 강도 추정 (간단한 버전)
        let emotionIntensity = estimateEmotionIntensity(from: message)
        
        addMessage(content: message, isFromUser: true, emotionIntensity: emotionIntensity)
    }
    
    /// 🤖 AI 응답 저장
    func handleAIResponse(_ response: String) {
        addMessage(content: response, isFromUser: false)
    }
    
    /// 🎭 감정 강도 추정 (키워드 기반)
    private func estimateEmotionIntensity(from message: String) -> Double {
        let content = message.lowercased()
        
        // 강한 감정 표현
        let strongEmotions = ["매우", "정말", "너무", "완전", "극도로", "심하게"]
        for word in strongEmotions {
            if content.contains(word) {
                return 0.8
            }
        }
        
        // 중간 감정 표현
        let moderateEmotions = ["조금", "약간", "살짝", "어느 정도"]
        for word in moderateEmotions {
            if content.contains(word) {
                return 0.4
            }
        }
        
        // 기본값
        return 0.5
    }
}