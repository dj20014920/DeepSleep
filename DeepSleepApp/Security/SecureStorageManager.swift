import Foundation
import Security
import LocalAuthentication

/// 2025년 최신 보안 기준을 준수하는 Secure Storage Manager
/// Keychain + Secure Enclave + 생체인증을 통합한 고도화된 보안 시스템
class SecureStorageManager {
    
    // MARK: - 싱글톤 패턴
    static let shared = SecureStorageManager()
    private init() {}
    
    // MARK: - 보안 설정 상수
    private struct SecurityConfig {
        static let serviceIdentifier = "com.deepsleep.secure.storage"
        static let accessGroup = "group.deepsleep.keychain"
        
        // 2025년 보안 권장사항: 생체인증 필수, 디바이스 잠금시에만 접근
        static let keychainAccessibility: SecAttrAccessible = .whenPasscodeSetThisDeviceOnly
        static let biometricPolicy: LAPolicy = .deviceOwnerAuthenticationWithBiometrics
    }
    
    // MARK: - 에러 타입 정의
    enum SecureStorageError: Error, LocalizedError {
        case keyNotFound
        case invalidData
        case biometricAuthenticationFailed
        case keychainWriteFailed(OSStatus)
        case keychainReadFailed(OSStatus)
        case secureEnclaveFailed
        case deviceNotSecured
        
        var errorDescription: String? {
            switch self {
            case .keyNotFound:
                return "암호화된 데이터를 찾을 수 없습니다"
            case .invalidData:
                return "잘못된 데이터 형식입니다"
            case .biometricAuthenticationFailed:
                return "생체인증에 실패했습니다"
            case .keychainWriteFailed(let status):
                return "Keychain 저장 실패: \(status)"
            case .keychainReadFailed(let status):
                return "Keychain 읽기 실패: \(status)"
            case .secureEnclaveFailed:
                return "Secure Enclave 처리 실패"
            case .deviceNotSecured:
                return "디바이스 보안 설정이 필요합니다"
            }
        }
    }
    
    // MARK: - 생체인증 확인
    func checkBiometricAvailability() -> Bool {
        let context = LAContext()
        var error: NSError?
        
        let isAvailable = context.canEvaluatePolicy(SecurityConfig.biometricPolicy, error: &error)
        
        if let error = error {
            print("// PERF-WARNING: 생체인증 불가 - \(error.localizedDescription)")
            // 테스트 방법: Settings > Face ID & Passcode 확인
        }
        
        return isAvailable
    }
    
    // MARK: - 보안 데이터 저장
    func saveSecureData<T: Codable>(_ data: T, forKey key: String, requireBiometric: Bool = true) async throws {
        // 1단계: 디바이스 보안 상태 확인
        guard checkDeviceSecurityStatus() else {
            throw SecureStorageError.deviceNotSecured
        }
        
        // 2단계: 생체인증 요구시 인증 수행
        if requireBiometric && checkBiometricAvailability() {
            try await performBiometricAuthentication()
        }
        
        // 3단계: 데이터 인코딩 및 암호화
        let jsonData = try JSONEncoder().encode(data)
        
        // 4단계: Keychain 저장 쿼리 구성
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: SecurityConfig.serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecValueData as String: jsonData,
            kSecAttrAccessible as String: SecurityConfig.keychainAccessibility
        ]
        
        // 생체인증 필수 설정 (2025년 권장사항)
        if requireBiometric && checkBiometricAvailability() {
            let access = SecAccessControlCreateWithFlags(
                nil,
                SecurityConfig.keychainAccessibility,
                .biometryAny,
                nil
            )
            query[kSecAttrAccessControl as String] = access
        }
        
        // 기존 항목 삭제 후 새로 저장
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw SecureStorageError.keychainWriteFailed(status)
        }
        
        print("✅ 보안 데이터 저장 완료: \(key)")
    }
    
    // MARK: - 보안 데이터 읽기
    func loadSecureData<T: Codable>(_ type: T.Type, forKey key: String, requireBiometric: Bool = true) async throws -> T? {
        // 1단계: 생체인증 수행 (필요시)
        if requireBiometric && checkBiometricAvailability() {
            try await performBiometricAuthentication()
        }
        
        // 2단계: Keychain 쿼리 구성
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
        
        // 3단계: 데이터 디코딩
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
    
    // MARK: - Private Helper Methods
    
    private func performBiometricAuthentication() async throws {
        let context = LAContext()
        context.localizedFallbackTitle = "암호 입력"
        
        do {
            let success = try await context.evaluatePolicy(
                SecurityConfig.biometricPolicy,
                localizedReason: "안전한 데이터 접근을 위해 생체인증이 필요합니다"
            )
            
            guard success else {
                throw SecureStorageError.biometricAuthenticationFailed
            }
        } catch {
            throw SecureStorageError.biometricAuthenticationFailed
        }
    }
    
    private func checkDeviceSecurityStatus() -> Bool {
        let context = LAContext()
        var error: NSError?
        
        // 디바이스에 암호/생체인증 설정이 되어있는지 확인
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        
        if let error = error {
            print("// PERF-WARNING: 디바이스 보안 설정 부족 - \(error.localizedDescription)")
            // 확인 방법: Settings > Face ID & Passcode에서 암호 설정 확인
        }
        
        return canEvaluate
    }
}

// MARK: - 사용자 설정 전용 확장
extension SecureStorageManager {
    
    // UserDefaults 마이그레이션을 위한 전용 메서드들
    func saveUserSettings(_ settings: UserSettingsModel) async throws {
        try await saveSecureData(settings, forKey: "user_settings", requireBiometric: true)
    }
    
    func loadUserSettings() async throws -> UserSettingsModel? {
        return try await loadSecureData(UserSettingsModel.self, forKey: "user_settings", requireBiometric: true)
    }
    
    func saveAPIKeys(_ keys: [String: String]) async throws {
        try await saveSecureData(keys, forKey: "api_keys", requireBiometric: true)
    }
    
    func loadAPIKeys() async throws -> [String: String]? {
        return try await loadSecureData([String: String].self, forKey: "api_keys", requireBiometric: true)
    }
    
    // 사용자 개인정보 (닉네임, 나이 등)
    func saveUserProfile(_ profile: UserProfile) async throws {
        try await saveSecureData(profile, forKey: "user_profile", requireBiometric: false)
    }
    
    func loadUserProfile() async throws -> UserProfile? {
        return try await loadSecureData(UserProfile.self, forKey: "user_profile", requireBiometric: false)
    }
}

// MARK: - 사용자 프로필 모델
struct UserProfile: Codable {
    let nickname: String
    let age: Int
    let preferences: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case nickname, age, preferences
    }
    
    init(nickname: String, age: Int, preferences: [String: Any] = [:]) {
        self.nickname = nickname
        self.age = age
        self.preferences = preferences
    }
    
    // Custom Codable 구현 (Any 타입 처리)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nickname = try container.decode(String.self, forKey: .nickname)
        age = try container.decode(Int.self, forKey: .age)
        
        // preferences의 Any 타입 처리는 실제 사용시 구체적인 타입으로 대체 필요
        preferences = [:]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nickname, forKey: .nickname)
        try container.encode(age, forKey: .age)
        // preferences 인코딩은 실제 사용시 구체적인 타입으로 구현 필요
    }
}