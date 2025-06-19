import Foundation
import Combine

// MARK: - Chat View Model

@MainActor
public final class ChatViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published public var messages: [ChatMessageViewModel] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var currentSessionId: UUID = UUID()
    @Published public var isTyping: Bool = false
    
    // MARK: - Dependencies (will be injected in Phase 2)
    // private let chatService: ChatService?
    // private let emotionAnalyzer: EmotionAnalyzer?
    private let aiRecommendationService: any AIRecommendationService
    // private let tokenTracker: TokenTracker
    
    // MARK: - Session Properties
    private var sessionStartTime: Date?
    private var messageCount: Int = 0
    private let maxMessages: Int = 75
    private var isProcessingRecommendation: Bool = false
    
    // MARK: - Initialization
    public init(
        aiRecommendationService: any AIRecommendationService = MockAIRecommendationService()
    ) {
        self.aiRecommendationService = aiRecommendationService
        
        startSession()
    }
    
    // MARK: - Public Methods
    
    public func sendMessage(_ content: String) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessageViewModel(
            id: UUID(),
            content: content,
            isUser: true,
            timestamp: Date(),
            messageType: .user
        )
        
        messages.append(userMessage)
        messageCount += 1
        
        // Process AI response
        await processAIResponse(for: content)
    }
    
    public func requestRecommendation() async {
        guard !isProcessingRecommendation else { return }
        
        isProcessingRecommendation = true
        isLoading = true
        
        defer {
            isProcessingRecommendation = false
            isLoading = false
        }
        
        do {
            // Get recent conversation context
            let recentMessages = Array(messages.suffix(5))
            let context = recentMessages.map { "\($0.isUser ? "User" : "AI"): \($0.content)" }.joined(separator: "\n")
            
            // Request AI recommendation
            let recommendation = try await aiRecommendationService.getRecommendation(context: context)
            
            let recommendationMessage = ChatMessageViewModel(
                id: UUID(),
                content: formatRecommendation(recommendation),
                isUser: false,
                timestamp: Date(),
                messageType: .presetRecommendation,
                metadata: recommendation
            )
            
            messages.append(recommendationMessage)
            
        } catch {
            errorMessage = "추천을 가져오는 중 오류가 발생했습니다: \(error.localizedDescription)"
        }
    }
    
    public func loadChatHistory() async {
        // Load existing chat history if available
        // This will be implemented with actual repository in Phase 2
    }
    
    public func clearSession() {
        messages.removeAll()
        messageCount = 0
        currentSessionId = UUID()
        startSession()
    }
    
    // MARK: - Private Methods
    
    private func startSession() {
        sessionStartTime = Date()
        // tokenTracker.resetIfNewDay() // Will be implemented in Phase 2
        
        // Add welcome message
        let welcomeMessage = ChatMessageViewModel(
            id: UUID(),
            content: "안녕하세요! 오늘 기분은 어떠신가요? 편안하게 대화를 나눠보세요 😊",
            isUser: false,
            timestamp: Date(),
            messageType: .system
        )
        
        messages.append(welcomeMessage)
    }
    
    private func processAIResponse(for userMessage: String) async {
        isTyping = true
        
        defer { isTyping = false }
        
        do {
            // Simulate AI processing delay
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Generate AI response based on user message
            let aiResponse = await generateAIResponse(for: userMessage)
            
            let aiMessage = ChatMessageViewModel(
                id: UUID(),
                content: aiResponse,
                isUser: false,
                timestamp: Date(),
                messageType: .aiResponse
            )
            
            messages.append(aiMessage)
            
        } catch {
            errorMessage = "AI 응답을 생성하는 중 오류가 발생했습니다."
        }
    }
    
    private func generateAIResponse(for userMessage: String) async -> String {
        // Analyze emotion from user message
        let emotion = analyzeEmotion(from: userMessage)
        
        // Generate contextual response
        return generateContextualResponse(emotion: emotion, userMessage: userMessage)
    }
    
    private func analyzeEmotion(from message: String) -> String {
        // Simple emotion analysis (will be replaced with actual EmotionAnalyzer)
        let lowerMessage = message.lowercased()
        
        if lowerMessage.contains("피곤") || lowerMessage.contains("힘들") || lowerMessage.contains("지쳐") {
            return "피곤"
        } else if lowerMessage.contains("기쁘") || lowerMessage.contains("행복") || lowerMessage.contains("좋아") {
            return "기쁨"
        } else if lowerMessage.contains("슬프") || lowerMessage.contains("우울") || lowerMessage.contains("마음") {
            return "슬픔"
        } else if lowerMessage.contains("불안") || lowerMessage.contains("걱정") || lowerMessage.contains("두려") {
            return "불안"
        } else if lowerMessage.contains("화") || lowerMessage.contains("짜증") || lowerMessage.contains("분노") {
            return "화남"
        } else {
            return "중립"
        }
    }
    
    private func generateContextualResponse(emotion: String, userMessage: String) -> String {
        switch emotion {
        case "피곤":
            return "많이 피곤하신 것 같네요. 휴식이 필요한 시간이에요. 🌙 편안한 음악과 함께 잠시 쉬어보시는 건 어떨까요?"
        case "기쁨":
            return "기분이 좋으시다니 저도 기뻐요! 😊 이런 좋은 기분을 더 오래 유지할 수 있는 음악을 들어보시겠어요?"
        case "슬픔":
            return "마음이 무거우신 것 같아요. 괜찮아요, 이런 감정도 자연스러운 거예요. 💙 위로가 되는 음악으로 마음을 달래보시면 어떨까요?"
        case "불안":
            return "불안한 마음이 드시는군요. 심호흡을 천천히 해보세요. 🌊 안정감을 주는 자연 소리가 도움이 될 것 같아요."
        case "화남":
            return "화가 많이 나셨나 보네요. 감정을 느끼는 것은 자연스러워요. 🔥 마음을 진정시킬 수 있는 음악을 들어보시겠어요?"
        default:
            return "오늘 하루는 어떠셨나요? 어떤 음악이나 소리가 지금 기분에 맞을지 함께 찾아보아요. 🎵"
        }
    }
    
    private func formatRecommendation(_ recommendation: [String: Any]) -> String {
        // Format AI recommendation into user-friendly message
        let presetName = recommendation["presetName"] as? String ?? "맞춤 프리셋"
        let description = recommendation["description"] as? String ?? "현재 기분에 맞는 사운드입니다"
        
        return "🎵 **\(presetName)** 추천드려요!\n\n\(description)\n\n이 사운드가 지금 기분에 딱 맞을 것 같아요. 사용해보시겠어요?"
    }
}

// MARK: - Chat Message View Model

public struct ChatMessageViewModel: Identifiable, Hashable {
    public let id: UUID
    public let content: String
    public let isUser: Bool
    public let timestamp: Date
    public let messageType: MessageType
    public let metadata: [String: Any]?
    
    public init(
        id: UUID = UUID(),
        content: String,
        isUser: Bool,
        timestamp: Date = Date(),
        messageType: MessageType,
        metadata: [String: Any]? = nil
    ) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.messageType = messageType
        self.metadata = metadata
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: ChatMessageViewModel, rhs: ChatMessageViewModel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Message Types

public enum MessageType: String, CaseIterable {
    case user = "user"
    case aiResponse = "ai_response"
    case system = "system"
    case presetRecommendation = "preset_recommendation"
    case loading = "loading"
    case error = "error"
}

// MARK: - Mock Services (임시)

public struct MockAIRecommendationService: AIRecommendationService {
    public func getRecommendation(context: String) async throws -> [String: Any] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        return [
            "presetName": "편안한 자연음",
            "description": "잔잔한 물소리와 새소리가 마음을 안정시켜줍니다",
            "volumes": [0.6, 0.4, 0.3, 0.2, 0.5],
            "confidence": 0.85
        ]
    }
}

public protocol AIRecommendationService {
    func getRecommendation(context: String) async throws -> [String: Any]
} 