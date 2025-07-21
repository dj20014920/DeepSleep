import Foundation

/// 🔄 통합 컨텍스트 관리자
/// 모든 AI 모델 간 대화 맥락을 공유하고 관리하는 핵심 시스템
/// PERF-WARNING: 모델 전환 시 컨텍스트 준비는 CPU 집약적일 수 있음
/// - 테스트 방안: Instruments의 Time Profiler로 전환 시간 측정
public final class UnifiedContextManager {
    public static let shared = UnifiedContextManager()
    
    // MARK: - Properties
    
    /// 현재 활성 세션의 공유 컨텍스트
    private var sharedContext: SharedContext
    
    /// 모델별 컨텍스트 어댑터
    private var modelAdapters: [AIModelType: ContextAdapter] = [:]
    
    /// 컨텍스트 업데이트를 위한 동시성 큐
    private let contextQueue = DispatchQueue(label: "com.deepsleep.unifiedcontext", attributes: .concurrent)
    
    /// 최대 컨텍스트 크기 (토큰 수)
    private let maxContextSize = 4000
    
    private init() {
        self.sharedContext = SharedContext()
        setupModelAdapters()
    }
    
    // MARK: - Public Methods
    
    /// 🎯 새로운 메시지 추가
    func addMessage(_ message: ContextMessage) {
        contextQueue.async(flags: .barrier) {
            self.sharedContext.messages.append(message)
            self.sharedContext.lastUpdated = Date()
            
            // 컨텍스트 크기 관리
            self.trimContextIfNeeded()
        }
    }
    
    /// 🔄 모델 전환 시 컨텍스트 준비
    func prepareContextForModel(_ modelType: AIModelType, previousModel: AIModelType? = nil) -> ModelContext {
        return contextQueue.sync {
            let adapter = modelAdapters[modelType] ?? DefaultContextAdapter()
            
            // 기본 컨텍스트 생성
            var context = adapter.adapt(sharedContext)
            
            // 모델 전환 정보 추가
            if let previousModel = previousModel {
                context.systemPrompt = generateModelSwitchPrompt(
                    from: previousModel,
                    to: modelType,
                    withSummary: context.conversationSummary
                )
            }
            
            print("🔄 [UnifiedContextManager] \(modelType.rawValue) 모델용 컨텍스트 준비 완료")
            return context
        }
    }
    
    /// 📊 현재 세션 요약 가져오기
    func getCurrentSessionSummary() -> SessionSummary {
        return contextQueue.sync {
            generateSessionSummary(from: sharedContext)
        }
    }
    
    /// 🗑️ 컨텍스트 초기화
    func clearContext() {
        contextQueue.async(flags: .barrier) {
            self.sharedContext = SharedContext()
            print("🗑️ [UnifiedContextManager] 컨텍스트 초기화됨")
        }
    }
    
    /// 💾 컨텍스트 저장 (세션 종료 시)
    func saveContext() async throws {
        let contextToSave = contextQueue.sync { self.sharedContext }
        
        // DailyConversationManager와 연동
        let conversation = DailyConversation(
            emotionContext: contextToSave.currentEmotionContext,
            messages: contextToSave.messages.map { convertToConversationMessage($0) }
        )
        
        try await DailyConversationManager.shared.saveTodaysConversation(conversation)
        print("💾 [UnifiedContextManager] 컨텍스트 저장 완료")
    }
    
    // MARK: - Private Methods
    
    private func setupModelAdapters() {
        modelAdapters[.claude35] = Claude35ContextAdapter()
        modelAdapters[.gpt4] = GPT4ContextAdapter()
        modelAdapters[.gemini] = GeminiContextAdapter()
        modelAdapters[.onDevice] = OnDeviceContextAdapter()
    }
    
    private func trimContextIfNeeded() {
        // 토큰 수 추정 (한글 평균 2자 = 1토큰)
        let estimatedTokens = sharedContext.messages.reduce(0) { total, message in
            total + (message.content.count / 2)
        }
        
        if estimatedTokens > maxContextSize {
            // 중요도 기반 메시지 필터링
            let importantMessages = filterImportantMessages(from: sharedContext.messages)
            sharedContext.messages = Array(importantMessages.suffix(20)) // 최대 20개
            print("⚠️ [UnifiedContextManager] 컨텍스트 크기 초과로 트리밍 실행")
        }
    }
    
    private func filterImportantMessages(from messages: [ContextMessage]) -> [ContextMessage] {
        return messages.filter { message in
            // 감정적 메시지, 목표 설정, 피드백 우선
            message.importance >= 0.7 ||
            message.type == .emotional ||
            message.type == .goal ||
            message.type == .feedback
        }
    }
    
    private func generateModelSwitchPrompt(from: AIModelType, to: AIModelType, withSummary: String) -> String {
        return """
        🔄 모델 전환 안내
        
        사용자가 \(from.displayName)에서 \(to.displayName)로 AI 모델을 변경했습니다.
        
        이전 대화 요약:
        \(withSummary)
        
        위 맥락을 이해하고 자연스럽게 대화를 이어가세요.
        사용자가 모델을 변경했다는 사실을 굳이 언급할 필요는 없습니다.
        이전 대화의 감정과 주제를 고려하여 응답하세요.
        """
    }
    
    private func generateSessionSummary(from context: SharedContext) -> SessionSummary {
        let recentMessages = Array(context.messages.suffix(10))
        
        // 주요 주제 추출
        let topics = extractTopics(from: recentMessages)
        
        // 감정 패턴 분석
        let emotionPattern = analyzeEmotionPattern(from: recentMessages)
        
        // 사용자 목표 추출
        let userGoals = extractUserGoals(from: recentMessages)
        
        return SessionSummary(
            messageCount: context.messages.count,
            duration: Date().timeIntervalSince(context.sessionStartTime),
            mainTopics: topics,
            emotionPattern: emotionPattern,
            userGoals: userGoals,
            lastActivity: context.lastUpdated
        )
    }
    
    private func extractTopics(from messages: [ContextMessage]) -> [String] {
        // 간단한 키워드 추출 (실제로는 더 정교한 NLP 필요)
        var topicCounts: [String: Int] = [:]
        
        let keywords = ["불면증", "스트레스", "불안", "우울", "피로", "걱정", "수면", "꿈", "휴식"]
        
        for message in messages {
            for keyword in keywords {
                if message.content.contains(keyword) {
                    topicCounts[keyword, default: 0] += 1
                }
            }
        }
        
        return topicCounts
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
    }
    
    private func analyzeEmotionPattern(from messages: [ContextMessage]) -> EmotionPattern {
        let emotions = messages.compactMap { $0.detectedEmotion }
        
        guard !emotions.isEmpty else {
            return EmotionPattern(primary: "중립", intensity: 0.5, trend: .stable)
        }
        
        // 최빈 감정 찾기
        let emotionCounts = emotions.reduce(into: [:]) { counts, emotion in
            counts[emotion.type, default: 0] += 1
        }
        
        let primaryEmotion = emotionCounts.max { $0.value < $1.value }?.key ?? "중립"
        
        // 감정 강도 평균
        let avgIntensity = emotions.reduce(0.0) { $0 + $1.intensity } / Double(emotions.count)
        
        // 감정 추세 분석 (최근 vs 이전)
        let recentEmotions = Array(emotions.suffix(3))
        let previousEmotions = Array(emotions.dropLast(3).suffix(3))
        
        let recentAvg = recentEmotions.isEmpty ? 0.5 : 
            recentEmotions.reduce(0.0) { $0 + $1.intensity } / Double(recentEmotions.count)
        let previousAvg = previousEmotions.isEmpty ? 0.5 :
            previousEmotions.reduce(0.0) { $0 + $1.intensity } / Double(previousEmotions.count)
        
        let trend: EmotionTrend = {
            if recentAvg > previousAvg + 0.1 { return .improving }
            else if recentAvg < previousAvg - 0.1 { return .worsening }
            else { return .stable }
        }()
        
        return EmotionPattern(
            primary: primaryEmotion,
            intensity: avgIntensity,
            trend: trend
        )
    }
    
    private func extractUserGoals(from messages: [ContextMessage]) -> [String] {
        return messages
            .filter { $0.type == .goal }
            .map { $0.content }
            .suffix(3)
            .map { String($0.prefix(50)) } // 요약
    }
    
    private func convertToConversationMessage(_ contextMessage: ContextMessage) -> ConversationMessage {
        return ConversationMessage(
            content: contextMessage.content,
            isFromUser: contextMessage.isFromUser,
            emotionIntensity: contextMessage.detectedEmotion?.intensity,
            messageType: mapMessageType(contextMessage.type)
        )
    }
    
    private func mapMessageType(_ type: ContextMessageType) -> ConversationMessageType {
        switch type {
        case .normal: return .normal
        case .emotional: return .emotional
        case .goal: return .goal
        case .feedback: return .feedback
        case .system: return .systemResponse
        }
    }
}

// MARK: - Data Models

/// 🎯 공유 컨텍스트
struct SharedContext {
    var messages: [ContextMessage] = []
    var currentEmotionContext: EmotionContext
    var sessionStartTime: Date = Date()
    var lastUpdated: Date = Date()
    var sessionMetadata: [String: Any] = [:]
    
    init() {
        self.currentEmotionContext = EmotionContext(
            primaryEmotion: "중립",
            intensity: 0.5
        )
    }
}

/// 📊 세션 요약
struct SessionSummary {
    let messageCount: Int
    let duration: TimeInterval
    let mainTopics: [String]
    let emotionPattern: EmotionPattern
    let userGoals: [String]
    let lastActivity: Date
}

/// 🎭 감정 패턴
struct EmotionPattern {
    let primary: String
    let intensity: Double
    let trend: EmotionTrend
}

/// 📈 감정 추세
enum EmotionTrend {
    case improving
    case stable
    case worsening
}

/// 🎭 감정 컨텍스트
struct EmotionContext {
    let primaryEmotion: String
    let intensity: Double
}

// MARK: - Context Adapters

/// 🔌 컨텍스트 어댑터 프로토콜
protocol ContextAdapter {
    func adapt(_ sharedContext: SharedContext) -> ModelContext
}

/// Claude 3.5용 어댑터
class Claude35ContextAdapter: ContextAdapter {
    func adapt(_ sharedContext: SharedContext) -> ModelContext {
        let messages = sharedContext.messages.suffix(20).map { msg in
            (role: msg.isFromUser ? "user" : "assistant",
             content: msg.content)
        }
        
        let summary = "감정 중심 대화. 주요 감정: \(sharedContext.currentEmotionContext.primaryEmotion)"
        
        return ModelContext(
            messages: messages,
            systemPrompt: "당신은 공감 능력이 뛰어난 AI 상담사입니다.",
            conversationSummary: summary,
            tokenCount: messages.reduce(0) { $0 + $1.content.count / 2 },
            metadata: [:]
        )
    }
}

/// GPT-4용 어댑터
class GPT4ContextAdapter: ContextAdapter {
    func adapt(_ sharedContext: SharedContext) -> ModelContext {
        // GPT-4 특화 포맷팅
        let messages = sharedContext.messages.suffix(15).map { msg in
            (role: msg.isFromUser ? "user" : "assistant",
             content: formatForGPT4(msg.content))
        }
        
        return ModelContext(
            messages: messages,
            systemPrompt: "You are an empathetic AI counselor specializing in emotional support.",
            conversationSummary: generateGPT4Summary(sharedContext),
            tokenCount: messages.reduce(0) { $0 + $1.content.count / 2 },
            metadata: ["temperature": 0.7]
        )
    }
    
    private func formatForGPT4(_ content: String) -> String {
        // GPT-4에 최적화된 포맷
        return content
    }
    
    private func generateGPT4Summary(_ context: SharedContext) -> String {
        return "Emotional conversation focused on \(context.currentEmotionContext.primaryEmotion)"
    }
}

/// Gemini용 어댑터
class GeminiContextAdapter: ContextAdapter {
    func adapt(_ sharedContext: SharedContext) -> ModelContext {
        // Gemini 특화 - 더 긴 컨텍스트 허용
        let messages = sharedContext.messages.suffix(30).map { msg in
            (role: msg.isFromUser ? "user" : "model",
             content: msg.content)
        }
        
        return ModelContext(
            messages: messages,
            systemPrompt: "감정 지원에 특화된 AI입니다.",
            conversationSummary: generateGeminiSummary(sharedContext),
            tokenCount: messages.reduce(0) { $0 + $1.content.count / 2 },
            metadata: ["safety_settings": "medium"]
        )
    }
    
    private func generateGeminiSummary(_ context: SharedContext) -> String {
        return "대화 맥락: \(context.currentEmotionContext.primaryEmotion) 관련 상담"
    }
}

/// 온디바이스 AI용 어댑터
class OnDeviceContextAdapter: ContextAdapter {
    func adapt(_ sharedContext: SharedContext) -> ModelContext {
        // 온디바이스는 제한된 컨텍스트만
        let messages = sharedContext.messages.suffix(5).map { msg in
            (role: msg.isFromUser ? "user" : "assistant",
             content: String(msg.content.prefix(200))) // 압축
        }
        
        return ModelContext(
            messages: messages,
            systemPrompt: "간단명료하게 응답하세요.",
            conversationSummary: "최근 대화 요약",
            tokenCount: messages.reduce(0) { $0 + $1.content.count / 2 },
            metadata: ["max_length": 100]
        )
    }
}

/// 기본 어댑터
class DefaultContextAdapter: ContextAdapter {
    func adapt(_ sharedContext: SharedContext) -> ModelContext {
        let messages = sharedContext.messages.suffix(10).map { msg in
            (role: msg.isFromUser ? "user" : "assistant",
             content: msg.content)
        }
        
        return ModelContext(
            messages: messages,
            systemPrompt: "AI 어시스턴트입니다.",
            conversationSummary: "대화 진행 중",
            tokenCount: messages.reduce(0) { $0 + $1.content.count / 2 },
            metadata: [:]
        )
    }
}