import Foundation
import Network
/*
/// 🔍 4대 AI 모델 API 연결 검증 및 상태 모니터링 시스템
/// 2025년 최신 API 엔드포인트 기반으로 실제 연결 테스트 수행
class APIConnectionValidator {
    
    // MARK: - 싱글톤 패턴
    static let shared = APIConnectionValidator()
    private init() {
        setupNetworkMonitoring()
    }
    
    // MARK: - 네트워크 모니터링
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "api.connection.validator")
    private var isNetworkAvailable = false
    
    // MARK: - API 엔드포인트 정의 (2025년 최신)
    private struct APIEndpoints {
        static let claude = "https://api.anthropic.com/v1/messages"
        static let openai = "https://api.openai.com/v1/chat/completions"
        static let gemini = "https://generativelanguage.googleapis.com/v1/models"
        static let naver = "https://naveropenapi.apigw.ntruss.com/chatbot/v1/messages"
    }
    
    // MARK: - 연결 상태 모델
    struct ConnectionStatus {
        let apiType: APIType
        let isConnected: Bool
        let responseTime: TimeInterval?
        let statusCode: Int?
        let errorMessage: String?
        let timestamp: Date
        
        var statusEmoji: String {
            return isConnected ? "✅" : "❌"
        }
        
        var responseTimeString: String {
            guard let responseTime = responseTime else { return "N/A" }
            return String(format: "%.0fms", responseTime * 1000)
        }
    }
    
    // MARK: - API 연결 검증 메인 메서드
    func validateAllAPIConnections() async {
        print("\n🚀 [APIConnectionValidator] 4대 AI 모델 연결 검증 시작")
        print("=" * 60)
        
        // 네트워크 연결 확인
        guard isNetworkAvailable else {
            print("❌ [네트워크] 인터넷 연결이 없습니다")
            return
        }
        
        print("🌐 [네트워크] 인터넷 연결 확인됨")
        
        // API 키 상태 먼저 확인
        let apiKeyStatus = APIKeyManager.shared.checkAllAPIKeys()
        APIKeyManager.shared.logAPIKeyStatus()
        
        // 각 API 연결 테스트 (병렬 처리)
        await withTaskGroup(of: ConnectionStatus.self) { group in
            
            // Claude API 테스트
            if apiKeyStatus.claude, let claudeKey = APIKeyManager.shared.claudeAPIKey {
                group.addTask {
                    await self.testClaudeConnection(apiKey: claudeKey)
                }
            }
            
            // OpenAI API 테스트
            if apiKeyStatus.openai, let openaiKey = APIKeyManager.shared.openAIAPIKey {
                group.addTask {
                    await self.testOpenAIConnection(apiKey: openaiKey)
                }
            }
            
            // Gemini API 테스트
            if apiKeyStatus.gemini, let geminiKey = APIKeyManager.shared.geminiAPIKey {
                group.addTask {
                    await self.testGeminiConnection(apiKey: geminiKey)
                }
            }
            
            // 결과 수집 및 출력
            print("\n📊 [연결 테스트] 결과:")
            print("-" * 40)
            
            for await status in group {
                logConnectionStatus(status)
            }
        }
        
        print("=" * 60)
        print("🏁 [APIConnectionValidator] 연결 검증 완료\n")
    }
    
    // MARK: - Claude API 연결 테스트
    private func testClaudeConnection(apiKey: String) async -> ConnectionStatus {
        let startTime = Date()
        
        UnifiedLogger.shared.logAPIStart("Claude")
        
        guard let claudeURL = URL(string: APIEndpoints.claude) else {
            return ConnectionStatus(
                apiType: .claude,
                isConnected: false,
                responseTime: nil,
                statusCode: nil,
                errorMessage: "Invalid Claude endpoint URL",
                timestamp: Date()
            )
        }
        var request = URLRequest(url: claudeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        // 최소한의 테스트 요청
        let testPayload: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 10,
            "messages": [
                ["role": "user", "content": "Hi"]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: testPayload)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            let responseTime = Date().timeIntervalSince(startTime)
            
            if let httpResponse = response as? HTTPURLResponse {
                let isSuccess = httpResponse.statusCode == 200
                
                if isSuccess {
                    UnifiedLogger.shared.logAPISuccess("Claude", responseTime: responseTime)
                } else {
                    UnifiedLogger.shared.logAPIFailure("Claude", error: "HTTP \(httpResponse.statusCode)")
                }
                
                return ConnectionStatus(
                    apiType: .claude,
                    isConnected: isSuccess,
                    responseTime: responseTime,
                    statusCode: httpResponse.statusCode,
                    errorMessage: isSuccess ? nil : "HTTP \(httpResponse.statusCode)",
                    timestamp: Date()
                )
            }
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            UnifiedLogger.shared.logAPIFailure("Claude", error: error.localizedDescription)
            
            return ConnectionStatus(
                apiType: .claude,
                isConnected: false,
                responseTime: responseTime,
                statusCode: nil,
                errorMessage: error.localizedDescription,
                timestamp: Date()
            )
        }
        
        return ConnectionStatus(
            apiType: .claude,
            isConnected: false,
            responseTime: nil,
            statusCode: nil,
            errorMessage: "Unknown error",
            timestamp: Date()
        )
    }
    
    // MARK: - OpenAI API 연결 테스트
    private func testOpenAIConnection(apiKey: String) async -> ConnectionStatus {
        let startTime = Date()
        
        UnifiedLogger.shared.logAPIStart("OpenAI")
        
        guard let openaiURL = URL(string: APIEndpoints.openai) else {
            return ConnectionStatus(
                apiType: .openai,
                isConnected: false,
                responseTime: nil,
                statusCode: nil,
                errorMessage: "Invalid OpenAI endpoint URL",
                timestamp: Date()
            )
        }
        var request = URLRequest(url: openaiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // 최소한의 테스트 요청
        let testPayload = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "user", "content": "Hi"]
            ],
            "max_tokens": 10
        ] as [String : Any]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: testPayload)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            let responseTime = Date().timeIntervalSince(startTime)
            
            if let httpResponse = response as? HTTPURLResponse {
                let isSuccess = httpResponse.statusCode == 200
                
                return ConnectionStatus(
                    apiType: .openai,
                    isConnected: isSuccess,
                    responseTime: responseTime,
                    statusCode: httpResponse.statusCode,
                    errorMessage: isSuccess ? nil : "HTTP \(httpResponse.statusCode)",
                    timestamp: Date()
                )
            }
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            return ConnectionStatus(
                apiType: .openai,
                isConnected: false,
                responseTime: responseTime,
                statusCode: nil,
                errorMessage: error.localizedDescription,
                timestamp: Date()
            )
        }
        
        return ConnectionStatus(
            apiType: .openai,
            isConnected: false,
            responseTime: nil,
            statusCode: nil,
            errorMessage: "Unknown error",
            timestamp: Date()
        )
    }
    
    // MARK: - Gemini API 연결 테스트
    private func testGeminiConnection(apiKey: String) async -> ConnectionStatus {
        let startTime = Date()
        
        UnifiedLogger.shared.logAPIStart("Gemini")
        
        // Gemini는 GET 요청으로 모델 목록을 가져와서 연결 확인
        let urlString = "\(APIEndpoints.gemini)?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            return ConnectionStatus(
                apiType: .gemini,
                isConnected: false,
                responseTime: nil,
                statusCode: nil,
                errorMessage: "Invalid URL",
                timestamp: Date()
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let responseTime = Date().timeIntervalSince(startTime)
            
            if let httpResponse = response as? HTTPURLResponse {
                let isSuccess = httpResponse.statusCode == 200
                
                return ConnectionStatus(
                    apiType: .gemini,
                    isConnected: isSuccess,
                    responseTime: responseTime,
                    statusCode: httpResponse.statusCode,
                    errorMessage: isSuccess ? nil : "HTTP \(httpResponse.statusCode)",
                    timestamp: Date()
                )
            }
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            return ConnectionStatus(
                apiType: .gemini,
                isConnected: false,
                responseTime: responseTime,
                statusCode: nil,
                errorMessage: error.localizedDescription,
                timestamp: Date()
            )
        }
        
        return ConnectionStatus(
            apiType: .gemini,
            isConnected: false,
            responseTime: nil,
            statusCode: nil,
            errorMessage: "Unknown error",
            timestamp: Date()
        )
    }
    
    // MARK: - Naver API 연결 테스트 (향후 구현)
    private func testNaverConnection(apiKey: String) async -> ConnectionStatus {
        // TODO: Naver API 키가 추가되면 구현
        return ConnectionStatus(
            apiType: .naver,
            isConnected: false,
            responseTime: nil,
            statusCode: nil,
            errorMessage: "Not implemented yet",
            timestamp: Date()
        )
    }
    
    // MARK: - 연결 상태 로깅
    private func logConnectionStatus(_ status: ConnectionStatus) {
        let icon = getAPIIcon(status.apiType)
        print("\(icon) [\(status.apiType.displayName)] \(status.statusEmoji) \(status.isConnected ? "연결 성공" : "연결 실패")")
        
        if status.responseTime != nil {
            print("   ⏱️  응답 시간: \(status.responseTimeString)")
        }
        
        if let statusCode = status.statusCode {
            print("   📡 HTTP 상태: \(statusCode)")
        }
        
        if let errorMessage = status.errorMessage {
            print("   ❌ 오류: \(errorMessage)")
        }
        
        print("   🕐 테스트 시간: \(formatTimestamp(status.timestamp))")
        print()
    }
    
    // MARK: - 네트워크 모니터링 설정
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isNetworkAvailable = path.status == .satisfied
            
            if path.status == .satisfied {
                print("🌐 [Network] 인터넷 연결 복원됨")
            } else {
                print("📵 [Network] 인터넷 연결 끊어짐")
            }
        }
        
        monitor.start(queue: queue)
    }
    
    // MARK: - 유틸리티 메서드
    
    private func getAPIIcon(_ apiType: APIType) -> String {
        switch apiType {
        case .claude: return "🤖"
        case .openai: return "🧠"
        case .gemini: return "💎"
        case .naver: return "🇰🇷"
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    // MARK: - 빠른 연결 상태 확인
    func quickHealthCheck() async -> Bool {
        print("⚡ [빠른 검사] API 연결 상태 확인 중...")
        
        guard isNetworkAvailable else {
            print("❌ [빠른 검사] 네트워크 연결 없음")
            return false
        }
        
        // 사용 가능한 첫 번째 API로 간단한 요청
        if let (apiType, _) = APIKeyManager.shared.getPreferredAPI() {
            print("✅ [빠른 검사] \(apiType.displayName) API 사용 가능")
            return true
        }
        
        print("❌ [빠른 검사] 사용 가능한 API 없음")
        return false
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - APIType 확장 (Naver 추가)
extension APIType {
    static let naver = APIType(rawValue: "Naver")!
    
    init?(rawValue: String) {
        switch rawValue {
        case "Claude": self = .claude
        case "OpenAI": self = .openai
        case "Gemini": self = .gemini
        case "Naver": self = .naver
        default: return nil
        }
    }
    
    static var allCases: [APIType] {
        return [.claude, .openai, .gemini, .naver]
    }
    
    var rawValue: String {
        switch self {
        case .claude: return "Claude"
        case .openai: return "OpenAI"
        case .gemini: return "Gemini"
        case .naver: return "Naver"
        }
    }
}

// MARK: - String 확장 (로그 포맷팅용)
private extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
*/
