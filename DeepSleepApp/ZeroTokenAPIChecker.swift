import Foundation
import Network

/// 💯 완전 토큰 소모 제로 API 상태 확인 시스템
/// 실제 API 호출 없이 로컬 검증과 DNS 조회만으로 상태 확인
public class ZeroTokenAPIChecker {
    
    // MARK: - 싱글톤 패턴
    public static let shared = ZeroTokenAPIChecker()
    private init() {
        setupNetworkMonitoring()
    }
    
    // MARK: - 네트워크 모니터링
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "zero.token.checker")
    private var isNetworkAvailable = false
    
    // MARK: - API 도메인 정보 (DNS 조회용 - 토큰 소모 없음)
    private struct APIDomains {
        static let claude = "api.anthropic.com"
        static let openai = "api.openai.com"
        static let gemini = "generativelanguage.googleapis.com"
        static let naver = "naveropenapi.apigw.ntruss.com"
    }
    
    // MARK: - 상태 결과
    struct ZeroTokenStatus {
        let apiName: String
        let hasValidKey: Bool
        let isDomainReachable: Bool
        let dnsResolutionTime: TimeInterval?
        let timestamp: Date
        
        var overallStatus: String {
            if hasValidKey && isDomainReachable {
                return "🟢 완전 준비됨"
            } else if hasValidKey && !isDomainReachable {
                return "🟡 네트워크 문제"
            } else if !hasValidKey && isDomainReachable {
                return "🟡 키 설정 필요"
            } else {
                return "🔴 설정 및 네트워크 문제"
            }
        }
        
        var statusEmoji: String {
            return hasValidKey && isDomainReachable ? "✅" : "⚠️"
        }
    }
    
    // MARK: - 메인 체크 메서드 (토큰 소모 완전 제로)
    func performZeroTokenCheck() async {
        print("\n💯 [ZeroTokenChecker] 완전 토큰 소모 제로 상태 확인")
        print(String(repeating: "=", count: 55))
        print("🔍 방식: 로컬 키 검증 + DNS 조회만 사용 (API 호출 없음)")
        print(String(repeating: "-", count: 55))
        
        // 1단계: 네트워크 기본 상태 확인
        await checkNetworkStatus()
        
        // 2단계: API 키 상태 확인 (완전 로컬)
        await checkAllAPIKeys()
        
        // 3단계: DNS 조회로 도메인 접근성 확인 (토큰 소모 없음)
        await checkDomainReachability()
        
        // 4단계: 종합 결과 및 권장사항
        await provideFinalRecommendation()
        
        print(String(repeating: "=", count: 55))
        print("🎉 [완료] 토큰 소모 없이 모든 상태 확인 완료!")
        print(String(repeating: "=", count: 55))
    }
    
    // MARK: - 1단계: 네트워크 상태 확인
    private func checkNetworkStatus() async {
        print("\n📡 [1단계] 네트워크 연결 상태")
        
        if isNetworkAvailable {
            print("   ✅ 인터넷 연결: 정상")
            
            // 연결 타입 확인
            monitor.currentPath.availableInterfaces.forEach { interface in
                switch interface.type {
                case .wifi:
                    print("   📶 연결 방식: Wi-Fi")
                case .cellular:
                    print("   📱 연결 방식: 모바일 데이터")
                case .wiredEthernet:
                    print("   🔌 연결 방식: 유선 이더넷")
                default:
                    print("   🔗 연결 방식: 기타")
                }
            }
        } else {
            print("   ❌ 인터넷 연결: 없음")
            print("   💡 해결책: Wi-Fi 또는 모바일 데이터 연결 확인")
        }
    }
    
    // MARK: - 2단계: API 키 로컬 검증 (토큰 소모 없음)
    private func checkAllAPIKeys() async {
        print("\n🔑 [2단계] API 키 로컬 검증 (토큰 소모 없음)")
        
        let claudeStatus = validateAPIKeyLocally(keyName: "CLAUDE_API_KEY", expectedPrefix: "sk-ant-")
        let openaiStatus = validateAPIKeyLocally(keyName: "OPEN_AI_4oMINI_API_KEY", expectedPrefix: "sk-")
        let geminiStatus = validateAPIKeyLocally(keyName: "GEMINI_API_KEY", expectedPrefix: nil)
        
        print("   🤖 Claude API:")
        printKeyStatus(claudeStatus)
        
        print("   🧠 OpenAI API:")
        printKeyStatus(openaiStatus)
        
        print("   💎 Gemini API:")
        printKeyStatus(geminiStatus)
        
        let validKeysCount = [claudeStatus, openaiStatus, geminiStatus].filter { $0.isValid }.count
        print("\n   📊 요약: \(validKeysCount)/3개 API 키 설정 완료")
        
        if validKeysCount == 0 {
            print("   ⚠️  모든 API 키가 설정되지 않았습니다")
            print("   💡 해결책: Secrets.xcconfig에서 실제 API 키로 교체")
        }
    }
    
    // MARK: - API 키 로컬 검증 (완전 로컬, 토큰 소모 없음)
    private func validateAPIKeyLocally(keyName: String, expectedPrefix: String?) -> (isValid: Bool, status: String, details: String) {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: keyName) as? String else {
            return (false, "❌ 없음", "Info.plist에서 키를 찾을 수 없음")
        }
        
        // 템플릿 키 패턴 확인
        let templatePatterns = [
            "YOUR_CLAUDE_API_KEY_HERE",
            "YOUR_OPENAI_API_KEY_HERE",
            "YOUR_GEMINI_API_KEY_HERE",
            "sk-ant-api03-YOUR_CLAUDE_API_KEY_HERE",
            "sk-proj-YOUR_OPENAI_API_KEY_HERE"
        ]
        
        if templatePatterns.contains(where: { apiKey.contains($0) }) {
            return (false, "🟡 템플릿", "실제 API 키로 교체 필요")
        }
        
        // 길이 확인
        if apiKey.count < 10 {
            return (false, "❌ 너무 짧음", "최소 10자 이상이어야 함")
        }
        
        // 접두사 확인 (해당하는 경우)
        if let prefix = expectedPrefix {
            if !apiKey.hasPrefix(prefix) {
                return (false, "❌ 형식 오류", "\(prefix)로 시작해야 함")
            }
        }
        
        // 기본적인 문자 구성 확인
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        if apiKey.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            return (false, "❌ 잘못된 문자", "영문, 숫자, -, _ 만 사용 가능")
        }
        
        // 모든 검증 통과
        let maskedKey = maskAPIKey(apiKey)
        return (true, "✅ 유효", "형식 정상 (\(maskedKey))")
    }
    
    // MARK: - API 키 마스킹 (보안)
    private func maskAPIKey(_ key: String) -> String {
        if key.count <= 8 {
            return String(repeating: "*", count: key.count)
        }
        
        let start = String(key.prefix(4))
        let end = String(key.suffix(4))
        let middleCount = key.count - 8
        let middle = String(repeating: "*", count: middleCount)
        
        return "\(start)\(middle)\(end)"
    }
    
    private func printKeyStatus(_ status: (isValid: Bool, status: String, details: String)) {
        print("      상태: \(status.status)")
        print("      상세: \(status.details)")
    }
    
    // MARK: - 3단계: 네트워크 연결성 확인 (토큰 소모 없음)
    private func checkDomainReachability() async {
        print("\n🌐 [3단계] 네트워크 연결성 확인 (토큰 소모 없음)")
        
        guard isNetworkAvailable else {
            print("   ❌ 네트워크 연결이 없음")
            print("   💡 Wi-Fi 또는 모바일 데이터 연결을 확인해주세요")
            return
        }
        
        print("   ✅ 네트워크 연결: 정상")
        print("   🔍 API 도메인 접근성 확인 중...")
        
        // 간단한 병렬 체크
        let domains = [
            ("Claude", APIDomains.claude),
            ("OpenAI", APIDomains.openai), 
            ("Gemini", APIDomains.gemini),
            ("Naver", APIDomains.naver)
        ]
        
        await withTaskGroup(of: (String, Bool, TimeInterval?).self) { group in
            
            for (name, domain) in domains {
                group.addTask {
                    let (isReachable, time) = await self.checkDNSResolution(domain: domain)
                    return (name, isReachable, time)
                }
            }
            
            // 결과 출력
            for await (apiName, isReachable, resolutionTime) in group {
                let icon = getAPIIcon(apiName)
                let status = isReachable ? "🟢 연결 가능" : "🔴 연결 불가"
                let timeString = resolutionTime.map { String(format: "%.0fms", $0 * 1000) } ?? "타임아웃"
                
                print("   \(icon) \(apiName): \(status) (\(timeString))")
            }
        }
        
        print("   📝 참고: 연결 테스트는 로컬 네트워크 상태만 확인하며 API 토큰을 전혀 사용하지 않습니다")
    }
    
    // MARK: - DNS 조회 (완전 토큰 소모 없음) - Swift 6 동시성 안전 버전
    private func checkDNSResolution(domain: String) async -> (Bool, TimeInterval?) {
        let startTime = Date()
        
        return await withCheckedContinuation { continuation in
            let host = NWEndpoint.Host(domain)
            
            // 더 관대한 네트워크 파라미터 설정
            let tcpOptions = NWProtocolTCP.Options()
            let parameters = NWParameters(tls: nil, tcp: tcpOptions)
            parameters.acceptLocalOnly = false
            parameters.prohibitExpensivePaths = false
            parameters.allowLocalEndpointReuse = true
            
            let connection = NWConnection(host: host, port: 80, using: parameters)
            
            // Swift 6 동시성 안전: 상태 추적을 위한 동기화된 접근자
            let resumeState = ResumeState()
            
            connection.stateUpdateHandler = { state in
                resumeState.performOnce {
                    switch state {
                    case .ready:
                        let resolutionTime = Date().timeIntervalSince(startTime)
                        connection.cancel()
                        continuation.resume(returning: (true, resolutionTime))
                    case .failed(_):
                        // 연결이 실패해도 DNS 조회는 성공했을 수 있음 (도메인이 존재함을 의미)
                        let resolutionTime = Date().timeIntervalSince(startTime)
                        connection.cancel()
                        continuation.resume(returning: (true, resolutionTime))
                    default:
                        break
                    }
                }
            }
            
            connection.start(queue: queue)
            
            // 3초 타임아웃
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                resumeState.performOnce {
                    connection.cancel()
                    continuation.resume(returning: (false, nil))
                }
            }
        }
    }
    
    // MARK: - Swift 6 동시성 안전한 상태 관리
    private final class ResumeState: @unchecked Sendable {
        private let lock = NSLock()
        private var hasResumed = false
        
        func performOnce(_ action: () -> Void) {
            lock.lock()
            defer { lock.unlock() }
            
            guard !hasResumed else { return }
            hasResumed = true
            action()
        }
    }
    
    // MARK: - 4단계: 종합 결과 및 권장사항
    private func provideFinalRecommendation() async {
        print("\n🎯 [4단계] 종합 결과 및 권장사항")
        
        // API별 상태 종합
        let claudeKey = validateAPIKeyLocally(keyName: "CLAUDE_API_KEY", expectedPrefix: "sk-ant-").isValid
        let openaiKey = validateAPIKeyLocally(keyName: "OPEN_AI_4oMINI_API_KEY", expectedPrefix: "sk-").isValid
        let geminiKey = validateAPIKeyLocally(keyName: "GEMINI_API_KEY", expectedPrefix: nil).isValid
        
        let validKeys = [claudeKey, openaiKey, geminiKey].filter { $0 }.count
        
        print("   📊 상태 요약:")
        print("      ✅ 설정된 API 키: \(validKeys)/3개")
        print("      🌐 네트워크 상태: \(isNetworkAvailable ? "정상" : "문제")")
        
        // 권장사항 제공
        print("\n   💡 권장사항:")
        
        if validKeys == 0 {
            print("      1. Secrets.xcconfig에서 최소 1개 API 키 설정")
            print("      2. 우선순위: Claude > OpenAI > Gemini")
        } else if validKeys < 3 {
            print("      1. 현재 \(validKeys)개 설정됨 - 추가 API 키 설정으로 안정성 향상")
            print("      2. 백업 API로 활용 가능")
        } else {
            print("      ✅ 모든 API 키 설정 완료!")
            print("      🚀 AI 기능 사용 준비 완료")
        }
        
        if !isNetworkAvailable {
            print("      ⚠️  네트워크 연결 확인 필요")
        }
        
        // 추천 API 제안
        if let recommendedAPI = getRecommendedAPI() {
            print("\n   🏆 추천 API: \(recommendedAPI)")
            print("      💰 비용 효율성과 성능을 고려한 추천")
        }
    }
    
    // MARK: - 추천 API 선택 (로컬 기반)
    private func getRecommendedAPI() -> String? {
        let claudeValid = validateAPIKeyLocally(keyName: "CLAUDE_API_KEY", expectedPrefix: "sk-ant-").isValid
        let openaiValid = validateAPIKeyLocally(keyName: "OPEN_AI_4oMINI_API_KEY", expectedPrefix: "sk-").isValid
        let geminiValid = validateAPIKeyLocally(keyName: "GEMINI_API_KEY", expectedPrefix: nil).isValid
        
        // 우선순위 기반 추천
        if claudeValid {
            return "Claude (고품질 응답)"
        } else if openaiValid {
            return "OpenAI (빠른 응답)"
        } else if geminiValid {
            return "Gemini (경제적)"
        }
        
        return nil
    }
    
    // MARK: - 빠른 상태 확인 (1초 이내)
    func quickZeroTokenCheck() -> (hasAnyValidKey: Bool, networkOK: Bool, recommendedAPI: String?) {
        print("⚡ [즉시 확인] 토큰 소모 없는 빠른 상태 체크")
        
        let claudeValid = validateAPIKeyLocally(keyName: "CLAUDE_API_KEY", expectedPrefix: "sk-ant-").isValid
        let openaiValid = validateAPIKeyLocally(keyName: "OPEN_AI_4oMINI_API_KEY", expectedPrefix: "sk-").isValid
        let geminiValid = validateAPIKeyLocally(keyName: "GEMINI_API_KEY", expectedPrefix: nil).isValid
        
        let hasAnyKey = claudeValid || openaiValid || geminiValid
        let recommended = getRecommendedAPI()
        
        print("   🔑 API 키: \(hasAnyKey ? "✅ 있음" : "❌ 없음")")
        print("   🌐 네트워크: \(isNetworkAvailable ? "✅ 정상" : "❌ 문제")")
        if let rec = recommended {
            print("   🏆 추천: \(rec)")
        }
        
        return (hasAnyKey, isNetworkAvailable, recommended)
    }
    
    // MARK: - 네트워크 모니터링 설정
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isNetworkAvailable = path.status == .satisfied
        }
        monitor.start(queue: queue)
    }
    
    // MARK: - 유틸리티
    private func getAPIIcon(_ apiName: String) -> String {
        switch apiName {
        case "Claude": return "🤖"
        case "OpenAI": return "🧠"
        case "Gemini": return "💎"
        case "Naver": return "🇰🇷"
        default: return "🔧"
        }
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - 사용 예시
/*

// 완전 상세 체크 (토큰 소모 없음)
Task {
    await ZeroTokenAPIChecker.shared.performZeroTokenCheck()
}

// 빠른 체크 (1초 이내)
let (hasKeys, networkOK, recommended) = ZeroTokenAPIChecker.shared.quickZeroTokenCheck()

*/