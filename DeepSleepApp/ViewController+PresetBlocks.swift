import UIKit
import CryptoKit
#if canImport(Compression)
import Compression
#endif

// MARK: - 프리셋 블록 UI 관련 Extension
extension MainViewController {
    
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
        
        // AI 개인화 추천 버튼 추가
        if #available(iOS 17.0, *) {
            let recSection = createRecommendationSection()
            presetStackView.addArrangedSubview(recSection)
        }
        
        // 🏆 Apple Watch 건강 분석 섹션 추가
        let healthSection = createAppleWatchHealthSection()
        presetStackView.addArrangedSubview(healthSection)
        
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
        // 🛡️ 디바운싱: 연속된 업데이트 요청을 방지
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.performPresetBlocksUpdate()
        }
    }
    
    private func performPresetBlocksUpdate() {
        let recentPresets = getRecentPresets()
        let favoritePresets = getFavoritePresets()
        
        // 🛡️ UI 업데이트를 메인 스레드에서 실행
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
        
        // 최근 사용한 프리셋 버튼 업데이트
            for (index, button) in self.recentPresetButtons.enumerated() {
            if index < recentPresets.count {
                let preset = recentPresets[index]
                    self.configurePresetButton(button, with: preset, isEmpty: false)
            } else {
                    self.configureEmptyPresetButton(button)
            }
        }
        
        // 즐겨찾기 프리셋 버튼 업데이트
            for (index, button) in self.favoritePresetButtons.enumerated() {
            if index < favoritePresets.count {
                let preset = favoritePresets[index]
                    self.configurePresetButton(button, with: preset, isEmpty: false)
            } else {
                    self.configureEmptyPresetButton(button)
                }
            }
        }
    }
    
    func configurePresetButton(_ button: UIButton, with preset: SoundPreset, isEmpty: Bool) {
        if isEmpty {
            configureEmptyPresetButton(button)
            return
        }
        
        // 🛡️ 완전한 초기화: 모든 UI 요소를 완전히 제거
        cleanButton(button)
        
        // 🛡️ 추가 안전장치: 잠시 대기 후 UI 업데이트
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak button] in
            guard let button = button else { return }
            
            // 🛡️ 마지막 확인: 모든 라벨이 제거되었는지 재확인
            let remainingLabels = button.subviews.compactMap { $0 as? UILabel }
            remainingLabels.forEach { $0.removeFromSuperview() }
            
            // 새 라벨 추가
            let nameLabel = UILabel()
            let displayText = preset.emotion != nil ? "\(preset.emotion!)\n\(preset.name)" : preset.name
            nameLabel.text = displayText
            nameLabel.font = .systemFont(ofSize: 12, weight: .medium)
            nameLabel.textColor = .label
            nameLabel.textAlignment = .center
            nameLabel.numberOfLines = 2
            nameLabel.lineBreakMode = .byTruncatingTail
            nameLabel.adjustsFontSizeToFitWidth = true
            nameLabel.minimumScaleFactor = 0.7
            nameLabel.translatesAutoresizingMaskIntoConstraints = false
            nameLabel.tag = 999999 // 고유 태그
            nameLabel.backgroundColor = .clear // 배경 투명
            
            button.addSubview(nameLabel)
            NSLayoutConstraint.activate([
                nameLabel.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                nameLabel.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: button.leadingAnchor, constant: 4),
                nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: button.trailingAnchor, constant: -4)
            ])
            
            button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
            button.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
            button.layer.borderWidth = 1
            button.layer.cornerRadius = 12
        }
    }
    
    func configureEmptyPresetButton(_ button: UIButton) {
        // 🛡️ 완전한 초기화
        cleanButton(button)
        
        // 🛡️ 추가 안전장치: 잠시 대기 후 UI 업데이트
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak button] in
            guard let button = button else { return }
            
            // 🛡️ 마지막 확인: 모든 라벨이 제거되었는지 재확인
            let remainingLabels = button.subviews.compactMap { $0 as? UILabel }
            remainingLabels.forEach { $0.removeFromSuperview() }
            
            let nameLabel = UILabel()
            nameLabel.text = "+ 빈 슬롯"
            nameLabel.font = .systemFont(ofSize: 12, weight: .medium)
            nameLabel.textColor = .systemGray2
            nameLabel.textAlignment = .center
            nameLabel.numberOfLines = 1
            nameLabel.translatesAutoresizingMaskIntoConstraints = false
            nameLabel.tag = 999998 // 고유 태그
            nameLabel.backgroundColor = .clear // 배경 투명
            
            button.addSubview(nameLabel)
            NSLayoutConstraint.activate([
                nameLabel.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                nameLabel.centerYAnchor.constraint(equalTo: button.centerYAnchor)
            ])
            
        button.backgroundColor = UIColor.systemGray6
        button.layer.borderColor = UIColor.systemGray4.cgColor
            button.layer.borderWidth = 1
            button.layer.cornerRadius = 12
        }
    }
    
    // 🛡️ 버튼 초기화 함수 - 간소화된 안전 버전
    private func cleanButton(_ button: UIButton) {
        // 기존 라벨들만 제거 (제약조건은 건드리지 않음)
        let problematicTags = [999999, 999998]
        for tag in problematicTags {
            if let taggedView = button.viewWithTag(tag) {
                taggedView.removeFromSuperview()
            }
        }
        
        // 버튼 타이틀 정리
        button.setTitle(nil, for: .normal)
        button.setAttributedTitle(nil, for: .normal)
    }
    
    func getRecentPresets() -> [SoundPreset] {
        let allPresets = SettingsManager.shared.loadSoundPresets()
        
        // 1. lastUsed 날짜가 있는 프리셋만 필터링
        // 2. 최신순으로 정렬 (내림차순)
        let sortedRecentPresets = allPresets
            .filter { $0.lastUsed != nil }
            .sorted { $0.lastUsed! > $1.lastUsed! }
        
        // 3. 상위 4개만 선택
        return Array(sortedRecentPresets.prefix(4))
    }
    
    func getFavoritePresets() -> [SoundPreset] {
        // UserDefaults에서 즐겨찾기 ID들을 가져와서 해당하는 프리셋들 반환
        let favoriteIds = UserDefaults.standard.array(forKey: "FavoritePresetIds") as? [String] ?? []
        let favoritePresetIds = Set(favoriteIds.compactMap { UUID(uuidString: $0) })
        
        let allPresets = SettingsManager.shared.loadSoundPresets()
        return allPresets.filter { favoritePresetIds.contains($0.id) }
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
        
        print("🎵 [presetButtonTapped] 프리셋 버튼 클릭: \(preset.name), ID: \(preset.id.uuidString)")
        print("  - 볼륨: \(preset.compatibleVolumes)")
        print("  - 버전: \(preset.compatibleVersions)")
        
        // ID를 전달하여 최근 사용 시간을 갱신하는 새 applyPreset 함수 호출
        applyPreset(
            volumes: preset.compatibleVolumes,
            versions: preset.compatibleVersions,
            name: preset.name,
            presetId: preset.id,
            saveAsNew: false
        )
        
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
        
        // 프리셋 적용 (ID가 없으므로 nil, 신규 저장 옵션 true)
        applyPreset(
            volumes: scientificPreset.volumes,
            versions: SoundPresetCatalog.defaultVersions,
            name: koreanName,
            presetId: nil,
            saveAsNew: true
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
        
        // 프리셋 적용 (ID가 없으므로 nil, 신규 저장 옵션 true)
        applyPreset(
            volumes: volumes,
            versions: SoundPresetCatalog.defaultVersions,
            name: koreanName,
            presetId: nil,
            saveAsNew: true
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
            // 프리셋 목록에서 선택 시 ID를 전달하여 시간 갱신
            self?.applyPreset(
                volumes: preset.compatibleVolumes,
                versions: preset.compatibleVersions,
                name: preset.name,
                presetId: preset.id,
                saveAsNew: false
            )
        }
        navigationController?.pushViewController(presetListVC, animated: true)
    }
    
    // MARK: - 개인화 추천 버튼 UI 및 로직
    @available(iOS 17.0, *)
    private func createRecommendationSection() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        let button = UIButton(type: .system)
        button.setTitle("🔍 개인화 추천", for: .normal)
        button.layer.cornerRadius = 12
        button.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.1)
        button.setTitleColor(.systemPurple, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(recommendationButtonTapped), for: .touchUpInside)
        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            button.heightAnchor.constraint(equalToConstant: 44)
        ])
        return container
    }

    @objc @available(iOS 17.0, *)
    private func recommendationButtonTapped() {
        // LLMRouter를 사용한 로컬/외부 AI 분기 추천 생성
        Task {
            do {
                let userContext = await createUserContext()
                // let llmOutput = try await LLMRouter.shared.processPrompt(userContext)
                // let recommendation = ComprehensiveRecommendationEngine.shared.generateMasterRecommendation()
                
                // 임시 플레이스홀더
                let recommendation = "AI 추천이 곧 제공됩니다."
                
                await MainActor.run {
                    // ... UI 업데이트
                }
            } catch {
                // ... 에러 처리
            }
        }
    }

    /// 사용자 컨텍스트 생성 (LLMRouter용 - 로컬/외부 분기)
    private func createUserContextForRecommendation() -> String {
        let currentTime = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: currentTime)
        
        // 현재 시간대에 따른 컨텍스트
        let timeContext: String
        let hour = Calendar.current.component(.hour, from: currentTime)
        switch hour {
        case 6..<12:
            timeContext = "아침 시간대"
        case 12..<18:
            timeContext = "오후 시간대"
        case 18..<22:
            timeContext = "저녁 시간대"
        default:
            timeContext = "밤 시간대"
        }
        
        // 배터리 상태 확인 (로컬 AI 우선 여부 결정)
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryInfo = batteryLevel < 0.3 ? "(배터리 부족 - 로컬 AI 우선)" : "(배터리 충분)"
        
        return """
        사용자 개인화 추천 요청:
        - 현재 시간: \(timeString) (\(timeContext))
        - 배터리 상태: \(batteryInfo)
        - 요청 유형: 음향 치료 프리셋 추천
        - 개인화 레벨: 고급
        - 응답 형식: 구체적인 프리셋 설정과 설명
        
        사용자의 현재 상황에 가장 적합한 딥슬립 음향 치료 프리셋을 추천해주세요.
        로컬 AI로 충분하면 로컬에서, 복잡한 분석이 필요하면 외부 AI를 활용해주세요.
        """
    }

    /// 추천 결과를 사용자에게 표시하고 적용할 수 있는 알림창을 띄웁니다.
    @available(iOS 17.0, *)
    private func showRecommendationResult(_ result: ComprehensiveMasterRecommendation) {
        let primary = result.primaryRecommendation
        let alert = UIAlertController(
            title: primary.presetName,
            message: primary.personalizedExplanation ?? primary.reasoning,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "적용", style: .default) { [weak self] _ in
            self?.applyPreset(
                volumes: primary.optimizedVolumes,
                versions: primary.optimizedVersions,
                name: primary.presetName,
                presetId: nil,
                saveAsNew: true
            )
        })
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        present(alert, animated: true)
    }

    /// LoRA 어댑터 다운로드 및 결합 모델 추천 실행
    @available(iOS 17.0, *)
    private func downloadAndApplyLoRAAdapter() {
        Task {
            let urlStringRaw = "https://example.com/adapterfile.adapter.gz"
            guard let url = URL(string: urlStringRaw) else {
                await MainActor.run { showToast(message: "잘못된 URL") }
                return
            }
            do {
                // 어댑터 다운로드 및 캐시
                let adapterURL = try await DynamicLoRAAdapter.shared.downloadAdapter(from: url, rank: 4)
                print("🔽 [LoRA] 다운로드 및 캐시 완료: \(adapterURL)")
                // 결합 모델로 추천 생성
                let recommendation = ComprehensiveRecommendationEngine.shared.generateMasterRecommendation()
                await MainActor.run {
                    showToast(message: "개인화 모델 적용 완료")
                    showRecommendationResult(recommendation)
                }
            } catch {
                await MainActor.run { showToast(message: "LoRA 다운로드 실패: \(error.localizedDescription)") }
            }
        }
    }
    
    // MARK: - 🏆 Apple Watch Health Analysis Section
    
    /// Apple Watch 건강 분석 섹션 생성
    private func createAppleWatchHealthSection() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "⌚ Apple Watch 건강 분석"
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 건강 분석 버튼
        let healthAnalysisButton = createHealthAnalysisButton()
        
        // 건강 상태 표시 라벨
        let healthStatusLabel = createHealthStatusLabel()
        
        let buttonStack = UIStackView(arrangedSubviews: [healthAnalysisButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 8
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleLabel)
        container.addSubview(buttonStack)
        container.addSubview(healthStatusLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            buttonStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            buttonStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            buttonStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            buttonStack.heightAnchor.constraint(equalToConstant: 50),
            
            healthStatusLabel.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 4),
            healthStatusLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            healthStatusLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            healthStatusLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    /// 건강 분석 버튼 생성
    private func createHealthAnalysisButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("🏥 건강 상태 분석", for: .normal)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 2
        
        // 그라데이션 스타일 적용
        button.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
        button.layer.borderColor = UIColor.systemRed.cgColor
        button.setTitleColor(.systemRed, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tag = 1001 // Apple Watch 건강 분석 버튼 식별용
        button.addTarget(self, action: #selector(appleWatchHealthButtonTapped), for: .touchUpInside)
        
        // 애니메이션 효과 추가
        button.addTarget(self, action: #selector(healthButtonTouchDown), for: .touchDown)
        button.addTarget(self, action: #selector(healthButtonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        return button
    }
    
    /// 건강 상태 표시 라벨 생성
    private func createHealthStatusLabel() -> UILabel {
        let label = UILabel()
        label.text = "건강 데이터를 분석하여 맞춤 프리셋을 추천받으세요"
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    // MARK: - Apple Watch Health Button Actions
    
    /// Apple Watch 건강 분석 버튼 액션
    @objc private func appleWatchHealthButtonTapped() {
        // 직접 HealthKitManager를 통한 건강 분석 수행
        HealthKitManager.shared.analyzeAndCoachWithAI { [weak self] wellness in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let wellness = wellness {
                    self.updateHealthAnalysisUI(wellness: wellness)
                    self.showToast(message: "🏥 건강 분석이 완료되었습니다")
                } else {
                    self.showToast(message: "건강 데이터 분석에 실패했습니다")
                }
            }
        }
        
        // 햅틱 피드백
        provideMediumHapticFeedback()
    }
    
    /// 버튼 터치 다운 애니메이션
    @objc private func healthButtonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            sender.alpha = 0.8
        }
    }
    
    /// 버튼 터치 업 애니메이션
    @objc private func healthButtonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = .identity
            sender.alpha = 1.0
        }
    }
    
    /// 건강 상태에 따른 버튼 스타일 업데이트
    func updateHealthButtonStyle(status: String) {
        guard let healthButton = view.viewWithTag(1001) as? UIButton else { return }
        
        let (color, emoji) = getHealthStatusStyle(status: status)
        
        healthButton.backgroundColor = color.withAlphaComponent(0.1)
        healthButton.layer.borderColor = color.cgColor
        healthButton.setTitleColor(color, for: .normal)
        healthButton.setTitle("\(emoji) \(status)", for: .normal)
        
        // 상태 라벨도 업데이트
        updateHealthStatusLabel(status: status)
    }
    
    /// 건강 상태별 색상과 이모지 반환
    private func getHealthStatusStyle(status: String) -> (UIColor, String) {
        switch status {
        case let s where s.contains("훌륭") || s.contains("excellent"):
            return (.systemGreen, "💚")
        case let s where s.contains("양호") || s.contains("good"):
            return (.systemBlue, "💙")
        case let s where s.contains("보통") || s.contains("fair"):
            return (.systemOrange, "🧡")
        case let s where s.contains("주의") || s.contains("concerning"):
            return (.systemRed, "❤️")
        case let s where s.contains("긴급") || s.contains("critical"):
            return (.systemPurple, "🆘")
        default:
            return (.systemGray, "🏥")
        }
    }
    
    /// 건강 상태 라벨 업데이트
    private func updateHealthStatusLabel(status: String) {
        // 건강 상태 라벨 찾기 (createHealthStatusLabel에서 생성된 라벨)
        if let container = view.viewWithTag(1001)?.superview?.superview,
           let statusLabel = container.subviews.compactMap({ $0 as? UILabel }).last {
            
            let statusMessage = generateHealthStatusMessage(status: status)
            statusLabel.text = statusMessage
        }
    }
    
    /// 건강 상태별 메시지 생성
    private func generateHealthStatusMessage(status: String) -> String {
        switch status {
        case let s where s.contains("훌륭") || s.contains("excellent"):
            return "✨ 건강 상태가 훌륭합니다! 현재 컨디션을 유지하세요"
        case let s where s.contains("양호") || s.contains("good"):
            return "😊 건강 상태가 양호합니다. 꾸준한 관리를 계속하세요"
        case let s where s.contains("보통") || s.contains("fair"):
            return "⚖️ 보통 상태입니다. 생활 패턴 개선을 고려해보세요"
        case let s where s.contains("주의") || s.contains("concerning"):
            return "⚠️ 주의가 필요한 상태입니다. 휴식과 스트레스 관리가 필요해요"
        case let s where s.contains("긴급") || s.contains("critical"):
            return "🚨 즉시 관리가 필요합니다. 충분한 휴식을 취하세요"
        default:
            return "건강 데이터를 분석하여 맞춤 프리셋을 추천받으세요"
        }
    }
    
    /// 건강 분석 완료 후 UI 업데이트
    func updateHealthAnalysisUI(wellness: HealthKitManager.DailyWellness) {
        // 건강 상태 평가
        let overallStatus = evaluateOverallHealthForUI(wellness: wellness)
        
        // 버튼 스타일 업데이트
        updateHealthButtonStyle(status: overallStatus)
        
        // 토스트 메시지 표시
        let statusEmoji = getHealthStatusStyle(status: overallStatus).1
        showToast(message: "\(statusEmoji) 건강 분석 완료: \(overallStatus)")
        
        print("🏥 [HealthAnalysisUI] 건강 상태 UI 업데이트 완료: \(overallStatus)")
    }
    
    /// UI용 건강 상태 종합 평가
    private func evaluateOverallHealthForUI(wellness: HealthKitManager.DailyWellness) -> String {
        var healthScore = 0
        
        // 스트레스 레벨 점수
        switch wellness.stressLevel {
        case .veryLow: healthScore += 4
        case .low: healthScore += 3
        case .moderate: healthScore += 2
        case .high: healthScore += 1
        case .veryHigh: healthScore += 0
        }
        
        // 수면 품질 점수
        switch wellness.sleepQuality {
        case .excellent: healthScore += 4
        case .good: healthScore += 3
        case .fair: healthScore += 2
        case .poor: healthScore += 1
        case .critical: healthScore += 0
        }
        
        // 활동 수준 점수
        switch wellness.activityLevel {
        case .veryActive: healthScore += 2
        case .active: healthScore += 2
        case .moderate: healthScore += 1
        case .light: healthScore += 1
        case .sedentary: healthScore += 0
        }
        
        // 총점 기반 상태 반환 (10점 만점)
        switch healthScore {
        case 8...10: return "훌륭함"
        case 6...7: return "양호"
        case 4...5: return "보통"
        case 2...3: return "주의필요"
        case 0...1: return "긴급상황"
        default: return "분석중"
        }
    }
}

// URLSessionDownloadDelegate extension removed in refactoring. Recommendation flow unified.
