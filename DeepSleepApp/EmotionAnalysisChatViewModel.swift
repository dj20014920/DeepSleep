import Foundation
import Core
import Combine

final class EmotionAnalysisChatViewModel: EmotionAnalysisViewModelProtocol {
    // MARK: - Properties
    private let service: EmotionAnalysisServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // Published 프로퍼티
    @Published private(set) var chatHistory: [(isUser: Bool, message: String)] = []
    @Published private(set) var emotionPatternData: String = ""
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?
    
    // 콜백
    var onLoadingStateChanged: ((Bool) -> Void)?
    var onNewMessageAdded: ((Bool, String) -> Void)?
    var onError: ((Error) -> Void)?
    
    // 내부 상태
    private var currentRecommendationId: String?
    private var lastRecommendedSounds: [EmotionAnalysisServiceSoundComponent] = []
    
    // MARK: - Initialization
    init(service: EmotionAnalysisServiceProtocol) {
        self.service = service
        setupBindings()
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // 로딩 상태 바인딩
        $isLoading
            .sink { [weak self] isLoading in
                self?.onLoadingStateChanged?(isLoading)
            }
            .store(in: &cancellables)
        
        // 에러 바인딩
        $error
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.onError?(error)
            }
            .store(in: &cancellables)
    }
    
    private func setLoading(_ loading: Bool) {
        isLoading = loading
    }
    
    private func handleError(_ error: Error) {
        self.error = error
        setLoading(false)
    }
    
    private func addMessage(isUser: Bool, content: String) {
        let message = (isUser: isUser, message: content)
        chatHistory.append(message)
        onNewMessageAdded?(isUser, content)
    }
    
    // MARK: - Public Methods
    func performInitialAnalysis() async {
        guard !emotionPatternData.isEmpty else {
            addMessage(isUser: false, content: "아직 감정 기록이 충분하지 않네요. 일기를 더 작성해주시면 더 정확한 분석을 도와드릴 수 있어요! 😊")
            return
        }
        
        setLoading(true)
        
        do {
            let result = try await service.analyzeEmotionPattern(emotionPatternData)
            
            await MainActor.run {
                addMessage(isUser: false, content: result.summary)
                setLoading(false)
            }
        } catch {
            await MainActor.run {
                handleError(error)
            }
        }
    }
    
    func sendUserMessage(_ message: String) async {
        addMessage(isUser: true, content: message)
        setLoading(true)
        
        do {
            let response = try await service.generateChatResponse(
                to: message,
                history: chatHistory
            )
            
            await MainActor.run {
                addMessage(isUser: false, content: response)
                setLoading(false)
            }
        } catch {
            await MainActor.run {
                handleError(error)
            }
        }
    }
    
    func handleQuickAction(title: String, intent: String) async {
        addMessage(isUser: true, content: title)
        setLoading(true)
        
        do {
            let tip = try await service.generateQuickTip(for: intent)
            
            await MainActor.run {
                addMessage(isUser: false, content: tip)
                setLoading(false)
            }
        } catch {
            await MainActor.run {
                handleError(error)
            }
        }
    }
    
    func handleAIRecommendation() async {
        setLoading(true)
        
        do {
            let recommendation = try await service.getAIRecommendation()
            
            await MainActor.run {
                currentRecommendationId = recommendation.id
                lastRecommendedSounds = recommendation.components
                
                let message = """
                🎵 AI가 추천하는 사운드 조합:
                
                \(recommendation.title)
                \(recommendation.description)
                
                지금 바로 들어보시겠어요?
                """
                
                addMessage(isUser: false, content: message)
                setLoading(false)
            }
        } catch {
            await MainActor.run {
                handleError(error)
            }
            
            // AI 추천 실패 시 로컬 추천으로 대체
            await handleLocalRecommendation()
        }
    }
    
    func handleLocalRecommendation() async {
        setLoading(true)
        
        do {
            let recommendation = try await service.getLocalRecommendation()
            
            await MainActor.run {
                currentRecommendationId = recommendation.id
                lastRecommendedSounds = recommendation.components
                
                let message = """
                🏠 현재 시간에 맞춘 로컬 추천:
                
                \(recommendation.title)
                \(recommendation.description)
                
                지금 바로 들어보시겠어요?
                """
                
                addMessage(isUser: false, content: message)
                setLoading(false)
            }
        } catch {
            await MainActor.run {
                handleError(error)
            }
        }
    }
    
    func submitFeedback(for recommendationId: String, score: Int, comment: String?) async {
        guard currentRecommendationId == recommendationId else { return }
        
        setLoading(true)
        
        do {
            try await service.saveFeedback(
                recommendationId: recommendationId,
                score: score,
                comment: comment
            )
            
            await MainActor.run {
                let message = "피드백을 주셔서 감사합니다! 더 나은 추천을 위해 소중히 활용하겠습니다. 😊"
                addMessage(isUser: false, content: message)
                setLoading(false)
            }
        } catch {
            await MainActor.run {
                handleError(error)
            }
        }
    }
}

// MARK: - Constants
private extension EmotionAnalysisChatViewModel {
    enum Constants {
        static let maxRetryAttempts = 3
        static let retryDelay: TimeInterval = 1.0
    }
} 