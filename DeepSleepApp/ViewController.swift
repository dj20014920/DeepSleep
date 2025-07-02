import UIKit
import AVFoundation
import MediaPlayer
import CoreData
import Combine

class MainViewController: UIViewController {
    
    // MARK: - Properties
    
    let instanceUUID = UUID().uuidString
    
    private var hasCompletedInitialSetup: Bool = false
    private var hasPerformedDelayedInit: Bool = false

    var persistentContainer: NSPersistentContainer? {
        (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer
    }

    // MARK: - Lifecycle & Staged Initialization
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("✅ ViewController [\(instanceUUID)] viewDidLoad.")
        setupUI()
        setupNotificationObserver()
        Task { await performAsyncInitialization() }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        print("🗑️ ViewController [\(instanceUUID)] deinit, Notification Observer 제거.")
    }

    
    
    @MainActor
    private func performAsyncInitialization() async {
        await Task.detached { PresetManager.shared.migrateLegacyPresetsIfNeeded() }.value
        restoreLastState()
    }
    

    // MARK: - Setup
    
    func setupUI() {
        view.backgroundColor = .systemBackground
        
        let titleLabel = UILabel()
        titleLabel.text = "#Todays_Moods"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        let emojiStackView = UIStackView()
        emojiStackView.axis = .vertical
        emojiStackView.spacing = 16
        emojiStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emojiStackView)
        
        let emojis = [
            ["😊", "😄", "😂", "😍"],
            ["😢", "😭", "😡", "😠"],
            ["😴", "🤯", "🤔", "😱"]
        ]
        
        for row in emojis {
            let rowStackView = UIStackView()
            rowStackView.axis = .horizontal
            rowStackView.spacing = 16
            rowStackView.distribution = .fillEqually
            
            for emoji in row {
                let button = UIButton(type: .system)
                button.setTitle(emoji, for: .normal)
                button.titleLabel?.font = .systemFont(ofSize: 48)
                button.addTarget(self, action: #selector(emojiTapped(_:)), for: .touchUpInside)
                rowStackView.addArrangedSubview(button)
            }
            emojiStackView.addArrangedSubview(rowStackView)
        }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            emojiStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            emojiStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            emojiStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    @objc func emojiTapped(_ sender: UIButton) {
        guard let emoji = sender.title(for: .normal) else { return }
        
        let chatVC = ChatViewController()
        chatVC.initialUserText = "오늘 내 기분은 \(emoji)이야."
        navigationController?.pushViewController(chatVC, animated: true)
    }
    
    func restoreLastState() {
        // 이전에 저장된 상태를 복원하는 코드를 여기에 추가하세요.
    }

    // MARK: - Notification Handling
    
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(presetDidChange(_:)),
            name: .PresetChanged,
            object: nil
        )
    }
    
    @objc private func presetDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let presetName = userInfo["presetName"] as? String else {
            return
        }
        
        print("🔔 [MainViewController] PresetChanged 알림 수신: \(presetName)")
        DispatchQueue.main.async {
            self.title = "Now Playing: \(presetName)"
        }
    }

    // MARK: - Preset Management
    
    func applyPreset(
        presetId: String?,
        presetName: String?,
        soundIds: [String]?,
        volumes: [Float]?,
        completion: ((Bool) -> Void)? = nil
    ) {
        // 프리셋 적용 로직
        if let presetId = presetId, let volumes = volumes {
            SoundManager.shared.applyPreset(presetId: presetId, volumes: volumes) { success in
                DispatchQueue.main.async {
                    if success {
                        NotificationCenter.default.post(
                            name: .PresetChanged,
                            object: nil,
                            userInfo: ["presetName": presetName ?? "Unknown"]
                        )
                    }
                    completion?(success)
                }
            }
        } else if let soundIds = soundIds, let volumes = volumes {
            // 개별 사운드 적용
            SoundManager.shared.applySounds(soundIds: soundIds, volumes: volumes) { success in
                DispatchQueue.main.async {
                    if success {
                        NotificationCenter.default.post(
                            name: .PresetChanged,
                            object: nil,
                            userInfo: ["presetName": presetName ?? "Custom"]
                        )
                    }
                    completion?(success)
                }
            }
        } else {
            completion?(false)
        }
    }
}