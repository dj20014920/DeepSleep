import Foundation
import GoogleGenerativeAI // Gemini SDK
import Combine

// MARK: - 🔐 Uniform API Key Management System
public class EnvironmentConfig {
    public static let shared = EnvironmentConfig()
    
    private init() {}
    
    // MARK: - API Key Properties
    
    /// 🔑 Gemini API 키
    public var geminiApiKey: String {
        return getKey(
            envVar: "GEMINI_API_KEY",
            plistKey: "GEMINI_API_KEY",
            keychainKey: "geminiAPIKey",
            prefix: "AIzaSy" // Gemini 키의 일반적인 접두사
        )
    }

    /// 🔑 Claude API 키
    public var claudeApiKey: String {
        return getKey(
            envVar: "CLAUDE_API_KEY",
            plistKey: "CLAUDE_API_KEY",
            keychainKey: "claudeAPIKey",
            prefix: "sk-ant-api03-"
        )
    }
    
    /// 🔑 Naver Cloud Platform API 키
    public var naverCloudApiKey: String {
        return getKey(
            envVar: "NAVER_CLOUD_API_KEY",
            plistKey: "NAVER_CLOUD_API_KEY",
            keychainKey: "naverCloudAPIKey",
            prefix: nil // 네이버 키는 특별한 접두사가 없을 수 있음
        )
    }
    
    /// 🔑 Naver Cloud Platform API Secret
    public var naverCloudApiSecret: String {
        return getKey(
            envVar: "NAVER_CLOUD_API_SECRET",
            plistKey: "NAVER_CLOUD_API_SECRET",
            keychainKey: "naverCloudAPISecret",
            prefix: nil // 네이버 시크릿은 특별한 접두사가 없을 수 있음
        )
    }
    
    /// 🔑 OpenAI API 키
    public var openAIApiKey: String {
        return getKey(
            envVar: "OPEN_AI_4oMINI_API_KEY",
            plistKey: "OPEN_AI_4oMINI_API_KEY",
            keychainKey: "openAIAPIKey",
            prefix: "sk-proj-" // OpenAI 키의 일반적인 접두사
        )
    }
    
    /// 🔑 Naver Cloud API 키
    @Published public private(set) var naverAPIKey: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Private Key Retrieval Logic
    
    private func getKey(envVar: String, plistKey: String, keychainKey: String, prefix: String?) -> String {
        // 1. 환경 변수 우선 (주로 CI/CD나 로컬 테스트 오버라이드용)
        if let envKey = ProcessInfo.processInfo.environment[envVar], !envKey.isEmpty {
            #if DEBUG
            print("✅ [EnvironmentConfig] Using environment variable for \(plistKey)")
            #endif
            return envKey
        }
        
        // 2. Info.plist -> xcconfig 값 사용 (주 개발 방식)
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: plistKey) as? String,
           !plistValue.isEmpty, plistValue != "$(\(plistKey))" {
            #if DEBUG
            print("✅ [EnvironmentConfig] Using Info.plist key for \(plistKey)")
            #endif
            return plistValue
        }
        
        // 3. Keychain 값 사용 (향후 사용자가 직접 키를 입력하는 기능 대비)
        if let keychainValue = getFromKeychain(key: keychainKey) {
             #if DEBUG
             print("✅ [EnvironmentConfig] Using keychain key for \(plistKey)")
             #endif
            return keychainValue
        }
        
        #if DEBUG
        print("⚠️ [EnvironmentConfig] API key for \(plistKey) not found. Returning empty string for DEBUG.")
        #endif
        return ""
    }
    
    private func getFromKeychain(key: String) -> String? {
        return SecureEnclaveKeyStore.shared.loadAPIKey(key: key)
    }
    
    // MARK: - Key Validation & Security
    
    func isAPIKeyValid(apiKey: String, prefix: String?) -> Bool {
        if let prefix = prefix {
            return !apiKey.isEmpty && apiKey.hasPrefix(prefix) && apiKey.count > 20
        }
        return !apiKey.isEmpty && apiKey.count > 10
    }
    
    func maskedAPIKey(apiKey: String) -> String {
        guard apiKey.count > 8 else { return "***" }
        return String(apiKey.prefix(4)) + "..." + String(apiKey.suffix(4))
    }
}

// MARK: - 🔐 Security Checks Extension
extension EnvironmentConfig {
    public func performSecurityCheck() {
        #if DEBUG
        print("🔐 Performing Security Checks...")
        
        let keys = [
            ("Gemini", geminiApiKey, "AIzaSy"),
            ("Claude", claudeApiKey, "sk-ant-api03-"),
            ("Naver Cloud", naverCloudApiKey, nil),
            ("OpenAI", openAIApiKey, "sk-proj-")
        ]
        
        for (name, key, prefix) in keys {
            let status = isAPIKeyValid(apiKey: key, prefix: prefix) ? "✅ Valid" : "❌ Invalid"
            print("🔑 \(name) API Key: \(status) | \(maskedAPIKey(apiKey: key))")
        }
        
        #endif
        
        #if !DEBUG
        if !isAPIKeyValid(apiKey: claudeApiKey, prefix: "sk-ant-api03-") {
            // This could be a silent failure or trigger a specific app state
            print("🚨 CRITICAL: Production Claude API Key is missing or invalid.")
        }
        if !isAPIKeyValid(apiKey: geminiApiKey, prefix: "AIzaSy") {
            print("🚨 CRITICAL: Production Gemini API Key is missing or invalid.")
        }
        #endif
    }
}

// MARK: - 🔐 Combine Latest Extension
extension EnvironmentConfig {
    public func loadAllKeysFromKeychain() async {
        naverAPIKey = getFromKeychain(key: "naverCloudAPIKey")
    }
    
    /// Info.plist에서 API 키를 로드하여 Keychain에 저장합니다.
    public func loadAndSaveKeysFromPlist() async {
        let keysToLoad: [(key: SecureEnclaveKeyStore.KeyType, plistKey: String, prefix: String?)] = [
            (.gemini, "Gemini_API_Key", nil),
            (.claude, "Claude_API_Key", "sk-ant-"),
            (.naver, "Naver_Cloud_API_Key", nil)
        ]
        
        for (keyType, plistKey, _) in keysToLoad {
            if let apiKey = Bundle.main.object(forInfoDictionaryKey: plistKey) as? String, !apiKey.isEmpty, apiKey != "$(\(plistKey))" {
                _ = SecureEnclaveKeyStore.shared.saveAPIKey(apiKey, for: keyType.rawValue)
            }
        }
    }
} 
