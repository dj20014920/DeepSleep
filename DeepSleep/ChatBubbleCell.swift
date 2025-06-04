import UIKit
import Foundation

class ChatBubbleCell: UITableViewCell {
    static let identifier = "ChatBubbleCell"
    
    private var messageLabelBottomConstraint: NSLayoutConstraint!
    private var messageLabelToButtonConstraint: NSLayoutConstraint!
    private var applyButtonBottomConstraint: NSLayoutConstraint!
    private var applyButtonHeightConstraint: NSLayoutConstraint!
    
    private let bubbleView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.defaultLow, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()
    
    private let applyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("🎵 바로 적용하기", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        button.setTitleColor(.systemBlue, for: .normal)
        button.layer.cornerRadius = 14
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        
        // 그림자 효과 추가
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.1
        button.layer.shadowRadius = 4
        
        return button
    }()
    
    // ✅ 새로운 옵션 버튼들을 위한 스택뷰
    private let optionButtonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.isHidden = true
        return stackView
    }()
    
    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    
    private var applyAction: (() -> Void)?
    
    // ✅ 옵션 액션들을 저장할 프로퍼티들
    private var saveAction: (() -> Void)?
    private var feedbackAction: (() -> Void)?
    private var goToMainAction: (() -> Void)?
    private var continueAction: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(messageLabel)
        bubbleView.addSubview(applyButton)
        bubbleView.addSubview(optionButtonStackView) // ✅ 새로운 스택뷰 추가
        
        // 제약 조건 설정
        messageLabelBottomConstraint = messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12)
        applyButtonHeightConstraint = applyButton.heightAnchor.constraint(equalToConstant: 32)
        messageLabelToButtonConstraint = applyButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 12)
        applyButtonBottomConstraint = applyButton.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12)

        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            messageLabelBottomConstraint,
            
            applyButton.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            applyButton.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            applyButtonHeightConstraint,
            
            // ✅ 옵션 버튼 스택뷰 제약 조건
            optionButtonStackView.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 12),
            optionButtonStackView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            optionButtonStackView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            optionButtonStackView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12),
            optionButtonStackView.heightAnchor.constraint(equalToConstant: 200) // 4개 버튼 * 50 높이
        ])

        // bubbleView 제약
        leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            leadingConstraint,
            trailingConstraint
        ])

        // 최대 너비 제한
        let bubbleWidthConstraint = bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.85)
        bubbleWidthConstraint.priority = .required
        bubbleWidthConstraint.isActive = true
        
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)
    }

    func configure(with message: ChatMessage) {
        // 초기화
        resetConstraints()
        applyButton.isHidden = true
        optionButtonStackView.isHidden = true // ✅ 옵션 스택뷰도 숨기기
        applyAction = nil
        clearOptionActions() // ✅ 옵션 액션들 초기화

        switch message {
        case .user(let text):
            configureUserMessage(text)
        case .bot(let text):
            configureBotMessage(text)
        case .presetRecommendation(_, let msg, let action):
            configurePresetMessage(msg, action: action)
        case .postPresetOptions(let presetName, let onSave, let onFeedback, let onGoToMain, let onContinueChat):
            // ✅ 새로운 postPresetOptions 케이스 처리
            configurePostPresetOptions(
                presetName: presetName,
                onSave: onSave,
                onFeedback: onFeedback,
                onGoToMain: onGoToMain,
                onContinueChat: onContinueChat
            )
        }
        
        // 애니메이션 효과
        bubbleView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut], animations: {
            self.bubbleView.transform = .identity
        })
    }
    
    private func resetConstraints() {
        leadingConstraint.isActive = false
        trailingConstraint.isActive = false
        messageLabelBottomConstraint.isActive = false
        messageLabelToButtonConstraint.isActive = false
        applyButtonBottomConstraint.isActive = false
    }
    
    // ✅ 옵션 액션들 초기화
    private func clearOptionActions() {
        saveAction = nil
        feedbackAction = nil
        goToMainAction = nil
        continueAction = nil
        
        // 기존 버튼들 제거
        optionButtonStackView.arrangedSubviews.forEach { subview in
            optionButtonStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
    }
    
    private func configureUserMessage(_ text: String) {
        // 사용자 메시지 스타일
        bubbleView.backgroundColor = .systemBlue
        messageLabel.textColor = .white
        messageLabel.text = text
        messageLabel.font = .systemFont(ofSize: 16, weight: .regular)
        
        // 오른쪽 정렬
        trailingConstraint.isActive = true
        messageLabelBottomConstraint.isActive = true
        
        // 그라데이션 효과 (선택적)
        addGradientToBubble(colors: [
            UIColor.systemBlue.cgColor,
            UIColor.systemBlue.withAlphaComponent(0.8).cgColor
        ])
    }
    
    private func configureBotMessage(_ text: String) {
        // AI 메시지 스타일
        bubbleView.backgroundColor = UIColor(white: 0.95, alpha: 1)
        messageLabel.textColor = .label
        messageLabel.text = text
        messageLabel.font = .systemFont(ofSize: 16, weight: .regular)
        
        // 왼쪽 정렬
        leadingConstraint.isActive = true
        messageLabelBottomConstraint.isActive = true
        
        // 부드러운 그림자
        bubbleView.layer.shadowColor = UIColor.black.cgColor
        bubbleView.layer.shadowOffset = CGSize(width: 0, height: 1)
        bubbleView.layer.shadowOpacity = 0.05
        bubbleView.layer.shadowRadius = 3
    }
    
    private func configurePresetMessage(_ msg: String, action: @escaping () -> Void) {
        // 프리셋 추천 메시지 스타일
        bubbleView.backgroundColor = UIColor.systemGreen
        messageLabel.textColor = .white
        messageLabel.text = msg
        messageLabel.font = .systemFont(ofSize: 16, weight: .medium)
        
        // 왼쪽 정렬 + 버튼 표시
        leadingConstraint.isActive = true
        applyButton.isHidden = false
        applyButtonHeightConstraint.constant = 36
        messageLabelToButtonConstraint.isActive = true
        applyButtonBottomConstraint.isActive = true
        applyAction = action
        
        // 특별한 그라데이션 효과
        addGradientToBubble(colors: [
            UIColor.systemGreen.cgColor,
            UIColor.systemGreen.withAlphaComponent(0.8).cgColor
        ])
        
        // 버튼 애니메이션 효과
        applyButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.3, delay: 0.1, options: [.curveEaseOut], animations: {
            self.applyButton.transform = .identity
        })
        
        // 맥동 효과 (선택적)
        addPulseAnimation()
    }
    
    // ✅ 새로운 postPresetOptions 구성 메서드
    private func configurePostPresetOptions(
        presetName: String,
        onSave: @escaping () -> Void,
        onFeedback: @escaping () -> Void,
        onGoToMain: @escaping () -> Void,
        onContinueChat: @escaping () -> Void
    ) {
        // AI 메시지 스타일 기본 적용
        bubbleView.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.1)
        messageLabel.textColor = .label
        messageLabel.text = "🎶 새로운 사운드 조합이 재생되고 있어요!\n\n이제 어떻게 하고 싶으신가요?"
        messageLabel.font = .systemFont(ofSize: 16, weight: .medium)
        
        // 왼쪽 정렬
        leadingConstraint.isActive = true
        
        // 옵션 버튼 스택뷰 표시
        optionButtonStackView.isHidden = false
        
        // 액션들 저장
        saveAction = onSave
        feedbackAction = onFeedback
        goToMainAction = onGoToMain
        continueAction = onContinueChat
        
        // 4개의 옵션 버튼 생성
        let saveButton = createOptionButton(
            title: "💾 저장하기",
            backgroundColor: .systemBlue,
            action: #selector(saveOptionTapped)
        )
        
        let feedbackButton = createOptionButton(
            title: "💬 피드백",
            backgroundColor: .systemOrange,
            action: #selector(feedbackOptionTapped)
        )
        
        let continueButton = createOptionButton(
            title: "💭 계속 대화",
            backgroundColor: .systemGreen,
            action: #selector(continueOptionTapped)
        )
        
        let mainButton = createOptionButton(
            title: "🏠 메인으로",
            backgroundColor: .systemGray,
            action: #selector(mainOptionTapped)
        )
        
        // 버튼들을 스택뷰에 추가
        [saveButton, feedbackButton, continueButton, mainButton].forEach {
            optionButtonStackView.addArrangedSubview($0)
        }
        
        // 부드러운 그림자 효과
        bubbleView.layer.shadowColor = UIColor.black.cgColor
        bubbleView.layer.shadowOffset = CGSize(width: 0, height: 2)
        bubbleView.layer.shadowOpacity = 0.1
        bubbleView.layer.shadowRadius = 5
    }
    
    // ✅ 옵션 버튼 생성 헬퍼 메서드
    private func createOptionButton(
        title: String,
        backgroundColor: UIColor,
        action: Selector
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = backgroundColor
        button.layer.cornerRadius = 8
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // 버튼 액션 설정
        button.addTarget(self, action: action, for: .touchUpInside)
        
        // 버튼 높이 제약
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        return button
    }
    
    // ✅ 옵션 버튼 액션 메서드들
    @objc private func saveOptionTapped() {
        provideButtonFeedback()
        saveAction?()
    }
    
    @objc private func feedbackOptionTapped() {
        provideButtonFeedback()
        feedbackAction?()
    }
    
    @objc private func continueOptionTapped() {
        provideButtonFeedback()
        continueAction?()
    }
    
    @objc private func mainOptionTapped() {
        provideButtonFeedback()
        goToMainAction?()
    }
    
    // ✅ 버튼 피드백 헬퍼 메서드
    private func provideButtonFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    private func addGradientToBubble(colors: [CGColor]) {
        // 기존 그라데이션 레이어 제거
        bubbleView.layer.sublayers?.removeAll { $0 is CAGradientLayer }
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = colors
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 16
        
        bubbleView.layer.insertSublayer(gradientLayer, at: 0)
        
        // 레이아웃 업데이트 시 그라데이션 크기 조정
        DispatchQueue.main.async {
            gradientLayer.frame = self.bubbleView.bounds
        }
    }
    
    private func addPulseAnimation() {
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.duration = 1.0
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 1.05
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = 3
        applyButton.layer.add(pulseAnimation, forKey: "pulse")
    }

    @objc private func applyTapped() {
        // 터치 피드백
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        // 버튼 애니메이션
        UIView.animate(withDuration: 0.1, animations: {
            self.applyButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.applyButton.transform = .identity
            }
        }
        
        // 액션 실행
        applyAction?()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // 레이어 정리
        bubbleView.layer.sublayers?.removeAll { $0 is CAGradientLayer }
        bubbleView.layer.shadowOpacity = 0
        applyButton.layer.removeAllAnimations()
        
        // 상태 초기화
        applyAction = nil
        applyButton.isHidden = true
        optionButtonStackView.isHidden = true // ✅ 옵션 스택뷰도 숨기기
        clearOptionActions() // ✅ 옵션 액션들 초기화
    }
}
