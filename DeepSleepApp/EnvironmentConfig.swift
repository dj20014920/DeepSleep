import Foundation

/// Bundle Configuration 방식의 환경 설정 관리자
/// Secrets.xcconfig + .gitignore + AppInfo.plist 방식 사용
public class EnvironmentConfig {
    public static let shared = EnvironmentConfig()
    
    private init() {}
    
    // MARK: - Test Overrides (DEBUG only)
    // 테스트에서 런타임 오버라이드를 허용해 Info.plist 의존도를 낮춤
    #if DEBUG
    public static var testUseProxyOverride: Bool? = nil
    public static var testProxyBaseURLOverride: String? = nil
    #endif
    
    // MARK: - API Key Properties (Bundle Configuration)
    
    /// 🔑 Gemini API 키
    public var geminiApiKey: String {
        return ConfigReader.string("GEMINI_API_KEY") ?? ""
    }

    /// 🔑 Claude API 키
    public var claudeApiKey: String {
        return ConfigReader.string("CLAUDE_API_KEY") ?? ""
    }
    
    /// 🔑 Naver Cloud Platform API 키
    public var naverCloudApiKey: String {
        return ConfigReader.string("NAVER_CLOUD_API_KEY") ?? ""
    }
    
    /// 🔑 Naver Cloud Platform API Secret
    public var naverCloudApiSecret: String {
        return ConfigReader.string("NAVER_CLOUD_API_SECRET") ?? ""
    }
    
    /// 🔑 OpenAI API 키
    public var openAIApiKey: String {
        return ConfigReader.string("OPEN_AI_4oMINI_API_KEY") ?? ""
    }

    // MARK: - Proxy Settings
    public var useProxy: Bool {
        #if DEBUG
        if let o = Self.testUseProxyOverride { return o }
        #endif
        return ConfigReader.bool("USE_PROXY") ?? false
    }
    public var proxyBaseURL: String {
        #if DEBUG
        if let o = Self.testProxyBaseURLOverride { return o }
        #endif
        return ConfigReader.string("PROXY_BASE_URL") ?? ""
    }
    public var clientProxyHmacSecret: String {
        return ConfigReader.string("CLIENT_PROXY_HMAC_SECRET") ?? ""
    }
    
    /// 프록시 인증 모드: Nonce 사용 여부 (운영 기본: false — 서버가 구버전 서명일 때 단일 요청 성공 보장)
    public var proxyAuthUseNonce: Bool {
        return ConfigReader.bool("PROXY_AUTH_USE_NONCE") ?? false
    }
    
    // MARK: - Security Checks
    
    public func performSecurityCheck() {
        #if DEBUG
        if useProxy {
            print("🔐 Performing Security Checks (Proxy Mode)...")
            let base = proxyBaseURL
            let baseStatus = !base.isEmpty ? "✅ Set" : "❌ Missing"
            print("🌐 Proxy Base URL: \(baseStatus) | \(base.isEmpty ? "***" : base)")
            // 프록시 모드에서는 API 키 검증/로깅을 생략한다 (키 불필요)
            print("🛡️ Proxy mode 활성화: API 키 검증 생략")
        } else {
            print("🔐 Performing Security Checks...")
            let keys = [
                ("Gemini", geminiApiKey),
                ("Claude", claudeApiKey),
                ("Naver Cloud", naverCloudApiKey),
                ("OpenAI", openAIApiKey)
            ]
            for (name, key) in keys {
                let status = !key.isEmpty ? "✅ Valid" : "❌ Invalid"
                let masked = key.isEmpty ? "***" : String(key.prefix(4)) + "..." + String(key.suffix(4))
                print("🔑 \(name) API Key: \(status) | \(masked)")
            }
        }
        #else
        // Release: 프록시 모드에서 번들 API 키가 남아 있으면 경고(보안/심사 위험)
        if useProxy {
            let keys = [geminiApiKey, claudeApiKey, naverCloudApiKey, openAIApiKey]
            if keys.contains(where: { !$0.isEmpty }) {
                print("⚠️ [Security] Release+ProxyMode: 번들에 공급자 API 키가 남아 있습니다. 서버 프록시만 사용하도록 키를 제거하세요.")
            }
        }
        #endif
    }
    
    /// API 키 유효성 검사
    public func isAPIKeyValid(apiKey: String) -> Bool {
        return !apiKey.isEmpty && apiKey.count > 10
    }
}
