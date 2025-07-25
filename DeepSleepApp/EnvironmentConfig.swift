import Foundation

/// Bundle Configuration 방식의 환경 설정 관리자
/// Secrets.xcconfig + .gitignore + AppInfo.plist 방식 사용
public class EnvironmentConfig {
    public static let shared = EnvironmentConfig()
    
    private init() {}
    
    // MARK: - API Key Properties (Bundle Configuration)
    
    /// 🔑 Gemini API 키
    public var geminiApiKey: String {
        return Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String ?? ""
    }

    /// 🔑 Claude API 키
    public var claudeApiKey: String {
        return Bundle.main.object(forInfoDictionaryKey: "CLAUDE_API_KEY") as? String ?? ""
    }
    
    /// 🔑 Naver Cloud Platform API 키
    public var naverCloudApiKey: String {
        return Bundle.main.object(forInfoDictionaryKey: "NAVER_CLOUD_API_KEY") as? String ?? ""
    }
    
    /// 🔑 Naver Cloud Platform API Secret
    public var naverCloudApiSecret: String {
        return Bundle.main.object(forInfoDictionaryKey: "NAVER_CLOUD_API_SECRET") as? String ?? ""
    }
    
    /// 🔑 OpenAI API 키
    public var openAIApiKey: String {
        return Bundle.main.object(forInfoDictionaryKey: "OPEN_AI_4oMINI_API_KEY") as? String ?? ""
    }
    
    // MARK: - Security Checks
    
    public func performSecurityCheck() {
        #if DEBUG
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
        #endif
    }
    
    /// API 키 유효성 검사
    public func isAPIKeyValid(apiKey: String) -> Bool {
        return !apiKey.isEmpty && apiKey.count > 10
    }
}