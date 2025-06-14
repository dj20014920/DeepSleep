import UIKit

// MARK: - 슬라이더 UI 및 제어 관련 Extension (11개 이모지 카테고리)
extension ViewController {
    
    func setupSliderUI() {
        let scrollView = UIScrollView()
        let containerView = UIView()
        let stackView = UIStackView()
        [scrollView, containerView, stackView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .automatic
        
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        containerView.addSubview(stackView)

        let controlsStack = UIStackView()
        controlsStack.axis = .horizontal
        controlsStack.spacing = 12
        controlsStack.translatesAutoresizingMaskIntoConstraints = false

        // 오디오 모드 버튼을 첫 번째로 배치
        audioModeButton = UIButton(type: .system)
        audioModeButton.setImage(UIImage(systemName: "speaker.wave.3"), for: .normal)
        audioModeButton.tintColor = UIDesignSystem.Colors.primaryText
        audioModeButton.addTarget(self, action: #selector(audioModeButtonTapped), for: .touchUpInside)
        updateAudioModeButtonTitle()

        let playAll = UIButton(type: .system)
        playAll.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playAll.tintColor = UIDesignSystem.Colors.primaryText
        playAll.addTarget(self, action: #selector(playAllTapped), for: .touchUpInside)

        let pauseAll = UIButton(type: .system)
        pauseAll.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        pauseAll.tintColor = UIDesignSystem.Colors.primaryText
        pauseAll.addTarget(self, action: #selector(pauseAllTapped), for: .touchUpInside)

        [audioModeButton, playAll, pauseAll].forEach { controlsStack.addArrangedSubview($0) }
        containerView.addSubview(controlsStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 70),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            containerView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            controlsStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            controlsStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            stackView.topAnchor.constraint(equalTo: controlsStack.bottomAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20)
        ])

        stackView.axis = .vertical
        stackView.spacing = 16

        // 마스터 볼륨 슬라이더 추가
        setupMasterVolumeSlider(stackView: stackView)

        let categoryCount = SoundPresetCatalog.categoryCount
        
        sliders.removeAll()
        volumeFields.removeAll()
        playButtons.removeAll()
        previewSeekSliders.removeAll()

        for i in 0..<categoryCount {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 12

            let categoryButton = UIButton(type: .system)
            updateCategoryButtonTitle(categoryButton, for: i)
            categoryButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
            categoryButton.contentHorizontalAlignment = .left
            categoryButton.setTitleColor(UIDesignSystem.Colors.primaryText, for: .normal)
            categoryButton.tag = i
            categoryButton.widthAnchor.constraint(equalToConstant: 90).isActive = true
            categoryButton.addTarget(self, action: #selector(categoryButtonTapped(_:)), for: .touchUpInside)
            
            let slider = UISlider()
            slider.minimumValue = 0
            slider.maximumValue = 100
            slider.value = 0
            slider.tag = i
            slider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)
            sliders.append(slider)

            let volumeField = UITextField()
            volumeField.text = "0"
            volumeField.borderStyle = .roundedRect
            volumeField.keyboardType = .numberPad
            volumeField.tag = i
            volumeField.delegate = self
            volumeField.widthAnchor.constraint(equalToConstant: 50).isActive = true
            volumeField.addTarget(self, action: #selector(textFieldChanged(_:)), for: .editingChanged)
            volumeField.addTarget(self, action: #selector(textFieldEditingEnded(_:)), for: .editingDidEnd)
            volumeFields.append(volumeField)

            let playButton = UIButton(type: .system)
            playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            playButton.tintColor = UIDesignSystem.Colors.primaryText
            playButton.tag = i
            playButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
            playButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
            playButton.addTarget(self, action: #selector(toggleTrack(_:)), for: .touchUpInside)
            playButtons.append(playButton)

            rowStack.addArrangedSubview(categoryButton)
            rowStack.addArrangedSubview(slider)
            rowStack.addArrangedSubview(volumeField)
            rowStack.addArrangedSubview(playButton)

            let previewSeekSlider = UISlider()
            previewSeekSlider.minimumValue = 0
            previewSeekSlider.maximumValue = 1
            previewSeekSlider.value = 0
            previewSeekSlider.tag = i
            previewSeekSlider.isHidden = true
            previewSeekSlider.addTarget(self, action: #selector(previewSeekSliderChanged(_:)), for: .valueChanged)
            previewSeekSliders.append(previewSeekSlider)

            let fullRowStack = UIStackView()
            fullRowStack.axis = .vertical
            fullRowStack.spacing = 8
            fullRowStack.addArrangedSubview(rowStack)
            fullRowStack.addArrangedSubview(previewSeekSlider)

            stackView.addArrangedSubview(fullRowStack)
        }
        
        print("✅ \(categoryCount)개 카테고리 슬라이더 UI 생성 완료 - 미리듣기 버튼 변경됨")
    }
    
    // MARK: - 마스터 볼륨 설정
    
    private func setupMasterVolumeSlider(stackView: UIStackView) {
        // 마스터 볼륨 컨트롤 행 (간단하게)
        let masterRowStack = UIStackView()
        masterRowStack.axis = .horizontal
        masterRowStack.spacing = 12
        
        // 40px 너비의 빈 공간 (슬라이더를 더 길게)
        let spacerView = UIView()
        spacerView.widthAnchor.constraint(equalToConstant: 40).isActive = true
        
        masterVolumeSlider = UISlider()
        masterVolumeSlider.minimumValue = 0
        masterVolumeSlider.maximumValue = 200  // 최대 200%로 확장하여 증폭 가능
        masterVolumeSlider.value = 100  // 기본값 100%로 변경 (정상 작동)
        masterVolumeLevel = 100  // 초기값 100%로 설정
        masterVolumeSlider.addTarget(self, action: #selector(masterVolumeChanged(_:)), for: .valueChanged)
        
        masterVolumeField = UITextField()
        masterVolumeField.text = "100"  // 기본값 100%
        masterVolumeField.borderStyle = .roundedRect
        masterVolumeField.keyboardType = .numberPad
        masterVolumeField.delegate = self
        masterVolumeField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        masterVolumeField.addTarget(self, action: #selector(masterVolumeFieldChanged(_:)), for: .editingChanged)
        masterVolumeField.addTarget(self, action: #selector(masterVolumeFieldEditingEnded(_:)), for: .editingDidEnd)
        
        // 15px 너비의 빈 공간 (슬라이더를 더 길게)
        let endSpacerView = UIView()
        endSpacerView.widthAnchor.constraint(equalToConstant: 15).isActive = true
        
        masterRowStack.addArrangedSubview(spacerView)
        masterRowStack.addArrangedSubview(masterVolumeSlider)
        masterRowStack.addArrangedSubview(masterVolumeField)
        masterRowStack.addArrangedSubview(endSpacerView)
        
        // 구분선
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        
        // 스택뷰에 추가
        stackView.addArrangedSubview(masterRowStack)
        stackView.addArrangedSubview(separator)
        
        // 약간의 여백 추가
        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
        stackView.addArrangedSubview(spacer)
    }
    
    // MARK: - 마스터 볼륨 액션
    
    @objc private func masterVolumeChanged(_ sender: UISlider) {
        // 마스터 볼륨 임계값 체크
        let volumeInt = Int(sender.value)
        if volumeInt > volumeThreshold && !hasMasterOverride {
            if let vc = findViewController() {
                let alert = UIAlertController(title: "주의", message: "큰 소리는 집중이나 수면을 방해할 수 있습니다. 계속 높이시겠습니까?", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "계속", style: .default) { _ in
                    self.hasMasterOverride = true
                    self.masterVolumeChanged(sender)
                })
                alert.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in
                    let thresholdValue = Float(self.volumeThreshold)
                    sender.value = thresholdValue
                    self.masterVolumeField.text = "\(self.volumeThreshold)"
                    self.masterVolumeLevel = thresholdValue
                    self.applyMasterVolumeToSoundManager()
                })
                vc.present(alert, animated: true)
            }
            return
        }
        // 임계값 이하로 낮추면 재확인 필요
        if volumeInt <= volumeThreshold {
            hasMasterOverride = false
        }
        let newMasterVolume = sender.value
        masterVolumeLevel = newMasterVolume
        masterVolumeField.text = "\(Int(newMasterVolume))"
        
        // 개별 슬라이더 위치는 그대로 두고 SoundManager에만 마스터 볼륨 적용
        applyMasterVolumeToSoundManager()
        provideLightHapticFeedback()
    }
    
    @objc private func masterVolumeFieldChanged(_ sender: UITextField) {
        guard let text = sender.text else { return }
        let sanitizedText = sanitizeVolumeInput(text)
        if sanitizedText != text {
            sender.text = sanitizedText
        }
    }
    
    @objc private func masterVolumeFieldEditingEnded(_ sender: UITextField) {
        // 마스터 볼륨 임계값 체크
        guard let text = sender.text,
              let volume = Int(text) else { return }
        if volume > volumeThreshold && !hasMasterOverride {
            if let vc = findViewController() {
                let alert = UIAlertController(title: "주의: 큰 소리", message: "이 소리는 집중이나 수면을 방해할 수 있습니다. 계속 높이시겠습니까?", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "계속", style: .default) { _ in
                    self.hasMasterOverride = true
                    self.masterVolumeFieldEditingEnded(sender)
                })
                alert.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in
                    let threshold = self.volumeThreshold
                    sender.text = "\(threshold)"
                    self.masterVolumeSlider.value = Float(threshold)
                    self.masterVolumeLevel = Float(threshold)
                    self.applyMasterVolumeToSoundManager()
                })
                vc.present(alert, animated: true)
            }
            return
        }
        // 임계값 이하로 낮추면 재확인 필요
        if volume <= volumeThreshold {
            hasMasterOverride = false
        }
        let clampedVolume = validateAndClampMasterVolume(text)
        sender.text = "\(clampedVolume)"
        masterVolumeSlider.value = Float(clampedVolume)
        masterVolumeLevel = Float(clampedVolume)
        
        // 개별 슬라이더 위치는 그대로 두고 SoundManager에만 마스터 볼륨 적용
        applyMasterVolumeToSoundManager()
        provideMediumHapticFeedback()
        
        print("🔊 마스터볼륨 변경: \(clampedVolume)% (최대 200% 가능)")
    }
    
    /// 마스터 볼륨을 SoundManager에만 적용 (슬라이더 위치는 변경하지 않음)
    private func applyMasterVolumeToSoundManager() {
        let masterMultiplier = masterVolumeLevel / 100.0
        
        // 현재 슬라이더 값들에 마스터 볼륨 배율을 적용해서 SoundManager에 전달
        for (index, slider) in sliders.enumerated() {
            let actualVolume = slider.value * masterMultiplier
            SoundManager.shared.setVolume(at: index, volume: actualVolume)
        }
    }
    
    // MARK: - 카테고리 버튼 액션 (미리듣기 및 버전 선택 통합)
    

    
    @objc private func categoryButtonTapped(_ sender: UIButton) {
        let categoryIndex = sender.tag
        let currentVersion = SoundManager.shared.getCurrentVersions()[categoryIndex]
        let versionCount = SoundPresetCatalog.getVersionCount(for: categoryIndex)
        let categoryName = SoundPresetCatalog.displayLabels[categoryIndex]
        
        // 바로 버전 선택 메뉴 표시 (iOS 14+)
        if #available(iOS 14.0, *) {
            let alertController = UIAlertController(title: "\(categoryName) 버전 선택", message: nil, preferredStyle: .actionSheet)
            
            // 각 버전별 액션 추가
            for versionIndex in 0..<versionCount {
                let versionTitle = "Ver \(versionIndex + 1)/\(versionCount)"
                let isCurrentVersion = versionIndex == currentVersion
                
                let action = UIAlertAction(title: versionTitle, style: .default) { [weak self] _ in
                    self?.selectVersion(categoryIndex: categoryIndex, versionIndex: versionIndex)
                }
                
                if isCurrentVersion {
                    action.setValue(UIImage(systemName: "checkmark.circle.fill"), forKey: "image")
                } else {
                    action.setValue(UIImage(systemName: "music.note"), forKey: "image")
                }
                
                alertController.addAction(action)
            }
            
            alertController.addAction(UIAlertAction(title: "취소", style: .cancel, handler: nil))
            
            // iPad 지원
            if let popover = alertController.popoverPresentationController {
                popover.sourceView = sender
                popover.sourceRect = sender.bounds
            }
            
            if let viewController = findViewController() {
                viewController.present(alertController, animated: true)
            }
        } else {
            // iOS 14 미만에서는 다음 버전으로 순환
            let nextVersion = (currentVersion + 1) % versionCount
            selectVersion(categoryIndex: categoryIndex, versionIndex: nextVersion)
        }
        
        provideMediumHapticFeedback()
    }

    // MARK: - 버전 선택 메서드
    private func selectVersion(categoryIndex: Int, versionIndex: Int) {
        // 1. 버전 변경을 SoundManager에 적용
        SoundManager.shared.selectVersion(categoryIndex: categoryIndex, versionIndex: versionIndex)
        
        // 2. SettingsManager에도 버전 정보 저장 (핵심 수정!)
        SettingsManager.shared.updateSelectedVersion(for: categoryIndex, to: versionIndex)
        
        // 3. 현재 재생 중인 해당 카테고리의 음원도 새 버전으로 변경
        let currentVolume = sliders[categoryIndex].value
        if currentVolume > 0 {
            let actualVolume = currentVolume * (masterVolumeLevel / 100.0)
            SoundManager.shared.setVolume(at: categoryIndex, volume: actualVolume)
        }
        
        // 4. 카테고리 버튼 제목 업데이트 (버전 정보 포함)
        if let button = view.viewWithTag(categoryIndex) as? UIButton {
            updateCategoryButtonTitle(button, for: categoryIndex)
        }
        
        // 5. 사용자 피드백
        let versionCount = SoundPresetCatalog.getVersionCount(for: categoryIndex)
        let categoryName = SoundPresetCatalog.displayLabels[categoryIndex]
        showToast(message: "\(categoryName) Ver \(versionIndex + 1)/\(versionCount) 선택됨")
        provideMediumHapticFeedback()
    }
    
    // MARK: - findViewController 헬퍼 메서드
    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while responder != nil {
            responder = responder?.next
            if let viewController = responder as? UIViewController {
                return viewController
            }
        }
        return nil
    }

    // MARK: - 버전 메뉴 생성 (카테고리 버튼용)
    @available(iOS 14.0, *)
    private func createVersionMenuForCategoryButton(for categoryIndex: Int, currentVersion: Int, button: UIButton) -> UIMenu {
        let categoryName = SoundPresetCatalog.displayLabels[categoryIndex]
        let versionCount = SoundPresetCatalog.getVersionCount(for: categoryIndex)
        
        var actions: [UIAction] = []
        
        // 각 버전에 대한 액션 생성
        for index in 0..<versionCount {
            let isSelected = index == currentVersion
            let title = isSelected ? "Ver \(index + 1) ✓ (현재)" : "Ver \(index + 1)"
            
            let action = UIAction(
                title: title,
                image: isSelected ? UIImage(systemName: "checkmark.circle.fill") : UIImage(systemName: "music.note"),
                state: isSelected ? .on : .off
            ) { [weak self] _ in
                self?.selectVersion(categoryIndex: categoryIndex, versionIndex: index)
            }
            actions.append(action)
        }
        
        return UIMenu(title: "\(categoryName) 버전 선택", children: actions)
    }
    


    // MARK: - 카테고리 버튼 제목 업데이트
    internal func updateCategoryButtonTitle(_ button: UIButton, for categoryIndex: Int) {
        let categoryDisplay = SoundManager.shared.getCategoryDisplay(at: categoryIndex)
        let currentVersion = SoundManager.shared.getCurrentVersions()[categoryIndex]
        let versionCount = SoundPresetCatalog.getVersionCount(for: categoryIndex)
        
        // 모든 카테고리에 버전 정보 표시 (단일 버전도 "Ver 1/1"로 표시)
        let title = "\(categoryDisplay)\nVer \(currentVersion + 1)/\(versionCount)"
        button.setTitle(title, for: .normal)
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.textAlignment = .left
    }
    
    // MARK: - 모든 카테고리 버튼 제목 업데이트
    internal func updateAllCategoryButtonTitles() {
        for i in 0..<SoundPresetCatalog.categoryCount {
            if let button = view.viewWithTag(i) as? UIButton {
                updateCategoryButtonTitle(button, for: i)
            }
        }
    }
    

    
    // MARK: - 버전 정보 업데이트 (토스트 메시지 등)
    private func updateVersionInfo(for categoryIndex: Int) {
        if let versionInfo = SoundManager.shared.getCurrentVersionInfo(at: categoryIndex) {
            print("🔄 카테고리 \(categoryIndex) 버전 변경: \(versionInfo)")
            showToast(message: "\(versionInfo) 선택됨")
        }
    }
    

    
    // MARK: - 토스트 메시지 표시 (fileprivate -> internal)

    /// 사용자에게 짧은 메시지를 화면 하단에 잠시 보여줍니다.
    /// - Parameter message: 표시할 메시지 문자열
    internal func showToast(message: String) {
        let toastLabel = UILabel()
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toastLabel.textColor = .white
        toastLabel.textAlignment = .center
        toastLabel.font = .systemFont(ofSize: 14)
        toastLabel.text = message
        toastLabel.alpha = 0
        toastLabel.layer.cornerRadius = 10
        toastLabel.clipsToBounds = true
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(toastLabel)
        NSLayoutConstraint.activate([
            toastLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40),
            toastLabel.heightAnchor.constraint(equalToConstant: 35)
        ])
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn, animations: {
            toastLabel.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5, options: .curveEaseOut, animations: {
                toastLabel.alpha = 0
            }) { _ in
                toastLabel.removeFromSuperview()
            }
        }
    }
    
    // MARK: - 슬라이더 & 텍스트필드 제어 (기존 로직 유지)
    
    @objc func sliderChanged(_ sender: UISlider) {
        let index = sender.tag
        let volume = Int(sender.value)
        
        // 임계값 초과 시 사용자 확인
        if volume > volumeThreshold && !hasVolumeOverride[index] {
            if let vc = findViewController() {
                let alert = UIAlertController(title: "주의: 큰 소리", message: "이 소리는 집중이나 수면을 방해할 수 있습니다. 계속 높이시겠습니까?", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "계속", style: .default) { _ in
                    self.hasVolumeOverride[index] = true
                    // 재호출하여 실제 볼륨 적용
                    self.sliderChanged(sender)
                })
                alert.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in
                    // 임계값으로 복원
                    sender.value = Float(self.volumeThreshold)
                    self.volumeFields[index].text = "\(self.volumeThreshold)"
                    let actual = Float(self.volumeThreshold) * (self.masterVolumeLevel / 100.0)
                    SoundManager.shared.setVolume(at: index, volume: actual)
                })
                vc.present(alert, animated: true)
            }
            return
        }

        // 임계값 이하로 낮추면 재확인 필요하도록 초기화
        if volume <= volumeThreshold {
            hasVolumeOverride[index] = false
        }

        sender.value = Float(volume)
        volumeFields[index].text = "\(volume)"
        
        // 마스터 볼륨을 적용한 실제 볼륨을 SoundManager에 전달
        let actualVolume = Float(volume) * (masterVolumeLevel / 100.0)
        
        // 디버그 로그 추가
        print("🎚️ 슬라이더 \(index) 변경: 설정값=\(volume), 마스터볼륨=\(masterVolumeLevel)%, 실제볼륨=\(actualVolume)")
        
        SoundManager.shared.setVolume(at: index, volume: actualVolume)
        
        provideLightHapticFeedback()
    }
    
    @objc func textFieldChanged(_ sender: UITextField) {
        guard let text = sender.text else { return }
        let sanitizedText = sanitizeVolumeInput(text)
        if sanitizedText != text {
            sender.text = sanitizedText
        }
    }
    
    @objc func textFieldEditingEnded(_ sender: UITextField) {
        let index = sender.tag
        guard let text = sender.text else { return }
        
        let volume = validateAndClampVolume(text)
        sender.text = "\(volume)"
        sliders[index].value = Float(volume)
        
        // 마스터 볼륨을 적용한 실제 볼륨을 SoundManager에 전달
        let actualVolume = Float(volume) * (masterVolumeLevel / 100.0)
        SoundManager.shared.setVolume(at: index, volume: actualVolume)
        
        provideMediumHapticFeedback()
    }
    
    func updateSliderAndTextField(at index: Int, volume: Float, shouldPlay: Bool = true) {
        guard index >= 0, index < sliders.count else { return }
        
        // ✅ Float 볼륨값을 올바른 정수로 변환
        var displayVolume: Int
        if volume <= 1.0 {
            // 0.3 → 30, 0.5 → 50 (0-1 범위를 0-100으로 스케일링)
            displayVolume = Int(volume * 100)
        } else {
            // 이미 정수 범위의 값 (25, 30 등)
            displayVolume = Int(volume)
        }
        
        let clampedVolume = max(0, min(100, displayVolume))
        
        sliders[index].value = Float(clampedVolume)
        volumeFields[index].text = "\(clampedVolume)"
        
        // 마스터 볼륨을 적용한 실제 볼륨을 SoundManager에 전달
        let actualVolume = Float(clampedVolume) * (masterVolumeLevel / 100.0)
        
        // 🆕 UI 업데이트 목적이면 forUIUpdate: true로 전달하여 재생 방지
        SoundManager.shared.setVolume(at: index, volume: actualVolume, forUIUpdate: !shouldPlay)
        
        print("🎚️ [updateSliderAndTextField] 인덱스 \(index): 입력볼륨=\(volume) → 표시볼륨=\(clampedVolume) → 실제볼륨=\(actualVolume), shouldPlay=\(shouldPlay)")
    }
    
    // MARK: - 전체 볼륨 업데이트 (프리셋 적용 시 사용)
    
    func updateAllSlidersAndFields(volumes: [Float], versions: [Int]? = nil) {
        print("🔄 [updateAllSlidersAndFields] UI 업데이트 시작")
        print("  - 볼륨: \(volumes)")
        
        // 1. 버전 정보가 있으면 먼저 적용
        if let versions = versions {
            print("  - 버전: \(versions)")
            for (categoryIndex, versionIndex) in versions.enumerated() {
                if categoryIndex < SoundPresetCatalog.categoryCount {
                    SoundManager.shared.selectVersion(categoryIndex: categoryIndex, versionIndex: versionIndex)
                    SettingsManager.shared.updateSelectedVersion(for: categoryIndex, to: versionIndex)
                }
            }
        }
        
        // 2. 볼륨 정보 적용 (배열 크기 안전 검사)
        let targetCount = min(volumes.count, sliders.count, volumeFields.count)
        print("  - 업데이트할 슬라이더 수: \(targetCount)")
        
        for i in 0..<targetCount {
            updateSliderAndTextField(at: i, volume: volumes[i])
        }
        
        // 3. 카테고리 버튼 UI 업데이트 (버전 정보 반영)
        updateAllCategoryButtonTitles()
        
        // 4. 🚫 중복된 마스터 볼륨 적용 제거 (updateSliderAndTextField에서 이미 처리함)
        
        print("✅ [updateAllSlidersAndFields] 모든 슬라이더 및 버전 UI 업데이트 완료")
    }
    
    // MARK: - 입력 검증 (기존 로직 유지)
    
    func sanitizeVolumeInput(_ input: String) -> String {
        let filtered = input.filter { $0.isNumber }
        if filtered.count > 3 {
            return String(filtered.prefix(3))
        }
        return filtered
    }
    
    func validateAndClampVolume(_ input: String) -> Int {
        guard !input.isEmpty else { return 0 }
        
        // 공백 제거
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return 0 }
        
        // 숫자 변환 (소수점 처리도 고려)
        guard let value = Int(trimmedInput) else { 
            // 소수점이 있는 경우 정수 부분만 추출
            if let doubleValue = Double(trimmedInput) {
                return max(0, min(100, Int(doubleValue)))
            }
            return 0 
        }
        
        // 경계값 체크 강화
        return max(0, min(100, value))
    }
    
    // MARK: - 마스터 볼륨 전용 검증 (0-200% 범위)
    func validateAndClampMasterVolume(_ input: String) -> Int {
        guard !input.isEmpty else { return 0 }
        
        // 공백 제거
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return 0 }
        
        // 숫자 변환 (소수점 처리도 고려)
        guard let value = Int(trimmedInput) else { 
            // 소수점이 있는 경우 정수 부분만 추출
            if let doubleValue = Double(trimmedInput) {
                return max(0, min(200, Int(doubleValue)))  // 마스터볼륨은 최대 200%
            }
            return 0 
        }
        
        // 경계값 체크: 0-200% 범위
        return max(0, min(200, value))
    }
    
    // MARK: - 기존 호환성 메서드들
    
    /// 현재 모든 볼륨값 가져오기
    func getCurrentVolumes() -> [Float] {
        return sliders.map { $0.value }
    }
    
    /// 현재 선택된 버전들 가져오기
    func getCurrentVersions() -> [Int] {
        return SoundManager.shared.getCurrentVersions()
    }
    
    /// 레거시 12개 볼륨을 11개로 변환하여 적용
    func applyLegacyVolumes(_ legacyVolumes: [Float]) {
        let convertedVolumes = legacyVolumes.count == 13 ? legacyVolumes : Array(repeating: 0.0, count: 13)
        updateAllSlidersAndFields(volumes: convertedVolumes)
    }
    
    // MARK: - 미리듣기 탐색 슬라이더 액션
    @objc private func previewSeekSliderChanged(_ sender: UISlider) {
        guard let previewingIndex = currentlyPreviewingIndex, sender.tag == previewingIndex else { return }
        SoundManager.shared.seekPreview(to: TimeInterval(sender.value))
    }
    
}

// MARK: - UITextFieldDelegate (기존 유지)
extension ViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        guard let textRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: textRange, with: string)
        
        if updatedText.isEmpty { return true }
        
        let allowedCharacters = CharacterSet.decimalDigits
        if string.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            return false
        }
        
        if updatedText.count > 3 { return false }
        
        // 마스터 볼륨 필드는 200까지, 일반 볼륨 필드는 100까지
        let maxValue = (textField == masterVolumeField) ? 200 : 100
        if let value = Int(updatedText), value > maxValue { return false }
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.selectAll(nil)
    }
}
