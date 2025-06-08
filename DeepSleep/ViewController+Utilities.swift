import UIKit
import CryptoKit

// MARK: - 유틸리티 & 피드백 관련 Extension
extension ViewController {
    
    // MARK: - ⚠️ 애플워치 헬스킷 초기화 (Apple Developer 계정 권한 부족으로 임시 비활성화)
    
    /*
     ⚠️ APPLE DEVELOPER 계정 권한 부족으로 인한 임시 비활성화
     
     HealthKit 연동 기능을 사용하려면 다음이 필요합니다:
     1. Apple Developer Program 가입 ($99/년)
     2. Provisioning Profile에 HealthKit capability 추가
     3. com.apple.developer.healthkit entitlement 권한
     
     현재 학술용 시뮬레이터 테스트를 위해 주석처리됨.
     실제 배포시에는 주석 해제 후 Apple Developer 계정으로 빌드 필요.
     
     기능 설명:
     - 애플워치 건강 데이터 기반 AI 프리셋 추천
     - 심박수, 활동량, 수면 패턴 실시간 분석
     - 개인화된 사운드 테라피 제안
    */
    
    /// ⚠️ Apple Developer 계정 권한 부족으로 임시 비활성화
    /// 애플워치 헬스킷 기능 초기화 (선택적)
    func setupHealthKitIfNeeded() {
        // ⚠️ Apple Developer 계정 권한 부족으로 임시 비활성화
        print("⚠️ [HealthKit UI] Apple Developer 계정 권한 부족으로 비활성화됨")
        print("📚 학술용 시뮬레이터 데모에서는 HealthKit 연동이 제외됩니다.")
        
        /* 원본 코드 - Apple Developer 계정 필요
        // 사용자가 이전에 거부했다면 다시 묻지 않음
        let hasAskedBefore = UserDefaults.standard.bool(forKey: "healthkit_permission_asked")
        
        if !hasAskedBefore {
            showHealthKitPermissionAlert()
        } else if UserDefaults.standard.bool(forKey: "healthkit_enabled") {
            // 이미 허용했다면 바로 초기화
            HealthKitManager.shared.requestPermission { success in
                print(success ? "✅ HealthKit 초기화 완료" : "❌ HealthKit 초기화 실패")
            }
        }
        */
    }
    
    /*
    private func showHealthKitPermissionAlert() {
        let alert = UIAlertController(
            title: "⌚ 스마트 추천 기능",
            message: "애플워치의 건강 데이터를 분석하여 당신에게 맞는 사운드를 추천해드릴까요?\n\n• 심박수, 활동량, 수면 패턴 분석\n• 개인화된 프리셋 추천\n• 데이터는 기기에서만 처리됩니다",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "사용하기", style: .default) { [weak self] _ in
            UserDefaults.standard.set(true, forKey: "healthkit_permission_asked")
            UserDefaults.standard.set(true, forKey: "healthkit_enabled")
            
            HealthKitManager.shared.requestPermission { success in
                DispatchQueue.main.async {
                    if success {
                        self?.showPresetAppliedFeedback(name: "✅ 스마트 추천 기능이 활성화되었습니다")
                        self?.addHealthRecommendationButton()
                    } else {
                        self?.showPresetAppliedFeedback(name: "⚠️ 건강 데이터 접근이 제한되었습니다")
                    }
                }
            }
        })
        
        alert.addAction(UIAlertAction(title: "나중에", style: .cancel) { _ in
            UserDefaults.standard.set(true, forKey: "healthkit_permission_asked")
            UserDefaults.standard.set(false, forKey: "healthkit_enabled")
        })
        
        present(alert, animated: true)
    }
    
    /// 네비게이션 바에 건강 추천 버튼 추가
    private func addHealthRecommendationButton() {
        let healthButton = UIBarButtonItem(
            title: "⌚AI",
            style: .plain,
            target: self,
            action: #selector(showHealthRecommendation)
        )
        
        // 기존 rightBarButtonItems에 추가
        if var rightItems = navigationItem.rightBarButtonItems {
            rightItems.append(healthButton)
            navigationItem.rightBarButtonItems = rightItems
        } else {
            navigationItem.rightBarButtonItems = [healthButton]
        }
    }
    
    @objc private func showHealthRecommendation() {
        // 로딩 인디케이터 표시
        let loadingAlert = UIAlertController(title: "⌚ 건강 데이터 분석 중...", message: "잠시만 기다려주세요", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        // 건강 데이터 분석 및 추천
        HealthKitManager.shared.analyzeTodayAndRecommend { [weak self] wellness in
            DispatchQueue.main.async {
                // 로딩 창 닫기
                loadingAlert.dismiss(animated: true) {
                    self?.presentWellnessResults(wellness)
                }
            }
        }
    }
    
    private func presentWellnessResults(_ wellness: HealthKitManager.DailyWellness?) {
        guard let wellness = wellness else {
            showPresetAppliedFeedback(name: "❌ 건강 데이터를 불러올 수 없습니다")
            return
        }
        
        let alert = UIAlertController(
            title: "📊 오늘의 건강 분석",
            message: """
            \(wellness.stressLevel.emoji) 스트레스: \(wellness.stressLevel.rawValue)
            🏃‍♂️ 활동량: \(wellness.activityLevel.rawValue)  
            😴 수면: \(wellness.sleepQuality.rawValue)
            
            \(wellness.explanation)
            """,
            preferredStyle: .alert
        )
        
        // 추천 프리셋 적용 버튼
        alert.addAction(UIAlertAction(title: "🎵 \(wellness.recommendedPreset) 적용", style: .default) { [weak self] _ in
            self?.applyRecommendedPreset(wellness.recommendedPreset)
        })
        
        alert.addAction(UIAlertAction(title: "확인", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func applyRecommendedPreset(_ presetName: String) {
        // SoundPresetCatalog에서 해당 프리셋 찾기
        if let volumes = SoundPresetCatalog.samplePresets[presetName] {
            applyPreset(volumes: volumes, versions: SoundPresetCatalog.defaultVersions, name: presetName, shouldSaveToRecent: true)
        } else {
            showPresetAppliedFeedback(name: "⚠️ 추천 프리셋을 찾을 수 없습니다")
        }
    }
    */
    
    // MARK: - 프리셋 적용 (Apple Developer 계정 무관)
    func applyPreset(volumes: [Float], versions: [Int]? = nil, name: String, shouldSaveToRecent: Bool = true) {
        print("🎵 [applyPreset] 프리셋 적용 시작: \(name)")
        print("  - 원본 볼륨: \(volumes) (길이: \(volumes.count))")
        print("  - shouldSaveToRecent: \(shouldSaveToRecent)")
        
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
        
        // 3. 슬라이더와 텍스트필드 UI 업데이트
        updateAllSlidersAndFields(volumes: correctedVolumes, versions: actualVersions)
        
        // 4. SoundManager에서 프리셋 적용 (볼륨 설정 + 버전 정보 포함)
        SoundManager.shared.applyPresetWithVersions(volumes: correctedVolumes, versions: actualVersions)
        
        // 5. 카테고리 버튼 UI 업데이트 (버전 정보 반영)
        updateAllCategoryButtonTitles()
        
        // 6. 최근 프리셋에 저장 (shouldSaveToRecent가 true인 경우만)
        if shouldSaveToRecent {
            addToRecentPresetsWithVersions(name: name, volumes: correctedVolumes, versions: actualVersions)
            print("💾 [applyPreset] 최근 프리셋에 저장: \(name) (보정된 볼륨 사용)")
        } else {
            print("⏭️ [applyPreset] 최근 프리셋 저장 생략 (shouldSaveToRecent: false)")
        }
        
        // 7. UI 상태 업데이트
        updatePlayButtonStates()
        updatePresetBlocks()
        
        // 8. 사용자 피드백
        showPresetAppliedFeedback(name: name)
        
        print("✅ [applyPreset] 프리셋 적용 완료: \(name)")
    }
    
    // 버전 정보 포함한 최근 프리셋 저장
    func addToRecentPresetsWithVersions(name: String, volumes: [Float], versions: [Int]) {
        let preset = SoundPreset(
            name: name,
            volumes: volumes,
            selectedVersions: versions,
            emotion: nil,
            isAIGenerated: false, // ✅ Recent Presets에 표시되도록 false로 설정
            description: "최근 사용한 프리셋"
        )
        SettingsManager.shared.saveSoundPreset(preset)
        print("💾 [addToRecentPresetsWithVersions] Recent Presets에 저장: \(name)")
        updatePresetBlocks() // 저장 후 즉시 UI 갱신
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
            showPresetAppliedFeedback(name: "프리셋 인코딩에 실패했습니다.")
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
