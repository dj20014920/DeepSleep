import Foundation
import Security

/// Keychain 저장소: 프록시 서명 비밀(per-device)
enum ProxySecretStore {
    private static let service = "emozleep.proxy.hmac"

    static func load(for uid: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: uid,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data, let secret = String(data: data, encoding: .utf8) {
            print("✅ [ProxySecretStore] 키체인에서 시크릿 로드 성공 (uid: \(uid))")
            return secret
        } else if status == errSecItemNotFound {
            print("⚠️ [ProxySecretStore] 키체인에 시크릿 없음 (uid: \(uid))")
            return nil
        } else {
            print("❌ [ProxySecretStore] 키체인 로드 실패 - status: \(status), uid: \(uid)")
            return nil
        }
    }

    static func save(_ secret: String, for uid: String) {
        let data = Data(secret.utf8)
        // delete existing
        let del: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: uid
        ]
        let deleteStatus = SecItemDelete(del as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            print("⚠️ [ProxySecretStore] 기존 시크릿 삭제 실패 - status: \(deleteStatus)")
        }
        
        // add
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: uid,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        if addStatus == errSecSuccess {
            print("✅ [ProxySecretStore] 시크릿 저장 성공 (uid: \(uid))")
        } else {
            print("❌ [ProxySecretStore] 시크릿 저장 실패 - status: \(addStatus), uid: \(uid)")
        }
    }
    
    /// 디버깅용: 특정 UID의 시크릿 삭제
    static func delete(for uid: String) {
        let del: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: uid
        ]
        let status = SecItemDelete(del as CFDictionary)
        if status == errSecSuccess {
            print("✅ [ProxySecretStore] 시크릿 삭제 성공 (uid: \(uid))")
        } else if status == errSecItemNotFound {
            print("ℹ️ [ProxySecretStore] 삭제할 시크릿 없음 (uid: \(uid))")
        } else {
            print("❌ [ProxySecretStore] 시크릿 삭제 실패 - status: \(status), uid: \(uid)")
        }
    }
    
    /// 디버깅용: 모든 시크릿 삭제
    static func clearAll() {
        let del: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(del as CFDictionary)
        if status == errSecSuccess {
            print("✅ [ProxySecretStore] 모든 시크릿 삭제 완료")
        } else if status == errSecItemNotFound {
            print("ℹ️ [ProxySecretStore] 삭제할 시크릿 없음")
        } else {
            print("❌ [ProxySecretStore] 전체 삭제 실패 - status: \(status)")
        }
    }
}
