import UIKit

/// 📋 스텁 뷰컨트롤러들 (향후 구현 예정)
/// 설정 화면에서 네비게이션하는 하위 뷰컨트롤러들의 임시 구현

// MARK: - Model Characteristics ViewController

/// 🤖 대나무숲 친구들 특성 보기 화면
class ModelCharacteristicsViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    
    // 대나무숲 친구들 정보
    private let aiModels = [
        AIModelInfo(
            name: "🌸 클로드",
            subtitle: "철학자이자 감정 전문가",
            personality: "차분하고 사려깊은 성격",
            specialties: ["깊이 있는 대화", "감정 분석", "창의적 문제해결", "윤리적 조언"],
            strengths: "복잡한 감정을 세심하게 이해하고, 장문의 일기도 꼼꼼히 분석해요",
            bestFor: "진지한 고민 상담, 감정 정리, 인생 조언"
        ),
        AIModelInfo(
            name: "⚡ 지피티",
            subtitle: "활발한 문제해결사",
            personality: "밝고 적극적인 성격",
            specialties: ["빠른 분석", "실용적 조언", "목표 설정", "동기부여"],
            strengths: "신속하고 명확한 답변으로 즉시 도움을 드려요",
            bestFor: "빠른 상담, 일상 조언, 스트레스 해소"
        ),
        AIModelInfo(
            name: "💎 제미니",
            subtitle: "창의적인 예술가",
            personality: "자유롭고 창의적인 성격",
            specialties: ["상상력 풍부한 조언", "예술적 표현", "새로운 관점", "재미있는 대화"],
            strengths: "독특하고 창의적인 시각으로 새로운 해결책을 제시해요",
            bestFor: "창의적 고민, 예술적 영감, 색다른 관점"
        ),
        AIModelInfo(
            name: "🇰🇷 하이퍼클로바",
            subtitle: "따뜻한 한국 친구",
            personality: "정겨우면서도 현실적인 성격",
            specialties: ["한국 문화 이해", "현실적 조언", "공감 대화", "진솔한 소통"],
            strengths: "한국인의 정서와 문화를 깊이 이해하며 현실적인 조언을 드려요",
            bestFor: "한국적 고민, 사회생활 조언, 인간관계 상담"
        )
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupContent()
    }
    
    private func setupUI() {
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        title = "🌸 대나무숲 친구들"
        
        // 스크롤뷰 설정
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.distribution = .fill
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupContent() {
        // 헤더 추가
        let headerView = createHeaderView()
        stackView.addArrangedSubview(headerView)
        
        // 각 AI 모델 카드 추가
        for model in aiModels {
            let modelCard = createModelCard(model: model)
            stackView.addArrangedSubview(modelCard)
        }
        
        // 푸터 추가
        let footerView = createFooterView()
        stackView.addArrangedSubview(footerView)
    }
    
    private func createHeaderView() -> UIView {
        let containerView = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = "🌸 대나무숲에 살고 있는 네 친구들을 소개할게요!"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = UIDesignSystem.Colors.primaryText
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "각자의 특별한 재능으로 당신을 도와줄 거예요 ✨"
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = UIDesignSystem.Colors.secondaryText
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
    
    private func createModelCard(model: AIModelInfo) -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = UIDesignSystem.Colors.cardBackground
        cardView.layer.cornerRadius = 16
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowRadius = 8
        cardView.layer.shadowOpacity = 0.1
        
        let cardStackView = UIStackView()
        cardStackView.axis = .vertical
        cardStackView.spacing = 12
        cardStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // 이름과 부제목
        let nameLabel = UILabel()
        nameLabel.text = model.name
        nameLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        nameLabel.textColor = UIDesignSystem.Colors.primaryText
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = model.subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = UIDesignSystem.Colors.accent
        
        // 성격
        let personalityLabel = createInfoLabel(title: "성격", content: model.personality)
        
        // 전문분야
        let specialtiesText = model.specialties.joined(separator: " • ")
        let specialtiesLabel = createInfoLabel(title: "전문분야", content: specialtiesText)
        
        // 장점
        let strengthsLabel = createInfoLabel(title: "특별한 장점", content: model.strengths)
        
        // 추천 상황
        let bestForLabel = createInfoLabel(title: "이럴 때 추천", content: model.bestFor)
                
        cardStackView.addArrangedSubview(nameLabel)
        cardStackView.addArrangedSubview(subtitleLabel)
        cardStackView.addArrangedSubview(personalityLabel)
        cardStackView.addArrangedSubview(specialtiesLabel)
        cardStackView.addArrangedSubview(strengthsLabel)
        cardStackView.addArrangedSubview(bestForLabel)
        
        cardView.addSubview(cardStackView)
        
        NSLayoutConstraint.activate([
            cardStackView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            cardStackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            cardStackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            cardStackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20)
        ])
        
        return cardView
    }
    
    private func createInfoLabel(title: String, content: String, isQuote: Bool = false) -> UIView {
        let containerView = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = "• \(title):"
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = UIDesignSystem.Colors.primaryText
        
        let contentLabel = UILabel()
        contentLabel.text = content
        contentLabel.font = UIFont.systemFont(ofSize: 13, weight: isQuote ? .medium : .regular)
        contentLabel.textColor = isQuote ? UIDesignSystem.Colors.accent : UIDesignSystem.Colors.secondaryText
        contentLabel.numberOfLines = 0
        
        if isQuote {
            contentLabel.layer.cornerRadius = 8
            contentLabel.backgroundColor = UIDesignSystem.Colors.accent.withAlphaComponent(0.1)
            contentLabel.layer.masksToBounds = true
        }
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(contentLabel)
        
        let titleWidthConstraint = titleLabel.widthAnchor.constraint(equalToConstant: 80)
        titleWidthConstraint.priority = UILayoutPriority(999)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleWidthConstraint,
            
            contentLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            contentLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            contentLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            contentLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        if isQuote {
            contentLabel.textInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        }
        
        return containerView
    }
    
    private func createFooterView() -> UIView {
        let containerView = UIView()
        
        let footerLabel = UILabel()
        footerLabel.text = "💡 설정에서 언제든지 기본 친구를 바꿀 수 있어요!\n대화 중에도 친구를 바꿔가며 이야기해보세요."
        footerLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        footerLabel.textColor = UIDesignSystem.Colors.secondaryText
        footerLabel.textAlignment = .center
        footerLabel.numberOfLines = 0
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(footerLabel)
        
        NSLayoutConstraint.activate([
            footerLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            footerLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            footerLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            footerLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
}

// MARK: - AI Model Info Structure
private struct AIModelInfo {
    let name: String
    let subtitle: String
    let personality: String
    let specialties: [String]
    let strengths: String
    let bestFor: String
}

// MARK: - UILabel Extension for Padding
private extension UILabel {
    var textInsets: UIEdgeInsets {
        get { return UIEdgeInsets.zero }
        set {
            layer.cornerRadius = 8
            layer.masksToBounds = true
            // 패딩 효과를 위한 attributed string 설정
            if let text = text {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.firstLineHeadIndent = newValue.left
                paragraphStyle.headIndent = newValue.left
                paragraphStyle.tailIndent = -newValue.right
                
                let attributedText = NSMutableAttributedString(string: text)
                attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: text.count))
                self.attributedText = attributedText
            }
        }
    }
}

// MARK: - User Info ViewControllers
// UserBasicInfoViewController는 별도 파일로 구현됨
// UsageAnalyticsViewController는 별도 파일로 구현됨

// MARK: - App Settings ViewControllers

/// 🔔 알림 설정 화면
class NotificationSettingsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        title = "알림 설정"
        
        let label = UILabel()
        label.text = "🚧 구현 예정\n\n푸시 알림, 수면 리마인더,\n감정 체크 알림 등을\n설정하는 화면"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIDesignSystem.Colors.secondaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])
    }
}

/// 🎨 테마 설정 화면
class ThemeSettingsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        title = "테마 설정"
        
        let label = UILabel()
        label.text = "🚧 구현 예정\n\n다크모드, 라이트모드,\n색상 테마, 폰트 크기 등을\n설정하는 화면"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIDesignSystem.Colors.secondaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])
    }
}

/// 💬 피드백 화면
class FeedbackViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        title = "개발자 피드백"
        
        let label = UILabel()
        label.text = "🚧 구현 예정\n\n앱 개선사항, 버그 리포트,\n기능 요청 등을 보내는 화면"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIDesignSystem.Colors.secondaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])
    }
}

/// 📜 개인정보 처리방침 화면
class PrivacyPolicyViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        title = "개인정보 처리방침"
        
        let label = UILabel()
        label.text = "🚧 구현 예정\n\n개인정보 처리방침,\n데이터 보호 정책,\n약관 등을 보여주는 화면"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIDesignSystem.Colors.secondaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])
    }
}
// StorageManagementViewController는 별도 파일에 정의되어 있음
/*
/// 💾 저장소 관리 화면
class StorageManagementViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        title = "저장소 관리"
        
        let label = UILabel()
        label.text = "🚧 구현 예정\n\n앱 데이터 사용량,\n캐시 정리, 백업/복원\n등을 관리하는 화면"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIDesignSystem.Colors.secondaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])
    }
}}
*/
