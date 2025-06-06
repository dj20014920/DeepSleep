import UIKit
import CryptoKit

// MARK: - 유틸리티 & 피드백 관련 Extension
extension ViewController {
    
    // MARK: - 프리셋 적용
    func applyPreset(volumes: [Float], name: String, shouldSaveToRecent: Bool = true) {
        // 1. 슬라이더와 텍스트필드 UI 업데이트 (실제 재생은 하지 않음)
        for (i, volume) in volumes.enumerated() where i < sliders.count {
            let intVolume = Int(volume)
            let clampedVolume = max(0, min(100, intVolume))
            
            sliders[i].value = Float(clampedVolume)
            volumeFields[i].text = "\(clampedVolume)"
        }
        
        // 2. SoundManager에서 프리셋 적용 (볼륨 설정 + 적절한 재생/정지)
        SoundManager.shared.applyPreset(volumes: volumes)
        
        // 3. 즐겨찾기 프리셋인 경우 최근 프리셋에 저장하지 않음
        if shouldSaveToRecent {
            addToRecentPresets(name: name, volumes: volumes)
        }
        
        updatePlayButtonStates()
        updatePresetBlocks()
        showPresetAppliedFeedback(name: name)
    }
    
    // MARK: - 피드백
    func provideLightHapticFeedback() {
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
    }
    
    func provideMediumHapticFeedback() {
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
    }
    
    func showPresetAppliedFeedback(name: String) {
        let toastLabel = UILabel()
        toastLabel.text = "🎵 \(name) 적용됨"
        toastLabel.backgroundColor = UIColor.label.withAlphaComponent(0.8)
        toastLabel.textColor = .systemBackground
        toastLabel.textAlignment = .center
        toastLabel.font = .systemFont(ofSize: 14, weight: .medium)
        toastLabel.layer.cornerRadius = 8
        toastLabel.clipsToBounds = true
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(toastLabel)
        
        NSLayoutConstraint.activate([
            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toastLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            toastLabel.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        toastLabel.alpha = 0
        UIView.animate(withDuration: 0.3, animations: {
            toastLabel.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5, animations: {
                toastLabel.alpha = 0
            }) { _ in
                toastLabel.removeFromSuperview()
            }
        }
    }
    
    // MARK: - 키보드 처리
    @objc func keyboardWillShow(notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        let keyboardHeight = keyboardFrame.height
        if let scrollView = view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
            scrollView.contentInset.bottom = keyboardHeight
            scrollView.verticalScrollIndicatorInsets.bottom = keyboardHeight
        }
    }
    
    @objc func keyboardWillHide(notification: Notification) {
        if let scrollView = view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
            scrollView.contentInset.bottom = 0
            scrollView.verticalScrollIndicatorInsets.bottom = 0
        }
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - 네비게이션
    @objc func savePresetTapped() {
        let alert = UIAlertController(title: "프리셋 저장", message: "프리셋 이름을 입력하세요", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "내 프리셋"
        }
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "저장", style: .default) { [weak self] _ in
            guard let self = self,
                  let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { return }
            
            let volumes = self.sliders.map { Float(Int($0.value)) }
            let versions = (0..<SoundPresetCatalog.categoryCount).map { i in
                SettingsManager.shared.getSelectedVersion(for: i)
            }
            
            let preset = SoundPreset(
                name: name,
                volumes: volumes,
                selectedVersions: versions,
                isAIGenerated: false,
                description: "사용자가 직접 저장한 프리셋"
            )
            
            SettingsManager.shared.saveSoundPreset(preset)
            self.updatePresetBlocks()
            self.showPresetAppliedFeedback(name: "프리셋 '\(name)' 저장됨")
        })
        present(alert, animated: true)
    }
    
    @objc func shareCurrentPresetTapped() {
        // 현재 설정을 임시 프리셋으로 생성하여 공유
        let volumes = sliders.map { Float(Int($0.value)) }
        let versions = (0..<SoundPresetCatalog.categoryCount).map { i in
            SettingsManager.shared.getSelectedVersion(for: i)
        }
        
        let tempPreset = SoundPreset(
            name: "현재 설정",
            volumes: volumes,
            selectedVersions: versions,
            isAIGenerated: false,
            description: "현재 슬라이더 설정"
        )
        
        showShareOptions(for: tempPreset)
    }
    
    private func showShareOptions(for preset: SoundPreset) {
        let alert = UIAlertController(
            title: "🎵 프리셋 공유",
            message: "'\(preset.name)' 프리셋을 어떻게 공유하시겠습니까?",
            preferredStyle: .actionSheet
        )
        
        // URL 링크로 공유
        alert.addAction(UIAlertAction(title: "링크로 공유", style: .default) { [weak self] _ in
            self?.sharePresetAsURL(preset)
        })
        
        // 숫자 코드로 공유
        alert.addAction(UIAlertAction(title: "숫자 코드로 공유", style: .default) { [weak self] _ in
            self?.sharePresetAsCode(preset)
        })
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        
        // iPad 지원
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    private func sharePresetAsURL(_ preset: SoundPreset) {
        do {
            let shareablePreset = ShareablePreset(from: preset)
            let jsonData = try JSONEncoder().encode(shareablePreset)
                         let base64String = jsonData.base64EncodedString()
             let shareURL = "emozleep://preset?data=\(base64String)"
            
                         let message = """
             🎵 EmoZleep 프리셋: \(preset.name)
             
             아래 링크를 클릭하여 프리셋을 가져오세요:
             
             \(shareURL)
             
             (이 링크는 24시간 후 만료됩니다)
             """
            
            shareContent(message)
        } catch {
            showToast(message: "프리셋 인코딩에 실패했습니다.")
        }
    }
    
    private func sharePresetAsCode(_ preset: SoundPreset) {
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
        let checksum = Int(volumeSum) % 100  // 00-99로 제한
        code += String(format: "%02d", checksum)
        
        let message = """
        🎵 EmoZleep 프리셋: \(preset.name)
        
        아래 코드를 EmoZleep 앱에서 가져오기하여 프리셋을 사용하세요:
        
        \(code)
        
        (이 코드는 24시간 후 만료됩니다)
        """
        
        shareContent(message)
    }
    
    private func shareContent(_ content: String) {
        let activityVC = UIActivityViewController(
            activityItems: [content],
            applicationActivities: nil
        )
        
        // iPad 지원
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(activityVC, animated: true)
    }
    
    @objc func loadPresetTapped() {
        showPresetList()
    }

    @objc func showTimer() {
        let vc = TimerViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - 공유 데이터 모델
private struct ShareablePreset: Codable {
    let version: String
    let name: String
    let volumes: [Float]
    let versions: [Int]?
    let emotion: String?
    let description: String?
    let createdAt: Date
    let expiresAt: Date
    let checksum: String
    
    init(from preset: SoundPreset) {
        self.version = "v1.0"
        self.name = preset.name
        self.volumes = preset.compatibleVolumes
        self.versions = preset.compatibleVersions
        self.emotion = preset.emotion
        self.description = preset.description
        self.createdAt = Date()
        self.expiresAt = Date().addingTimeInterval(24 * 3600) // 24시간 후 만료
        
        // 체크섬 계산
        let volumeString = volumes.map { String(format: "%.2f", $0) }.joined(separator: ",")
        let versionString = (versions ?? []).map { String($0) }.joined(separator: ",")
        let dataToHash = "\(name)|\(volumeString)|\(versionString)|\(createdAt.timeIntervalSince1970)"
        
        let data = Data(dataToHash.utf8)
        let hashed = SHA256.hash(data: data)
        self.checksum = hashed.compactMap { String(format: "%02x", $0) }.joined().prefix(8).lowercased()
    }
}
