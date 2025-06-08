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
        
        // AI 추천 버튼 제거 - 채팅을 통한 추천으로 대체
        
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
    
    func createAIRecommendButton() -> UIButton {
        let button = UIButton(type: .system)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.systemPurple.cgColor
        button.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.1)
        button.titleLabel?.font = .systemFont(ofSize: 11, weight: .bold)
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.textAlignment = .center
        button.setTitle("🧠\nAI 추천", for: .normal)
        button.setTitleColor(.systemPurple, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tag = 999 // AI 추천 버튼 식별용
        button.addTarget(self, action: #selector(aiRecommendButtonTapped), for: .touchUpInside)
        
        // 그라데이션 효과 추가
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.systemPurple.withAlphaComponent(0.1).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.1).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 12
        button.layer.insertSublayer(gradientLayer, at: 0)
        
        // 버튼이 레이아웃된 후 그라데이션 크기 조정
        DispatchQueue.main.async {
            gradientLayer.frame = button.bounds
        }
        
        return button
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
        print("🔄 [updatePresetBlocks] 프리셋 블록 업데이트 시작")
        
        let recentPresets = getRecentPresets()
        let favoritePresets = getFavoritePresets()
        
        print("  - 최근 프리셋 수: \(recentPresets.count)")
        print("  - 즐겨찾기 프리셋 수: \(favoritePresets.count)")
        
        // 최근 사용한 프리셋 버튼 업데이트
        for (index, button) in recentPresetButtons.enumerated() {
            if index < recentPresets.count {
                let preset = recentPresets[index]
                configurePresetButton(button, with: preset, isEmpty: false)
                print("  - 최근 프리셋 \(index): \(preset.name)")
            } else {
                configureEmptyPresetButton(button)
            }
        }
        
        // 즐겨찾기 프리셋 버튼 업데이트
        for (index, button) in favoritePresetButtons.enumerated() {
            if index < favoritePresets.count {
                let preset = favoritePresets[index]
                configurePresetButton(button, with: preset, isEmpty: false)
                print("  - 즐겨찾기 프리셋 \(index): \(preset.name)")
            } else {
                configureEmptyPresetButton(button)
            }
        }
        
        print("✅ [updatePresetBlocks] 프리셋 블록 업데이트 완료")
    }
    
    func configurePresetButton(_ button: UIButton, with preset: SoundPreset, isEmpty: Bool) {
        if isEmpty {
            configureEmptyPresetButton(button)
            return
        }
        
        // 프리셋 이름을 버튼 제목으로 설정
        button.setTitle(preset.name, for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        button.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        
        // 감정 정보가 있으면 추가 표시
        if let emotion = preset.emotion {
            button.setTitle("\(emotion)\n\(preset.name)", for: .normal)
        }
        
        // 프리셋 이름이 너무 길면 줄임표 처리
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.8
        
        print("  - 버튼 설정: '\(preset.name)'")
    }
    
    func configureEmptyPresetButton(_ button: UIButton) {
        button.setTitle("+ 빈 슬롯", for: .normal)
        button.setTitleColor(.systemGray2, for: .normal)
        button.backgroundColor = UIColor.systemGray6
        button.layer.borderColor = UIColor.systemGray4.cgColor
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.textAlignment = .center
    }
    
    func getRecentPresets() -> [SoundPreset] {
        let allPresets = SettingsManager.shared.loadSoundPresets()
        // ✅ 수정: isAIGenerated 필터링 제거하고 실제 최근 사용 순으로 정렬
        // 최신 생성 날짜 순으로 4개까지 (AI/로컬 구분 없이)
        let recentPresets = Array(allPresets.prefix(4))
        print("  - getRecentPresets: \(recentPresets.count)개 반환 (AI/로컬 구분 없이)")
        for (index, preset) in recentPresets.enumerated() {
            print("    [\(index)] \(preset.name) - \(preset.isAIGenerated ? "AI" : "User")")
        }
        return recentPresets
    }
    
    func getFavoritePresets() -> [SoundPreset] {
        // UserDefaults에서 즐겨찾기 ID들을 가져와서 해당하는 프리셋들 반환
        let favoriteIds = UserDefaults.standard.array(forKey: "FavoritePresetIds") as? [String] ?? []
        let favoritePresetIds = Set(favoriteIds.compactMap { UUID(uuidString: $0) })
        
        let allPresets = SettingsManager.shared.loadSoundPresets()
        let favoritePresets = allPresets.filter { favoritePresetIds.contains($0.id) }
        print("  - getFavoritePresets: \(favoritePresets.count)개 반환")
        return favoritePresets
    }
    
    // 이 메서드는 제거됨 - ViewController+Utilities.swift의 addToRecentPresetsWithVersions 사용
    // func addToRecentPresets(name: String, volumes: [Float]) - 삭제됨
    
    @objc func presetButtonTapped(_ sender: UIButton) {
        let isRecentButton = sender.tag >= 100 && sender.tag < 200
        let buttonIndex = sender.tag % 100
        
        let presets = isRecentButton ? getRecentPresets() : getFavoritePresets()
        
        guard buttonIndex < presets.count else {
            showPresetList()
            return
        }
        
        let preset = presets[buttonIndex]
        
        print("🎵 [presetButtonTapped] 프리셋 버튼 클릭: \(preset.name)")
        print("  - 최근 버튼: \(isRecentButton)")
        print("  - 볼륨: \(preset.compatibleVolumes)")
        print("  - 버전: \(preset.compatibleVersions)")
        
        // 최근 프리셋인 경우 새로운 프리셋을 생성하지 않음 (중복 저장 방지)
        // 즐겨찾기 프리셋인 경우도 최근 프리셋에 저장하지 않음 (기존 동작 유지)
        let shouldSaveToRecent = false  // 클릭한 프리셋은 이미 존재하므로 저장하지 않음
        
        // 통합된 applyPreset 메서드 사용 (UI 동기화 포함)
        applyPreset(volumes: preset.compatibleVolumes, versions: preset.compatibleVersions, name: preset.name, shouldSaveToRecent: shouldSaveToRecent)
        
        // 햅틱 피드백
        provideMediumHapticFeedback()
        
        print("✅ [presetButtonTapped] 프리셋 적용 완료: \(preset.name)")
    }
    
    @objc func aiRecommendButtonTapped() {
        showAIRecommendationDialog()
    }
    
    func showAIRecommendationDialog() {
        let alert = UIAlertController(
            title: "🧠 심리 음향학 AI 추천",
            message: "현재 기분이나 상황을 선택해주세요. 전문가가 설계한 최적의 사운드 조합을 추천해드립니다.",
            preferredStyle: .actionSheet
        )
        
        // 감정 상태별 추천 옵션들
        let emotionOptions = [
            ("😫 스트레스/불안", "스트레스"),
            ("😰 걱정/긴장", "불안"),
            ("😔 우울/침울", "우울"),
            ("😴 불면/수면곤란", "불면"),
            ("😓 피로/무기력", "피로"),
            ("🤯 압도/과부하", "압도감"),
            ("😞 외로움/고독", "외로움"),
            ("😡 분노/짜증", "분노"),
            ("🎯 집중/몰입 필요", "집중"),
            ("💡 창의/영감 필요", "창의"),
            ("😊 기쁨/행복", "기쁨"),
            ("🧘 명상/영적 성장", "명상"),
            ("🌅 활력/에너지 필요", "활력"),
            ("😌 평온/안정", "평온")
        ]
        
        for (title, emotion) in emotionOptions {
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.generateAIRecommendation(for: emotion)
            })
        }
        
        // 상황별 자동 추천
        alert.addAction(UIAlertAction(title: "지금 시간대에 맞는 자동 추천", style: .default) { [weak self] _ in
            self?.generateContextualRecommendation()
        })
        
        // 전문가 프리셋 목록
        alert.addAction(UIAlertAction(title: "🎨 전문가 프리셋 목록", style: .default) { [weak self] _ in
            self?.showExpertPresetList()
        })
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        
        // iPad 지원
        if let popover = alert.popoverPresentationController {
            if let button = view.viewWithTag(999) {
                popover.sourceView = button
                popover.sourceRect = button.bounds
            }
        }
        
        present(alert, animated: true)
    }
    
    func generateAIRecommendation(for emotion: String) {
        // 로딩 표시
        let loadingAlert = UIAlertController(title: "🧠 AI 분석 중...", message: "최적의 사운드 조합을 계산하고 있습니다.", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        SoundManager.shared.applyEmotionalPreset(emotion: emotion) { [weak self] description in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    self?.showRecommendationResult(description: description, emotion: emotion)
                }
            }
        }
    }
    
    func generateContextualRecommendation() {
        let recommendation = SoundManager.shared.getContextualRecommendation()
        SoundManager.shared.applyExpertPreset(recommendation: recommendation)
        
        let description = recommendation["description"] as? String ?? "시간대에 맞는 최적의 조합을 적용했습니다."
        let category = recommendation["category"] as? String ?? "상황별 추천"
        
        showRecommendationResult(description: description, emotion: category)
    }
    
    func showExpertPresetList() {
        let presetNames = SoundManager.shared.getExpertPresetCategories()
        
        let alert = UIAlertController(
            title: "🎨 전문가 설계 프리셋",
            message: "심리 음향학 전문가가 특별히 설계한 프리셋들입니다.",
            preferredStyle: .actionSheet
        )
        
        for presetName in presetNames {
            let displayName = presetName.replacingOccurrences(of: "_", with: " ")
            alert.addAction(UIAlertAction(title: displayName, style: .default) { [weak self] _ in
                SoundManager.shared.applyNamedExpertPreset(presetName)
                self?.showToast(message: "'\(displayName)' 프리셋이 적용되었습니다. 🎵")
            })
        }
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        
        // iPad 지원
        if let popover = alert.popoverPresentationController {
            if let button = view.viewWithTag(999) {
                popover.sourceView = button
                popover.sourceRect = button.bounds
            }
        }
        
        present(alert, animated: true)
    }
    
    func showRecommendationResult(description: String, emotion: String) {
        let alert = UIAlertController(
            title: "✨ AI 추천 완료",
            message: description,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "적용하기", style: .default) { [weak self] _ in
            // 현재 설정을 프리셋으로 저장
            self?.saveCurrentAsAIPreset(emotion: emotion)
            self?.showToast(message: "AI 추천 프리셋이 적용되었습니다! 🎵")
        })
        
        alert.addAction(UIAlertAction(title: "다시 추천받기", style: .default) { [weak self] _ in
            self?.generateAIRecommendation(for: emotion)
        })
        
        alert.addAction(UIAlertAction(title: "확인", style: .cancel))
        
        present(alert, animated: true)
    }
    
    func saveCurrentAsAIPreset(emotion: String) {
        let volumes = getCurrentVolumes()
        let versions = getCurrentVersions()
        let timeStamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        let presetName = "\(emotion) AI 추천 (\(timeStamp))"
        
        let preset = SoundPreset(
            name: presetName,
            volumes: volumes,
            selectedVersions: versions,
            emotion: emotion,
            isAIGenerated: true
        )
        
        SettingsManager.shared.saveSoundPreset(preset)
        updatePresetBlocks()
    }
    
    func showPresetList() {
        let presetListVC = PresetListViewController()
        // SoundPreset으로 변경된 콜백 - 버전 정보 포함
        presetListVC.onPresetSelected = { [weak self] preset in
            // 프리셋 목록에서 선택한 경우 새로운 프리셋 생성하지 않음
            self?.applyPreset(volumes: preset.compatibleVolumes, versions: preset.compatibleVersions, name: preset.name, shouldSaveToRecent: false)
        }
        navigationController?.pushViewController(presetListVC, animated: true)
    }
}
