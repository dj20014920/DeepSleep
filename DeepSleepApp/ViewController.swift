import UIKit
import AVFoundation
import MediaPlayer

class ViewController: UIViewController {
    
    let instanceUUID = UUID().uuidString // 각 인스턴스에 고유 ID 부여
    
    // 구독 UI 바인더/배지
    private var subscriptionBinder: SubscriptionUIBinder?
    private var subscriptionBadge: PremiumBadgeView?
    // 해시태그 버튼 레퍼런스(정렬용)
    var hashtagButtonRef: UIButton?

    // AdMob 배너 호스트(탭바를 가리지 않고 그 위에 표시)
    private var adsBannerContainer: BannerAdContainerView?
    private var hasLoadedBannerOnce = false
    
    // MARK: - Properties (13개 카테고리로 업데이트)
    
    /// 새로운 13개 이모지 라벨 (기존 A-L 대신)
    var categoryLabels: [String] {
        return SoundPresetCatalog.displayLabels
    }
    
    ///  슬라이더 라벨
    @available(*, deprecated, message: "Use categoryLabels instead")
    let sliderLabels = Array("ABCDEFGHIJKLM")  // 13개로 변경
    
    // TODO: 감정 이모지 제거됨 - 감정 일기 탭에서 통합 관리
    // let emojis = ["😴","😢","😠","😊","😔","😐"]
    
    /// UI 요소들 (13개 카테고리)
    var sliders: [UISlider] = []
    var volumeFields: [UITextField] = []
    var playButtons: [UIButton] = []
    var previewSeekSliders: [UISlider] = [] // 미리듣기 탐색 슬라이더들
    
    // 프리셋 블록 UI 요소들 (기존 유지)
    var recentPresetButtons: [UIButton] = []
    var favoritePresetButtons: [UIButton] = []
    var presetStackView: UIStackView!
    
    // 프리셋 업데이트 디바운싱을 위한 타이머
    var updateTimer: Timer?
    
    // 실시간 재생 상태 모니터링 (기존 유지)
    var playbackMonitorTimer: Timer?
    
    // 현재 미리듣기 상태
    var currentlyPreviewingIndex: Int? = nil
    var previewSliderUpdateTimer: Timer?

    var globalVolume: Float = 0.75 // 기본 글로벌 볼륨 (0.0 ~ 1.0) - 0.01에서 0.75로 변경
    
    // 🆕 초기화 상태 추적 플래그들
    private var hasCompletedInitialSetup: Bool = false
    private var hasPerformedDelayedInit: Bool = false
    
    // 오디오 모드 버튼
    var audioModeButton: UIButton!
    
    // 마스터 볼륨 컨트롤
    var masterVolumeSlider: UISlider!
    var masterVolumeField: UITextField!
    internal var masterVolumeLevel: Float = 50.0  // 마스터 볼륨 레벨 (0-100), 기본값 50

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // ViewController 초기화
        
        // 🚀 1단계: 필수 UI만 먼저 설정 (즉시)
        setupCriticalUI()
        
        // 🚀 2단계: 나머지 초기화는 백그라운드에서 비동기 처리
        Task {
            await performAsyncInitialization()
        }
        
        // 🚀 3단계: 지연 로딩 항목들은 viewDidAppear에서 처리
        // (별도 메서드로 이동)
    }
    
    // MARK: - 🚀 성능 최적화: 단계별 초기화
    
    /// 1단계: 즉시 필요한 최소한의 UI만 설정
    private func setupCriticalUI() {
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        configureNavBar()
        
        // Trial 배지 제거됨 - 구독 상태 수신은 유지
        setupTrialBadge()

        // 광고 배너 호스트(높이 0으로 시작, 탭바 바로 위에 고정)
        setupAdsBannerContainer()
        
        // 기본 슬라이더만 먼저 표시 (데이터 로딩 없이)
        setupBasicSliderUI()
        
        // 필수 UI 설정 완료
    }
    
    /// 2단계: 백그라운드에서 비동기 초기화
    @MainActor
    private func performAsyncInitialization() async {
        // 데이터 검증 (백그라운드)
        await Task.detached { [weak self] in
            // SoundPresetCatalog 카테고리 로드됨
            
            // 마이그레이션 실행 (백그라운드)
LegacyPresetManager.shared.migrateLegacyPresetsIfNeeded()
            
            await MainActor.run { [weak self] in
                self?.setupKeyboardNotifications()
                self?.setupNotifications()
                // 백그라운드 초기화 완료
            }
        }.value
        
        // UI 업데이트는 메인 스레드에서
        setupInitialState()
    }
    
    /// 3단계: 지연 로딩 (viewDidAppear에서 호출)
    private func performDelayedInitialization() {
        // 지연 초기화 시작
        
        // 🆕 애플워치 헬스킷 초기화 (지연)
        Task {
            await setupHealthKitIfNeeded()
        }
        
        // 프리셋 블록 업데이트 (지연)
        Task {
            await MainActor.run {
                setupPresetBlocks()
                updatePresetBlocks()
            }
        }
        
        // 🆕 온디바이스 학습은 앱 시작 후 5분 후에만 실행 (성능 최적화)
        let lastLearningTime = UserDefaults.standard.double(forKey: "lastOnDeviceLearningTime")
        let now = Date().timeIntervalSince1970
        let fiveMinutes = 5 * 60.0
        
        if now - lastLearningTime > fiveMinutes {
            Task {
                await checkAndTriggerOnDeviceLearning()
                // 학습 시간 업데이트
                UserDefaults.standard.set(now, forKey: "lastOnDeviceLearningTime")
            }
            // 온디바이스 학습 스케줄됨
        } else {
            // 온디바이스 학습 스킵
        }
        
        // 지연 초기화 완료
    }
    
    private func setupTrialBadge() {
        // 구독 상태 변경 수신 유지 - 네비게이션 바 배지 업데이트에 사용
        subscriptionBinder = SubscriptionUIBinder.attach(to: self) { [weak self] _ in
            self?.updateSubscriptionBadge()
        }
        setupNavBarSubscriptionBadge()
    }
    
    private func setupNavBarSubscriptionBadge() {
        // 네비게이션 바 중앙에 강화된 배지 설정
        let badge = PremiumBadgeView()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.isUserInteractionEnabled = true
        
        // 패딩을 위한 컨테이너 뷰
        let container = UIView()
        container.addSubview(badge)
        
        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            badge.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            badge.topAnchor.constraint(equalTo: container.topAnchor),
            badge.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            badge.heightAnchor.constraint(equalToConstant: 32),
            badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
        
        // 탭 제스처 추가
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(presentSubscriptionTierSelection))
        badge.addGestureRecognizer(tapGesture)
        
        self.subscriptionBadge = badge
        navigationItem.titleView = container
        
        // 초기 상태 업데이트
        updateSubscriptionBadge()
    }
    
    private func updateSubscriptionBadge() {
        guard let badge = subscriptionBadge else { return }
        
        // 사운드 탭에서만 표시
        let isSoundTab = (tabBarController?.selectedIndex == 0) || (tabBarController == nil)
        
        if isSoundTab {
            // 구독 상태에 따른 배지 업데이트
            let badgeState = PremiumBadgeView.determineBadgeState()
            badge.updateState(badgeState)
            badge.isHidden = false
            navigationItem.titleView?.isHidden = false
        } else {
            badge.isHidden = true
            navigationItem.titleView?.isHidden = true
        }
    }
    
    @objc private func presentSubscriptionTierSelection() {
        // 햅틱 피드백
        provideLightHapticFeedback()
        
        #if DEBUG
        print("🎯 Trial badge tapped - presenting subscription tier selection")
        #endif
        
        let tierVC = SubscriptionTierSelectionViewController()
        let nav = UINavigationController(rootViewController: tierVC)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }
    
    /// 기본 슬라이더 UI만 설정 (데이터 로딩 최소화)
    private func setupBasicSliderUI() {
        // 슬라이더만 기본값으로 빠르게 표시
        setupSliderUI()
        
        // AI 채팅 진입을 위한 해시태그 버튼 (이모지는 제거)
        Task { @MainActor in
            setupHashtagButton()
        }
    }
    
    // MARK: - 프리셋 마이그레이션
    private func migratePresets() {
        // 통합된 프리셋 마이그레이션 (12개 → 11개 + 버전 정보 추가)
LegacyPresetManager.shared.migrateLegacyPresetsIfNeeded()
        
        print("✅ 프리셋 마이그레이션 완료")
    }
    
    // MARK: - viewWillAppear 중복 제거 - Extension에서 처리
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // viewWillAppear 호출됨
        
        updatePlayButtonStates()
        startPlaybackStateMonitoring()
        
        // 🆕 프리셋 블록 업데이트는 초기화 완료 후에만
        if hasCompletedInitialSetup {
            updatePresetBlocks()
        }
        
        // 네비게이션 바 배지 업데이트
        updateSubscriptionBadge()
        
        updateAudioModeButtonTitle() // 오디오 모드 버튼 제목 업데이트
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // viewDidAppear 호출됨
        
        // ✅ 카테고리 버튼 UI 업데이트 (저장된 버전 정보 반영)
        updateAllCategoryButtonTitles()
        
        startPlaybackStateMonitoring()
        
        // 🚀 지연 초기화는 최초 1회만 실행
        if !hasPerformedDelayedInit {
            hasPerformedDelayedInit = true
            // 지연 초기화 최초 실행
            performDelayedInitialization()
        } else {
            print("🔄 [ViewController] 지연 초기화 이미 완료됨 - 스킵")
        }
        
        // 🆕 초기화 완료 플래그 설정
        hasCompletedInitialSetup = true

        // 광고 배너는 화면 표시 후 1회만 로드(중복 로드 방지)
        if !hasLoadedBannerOnce {
            hasLoadedBannerOnce = true
            adsBannerContainer?.loadBanner(in: self)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPlaybackStateMonitoring()
    }

    deinit {
        // 명시적으로 특정 옵저버만 제거 (안전성 향상)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ApplyPresetFromChat"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("SoundVolumesUpdated"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("LocalPresetApplied"), object: nil)
        NotificationCenter.default.removeObserver(self, name: .modelUpdated, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RecentPresetsUpdated"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("FavoritesUpdated"), object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        stopPlaybackStateMonitoring()
        
        #if DEBUG
        print("🗑️ ViewController [\(instanceUUID)] 메모리 해제됨")
        #endif
    }

    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        configureNavBar()
        
        // ✅ 필수 UI 초기화 추가
        setupHashtagButton()  // AI 채팅 진입점
        setupSliderUI()
        setupPresetBlocks()
        setupNotifications()
        setupGestures()
        
        print("✅ ViewController UI 설정 완료")
    }
    
    private func setupInitialState() {
        // 초기 상태 설정
        updatePlayButtonStates()
        updateAllCategoryButtonTitles()
        updateAllVersionButtons()
        updatePresetBlocks()
        // ViewController 초기 상태 설정 완료
    }
    
    private func setupKeyboardNotifications() {
        // 키보드 알림 설정
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
    
    private func configureNavBar() {
        // 왼쪽: 타이머
        let timerItem = UIBarButtonItem(title: "타이머", style: .plain, target: self, action: #selector(showTimer))
        timerItem.tintColor = UIDesignSystem.Colors.primaryText
        
        // 오른쪽: 저장 + 프리셋  
        let saveItem = UIBarButtonItem(title: "저장", style: .plain, target: self, action: #selector(savePresetTapped))
        saveItem.tintColor = UIDesignSystem.Colors.primaryText
        
        let presetItem = UIBarButtonItem(title: "프리셋", style: .plain, target: self, action: #selector(loadPresetTapped))
        presetItem.tintColor = UIDesignSystem.Colors.primaryText
        
        navigationItem.leftBarButtonItems = [timerItem]
        navigationItem.rightBarButtonItems = [saveItem, presetItem]
        
        // 중앙: 구독 배지는 setupTrialBadge()에서 설정됨
    }
    
    private func setupNotifications() {
        // 채팅에서 프리셋 적용 요청 받기
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplyPresetFromChat(_:)),
            name: NSNotification.Name("ApplyPresetFromChat"),
            object: nil
        )
        
        // 외부에서 로컬 프리셋 적용 알림 받기 (채팅 → 메인 뷰)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocalPresetApplied(_:)),
            name: NSNotification.Name("LocalPresetApplied"),
            object: nil
        )
        
        // SoundManager 볼륨 변경 동기화
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSoundVolumesUpdated(_:)),
            name: NSNotification.Name("SoundVolumesUpdated"),
            object: nil
        )
        
        // 감정 분석 모델 업데이트 알림
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleModelUpdated),
            name: .modelUpdated,
            object: nil
        )
        
        // ✅ 최근 사용한 프리셋 갱신 알림 받기
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRecentPresetsUpdated),
            name: NSNotification.Name("RecentPresetsUpdated"),
            object: nil
        )
        
        // ✅ 즐겨찾기 프리셋 갱신 알림 받기
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFavoritesUpdated),
            name: NSNotification.Name("FavoritesUpdated"),
            object: nil
        )
        
        // 알림 옵저버 설정 완료
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
            let convertedVolumes = volumes12.count == 13 ? volumes12 : Array(repeating: 0.0, count: 13)
            // 레거시 프리셋은 기본 버전을 사용하거나, 별도의 버전 변환 로직이 필요할 수 있음
            // 여기서는 nil을 전달하여 applyPreset 내부에서 기본값을 사용하도록 함
            applyPreset(volumes: convertedVolumes, versions: nil, name: name)
            print("✅ 12개 → 11개 프리셋 변환 적용: \(name)")
        } else {
            // 12개가 아닌 다른 개수의 레거시 볼륨은 버전 정보 없이 적용 시도
            applyPreset(volumes: volumes12, versions: nil, name: name)
        }
    }
    
    /// 현재 11개 볼륨을 12개 형식으로 반환 (기존 시스템과의 호환성)
    func getCurrentVolumesAs12() -> [Float] {
        let current11 = getCurrentVolumes()
        return current11.count == 13 ? current11 : Array(repeating: 0.0, count: 12)
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
        SoundManager.shared.pauseAll()
        // UI 업데이트를 위한 타이머 (메모리 누수 방지)
        let fadeOutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            self.updatePlayButtonStates()
        }
        
        // 30초 후 타이머 정리 (메모리 누수 방지)
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak fadeOutTimer] in
            fadeOutTimer?.invalidate()
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
        
        // 랜덤 프리셋은 모든 카테고리의 기본 버전을 사용
        applyPreset(volumes: randomVolumes, versions: SoundPresetCatalog.defaultVersions, name: "🎲 랜덤 프리셋")
        print("✅ 랜덤 프리셋 생성")
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
    
    // MARK: - 광고 배너 배치 및 콘텐츠 하단 앵커 제공
    private func setupAdsBannerContainer() {
        let banner = BannerAdContainerView()
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            banner.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        self.adsBannerContainer = banner
    }

    /// 배너가 존재하면 그 상단을, 없으면 기본 안전영역 하단을 반환
    internal func contentBottomAnchor() -> NSLayoutYAxisAnchor {
        return adsBannerContainer?.topAnchor ?? view.safeAreaLayoutGuide.bottomAnchor
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
            print("✅ 모든 샘플 프리셋: \(SoundPresetCatalog.samplePresets.keys.joined(separator: ", "))")
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
        guard let randomPreset = samplePresets.randomElement() else { return }
        // 샘플 프리셋의 경우, SoundPresetCatalog에 버전 정보가 있다면 가져오고, 없다면 기본값 사용
        // 현재 SoundPresetCatalog.samplePresets는 볼륨 정보만 있으므로 기본 버전 사용
        applyPreset(volumes: randomPreset.value, versions: SoundPresetCatalog.defaultVersions, name: randomPreset.key)
        print("🎲 랜덤 샘플 프리셋 적용: \(randomPreset.key)")
    }
    
    private func testAllSounds() {
        let testVolumes: [Float] = Array(repeating: 30, count: SoundPresetCatalog.categoryCount)
        // 모든 사운드 테스트는 기본 버전을 사용
        applyPreset(volumes: testVolumes, versions: SoundPresetCatalog.defaultVersions, name: "🧪 테스트 모드")
        print("🧪 모든 사운드 30% 볼륨으로 테스트")
    }
    #endif
    
    // "일기" 버튼 클릭 시 EmotionDiaryViewController (또는 메인 일기 화면 컨트롤러)를 표시하도록 수정
    @objc func showDiary() {
        // EmotionDiaryViewController의 실제 클래스 이름으로 변경해야 할 수 있습니다.
        let diaryVC = EmotionDiaryViewController() 
        // diaryVC.title = "감정 일기" // 필요에 따라 타이틀 설정
        navigationController?.pushViewController(diaryVC, animated: true)
        provideLightHapticFeedback()
    }

    // MARK: - Notification Handlers
    @objc private func handleApplyPresetFromChat(_ notification: Notification) {
        print("🎵 ViewController [\(self.instanceUUID)] received ApplyPresetFromChat notification.")

        guard let userInfo = notification.userInfo else {
            print("⚠️ [ViewController [\(self.instanceUUID)]] ApplyPresetFromChat 알림 수신 오류: userInfo 없음")
            return
        }
        
        // 모든 key 조합 허용 (이전/신규 모두)
        let volumes = userInfo["volumes"] as? [Float]
        let presetName = userInfo["presetName"] as? String ?? userInfo["name"] as? String
        let selectedVersions = userInfo["selectedVersions"] as? [Int] ?? userInfo["versions"] as? [Int]

        guard let volumes = volumes, let presetName = presetName, let selectedVersions = selectedVersions else {
            print("⚠️ [ViewController [\(self.instanceUUID)]] ApplyPresetFromChat 알림 수신 오류: userInfo 파싱 실패. Info: \(String(describing: notification.userInfo))")
            DispatchQueue.main.async {
                print("Error: Toast - Preset application failed due to userInfo parsing. (Instance: \(self.instanceUUID))")
            }
            return
        }

        print("🎵 [ViewController [\(self.instanceUUID)]] ApplyPresetFromChat 알림 수신 성공: \(presetName)")
        let threadInfo = Thread.isMainThread ? "Main Thread" : "Background Thread"
        print("  - Instance: \(self.instanceUUID)")
        print("  - 알림 수신 스레드: \(threadInfo)")
        print("  - Volumes: \(volumes)")
        print("  - Selected Versions: \(selectedVersions)")

        DispatchQueue.main.async { [weak self] in 
            guard let strongSelf = self else {
                print("  [ViewController] self is nil before calling applyPreset on main thread. Aborting for preset: \(presetName).")
                return
            }
            print("  [ViewController [\(strongSelf.instanceUUID)]] 메인 스레드에서 applyPreset 호출 예정: \(presetName)")
            strongSelf.applyPreset(volumes: volumes, versions: selectedVersions, name: presetName)
            strongSelf.switchToMainSoundTab()
        }
    }

    private func switchToMainSoundTab(attempt: Int = 0) {
        print("👍 [ViewController] switchToMainSoundTab - tabBarController: \(String(describing: self.tabBarController)), navigationController: \(String(describing: self.navigationController)), parent: \(String(describing: self.parent)), presentingViewController: \(String(describing: self.presentingViewController))")
        let currentInstanceUUID = self.instanceUUID // 현재 함수의 UUID도 로깅
        if let tabBarController = self.tabBarController {
            if tabBarController.selectedIndex != 0 {
                print("  [ViewController [\(currentInstanceUUID)]] 메인 사운드 탭(0번)으로 전환합니다.")
                tabBarController.selectedIndex = 0
            } else {
                print("  [ViewController [\(currentInstanceUUID)]] 이미 메인 사운드 탭(0번)입니다.")
            }
        } else {
            if attempt < 5 { // 최대 5번 (0.5초) 시도
                print("  [ViewController [\(currentInstanceUUID)]] TabBarController를 찾을 수 없습니다. (시도: \(attempt + 1)) 0.1초 후 재시도합니다.")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.switchToMainSoundTab(attempt: attempt + 1)
                }
            } else {
                print("  [ViewController [\(currentInstanceUUID)]] TabBarController를 여러 번 시도했지만 찾을 수 없었습니다.")
            }
        }
    }

    // MARK: - 오디오 모드 관리
    
    /// 오디오 모드 버튼 제목 업데이트
    func updateAudioModeButtonTitle() {
        let currentMode = SoundManager.shared.audioPlaybackMode
        audioModeButton.setTitle(currentMode.displayName, for: .normal)
        audioModeButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
    }
    
    /// 오디오 모드 선택 버튼 액션
    @objc func audioModeButtonTapped() {
        showAudioModeSelectionAlert()
    }
    
    /// 오디오 모드 선택 액션 시트 표시
    func showAudioModeSelectionAlert() {
        let alertController = UIAlertController(
            title: "🔊 오디오 재생 모드 선택",
            message: "원하는 재생 방식을 선택해주세요",
            preferredStyle: .actionSheet
        )
        
        // 각 모드별 액션 추가
        for mode in AudioPlaybackMode.allCases {
            let action = UIAlertAction(title: mode.displayName, style: .default) { [weak self] _ in
                self?.selectAudioMode(mode)
            }
            
            // 현재 선택된 모드 표시
            if mode == SoundManager.shared.audioPlaybackMode {
                action.setValue(UIImage(systemName: "checkmark"), forKey: "image")
            }
            
            alertController.addAction(action)
        }
        
        // 취소 버튼
        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))
        
        // iPad 지원
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = audioModeButton
            popover.sourceRect = audioModeButton.bounds
        }
        
        present(alertController, animated: true)
    }
    
    /// 선택된 오디오 모드로 변경
    func selectAudioMode(_ mode: AudioPlaybackMode) {
        // 모드 상세 설명 표시
        showModeDescriptionAlert(mode: mode) { [weak self] in
            // 사용자가 확인을 누르면 모드 변경
            SoundManager.shared.setAudioPlaybackMode(mode)
            self?.updateAudioModeButtonTitle()
            self?.provideMediumHapticFeedback()
            
            let feedbackMessage = "\(mode.displayName) 모드가 적용되었습니다"
            if let sliderExt = self as? ViewController {
                sliderExt.showToast(message: feedbackMessage)
            }
        }
    }
    
    /// 모드 상세 설명 알림 표시
    func showModeDescriptionAlert(mode: AudioPlaybackMode, completion: @escaping () -> Void) {
        let alertController = UIAlertController(
            title: "🎵 \(mode.displayName)",
            message: mode.description,
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(title: "적용", style: .default) { _ in
            completion()
        })
        
        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))
        
        present(alertController, animated: true)
    }

    // 🆕 사운드 볼륨 업데이트 핸들러
    @objc private func handleSoundVolumesUpdated(_ notification: Notification) {
        guard let volumes = notification.userInfo?["volumes"] as? [Float] else { return }
        
        applyPreset(volumes: volumes, name: "실시간 조절")
    }
    
    // 🆕 ChatViewController fallback 프리셋 적용 핸들러
    @objc private func handlePresetAppliedFromChat(_ notification: Notification) {
        print("🎵 ViewController [\(self.instanceUUID)] received PresetAppliedFromChat notification (fallback)")
        
        guard let userInfo = notification.userInfo,
              let volumes = userInfo["volumes"] as? [Float],
              let versions = userInfo["versions"] as? [Int],
              let name = userInfo["name"] as? String else {
            print("⚠️ [ViewController [\(self.instanceUUID)]] PresetAppliedFromChat 알림 수신 오류: userInfo 파싱 실패")
            return
        }
        
        print("🎵 [ViewController [\(self.instanceUUID)]] PresetAppliedFromChat 알림 수신 성공: \(name)")
        print("  - 볼륨: \(volumes)")
        print("  - 버전: \(versions)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 직접 UI 업데이트 (이미 SoundManager에 적용되어 있음)
            self.updateAllSlidersAndFields(volumes: volumes, versions: versions)
            self.updatePlayButtonStates()
            self.updatePresetBlocks() // 최근 프리셋 UI 갱신
            
            // 메인 탭으로 이동
            if let tabBarController = self.tabBarController {
                tabBarController.selectedIndex = 0
            }
            
            print("🔄 [ViewController [\(self.instanceUUID)]] Fallback UI 업데이트 완료: \(name)")
        }
    }
    
    // 🆕 로컬 추천 프리셋 적용 알림 처리
    @objc private func handleLocalPresetApplied(_ notification: Notification) {
        print("🏠 ViewController [\(self.instanceUUID)] received LocalPresetApplied notification")
        
        guard let userInfo = notification.userInfo,
              let volumes = userInfo["volumes"] as? [Float],
              let versions = userInfo["versions"] as? [Int],
              let name = userInfo["name"] as? String else {
            print("⚠️ [ViewController [\(self.instanceUUID)]] LocalPresetApplied 알림 수신 오류: userInfo 파싱 실패")
            return
        }
        
        print("🏠 [ViewController [\(self.instanceUUID)]] LocalPresetApplied 알림 수신 성공: \(name)")
        print("  - 볼륨: \(volumes)")
        print("  - 버전: \(versions)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // ✅ 프리셋 이름으로 실제 프리셋을 찾아서 ID 가져오기
            let allPresets = SettingsManager.shared.loadSoundPresets()
            if let foundPreset = allPresets.first(where: { $0.name == name }) {
                SettingsManager.shared.updatePresetTimestamp(id: foundPreset.id)
                print("  - 프리셋 ID \(foundPreset.id.uuidString)의 사용 시간 갱신 완료")
            } else {
                print("  - 프리셋 '\(name)'을 찾을 수 없어 사용 시간 갱신 생략")
            }
            
            applyPreset(
                volumes: volumes,
                versions: versions,
                name: name
            )
            
            // UI 업데이트 (이미 SoundManager에 적용되어 있음)
            self.updateAllSlidersAndFields(volumes: volumes, versions: versions)
            self.updatePlayButtonStates()
            self.updateAllCategoryButtonTitles() // 버전 정보 반영
            self.updatePresetBlocks() // 최근 프리셋 UI 갱신
            
            // 메인 탭으로 이동
            if let tabBarController = self.tabBarController {
                tabBarController.selectedIndex = 0
                print("🏠 메인 탭으로 이동 완료")
            }
            
            // 피드백
            self.showToast(message: "  앱 분석 추천 '\(name)' 적용됨. ")
            self.provideMediumHapticFeedback()
            
            print("🔄 [ViewController [\(self.instanceUUID)]] 로컬 추천 UI 업데이트 완료: \(name)")
        }
    }
    
    // 🆕 SoundManager의 현재 볼륨 및 버전으로 UI 업데이트
    private func refreshSlidersFromSoundManager() {
        for i in 0..<sliders.count {
            let currentVolume = SoundManager.shared.getVolume(for: i) // 0.0~1.0 범위
            let volumeAsPercent = currentVolume * 100  // 0~100 범위로 변환
            
            // 🔧 슬라이더와 텍스트필드 모두 업데이트
            sliders[i].value = volumeAsPercent
            volumeFields[i].text = String(Int(volumeAsPercent))
        }
        
        // 🔧 버전 버튼도 함께 업데이트
        updateAllVersionButtons()
        
        print("🔄 메인 화면 슬라이더 및 버전 버튼 업데이트 완료")
    }
    
    // 🆕 모든 버전 버튼 업데이트 (기존 updateAllCategoryButtonTitles 방식 사용)
    private func updateAllVersionButtons() {
        // 기존 ViewController+SliderControls.swift의 updateAllCategoryButtonTitles() 호출
        updateAllCategoryButtonTitles()
        // 모든 버전 버튼 업데이트 완료
    }

    @objc private func handleFavoritesUpdated() {
        print("📢 [ViewController] 즐겨찾기 업데이트 알림 수신")
        updatePresetBlocks()
    }

    @objc private func handlePresetBlocksUpdate() {
        print("📢 [ViewController] 프리셋 블록 업데이트 알림 수신")
        updatePresetBlocks()
    }

    // MARK: - Phase 4: 온디바이스 학습 자동 트리거

    /// 온디바이스 학습 조건 검사 및 자동 트리거
    @MainActor
    private func checkAndTriggerOnDeviceLearning() async {
        // 온디바이스 학습 조건 검사 (추후 구현 예정)
    }

    // 🆕 온디바이스 학습 모델 업데이트 완료 알림 옵저버 처리
    @objc private func handleModelUpdated() {
        print("🎉 [Auto Learning] 온디바이스 학습 모델 업데이트 완료")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let currentVolumes = self.getCurrentVolumes()
            let currentVersions = self.getCurrentVersions()
            
            self.updateAllSlidersAndFields(volumes: currentVolumes, versions: currentVersions)
            self.updatePlayButtonStates()
            self.updatePresetBlocks()
            self.updateAllCategoryButtonTitles()
            self.updateAllVersionButtons()
            
            // 메인 탭으로 이동
            if let tabBarController = self.tabBarController {
                tabBarController.selectedIndex = 0
                print("🏠 메인 탭으로 이동 완료")
            }
            
            // 피드백
            self.provideMediumHapticFeedback()
            
            print("🔄 [ViewController [\(self.instanceUUID)] 로컬 추천 UI 업데이트 완료")
        }
    }
    
    // ✅ 최근 사용한 프리셋 갱신 처리
    @objc private func handleRecentPresetsUpdated() {
        print("🔄 [ViewController [\(self.instanceUUID)]] 최근 사용한 프리셋 갱신 알림 수신")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updatePresetBlocks()
            print("✅ [ViewController [\(self.instanceUUID)]] 최근 사용한 프리셋 UI 갱신 완료")
        }
    }
}
