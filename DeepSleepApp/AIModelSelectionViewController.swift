import UIKit

/// 🌳 대나무숲 친구 선택 화면
/// 모델별 설명과 버블블록체크 형식의 UI로 AI 친구를 선택하는 화면
class AIModelSelectionViewController: UIViewController {
    
    // MARK: - Properties
    
    var currentSelectedModel: AIModelType = .claude35
    var onModelSelected: ((AIModelType) -> Void)?
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    
    private var modelCards: [AIModelCardView] = []
    
    // 헤더 컴포넌트
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    // 확인 버튼
    private let confirmButton = UIButton(type: .system)
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigation()
        createModelCards()
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        
        // 스크롤뷰 설정
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // 스택뷰 설정
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .fill
        contentView.addSubview(stackView)
        
        // 헤더 설정
        setupHeader()
        
        // 확인 버튼 설정
        setupConfirmButton()
        
        // 제약조건 설정
        setupConstraints()
    }
    
    private func setupNavigation() {
        title = "대나무숲 친구 선택"
        navigationController?.navigationBar.prefersLargeTitles = false
        
        // 닫기 버튼
        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
        )
        navigationItem.leftBarButtonItem = closeButton
    }
    
    private func setupHeader() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        // 타이틀
        titleLabel.text = "🌸 대나무숲에 살고 있는 친구들을 소개할게요!"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = UIDesignSystem.Colors.primaryText
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 서브타이틀
        subtitleLabel.text = "각자의 특별한 재능으로 당신을 도와줄 거예요. 대화하고 싶은 친구를 선택해주세요 ✨"
        subtitleLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textColor = UIDesignSystem.Colors.secondaryText
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor)
        ])
        
        stackView.addArrangedSubview(headerView)
    }
    
    private func setupConfirmButton() {
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.setTitle("이 친구와 대화하기", for: .normal)
        confirmButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        confirmButton.backgroundColor = UIDesignSystem.Colors.accent
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.layer.cornerRadius = 25
        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
        
        // 그림자 효과
        confirmButton.layer.shadowColor = UIDesignSystem.Colors.accent.cgColor
        confirmButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        confirmButton.layer.shadowRadius = 8
        confirmButton.layer.shadowOpacity = 0.3
        
        view.addSubview(confirmButton)
    }
    
    private func createModelCards() {
        // AI 모델 정보
        let models = [
            (
                type: AIModelType.gemini,
                personality: "자유롭고 창의적인 성격",
                specialties: ["상상력 풍부한 조언", "예술적 표현", "새로운 관점", "재미있는 대화"],
                strengths: "독특하고 창의적인 시각으로 새로운 해결책을 제시해요",
                bestFor: "창의적 고민, 예술적 영감, 색다른 관점",
            ),
            (
                type: AIModelType.gpt4,
                personality: "밝고 적극적인 성격",
                specialties: ["빠른 분석", "실용적 조언", "목표 설정", "동기부여"],
                strengths: "신속하고 명확한 답변으로 즉시 도움을 드려요",
                bestFor: "빠른 상담, 일상 조언, 스트레스 해소",
            ),
            (
                type: AIModelType.naver,
                personality: "정겨우면서도 현실적인 성격",
                specialties: ["한국 문화 이해", "현실적 조언", "공감 대화", "진솔한 소통"],
                strengths: "한국인의 정서와 문화를 깊이 이해하며 현실적인 조언을 드려요",
                bestFor: "한국적 고민, 사회생활 조언, 인간관계 상담",
            ),
            (
                type: AIModelType.claude35,
                personality: "차분하고 사려깊은 성격",
                specialties: ["깊이 있는 대화", "감정 분석", "창의적 문제해결", "윤리적 조언"],
                strengths: "복잡한 감정을 세심하게 이해하고, 장문의 일기도 꼼꼼히 분석해요",
                bestFor: "진지한 고민 상담, 감정 정리, 인생 조언",
            )
        ]
        
        // 각 모델에 대한 카드 생성
        for modelInfo in models {
            let card = AIModelCardView(
                model: modelInfo.type,
                personality: modelInfo.personality,
                specialties: modelInfo.specialties,
                strengths: modelInfo.strengths,
                bestFor: modelInfo.bestFor
            )
            card.isSelected = (modelInfo.type == currentSelectedModel)
            card.onTap = { [weak self] in
                self?.selectModel(modelInfo.type)
            }
            
            modelCards.append(card)
            stackView.addArrangedSubview(card)
        }
        
        // 하단 여백
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 100).isActive = true
        stackView.addArrangedSubview(spacer)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // ContentView
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // StackView
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Confirm Button
            confirmButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            confirmButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            confirmButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - Actions
    
    private func selectModel(_ model: AIModelType) {
        // 모든 카드의 선택 상태 업데이트
        for card in modelCards {
            card.isSelected = (card.model == model)
        }
        
        currentSelectedModel = model
        
        // 버튼 애니메이션
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.confirmButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                self.confirmButton.transform = .identity
            }
        }
    }
    
    @objc private func confirmButtonTapped() {
        onModelSelected?(currentSelectedModel)
        dismiss(animated: true)
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
}

// MARK: - AI Model Card View

/// 개별 AI 모델 카드 뷰
class AIModelCardView: UIView {
    
    // MARK: - Properties
    
    let model: AIModelType
    var isSelected: Bool = false {
        didSet {
            updateSelectionState()
        }
    }
    var onTap: (() -> Void)?
    
    // UI Components
    private let containerView = UIView()
    private let checkboxView = UIView()
    private let checkmarkImageView = UIImageView()
    private let contentStackView = UIStackView()
    
    private let headerStackView = UIStackView()
    private let iconLabel = UILabel()
    private let nameLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    private let personalityLabel = UILabel()
    private let specialtiesContainer = UIView()
    private let strengthsLabel = UILabel()
    private let bestForLabel = UILabel()
    
    // Data
    private let personality: String
    private let specialties: [String]
    private let strengths: String
    private let bestFor: String
    
    // MARK: - Initialization
    
    init(model: AIModelType, personality: String, specialties: [String], strengths: String, bestFor: String) {
        self.model = model
        self.personality = personality
        self.specialties = specialties
        self.strengths = strengths
        self.bestFor = bestFor
        
        super.init(frame: .zero)
        setupUI()
        setupGesture()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        // Container View
        containerView.backgroundColor = UIDesignSystem.Colors.cardBackground
        containerView.layer.cornerRadius = 20
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 12
        containerView.layer.shadowOpacity = 0.08
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        // Checkbox (버블블록 체크박스)
        checkboxView.backgroundColor = UIDesignSystem.Colors.adaptiveTertiaryBackground
        checkboxView.layer.cornerRadius = 12
        checkboxView.layer.borderWidth = 2
        checkboxView.layer.borderColor = UIDesignSystem.Colors.border.cgColor
        checkboxView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(checkboxView)
        
        // Checkmark
        checkmarkImageView.image = UIImage(systemName: "checkmark")
        checkmarkImageView.tintColor = .white
        checkmarkImageView.contentMode = .scaleAspectFit
        checkmarkImageView.alpha = 0
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        checkboxView.addSubview(checkmarkImageView)
        
        // Content Stack View
        contentStackView.axis = .vertical
        contentStackView.spacing = 16
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(contentStackView)
        
        // Header
        setupHeader()
        
        // Content
        setupContent()
        
        // Constraints
        setupConstraints()
    }
    
    private func setupHeader() {
        headerStackView.axis = .horizontal
        headerStackView.spacing = 12
        headerStackView.alignment = .center
        
        // Icon
        iconLabel.text = model.icon
        iconLabel.font = UIFont.systemFont(ofSize: 40)
        
        // Name and Subtitle Stack
        let nameStackView = UIStackView()
        nameStackView.axis = .vertical
        nameStackView.spacing = 4
        
        nameLabel.text = model.displayName
        nameLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        nameLabel.textColor = UIDesignSystem.Colors.primaryText
        
        subtitleLabel.text = model.description
        subtitleLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        subtitleLabel.textColor = UIDesignSystem.Colors.accent
        
        nameStackView.addArrangedSubview(nameLabel)
        nameStackView.addArrangedSubview(subtitleLabel)
        
        headerStackView.addArrangedSubview(iconLabel)
        headerStackView.addArrangedSubview(nameStackView)
        headerStackView.addArrangedSubview(UIView()) // Spacer
        
        contentStackView.addArrangedSubview(headerStackView)
    }
    
    private func setupContent() {
        
        
        let specialtiesFlowLayout = UIView()
        specialtiesFlowLayout.translatesAutoresizingMaskIntoConstraints = false
        setupSpecialtiesTags(in: specialtiesFlowLayout)
        contentStackView.addArrangedSubview(specialtiesFlowLayout)
        // 성격
        personalityLabel.attributedText = createAttributedText(title: "성격", content: personality)
        personalityLabel.numberOfLines = 0
        contentStackView.addArrangedSubview(personalityLabel)
        // 특별한 장점
        strengthsLabel.attributedText = createAttributedText(title: "특별한 장점", content: strengths)
        strengthsLabel.numberOfLines = 0
        contentStackView.addArrangedSubview(strengthsLabel)
        
        // 추천 상황
        bestForLabel.attributedText = createAttributedText(title: "이럴 때 추천", content: bestFor)
        bestForLabel.numberOfLines = 0
        contentStackView.addArrangedSubview(bestForLabel)
        
        
        
    }
    
    private func setupSpecialtiesTags(in container: UIView) {
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        let spacing: CGFloat = 8
        let lineHeight: CGFloat = 32
        
        for specialty in specialties {
            let tag = createTag(text: specialty)
            container.addSubview(tag)
            
            // 태그 크기 계산
            let size = tag.sizeThatFits(CGSize(width: .greatestFiniteMagnitude, height: lineHeight))
            
            // 줄바꿈 체크
            if currentX + size.width > UIScreen.main.bounds.width*0.95 {
                currentX = 0
                currentY += lineHeight + spacing
            }
            
            tag.frame = CGRect(x: currentX, y: currentY, width: size.width, height: lineHeight)
            currentX += size.width + spacing
        }
        
        container.heightAnchor.constraint(equalToConstant: currentY + lineHeight).isActive = true
    }
    
    private func createTag(text: String) -> UIView {
        let container = UIView()
        container.backgroundColor = UIDesignSystem.Colors.tagBackground
        container.layer.cornerRadius = 16
        
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIDesignSystem.Colors.secondaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12)
        ])
        
        return container
    }
    
    private func createAttributedText(title: String, content: String, isQuote: Bool = false) -> NSAttributedString {
        let attributedString = NSMutableAttributedString()
        
        // 타이틀
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIDesignSystem.Colors.primaryText
        ]
        attributedString.append(NSAttributedString(string: "• \(title): ", attributes: titleAttributes))
        
        // 내용
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: isQuote ? .medium : .regular),
            .foregroundColor: isQuote ? UIDesignSystem.Colors.accent : UIDesignSystem.Colors.secondaryText
        ]
        attributedString.append(NSAttributedString(string: content, attributes: contentAttributes))
        
        return attributedString
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Checkbox
            checkboxView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            checkboxView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            checkboxView.widthAnchor.constraint(equalToConstant: 24),
            checkboxView.heightAnchor.constraint(equalToConstant: 24),
            
            // Checkmark
            checkmarkImageView.centerXAnchor.constraint(equalTo: checkboxView.centerXAnchor),
            checkmarkImageView.centerYAnchor.constraint(equalTo: checkboxView.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 16),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 16),
            
            // Content
            contentStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            contentStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            contentStackView.trailingAnchor.constraint(equalTo: checkboxView.leadingAnchor, constant: -16),
            contentStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24)
        ])
    }
    
    private func setupGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Actions
    
    @objc private func handleTap() {
        onTap?()
    }
    
    private func updateSelectionState() {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            if self.isSelected {
                self.containerView.layer.borderWidth = 2
                self.containerView.layer.borderColor = UIDesignSystem.Colors.accent.cgColor
                self.containerView.backgroundColor = UIDesignSystem.Colors.accentLight
                
                self.checkboxView.backgroundColor = UIDesignSystem.Colors.accent
                self.checkboxView.layer.borderColor = UIDesignSystem.Colors.accent.cgColor
                self.checkmarkImageView.alpha = 1
                
                self.containerView.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
            } else {
                self.containerView.layer.borderWidth = 0
                self.containerView.backgroundColor = UIDesignSystem.Colors.cardBackground
                
                self.checkboxView.backgroundColor = UIDesignSystem.Colors.adaptiveTertiaryBackground
                self.checkboxView.layer.borderColor = UIDesignSystem.Colors.border.cgColor
                self.checkmarkImageView.alpha = 0
                
                self.containerView.transform = .identity
            }
        }
    }
}
