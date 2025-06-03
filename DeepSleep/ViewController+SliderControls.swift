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

        let playAll = UIButton(type: .system)
        playAll.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playAll.addTarget(self, action: #selector(playAllTapped), for: .touchUpInside)

        let pauseAll = UIButton(type: .system)
        pauseAll.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        pauseAll.addTarget(self, action: #selector(pauseAllTapped), for: .touchUpInside)

        [playAll, pauseAll].forEach { controlsStack.addArrangedSubview($0) }
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

        // 새로운 11개 이모지 카테고리로 슬라이더 생성
        let categoryCount = SoundPresetCatalog.categoryCount
        
        for i in 0..<categoryCount {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 12

            // 이모지 + 이름 라벨 (기존 A,B,C 대신)
            let nameLabel = UILabel()
            nameLabel.text = SoundPresetCatalog.displayLabels[i]
            nameLabel.font = .systemFont(ofSize: 14, weight: .medium)
            nameLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true
            nameLabel.numberOfLines = 1
            nameLabel.adjustsFontSizeToFitWidth = true

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

            // 재생/일시정지 버튼
            let playButton = UIButton(type: .system)
            playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            playButton.tag = i
            playButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
            playButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
            playButton.addTarget(self, action: #selector(toggleTrack(_:)), for: .touchUpInside)
            playButtons.append(playButton)
            
            // 버전 선택 버튼 (다중 버전이 있는 카테고리만)
            let versionButton = createVersionButton(for: i)

            // 미리듣기 버튼
            let previewButton = UIButton(type: .system)
            previewButton.setImage(UIImage(systemName: "headphones"), for: .normal)
            previewButton.tag = i
            previewButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
            previewButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
            previewButton.addTarget(self, action: #selector(previewButtonTapped(_:)), for: .touchUpInside)
            
            // 버전 버튼이 있으면 포함, 없으면 spacer 추가
            if let versionBtn = versionButton {
                [nameLabel, slider, volumeField, playButton, versionBtn, previewButton].forEach {
                    row.addArrangedSubview($0)
                }
            } else {
                let spacer = UIView()
                spacer.widthAnchor.constraint(equalToConstant: 30).isActive = true
                [nameLabel, slider, volumeField, playButton, spacer, previewButton].forEach {
                    row.addArrangedSubview($0)
                }
            }
            
            stackView.addArrangedSubview(row)
        }
        
        print("✅ \(categoryCount)개 카테고리 슬라이더 UI 생성 완료")
    }
    
    // MARK: - 버전 선택 버튼 생성
    
    private func createVersionButton(for categoryIndex: Int) -> UIButton? {
        // 다중 버전이 있는 카테고리만 버튼 생성
        guard SoundPresetCatalog.hasMultipleVersions(at: categoryIndex) else {
            return nil
        }
        
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "arrow.triangle.2.circlepath"), for: .normal)
        button.tag = categoryIndex
        button.widthAnchor.constraint(equalToConstant: 30).isActive = true
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        button.addTarget(self, action: #selector(versionButtonTapped(_:)), for: .touchUpInside)
        
        // 툴팁 설정
        updateVersionButtonTooltip(button, categoryIndex: categoryIndex)
        
        return button
    }
    
    private func updateVersionButtonTooltip(_ button: UIButton, categoryIndex: Int) {
        let versionNames = SoundPresetCatalog.getVersionNames(for: categoryIndex)
        let currentVersion = SoundManager.shared.getCurrentVersions()[categoryIndex]
        
        if #available(iOS 14.0, *) {
            button.menu = createVersionMenu(for: categoryIndex, currentVersion: currentVersion)
            button.showsMenuAsPrimaryAction = true
        } else {
            // iOS 13 이하에서는 간단한 토글
            button.accessibilityHint = "현재: \(versionNames[currentVersion])"
        }
    }
    
    @available(iOS 14.0, *)
    private func createVersionMenu(for categoryIndex: Int, currentVersion: Int) -> UIMenu {
        let versionNames = SoundPresetCatalog.getVersionNames(for: categoryIndex)
        let actions = versionNames.enumerated().map { (index, name) in
            UIAction(
                title: name,
                image: index == currentVersion ? UIImage(systemName: "checkmark") : nil,
                state: index == currentVersion ? .on : .off
            ) { [weak self] _ in
                self?.selectVersion(categoryIndex: categoryIndex, versionIndex: index)
            }
        }
        
        return UIMenu(title: "버전 선택", children: actions)
    }
    
    // MARK: - 액션 메서드들
    
    // 전체 재생/일시정지 (ViewController+PlaybackControls.swift에 정의된 메서드들 직접 호출 또는 중복 정의)
    @objc func playAllPressed() {
        SoundManager.shared.playAll()
        updatePlayButtonStates()
        provideMediumHapticFeedback()
    }

    @objc func pauseAllPressed() {
        SoundManager.shared.pauseAll()
        updatePlayButtonStates()
        provideMediumHapticFeedback()
    }
    
    @objc func toggleSoundTrack(_ sender: UIButton) {
        let index = sender.tag
        
        if SoundManager.shared.isPlaying(at: index) {
            SoundManager.shared.pause(at: index)
        } else {
            SoundManager.shared.play(at: index)
        }
        
        updatePlayButtonStates()
    }
    
    @objc func versionButtonTapped(_ sender: UIButton) {
        let categoryIndex = sender.tag
        
        if #available(iOS 14.0, *) {
            // iOS 14+에서는 메뉴가 자동으로 표시됨
            return
        } else {
            // iOS 13 이하에서는 다음 버전으로 토글
            SoundManager.shared.selectNextVersion(categoryIndex: categoryIndex)
            updateVersionButtonTooltip(sender, categoryIndex: categoryIndex)
            updateVersionInfo(for: categoryIndex)
        }
    }
    
    @objc func previewButtonTapped(_ sender: UIButton) {
        let categoryIndex = sender.tag
        let currentVersion = SoundManager.shared.getCurrentVersions()[categoryIndex]
        
        // 현재 선택된 버전 미리듣기
        SoundManager.shared.previewVersion(categoryIndex: categoryIndex, versionIndex: currentVersion)
        
        // 버튼 피드백
        sender.alpha = 0.5
        UIView.animate(withDuration: 0.3) {
            sender.alpha = 1.0
        }
        
        provideLightHapticFeedback()
    }
    
    private func selectVersion(categoryIndex: Int, versionIndex: Int) {
        SoundManager.shared.selectVersion(categoryIndex: categoryIndex, versionIndex: versionIndex)
        updateVersionInfo(for: categoryIndex)
        provideMediumHapticFeedback()
    }
    
    private func updateVersionInfo(for categoryIndex: Int) {
        // 버전 정보 업데이트 (필요시 UI 갱신)
        if let versionInfo = SoundManager.shared.getCurrentVersionInfo(at: categoryIndex) {
            print("🔄 카테고리 \(categoryIndex) 버전 변경: \(versionInfo)")
        }
        
        // 버전 버튼 업데이트
        updateVersionButtons()
    }
    
    private func updateVersionButtons() {
        // 모든 버전 버튼의 메뉴/툴팁 업데이트
        for (index, category) in SoundPresetCatalog.multiVersionCategories.enumerated() {
            // 버전 버튼 찾기 (stackView 구조에서)
            // 실제 구현에서는 버전 버튼들을 별도 배열로 관리하는 것이 좋음
        }
    }
    
    // MARK: - 슬라이더 & 텍스트필드 제어 (기존 로직 유지)
    
    @objc func sliderChanged(_ sender: UISlider) {
        let index = sender.tag
        let volume = Int(sender.value)
        
        sender.value = Float(volume)
        volumeFields[index].text = "\(volume)"
        SoundManager.shared.setVolume(at: index, volume: Float(volume))
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
        SoundManager.shared.setVolume(at: index, volume: Float(volume))
        provideMediumHapticFeedback()
    }
    
    func updateSliderAndTextField(at index: Int, volume: Float) {
        guard index >= 0, index < sliders.count else { return }
        
        let intVolume = Int(volume)
        let clampedVolume = max(0, min(100, intVolume))
        
        sliders[index].value = Float(clampedVolume)
        volumeFields[index].text = "\(clampedVolume)"
        SoundManager.shared.setVolume(at: index, volume: Float(clampedVolume))
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
            updateVersionButtons()
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
