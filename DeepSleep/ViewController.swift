import UIKit
import AVFoundation        // AVAudioSession
import MediaPlayer         // MPRemoteCommandCenter, MPNowPlayingInfoCenter

class ViewController: UIViewController, UITextFieldDelegate {
    // 트랙 레이블(A~L)
    let sliderLabels = Array("ABCDEFGHIJKL")
    
    // 동적 생성되는 UI 컴포넌트 배열
    var sliders:      [UISlider]     = []
    var volumeFields: [UITextField]  = []
    var playButtons:  [UIButton]     = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // 1) UI 구성
        setupUI()

        // 2) 저장/불러오기 버튼 추가
        let saveButton = UIBarButtonItem(
            title: "저장",
            style: .plain,
            target: self,
            action: #selector(savePresetTapped)
        )
        let loadButton = UIBarButtonItem(
            title: "불러오기",
            style: .plain,
            target: self,
            action: #selector(loadPresetTapped)
        )
        navigationItem.rightBarButtonItems = [saveButton, loadButton]

        // 3) Media Remote Command 설정
        configureRemoteCommands()
    }
    
    // MARK: - UI 구성
    func setupUI() {
        let scrollView    = UIScrollView()
        let containerView = UIView()
        let stackView     = UIStackView()
        
        [scrollView, containerView, stackView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        containerView.addSubview(stackView)
        
        // 전체 제어용 버튼 스택뷰 (playAll / pauseAll)
        let controlsStack = UIStackView()
        controlsStack.axis      = .horizontal
        controlsStack.spacing   = 12
        controlsStack.alignment = .center
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        
        // ▶ 전체 재생 버튼
        let playAll = UIButton(type: .system)
        playAll.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playAll.addTarget(self, action: #selector(playAllTapped), for: .touchUpInside)
        playAll.translatesAutoresizingMaskIntoConstraints = false
        
        // ⏸ 전체 일시정지 버튼
        let pauseAll = UIButton(type: .system)
        pauseAll.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        pauseAll.addTarget(self, action: #selector(pauseAllTapped), for: .touchUpInside)
        pauseAll.translatesAutoresizingMaskIntoConstraints = false
        
        controlsStack.addArrangedSubview(playAll)
        controlsStack.addArrangedSubview(pauseAll)
        containerView.addSubview(controlsStack)
        
        // Auto Layout
        NSLayoutConstraint.activate([
            // scrollView: 화면 전체
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // containerView: scrollView content
            containerView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            
            // controlsStack: 오른쪽 위
            controlsStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            controlsStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // stackView: controlsStack 아래, 좌우/바닥 여백
            stackView.topAnchor.constraint(equalTo: controlsStack.bottomAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
        
        // stackView 설정
        stackView.axis      = .vertical
        stackView.spacing   = 16
        stackView.alignment = .fill
        
        // 각 트랙별 UI 생성
        for (i, labelChar) in sliderLabels.enumerated() {
            let rowStack = UIStackView()
            rowStack.axis      = .horizontal
            rowStack.spacing   = 12
            rowStack.alignment = .center
            
            // (1) 트랙 라벨
            let nameLabel = UILabel()
            nameLabel.text = "\(labelChar)"
            nameLabel.widthAnchor.constraint(equalToConstant: 30).isActive = true
            
            // (2) 볼륨 슬라이더
            let slider = UISlider()
            slider.minimumValue = 0
            slider.maximumValue = 100
            slider.value        = 0
            slider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)
            sliders.append(slider)
            
            // (3) 볼륨 수치 입력 필드
            let volumeField = UITextField()
            volumeField.borderStyle  = .roundedRect
            volumeField.keyboardType = .numberPad
            volumeField.text         = "0"
            volumeField.delegate     = self
            volumeField.widthAnchor.constraint(equalToConstant: 50).isActive = true
            volumeFields.append(volumeField)
            
            // (4) 개별 Play/Pause 버튼
            let btn = UIButton(type: .system)
            btn.tag = i
            btn.setImage(UIImage(systemName: "play.fill"), for: .normal)
            btn.addTarget(self, action: #selector(toggleTrack(_:)), for: .touchUpInside)
            btn.widthAnchor.constraint(equalToConstant: 30).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 30).isActive = true
            playButtons.append(btn)
            
            // (5) 한 줄에 추가
            rowStack.addArrangedSubview(nameLabel)
            rowStack.addArrangedSubview(slider)
            rowStack.addArrangedSubview(volumeField)
            rowStack.addArrangedSubview(btn)
            stackView.addArrangedSubview(rowStack)
        }
    }
    
    // MARK: - 전체 재생/일시정지 액션
    @objc private func playAllTapped() {
        SoundManager.shared.playAll()
        playButtons.forEach {
            $0.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
    }
    @objc private func pauseAllTapped() {
        SoundManager.shared.pauseAll()
        playButtons.forEach {
            $0.setImage(UIImage(systemName: "play.fill"), for: .normal)
        }
    }
    
    // MARK: - 슬라이더 값 변경
    @objc func sliderChanged(_ sender: UISlider) {
        guard let index = sliders.firstIndex(of: sender) else { return }
        let intValue = Int(sender.value)
        volumeFields[index].text = "\(intValue)"
        SoundManager.shared.setVolume(at: index, volume: sender.value)
    }
    
    // MARK: - 텍스트필드 편집 종료
    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let idx = volumeFields.firstIndex(of: textField) else {
            textField.text = "0"
            return
        }
        let raw     = Float(textField.text ?? "") ?? 0
        let clamped = min(max(raw, 0), 100)
        sliders[idx].value       = clamped
        volumeFields[idx].text   = "\(Int(clamped))"
        SoundManager.shared.setVolume(at: idx, volume: clamped)
    }
    
    // MARK: - 개별 트랙 Play/Pause 토글
    @objc func toggleTrack(_ sender: UIButton) {
        let idx = sender.tag
        if SoundManager.shared.isPlaying(at: idx) {
            SoundManager.shared.pause(at: idx)
            sender.setImage(UIImage(systemName: "play.fill"), for: .normal)
        } else {
            SoundManager.shared.play(at: idx)
            sender.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
    }
    
    // MARK: - Preset 저장/불러오기
    @objc func savePresetTapped() {
        let alert = UIAlertController(
            title: "프리셋 저장",
            message: "프리셋 이름을 입력하세요",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "예: Rainy Night"
        }
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "저장", style: .default) { [weak self] _ in
            guard let self = self,
                  let name = alert.textFields?.first?.text?
                                 .trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else {
                self?.showWarning()
                return
            }
            let volumes = self.sliders.map { $0.value }
            if PresetManager.shared.getPreset(named: name) != nil {
                self.showOverwriteConfirmation(name: name, volumes: volumes)
            } else {
                PresetManager.shared.savePreset(name: name, volumes: volumes)
                self.showToast("프리셋이 저장되었습니다.")
            }
        })
        present(alert, animated: true)
    }
    @objc func loadPresetTapped() {
        let presetListVC = PresetListViewController()
        presetListVC.onPresetSelected = { [weak self] preset in
            guard let self = self else { return }
            for (i, vol) in preset.volumes.enumerated() where i < self.sliders.count {
                self.sliders[i].value      = vol
                self.volumeFields[i].text  = "\(Int(vol))"
                SoundManager.shared.setVolume(at: i, volume: vol)
                let icon = SoundManager.shared.isPlaying(at: i) ? "pause.fill" : "play.fill"
                self.playButtons[i].setImage(UIImage(systemName: icon), for: .normal)
            }
            SoundManager.shared.playAll()
        }
        navigationController?.pushViewController(presetListVC, animated: true)
    }
    // MARK: - 토스트 메시지 띄우기
    private func showToast(_ message: String) {
        let toast = UILabel()
        toast.text = message
        toast.font = .systemFont(ofSize: 14)
        toast.textColor = .white
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toast.textAlignment = .center
        toast.layer.cornerRadius = 8
        toast.clipsToBounds = true
        toast.alpha = 0
        toast.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toast.widthAnchor.constraint(lessThanOrEqualToConstant: 240),
            toast.heightAnchor.constraint(equalToConstant: 35)
        ])

        UIView.animate(withDuration: 0.3, animations: {
            toast.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5, options: [], animations: {
                toast.alpha = 0
            }) { _ in
                toast.removeFromSuperview()
            }
        }
    }

    // MARK: - 저장 경고 다이얼로그
    private func showWarning() {
        let warning = UIAlertController(
            title: "⚠️ 이름 없음",
            message: "프리셋 이름을 입력해야 저장됩니다.",
            preferredStyle: .alert
        )
        warning.addAction(UIAlertAction(title: "확인", style: .default))
        present(warning, animated: true)
    }

    // MARK: - 덮어쓰기 확인 다이얼로그
    private func showOverwriteConfirmation(name: String, volumes: [Float]) {
        let confirm = UIAlertController(
            title: "중복된 이름",
            message: "'\(name)' 이름의 프리셋이 이미 존재합니다.\n덮어쓰시겠습니까?",
            preferredStyle: .alert
        )
        confirm.addAction(UIAlertAction(title: "취소", style: .cancel))
        confirm.addAction(UIAlertAction(title: "덮어쓰기", style: .destructive) { _ in
            PresetManager.shared.savePreset(name: name, volumes: volumes)
            self.showToast("덮어쓰기 완료되었습니다.")
        })
        present(confirm, animated: true)
    }
    
    // MARK: - Media Remote Command 설정
    func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        
        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            SoundManager.shared.playAll()
            self?.updateNowPlaying(isPlaying: true)
            return .success
        }
        
        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            SoundManager.shared.pauseAll()
            self?.updateNowPlaying(isPlaying: false)
            return .success
        }
        
        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            if SoundManager.shared.isPlaying {
                SoundManager.shared.pauseAll()
            } else {
                SoundManager.shared.playAll()
            }
            self?.updateNowPlaying(isPlaying: SoundManager.shared.isPlaying)
            return .success
        }
    }
    
    // MARK: - Now Playing 정보 업데이트
    private func updateNowPlaying(isPlaying: Bool) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
