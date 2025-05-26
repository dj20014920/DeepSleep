import UIKit

// MARK: - 슬라이더 UI 및 제어 관련 Extension
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

        for (i, labelChar) in sliderLabels.enumerated() {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 12

            let nameLabel = UILabel()
            nameLabel.text = "\(labelChar)"
            nameLabel.widthAnchor.constraint(equalToConstant: 30).isActive = true

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

            let button = UIButton(type: .system)
            button.setImage(UIImage(systemName: "play.fill"), for: .normal)
            button.tag = i
            button.widthAnchor.constraint(equalToConstant: 30).isActive = true
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
            button.addTarget(self, action: #selector(toggleTrack(_:)), for: .touchUpInside)
            playButtons.append(button)

            [nameLabel, slider, volumeField, button].forEach { row.addArrangedSubview($0) }
            stackView.addArrangedSubview(row)
        }
    }
    
    // MARK: - 슬라이더 & 텍스트필드 제어
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
        let intVolume = Int(volume)
        let clampedVolume = max(0, min(100, intVolume))
        
        sliders[index].value = Float(clampedVolume)
        volumeFields[index].text = "\(clampedVolume)"
        SoundManager.shared.setVolume(at: index, volume: Float(clampedVolume))
    }
    
    // MARK: - 입력 검증
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
}

// MARK: - UITextFieldDelegate
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
