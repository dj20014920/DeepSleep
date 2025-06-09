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
            title: "🧠 과학적 음향치료 추천",
            message: "음향심리학 연구 기반으로 설계된 전문 프리셋을 추천해드립니다. 특정 호르몬과 뇌파를 타겟으로 한 정교한 사운드 조합입니다.",
            preferredStyle: .actionSheet
        )
        
        // 과학적 카테고리별 추천 옵션들
        let scientificOptions = [
            ("🧠 인지능력 & 집중력", ["Deep Work Flow", "Study Session", "Learning Optimization", "Information Processing"]),
            ("💤 수면 & 휴식", ["Delta Sleep Induction", "Sleep Onset Helper", "Deep Sleep Maintenance", "REM Sleep Support"]),
            ("🌊 스트레스 & 코르티솔 완화", ["Deep Ocean Cortisol Reset", "Forest Stress Relief", "Rain Anxiety Calm", "Nature Stress Detox"]),
            ("🧘 명상 & 마음챙김", ["Theta Deep Relaxation", "Zen Garden Flow", "Mindfulness Bell", "Tibetan Bowl Substitute"]),
            ("⚡ 에너지 & 각성", ["Morning Energy Boost", "Afternoon Revival", "Workout Motivation", "Social Energy"]),
            ("💚 감정조절 & 치유", ["Emotional Healing", "Self Compassion", "Love & Connection", "Inner Peace"]),
            ("🌿 자연치유력", ["Forest Bathing", "Ocean Therapy", "Mountain Serenity", "Desert Vastness"]),
            ("🔬 신경과학 특화", ["Neuroplasticity Boost", "Brain Training", "Mental Flexibility", "Cognitive Reserve"]),
            ("🏥 치료 목적", ["Tinnitus Relief", "Autism Sensory Calm", "ADHD Focus Aid", "PTSD Grounding"]),
            ("🌈 고급 체험", ["Multi-sensory Harmony", "Synesthetic Experience", "Temporal Perception", "Spatial Awareness"])
        ]
        
        for (category, presets) in scientificOptions {
            alert.addAction(UIAlertAction(title: category, style: .default) { [weak self] _ in
                self?.showScientificPresetSubMenu(category: category, presets: presets)
            })
        }
        
        // 랜덤 과학적 추천
        alert.addAction(UIAlertAction(title: "🎲 랜덤 과학적 추천", style: .default) { [weak self] _ in
            self?.generateRandomScientificRecommendation()
        })
        
        // 시간대 최적화 추천
        alert.addAction(UIAlertAction(title: "⏰ 지금 시간대 최적화", style: .default) { [weak self] _ in
            self?.generateTimeOptimizedRecommendation()
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
    
    func showScientificPresetSubMenu(category: String, presets: [String]) {
        let alert = UIAlertController(
            title: category,
            message: "원하는 과학적 프리셋을 선택하세요. 각 프리셋은 특정 신경과학적 효과를 위해 정교하게 설계되었습니다.",
            preferredStyle: .actionSheet
        )
        
        for presetName in presets {
            let description = SoundPresetCatalog.scientificDescriptions[presetName] ?? "과학적 연구 기반 음향 치료"
            let shortDescription = String(description.prefix(40)) + (description.count > 40 ? "..." : "")
            
            alert.addAction(UIAlertAction(title: "\(convertToKoreanName(presetName))", style: .default) { [weak self] _ in
                self?.applyScientificPreset(presetName)
            })
        }
        
        alert.addAction(UIAlertAction(title: "🔙 뒤로", style: .cancel) { [weak self] _ in
            self?.showAIRecommendationDialog()
        })
        
        present(alert, animated: true)
    }
    
    func generateRandomScientificRecommendation() {
        let scientificPreset = SoundPresetCatalog.getRandomScientificPreset()
        let koreanName = convertToKoreanName(scientificPreset.name)
        
        // 프리셋 적용
        applyPreset(
            volumes: scientificPreset.volumes,
            versions: SoundPresetCatalog.defaultVersions,
            name: koreanName,
            shouldSaveToRecent: true
        )
        
        // 상세 정보와 함께 결과 표시
        showScientificRecommendationResult(
            name: koreanName,
            description: scientificPreset.description,
            duration: scientificPreset.duration,
            originalName: scientificPreset.name
        )
    }
    
    func generateTimeOptimizedRecommendation() {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let timeOfDay = getTimeOfDay(currentHour)
        
        let timeBasedPresets: [String: [String]] = [
            "새벽": ["Dawn Awakening", "Sleep Onset Helper", "Night Preparation"],
            "아침": ["Morning Energy Boost", "Social Energy", "Workout Motivation"],
            "오전": ["Deep Work Flow", "Study Session", "Learning Optimization"],
            "점심": ["Midday Balance", "Problem Solving", "Alpha Wave Mimic"],
            "오후": ["Afternoon Revival", "Information Processing", "Brain Training"],
            "저녁": ["Sunset Transition", "Emotional Healing", "Inner Peace"],
            "밤": ["Delta Sleep Induction", "Theta Deep Relaxation", "Night Preparation"]
        ]
        
        let availablePresets = timeBasedPresets[timeOfDay] ?? ["Alpha Wave Mimic", "Inner Peace", "Deep Ocean Cortisol Reset"]
        let selectedPreset = availablePresets.randomElement() ?? "Alpha Wave Mimic"
        
        applyScientificPreset(selectedPreset)
    }
    
    func applyScientificPreset(_ presetName: String) {
        guard let volumes = SoundPresetCatalog.scientificPresets[presetName] else {
            showToast(message: "⚠️ 프리셋을 찾을 수 없습니다")
            return
        }
        
        let koreanName = convertToKoreanName(presetName)
        let description = SoundPresetCatalog.scientificDescriptions[presetName] ?? "과학적 연구 기반 음향 치료"
        let duration = SoundPresetCatalog.recommendedDurations[presetName] ?? "20-30분"
        
        // 프리셋 적용
        applyPreset(
            volumes: volumes,
            versions: SoundPresetCatalog.defaultVersions,
            name: koreanName,
            shouldSaveToRecent: true
        )
        
        // 결과 표시
        showScientificRecommendationResult(
            name: koreanName,
            description: description,
            duration: duration,
            originalName: presetName
        )
    }
    
    func showScientificRecommendationResult(name: String, description: String, duration: String, originalName: String) {
        let timing = SoundPresetCatalog.optimalTimings[originalName] ?? "언제든지"
        
        let alert = UIAlertController(
            title: "🧠 과학적 프리셋 적용됨",
            message: """
            \(name)
            
            📚 과학적 근거:
            \(description)
            
            ⏰ 권장 사용시간: \(duration)
            🎯 최적 타이밍: \(timing)
            
            이 프리셋은 음향심리학 연구를 바탕으로 특정 호르몬과 뇌파에 최적화되어 설계되었습니다.
            """,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "✅ 완료", style: .default))
        
        alert.addAction(UIAlertAction(title: "💾 즐겨찾기 추가", style: .default) { [weak self] _ in
            self?.saveCurrentAsScientificPreset(name: name, originalName: originalName)
        })
        
        present(alert, animated: true)
    }
    
    func saveCurrentAsScientificPreset(name: String, originalName: String) {
        let volumes = getCurrentVolumes()
        let versions = getCurrentVersions()
        
        let preset = SoundPreset(
            name: name,
            volumes: volumes,
            selectedVersions: versions,
            emotion: "과학적",
            isAIGenerated: true,
            scientificBasis: SoundPresetCatalog.scientificDescriptions[originalName]
        )
        
        SettingsManager.shared.saveSoundPreset(preset)
        updatePresetBlocks()
        showToast(message: "🧠 과학적 프리셋 '\(name)'이 저장되었습니다!")
    }
    
    private func convertToKoreanName(_ englishName: String) -> String {
        let nameMapping: [String: String] = [
            "Deep Ocean Cortisol Reset": "🌊 깊은 바다 코르티솔 리셋",
            "Forest Stress Relief": "🌲 숲속 스트레스 완화",
            "Rain Anxiety Calm": "🌧️ 빗소리 불안 진정",
            "Nature Stress Detox": "🍃 자연 스트레스 해독",
            "Alpha Wave Mimic": "🧠 알파파 모방 집중",
            "Theta Deep Relaxation": "🌀 세타파 깊은 이완",
            "Delta Sleep Induction": "😴 델타파 수면 유도",
            "Gamma Focus Simulation": "⚡ 감마파 집중 시뮬레이션",
            "Sleep Onset Helper": "🌙 수면 시작 도우미",
            "Deep Sleep Maintenance": "💤 깊은 수면 유지",
            "REM Sleep Support": "👁️ 렘수면 지원",
            "Night Terror Calm": "🌃 야간 공포 진정",
            "Tibetan Bowl Substitute": "🎵 티베트 보울 대체",
            "Zen Garden Flow": "🧘 선 정원 흐름",
            "Mindfulness Bell": "🔔 마음챙김 종소리",
            "Walking Meditation": "🚶 걸으며 명상",
            "Deep Work Flow": "💻 몰입 작업 플로우",
            "Creative Burst": "💡 창의성 폭발",
            "Study Session": "📚 학습 세션",
            "Coding Focus": "⌨️ 코딩 집중",
            "Morning Energy Boost": "🌅 아침 에너지 부스터",
            "Afternoon Revival": "☀️ 오후 활력 회복",
            "Workout Motivation": "💪 운동 동기 부여",
            "Social Energy": "👥 사회적 에너지",
            "Dawn Awakening": "🌄 새벽 깨어남",
            "Midday Balance": "⚖️ 한낮 균형",
            "Sunset Transition": "🌅 석양 전환",
            "Night Preparation": "🌙 밤 준비",
            "Memory Enhancement": "🧠 기억력 향상",
            "Learning Optimization": "📖 학습 최적화",
            "Problem Solving": "🧩 문제 해결",
            "Information Processing": "🔍 정보 처리",
            "Emotional Healing": "💚 감정 치유",
            "Self Compassion": "🤗 자기 연민",
            "Love & Connection": "💕 사랑과 연결",
            "Inner Peace": "☮️ 내면의 평화",
            "Forest Bathing": "🌲 산림욕 (신린요쿠)",
            "Ocean Therapy": "🌊 바다 치료",
            "Mountain Serenity": "🏔️ 산의 고요함",
            "Desert Vastness": "🏜️ 사막의 광활함",
            "Neuroplasticity Boost": "🧠 신경가소성 부스터",
            "Brain Training": "🎯 뇌 훈련",
            "Mental Flexibility": "🤸 정신적 유연성",
            "Cognitive Reserve": "🧠 인지 예비능력",
            "Tinnitus Relief": "👂 이명 완화",
            "Autism Sensory Calm": "🧩 자폐 감각 진정",
            "ADHD Focus Aid": "🎯 ADHD 집중 보조",
            "PTSD Grounding": "🌍 PTSD 그라운딩",
            "Multi-sensory Harmony": "🌈 다감각 조화",
            "Synesthetic Experience": "🎨 공감각적 경험",
            "Temporal Perception": "⏰ 시간 지각",
            "Spatial Awareness": "📐 공간 인식"
        ]
        
        return nameMapping[englishName] ?? "🎵 \(englishName)"
    }
    
    private func getTimeOfDay(_ hour: Int) -> String {
        switch hour {
        case 5..<8: return "새벽"
        case 8..<12: return "아침"
        case 12..<14: return "점심"
        case 14..<18: return "오후"
        case 18..<22: return "저녁"
        case 22..<24, 0..<5: return "밤"
        default: return "하루"
        }
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
