import Foundation
import Security

/// Secure Enclave 기반 API 키 저장/조회/삭제 매니저
final class SecureEnclaveKeyStore {
    static let shared = SecureEnclaveKeyStore()
    private let service = "com.deepsleep.api"
    
    enum KeyType: String {
        case gemini
        case claude
        case naver
    }
    
    private init() {}
    
    /// API 키 저장 (업데이트)
    /// - Parameters:
    ///   - key: The API key value to save.
    ///   - account: A unique account name to identify the key (e.g., "geminiAPIKey", "claudeAPIKey").
    func saveAPIKey(_ key: String, for account: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        // First, try to delete any existing key for this account to ensure a clean slate.
        SecItemDelete(query as CFDictionary)
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            // Restrict accessibility to when the device is unlocked and requires user presence (e.g., Face ID/Touch ID) for access.
            kSecAttrAccessControl as String: SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, .userPresence, nil)!,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIAllow, // Prompt user for biometric auth if needed.
            kSecValueData as String: data
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// API 키 조회
    /// - Parameter key: The unique account name for the key to load.
    func loadAPIKey(key account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            // Require user authentication to read the key.
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIAllow
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            #if DEBUG
            // print("Keychain: Could not load key for account '\(account)'. Status: \(status)")
            #endif
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }

    /// API 키 삭제
    /// - Parameter account: The unique account name for the key to delete.
    func deleteAPIKey(for account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        #if DEBUG
        if status == errSecSuccess {
            print("Keychain: Successfully deleted key for account '\(account)'.")
        } else if status == errSecItemNotFound {
            // This is not an error, just means the key wasn't there to be deleted.
        } else {
            print("Keychain: Error deleting key for account '\(account)'. Status: \(status)")
        }
        #endif
    }
} 
