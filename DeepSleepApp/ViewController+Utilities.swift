import UIKit
import CryptoKit

// MARK: - 유틸리티 & 피드백 관련 Extension
extension ViewController {
    
    // 건강 분석 알림 표시 (HealthKit 제거 이후도 사용 가능하도록 일반화)
    private func showWellnessAlert(
        stressEmoji: String,
        stressText: String,
        activityText: String,
        sleepText: String,
        explanation: String,
        recommendedPreset: String
    ) {
        let alert = UIAlertController(
            title: "📊 오늘의 건강 분석",
            message: """
            \(stressEmoji) 스트레스: \(stressText)
            🏃‍♂️ 활동량: \(activityText)
            😴 수면: \(sleepText)
            
            \(explanation)
            """,
            preferredStyle: .alert
        )
        
        // 추천 프리셋 적용 버튼
        alert.addAction(UIAlertAction(title: "🎵 \(recommendedPreset) 적용", style: .default) { [weak self] _ in
            self?.applyRecommendedPreset(recommendedPreset)
        })
        
        alert.addAction(UIAlertAction(title: "확인", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func applyRecommendedPreset(_ presetName: String) {
        // SoundPresetCatalog에서 해당 프리셋 찾기
        if let volumes = SoundPresetCatalog.samplePresets[presetName] {
            applyPreset(volumes: volumes, versions: SoundPresetCatalog.defaultVersions, name: presetName)
        } else {
            showPresetAppliedFeedback(name: "⚠️ 추천 프리셋을 찾을 수 없습니다")
        }
    }
    
    // MARK: - 프리셋 적용 (Apple Developer 계정 무관)
    
    /// `presetId`가 필요 없는 기존 호출을 위한 래퍼 함수
    func applyPreset(volumes: [Float], versions: [Int]? = nil, name: String) {
        // "실시간 조절"의 경우, 프리셋으로 저장하거나 사용시간을 갱신하지 않음
        if name == "실시간 조절" {
             applyPreset(volumes: volumes, versions: versions, name: name, presetId: nil, saveAsNew: false)
        } else {
            // 그 외의 경우는 신규 저장으로 간주 (채팅 추천 등)
            applyPreset(volumes: volumes, versions: versions, name: name, presetId: nil, saveAsNew: true)
        }
    }

    /// 모든 로직을 처리하는 메인 프리셋 적용 함수
    func applyPreset(volumes: [Float], versions: [Int]? = nil, name: String, presetId: UUID?, saveAsNew: Bool = false) {
        print("🎵 [applyPreset] 프리셋 적용 시작: \(name), ID: \(presetId?.uuidString ?? "없음"), 신규 저장: \(saveAsNew)")
        print("  - 원본 볼륨: \(volumes) (길이: \(volumes.count))")
        
        // ✅ 배열 크기 자동 보정 (11개 → 13개, 12개 → 13개)
        var correctedVolumes = volumes
        if volumes.count == 11 {
            // 11개를 13개로 확장 (끝에 2개 추가)
            correctedVolumes = volumes + [0.0, 0.0]
            print("  - ✅ 11개 → 13개 볼륨 배열 보정: \(correctedVolumes)")
        } else if volumes.count == 12 {
            // 12개를 13개로 확장 (끝에 1개 추가)
            correctedVolumes = volumes + [0.0]
            print("  - ✅ 12개 → 13개 볼륨 배열 보정: \(correctedVolumes)")
        } else if volumes.count != SoundPresetCatalog.categoryCount {
            // 다른 크기는 13개로 맞춤
            correctedVolumes = Array(repeating: 0.0, count: SoundPresetCatalog.categoryCount)
            for i in 0..<min(volumes.count, correctedVolumes.count) {
                correctedVolumes[i] = volumes[i]
            }
            print("  - ⚠️ \(volumes.count)개 → 13개 볼륨 배열 보정: \(correctedVolumes)")
        }
        
        let actualVersions = versions ?? SoundPresetCatalog.defaultVersions
        print("  - 버전: \(actualVersions)")
        
        // 2. 최종 배열 크기 검증
        guard correctedVolumes.count == SoundPresetCatalog.categoryCount,
              actualVersions.count == SoundPresetCatalog.categoryCount else {
            print("❌ [applyPreset] 배열 크기 오류: 볼륨(\(correctedVolumes.count)) 또는 버전(\(actualVersions.count)) ≠ 카테고리 수(\(SoundPresetCatalog.categoryCount))")
            showToast(message: "프리셋 적용 오류: 데이터 형식을 보정할 수 없습니다")
            return
        }
        
        // 2. 버전 정보를 SettingsManager에 저장
        for (categoryIndex, versionIndex) in actualVersions.enumerated() {
            if categoryIndex < SoundPresetCatalog.categoryCount {
                SettingsManager.shared.updateSelectedVersion(for: categoryIndex, to: versionIndex)
            }
        }
        
        // 3. 🔧 통합된 볼륨 설정: updateAllSlidersAndFields에서 UI + SoundManager 모두 처리
        updateAllSlidersAndFields(volumes: correctedVolumes, versions: actualVersions)
        
        // 4. 🚫 중복된 SoundManager 호출 제거 (updateAllSlidersAndFields에서 이미 처리함)
        
        // 5. 카테고리 버튼 UI 업데이트 (버전 정보 반영)
        updateAllCategoryButtonTitles()
        
        // 6. ✅ 프리셋 저장/갱신 로직 - 🛡️ 안전한 저장 사용
        if let id = presetId {
            // ID가 있으면 기존 프리셋의 사용 시간 갱신
            SettingsManager.shared.updatePresetTimestamp(id: id)
            print("💾 [applyPreset] 최근 프리셋으로 시간 갱신: \(name)")
            
            // ✅ 최근 사용한 프리셋 UI 갱신 알림 발송
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("RecentPresetsUpdated"), object: nil)
            }
        } else if saveAsNew {
            // ID가 없고 saveAsNew가 true이면 새로운 프리셋으로 저장 - 🛡️ 안전한 저장 사용
            let newPreset = SoundPreset(
                name: name,
                volumes: correctedVolumes,
                selectedVersions: actualVersions,
                isAIGenerated: false,
                description: "신규 저장된 프리셋"
            )
            
            // 🛡️ 안전한 저장 메서드 사용
            let result = SettingsManager.shared.saveSoundPresetSafely(newPreset, allowOverwrite: false)
            
            if result.success {
                if result.wasRenamed {
                    print("💾 [applyPreset] 중복 이름으로 인해 변경됨: \(name) → \(result.finalName)")
                    showToast(message: "프리셋이 '\(result.finalName)'으로 저장되었습니다")
                } else {
                    print("💾 [applyPreset] 신규 프리셋 저장 완료: \(result.finalName)")
                    showToast(message: "'\(result.finalName)' 프리셋이 저장되었습니다")
                }
        } else {
                print("❌ [applyPreset] 프리셋 저장 실패: \(name)")
                showToast(message: "프리셋 저장에 실패했습니다")
            }
        }
        
        // 7. UI 상태 업데이트
        updatePlayButtonStates()
        updatePresetBlocks()
        
        // 8. 사용자 피드백
        showPresetAppliedFeedback(name: name)
        
        print("✅ [applyPreset] 프리셋 적용 완료: \(name)")
    }
    
    // MARK: - 피드백 (Apple Developer 계정 무관)
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
            toastLabel.bottomAnchor.constraint(equalTo: contentBottomAnchor(), constant: -20),
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
    
    // MARK: - 키보드 처리 (Apple Developer 계정 무관)
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
        // PresetSharingManager의 통일된 메서드 사용
        PresetSharingManager.shared.sharePreset(preset, from: self, preferNumericCode: false)
    }
    
    private func sharePresetAsCode(_ preset: SoundPreset) {
        // PresetSharingManager의 통일된 메서드 사용
        PresetSharingManager.shared.sharePreset(preset, from: self, preferNumericCode: true)
    }
    
    private func shareContent(_ content: String) {
        // 모든 공유 텍스트는 PII 마스킹 적용
        let masked = SettingsManager.shared.maskPIIForExport(content)
        let activityVC = UIActivityViewController(
            activityItems: [masked],
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
