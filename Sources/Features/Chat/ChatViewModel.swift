import Foundation
import Combine
import ComposableArchitecture

// MARK: - Chat Feature (TCA Style)
@Reducer
struct ChatFeature {
    
    // MARK: - State
    @ObservableState
    struct State: Equatable {
        var messages: [ChatMessage] = []
        var currentText: String = ""
        var isLoading: Bool = false
        var error: String?
        var selectedEmotion: EmotionType?
        var soundRecommendations: [SoundRecommendation] = []
        
        // Analysis states
        var sentimentScore: Double = 0.0
        var emotionalContext: String = ""
        var isAnalyzing: Bool = false
        
        // Preset and sharing
        var generatedPresets: [SoundPreset] = []
        var isSharingEnabled: Bool = false
        
        // Performance optimization
        var lastMessageTimestamp: Date = Date()
        var messageCount: Int = 0
        
        // Feedback integration
        var feedbackPrompt: String?
        var showFeedbackAlert: Bool = false
        
        // Typing indicator
        var isTyping: Bool = false
        var typingUsers: Set<String> = []
        
        // Chat session
        var sessionId: String = UUID().uuidString
        var isSessionActive: Bool = true
    }
    
    // MARK: - Action
    enum Action: ViewAction, BindableAction {
        case binding(BindingAction<State>)
        case view(View)
        
        // Internal actions
        case messageReceived(ChatMessage)
        case analysisCompleted(SentimentResult)
        case recommendationsGenerated([SoundRecommendation])
        case presetsGenerated([SoundPreset])
        case errorOccurred(String)
        case feedbackPromptTriggered(String)
        case sessionStarted
        case sessionEnded
        
        @CasePathable
        enum View {
            case sendMessage
            case clearMessages
            case selectEmotion(EmotionType?)
            case regenerateRecommendations
            case sharePreset(SoundPreset)
            case dismissError
            case submitFeedback(String)
            case startNewSession
            case loadPreviousMessages
            case toggleTyping(Bool)
        }
    }
    
    // MARK: - Dependencies
    @Dependency(\.chatRepository) var chatRepository
    @Dependency(\.sentimentAnalyzer) var sentimentAnalyzer
    @Dependency(\.recommendationEngine) var recommendationEngine
    @Dependency(\.presetManager) var presetManager
    @Dependency(\.feedbackManager) var feedbackManager
    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date
    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.logger) var logger
    
    // MARK: - Body
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding(\.currentText):
                // Handle text input changes
                state.isTyping = !state.currentText.isEmpty
                return .none
                
            case .view(.sendMessage):
                return sendMessage(&state)
                
            case .view(.clearMessages):
                state.messages.removeAll()
                state.messageCount = 0
                logger.info("Messages cleared for session: \(state.sessionId)")
                return .none
                
            case let .view(.selectEmotion(emotion)):
                state.selectedEmotion = emotion
                if emotion != nil {
                    return .send(.view(.regenerateRecommendations))
                }
                return .none
                
            case .view(.regenerateRecommendations):
                return regenerateRecommendations(state)
                
            case let .view(.sharePreset(preset)):
                return sharePreset(preset, state: state)
                
            case .view(.dismissError):
                state.error = nil
                return .none
                
            case let .view(.submitFeedback(feedback)):
                return submitFeedback(feedback, state: state)
                
            case .view(.startNewSession):
                return startNewSession(&state)
                
            case .view(.loadPreviousMessages):
                return loadPreviousMessages(state)
                
            case let .view(.toggleTyping(isTyping)):
                state.isTyping = isTyping
                return .none
                
            case let .messageReceived(message):
                return handleMessageReceived(message, state: &state)
                
            case let .analysisCompleted(result):
                return handleAnalysisCompleted(result, state: &state)
                
            case let .recommendationsGenerated(recommendations):
                state.soundRecommendations = recommendations
                state.isLoading = false
                logger.info("Generated \(recommendations.count) recommendations")
                return .none
                
            case let .presetsGenerated(presets):
                state.generatedPresets = presets
                logger.info("Generated \(presets.count) presets")
                return .none
                
            case let .errorOccurred(error):
                state.error = error
                state.isLoading = false
                state.isAnalyzing = false
                logger.error("Error occurred: \(error)")
                return .none
                
            case let .feedbackPromptTriggered(prompt):
                state.feedbackPrompt = prompt
                state.showFeedbackAlert = true
                return .none
                
            case .sessionStarted:
                state.sessionId = uuid().uuidString
                state.isSessionActive = true
                state.lastMessageTimestamp = date()
                logger.info("New session started: \(state.sessionId)")
                return .none
                
            case .sessionEnded:
                state.isSessionActive = false
                logger.info("Session ended: \(state.sessionId)")
                return .none
                
            case .binding:
                return .none
            }
        }
        .onChange(of: \.messageCount) { oldValue, newValue in
            Reduce { state, action in
                // Trigger feedback prompt every 5 messages
                if newValue > 0 && newValue % 5 == 0 {
                    return .send(.feedbackPromptTriggered("How are the recommendations helping you?"))
                }
                return .none
            }
        }
    }
}

// MARK: - Private Methods
private extension ChatFeature {
    
    func sendMessage(_ state: inout State) -> Effect<Action> {
        guard !state.currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .none
        }
        
        let userMessage = ChatMessage(
            id: uuid(),
            content: state.currentText,
            type: .user,
            timestamp: date(),
            emotion: state.selectedEmotion
        )
        
        state.messages.append(userMessage)
        state.messageCount += 1
        state.lastMessageTimestamp = date()
        let messageText = state.currentText
        state.currentText = ""
        state.isLoading = true
        state.isAnalyzing = true
        state.isTyping = false
        
        logger.info("User message sent: \(messageText)")
        
        return .run { send in
            do {
                // Parallel execution of analysis and AI response
                async let sentimentResult = sentimentAnalyzer.analyze(messageText)
                async let aiResponse = chatRepository.sendMessage(messageText, emotion: state.selectedEmotion)
                
                let (sentiment, response) = try await (sentimentResult, aiResponse)
                
                await send(.analysisCompleted(sentiment))
                await send(.messageReceived(response))
                
                // Generate recommendations based on analysis
                let recommendations = try await recommendationEngine.generateRecommendations(
                    sentiment: sentiment,
                    emotion: state.selectedEmotion,
                    context: messageText
                )
                await send(.recommendationsGenerated(recommendations))
                
                // Generate presets if sentiment is significant
                if abs(sentiment.score) > 0.5 {
                    let presets = try await presetManager.generatePresets(
                        basedOn: recommendations,
                        emotion: state.selectedEmotion
                    )
                    await send(.presetsGenerated(presets))
                }
                
            } catch {
                await send(.errorOccurred(error.localizedDescription))
            }
        }
    }
    
    func regenerateRecommendations(_ state: State) -> Effect<Action> {
        guard let emotion = state.selectedEmotion else {
            return .send(.errorOccurred("Please select an emotion first"))
        }
        
        let recentMessages = state.messages.suffix(5).map(\.content).joined(separator: " ")
        
        return .run { send in
            do {
                let recommendations = try await recommendationEngine.generateRecommendations(
                    emotion: emotion,
                    context: recentMessages,
                    preferredCount: 6
                )
                await send(.recommendationsGenerated(recommendations))
            } catch {
                await send(.errorOccurred("Failed to regenerate recommendations: \(error.localizedDescription)"))
            }
        }
    }
    
    func sharePreset(_ preset: SoundPreset, state: State) -> Effect<Action> {
        guard state.isSharingEnabled else {
            return .send(.errorOccurred("Sharing is not enabled"))
        }
        
        return .run { send in
            do {
                try await presetManager.sharePreset(preset)
                logger.info("Preset shared successfully: \(preset.name)")
            } catch {
                await send(.errorOccurred("Failed to share preset: \(error.localizedDescription)"))
            }
        }
    }
    
    func submitFeedback(_ feedback: String, state: State) -> Effect<Action> {
        return .run { send in
            do {
                try await feedbackManager.submitFeedback(
                    feedback,
                    sessionId: state.sessionId,
                    context: state.messages.suffix(3).map(\.content).joined(separator: "\n")
                )
                logger.info("Feedback submitted successfully")
            } catch {
                await send(.errorOccurred("Failed to submit feedback: \(error.localizedDescription)"))
            }
        }
    }
    
    func startNewSession(_ state: inout State) -> Effect<Action> {
        state.messages.removeAll()
        state.messageCount = 0
        state.currentText = ""
        state.error = nil
        state.soundRecommendations.removeAll()
        state.generatedPresets.removeAll()
        state.isLoading = false
        state.isAnalyzing = false
        state.selectedEmotion = nil
        
        return .send(.sessionStarted)
    }
    
    func loadPreviousMessages(_ state: State) -> Effect<Action> {
        return .run { send in
            do {
                let messages = try await chatRepository.loadPreviousMessages(sessionId: state.sessionId)
                for message in messages {
                    await send(.messageReceived(message))
                }
            } catch {
                await send(.errorOccurred("Failed to load previous messages: \(error.localizedDescription)"))
            }
        }
    }
    
    func handleMessageReceived(_ message: ChatMessage, state: inout State) -> Effect<Action> {
        state.messages.append(message)
        if message.type == .ai {
            state.isLoading = false
        }
        state.lastMessageTimestamp = date()
        
        logger.info("Message received: \(message.type.rawValue)")
        return .none
    }
    
    func handleAnalysisCompleted(_ result: SentimentResult, state: inout State) -> Effect<Action> {
        state.sentimentScore = result.score
        state.emotionalContext = result.context
        state.isAnalyzing = false
        
        logger.info("Sentiment analysis completed: score=\(result.score)")
        return .none
    }
}

// MARK: - Legacy ViewModel for Migration Support
@Observable
class ChatViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var messages: [ChatMessage] = []
    @Published var currentText: String = ""
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var selectedEmotion: EmotionType?
    @Published var soundRecommendations: [SoundRecommendation] = []
    @Published var sentimentScore: Double = 0.0
    @Published var emotionalContext: String = ""
    @Published var isAnalyzing: Bool = false
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let store: StoreOf<ChatFeature>
    
    // MARK: - Dependencies (Legacy)
    private let chatRepository: ChatRepository
    private let sentimentAnalyzer: SentimentAnalyzer
    private let recommendationEngine: RecommendationEngine
    
    // MARK: - Initialization
    init(
        chatRepository: ChatRepository = ChatRepositoryImpl(),
        sentimentAnalyzer: SentimentAnalyzer = SentimentAnalyzerImpl(),
        recommendationEngine: RecommendationEngine = RecommendationEngineImpl()
    ) {
        self.chatRepository = chatRepository
        self.sentimentAnalyzer = sentimentAnalyzer
        self.recommendationEngine = recommendationEngine
        
        // Initialize TCA store
        self.store = Store(initialState: ChatFeature.State()) {
            ChatFeature()
        }
        
        // Bind TCA state to legacy properties
        setupStateBinding()
    }
    
    // MARK: - Legacy Methods
    func sendMessage() {
        store.send(.view(.sendMessage))
    }
    
    func clearMessages() {
        store.send(.view(.clearMessages))
    }
    
    func selectEmotion(_ emotion: EmotionType?) {
        store.send(.view(.selectEmotion(emotion)))
    }
    
    func regenerateRecommendations() {
        store.send(.view(.regenerateRecommendations))
    }
    
    func dismissError() {
        store.send(.view(.dismissError))
    }
    
    // MARK: - Private Methods
    private func setupStateBinding() {
        store.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateFromState(state)
            }
            .store(in: &cancellables)
    }
    
    private func updateFromState(_ state: ChatFeature.State) {
        messages = state.messages
        currentText = state.currentText
        isLoading = state.isLoading
        error = state.error
        selectedEmotion = state.selectedEmotion
        soundRecommendations = state.soundRecommendations
        sentimentScore = state.sentimentScore
        emotionalContext = state.emotionalContext
        isAnalyzing = state.isAnalyzing
    }
}

// MARK: - Dependencies
extension DependencyValues {
    var chatRepository: ChatRepository {
        get { self[ChatRepositoryKey.self] }
        set { self[ChatRepositoryKey.self] = newValue }
    }
    
    var sentimentAnalyzer: SentimentAnalyzer {
        get { self[SentimentAnalyzerKey.self] }
        set { self[SentimentAnalyzerKey.self] = newValue }
    }
    
    var recommendationEngine: RecommendationEngine {
        get { self[RecommendationEngineKey.self] }
        set { self[RecommendationEngineKey.self] = newValue }
    }
    
    var presetManager: PresetManager {
        get { self[PresetManagerKey.self] }
        set { self[PresetManagerKey.self] = newValue }
    }
    
    var feedbackManager: FeedbackManager {
        get { self[FeedbackManagerKey.self] }
        set { self[FeedbackManagerKey.self] = newValue }
    }
    
    var logger: Logger {
        get { self[LoggerKey.self] }
        set { self[LoggerKey.self] = newValue }
    }
}

// MARK: - Dependency Keys
private enum ChatRepositoryKey: DependencyKey {
    static let liveValue: ChatRepository = ChatRepositoryImpl()
}

private enum SentimentAnalyzerKey: DependencyKey {
    static let liveValue: SentimentAnalyzer = SentimentAnalyzerImpl()
}

private enum RecommendationEngineKey: DependencyKey {
    static let liveValue: RecommendationEngine = RecommendationEngineImpl()
}

private enum PresetManagerKey: DependencyKey {
    static let liveValue: PresetManager = PresetManagerImpl()
}

private enum FeedbackManagerKey: DependencyKey {
    static let liveValue: FeedbackManager = FeedbackManagerImpl()
}

private enum LoggerKey: DependencyKey {
    static let liveValue: Logger = LoggerImpl()
}

// MARK: - Supporting Types
struct SentimentResult: Equatable {
    let score: Double
    let context: String
    let confidence: Double
}

struct SoundRecommendation: Equatable, Identifiable {
    let id: UUID
    let soundName: String
    let description: String
    let emotionMatch: Double
    let filePath: String
}

struct SoundPreset: Equatable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let sounds: [String]
    let emotion: EmotionType?
}

// MARK: - Protocol Definitions
protocol ChatRepository {
    func sendMessage(_ text: String, emotion: EmotionType?) async throws -> ChatMessage
    func loadPreviousMessages(sessionId: String) async throws -> [ChatMessage]
}

protocol SentimentAnalyzer {
    func analyze(_ text: String) async throws -> SentimentResult
}

protocol RecommendationEngine {
    func generateRecommendations(sentiment: SentimentResult, emotion: EmotionType?, context: String) async throws -> [SoundRecommendation]
    func generateRecommendations(emotion: EmotionType, context: String, preferredCount: Int) async throws -> [SoundRecommendation]
}

protocol PresetManager {
    func generatePresets(basedOn recommendations: [SoundRecommendation], emotion: EmotionType?) async throws -> [SoundPreset]
    func sharePreset(_ preset: SoundPreset) async throws
}

protocol FeedbackManager {
    func submitFeedback(_ feedback: String, sessionId: String, context: String) async throws
}

protocol Logger {
    func info(_ message: String)
    func error(_ message: String)
}

// MARK: - Implementation Stubs
class ChatRepositoryImpl: ChatRepository {
    func sendMessage(_ text: String, emotion: EmotionType?) async throws -> ChatMessage {
        // Implementation here
        return ChatMessage(id: UUID(), content: "AI Response", type: .ai, timestamp: Date())
    }
    
    func loadPreviousMessages(sessionId: String) async throws -> [ChatMessage] {
        // Implementation here
        return []
    }
}

class SentimentAnalyzerImpl: SentimentAnalyzer {
    func analyze(_ text: String) async throws -> SentimentResult {
        // Implementation here
        return SentimentResult(score: 0.0, context: text, confidence: 0.8)
    }
}

class RecommendationEngineImpl: RecommendationEngine {
    func generateRecommendations(sentiment: SentimentResult, emotion: EmotionType?, context: String) async throws -> [SoundRecommendation] {
        // Implementation here
        return []
    }
    
    func generateRecommendations(emotion: EmotionType, context: String, preferredCount: Int) async throws -> [SoundRecommendation] {
        // Implementation here
        return []
    }
}

class PresetManagerImpl: PresetManager {
    func generatePresets(basedOn recommendations: [SoundRecommendation], emotion: EmotionType?) async throws -> [SoundPreset] {
        // Implementation here
        return []
    }
    
    func sharePreset(_ preset: SoundPreset) async throws {
        // Implementation here
    }
}

class FeedbackManagerImpl: FeedbackManager {
    func submitFeedback(_ feedback: String, sessionId: String, context: String) async throws {
        // Implementation here
    }
}

class LoggerImpl: Logger {
    func info(_ message: String) {
        print("ℹ️ \(message)")
    }
    
    func error(_ message: String) {
        print("❌ \(message)")
    }
} 