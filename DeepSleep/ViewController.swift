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
        
        // 2) Media Remote Command 설정
        configureRemoteCommands()
    }
    
    // MARK: - UI 구성
    func setupUI() {
        // 1) 스크롤 뷰 및 컨테이너
        let scrollView    = UIScrollView()
        let containerView = UIView()
        let stackView     = UIStackView()
        
        [scrollView, containerView, stackView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        containerView.addSubview(stackView)
        
        // 2) 전체 제어용 버튼 스택뷰 (playAll / pauseAll)
        let controlsStack = UIStackView()
        controlsStack.axis         = .horizontal
        controlsStack.spacing      = 12
        controlsStack.alignment    = .center
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
        
        // 3) Auto Layout
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
            
            // stackView: controlsStack 아래, 좌우 20pt 여백, 바닥 20pt 여백
            stackView.topAnchor.constraint(equalTo: controlsStack.bottomAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
        
        // 4) stackView 설정
        stackView.axis     = .vertical
        stackView.spacing  = 16
        stackView.alignment = .fill
        
        // 5) 각 트랙별 UI 생성
        for (i, labelChar) in sliderLabels.enumerated() {
            let rowStack = UIStackView()
            rowStack.axis        = .horizontal
            rowStack.spacing     = 12
            rowStack.alignment   = .center
            
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
            volumeField.borderStyle   = .roundedRect
            volumeField.keyboardType  = .numberPad
            volumeField.text          = "0"
            volumeField.delegate      = self
            volumeField.widthAnchor.constraint(equalToConstant: 50).isActive = true
            volumeFields.append(volumeField)
            
            // (4) 개별 Play/Pause 버튼
            let btn = UIButton(type: .system)
            btn.tag = i  // index 식별용
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
        
        // SoundManager 에 볼륨 반영 (0~100 → 0.0~1.0)
        SoundManager.shared.setVolume(at: index, volume: sender.value)
    }
    
    // MARK: - 텍스트필드 편집 종료
    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let idx = volumeFields.firstIndex(of: textField) else {
            textField.text = "0"
            return
        }
        
        let raw = Float(textField.text ?? "") ?? 0
        let clamped = min(max(raw, 0), 100)
        sliders[idx].value = clamped
        volumeFields[idx].text = "\(Int(clamped))"
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
        // (생략…) 기존 구현 그대로
    }
    @objc func loadPresetTapped() {
        // (생략…) 기존 구현 그대로
    }
    
    // MARK: - Media Remote Command 설정
    func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        
        center.playCommand.isEnabled   = true
        center.playCommand.addTarget { [weak self] _ in
            SoundManager.shared.playAll()
            self?.updateNowPlaying(isPlaying: true)
            return .success
        }
        
        center.pauseCommand.isEnabled  = true
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
        // (추가: 제목, elapsedTime, artwork 등 설정 가능)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
