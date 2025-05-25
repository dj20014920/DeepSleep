import UIKit
import AVFoundation
import MediaPlayer

class ViewController: UIViewController {
    let sliderLabels = Array("ABCDEFGHIJKL")
    private let emojis = ["😊","😢","😠","😰","😴"]
    var sliders: [UISlider] = []
    var volumeFields: [UITextField] = []
    var playButtons: [UIButton] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureNavBar()
        setupEmojiSelector()
        setupSliderUI()
        configureRemoteCommands()
    }

    private func configureNavBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "타이머", style: .plain, target: self, action: #selector(showTimer))
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "저장", style: .plain, target: self, action: #selector(savePresetTapped)),
            UIBarButtonItem(title: "불러오기", style: .plain, target: self, action: #selector(loadPresetTapped))
        ]
    }

    private func setupEmojiSelector() {
        // 1. 해시태그 버튼 (#Todays_Mood)
        let hashtagButton = UIButton(type: .system)
        let attributedTitle = NSAttributedString(
            string: "#Todays_Mood",
            attributes: [
                .foregroundColor: UIColor.systemBlue,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .font: UIFont.italicSystemFont(ofSize: 20)  // ✅ 폰트 20pt
            ]
        )
        hashtagButton.setAttributedTitle(attributedTitle, for: .normal)
        hashtagButton.addTarget(self, action: #selector(hashtagTapped), for: .touchUpInside)
        hashtagButton.translatesAutoresizingMaskIntoConstraints = false

        // 2. 이모지 버튼들
        let emojiButtons = emojis.enumerated().map { idx, emoji in
            let btn = UIButton(type: .system)
            btn.setTitle(emoji, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 24)
            btn.tag = idx
            btn.addTarget(self, action: #selector(emojiTapped(_:)), for: .touchUpInside)
            return btn
        }

        let emojiStack = UIStackView(arrangedSubviews: emojiButtons)
        emojiStack.axis = .horizontal
        emojiStack.spacing = 8
        emojiStack.distribution = .fillEqually
        emojiStack.translatesAutoresizingMaskIntoConstraints = false

        // 3. 해시태그 + 이모지 수직 스택
        let moodStack = UIStackView(arrangedSubviews: [hashtagButton, emojiStack])
        moodStack.axis = .vertical
        moodStack.spacing = 4  // ✅ 줄임
        moodStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(moodStack)

        // 4. 제약조건
        NSLayoutConstraint.activate([
            moodStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),  // ✅ 줄임
            moodStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            moodStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            emojiStack.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
    
    @objc private func hashtagTapped() {
        let chatVC = ChatViewController()
        chatVC.initialUserText = nil  // 해시태그는 직접 문장 입력 유도
        chatVC.onPresetApply = { (preset: RecommendationResponse) in
            for (i, v) in preset.volumes.enumerated() where i < self.sliders.count {
                self.sliders[i].value = v
                self.volumeFields[i].text = "\(Int(v))"
                SoundManager.shared.setVolume(at: i, volume: v)
            }
            SoundManager.shared.playAll()
        }
        navigationController?.pushViewController(chatVC, animated: true)
    }
    
    @objc private func emojiTapped(_ sender: UIButton) {
        let chatVC = ChatViewController()
        chatVC.initialUserText = emojis[sender.tag]
        chatVC.onPresetApply = { (preset: RecommendationResponse) in
            for (i, v) in preset.volumes.enumerated() where i < self.sliders.count {
                self.sliders[i].value = v
                self.volumeFields[i].text = "\(Int(v))"
                SoundManager.shared.setVolume(at: i, volume: v)
            }
            SoundManager.shared.playAll()
        }
        navigationController?.pushViewController(chatVC, animated: true)
    }

    private func setupSliderUI() {
        let scrollView = UIScrollView()
        let containerView = UIView()
        let stackView = UIStackView()
        [scrollView, containerView, stackView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        containerView.addSubview(stackView)

        let controlsStack = UIStackView()
        controlsStack.axis = .horizontal
        controlsStack.spacing = 12
        controlsStack.translatesAutoresizingMaskIntoConstraints = false

        let playAll = UIButton(type: .system)
        playAll.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playAll.addTarget(self, action: #selector(playAllTapped), for: .touchUpInside)

        let pauseAll = UIButton(type: .system)
        pauseAll.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        pauseAll.addTarget(self, action: #selector(pauseAllTapped), for: .touchUpInside)

        [playAll, pauseAll].forEach { controlsStack.addArrangedSubview($0) }
        containerView.addSubview(controlsStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 70),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            containerView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            controlsStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            controlsStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            stackView.topAnchor.constraint(equalTo: controlsStack.bottomAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])

        stackView.axis = .vertical
        stackView.spacing = 16

        for (i, labelChar) in sliderLabels.enumerated() {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 12

            let nameLabel = UILabel()
            nameLabel.text = "\(labelChar)"
            nameLabel.widthAnchor.constraint(equalToConstant: 30).isActive = true

            let slider = UISlider()
            slider.minimumValue = 0
            slider.maximumValue = 100
            slider.value = 0
            slider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)
            sliders.append(slider)

            let volumeField = UITextField()
            volumeField.text = "0"
            volumeField.borderStyle = .roundedRect
            volumeField.keyboardType = .numberPad
            volumeField.widthAnchor.constraint(equalToConstant: 50).isActive = true
            volumeFields.append(volumeField)

            let button = UIButton(type: .system)
            button.setImage(UIImage(systemName: "play.fill"), for: .normal)
            button.tag = i
            button.widthAnchor.constraint(equalToConstant: 30).isActive = true
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
            button.addTarget(self, action: #selector(toggleTrack(_:)), for: .touchUpInside)
            playButtons.append(button)

            [nameLabel, slider, volumeField, button].forEach { row.addArrangedSubview($0) }
            stackView.addArrangedSubview(row)
        }
    }

    @objc private func sliderChanged(_ sender: UISlider) {
        guard let i = sliders.firstIndex(of: sender) else { return }
        let v = sender.value
        volumeFields[i].text = "\(Int(v))"
        SoundManager.shared.setVolume(at: i, volume: v)
    }

    @objc private func toggleTrack(_ sender: UIButton) {
        let i = sender.tag
        if SoundManager.shared.isPlaying(at: i) {
            SoundManager.shared.pause(at: i)
            sender.setImage(UIImage(systemName: "play.fill"), for: .normal)
        } else {
            SoundManager.shared.play(at: i)
            sender.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
    }

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

    @objc func savePresetTapped() { /* 그대로 */ }
    @objc func loadPresetTapped() { /* 그대로 */ }

    @objc private func showTimer() {
        let vc = TimerViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { _ in SoundManager.shared.playAll(); return .success }
        center.pauseCommand.addTarget { _ in SoundManager.shared.pauseAll(); return .success }
        center.togglePlayPauseCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            
            if SoundManager.shared.isPlaying {
                SoundManager.shared.pauseAll()
            } else {
                SoundManager.shared.playAll()
            }

            return .success
        }
    }
}
