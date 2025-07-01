import UIKit
import AVFoundation
import MediaPlayer
import CoreData
import Combine

class MainViewController: UIViewController {
    
    // MARK: - Properties
    
    let instanceUUID = UUID().uuidString
    
    var sliders: [UISlider] = []
    var volumeFields: [UITextField] = []
    var playButtons: [UIButton] = []
    
    var recentPresetButtons: [UIButton] = []
    var favoritePresetButtons: [UIButton] = []
    var presetStackView: UIStackView!
    
    var audioModeButton: UIButton!
    
    var overallVolumeSlider: UISlider!
    var overallVolumeField: UITextField!
    var overallVolumeLevel: Float = 100.0
    
    var updateTimer: Timer?
    var playbackMonitorTimer: Timer?
    
    let volumeThreshold: Int = 80
    var hasVolumeOverride: [Bool] = Array(repeating: false, count: SoundPresetCatalog.categoryCount)
    var hasMasterOverride: Bool = false

    private var hasCompletedInitialSetup: Bool = false
    private var hasPerformedDelayedInit: Bool = false

    var persistentContainer: NSPersistentContainer? {
        (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer
    }

    // MARK: - Lifecycle & Staged Initialization
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("✅ ViewController [\(instanceUUID)] viewDidLoad.")
        setupCriticalUI()
        Task { await performAsyncInitialization() }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startPlaybackStateMonitoring()
        if hasCompletedInitialSetup { updatePresetBlocks() }
        if audioModeButton != nil { updateAudioModeButtonTitle() }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !hasPerformedDelayedInit {
            hasPerformedDelayedInit = true
            performDelayedInitialization()
        }
        hasCompletedInitialSetup = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopPlaybackStateMonitoring()
        saveCurrentState()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopPlaybackStateMonitoring()
    }

    private func setupCriticalUI() {
        view.backgroundColor = .systemBackground
        configureNavBar()
        setupSliderUI()
    }
    
    @MainActor
    private func performAsyncInitialization() async {
        await Task.detached { PresetManager.shared.migrateLegacyPresetsIfNeeded() }.value
        setupNotifications()
        setupGestures()
        restoreLastState()
    }
    
    private func performDelayedInitialization() {
        setupPresetBlocks()
        updatePresetBlocks()
        Task { await checkAndTriggerOnDeviceLearning() }
    }

    // MARK: - Setup
    
    private func configureNavBar() {
        navigationItem.title = "Deep Sleep"
        let timerItem = UIBarButtonItem(title: "타이머", style: .plain, target: self, action: #selector(showTimer))
        let saveItem = UIBarButtonItem(title: "저장", style: .plain, target: self, action: #selector(savePresetTapped))
        let presetItem = UIBarButtonItem(title: "프리셋", style: .plain, target: self, action: #selector(loadPresetTapped))
        navigationItem.leftBarButtonItems = [timerItem]
        navigationItem.rightBarButtonItems = [saveItem, presetItem]
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleApplyPresetFromChat(_:)), name: NSNotification.Name("ApplyPresetFromChat"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleModelUpdated), name: .modelUpdated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRecentPresetsUpdated), name: NSNotification.Name("RecentPresetsUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleFavoritesUpdated(_:)), name: NSNotification.Name("FavoritesUpdated"), object: nil)
    }
    
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    func setupSliderUI() {
        let scrollView = UIScrollView()
        let containerView = UIView()
        let stackView = UIStackView(axis: .vertical, spacing: 16)
        [scrollView, containerView, stackView].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        containerView.addSubview(stackView)

        let controlsStack = UIStackView(axis: .horizontal, spacing: 12)
        audioModeButton = UIButton.systemButton(image: UIImage(systemName: "speaker.wave.3"), target: self, action: #selector(audioModeButtonTapped))
        let playAll = UIButton.systemButton(image: UIImage(systemName: "play.fill"), target: self, action: #selector(playAllTapped))
        let pauseAll = UIButton.systemButton(image: UIImage(systemName: "pause.fill"), target: self, action: #selector(pauseAllTapped))
        controlsStack.addArrangedSubviews([audioModeButton, playAll, pauseAll])
        containerView.addSubview(controlsStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            containerView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            controlsStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            controlsStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: controlsStack.bottomAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])

        setupMasterVolumeSlider(stackView: stackView)

        sliders.removeAll()
        volumeFields.removeAll()
        playButtons.removeAll()
        
        for i in 0..<SoundPresetCatalog.categoryCount {
            let rowStack = UIStackView(axis: .horizontal, spacing: 12)
            let categoryButton = UIButton.systemButton(target: self, action: #selector(categoryButtonTapped(_:)))
            updateCategoryButtonTitle(categoryButton, for: i)
            categoryButton.contentHorizontalAlignment = .left
            categoryButton.tag = i
            categoryButton.widthAnchor.constraint(equalToConstant: 90).isActive = true
            
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

            let playButton = UIButton.systemButton(image: UIImage(systemName: "play.fill"), target: self, action: #selector(toggleTrack(_:)))
            playButton.tag = i
            playButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
            playButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
            playButtons.append(playButton)

            rowStack.addArrangedSubviews([categoryButton, slider, volumeField, playButton])
            stackView.addArrangedSubview(rowStack)
        }
    }
    
    // MARK: - Playback Controls

    @objc func toggleTrack(_ sender: UIButton) {
        let index = sender.tag
        if SoundManager.shared.isPlaying(at: index) {
            SoundManager.shared.pause(at: index)
        } else {
            SoundManager.shared.play(at: index)
        }
        updatePlayButtonStates()
    }
    
    @objc func playAllTapped() {
        SoundManager.shared.playAll()
        SoundManager.shared.updateNowPlayingInfo(presetName: "DeepSleep 믹스", isPlayingOverride: true)
        updatePlayButtonStates()
        provideMediumHapticFeedback()
    }

    @objc func pauseAllTapped() {
        SoundManager.shared.pauseAll()
        SoundManager.shared.updateNowPlayingInfo(presetName: SoundManager.shared.currentPresetName, isPlayingOverride: false)
        updatePlayButtonStates()
        provideMediumHapticFeedback()
    }
    
    func startPlaybackStateMonitoring() {
        stopPlaybackStateMonitoring()
        playbackMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updatePlayButtonStates()
        }
    }
    
    func stopPlaybackStateMonitoring() {
        playbackMonitorTimer?.invalidate()
        playbackMonitorTimer = nil
    }
    
    func updatePlayButtonStates() {
        DispatchQueue.main.async {
            for (index, button) in self.playButtons.enumerated() {
                let isPlaying = SoundManager.shared.isPlaying(at: index)
                button.setImage(UIImage(systemName: isPlaying ? "pause.fill" : "play.fill"), for: .normal)
            }
        }
    }
    
    // MARK: - Slider & Volume Controls

    private func setupMasterVolumeSlider(stackView: UIStackView) {
        let masterRowStack = UIStackView(axis: .horizontal, spacing: 12)
        let spacerView = UIView()
        spacerView.widthAnchor.constraint(equalToConstant: 90).isActive = true
        
        overallVolumeSlider = UISlider()
        overallVolumeSlider.minimumValue = 0
        overallVolumeSlider.maximumValue = 200
        overallVolumeSlider.value = 100
        overallVolumeSlider.addTarget(self, action: #selector(overallVolumeChanged(_:)), for: .valueChanged)
        
        overallVolumeField = UITextField()
        overallVolumeField.text = "100"
        overallVolumeField.borderStyle = .roundedRect
        overallVolumeField.keyboardType = .numberPad
        overallVolumeField.delegate = self
        overallVolumeField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        overallVolumeField.addTarget(self, action: #selector(overallVolumeFieldChanged(_:)), for: .editingChanged)
        overallVolumeField.addTarget(self, action: #selector(overallVolumeFieldEditingEnded(_:)), for: .editingDidEnd)
        
        let endSpacerView = UIView()
        endSpacerView.widthAnchor.constraint(equalToConstant: 42).isActive = true
        
        masterRowStack.addArrangedSubviews([spacerView, overallVolumeSlider, overallVolumeField, endSpacerView])
        
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        
        stackView.addArrangedSubview(masterRowStack)
        stackView.addArrangedSubview(separator)
        stackView.setCustomSpacing(16, after: separator)
    }
    
    @objc private func overallVolumeChanged(_ sender: UISlider) {
        let volumeInt = Int(sender.value)
        if volumeInt > volumeThreshold && !hasMasterOverride {
            showAlertForHighVolume()
            return
        }
        if volumeInt <= volumeThreshold { hasMasterOverride = false }
        overallVolumeLevel = sender.value
        overallVolumeField.text = "\(Int(overallVolumeLevel))"
        applyMasterVolumeToSoundManager()
        provideLightHapticFeedback()
    }
    
    @objc internal func overallVolumeFieldChanged(_ sender: UITextField) {
        sender.text = sanitizeVolumeInput(sender.text ?? "")
    }
    
    @objc private func overallVolumeFieldEditingEnded(_ sender: UITextField) {
        let volume = validateAndClampMasterVolume(sender.text ?? "")
        if volume > volumeThreshold && !hasMasterOverride {
            showAlertForHighVolume()
            return
        }
        if volume <= volumeThreshold { hasMasterOverride = false }
        sender.text = "\(volume)"
        overallVolumeSlider.value = Float(volume)
        overallVolumeLevel = Float(volume)
        applyMasterVolumeToSoundManager()
        provideMediumHapticFeedback()
    }
    
    private func applyMasterVolumeToSoundManager() {
        let masterMultiplier = overallVolumeLevel / 100.0
        for (index, slider) in sliders.enumerated() {
            let actualVolume = (slider.value / 100.0) * masterMultiplier
            SoundManager.shared.setVolume(at: index, volume: actualVolume)
        }
    }
    
    @objc private func categoryButtonTapped(_ sender: UIButton) {
        let categoryIndex = sender.tag
        let versionCount = SoundPresetCatalog.getVersionCount(for: categoryIndex)
        guard versionCount > 1 else { return }
        let nextVersion = (SoundManager.shared.getCurrentVersions()[categoryIndex] + 1) % versionCount
        selectVersion(categoryIndex: categoryIndex, versionIndex: nextVersion)
    }

    private func selectVersion(categoryIndex: Int, versionIndex: Int) {
        SoundManager.shared.selectVersion(categoryIndex: categoryIndex, versionIndex: versionIndex)
        if let button = view.viewWithTag(categoryIndex) as? UIButton {
            updateCategoryButtonTitle(button, for: categoryIndex)
        }
        provideMediumHapticFeedback()
    }
    
    internal func updateCategoryButtonTitle(_ button: UIButton, for categoryIndex: Int) {
        let categoryDisplay = SoundPresetCatalog.getCategoryInfo(at: categoryIndex)?.name ?? ""
        let versionCount = SoundPresetCatalog.getVersionCount(for: categoryIndex)
        let title = versionCount > 1 ? "\(categoryDisplay) (v\(SoundManager.shared.getCurrentVersions()[categoryIndex] + 1))" : categoryDisplay
        button.setTitle(title, for: .normal)
    }
    
    internal func updateAllCategoryButtonTitles() {
        for i in 0..<SoundPresetCatalog.categoryCount {
            if let button = view.viewWithTag(i) as? UIButton {
                updateCategoryButtonTitle(button, for: i)
            }
        }
    }
    
    @objc func sliderChanged(_ sender: UISlider) {
        let index = sender.tag
        let volume = Int(sender.value)
        if volume > volumeThreshold && !hasVolumeOverride[index] {
            showAlertForHighVolume()
            return
        }
        if volume <= volumeThreshold { hasVolumeOverride[index] = false }
        volumeFields[index].text = "\(volume)"
        let actualVolume = (Float(volume) / 100.0) * (overallVolumeLevel / 100.0)
        SoundManager.shared.setVolume(at: index, volume: actualVolume)
        provideLightHapticFeedback()
    }

    @objc func textFieldChanged(_ sender: UITextField) {
        sender.text = sanitizeVolumeInput(sender.text ?? "")
    }
    
    @objc func textFieldEditingEnded(_ sender: UITextField) {
        let index = sender.tag
        let volume = validateAndClampVolume(sender.text ?? "")
        sender.text = "\(volume)"
        sliders[index].value = Float(volume)
        let actualVolume = (Float(volume) / 100.0) * (overallVolumeLevel / 100.0)
        SoundManager.shared.setVolume(at: index, volume: actualVolume)
        provideMediumHapticFeedback()
    }
    
    func updateSliderAndTextField(at index: Int, volume: Float) {
        guard index >= 0, index < sliders.count else { return }
        let clampedVolume = max(0, min(100, volume))
        sliders[index].value = clampedVolume
        volumeFields[index].text = "\(Int(clampedVolume))"
        let actualVolume = (clampedVolume / 100.0) * (overallVolumeLevel / 100.0)
        SoundManager.shared.setVolume(at: index, volume: actualVolume)
    }
    
    func updateAllSlidersAndFields(volumes: [Float], versions: [Int]? = nil) {
        if let versions = versions {
            for (i, v) in versions.enumerated() {
                selectVersion(categoryIndex: i, versionIndex: v)
            }
        }
        for i in 0..<min(volumes.count, sliders.count) {
            updateSliderAndTextField(at: i, volume: volumes[i])
        }
        updateAllCategoryButtonTitles()
    }
    
    func sanitizeVolumeInput(_ input: String) -> String {
        return String(input.filter { $0.isNumber }.prefix(3))
    }
    
    func validateAndClampVolume(_ input: String) -> Int {
        return min(100, max(0, Int(input) ?? 0))
    }
    
    func validateAndClampMasterVolume(_ input: String) -> Int {
        return min(200, max(0, Int(input) ?? 0))
    }
    
    // MARK: - Preset Blocks
    
    func setupPresetBlocks() {
        presetStackView = UIStackView(axis: .vertical, spacing: 20)
        presetStackView.translatesAutoresizingMaskIntoConstraints = false
        
        let recentSection = createPresetSection(title: "🕰️ 최근 사용한 프리셋", buttonCount: 4, isRecent: true)
        recentPresetButtons = recentSection.buttons
        
        let favoriteSection = createPresetSection(title: "⭐️ 즐겨찾기 프리셋", buttonCount: 4, isRecent: false)
        favoritePresetButtons = favoriteSection.buttons
        
        presetStackView.addArrangedSubviews([recentSection.container, favoriteSection.container])
        
        if let scrollView = view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView,
           let containerView = scrollView.subviews.first,
           let sliderStackView = containerView.subviews.first(where: { $0 is UIStackView }) {
            containerView.addSubview(presetStackView)
            NSLayoutConstraint.activate([
                presetStackView.topAnchor.constraint(equalTo: sliderStackView.bottomAnchor, constant: 30),
                presetStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
                presetStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
                presetStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -30)
            ])
        }
    }
    
    func createPresetSection(title: String, buttonCount: Int, isRecent: Bool) -> (container: UIView, buttons: [UIButton]) {
        let container = UIView()
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        
        let buttons = (0..<buttonCount).map { createPresetButton(index: $0, isRecent: isRecent) }
        let buttonStack = UIStackView(axis: .horizontal, spacing: 8, distribution: .fillEqually)
        buttons.forEach(buttonStack.addArrangedSubview)
        buttonStack.heightAnchor.constraint(equalToConstant: 60).isActive = true
        
        let sectionStack = UIStackView(axis: .vertical, spacing: 8)
        sectionStack.addArrangedSubviews([titleLabel, buttonStack])
        container.addSubview(sectionStack)
        
        sectionStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sectionStack.topAnchor.constraint(equalTo: container.topAnchor),
            sectionStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            sectionStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            sectionStack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return (container, buttons)
    }
    
    func createPresetButton(index: Int, isRecent: Bool) -> UIButton {
        let button = UIButton.systemButton(title: "빈 슬롯", target: self, action: #selector(presetButtonTapped(_:)))
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemGray4.cgColor
        button.backgroundColor = .systemGray6
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.textAlignment = .center
        button.setTitleColor(.systemGray2, for: .normal)
        button.tag = (isRecent ? 100 : 200) + index
        return button
    }
    
    func updatePresetBlocks() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.performPresetBlocksUpdate()
        }
    }
    
    private func performPresetBlocksUpdate() {
        let recentPresets = getRecentPresets()
        let favoritePresets = getFavoritePresets()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.configureButtonSet(self.recentPresetButtons, with: recentPresets)
            self.configureButtonSet(self.favoritePresetButtons, with: favoritePresets)
        }
    }

    private func configureButtonSet(_ buttons: [UIButton], with presets: [SoundPreset]) {
        for (index, button) in buttons.enumerated() {
            if index < presets.count {
                configurePresetButton(button, with: presets[index])
            } else {
                configureEmptyPresetButton(button)
            }
        }
    }
    
    func configurePresetButton(_ button: UIButton, with preset: SoundPreset) {
        let displayText = preset.emotion.map { "\($0)\n\(preset.name)" } ?? preset.name
        button.setTitle(displayText, for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.backgroundColor = .systemBlue.withAlphaComponent(0.1)
        button.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
    }
    
    func configureEmptyPresetButton(_ button: UIButton) {
        button.setTitle("+ 빈 슬롯", for: .normal)
        button.setTitleColor(.systemGray2, for: .normal)
        button.backgroundColor = .systemGray6
        button.layer.borderColor = UIColor.systemGray4.cgColor
    }
    
    func getRecentPresets() -> [SoundPreset] {
        return SettingsManager.shared.loadSoundPresets().filter { $0.lastUsed != nil }.sorted { $0.lastUsed! > $1.lastUsed! }.prefix(4).map { $0 }
    }
    
    func getFavoritePresets() -> [SoundPreset] {
        let favoriteIds = Set(UserDefaults.standard.stringArray(forKey: "FavoritePresetIds")?.compactMap { UUID(uuidString: $0) } ?? [])
        return SettingsManager.shared.loadSoundPresets().filter { favoriteIds.contains($0.id) }
    }
    
    @objc func presetButtonTapped(_ sender: UIButton) {
        let isRecent = sender.tag < 200
        let index = sender.tag % 100
        let presets = isRecent ? getRecentPresets() : getFavoritePresets()
        
        guard index < presets.count else {
            showPresetList()
            return
        }
        
        let preset = presets[index]
        applyPreset(volumes: preset.compatibleVolumes, versions: preset.compatibleVersions, name: preset.name, presetId: preset.id)
        provideMediumHapticFeedback()
    }
    
    // MARK: - State & Preset Management
    
    func saveCurrentState() {
        UserDefaults.standard.set(sliders.map { $0.value }, forKey: "lastSessionVolumes")
        UserDefaults.standard.set(SoundManager.shared.getCurrentVersions(), forKey: "lastSessionVersions")
        UserDefaults.standard.set(SoundManager.shared.isPlaying, forKey: "lastSessionPlaying")
    }
    
    func restoreLastState() {
        guard let volumes = UserDefaults.standard.array(forKey: "lastSessionVolumes") as? [Float],
              let versions = UserDefaults.standard.array(forKey: "lastSessionVersions") as? [Int] else { return }
        
        updateAllSlidersAndFields(volumes: volumes, versions: versions)
        
        if UserDefaults.standard.bool(forKey: "lastSessionPlaying") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.playAllTapped()
            }
        }
    }
    
    @objc func savePresetTapped() { /* TODO */ }
    @objc func loadPresetTapped() { showPresetList() }
    @objc func showTimer() { /* TODO */ }
    @objc func dismissKeyboard() { view.endEditing(true) }

    @objc private func handleApplyPresetFromChat(_ notification: Notification) {
        guard let info = notification.userInfo,
              let volumes = info["volumes"] as? [Float],
              let versions = info["versions"] as? [Int],
              let name = info["name"] as? String else { return }
        applyPreset(volumes: volumes, versions: versions, name: name)
    }

    func applyPreset(volumes: [Float], versions: [Int]? = nil, name: String, presetId: UUID? = nil) {
        updateAllSlidersAndFields(volumes: volumes, versions: versions)
        SoundManager.shared.updateNowPlayingInfo(presetName: name)
        if let id = presetId {
            SettingsManager.shared.updatePresetTimestamp(id: id)
        }
        updatePresetBlocks()
    }

    func showPresetList() {
        let vc = PresetListViewController()
        vc.onPresetSelected = { [weak self] preset in
            self?.applyPreset(volumes: preset.compatibleVolumes, versions: preset.compatibleVersions, name: preset.name, presetId: preset.id)
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    // MARK: - On-Device Learning & Misc
    
    @MainActor
    private func checkAndTriggerOnDeviceLearning() async {
        if await ComprehensiveRecommendationEngine.shared.triggerModelUpdate() {
            ComprehensiveRecommendationEngine.shared.applyUpdatedModel()
        }
    }

    @objc private func handleModelUpdated() {
        updatePresetBlocks()
    }
    
    @objc private func handleRecentPresetsUpdated() {
        updatePresetBlocks()
    }
    
    @objc private func handleFavoritesUpdated(_ notification: Notification) {
        updatePresetBlocks()
    }
    
    func provideLightHapticFeedback() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    func provideMediumHapticFeedback() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func showAlertForHighVolume() {
        let alert = UIAlertController(
            title: "🔊 볼륨 주의",
            message: "현재 볼륨이 높게 설정되어 있습니다. 청력 보호를 위해 볼륨을 낮추는 것을 권장합니다.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "볼륨 조절", style: .default) { _ in
            // 볼륨을 안전한 수준으로 자동 조절
            self.adjustVolumeToSafeLevel()
        })
        
        alert.addAction(UIAlertAction(title: "현재 유지", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func adjustVolumeToSafeLevel() {
        // 모든 슬라이더를 안전한 수준 (50%)으로 조절
        for (index, slider) in sliders.enumerated() {
            slider.value = 0.5
            SettingsManager.shared.updateSelectedVersion(for: index, to: Int(slider.value * Float(3 - 1))) // 기본 버전 수 3 사용
        }
        updateTotalVolume()
    }
    
    private func updateTotalVolume() {
        // 전체 볼륨 업데이트 로직
        let totalVolume = sliders.reduce(0) { $0 + $1.value }
        let averageVolume = totalVolume / Float(sliders.count)
        
        // 마스터 볼륨 슬라이더가 있다면 업데이트
        if let masterSlider = view.subviews.compactMap({ $0 as? UISlider }).first(where: { $0.tag == 999 }) {
            masterSlider.value = averageVolume
        }
        
        // 볼륨 라벨 업데이트
        if let volumeLabel = view.subviews.compactMap({ $0 as? UILabel }).first(where: { $0.tag == 998 }) {
            volumeLabel.text = "전체 볼륨: \(Int(averageVolume * 100))%"
        }
    }
}

extension MainViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        guard let textRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: textRange, with: string)
        
        if updatedText.isEmpty { return true }
        if updatedText.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) != nil { return false }
        if updatedText.count > 3 { return false }
        
        let maxValue = (textField == overallVolumeField) ? 200 : 100
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

extension UIStackView {
    
    convenience init(axis: NSLayoutConstraint.Axis, spacing: CGFloat, distribution: UIStackView.Distribution = .fill) {
        self.init(frame: .zero)
        self.axis = axis
        self.spacing = spacing
        self.distribution = distribution
    }
    
    func addArrangedSubviews(_ views: [UIView]) {
        views.forEach(addArrangedSubview)
    }
}

extension UIButton {
    
    static func systemButton(title: String = "", image: UIImage? = nil, target: Any?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setImage(image, for: .normal)
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }
}

// MARK: - Audio Mode Methods (실제 구현 필요)
extension MainViewController {
    
    @objc func audioModeButtonTapped() {
        // TODO: 실제 오디오 모드 변경 구현 필요
    }
    
    func updateAudioModeButtonTitle() {
        // TODO: 실제 오디오 모드 타이틀 업데이트 구현 필요
    }
}