import UIKit

// MARK: - 프리셋 블록 UI 관련 Extension
extension ViewController {
    
    // MARK: - 프리셋 블록 UI 설정
    func setupPresetBlocks() {
        presetStackView = UIStackView()
        presetStackView.axis = .vertical
        presetStackView.spacing = 16
        presetStackView.translatesAutoresizingMaskIntoConstraints = false
        
        let recentSection = createPresetSection(
            title: "🕐 최근 사용한 프리셋",
            buttonCount: 4,
            isRecent: true
        )
        recentPresetButtons = recentSection.buttons
        
        let favoriteSection = createPresetSection(
            title: "⭐️ 즐겨찾기 프리셋",
            buttonCount: 4,
            isRecent: false
        )
        favoritePresetButtons = favoriteSection.buttons
        
        presetStackView.addArrangedSubview(recentSection.container)
        presetStackView.addArrangedSubview(favoriteSection.container)
        
        if let scrollView = view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView,
           let containerView = scrollView.subviews.first {
            containerView.addSubview(presetStackView)
            
            if let sliderStackView = containerView.subviews.first(where: { $0 is UIStackView }) {
                NSLayoutConstraint.activate([
                    presetStackView.topAnchor.constraint(equalTo: sliderStackView.bottomAnchor, constant: 30),
                    presetStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
                    presetStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
                    presetStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -30)
                ])
            }
        }
    }
    
    func createPresetSection(title: String, buttonCount: Int, isRecent: Bool) -> (container: UIView, buttons: [UIButton]) {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        var buttons: [UIButton] = []
        for i in 0..<buttonCount {
            let button = createPresetButton(index: i, isRecent: isRecent)
            buttons.append(button)
        }
        
        let buttonStack = UIStackView(arrangedSubviews: buttons)
        buttonStack.axis = .horizontal
        buttonStack.spacing = 8
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleLabel)
        container.addSubview(buttonStack)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            buttonStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            buttonStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            buttonStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            buttonStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            buttonStack.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        return (container, buttons)
    }
    
    func createPresetButton(index: Int, isRecent: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemGray4.cgColor
        button.backgroundColor = UIColor.systemGray6
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.textAlignment = .center
        button.setTitle("빈 슬롯", for: .normal)
        button.setTitleColor(.systemGray2, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tag = (isRecent ? 100 : 200) + index
        button.addTarget(self, action: #selector(presetButtonTapped(_:)), for: .touchUpInside)
        return button
    }
    
    // MARK: - 프리셋 관리
    func updatePresetBlocks() {
        updateRecentPresets()
        updateFavoritePresets()
    }
    
    func updateRecentPresets() {
        let recentPresets = getRecentPresets()
        for (index, button) in recentPresetButtons.enumerated() {
            if index < recentPresets.count {
                let preset = recentPresets[index]
                configurePresetButton(button, with: preset, isEmpty: false)
            } else {
                configureEmptyPresetButton(button)
            }
        }
    }
    
    func updateFavoritePresets() {
        let favoritePresets = getFavoritePresets()
        for (index, button) in favoritePresetButtons.enumerated() {
            if index < favoritePresets.count {
                let preset = favoritePresets[index]
                configurePresetButton(button, with: preset, isEmpty: false)
            } else {
                configureEmptyPresetButton(button)
            }
        }
    }
    
    func configurePresetButton(_ button: UIButton, with preset: SoundPreset, isEmpty: Bool) {
        if isEmpty {
            configureEmptyPresetButton(button)
            return
        }
        
        button.setTitle(preset.name, for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        button.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        
        if let emotion = preset.emotion {
            button.setTitle("\(emotion)\n\(preset.name)", for: .normal)
        }
    }
    
    func configureEmptyPresetButton(_ button: UIButton) {
        button.setTitle("+ 빈 슬롯", for: .normal)
        button.setTitleColor(.systemGray2, for: .normal)
        button.backgroundColor = UIColor.systemGray6
        button.layer.borderColor = UIColor.systemGray4.cgColor
    }
    
    func getRecentPresets() -> [SoundPreset] {
        let allPresets = SettingsManager.shared.loadSoundPresets()
        return Array(allPresets.filter { $0.isAIGenerated }.prefix(4))
    }
    
    func getFavoritePresets() -> [SoundPreset] {
        let allPresets = SettingsManager.shared.loadSoundPresets()
        return Array(allPresets.filter { !$0.isAIGenerated }.prefix(4))
    }
    
    func addToRecentPresets(name: String, volumes: [Float]) {
        let preset = SoundPreset(
            name: name,
            volumes: volumes,
            emotion: nil,
            isAIGenerated: true,
            description: "최근 사용한 프리셋"
        )
        SettingsManager.shared.saveSoundPreset(preset)
    }
    
    @objc func presetButtonTapped(_ sender: UIButton) {
        let isRecentButton = sender.tag >= 100 && sender.tag < 200
        let buttonIndex = sender.tag % 100
        
        let presets = isRecentButton ? getRecentPresets() : getFavoritePresets()
        
        guard buttonIndex < presets.count else {
            showPresetList()
            return
        }
        
        let preset = presets[buttonIndex]
        applyPreset(volumes: preset.volumes, name: preset.name)
    }
    
    func showPresetList() {
        let presetListVC = PresetListViewController()
        presetListVC.onPresetSelected = { [weak self] preset in
            let soundPreset = SoundPreset(
                name: preset.name,
                volumes: preset.volumes,
                isAIGenerated: false
            )
            self?.applyPreset(volumes: soundPreset.volumes, name: soundPreset.name)
        }
        navigationController?.pushViewController(presetListVC, animated: true)
    }
}
