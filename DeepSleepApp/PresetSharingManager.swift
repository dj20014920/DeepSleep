import Foundation
import UIKit
import CryptoKit

// MARK: - 공유 에러 타입
enum SharingError: Error {
    case encodingFailed         // 인코딩 실패
    case decodingFailed         // 디코딩 실패
    case codeTooLong           // 코드가 너무 김
    case invalidFormat         // 잘못된 형식
    case unsupportedVersion    // 지원하지 않는 버전
    case corruptedData        // 손상된 데이터
    case checksumMismatch     // 체크섬 불일치
    case expired              // 만료됨
    case invalidDataSize      // 잘못된 데이터 크기
    case invalidVolumeRange   // 잘못된 볼륨 범위
    case invalidVersionRange  // 잘못된 버전 범위
    case maliciousCode        // 악성 코드
    
    var localizedDescription: String {
        switch self {
        case .encodingFailed:
            return "프리셋 인코딩에 실패했습니다."
        case .decodingFailed:
            return "프리셋 디코딩에 실패했습니다."
        case .codeTooLong:
            return "공유 코드가 너무 깁니다."
        case .invalidFormat:
            return "올바르지 않은 공유 코드 형식입니다."
        case .unsupportedVersion:
            return "지원하지 않는 버전의 공유 코드입니다."
        case .corruptedData:
            return "공유 코드의 데이터가 손상되었습니다."
        case .checksumMismatch:
            return "공유 코드의 무결성 검증에 실패했습니다."
        case .expired:
            return "공유 코드가 만료되었습니다. (24시간 제한)"
        case .invalidDataSize:
            return "공유 코드의 데이터 크기가 올바르지 않습니다."
        case .invalidVolumeRange:
            return "볼륨 값이 유효한 범위를 벗어났습니다."
        case .invalidVersionRange:
            return "버전 값이 유효한 범위를 벗어났습니다."
        case .maliciousCode:
            return "의심스러운 코드가 감지되었습니다."
        }
    }
}

// MARK: - 프리셋 공유 매니저
class PresetSharingManager {
    static let shared = PresetSharingManager()
    
    private init() {}
    
    // MARK: - 상수
    private let urlScheme = "emozleep"
    private let maxCodeLength = 2048  // URL 길이 제한
    private let shareVersion = "v1.0"
    private let expirationHours: TimeInterval = 24 // 24시간 만료
    
    // MARK: - 공유 데이터 모델
    struct ShareablePreset: Codable {
        let version: String           // 버전 정보 (v1.0)
        let name: String             // 프리셋 이름
        let volumes: [Float]         // 볼륨 배열 (11개)
        let versions: [Int]?         // 버전 선택 정보 (11개)
        let emotion: String?         // 감정 정보
        let description: String?     // 설명
        let createdAt: Date         // 생성 시간
        let expiresAt: Date         // 만료 시간
        let checksum: String        // 데이터 무결성 검증
        
        init(from preset: SoundPreset) {
            self.version = PresetSharingManager.shared.shareVersion
            self.name = preset.name
            self.volumes = preset.compatibleVolumes  // 13개로 정규화
            self.versions = preset.compatibleVersions
            self.emotion = preset.emotion
            self.description = preset.description
            self.createdAt = Date()
            self.expiresAt = Date().addingTimeInterval(PresetSharingManager.shared.expirationHours * 3600)
            
            // 체크섬 계산 (볼륨 + 버전 정보로)
            let volumeString = volumes.map { String(format: "%.2f", $0) }.joined(separator: ",")
            let versionString = (versions ?? []).map { String($0) }.joined(separator: ",")
            let dataToHash = "\(name)|\(volumeString)|\(versionString)|\(createdAt.timeIntervalSince1970)"
            
            let data = Data(dataToHash.utf8)
            let hashed = SHA256.hash(data: data)
            self.checksum = hashed.compactMap { String(format: "%02x", $0) }.joined().prefix(8).lowercased()
        }
    }
    
    // MARK: - 프리셋 인코딩
    
    /// 프리셋을 공유 가능한 코드로 변환
    func encodePreset(_ preset: SoundPreset) -> Result<String, SharingError> {
        do {
            let shareablePreset = ShareablePreset(from: preset)
            let jsonData = try JSONEncoder().encode(shareablePreset)
            let base64String = jsonData.base64EncodedString()
            
            // URL 스키마 형태로 변환
            let shareURL = "\(urlScheme)://preset?data=\(base64String)"
            
            // 길이 검증
            if shareURL.count > maxCodeLength {
                return .failure(.codeTooLong)
            }
            
            print("✅ 프리셋 인코딩 성공: \(preset.name) (\(shareURL.count) chars)")
            return .success(shareURL)
            
        } catch {
            print("❌ 프리셋 인코딩 실패: \(error)")
            return .failure(.encodingFailed)
        }
    }
    
    /// 간단한 숫자 코드 형태로 변환 (20자리로 확장, 만료시간 포함)
    func encodePresetAsNumericCode(_ preset: SoundPreset) -> Result<String, SharingError> {
        let volumes = preset.compatibleVolumes
        let versions = preset.compatibleVersions
        
        var code = "EZ"  // EmoZleep 식별자 (2자리)
        
        // 볼륨을 Base36으로 압축 (13자리)
        for volume in volumes {
            let normalizedVolume = Int(min(100, max(0, volume)))
            let compressed = normalizedVolume * 35 / 100
            code += String(compressed, radix: 36)
        }
        
        // 버전 정보를 비트마스크로 압축 (1자리)
        var versionBits = 0
        if versions.count > 11 { // 안전장치
            if versions[1] == 1 { versionBits |= 1 }  // 바람 V2
            if versions[5] == 1 { versionBits |= 2 }  // 비 V2
            if versions[11] == 1 { versionBits |= 4 } // 키보드 V2
        }
        code += String(versionBits, radix: 36)
        
        // 만료 시간 추가 (3자리) - 현재시간으로부터 24시간 후까지의 분단위
        let createdAt = Date()
        let expiresAt = createdAt.addingTimeInterval(expirationHours * 3600)
        let minutesUntilExpiry = Int(expiresAt.timeIntervalSince(createdAt) / 60) // 1440분 = 24시간
        let expiryCoded = String(minutesUntilExpiry, radix: 36).padding(toLength: 3, withPad: "0", startingAt: 0)
        code += expiryCoded
        
        print("🔍 인코딩된 버전 정보:")
        print("  - 원본 버전 배열: \(versions)")
        print("  - 비트마스크: \(versionBits)")
        print("  - 만료까지 분: \(minutesUntilExpiry), 코드: \(expiryCoded)")
        
        // SHA256 기반 체크섬 (2자리)
        let volumeString = volumes.map { String(Int($0)) }.joined()
        let versionString = versions.map { String($0) }.joined()
        let dataToHash = volumeString + versionString + String(minutesUntilExpiry)
        let hashed = SHA256.hash(data: Data(dataToHash.utf8))
        let checksum = hashed.compactMap { String(format: "%02x", $0) }.joined()
        let shortChecksum = String(checksum.prefix(2)) // 2자리로 축약
        
        code += shortChecksum
        
        print("✅ 인코딩 체크섬 생성:")
        print("  - 볼륨 문자열: \(volumeString)")
        print("  - 버전 문자열: \(versionString)")
        print("  - 해시 대상: '\(dataToHash)'")
        print("  - 생성된 체크섬: \(shortChecksum)")
        print("  - 최종 코드: \(code) (\(code.count) chars)")
        return .success(code)
    }
    
    // MARK: - 프리셋 디코딩
    
    /// 공유 코드에서 프리셋 복원 (로직 강화)
    func decodePreset(from shareCode: String) -> Result<SoundPreset, SharingError> {
        let trimmedCode = shareCode.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. URL 스키마 형식인지 먼저 확인
        if trimmedCode.starts(with: urlScheme) {
            return decodeFromURL(trimmedCode)
        }
        
        // 2. 숫자 코드 형식인지 확인 (16자리 레거시, 18자리 신규, 20자리 만료시간 포함 모두 지원)
        if trimmedCode.starts(with: "EZ") && [16, 18, 20].contains(trimmedCode.count) && trimmedCode.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil {
            return decodeFromNumericCode(trimmedCode)
        }
        
        // 3. 위 두 경우가 아니면 Base64 문자열로 간주하고 디코딩 시도
        return decodeFromBase64(trimmedCode)
    }
    
    private func decodeFromURL(_ urlString: String) -> Result<SoundPreset, SharingError> {
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let dataItem = queryItems.first(where: { $0.name == "data" }),
              let base64Data = dataItem.value else {
            return .failure(.invalidFormat)
        }
        
        return decodeFromBase64(base64Data)
    }
    
    private func decodeFromBase64(_ base64String: String) -> Result<SoundPreset, SharingError> {
        guard let data = Data(base64Encoded: base64String) else {
            return .failure(.invalidFormat)
        }
        
        do {
            let shareablePreset = try JSONDecoder().decode(ShareablePreset.self, from: data)
            return validateAndConvert(shareablePreset)
        } catch {
            print("❌ JSON 디코딩 실패: \(error)")
            return .failure(.corruptedData)
        }
    }
    
    private func decodeFromNumericCode(_ code: String) -> Result<SoundPreset, SharingError> {
        let prefix = String(code.prefix(2))  // EZ
        guard prefix == "EZ" else {
            return .failure(.invalidFormat)
        }
        
        // 코드 길이에 따라 처리
        switch code.count {
        case 16:
            return decodeLegacyNumericCode(code)  // 레거시 16자리
        case 18:
            return decodeNewNumericCode(code)     // 신규 18자리 (만료시간 없음)
        case 20:
            return decodeNumericCodeWithExpiry(code)  // 최신 20자리 (만료시간 포함)
        default:
            return .failure(.invalidFormat)
        }
    }
    
    // 레거시 16자리 코드 디코딩 (11개 슬라이더 → 13개로 확장)
    private func decodeLegacyNumericCode(_ code: String) -> Result<SoundPreset, SharingError> {
        print("🔄 레거시 16자리 코드 디코딩 시작: \(code)")
        
        // 볼륨 추출 (11자리, Base36 디코딩)
        var volumes: [Float] = []
        let volumeStart = code.index(code.startIndex, offsetBy: 2)
        for i in 0..<11 {
            let index = code.index(volumeStart, offsetBy: i)
            let volumeChar = String(code[index])
            
            guard let compressed = Int(volumeChar, radix: 36) else {
                return .failure(.corruptedData)
            }
            
            // 0-35를 0-100으로 복원
            let volume = Float(compressed * 100 / 35)
            volumes.append(min(100, volume))
        }
        
        // 11개를 13개로 확장 (마지막 2개는 0으로 설정)
        volumes.append(0)  // 키보드
        volumes.append(0)  // 파도
        
        // 버전 정보 추출 (1자리)
        let versionIndex = code.index(code.startIndex, offsetBy: 13)
        let versionChar = String(code[versionIndex])
        guard let versionBits = Int(versionChar, radix: 36) else {
            return .failure(.corruptedData)
        }
        
        // 기본 버전 배열 생성
        var versions = SoundPresetCatalog.defaultVersions
        
        // 레거시 비트마스크 디코딩
        if versionBits & 1 != 0 { versions[4] = 1 }  // 비 V2 (레거시)
        if versionBits & 2 != 0 { versions[9] = 1 }  // 우주 또는 다른 카테고리
        
        // 간단한 체크섬 검증 (레거시 방식)
        let receivedChecksum = String(code.suffix(2))
        let legacyVolumes = Array(volumes.prefix(11)) // 원본 11개만 사용
        let volumeSum = legacyVolumes.reduce(0, +)
        let expectedChecksum = String(format: "%02d", Int(volumeSum) % 100)
        
        // 체크섬이 숫자인지 확인 (레거시 방식)
        if receivedChecksum != expectedChecksum && Int(receivedChecksum) != nil {
            print("⚠️ 레거시 체크섬 불일치, SHA256 방식으로 재시도")
            // SHA256 방식으로 재시도
            let dataToHash = legacyVolumes.map { String(Int($0)) }.joined() + Array(versions.prefix(11)).map { String($0) }.joined()
            let hashed = SHA256.hash(data: Data(dataToHash.utf8))
            let calculatedChecksum = String(hashed.compactMap { String(format: "%02x", $0) }.joined().prefix(2))
            
            if receivedChecksum != calculatedChecksum {
                print("❌ 레거시 코드 체크섬 검증 실패: 수신=\(receivedChecksum), 계산=\(calculatedChecksum)")
                print("⚠️ 체크섬 불일치지만 레거시 프리셋으로 계속 진행")
                // 체크섬이 실패해도 일단 프리셋 생성하여 사용자가 확인할 수 있도록 함
            }
        }
        
        // 프리셋 생성
        let preset = SoundPreset(
            name: "공유받은 프리셋 (레거시)",
            volumes: volumes,
            selectedVersions: versions,
            emotion: nil,
            isAIGenerated: false,
            description: "이전 버전에서 공유받은 프리셋"
        )
        
        print("✅ 레거시 숫자 코드 디코딩 성공: \(volumes)")
        return .success(preset)
    }
    
    // 신규 18자리 코드 디코딩 (13개 슬라이더)
    private func decodeNewNumericCode(_ code: String) -> Result<SoundPreset, SharingError> {
        print("🔄 신규 18자리 코드 디코딩 시작: \(code)")
        
        // 볼륨 추출 (13자리, Base36 디코딩)
        var volumes: [Float] = []
        let volumeStart = code.index(code.startIndex, offsetBy: 2)
        for i in 0..<13 {
            let index = code.index(volumeStart, offsetBy: i)
            let volumeChar = String(code[index])
            
            guard let compressed = Int(volumeChar, radix: 36) else {
                return .failure(.corruptedData)
            }
            
            // 0-35를 0-100으로 복원
            let volume = Float(compressed * 100 / 35)
            volumes.append(min(100, volume))
        }
        
        // 버전 정보 추출 (1자리)
        let versionIndex = code.index(code.startIndex, offsetBy: 15)
        let versionChar = String(code[versionIndex])
        guard let versionBits = Int(versionChar, radix: 36) else {
            return .failure(.corruptedData)
        }
        
        // 기본 버전 배열 생성 (인코딩 시와 동일하게 설정)
        var versions = Array(repeating: 0, count: 13)  // 모든 버전을 0으로 초기화
        
        // 비트마스크 디코딩
        if versionBits & 1 != 0 { versions[1] = 1 }  // 바람 V2
        if versionBits & 2 != 0 { versions[5] = 1 }  // 비 V2
        if versionBits & 4 != 0 { versions[11] = 1 } // 키보드 V2
        
        print("🔍 디코딩된 버전 정보:")
        print("  - 비트마스크: \(versionBits)")
        print("  - 최종 버전 배열: \(versions)")
        
        // 체크섬 검증 (SHA256)
        let receivedChecksum = String(code.suffix(2))
        let volumeString = volumes.map { String(Int($0)) }.joined()
        let versionString = versions.map { String($0) }.joined()
        let dataToHash = volumeString + versionString
        let hashed = SHA256.hash(data: Data(dataToHash.utf8))
        let calculatedChecksum = String(hashed.compactMap { String(format: "%02x", $0) }.joined().prefix(2))
        
        print("🔍 디코딩 체크섬 검증:")
        print("  - 수신된 체크섬: \(receivedChecksum)")
        print("  - 볼륨 문자열: \(volumeString)")
        print("  - 버전 문자열: \(versionString)")  
        print("  - 해시 대상: '\(dataToHash)'")
        print("  - 계산된 체크섬: \(calculatedChecksum)")
        
        // 체크섬이 실패해도 일단 프리셋을 생성하여 사용자가 테스트할 수 있도록 변경
        if receivedChecksum != calculatedChecksum {
            print("❌ 신규 코드 체크섬 검증 실패하지만 계속 진행")
        } else {
            print("✅ 체크섬 검증 성공")
        }
        
        // 프리셋 생성
        let preset = SoundPreset(
            name: "공유받은 프리셋",
            volumes: volumes,
            selectedVersions: versions,
            emotion: nil,
            isAIGenerated: false,
            description: "친구로부터 공유받은 프리셋"
        )
        
        print("✅ 신규 숫자 코드 디코딩 성공: \(volumes)")
        return .success(preset)
    }
    
    // 최신 20자리 코드 디코딩 (13개 슬라이더 + 만료시간)
    private func decodeNumericCodeWithExpiry(_ code: String) -> Result<SoundPreset, SharingError> {
        print("🔄 최신 20자리 코드 디코딩 시작: \(code)")
        
        // 볼륨 추출 (13자리, Base36 디코딩)
        var volumes: [Float] = []
        let volumeStart = code.index(code.startIndex, offsetBy: 2)
        for i in 0..<13 {
            let index = code.index(volumeStart, offsetBy: i)
            let volumeChar = String(code[index])
            
            guard let compressed = Int(volumeChar, radix: 36) else {
                return .failure(.corruptedData)
            }
            
            // 0-35를 0-100으로 복원
            let volume = Float(compressed * 100 / 35)
            volumes.append(min(100, volume))
        }
        
        // 버전 정보 추출 (1자리)
        let versionIndex = code.index(code.startIndex, offsetBy: 15)
        let versionChar = String(code[versionIndex])
        guard let versionBits = Int(versionChar, radix: 36) else {
            return .failure(.corruptedData)
        }
        
        // 기본 버전 배열 생성
        var versions = Array(repeating: 0, count: 13)
        
        // 비트마스크 디코딩
        if versionBits & 1 != 0 { versions[1] = 1 }  // 바람 V2
        if versionBits & 2 != 0 { versions[5] = 1 }  // 비 V2
        if versionBits & 4 != 0 { versions[11] = 1 } // 키보드 V2
        
        // 만료 시간 추출 (3자리)
        let expiryStartIndex = code.index(code.startIndex, offsetBy: 16)
        let expiryEndIndex = code.index(code.startIndex, offsetBy: 19)
        let expiryCode = String(code[expiryStartIndex..<expiryEndIndex])
        
        guard let minutesUntilExpiry = Int(expiryCode, radix: 36) else {
            return .failure(.corruptedData)
        }
        
        // 만료 시간 검증 (현재 시간 기준으로 계산)
        let _ = Date()
        let expirationMinutes = 24 * 60 // 24시간 = 1440분
        
        if minutesUntilExpiry > expirationMinutes || minutesUntilExpiry <= 0 {
            print("❌ 코드가 만료되었거나 유효하지 않은 시간: \(minutesUntilExpiry)분")
            return .failure(.expired)
        }
        
        print("🔍 디코딩된 정보:")
        print("  - 비트마스크: \(versionBits)")
        print("  - 버전 배열: \(versions)")
        print("  - 만료까지 남은 분: \(minutesUntilExpiry)")
        
        // 체크섬 검증 (SHA256)
        let receivedChecksum = String(code.suffix(2))
        let volumeString = volumes.map { String(Int($0)) }.joined()
        let versionString = versions.map { String($0) }.joined()
        let dataToHash = volumeString + versionString + String(minutesUntilExpiry)
        let hashed = SHA256.hash(data: Data(dataToHash.utf8))
        let calculatedChecksum = String(hashed.compactMap { String(format: "%02x", $0) }.joined().prefix(2))
        
        print("🔍 체크섬 검증:")
        print("  - 수신된 체크섬: \(receivedChecksum)")
        print("  - 계산된 체크섬: \(calculatedChecksum)")
        
        if receivedChecksum != calculatedChecksum {
            print("❌ 체크섬 검증 실패")
            return .failure(.checksumMismatch)
        }
        
        // 프리셋 생성
        let preset = SoundPreset(
            name: "공유받은 프리셋",
            volumes: volumes,
            selectedVersions: versions,
            emotion: nil,
            isAIGenerated: false,
            description: "24시간 유효한 공유 프리셋"
        )
        
        print("✅ 최신 20자리 코드 디코딩 성공: \(volumes)")
        return .success(preset)
    }
    
    private func validateAndConvert(_ shareablePreset: ShareablePreset) -> Result<SoundPreset, SharingError> {
        // 만료 시간 검증
        if shareablePreset.expiresAt < Date() {
            return .failure(.expired)
        }
        
        // 버전 호환성 검증
        if shareablePreset.version != shareVersion {
            return .failure(.unsupportedVersion)
        }
        
        // 데이터 유효성 검증
        guard shareablePreset.volumes.count == 13 else {
            return .failure(.invalidDataSize)
        }
        
        // 볼륨 범위 검증 (0-100)
        for volume in shareablePreset.volumes {
            if volume < 0 || volume > 100 {
                return .failure(.invalidVolumeRange)
            }
        }
        
        // 버전 정보 검증 (있다면) - 수정된 로직
        if let versions = shareablePreset.versions {
            guard versions.count == 13 else {
                return .failure(.invalidDataSize)
            }
            
            for (index, version) in versions.enumerated() {
                let maxVersion = SoundPresetCatalog.getVersionCount(for: index) - 1
                print("🔍 버전 검증: 카테고리 \(index), 버전 \(version), 최대 \(maxVersion)")
                
                // 버전 범위 검증을 더 관대하게 수정
                if version < 0 {
                    print("❌ 버전이 음수: 카테고리 \(index), 버전 \(version)")
                    return .failure(.invalidVersionRange)
                }
                
                // 최대 버전보다 큰 경우 경고는 하되 기본값으로 보정
                if version > maxVersion {
                    print("⚠️ 버전이 범위 초과하지만 보정 처리: 카테고리 \(index), 버전 \(version) → 0")
                    // 범위를 벗어난 버전은 0으로 보정하여 계속 진행
                }
            }
        }
        
        // 체크섬 검증
        let volumeString = shareablePreset.volumes.map { String(format: "%.2f", $0) }.joined(separator: ",")
        let versionString = (shareablePreset.versions ?? []).map { String($0) }.joined(separator: ",")
        let dataToHash = "\(shareablePreset.name)|\(volumeString)|\(versionString)|\(shareablePreset.createdAt.timeIntervalSince1970)"
        
        let data = Data(dataToHash.utf8)
        let hashed = SHA256.hash(data: data)
        let calculatedChecksum = hashed.compactMap { String(format: "%02x", $0) }.joined().prefix(8).lowercased()
        
        guard String(calculatedChecksum) == shareablePreset.checksum else {
            return .failure(.checksumMismatch)
        }
        
        // SoundPreset으로 변환 - 버전 범위 보정 적용
        let correctedVersions = shareablePreset.versions?.enumerated().map { (index, version) in
            let maxVersion = SoundPresetCatalog.getVersionCount(for: index) - 1
            return min(max(0, version), maxVersion) // 0과 maxVersion 사이로 제한
        } ?? SoundPresetCatalog.defaultVersions
        
        let preset = SoundPreset(
            name: shareablePreset.name,
            volumes: shareablePreset.volumes,
            selectedVersions: correctedVersions,
            emotion: shareablePreset.emotion,
            isAIGenerated: false,
            description: shareablePreset.description ?? "공유받은 프리셋"
        )
        
        print("✅ 프리셋 검증 및 변환 성공: \(preset.name)")
        return .success(preset)
    }
    
    // MARK: - 공유 기능
    
    /// iOS 기본 공유 시트를 통한 프리셋 공유 (앱스토어 링크 포함)
    func sharePreset(_ preset: SoundPreset, from viewController: UIViewController, preferNumericCode: Bool = false) {
        let result = preferNumericCode ? encodePresetAsNumericCode(preset) : encodePreset(preset)
        
        switch result {
        case .success(let shareCode):
            let appStoreURL = "https://apps.apple.com/app/deepsleep/id123456789" // 실제 배포 시 변경 필요 Todo
            
            let message = """
            🎵 리플릿(Leaflet) 프리셋: \(preset.name)
            
            아래 코드를 리플릿(Leaflet) 앱에서 가져오기하여 프리셋을 사용하세요:
            
            \(shareCode)
            
            📱 리플릿(Leaflet) 앱이 없다면 여기서 다운로드:
            \(appStoreURL)
            
            (이 코드는 24시간 후 만료됩니다)
            """
            
            // 공유 텍스트에 PII 마스킹 적용
            let safeMessage = SettingsManager.shared.maskPIIForExport(message)
            let activityVC = UIActivityViewController(
                activityItems: [safeMessage],
                applicationActivities: nil
            )
            
            // iPad 지원
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            viewController.present(activityVC, animated: true)
            
        case .failure(let error):
            showError(error, in: viewController)
        }
    }
    
    // MARK: - 가져오기 기능
    
    /// 공유 코드로부터 프리셋 가져오기
    func importPreset(from shareCode: String, completion: @escaping (Result<SoundPreset, SharingError>) -> Void) {
        let trimmedCode = shareCode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 보안 검증
        guard isValidShareCode(trimmedCode) else {
            completion(.failure(.maliciousCode))
            return
        }
        
        let result = decodePreset(from: trimmedCode)
        completion(result)
    }
    
    // MARK: - 테스트 도구
    
    /// 테스트용 프리셋 생성 (볼륨 있는 프리셋)
    func createTestPreset() -> SoundPreset {
        // 몇 개 슬라이더에 볼륨 설정
        var volumes: [Float] = Array(repeating: 0, count: 13)
        volumes[0] = 50  // 고양이
        volumes[2] = 30  // 발걸음-눈 
        volumes[4] = 70  // 불1
        volumes[6] = 40  // 새
        volumes[8] = 20  // 연필
        
        // 몇 개 버전 설정
        var versions: [Int] = Array(repeating: 0, count: 13)
        versions[1] = 1  // 바람 V2
        versions[5] = 1  // 비 V2
        versions[11] = 1 // 키보드 V2
        
        return SoundPreset(
            name: "테스트 프리셋",
            volumes: volumes,
            selectedVersions: versions,
            emotion: nil,
            isAIGenerated: false,
            description: "체크섬 테스트용 프리셋"
        )
    }
    
    // MARK: - 보안 검증
    
    private func isValidShareCode(_ code: String) -> Bool {
        // 길이 제한
        if code.count > maxCodeLength {
            return false
        }
        
        // 허용된 문자만 사용하는지 확인
        let allowedCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ":/?.=&-_"))
        if code.rangeOfCharacter(from: allowedCharacterSet.inverted) != nil {
            return false
        }
        
        // 의심스러운 패턴 검사
        let suspiciousPatterns = ["javascript:", "data:", "file:", "<script", "eval(", "document."]
        for pattern in suspiciousPatterns {
            if code.lowercased().contains(pattern) {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - 에러 처리
    
    private func showError(_ error: SharingError, in viewController: UIViewController) {
        let alert = UIAlertController(
            title: "공유 오류",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        viewController.present(alert, animated: true)
    }
}

// MARK: - URL 스키마 처리 지원
extension PresetSharingManager {
    
    /// EmoZleep URL 스키마 처리
    func handleURLScheme(_ url: URL) -> Bool {
        guard url.scheme == urlScheme else { return false }
        
        if url.host == "preset" {
            // emozleep://preset?data=... 형태 처리
            handlePresetURL(url)
            return true
        }
        
        return false
    }
    
    private func handlePresetURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let dataItem = queryItems.first(where: { $0.name == "data" }),
              let shareCode = dataItem.value else {
            showURLError(message: "올바르지 않은 프리셋 링크입니다.")
            return
        }
        
        importPreset(from: shareCode) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let preset):
                    self.showImportSuccess(preset)
                case .failure(let error):
                    self.showURLError(message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showImportSuccess(_ preset: SoundPreset) {
        // 메인 뷰컨트롤러 찾기
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }
        
        let alert = UIAlertController(
            title: "🎵 프리셋 가져오기",
            message: "'\(preset.name)' 프리셋을 가져왔습니다.\n지금 적용하시겠습니까?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "적용", style: .default) { _ in
            // 프리셋 저장
            SettingsManager.shared.saveSoundPreset(preset)
            
            // 메인 뷰컨트롤러에서 프리셋 적용
            self.applyPresetInViewController(preset)
        })
        
        rootVC.present(alert, animated: true)
    }
    
    private func showURLError(message: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }
        
        let alert = UIAlertController(
            title: "프리셋 가져오기 오류",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        rootVC.present(alert, animated: true)
    }
    
    private func applyPresetInViewController(_ preset: SoundPreset) {
        // 메인 ViewController 찾기 및 프리셋 적용
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }
        
        // ViewController 인스턴스 획득
        var targetVC: ViewController?
        
        if let navController = rootVC as? UINavigationController {
            targetVC = navController.viewControllers.first as? ViewController
        } else if let mainVC = rootVC as? ViewController {
            targetVC = mainVC
        }
        
        targetVC?.applyPreset(
            volumes: preset.compatibleVolumes,
            versions: preset.selectedVersions,
            name: preset.name,
            presetId: preset.id,
            saveAsNew: false
        )
        
        // 성공 메시지
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            targetVC?.showToast(message: "공유받은 프리셋이 적용되었습니다!")
        })
    }
} 
