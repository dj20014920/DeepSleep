import Foundation

/// 🔄 모델 전환 관리자
/// AI 모델 간 전환을 매끄럽게 처리하고 컨텍스트를 유지하는 시스템
public final class ModelSwitchingManager {
    public static let shared = ModelSwitchingManager()
    
    // MARK: - Properties
    
    /// 현재 활성 모델
    private(set) var currentModel: AIModelType = .claude35
    
    /// 모델 전환 히스토리
    private var switchHistory: [ModelSwitchEvent] = []
    
    /// 전환 중 상태
    private(set) var isSwitching = false
    
    /// 델리게이트 (UI 업데이트용)
    weak var delegate: ModelSwitchingDelegate?
    
    private let switchQueue = DispatchQueue(label: "com.deepsleep.modelswitching")
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 🎯 모델 전환 실행
    @MainActor
    func switchToModel(_ newModel: AIModelType) async throws {
        guard newModel != currentModel else {
            print("⚠️ [ModelSwitchingManager] 동일한 모델로 전환 시도 무시")
            return
        }
        
        guard !isSwitching else {
            throw ModelSwitchError.alreadySwitching
        }
        
        isSwitching = true
        delegate?.modelSwitchingWillBegin(from: currentModel, to: newModel)
        
        do {
            // 1. 현재 세션 저장
            await saveCurrentSession()
            
            // 2. 컨텍스트 준비
            let modelContext = await prepareContextForNewModel(newModel)
            
            // 3. 모델 전환 실행
            try await performModelSwitch(to: newModel, with: modelContext)
            
            // 4. 전환 기록
            recordSwitchEvent(from: currentModel, to: newModel)
            
            // 5. UI 업데이트
            let previousModel = currentModel
            currentModel = newModel
            
            delegate?.modelSwitchingDidComplete(from: previousModel, to: newModel)
            
            print("✅ [ModelSwitchingManager] \(previousModel.displayName) → \(newModel.displayName) 전환 완료")
            
        } catch {
            isSwitching = false
            delegate?.modelSwitchingDidFail(error: error)
            throw error
        }
        
        isSwitching = false
    }
    
    /// 📊 전환 가능 여부 확인
    func canSwitchToModel(_ model: AIModelType) -> Bool {
        // 온디바이스 모델은 네트워크 상태와 무관
        if model == .onDevice {
            return true
        }
        
        // 네트워크 연결 상태 확인
        return NetworkMonitor.shared.isConnected
    }
    
    /// 🎭 현재 모델에 맞는 시스템 프롬프트 가져오기
    func getSystemPrompt(for model: AIModelType? = nil) -> String {
        let targetModel = model ?? currentModel
        
        switch targetModel {
        case .claude35:
            return """
            당신은 DeepSleep 앱의 감정 상담 AI입니다.
            사용자의 감정을 깊이 이해하고 공감하며, 수면 개선을 위한 맞춤형 조언을 제공합니다.
            항상 따뜻하고 이해심 있는 태도로 대화하세요.
            """
            
        case .gpt4:
            return """
            You are an empathetic AI counselor for the DeepSleep app.
            Focus on understanding users' emotions and providing personalized sleep improvement advice.
            Maintain a warm and understanding tone throughout the conversation.
            """
            
        case .gemini:
            return """
            DeepSleep 앱의 AI 상담사로서 사용자의 감정과 수면 문제를 도와드립니다.
            과학적 근거와 함께 실용적인 조언을 제공하며, 공감적인 대화를 이어갑니다.
            """
            
        case .onDevice:
            return """
            간결하고 실용적인 수면 도우미입니다.
            핵심만 전달하며 즉각적인 도움을 제공합니다.
            """
        }
    }
    
    /// 🔍 모델별 특성 정보
    func getModelCharacteristics(_ model: AIModelType) -> ModelCharacteristics {
        switch model {
        case .claude35:
            return ModelCharacteristics(
                name: "Claude 3.5 Sonnet",
                strengths: ["깊은 공감 능력", "자연스러운 한국어", "긴 대화 맥락 이해"],
                contextWindow: 200_000,
                responseStyle: .empathetic,
                costPerMillionTokens: 3.0
            )
            
        case .gpt4:
            return ModelCharacteristics(
                name: "GPT-4",
                strengths: ["논리적 분석", "다국어 지원", "창의적 해결책"],
                contextWindow: 128_000,
                responseStyle: .analytical,
                costPerMillionTokens: 10.0
            )
            
        case .gemini:
            return ModelCharacteristics(
                name: "Gemini Pro",
                strengths: ["빠른 응답", "멀티모달", "실시간 정보"],
                contextWindow: 1_000_000,
                responseStyle: .informative,
                costPerMillionTokens: 0.5
            )
            
        case .onDevice:
            return ModelCharacteristics(
                name: "온디바이스 AI",
                strengths: ["완전한 프라이버시", "오프라인 작동", "즉각 응답"],
                contextWindow: 4_000,
                responseStyle: .concise,
                costPerMillionTokens: 0.0
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func saveCurrentSession() async {
        do {
            // 현재 대화 저장
            try await UnifiedContextManager.shared.saveContext()
            
            // ChatManager에도 동기화
            if let currentSession = ChatManager.shared.getCurrentOrCreateSession() {
                ChatManager.shared.saveSessionToDisk(currentSession)
            }
            
            print("💾 [ModelSwitchingManager] 현재 세션 저장 완료")
        } catch {
            print("❌ [ModelSwitchingManager] 세션 저장 실패: \(error)")
        }
    }
    
    private func prepareContextForNewModel(_ newModel: AIModelType) async -> ModelContext {
        let context = UnifiedContextManager.shared.prepareContextForModel(
            newModel,
            previousModel: currentModel
        )
        
        // 모델별 추가 처리
        switch newModel {
        case .onDevice:
            // 온디바이스는 컨텍스트 압축 필요
            return compressContextForOnDevice(context)
            
        case .gemini:
            // Gemini는 안전 설정 추가
            var modifiedContext = context
            modifiedContext.metadata["safety_level"] = "balanced"
            return modifiedContext
            
        default:
            return context
        }
    }
    
    private func performModelSwitch(to newModel: AIModelType, with context: ModelContext) async throws {
        // 실제 모델 전환 로직 (API 설정 등)
        switch newModel {
        case .claude35:
            try await configureClaude(with: context)
        case .gpt4:
            try await configureGPT4(with: context)
        case .gemini:
            try await configureGemini(with: context)
        case .onDevice:
            try await configureOnDevice(with: context)
        }
    }
    
    private func configureClaude(with context: ModelContext) async throws {
        // Claude API 설정
        guard let apiKey = EnvironmentConfig.shared.claudeAPIKey else {
            throw ModelSwitchError.missingAPIKey("Claude")
        }
        
        // LLMRouter에 설정 전달
        await LLMRouter.shared.updateConfiguration(
            model: .claude35,
            apiKey: apiKey,
            context: context
        )
    }
    
    private func configureGPT4(with context: ModelContext) async throws {
        // GPT-4 API 설정
        guard let apiKey = EnvironmentConfig.shared.openAIAPIKey else {
            throw ModelSwitchError.missingAPIKey("OpenAI")
        }
        
        await LLMRouter.shared.updateConfiguration(
            model: .gpt4,
            apiKey: apiKey,
            context: context
        )
    }
    
    private func configureGemini(with context: ModelContext) async throws {
        // Gemini API 설정
        guard let apiKey = EnvironmentConfig.shared.geminiAPIKey else {
            throw ModelSwitchError.missingAPIKey("Gemini")
        }
        
        await LLMRouter.shared.updateConfiguration(
            model: .gemini,
            apiKey: apiKey,
            context: context
        )
    }
    
    private func configureOnDevice(with context: ModelContext) async throws {
        // 온디바이스 모델 설정
        await LLMRouter.shared.updateConfiguration(
            model: .onDevice,
            apiKey: nil, // 온디바이스는 API 키 불필요
            context: context
        )
    }
    
    private func compressContextForOnDevice(_ context: ModelContext) -> ModelContext {
        // 온디바이스 모델을 위한 컨텍스트 압축
        let compressedMessages = context.messages.suffix(5).map { msg in
            (role: msg.role, content: String(msg.content.prefix(200)))
        }
        
        return ModelContext(
            messages: compressedMessages,
            systemPrompt: context.systemPrompt,
            conversationSummary: String(context.conversationSummary.prefix(100)),
            tokenCount: compressedMessages.reduce(0) { $0 + $1.content.count / 2 },
            metadata: context.metadata
        )
    }
    
    private func recordSwitchEvent(from: AIModelType, to: AIModelType) {
        let event = ModelSwitchEvent(
            timestamp: Date(),
            fromModel: from,
            toModel: to,
            reason: .userInitiated,
            contextPreserved: true
        )
        
        switchQueue.async {
            self.switchHistory.append(event)
            
            // 최대 50개만 유지
            if self.switchHistory.count > 50 {
                self.switchHistory.removeFirst()
            }
        }
    }
}

// MARK: - Supporting Types

/// 🔄 모델 전환 이벤트
struct ModelSwitchEvent {
    let timestamp: Date
    let fromModel: AIModelType
    let toModel: AIModelType
    let reason: SwitchReason
    let contextPreserved: Bool
}

/// 🎯 전환 사유
enum SwitchReason {
    case userInitiated
    case costOptimization
    case performanceIssue
    case networkUnavailable
    case quotaExceeded
}

/// 📊 모델 특성
struct ModelCharacteristics {
    let name: String
    let strengths: [String]
    let contextWindow: Int
    let responseStyle: ResponseStyle
    let costPerMillionTokens: Double
}

/// 💬 응답 스타일
enum ResponseStyle {
    case empathetic    // 공감적
    case analytical    // 분석적
    case informative   // 정보 제공
    case concise       // 간결
}

/// ❌ 모델 전환 에러
enum ModelSwitchError: LocalizedError {
    case alreadySwitching
    case missingAPIKey(String)
    case networkUnavailable
    case contextPreparationFailed
    case modelUnavailable(String)
    
    var errorDescription: String? {
        switch self {
        case .alreadySwitching:
            return "이미 모델 전환이 진행 중입니다"
        case .missingAPIKey(let model):
            return "\(model) API 키가 설정되지 않았습니다"
        case .networkUnavailable:
            return "네트워크 연결이 필요합니다"
        case .contextPreparationFailed:
            return "컨텍스트 준비에 실패했습니다"
        case .modelUnavailable(let model):
            return "\(model) 모델을 사용할 수 없습니다"
        }
    }
}

// MARK: - Delegate Protocol

/// 🎯 모델 전환 델리게이트
protocol ModelSwitchingDelegate: AnyObject {
    func modelSwitchingWillBegin(from: AIModelType, to: AIModelType)
    func modelSwitchingDidComplete(from: AIModelType, to: AIModelType)
    func modelSwitchingDidFail(error: Error)
}

// MARK: - Network Monitor (간단한 구현)

/// 🌐 네트워크 모니터
class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    var isConnected: Bool {
        // 실제로는 NWPathMonitor 사용
        return true // 임시 구현
    }
    
    private init() {}
}