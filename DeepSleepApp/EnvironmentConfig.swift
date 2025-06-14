import Foundation

// MARK: - 🔐 완전히 새로운 보안 환경 설정 시스템
class EnvironmentConfig {
    static let shared = EnvironmentConfig()
    
    private init() {}
    
    /// 🔑 Replicate API 키 (런타임에서만 접근 가능)
    var replicateAPIKey: String {
        #if DEBUG
        let envValue = ProcessInfo.processInfo.environment["REPLICATE_API_TOKEN"]
        print("🔍 [EnvironmentConfig] environment variable REPLICATE_API_TOKEN = \(envValue ?? "nil")")
        #endif
        // 1. 환경 변수에서 먼저 확인
        if let envKey = ProcessInfo.processInfo.environment["REPLICATE_API_TOKEN"], !envKey.isEmpty {
            #if DEBUG
            print("✅ [EnvironmentConfig] using environment key -> \(envKey)")
            #endif
            return envKey
        }
        #if DEBUG
        let plistValue = Bundle.main.object(forInfoDictionaryKey: "REPLICATE_API_TOKEN") as? String
        print("🔍 [EnvironmentConfig] Info.plist REPLICATE_API_TOKEN = \(plistValue ?? "nil")")
        #endif
        // 2. Info.plist에서 확인
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "REPLICATE_API_TOKEN") as? String,
           !plistKey.isEmpty && plistKey != "$(REPLICATE_API_TOKEN)" {
            #if DEBUG
            print("✅ [EnvironmentConfig] using Info.plist key -> \(plistKey)")
            #endif
            return plistKey
        }
        #if DEBUG
        let keychainValue = getFromKeychain() ?? "nil"
        print("🔍 [EnvironmentConfig] keychain value = \(keychainValue)")
        #endif
        // 3. 키체인에서 확인
        if let keychainKey = getFromKeychain() {
            #if DEBUG
            print("✅ [EnvironmentConfig] using keychain key -> \(keychainKey)")
            #endif
            return keychainKey
        }
        #if DEBUG
        print("⚠️ [EnvironmentConfig] API 키를 찾을 수 없어 빈 문자열 반환")
        #endif
        // 4. 개발 중에만 사용할 fallback
        #if DEBUG
        print("⚠️ [EnvironmentConfig] fallback empty string in DEBUG")
        #endif
        return ""
    }
    
    /// 🔐 키체인에서 API 키 조회 (미래 구현)
    private func getFromKeychain() -> String? {
        // Keychain에서 API 키 조회
        return SecureEnclaveKeyStore.shared.loadAPIKey()
    }
    
    /// ✅ API 키 유효성 검증
    func isAPIKeyValid() -> Bool {
        let key = replicateAPIKey
        return !key.isEmpty && key.hasPrefix("r8_") && key.count > 10
    }
    
    /// 🛡️ 안전한 API 키 마스킹 (로그용)
    func maskedAPIKey() -> String {
        let key = replicateAPIKey
        guard key.count > 8 else { return "***" }
        return String(key.prefix(4)) + "****" + String(key.suffix(4))
    }
}

// MARK: - 🔐 보안 강화 확장
extension EnvironmentConfig {
    /// 📱 앱 시작 시 보안 검증
    func performSecurityCheck() {
        #if DEBUG
        print("🔐 보안 검증 시작...")
        print("📱 API 키 상태: \(isAPIKeyValid() ? "✅ 유효" : "❌ 무효")")
        print("🔑 마스킹된 키: \(maskedAPIKey())")
        #endif
        
        // 운영 환경에서 API 키 누락 시 안전 조치
        #if !DEBUG
        if !isAPIKeyValid() {
            // 운영에서는 AI 기능 비활성화
            print("🚨 API 키 없음: AI 기능이 비활성화됩니다.")
        }
        #endif
    }
} 