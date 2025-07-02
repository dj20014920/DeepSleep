import Foundation
import Security
import LocalAuthentication

/// Secure Enclave 기반 API 키 저장/조회/삭제 매니저
public final class SecureEnclaveKeyStore {
    
    // MARK: - Error Type
    
    public enum KeyStoreError: Error {
        case storeError(status: OSStatus)
        case retrieveError(status: OSStatus)
        case deleteError(status: OSStatus)
    }
    
    // MARK: - Key Types
    
    public enum KeyType: String, CaseIterable {
        case gemini = "geminiAPIKey"
        case claude = "claudeAPIKey"
        case naver = "naverAPIKey"
        case openAI = "openAIAPIKey"
    }
    
    // MARK: - Singleton
    
    public static let shared = SecureEnclaveKeyStore()
    
    private init() {}
    
    // MARK: - Public Methods
    
    public func storeKey(_ key: Data, withTag tag: String) throws {
        let context = LAContext()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecValueData as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecUseAuthenticationContext as String: context
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeyStoreError.storeError(status: status)
        }
    }
    
    public func retrieveKey(withTag tag: String) throws -> Data {
        let context = LAContext()
        context.touchIDAuthenticationAllowableReuseDuration = 60 // 60초 동안 재사용 허용
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: context
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            throw KeyStoreError.retrieveError(status: status)
        }
        
        return data
    }
    
    public func deleteKey(withTag tag: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeyStoreError.deleteError(status: status)
        }
    }
    
    // MARK: - API Key Convenience Methods
    
    /// API 키를 저장합니다.
    public func saveAPIKey(_ apiKey: String, for keyType: String) -> Bool {
        guard let keyData = apiKey.data(using: .utf8) else { return false }
        
        do {
            try storeKey(keyData, withTag: keyType)
            return true
        } catch {
            return false
        }
    }
    
    /// API 키를 로드합니다.
    public func loadAPIKey(key: String) -> String? {
        do {
            let keyData = try retrieveKey(withTag: key)
            return String(data: keyData, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    /// API 키를 삭제합니다.
    public func deleteAPIKey(for keyType: String) -> Bool {
        do {
            try deleteKey(withTag: keyType)
            return true
        } catch {
            return false
        }
    }
} 
