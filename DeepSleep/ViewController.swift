import UIKit
import AVFoundation
import MediaPlayer

class ViewController: UIViewController {
    
    // MARK: - Properties
    let sliderLabels = Array("ABCDEFGHIJKL")
    let emojis = ["😊","😢","😠","😰","😴"]
    var sliders: [UISlider] = []
    var volumeFields: [UITextField] = []
    var playButtons: [UIButton] = []
    
    // 프리셋 블록 UI 요소들
    var recentPresetButtons: [UIButton] = []
    var favoritePresetButtons: [UIButton] = []
    var presetStackView: UIStackView!
    
    // 실시간 재생 상태 모니터링
    var playbackMonitorTimer: Timer?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 기존 프리셋 데이터 마이그레이션 (앱 시작 시 한 번만 실행)
        PresetManager.shared.migrateLegacyPresetsIfNeeded()
        
        setupViewController()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updatePresetBlocks()
    }
    
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
}
