import Foundation
import Network

/// 🏥 토큰 소모 없는 API 헬스체크 시스템
/// 실제 API 호출 대신 기본적인 연결성만 확인하는 경량화된 시스템
class APIHealthChecker {
    
    // MARK: - 싱글톤 패턴
    static let shared = APIHealthChecker()
    private init() {
        setupNetworkMonitoring()
    }
    
    // MARK: - 네트워크 모니터링
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "api.health.checker")
    private var isNetworkAvailable = false
    
    // MARK: - API 기본 정보 (토큰 소모 없이 확인 가능한 엔드포인트)
    private struct APIHealthEndpoints {
        // HEAD 요청이나 GET 요청으로 기본 상태만 확인
        static let claude = "https://api.anthropic.com/v1"
        static let openai = "https://api.openai.com/v1"
        static let gemini = "https://generativelanguage.googleapis.com/v1"
        static let naver = "https://naveropenapi.apigw.ntruss.com"
    }
    
    // MARK: - 헬스체크 상태
    struct HealthStatus {
        let apiType: String
        let isReachable: Bool
        let responseTime: TimeInterval?
        let errorMessage: String?
        let timestamp: Date
        
        var statusEmoji: String {
            return isReachable ? "🟢" : "🔴"
        }
        
        var responseTimeString: String {
            guard let responseTime = responseTime else { return "N/A" }
            return String(format: "%.0fms", responseTime * 1000)
        }
    }
    
    // MARK: - 메인 헬스체크 메서드 (토큰 소모 없음)
    func performHealthCheck() async {
        print("\n🏥 [APIHealthChecker] API 연결성 확인 시작 (토큰 소모 없음)")
        print(String(repeating: "=", count: 50))
        
        // 네트워크 연결 확인
        guard isNetworkAvailable else {
            print("❌ [네트워크] 인터넷 연결이 없습니다")
            return
        }
        
        print("🌐 [네트워크] 인터넷 연결 확인됨")
        
        // API 키 상태 먼저 확인
        checkAPIKeyStatus()
        
        // 각 API 기본 연결성 테스트 (병렬 처리)
        await withTaskGroup(of: HealthStatus.self) { group in
            
            // Claude API 기본 연결성 테스트
            if hasValidAPIKey(for: "CLAUDE_API_KEY") {
                group.addTask {
                    await self.checkBasicConnectivity(
                        apiName: "Claude",
                        endpoint: APIHealthEndpoints.claude
                    )
                }
            }
            
            // OpenAI API 기본 연결성 테스트
            if hasValidAPIKey(for: "OPEN_AI_4oMINI_API_KEY") {
                group.addTask {
                    await self.checkBasicConnectivity(
                        apiName: "OpenAI",
                        endpoint: APIHealthEndpoints.openai
                    )
                }
            }
            
            // Gemini API 기본 연결성 테스트
            if hasValidAPIKey(for: "GEMINI_API_KEY") {
                group.addTask {
                    await self.checkBasicConnectivity(
                        apiName: "Gemini",
                        endpoint: APIHealthEndpoints.gemini
                    )
                }
            }
            
            // 결과 수집 및 출력
            print("\n📊 [헬스체크] 결과:")
            print(String(repeating: "-", count: 40))
            
            for await status in group {
                logHealthStatus(status)
            }
        }
        
        print(String(repeating: "=", count: 50))
        print("🏁 [APIHealthChecker] 헬스체크 완료\n")
    }
    
    // MARK: - 기본 연결성 확인 (토큰 소모 없음)
    private func checkBasicConnectivity(apiName: String, endpoint: String) async -> HealthStatus {
        let startTime = Date()
        
        print("🔍 [\(apiName)] 기본 연결성 확인 중...")
        
        guard let url = URL(string: endpoint) else {
            return HealthStatus(
                apiType: apiName,
                isReachable: false,
                responseTime: nil,
                errorMessage: "Invalid URL",
                timestamp: Date()
            )
        }
        
        // HEAD 요청으로 기본 연결성만 확인 (토큰 소모 없음)
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0 // 5초 타임아웃
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let responseTime = Date().timeIntervalSince(startTime)
            
            if let httpResponse = response as? HTTPURLResponse {
                // 200, 404, 401 등은 모두 서버가 응답한다는 의미로 "연결 가능"으로 판단
                let isReachable = httpResponse.statusCode < 500
                
                return HealthStatus(
                    apiType: apiName,
                    isReachable: isReachable,
                    responseTime: responseTime,
                    errorMessage: isReachable ? nil : "Server Error (\(httpResponse.statusCode))",
                    timestamp: Date()
                )
            }
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            return HealthStatus(
                apiType: apiName,
                isReachable: false,
                responseTime: responseTime,
                errorMessage: error.localizedDescription,
                timestamp: Date()
            )
        }
        
        return HealthStatus(
            apiType: apiName,
            isReachable: false,
            responseTime: nil,
            errorMessage: "Unknown error",
            timestamp: Date()
        )
    }
    
    // MARK: - API 키 상태 확인
    private func checkAPIKeyStatus() {
        print("\n🔑 [API 키 상태]")
        
        let claudeStatus = hasValidAPIKey(for: "CLAUDE_API_KEY")
        let openaiStatus = hasValidAPIKey(for: "OPEN_AI_4oMINI_API_KEY")
        let geminiStatus = hasValidAPIKey(for: "GEMINI_API_KEY")
        
        print("   🤖 Claude: \(claudeStatus ? "✅ 설정됨" : "❌ 미설정")")
        print("   🧠 OpenAI: \(openaiStatus ? "✅ 설정됨" : "❌ 미설정")")
        print("   💎 Gemini: \(geminiStatus ? "✅ 설정됨" : "❌ 미설정")")
        
        let anyKeyAvailable = claudeStatus || openaiStatus || geminiStatus
        print("   📊 전체 상태: \(anyKeyAvailable ? "✅ 사용 가능" : "❌ 설정 필요")")
        
        if !anyKeyAvailable {
            print("   ⚠️  경고: Secrets.xcconfig에서 API 키를 설정해주세요")
        }
    }
    
    private func hasValidAPIKey(for keyName: String) -> Bool {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: keyName) as? String else {
            return false
        }
        
        // 템플릿 키인지 확인
        let templatePatterns = [
            "YOUR_CLAUDE_API_KEY_HERE",
            "YOUR_OPENAI_API_KEY_HERE", 
            "YOUR_GEMINI_API_KEY_HERE"
        ]
        
        if templatePatterns.contains(where: { apiKey.contains($0) }) {
            return false
        }
        
        // 기본적인 길이 확인
        return apiKey.count > 10
    }
    
    // MARK: - 헬스체크 결과 로깅
    private func logHealthStatus(_ status: HealthStatus) {
        let icon = getAPIIcon(status.apiType)
        print("\(icon) [\(status.apiType)] \(status.statusEmoji) \(status.isReachable ? "연결 가능" : "연결 불가")")
        
        if let responseTime = status.responseTime {
            print("   ⏱️  응답 시간: \(status.responseTimeString)")
        }
        
        if let errorMessage = status.errorMessage {
            print("   ❌ 상태: \(errorMessage)")
        }
        
        print("   🕐 확인 시간: \(formatTimestamp(status.timestamp))")
        print()
    }
    
    // MARK: - 네트워크 모니터링 설정
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isNetworkAvailable = path.status == .satisfied
        }
        monitor.start(queue: queue)
    }
    
    // MARK: - 유틸리티 메서드
    
    private func getAPIIcon(_ apiType: String) -> String {
        switch apiType {
        case "Claude": return "🤖"
        case "OpenAI": return "🧠"
        case "Gemini": return "💎"
        case "Naver": return "🇰🇷"
        default: return "🔧"
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    // MARK: - 빠른 상태 확인
    func quickCheck() -> Bool {
        print("⚡ [빠른 체크] API 설정 상태 확인...")
        
        guard isNetworkAvailable else {
            print("❌ [빠른 체크] 네트워크 연결 없음")
            return false
        }
        
        let hasAnyKey = hasValidAPIKey(for: "CLAUDE_API_KEY") ||
                       hasValidAPIKey(for: "OPEN_AI_4oMINI_API_KEY") ||
                       hasValidAPIKey(for: "GEMINI_API_KEY")
        
        if hasAnyKey {
            print("✅ [빠른 체크] API 키 설정 완료")
            return true
        } else {
            print("❌ [빠른 체크] API 키 설정 필요")
            return false
        }
    }
    
    // MARK: - 권장 API 반환
    func getPreferredAPI() -> (name: String, key: String)? {
        // 우선순위: Claude > OpenAI > Gemini
        if let claudeKey = Bundle.main.object(forInfoDictionaryKey: "CLAUDE_API_KEY") as? String,
           !claudeKey.contains("YOUR_CLAUDE_API_KEY_HERE"), claudeKey.count > 10 {
            return ("Claude", claudeKey)
        }
        
        if let openaiKey = Bundle.main.object(forInfoDictionaryKey: "OPEN_AI_4oMINI_API_KEY") as? String,
           !openaiKey.contains("YOUR_OPENAI_API_KEY_HERE"), openaiKey.count > 10 {
            return ("OpenAI", openaiKey)
        }
        
        if let geminiKey = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String,
           !geminiKey.contains("YOUR_GEMINI_API_KEY_HERE"), geminiKey.count > 10 {
            return ("Gemini", geminiKey)
        }
        
        return nil
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - 사용 예시
/*
 
// 앱 시작 시 헬스체크 수행
Task {
    await APIHealthChecker.shared.performHealthCheck()
}

// 빠른 상태 확인
let isHealthy = APIHealthChecker.shared.quickCheck()

// 사용 가능한 API 확인
if let (apiName, apiKey) = APIHealthChecker.shared.getPreferredAPI() {
    print("사용할 API: \(apiName)")
}

*/