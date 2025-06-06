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
            self.volumes = preset.compatibleVolumes  // 11개로 정규화
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
    
    /// 간단한 숫자 코드 형태로 변환 (16자리로 압축)
    func encodePresetAsNumericCode(_ preset: SoundPreset) -> Result<String, SharingError> {
        let volumes = preset.compatibleVolumes
        let versions = preset.compatibleVersions
        
        var code = "EZ"  // EmoZleep 식별자 (2자리)
        
        // 볼륨을 Base36으로 압축 (0-100을 0-35로 매핑, 11자리)
        for volume in volumes {
            let normalizedVolume = Int(min(100, max(0, volume)))
            let compressed = normalizedVolume * 35 / 100  // 0-100을 0-35로 압축
            code += String(compressed, radix: 36)  // Base36 (0-9, a-z)
        }
        
        // 버전 정보를 비트마스크로 압축 (1자리)
        // 비(인덱스4)와 키보드(인덱스9)만 2가지 버전 있음
        var versionBits = 0
        if versions[4] == 1 { versionBits |= 1 }  // 비 V2
        if versions[9] == 1 { versionBits |= 2 }  // 키보드 V2
        code += String(versionBits, radix: 36)  // 0,1,2,3을 0,1,2,3으로
        
        // 간단한 체크섬 (2자리)
        let volumeSum = volumes.reduce(0, +)
        let checksum = Int(volumeSum) % 1296  // 36^2 = 1296
        code += String(format: "%02d", checksum % 100)  // 00-99로 제한
        
        print("✅ 압축 숫자 코드 생성: \(code) (\(code.count) chars)")
        return .success(code)
    }
    
    // MARK: - 프리셋 디코딩
    
    /// 공유 코드에서 프리셋 복원
    func decodePreset(from shareCode: String) -> Result<SoundPreset, SharingError> {
        // URL 스키마 처리
        if shareCode.hasPrefix(urlScheme) {
            return decodeFromURL(shareCode)
        }
        
        // 숫자 코드 처리
        if shareCode.hasPrefix("EZL") {
            return decodeFromNumericCode(shareCode)
        }
        
        // Base64 직접 처리
        return decodeFromBase64(shareCode)
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
        // EZ + (11자리 볼륨) + (1자리 버전) + (2자리 체크섬) = 16자리
        guard code.count == 16 else {
            return .failure(.invalidFormat)
        }
        
        let prefix = String(code.prefix(2))  // EZ
        guard prefix == "EZ" else {
            return .failure(.invalidFormat)
        }
        
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
        
        // 버전 정보 추출 (1자리)
        let versionIndex = code.index(code.startIndex, offsetBy: 13)
        let versionChar = String(code[versionIndex])
        guard let versionBits = Int(versionChar, radix: 36) else {
            return .failure(.corruptedData)
        }
        
        // 기본 버전 배열 생성
        var versions = SoundPresetCatalog.defaultVersionSelection
        
        // 비트마스크 디코딩
        if versionBits & 1 != 0 { versions[4] = 1 }  // 비 V2
        if versionBits & 2 != 0 { versions[9] = 1 }  // 키보드 V2
        
        // 체크섬 검증 (2자리)
        let checksumPart = String(code.suffix(2))
        guard let receivedChecksum = Int(checksumPart) else {
            return .failure(.corruptedData)
        }
        
        let volumeSum = volumes.reduce(0, +)
        let expectedChecksum = Int(volumeSum) % 100
        
        guard receivedChecksum == expectedChecksum else {
            return .failure(.checksumMismatch)
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
        
        print("✅ 압축 숫자 코드 디코딩 성공: \(volumes)")
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
        guard shareablePreset.volumes.count == 11 else {
            return .failure(.invalidDataSize)
        }
        
        // 볼륨 범위 검증 (0-100)
        for volume in shareablePreset.volumes {
            if volume < 0 || volume > 100 {
                return .failure(.invalidVolumeRange)
            }
        }
        
        // 버전 정보 검증 (있다면)
        if let versions = shareablePreset.versions {
            guard versions.count == 11 else {
                return .failure(.invalidDataSize)
            }
            
            for (index, version) in versions.enumerated() {
                let maxVersion = SoundPresetCatalog.getVersionCount(at: index) - 1
                if version < 0 || version > maxVersion {
                    return .failure(.invalidVersionRange)
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
        
        // SoundPreset으로 변환
        let preset = SoundPreset(
            name: shareablePreset.name,
            volumes: shareablePreset.volumes,
            selectedVersions: shareablePreset.versions ?? SoundPresetCatalog.defaultVersionSelection,
            emotion: shareablePreset.emotion,
            isAIGenerated: false,
            description: shareablePreset.description ?? "공유받은 프리셋"
        )
        
        print("✅ 프리셋 검증 및 변환 성공: \(preset.name)")
        return .success(preset)
    }
    
    // MARK: - 공유 기능
    
    /// iOS 기본 공유 시트를 통한 프리셋 공유
    func sharePreset(_ preset: SoundPreset, from viewController: UIViewController, preferNumericCode: Bool = false) {
        let result = preferNumericCode ? encodePresetAsNumericCode(preset) : encodePreset(preset)
        
        switch result {
        case .success(let shareCode):
            let message = """
            🎵 EmoZleep 프리셋: \(preset.name)
            
            아래 코드를 EmoZleep 앱에서 가져오기하여 프리셋을 사용하세요:
            
            \(shareCode)
            
            (이 코드는 24시간 후 만료됩니다)
            """
            
            let activityVC = UIActivityViewController(
                activityItems: [message],
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
            self.applyPresetInMainViewController(preset)
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
    
    private func applyPresetInMainViewController(_ preset: SoundPreset) {
        // 메인 ViewController 찾기 및 프리셋 적용
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }
        
        var targetVC: ViewController?
        
        if let navController = rootVC as? UINavigationController {
            targetVC = navController.viewControllers.first as? ViewController
        } else if let mainVC = rootVC as? ViewController {
            targetVC = mainVC
        }
        
        targetVC?.applyPreset(
            volumes: preset.compatibleVolumes,
            versions: preset.compatibleVersions,
            name: preset.name
        )
        
        // 성공 메시지
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            targetVC?.showToast(message: "공유받은 프리셋이 적용되었습니다!")
        }
    }
} 