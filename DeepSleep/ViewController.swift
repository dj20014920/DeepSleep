import UIKit
import AVFoundation
import MediaPlayer

class ViewController: UIViewController {
    
    // MARK: - Properties (11개 카테고리로 업데이트)
    
    /// 새로운 11개 이모지 라벨 (기존 A-L 대신)
    var categoryLabels: [String] {
        return SoundPresetCatalog.displayLabels
    }
    
    /// 기존 호환성을 위한 슬라이더 라벨 (deprecated)
    @available(*, deprecated, message: "Use categoryLabels instead")
    let sliderLabels = Array("ABCDEFGHIJK")  // 11개로 변경
    
    /// 감정 이모지 (기존 유지)
    let emojis = ["😊","😢","😠","😰","😴"]
    
    /// UI 요소들 (11개 카테고리)
    var sliders: [UISlider] = []
    var volumeFields: [UITextField] = []
    var playButtons: [UIButton] = []
    var versionButtons: [UIButton?] = []  // 다중 버전 카테고리만 버튼 존재
    var previewButtons: [UIButton] = []   // 미리듣기 버튼들
    
    // 프리셋 블록 UI 요소들 (기존 유지)
    var recentPresetButtons: [UIButton] = []
    var favoritePresetButtons: [UIButton] = []
    var presetStackView: UIStackView!
    
    // 실시간 재생 상태 모니터링 (기존 유지)
    var playbackMonitorTimer: Timer?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 데이터 일관성 검증 (Debug 모드에서만)
        #if DEBUG
        if !SoundPresetCatalog.validateDataConsistency() {
            print("❌ SoundPresetCatalog 데이터 불일치 감지!")
        }
        SoundPresetCatalog.printSampleData()
        #endif
        
        // 기존 프리셋 데이터 마이그레이션 (앱 시작 시 한 번만 실행)
        PresetManager.shared.migrateLegacyPresetsIfNeeded()
        
        setupViewController()
    }
    
    // MARK: - viewWillAppear 중복 제거 - Extension에서 처리
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startPlaybackStateMonitoring()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPlaybackStateMonitoring()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopPlaybackStateMonitoring()
    }

    // MARK: - Setup
    private func setupViewController() {
        view.backgroundColor = .systemBackground
        configureNavBar()
        setupEmojiSelector()
        setupSliderUI()
        setupPresetBlocks()
        configureRemoteCommands()
        setupNotifications()
        setupGestures()
        
        print("✅ ViewController 초기화 완료 - \(SoundPresetCatalog.categoryCount)개 카테고리")
    }
    
    private func configureNavBar() {
        // 왼쪽: 타이머 + 일기
        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(title: "타이머", style: .plain, target: self, action: #selector(showTimer)),
            UIBarButtonItem(title: "일기", style: .plain, target: self, action: #selector(showDiary))
        ]
        
        // 오른쪽: 저장 + 불러오기
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "저장", style: .plain, target: self, action: #selector(savePresetTapped)),
            UIBarButtonItem(title: "불러오기", style: .plain, target: self, action: #selector(loadPresetTapped))
        ]
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - 햅틱 피드백 타입 정의
    enum HapticType {
        case light, medium, heavy
    }
    
    // MARK: - 햅틱 피드백 wrapper 메서드 (ViewController+Utilities.swift와 연동)
    func provideHapticFeedback(_ type: HapticType) {
        switch type {
        case .light:
            provideLightHapticFeedback()
        case .medium:
            provideMediumHapticFeedback()
        case .heavy:
            let feedback = UIImpactFeedbackGenerator(style: .heavy)
            feedback.impactOccurred()
        }
    }
    
    // MARK: - 기존 API 호환성 보장 (중요!)
    
    /// 기존 A-L 인덱스를 사용하는 메서드들 (레거시 지원)
    var sliderCount: Int {
        return SoundPresetCatalog.categoryCount  // 11개
    }
    
    /// 기존 코드에서 sliderLabels 사용하는 부분 지원
    func getSliderLabel(at index: Int) -> String {
        guard index >= 0, index < SoundPresetCatalog.categoryCount else {
            return "Unknown"
        }
        return SoundPresetCatalog.displayLabels[index]
    }
    
    /// 기존 12개 볼륨 배열을 받아서 11개로 변환 후 적용
    func applyLegacyPreset(volumes12: [Float], name: String) {
        if volumes12.count == 12 {
            let convertedVolumes = SoundPresetCatalog.convertLegacyVolumes(volumes12)
            applyPreset(volumes: convertedVolumes, name: name)
            print("✅ 12개 → 11개 프리셋 변환 적용: \(name)")
        } else {
            applyPreset(volumes: volumes12, name: name)
        }
    }
    
    /// 현재 11개 볼륨을 12개 형식으로 반환 (기존 시스템과의 호환성)
    func getCurrentVolumesAs12() -> [Float] {
        let current11 = getCurrentVolumes()
        return SoundPresetCatalog.convertToLegacyVolumes(current11)
    }
    
    // MARK: - 재생 상태 관리 (기존 기능 유지)
    
    /// 현재 재생 중인 트랙들의 인덱스 반환
    func getPlayingTracks() -> [Int] {
        var playingTracks: [Int] = []
        for i in 0..<sliders.count {
            if SoundManager.shared.isPlaying(at: i) {
                playingTracks.append(i)
            }
        }
        return playingTracks
    }
    
    /// 특정 볼륨 이상의 트랙들만 재생
    func playTracksAboveVolume(_ minVolume: Float) {
        for i in 0..<sliders.count {
            if sliders[i].value >= minVolume {
                SoundManager.shared.play(at: i)
            }
        }
        updatePlayButtonStates()
    }
    
    /// 모든 볼륨을 특정 비율로 조정
    func adjustAllVolumes(by ratio: Float) {
        for i in 0..<sliders.count {
            let newVolume = min(100, max(0, sliders[i].value * ratio))
            updateSliderAndTextField(at: i, volume: newVolume)
        }
    }
    
    // MARK: - 기존 인터페이스 메서드들 (반드시 유지)
    
    @objc func fadeOutTapped() {
        SoundManager.shared.fadeOutAll()
        
        // UI 업데이트를 위한 타이머
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            self?.updatePlayButtonStates()
            
            // 30초 후 타이머 정리
            DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
                timer.invalidate()
            }
        }
        
        provideMediumHapticFeedback()
        print("🌅 페이드아웃 시작")
    }
    
    /// 볼륨 프리셋 빠른 적용
    @objc func quickVolumePreset(_ sender: UIButton) {
        let presetVolume: Float = Float(sender.tag)  // 버튼 태그를 볼륨으로 사용
        
        for i in 0..<sliders.count {
            if sliders[i].value > 0 {  // 현재 재생 중인 트랙만
                updateSliderAndTextField(at: i, volume: presetVolume)
            }
        }
        
        provideLightHapticFeedback()
        print("⚡ 빠른 볼륨 조정: \(presetVolume)%")
    }
    
    /// 랜덤 프리셋 생성
    @objc func generateRandomPreset() {
        var randomVolumes: [Float] = []
        
        for _ in 0..<SoundPresetCatalog.categoryCount {
            let randomVolume = Float.random(in: 0...100)
            randomVolumes.append(randomVolume)
        }
        
        applyPreset(volumes: randomVolumes, name: "🎲 랜덤 프리셋")
        print("🎲 랜덤 프리셋 생성")
    }
    
    // MARK: - 볼륨 컨트롤 단축키들 (기존 기능)
    
    /// 전체 볼륨 업
    @objc func volumeUpAll() {
        adjustAllVolumes(by: 1.1)  // 10% 증가
        provideLightHapticFeedback()
    }
    
    /// 전체 볼륨 다운
    @objc func volumeDownAll() {
        adjustAllVolumes(by: 0.9)  // 10% 감소
        provideLightHapticFeedback()
    }
    
    /// 전체 볼륨 뮤트/언뮤트
    @objc func muteToggleAll() {
        let hasAnyVolume = sliders.contains { $0.value > 0 }
        
        if hasAnyVolume {
            // 뮤트: 현재 볼륨들을 저장하고 0으로 설정
            let currentVolumes = getCurrentVolumes()
            UserDefaults.standard.set(currentVolumes, forKey: "lastVolumesBeforeMute")
            
            for i in 0..<sliders.count {
                updateSliderAndTextField(at: i, volume: 0)
            }
            print("🔇 전체 뮤트")
        } else {
            // 언뮤트: 저장된 볼륨 복원
            if let savedVolumes = UserDefaults.standard.array(forKey: "lastVolumesBeforeMute") as? [Float] {
                let targetCount = min(savedVolumes.count, sliders.count)
                for i in 0..<targetCount {
                    updateSliderAndTextField(at: i, volume: savedVolumes[i])
                }
            } else {
                // 저장된 볼륨이 없으면 기본값 적용
                let defaultVolumes: [Float] = Array(repeating: 50, count: SoundPresetCatalog.categoryCount)
                updateAllSlidersAndFields(volumes: defaultVolumes)
            }
            print("🔊 전체 언뮤트")
        }
        
        provideMediumHapticFeedback()
    }
    
    // MARK: - 접근성 지원 (기존 기능 확장)
    
    override func accessibilityPerformEscape() -> Bool {
        // 접근성: Escape 제스처로 모든 사운드 정지
        SoundManager.shared.pauseAll()
        updatePlayButtonStates()
        return true
    }
    
    /// VoiceOver 지원을 위한 슬라이더 설명
    func setupAccessibilityLabels() {
        for (index, slider) in sliders.enumerated() {
            let categoryInfo = SoundPresetCatalog.getCategoryInfo(at: index)
            slider.accessibilityLabel = "\(categoryInfo?.emoji ?? "") \(categoryInfo?.name ?? "") 볼륨"
            slider.accessibilityHint = "위아래로 드래그하여 볼륨을 조절하세요"
        }
        
        for (index, button) in playButtons.enumerated() {
            let categoryInfo = SoundPresetCatalog.getCategoryInfo(at: index)
            button.accessibilityLabel = "\(categoryInfo?.emoji ?? "") \(categoryInfo?.name ?? "") 재생"
            button.accessibilityHint = "탭하여 재생 또는 정지"
        }
    }
    
    // MARK: - 상태 저장/복원 (앱 종료 시 현재 상태 유지)
    
    func saveCurrentState() {
        let currentVolumes = getCurrentVolumes()
        let currentVersions = getCurrentVersions()
        let isPlaying = SoundManager.shared.isPlaying
        
        UserDefaults.standard.set(currentVolumes, forKey: "lastSessionVolumes")
        UserDefaults.standard.set(currentVersions, forKey: "lastSessionVersions")
        UserDefaults.standard.set(isPlaying, forKey: "lastSessionPlaying")
        
        print("💾 현재 상태 저장 완료")
    }
    
    func restoreLastState() {
        guard let savedVolumes = UserDefaults.standard.array(forKey: "lastSessionVolumes") as? [Float],
              let savedVersions = UserDefaults.standard.array(forKey: "lastSessionVersions") as? [Int] else {
            print("ℹ️ 복원할 세션 상태 없음")
            return
        }
        
        let wasPlaying = UserDefaults.standard.bool(forKey: "lastSessionPlaying")
        
        // 상태 복원
        updateAllSlidersAndFields(volumes: savedVolumes, versions: savedVersions)
        
        if wasPlaying {
            // 0.5초 후 재생 시작 (초기화 완료 후)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                SoundManager.shared.playAll()
                self.updatePlayButtonStates()
            }
        }
        
        print("🔄 세션 상태 복원 완료")
    }
    
    // MARK: - 앱 생명주기 연동
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopPlaybackStateMonitoring()
        saveCurrentState()  // 앱이 백그라운드로 가거나 종료될 때 상태 저장
    }
    
    private func isFirstLaunch() -> Bool {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if !hasLaunchedBefore {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            return true
        }
        return false
    }
    
    // MARK: - 오류 처리 및 복구
    
    func handleSoundManagerError() {
        // SoundManager 오류 시 복구 로직
        print("⚠️ SoundManager 오류 감지, 복구 시도...")
        
        // 모든 플레이어 정지
        SoundManager.shared.stopAll()
        
        // UI 상태 초기화
        for i in 0..<sliders.count {
            sliders[i].value = 0
            volumeFields[i].text = "0"
        }
        updatePlayButtonStates()
        
        // 사용자에게 알림
        let alert = UIAlertController(title: "오디오 오류", message: "오디오 시스템을 다시 시작합니다.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    #if DEBUG
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            // 디버그 메뉴 표시
            showDebugMenu()
        }
    }
    
    private func showDebugMenu() {
        let alert = UIAlertController(title: "🐛 디버그 메뉴", message: "개발용 기능", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "📊 카테고리 정보 출력", style: .default) { _ in
            SoundPresetCatalog.printSampleData()
        })
        
        alert.addAction(UIAlertAction(title: "🔄 샘플 프리셋 적용", style: .default) { [weak self] _ in
            self?.applySamplePreset()
        })
        
        alert.addAction(UIAlertAction(title: "🎵 모든 사운드 테스트", style: .default) { [weak self] _ in
            self?.testAllSounds()
        })
        
        alert.addAction(UIAlertAction(title: "💾 상태 저장 테스트", style: .default) { [weak self] _ in
            self?.saveCurrentState()
        })
        
        alert.addAction(UIAlertAction(title: "🔄 상태 복원 테스트", style: .default) { [weak self] _ in
            self?.restoreLastState()
        })
        
        alert.addAction(UIAlertAction(title: "🎲 랜덤 프리셋", style: .default) { [weak self] _ in
            self?.generateRandomPreset()
        })
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func applySamplePreset() {
        let samplePresets = SoundPresetCatalog.samplePresets
        let randomPreset = samplePresets.randomElement()!
        applyPreset(volumes: randomPreset.value, name: randomPreset.key)
        print("🎲 랜덤 샘플 프리셋 적용: \(randomPreset.key)")
    }
    
    private func testAllSounds() {
        let testVolumes: [Float] = Array(repeating: 30, count: SoundPresetCatalog.categoryCount)
        applyPreset(volumes: testVolumes, name: "🧪 테스트 모드")
        print("🧪 모든 사운드 30% 볼륨으로 테스트")
    }
    #endif
}

// MARK: - Extension에서 구현되는 메서드들은 실제 Extension에서만 정의됨
// ViewController+SliderControls.swift, ViewController+PlaybackControls.swift 등에서 구현됨
