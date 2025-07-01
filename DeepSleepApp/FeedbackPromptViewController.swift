import UIKit

class FeedbackPromptViewController: UIViewController {
    
    // MARK: - Properties
    private var presetName: String
    private var recommendationType: RecommendationType
    private var onFeedbackProvided: ((Int) -> Void)?
    
    // UI Components
    private let containerView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let benefitLabel = UILabel()
    private let buttonStackView = UIStackView()
    
    enum RecommendationType {
        case local
        case ai
        case comprehensive
        
        var displayName: String {
            switch self {
            case .local: return "로컬 AI 추천"
            case .ai: return "외부 AI 추천"
            case .comprehensive: return "종합 AI 추천"
            }
        }
        
        var benefitMessage: String {
            switch self {
            case .local:
                return "💡 이 피드백은 앱 내 로컬 AI의 학습에 도움이 됩니다.\n개인화된 추천이 더욱 정확해져요!"
            case .ai:
                return "🌐 이 피드백은 외부 AI 모델의 성능 향상에 기여합니다.\n더 똑똑한 추천을 받으실 수 있어요!"
            case .comprehensive:
                return "🧠 이 피드백은 로컬+외부 AI 모두에게 도움이 됩니다.\n최고의 개인화 경험을 만들어드려요!"
            }
        }
    }
    
    // MARK: - Initialization
    init(presetName: String, recommendationType: RecommendationType, onFeedbackProvided: @escaping (Int) -> Void) {
        self.presetName = presetName
        self.recommendationType = recommendationType
        self.onFeedbackProvided = onFeedbackProvided
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLayout()
        animatePresentation()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        // Container
        containerView.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowOpacity = 0.3
        containerView.layer.shadowRadius = 8
        containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        containerView.alpha = 0
        
        // Icon
        iconImageView.image = UIImage(systemName: "heart.circle.fill")
        iconImageView.tintColor = UIColor.systemPink
        iconImageView.contentMode = .scaleAspectFit
        
        // Title
        titleLabel.text = "🎵 '\(presetName)'는 어떠셨나요?"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = UIDesignSystem.Colors.primaryText
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        
        // Message
        messageLabel.text = "짧은 피드백으로 AI가 더 똑똑해져요"
        messageLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        messageLabel.textColor = UIDesignSystem.Colors.secondaryText
        messageLabel.textAlignment = .center
        
        // Benefit
        benefitLabel.text = recommendationType.benefitMessage
        benefitLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        benefitLabel.textColor = UIDesignSystem.Colors.primary
        benefitLabel.textAlignment = .center
        benefitLabel.numberOfLines = 0
        benefitLabel.backgroundColor = UIDesignSystem.Colors.primary.withAlphaComponent(0.1)
        benefitLabel.layer.cornerRadius = 8
        benefitLabel.layer.masksToBounds = true
        
        // Add padding to benefit label
        benefitLabel.layer.borderWidth = 1
        benefitLabel.layer.borderColor = UIDesignSystem.Colors.primary.withAlphaComponent(0.3).cgColor
        
        // Button Stack
        buttonStackView.axis = .horizontal
        buttonStackView.distribution = .fillEqually
        buttonStackView.spacing = 12
        
        // Create feedback buttons
        let loveButton = createFeedbackButton(
            title: "😍 좋아요",
            satisfaction: 2,
            backgroundColor: UIColor.systemGreen.withAlphaComponent(0.2),
            borderColor: UIColor.systemGreen
        )
        
        let okayButton = createFeedbackButton(
            title: "😊 그냥 그래요",
            satisfaction: 1,
            backgroundColor: UIColor.systemOrange.withAlphaComponent(0.2),
            borderColor: UIColor.systemOrange
        )
        
        let mehButton = createFeedbackButton(
            title: "😐 별로예요",
            satisfaction: 0,
            backgroundColor: UIColor.systemRed.withAlphaComponent(0.2),
            borderColor: UIColor.systemRed
        )
        
        buttonStackView.addArrangedSubview(loveButton)
        buttonStackView.addArrangedSubview(okayButton)
        buttonStackView.addArrangedSubview(mehButton)
        
        // Skip button
        let skipButton = UIButton(type: .system)
        skipButton.setTitle("나중에 할게요", for: .normal)
        skipButton.setTitleColor(UIDesignSystem.Colors.secondaryText, for: .normal)
        skipButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        skipButton.addTarget(self, action: #selector(skipButtonTapped), for: .touchUpInside)
        
        // Add all views
        view.addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(messageLabel)
        containerView.addSubview(benefitLabel)
        containerView.addSubview(buttonStackView)
        containerView.addSubview(skipButton)
        
        // Configure constraints
        [containerView, iconImageView, titleLabel, messageLabel, benefitLabel, buttonStackView, skipButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }
    
    private func createFeedbackButton(title: String, satisfaction: Int, backgroundColor: UIColor, borderColor: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(borderColor, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.backgroundColor = backgroundColor
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1.5
        button.layer.borderColor = borderColor.cgColor
        
        button.addTarget(self, action: #selector(feedbackButtonTapped(_:)), for: .touchUpInside)
        button.tag = satisfaction
        
        return button
    }
    
    private func setupLayout() {
        NSLayoutConstraint.activate([
            // Container
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
            containerView.widthAnchor.constraint(lessThanOrEqualToConstant: 360),
            
            // Icon
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Message
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Benefit
            benefitLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 16),
            benefitLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            benefitLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Button Stack
            buttonStackView.topAnchor.constraint(equalTo: benefitLabel.bottomAnchor, constant: 24),
            buttonStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            buttonStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            buttonStackView.heightAnchor.constraint(equalToConstant: 44),
            
            // Skip Button
            buttonStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -64),
        ])
        
        // Padding for benefit label - UILabel에는 layoutMargins 직접 설정이 제한적이므로 수동 패딩 적용
        // 이미 텍스트 앞뒤로 공백을 추가하거나 constraints로 패딩 처리
    }
    
    // MARK: - Animations
    private func animatePresentation() {
        UIView.animate(
            withDuration: 0.4,
            delay: 0.1,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.2,
            options: [.curveEaseOut]
        ) {
            self.containerView.transform = .identity
            self.containerView.alpha = 1.0
        }
    }
    
    private func animateDismissal(completion: @escaping () -> Void) {
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: [.curveEaseIn]
        ) {
            self.containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            self.containerView.alpha = 0
            self.view.alpha = 0
        } completion: { _ in
            completion()
        }
    }
    
    // MARK: - Actions
    @objc private func feedbackButtonTapped(_ sender: UIButton) {
        let satisfaction = sender.tag
        
        // 햅틱 피드백
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // 버튼 애니메이션
        UIView.animate(withDuration: 0.1, animations: {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                sender.transform = .identity
            }
        }
        
        // 감사 메시지 표시 후 종료
        showThankYouMessage(satisfaction: satisfaction)
    }
    
    @objc private func skipButtonTapped() {
        animateDismissal {
            self.dismiss(animated: false)
        }
    }
    
    private func showThankYouMessage(satisfaction: Int) {
        let thankYouMessages = [
            "🙏 소중한 피드백 감사해요!\nAI가 더 똑똑해졌어요.",
            "💝 피드백 고마워요!\n앞으로 더 나은 추천을 드릴게요.",
            "✨ 의견 감사합니다!\n개인화 추천이 향상됐어요."
        ]
        
        let message = thankYouMessages.randomElement() ?? thankYouMessages[0]
        
        // UI 업데이트
        titleLabel.text = "감사합니다! 🎉"
        messageLabel.text = message
        benefitLabel.isHidden = true
        buttonStackView.isHidden = true
        
        // 피드백 콜백 호출
        onFeedbackProvided?(satisfaction)
        
        // 2초 후 자동 종료
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.animateDismissal {
                self.dismiss(animated: false)
            }
        }
    }
    
    // MARK: - Static Convenience Method
    static func present(
        from presentingViewController: UIViewController,
        presetName: String,
        recommendationType: RecommendationType,
        onFeedbackProvided: @escaping (Int) -> Void
    ) {
        let feedbackVC = FeedbackPromptViewController(
            presetName: presetName,
            recommendationType: recommendationType,
            onFeedbackProvided: onFeedbackProvided
        )
        
        feedbackVC.modalPresentationStyle = .overFullScreen
        feedbackVC.modalTransitionStyle = .crossDissolve
        
        presentingViewController.present(feedbackVC, animated: true)
    }
} 
