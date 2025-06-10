import UIKit

// MARK: - 감정 선택 UI 관련 Extension
extension ViewController {
    
    func setupEmojiSelector() {
        let hashtagButton = UIButton(type: .system)
        let attributedTitle = NSAttributedString(
            string: "#Todays_Mood",
            attributes: [
                .foregroundColor: UIDesignSystem.Colors.primaryText,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .font: UIFont.italicSystemFont(ofSize: 20)
            ]
        )
        hashtagButton.setAttributedTitle(attributedTitle, for: .normal)
        hashtagButton.addTarget(self, action: #selector(hashtagTapped), for: .touchUpInside)
        hashtagButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 접근성 및 사용자 가이던스 개선
        hashtagButton.accessibilityLabel = "오늘의 기분"
        hashtagButton.accessibilityHint = "AI와 대화하며 나의 감정을 표현해보세요"

        let emojiButtons = emojis.enumerated().map { idx, emoji in
            let btn = UIButton(type: .system)
            btn.setTitle(emoji, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 24)
            btn.tag = 1000 + idx  // 카테고리 버튼과 구분하기 위해 1000번대 사용
            btn.addTarget(self, action: #selector(emojiTapped(_:)), for: .touchUpInside)
            return btn
        }

        let emojiStack = UIStackView(arrangedSubviews: emojiButtons)
        emojiStack.axis = .horizontal
        emojiStack.spacing = 8
        emojiStack.distribution = .fillEqually
        emojiStack.translatesAutoresizingMaskIntoConstraints = false

        let moodStack = UIStackView(arrangedSubviews: [hashtagButton, emojiStack])
        moodStack.axis = .vertical
        moodStack.spacing = 4
        moodStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(moodStack)

        NSLayoutConstraint.activate([
            moodStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            moodStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            moodStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            emojiStack.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    @objc func hashtagTapped() {
        let chatVC = ChatRouter.chatViewController()
        chatVC.initialUserText = nil
        chatVC.onPresetApply = { [weak self] (preset: RecommendationResponse) in
            self?.applyPreset(volumes: preset.volumes, versions: preset.selectedVersions, name: preset.presetName, shouldSaveToRecent: true)
        }
        navigationController?.pushViewController(chatVC, animated: true)
    }

    @objc func emojiTapped(_ sender: UIButton) {
        let emojiIndex = sender.tag - 1000  // 1000번대에서 실제 인덱스로 변환
        let selectedEmoji = emojis[emojiIndex]
        
        // 바로 AI 대화창으로 이동
        let chatVC = ChatRouter.chatViewController()
        chatVC.initialUserText = selectedEmoji
        chatVC.onPresetApply = { [weak self] (preset: RecommendationResponse) in
            self?.applyPreset(volumes: preset.volumes, versions: preset.selectedVersions, name: preset.presetName, shouldSaveToRecent: true)
        }
        navigationController?.pushViewController(chatVC, animated: true)
    }

}
