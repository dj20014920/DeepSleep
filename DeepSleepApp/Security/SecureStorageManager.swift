import Foundation
import Security

/// 2025년 최신 보안 기준을 준수하는 Secure Storage Manager
/// Keychain 기반 보안 저장소 시스템
class SecureStorageManager {
    
    // MARK: - 싱글톤 패턴
    static let shared = SecureStorageManager()
    private init() {}
    
    // MARK: - 보안 설정 상수
    private struct SecurityConfig {
        static let serviceIdentifier = "com.deepsleep.secure.storage"
        static let accessGroup = "group.deepsleep.keychain"
        
        // 2025년 보안 권장사항: 디바이스 잠금시에만 접근
        static let keychainAccessibility: CFString = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
    }
    
    // MARK: - 에러 타입 정의
    enum SecureStorageError: Error, LocalizedError {
        case keyNotFound
        case invalidData
        case keychainWriteFailed(OSStatus)
        case keychainReadFailed(OSStatus)
        case secureEnclaveFailed
        
        var errorDescription: String? {
            switch self {
            case .keyNotFound:
                return "암호화된 데이터를 찾을 수 없습니다"
            case .invalidData:
                return "잘못된 데이터 형식입니다"
            case .keychainWriteFailed(let status):
                return "Keychain 저장 실패: \(status)"
            case .keychainReadFailed(let status):
                return "Keychain 읽기 실패: \(status)"
            case .secureEnclaveFailed:
                return "Secure Enclave 처리 실패"
            }
        }
    }
    
    // MARK: - 보안 데이터 저장
    func saveSecureData<T: Codable>(_ data: T, forKey key: String) async throws {
        // 1단계: 데이터 인코딩
        let jsonData = try JSONEncoder().encode(data)
        
        // 2단계: Keychain 저장 쿼리 구성
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: SecurityConfig.serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecValueData as String: jsonData,
            kSecAttrAccessible as String: SecurityConfig.keychainAccessibility
        ]
        
        // 기존 항목 삭제 후 새로 저장
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw SecureStorageError.keychainWriteFailed(status)
        }
        
        print("✅ 보안 데이터 저장 완료: \(key)")
    }
    
    // MARK: - 보안 데이터 읽기
    func loadSecureData<T: Codable>(_ type: T.Type, forKey key: String) async throws -> T? {
        // 1단계: Keychain 쿼리 구성
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: SecurityConfig.serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw SecureStorageError.keychainReadFailed(status)
        }
        
        guard let data = result as? Data else {
            throw SecureStorageError.invalidData
        }
        
        // 2단계: 데이터 디코딩
        let decodedData = try JSONDecoder().decode(type, from: data)
        print("✅ 보안 데이터 읽기 완료: \(key)")
        
        return decodedData
    }
    
    // MARK: - 보안 데이터 삭제
    func deleteSecureData(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: SecurityConfig.serviceIdentifier,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureStorageError.keychainWriteFailed(status)
        }
        
        print("✅ 보안 데이터 삭제 완료: \(key)")
    }
    
    // MARK: - 모든 보안 데이터 삭제 (로그아웃/데이터 초기화시)
    func clearAllSecureData() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: SecurityConfig.serviceIdentifier
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureStorageError.keychainWriteFailed(status)
        }
        
        print("✅ 모든 보안 데이터 삭제 완료")
    }
    
}

// MARK: - 사용자 설정 전용 확장
extension SecureStorageManager {
    
    // UserDefaults 마이그레이션을 위한 전용 메서드들
    func saveUserSettings(_ settings: UserSettingsModel) async throws {
        try await saveSecureData(settings, forKey: "user_settings")
    }
    
    func loadUserSettings() async throws -> UserSettingsModel? {
        return try await loadSecureData(UserSettingsModel.self, forKey: "user_settings")
    }
    
    func saveAPIKeys(_ keys: [String: String]) async throws {
        try await saveSecureData(keys, forKey: "api_keys")
    }
    
    func loadAPIKeys() async throws -> [String: String]? {
        return try await loadSecureData([String: String].self, forKey: "api_keys")
    }
    
    // 사용자 개인정보 (닉네임, 나이 등)
    func saveUserProfile(_ profile: UserProfile) async throws {
        try await saveSecureData(profile, forKey: "user_profile")
    }
    
    func loadUserProfile() async throws -> UserProfile? {
        return try await loadSecureData(UserProfile.self, forKey: "user_profile")
    }
}

// UserProfile은 Models.swift에 정의됨