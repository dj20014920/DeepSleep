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
            emojiStack.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    @objc func hashtagTapped() {
        let chatVC = ChatViewController()
        chatVC.initialUserText = nil
        chatVC.onPresetApply = { [weak self] (preset: RecommendationResponse) in
            self?.applyPreset(volumes: preset.volumes, name: preset.presetName, shouldSaveToRecent: true)
        }
        navigationController?.pushViewController(chatVC, animated: true)
    }

    @objc func emojiTapped(_ sender: UIButton) {
        let selectedEmoji = emojis[sender.tag]
        
        // EmotionResponseManager를 사용하여 하드코딩된 응답 가져오기
        if let emotionResponse = EmotionResponseManager.shared.getRandomResponse(for: selectedEmoji) {
            let randomPreset = emotionResponse.randomPreset
            let randomMessage = emotionResponse.randomMessage
            
            // 프리셋 직접 적용
            applyPreset(volumes: randomPreset.floatVolumes, name: randomPreset.name, shouldSaveToRecent: true)
            
            // 사용자에게 메시지 표시
            showEmotionResponseAlert(message: randomMessage, presetName: randomPreset.name)
        } else {
            // 기본 ChatViewController로 이동 (fallback)
            let chatVC = ChatViewController()
            chatVC.initialUserText = selectedEmoji
            chatVC.onPresetApply = { [weak self] (preset: RecommendationResponse) in
                self?.applyPreset(volumes: preset.volumes, name: preset.presetName, shouldSaveToRecent: true)
            }
            navigationController?.pushViewController(chatVC, animated: true)
        }
    }
    
    // 감정 응답 메시지를 보여주는 알림
    private func showEmotionResponseAlert(message: String, presetName: String) {
        let alert = UIAlertController(
            title: "🎵 프리셋 적용됨",
            message: "\(message)\n\n적용된 프리셋: \(presetName)",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        
        // AI 대화 옵션 추가
        alert.addAction(UIAlertAction(title: "AI와 더 대화하기", style: .default) { [weak self] _ in
            let chatVC = ChatViewController()
            chatVC.initialUserText = nil
            chatVC.onPresetApply = { [weak self] (preset: RecommendationResponse) in
                self?.applyPreset(volumes: preset.volumes, name: preset.presetName, shouldSaveToRecent: true)
            }
            self?.navigationController?.pushViewController(chatVC, animated: true)
        })
        
        present(alert, animated: true)
    }
}
