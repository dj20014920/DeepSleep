import UIKit

// MARK: - 유틸리티 & 피드백 관련 Extension
extension ViewController {
    
    // MARK: - 프리셋 적용
    func applyPreset(volumes: [Float], name: String) {
        for (i, volume) in volumes.enumerated() where i < sliders.count {
            updateSliderAndTextField(at: i, volume: volume)
        }
        
        SoundManager.shared.playAll()
        addToRecentPresets(name: name, volumes: volumes)
        updatePlayButtonStates()
        updatePresetBlocks()
        showPresetAppliedFeedback(name: name)
    }
    
    // MARK: - 피드백
    func provideLightHapticFeedback() {
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
    }
    
    func provideMediumHapticFeedback() {
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
    }
    
    func showPresetAppliedFeedback(name: String) {
        let toastLabel = UILabel()
        toastLabel.text = "🎵 \(name) 적용됨"
        toastLabel.backgroundColor = UIColor.label.withAlphaComponent(0.8)
        toastLabel.textColor = .systemBackground
        toastLabel.textAlignment = .center
        toastLabel.font = .systemFont(ofSize: 14, weight: .medium)
        toastLabel.layer.cornerRadius = 8
        toastLabel.clipsToBounds = true
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(toastLabel)
        
        NSLayoutConstraint.activate([
            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toastLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            toastLabel.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        toastLabel.alpha = 0
        UIView.animate(withDuration: 0.3, animations: {
            toastLabel.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5, animations: {
                toastLabel.alpha = 0
            }) { _ in
                toastLabel.removeFromSuperview()
            }
        }
    }
    
    // MARK: - 키보드 처리
    @objc func keyboardWillShow(notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        let keyboardHeight = keyboardFrame.height
        if let scrollView = view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
            scrollView.contentInset.bottom = keyboardHeight
            scrollView.verticalScrollIndicatorInsets.bottom = keyboardHeight
        }
    }
    
    @objc func keyboardWillHide(notification: Notification) {
        if let scrollView = view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
            scrollView.contentInset.bottom = 0
            scrollView.verticalScrollIndicatorInsets.bottom = 0
        }
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - 네비게이션
    @objc func savePresetTapped() {
        let alert = UIAlertController(title: "프리셋 저장", message: "프리셋 이름을 입력하세요", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "내 프리셋"
        }
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "저장", style: .default) { [weak self] _ in
            guard let self = self,
                  let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { return }
            
            let volumes = self.sliders.map { Float(Int($0.value)) }
            let preset = SoundPreset(
                name: name,
                volumes: volumes,
                isAIGenerated: false,
                description: "사용자가 직접 저장한 프리셋"
            )
            
            SettingsManager.shared.saveSoundPreset(preset)
            self.updatePresetBlocks()
            self.showPresetAppliedFeedback(name: "프리셋 '\(name)' 저장됨")
        })
        present(alert, animated: true)
    }
    
    @objc func loadPresetTapped() {
        showPresetList()
    }

    @objc func showTimer() {
        let vc = TimerViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc func showDiary() {
        let diaryVC = EmotionDiaryViewController()
        navigationController?.pushViewController(diaryVC, animated: true)
    }
}
