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
            categoryButton.setTitle(SoundPresetCatalog.displayLabels[i], for: .normal)
            categoryButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
            categoryButton.contentHorizontalAlignment = .left
            categoryButton.setTitleColor(UIDesignSystem.Colors.primaryText, for: .normal)
            categoryButton.tag = i
            categoryButton.widthAnchor.constraint(equalToConstant: 80).isActive = true
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
        masterVolumeSlider.maximumValue = 100
        masterVolumeSlider.value = 50  // 기본값 50으로 변경
        masterVolumeLevel = 50  // 초기값 50으로 설정
        masterVolumeSlider.addTarget(self, action: #selector(masterVolumeChanged(_:)), for: .valueChanged)
        
        masterVolumeField = UITextField()
        masterVolumeField.text = "50"  // 기본값 50
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
        guard let text = sender.text else { return }
        
        let volume = validateAndClampVolume(text)
        sender.text = "\(volume)"
        masterVolumeSlider.value = Float(volume)
        masterVolumeLevel = Float(volume)
        
        // 개별 슬라이더 위치는 그대로 두고 SoundManager에만 마스터 볼륨 적용
        applyMasterVolumeToSoundManager()
        provideMediumHapticFeedback()
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

        if currentlyPreviewingIndex == categoryIndex {
            stopCurrentPreview()
        } else {
            stopCurrentPreview() 
            
            currentlyPreviewingIndex = categoryIndex
            let currentVersion = SoundManager.shared.getCurrentVersions()[categoryIndex]
            SoundManager.shared.previewVersion(categoryIndex: categoryIndex, versionIndex: currentVersion)
            
            if let player = SoundManager.shared.previewPlayer, player.duration > 0 {
                previewSeekSliders.forEach { $0.isHidden = true }
                
                if categoryIndex < previewSeekSliders.count {
                    let slider = previewSeekSliders[categoryIndex]
                    slider.maximumValue = Float(player.duration)
                    slider.value = 0
                    slider.isHidden = false
                }
                startPreviewSliderTimer() 
                provideLightHapticFeedback()
            } else {
                currentlyPreviewingIndex = nil 
                showToast(message: "미리듣기를 재생할 수 없습니다.")
                return 
            }

            if SoundPresetCatalog.hasMultipleVersions(at: categoryIndex) {
                if #available(iOS 14.0, *) {
                    sender.menu = createVersionMenuForCategoryButton(for: categoryIndex, currentVersion: currentVersion, button: sender)
                    sender.showsMenuAsPrimaryAction = true 
                } else {
                    let nextVersion = (currentVersion + 1) % SoundPresetCatalog.getVersionCount(at: categoryIndex)
                    selectVersionAndSyncPreview(categoryIndex: categoryIndex, versionIndex: nextVersion)
                }
            }
        }
    }

    // MARK: - 버전 메뉴 생성 (카테고리 버튼용)
    @available(iOS 14.0, *)
    private func createVersionMenuForCategoryButton(for categoryIndex: Int, currentVersion: Int, button: UIButton) -> UIMenu {
        let versionNames = SoundPresetCatalog.getVersionNames(for: categoryIndex)
        let actions = versionNames.enumerated().map { (index, name) in
            UIAction(
                title: name,
                image: index == currentVersion ? UIImage(systemName: "checkmark") : nil,
                state: index == currentVersion ? .on : .off
            ) { [weak self] _ in
                self?.selectVersionAndSyncPreview(categoryIndex: categoryIndex, versionIndex: index)
            }
        }
        return UIMenu(title: "버전 선택", children: actions)
    }

    // MARK: - 버전 선택 및 미리듣기 동기화
    private func selectVersionAndSyncPreview(categoryIndex: Int, versionIndex: Int) {
        SoundManager.shared.selectVersion(categoryIndex: categoryIndex, versionIndex: versionIndex)
        updateVersionInfo(for: categoryIndex) 
        provideMediumHapticFeedback()

        if currentlyPreviewingIndex != categoryIndex {
             stopCurrentPreview() 
        }
        
        SoundManager.shared.previewVersion(categoryIndex: categoryIndex, versionIndex: versionIndex)
        currentlyPreviewingIndex = categoryIndex 

        if let player = SoundManager.shared.previewPlayer, player.duration > 0 {
            previewSeekSliders.forEach { $0.isHidden = true }
            if categoryIndex < previewSeekSliders.count {
                let slider = previewSeekSliders[categoryIndex]
                slider.maximumValue = Float(player.duration)
                slider.value = 0
                slider.isHidden = false 
            }
            startPreviewSliderTimer()
        } else {
            stopCurrentPreview()
            showToast(message: "선택한 버전 미리듣기를 재생할 수 없습니다.")
        }
        
        if #available(iOS 14.0, *) {
            if let button = view.viewWithTag(categoryIndex) as? UIButton {
                 button.menu = createVersionMenuForCategoryButton(for: categoryIndex, currentVersion: versionIndex, button: button)
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
    
    private func stopCurrentPreview() {
        SoundManager.shared.stopPreview()
        previewSliderUpdateTimer?.invalidate()
        previewSliderUpdateTimer = nil
        
        if let index = currentlyPreviewingIndex, index < previewSeekSliders.count {
            previewSeekSliders[index].isHidden = true
            previewSeekSliders[index].value = 0
        }
        currentlyPreviewingIndex = nil
    }

    private func startPreviewSliderTimer() {
        previewSliderUpdateTimer?.invalidate() 
        previewSliderUpdateTimer = Timer.scheduledTimer(
            timeInterval: 0.1, 
            target: self,
            selector: #selector(updatePreviewSlider),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func updatePreviewSlider() {
        guard let previewIndex = currentlyPreviewingIndex, 
              previewIndex < previewSeekSliders.count,
              let player = SoundManager.shared.previewPlayer else {
            stopCurrentPreview() 
            return
        }

        if player.isPlaying {
            previewSeekSliders[previewIndex].value = Float(player.currentTime)
        } else {
            stopCurrentPreview()
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
        
        sender.value = Float(volume)
        volumeFields[index].text = "\(volume)"
        
        // 마스터 볼륨을 적용한 실제 볼륨을 SoundManager에 전달
        let actualVolume = Float(volume) * (masterVolumeLevel / 100.0)
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
    
    func updateSliderAndTextField(at index: Int, volume: Float) {
        guard index >= 0, index < sliders.count else { return }
        
        let intVolume = Int(volume)
        let clampedVolume = max(0, min(100, intVolume))
        
        sliders[index].value = Float(clampedVolume)
        volumeFields[index].text = "\(clampedVolume)"
        
        // 마스터 볼륨을 적용한 실제 볼륨을 SoundManager에 전달
        let actualVolume = Float(clampedVolume) * (masterVolumeLevel / 100.0)
        SoundManager.shared.setVolume(at: index, volume: actualVolume)
    }
    
    // MARK: - 전체 볼륨 업데이트 (프리셋 적용 시 사용)
    
    func updateAllSlidersAndFields(volumes: [Float], versions: [Int]? = nil) {
        // 1. 버전 정보가 있으면 먼저 적용
        if let versions = versions {
            for (categoryIndex, versionIndex) in versions.enumerated() {
                if categoryIndex < SoundPresetCatalog.categoryCount {
                    SoundManager.shared.selectVersion(categoryIndex: categoryIndex, versionIndex: versionIndex)
                }
            }
        }
        
        // 2. 볼륨 정보 적용
        let targetCount = min(volumes.count, sliders.count, volumeFields.count)
        
        for i in 0..<targetCount {
            updateSliderAndTextField(at: i, volume: volumes[i])
        }
        
        print("✅ 모든 슬라이더 업데이트 완료: \(volumes)")
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
        guard let value = Int(input) else { return 0 }
        return max(0, min(100, value))
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
        let convertedVolumes = SoundPresetCatalog.convertLegacyVolumes(legacyVolumes)
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
        if let value = Int(updatedText), value > 100 { return false }
        
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
