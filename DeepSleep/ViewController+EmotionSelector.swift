import UIKit

// MARK: - 감정 선택 UI 관련 Extension
extension ViewController {
    
    func setupEmojiSelector() {
        let hashtagButton = UIButton(type: .system)
        let attributedTitle = NSAttributedString(
            string: "#Todays_Mood",
            attributes: [
                .foregroundColor: UIColor.systemBlue,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .font: UIFont.italicSystemFont(ofSize: 20)
            ]
        )
        hashtagButton.setAttributedTitle(attributedTitle, for: .normal)
        hashtagButton.addTarget(self, action: #selector(hashtagTapped), for: .touchUpInside)
        hashtagButton.translatesAutoresizingMaskIntoConstraints = false

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

        let moodStack = UIStackView(arrangedSubviews: [hashtagButton, emojiStack])
        moodStack.axis = .vertical
        moodStack.spacing = 4
        moodStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(moodStack)

        NSLayoutConstraint.activate([
            moodStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            moodStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            moodStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            emojiStack.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
    
    @objc func hashtagTapped() {
        let chatVC = ChatViewController()
        chatVC.initialUserText = nil
        chatVC.onPresetApply = { [weak self] (preset: ChatViewController.RecommendationResponse) in
            self?.applyPreset(volumes: preset.volumes, name: preset.presetName)
        }
        navigationController?.pushViewController(chatVC, animated: true)
    }

    @objc func emojiTapped(_ sender: UIButton) {
        let chatVC = ChatViewController()
        chatVC.initialUserText = emojis[sender.tag]
        chatVC.onPresetApply = { [weak self] (preset: ChatViewController.RecommendationResponse) in
            self?.applyPreset(volumes: preset.volumes, name: preset.presetName)
        }
        navigationController?.pushViewController(chatVC, animated: true)
    }
}
