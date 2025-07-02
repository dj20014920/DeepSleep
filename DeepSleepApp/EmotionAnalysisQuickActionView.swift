import UIKit

protocol EmotionAnalysisQuickActionViewDelegate: AnyObject {
    func quickActionView(_ view: EmotionAnalysisQuickActionView, didSelectEmotion emotion: String)
}

final class EmotionAnalysisQuickActionView: UIView {
    // MARK: - Types
    struct QuickAction {
        let title: String
        let intent: String
        let icon: String
    }
    
    // MARK: - Properties
    private let actions: [QuickAction]
    var onActionSelected: ((QuickAction) -> Void)?
    weak var delegate: EmotionAnalysisQuickActionViewDelegate?
    
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    // MARK: - Initialization
    init(actions: [QuickAction] = EmotionAnalysisQuickActionView.defaultActions) {
        self.actions = actions
        super.init(frame: .zero)
        setupUI()
    }
    
    convenience init() {
        self.init(actions: EmotionAnalysisQuickActionView.defaultActions)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        actions.forEach { action in
            let button = createActionButton(for: action)
            stackView.addArrangedSubview(button)
        }
    }
    
    private func createActionButton(for action: QuickAction) -> UIButton {
        let button = UIButton(type: .system)
        
        // iOS 15 이상에서는 Configuration 사용
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.title = action.title
            config.image = UIImage(systemName: action.icon)
            config.imagePadding = 8
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
            config.background.backgroundColor = .systemBlue.withAlphaComponent(0.1)
            button.configuration = config
        } else {
            button.setTitle(action.title, for: .normal)
            button.setImage(UIImage(systemName: action.icon), for: .normal)
            button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
            button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
            button.backgroundColor = .systemBlue.withAlphaComponent(0.1)
        }
        
        button.setTitleColor(.systemBlue, for: .normal)
        button.tintColor = .systemBlue
        button.layer.cornerRadius = 8
        button.titleLabel?.font = .systemFont(ofSize: 14)
        
        // 액션 추가
        button.addAction(UIAction { [weak self] _ in
            self?.onActionSelected?(action)
        }, for: .touchUpInside)
        
        return button
    }
    
    // MARK: - Public Methods
    func updateActions(_ newActions: [QuickAction]) {
        // 기존 버튼들 제거
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // 새 버튼들 추가
        newActions.forEach { action in
            let button = createActionButton(for: action)
            stackView.addArrangedSubview(button)
        }
    }
}

// MARK: - Default Actions
extension EmotionAnalysisQuickActionView {
    static var defaultActions: [QuickAction] {
        [
            QuickAction(title: "🎯 개선 방법이 궁금해요", intent: "improvement_tips", icon: "arrow.up.circle"),
            QuickAction(title: "📈 감정 변화 추이 설명해주세요", intent: "trend_analysis", icon: "chart.line.uptrend.xyaxis"),
            QuickAction(title: "💡 스트레스 관리 조언 주세요", intent: "stress_management", icon: "brain.head.profile"),
            QuickAction(title: "🧠 AI 추천받기", intent: "ai_recommendation", icon: "sparkles"),
            QuickAction(title: "🏠 로컬 추천받기", intent: "local_recommendation", icon: "house")
        ]
    }
}

// MARK: - Accessibility
extension EmotionAnalysisQuickActionView {
    override var accessibilityElements: [Any]? {
        get { stackView.arrangedSubviews }
        set { }
    }
} 