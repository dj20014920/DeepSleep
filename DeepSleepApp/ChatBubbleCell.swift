import UIKit
import Foundation

// MARK: - ChatBubbleCell Implementation

// MARK: - ✅ GIF 고양이 뷰
class GifCatView: UIView {
    private let imageView = UIImageView()
    private var catDirection: CGFloat = 1
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupImageView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupImageView()
    }
    
    private func setupImageView() {
        // 이미지뷰 설정
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = .clear
        addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // GIF 로드
        setupGifCat()
    }
    
    func setupGifCat() {
        
        // 기존 애니메이션 정지
        imageView.stopAnimating()
        imageView.animationImages = nil
        
        // 1차: Bundle.main.path 방법들
        let searchMethods = [
            ("Bundle 루트", { Bundle.main.path(forResource: "cat", ofType: "gif") }),
            ("Bundle URL", { Bundle.main.url(forResource: "cat", withExtension: "gif")?.path }),
            ("Bundle with extension", { Bundle.main.path(forResource: "cat.gif", ofType: nil) })
        ]
        
        for (method, pathFunc) in searchMethods {
            if let gifPath = pathFunc() {
                if loadGifFromPath(gifPath) {
                    return
                }
            } else {
                print("❌ \(method) 실패")
            }
        }
        
        print("❌ Bundle에서 GIF 파일을 찾을 수 없음")
        // GIF 없으면 빈 상태로 두기
        imageView.backgroundColor = UIColor.clear
    }
    
    private func loadGifFromPath(_ path: String) -> Bool {
        guard let gifData = NSData(contentsOfFile: path),
              let source = CGImageSourceCreateWithData(gifData, nil) else {
            print("❌ GIF 데이터 로드 실패: \(path)")
            return false
        }
        
        var images: [UIImage] = []
        let count = CGImageSourceGetCount(source)
        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                images.append(UIImage(cgImage: cgImage))
            }
        }
        
        if !images.isEmpty {
            DispatchQueue.main.async {
                self.imageView.animationImages = images
                self.imageView.animationDuration = Double(images.count) * 0.1
                self.imageView.animationRepeatCount = 0
                self.imageView.startAnimating()
                self.imageView.contentMode = .scaleAspectFit
                self.imageView.backgroundColor = .clear
            }
            return true
        } else {
            print("❌ GIF 프레임 변환 실패")
            return false
        }
    }
     
     
     
     func updateDirection(_ direction: CGFloat) {
        catDirection = direction
        // 방향에 따라 고양이 뒤집기
        UIView.animate(withDuration: 0.2) {
            if direction < 0 {
                self.transform = CGAffineTransform(scaleX: -1, y: 1)
            } else {
                self.transform = CGAffineTransform.identity
            }
        }
    }
}

class ChatBubbleCell: UITableViewCell {
    static let identifier = "ChatBubbleCell"
    
    private var messageLabelBottomConstraint: NSLayoutConstraint!
    private var messageLabelToButtonConstraint: NSLayoutConstraint!
    private var applyButtonBottomConstraint: NSLayoutConstraint!
    private var applyButtonHeightConstraint: NSLayoutConstraint!
    private var optionStackBottomConstraint: NSLayoutConstraint!
    
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
        
        // ✅ 버블 크기 최적화: 텍스트 크기에 맞게 조정
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal) // 수평으로 꽉 차지 않도록
        label.setContentHuggingPriority(.defaultLow, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        
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
    
    // ✅ 로딩 애니메이션 관련 UI 컴포넌트들 (GIF 고양이로 변경)
    private let loadingContainer = UIView()
    private let gifCatView = GifCatView() // GIF 고양이
    private let loadingTextLabel = UILabel()
    private let typingDotsLabel = UILabel()
    private let thinkingLabel = UILabel() // 생각중... 텍스트
    
    // ✅ 애니메이션 관련 프로퍼티들
    private var catAnimationTimer: Timer?
    private var typingDotsTimer: Timer?
    private var currentCatPosition: CGFloat = 0
    private var catDirection: CGFloat = 1
    private var dotCount = 0
    
    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    
    private var applyAction: (() -> Void)?
    
    // ✅ 옵션 액션들을 저장할 프로퍼티들
    private var saveAction: (() -> Void)?
    private var feedbackAction: (() -> Void)?
    private var goToMainAction: (() -> Void)?
    private var continueAction: (() -> Void)?
    
    // ✅ 가르치기 액션을 위한 클로저 추가
    var teachAction: ((String) -> Void)?
    private var originalUserMessageForTeachable: String?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        setupGestureRecognizers() // 제스처 초기화 호출
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
        
        // ✅ 로딩 컨테이너 설정
        bubbleView.addSubview(loadingContainer)
        loadingContainer.addSubview(gifCatView)
        loadingContainer.addSubview(loadingTextLabel)
        loadingContainer.addSubview(typingDotsLabel)
        loadingContainer.addSubview(thinkingLabel)
        
        bubbleView.layer.cornerRadius = 12
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        optionButtonStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // ✅ 로딩 관련 컴포넌트들 설정
        loadingContainer.translatesAutoresizingMaskIntoConstraints = false
        gifCatView.translatesAutoresizingMaskIntoConstraints = false
        loadingTextLabel.translatesAutoresizingMaskIntoConstraints = false
        typingDotsLabel.translatesAutoresizingMaskIntoConstraints = false
        thinkingLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // ✅ GIF 고양이 뷰 설정
        gifCatView.backgroundColor = .clear
        
        // ✅ 로딩 텍스트 라벨 설정 (숨김)
        loadingTextLabel.isHidden = true
        
        // ✅ 타이핑 텍스트 라벨 설정 (Claude 스타일)
        typingDotsLabel.text = "생각 중▊"
        typingDotsLabel.font = .systemFont(ofSize: 11, weight: .regular)
        typingDotsLabel.textColor = .systemGray
        typingDotsLabel.textAlignment = .left
        
        // ✅ 생각중 라벨 설정
        thinkingLabel.text = "생각중..."
        thinkingLabel.font = .systemFont(ofSize: 14, weight: .medium)
        thinkingLabel.textColor = .systemGray
        thinkingLabel.textAlignment = .left
        thinkingLabel.alpha = 0 // 처음에는 숨김
        
        // 제약 조건 설정
        messageLabelBottomConstraint = messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8)
        applyButtonHeightConstraint = applyButton.heightAnchor.constraint(equalToConstant: 32)
        messageLabelToButtonConstraint = applyButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 12)
        applyButtonBottomConstraint = applyButton.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12)
        optionStackBottomConstraint = optionButtonStackView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -16)

        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            messageLabelBottomConstraint,
            
            applyButton.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            applyButton.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            applyButtonHeightConstraint,
            
            // ✅ 옵션 버튼 스택뷰 제약 조건 - 챗 버블 전체 너비에 맞게 확장
            optionButtonStackView.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 12),
            optionButtonStackView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            optionButtonStackView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16)
        ])

        // ✅ 로딩 컨테이너 제약조건 (2배 크게 + 생각중 텍스트) - bottomAnchor 제거로 다른 버블에 영향 안 줌
        NSLayoutConstraint.activate([
            loadingContainer.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 2),
            loadingContainer.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            loadingContainer.widthAnchor.constraint(equalToConstant: 200),
            loadingContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
            // ✅ bottomAnchor 제거 - 다른 버블에 영향주지 않도록
            
            gifCatView.leadingAnchor.constraint(equalTo: loadingContainer.leadingAnchor),
            gifCatView.topAnchor.constraint(equalTo: loadingContainer.topAnchor, constant: 0),
            gifCatView.widthAnchor.constraint(equalToConstant: 48),
            gifCatView.heightAnchor.constraint(equalToConstant: 48),
            
            thinkingLabel.leadingAnchor.constraint(equalTo: loadingContainer.leadingAnchor),
            thinkingLabel.topAnchor.constraint(equalTo: gifCatView.bottomAnchor, constant: 2),
            thinkingLabel.trailingAnchor.constraint(lessThanOrEqualTo: loadingContainer.trailingAnchor, constant: -16)
        ])
        thinkingLabel.numberOfLines = 1
        thinkingLabel.lineBreakMode = .byTruncatingTail;
        
        // bubbleView 제약조건 복원 (우선순위 조정)
        leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        
        // 🔧 bubbleView의 bottom 제약조건 우선순위를 낮춰서 오토레이아웃 충돌 방지
        let bubbleBottomConstraint = bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2)
        bubbleBottomConstraint.priority = UILayoutPriority(999) // required보다 낮춤
        
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            bubbleBottomConstraint
        ])
        
        // 🔧 버블 크기 동적 조정: 최대 너비만 제한하고 최소 너비는 컨텐츠에 맞게
        let maxWidthConstraint = bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.85)
        let minWidthConstraint = bubbleView.widthAnchor.constraint(greaterThanOrEqualToConstant: 60) // 최소 너비
        
        // 초기 상태에서 로딩 컨테이너 숨김
        loadingContainer.isHidden = true
        
        maxWidthConstraint.priority = .required
        minWidthConstraint.priority = .required
        maxWidthConstraint.isActive = true
        minWidthConstraint.isActive = true
        
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)
    }

    private func setupGestureRecognizers() {
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        bubbleView.addGestureRecognizer(longPressGesture)
        bubbleView.isUserInteractionEnabled = true
    }
    
    @objc private func handleLongPress(gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let isUser = (leadingConstraint.isActive == false && trailingConstraint.isActive == true) ? true : false,
              !isUser, // AI 메시지인 경우에만 메뉴 표시
              let originalUserMessage = originalUserMessageForTeachable, // 가르칠 원본 메시지가 있을 때만
              !originalUserMessage.isEmpty
        else { return }
        
        becomeFirstResponder()
        
        let teachMenuItem = UIMenuItem(title: "가르치기", action: #selector(teachTapped))
        let copyMenuItem = UIMenuItem(title: "복사하기", action: #selector(copyTapped))
        
        UIMenuController.shared.menuItems = [teachMenuItem, copyMenuItem]
        UIMenuController.shared.showMenu(from: bubbleView, rect: bubbleView.bounds)
    }

    @objc private func teachTapped() {
        guard let originalUserMessage = originalUserMessageForTeachable else { return }
        teachAction?(originalUserMessage)
        resignFirstResponder()
    }

    @objc private func copyTapped() {
        UIPasteboard.general.string = messageLabel.text
        resignFirstResponder()
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return action == #selector(copyTapped) || action == #selector(teachTapped)
    }
    
    func configure(with message: ChatMessage) {
        // 초기화
        resetConstraints()
        applyButton.isHidden = true
        optionButtonStackView.isHidden = true // ✅ 옵션 스택뷰도 숨기기
        applyAction = nil
        clearOptionActions() // ✅ 옵션 액션들 초기화
        stopLoadingAnimation() // ✅ 기존 로딩 애니메이션 정지

        switch message.type {
        case .user:
            configureUserMessage(message.text)
        case .bot:
            configureBotMessage(message.text)
            // 🆕 퀵 액션이 있는 메시지인지 확인
            if let quickActions = message.quickActions {
                configureQuickActionButtons(quickActions)
            }
        case .aiResponse:
            configureBotMessage(message.text) // aiResponse도 봇 스타일로 표시
        case .loading: // ✅ 로딩 케이스 처리
            configureLoadingMessage()
        case .error:
            configureBotMessage(message.text) // 에러 메시지도 봇 스타일로 표시
        case .system: // 🆕 시스템 안내 메시지
            configureSystemMessage(message.text)
        case .presetRecommendation:
            configurePresetMessage(message.text) {
                message.onApplyPreset?()
            }
        case .recommendationSelector:
            configureRecommendationSelectorMessage(message.text)
            // 🆕 퀵 액션이 있는 메시지인지 확인
            if let quickActions = message.quickActions {
                configureQuickActionButtons(quickActions)
            }
        case .presetOptions:
            configureBotMessage(message.text) // 프리셋 옵션도 봇 스타일로 표시
        case .postPresetOptions:
            configureBotMessage(message.text) // 포스트 프리셋 옵션도 봇 스타일로 표시
        }
        
        // 애니메이션 효과 (로딩이 아닐 때만)
        if message.type == .loading {
            // 로딩일 때는 애니메이션 효과 없음
        } else {
            bubbleView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut], animations: {
                self.bubbleView.transform = .identity
            })
        }
    }
    
    private func resetConstraints() {
        leadingConstraint.isActive = false
        trailingConstraint.isActive = false
        messageLabelBottomConstraint.isActive = false
        messageLabelToButtonConstraint.isActive = false
        applyButtonBottomConstraint.isActive = false
        optionStackBottomConstraint.isActive = false
        
        // 🔧 제약조건 우선순위와 상수 초기화 (버블 크기 문제 해결)
        leadingConstraint.priority = .required
        trailingConstraint.priority = .required
        leadingConstraint.constant = 16
        trailingConstraint.constant = -16
        
        // 로딩 컨테이너 완전히 숨기기 및 상태 초기화
        loadingContainer.isHidden = true
        loadingContainer.alpha = 0
        messageLabel.isHidden = false
        
        // 로딩 애니메이션 정지
        stopLoadingAnimation()
        
        // 고양이 위치 및 상태 완전 초기화
        gifCatView.transform = .identity
        thinkingLabel.alpha = 0
        currentCatPosition = 0
        
        // 버블뷰 배경색 복원 (투명했을 수 있음)
        bubbleView.backgroundColor = .systemGray6
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
        // 로딩 컨테이너 완전히 숨기고 일반 메시지 표시
        loadingContainer.isHidden = true
        loadingContainer.alpha = 0
        messageLabel.isHidden = false
        
        // 사용자 메시지 스타일 - 다크모드에서 보라색 계열
        let userMessageColor = UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.systemPurple.withAlphaComponent(0.8)
            default:
                return UIColor.systemBlue.withAlphaComponent(0.8)
            }
        }
        
        bubbleView.backgroundColor = userMessageColor
        messageLabel.textColor = .white
        messageLabel.text = text
        messageLabel.font = .systemFont(ofSize: 16, weight: .regular)
        
        // 🔧 오른쪽 정렬 + 텍스트 크기에 맞는 버블
        trailingConstraint.priority = .required
        trailingConstraint.isActive = true
        
        // 짧은 텍스트일 때 leading constraint를 낮은 우선순위로 설정
        let isShortText = text.count <= 10
        if isShortText {
            // 짧은 텍스트: 오른쪽에서만 고정, 왼쪽은 유동적
            leadingConstraint.priority = .init(250) // 낮은 우선순위
            leadingConstraint.constant = 100 // 더 많이 들여쓰기
            leadingConstraint.isActive = true
        }
        
        messageLabelBottomConstraint.isActive = true
        
        // 그라데이션 효과 (다크모드에서 보라색)
        let gradientColor1 = UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.systemPurple.withAlphaComponent(0.8)
            default:
                return UIColor.systemBlue.withAlphaComponent(0.8)
            }
        }
        
        let gradientColor2 = UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.systemPurple.withAlphaComponent(0.6)
            default:
                return UIColor.systemBlue.withAlphaComponent(0.6)
            }
        }
        
        addGradientToBubble(colors: [
            gradientColor1.cgColor,
            gradientColor2.cgColor
        ])
    }
    
    private func configureBotMessage(_ text: String) {
        // 로딩 컨테이너 완전히 숨기고 일반 메시지 표시
        loadingContainer.isHidden = true
        loadingContainer.alpha = 0
        messageLabel.isHidden = false
        
        // AI 메시지 스타일 - 다크모드 호환
        bubbleView.backgroundColor = UIDesignSystem.Colors.adaptiveTertiaryBackground
        messageLabel.textColor = UIDesignSystem.Colors.primaryText
        messageLabel.text = text
        messageLabel.font = .systemFont(ofSize: 16, weight: .regular)
        
        // 🔧 AI 메시지 왼쪽 정렬 확실히 하기
        messageLabel.textAlignment = .left  // 명시적으로 왼쪽 정렬
        
        // 🔧 왼쪽 정렬 + 텍스트 크기에 맞는 버블
        leadingConstraint.priority = .required
        leadingConstraint.isActive = true
        
        // 짧은 텍스트일 때 trailing constraint를 낮은 우선순위로 설정
        let isShortText = text.count <= 10
        if isShortText {
            // 짧은 텍스트: 왼쪽에서만 고정, 오른쪽은 유동적
            trailingConstraint.priority = .init(250) // 낮은 우선순위
            trailingConstraint.constant = -100 // 더 많이 들여쓰기
            trailingConstraint.isActive = true
        }
        
        messageLabelBottomConstraint.isActive = true
        
        // 부드러운 그림자
        bubbleView.layer.shadowColor = UIColor.black.cgColor
        bubbleView.layer.shadowOffset = CGSize(width: 0, height: 1)
        bubbleView.layer.shadowOpacity = 0.05
        bubbleView.layer.shadowRadius = 3
    }
    
    private func configureSystemMessage(_ text: String) {
        // 로딩 컨테이너 완전히 숨기고 일반 메시지 표시
        loadingContainer.isHidden = true
        loadingContainer.alpha = 0
        messageLabel.isHidden = false
        
        // 시스템 메시지 스타일 - 중앙 정렬, 연한 색상
        bubbleView.backgroundColor = UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.systemYellow.withAlphaComponent(0.2)
            default:
                return UIColor.systemYellow.withAlphaComponent(0.1)
            }
        }
        
        messageLabel.textColor = UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.systemYellow
            default:
                return UIColor.systemOrange
            }
        }
        messageLabel.text = text
        messageLabel.font = .systemFont(ofSize: 15, weight: .medium)
        messageLabel.textAlignment = .center
        
        // 중앙 정렬을 위해 양쪽 여백을 동일하게
        leadingConstraint.constant = 40
        trailingConstraint.constant = -40
        leadingConstraint.isActive = true
        trailingConstraint.isActive = true
        messageLabelBottomConstraint.isActive = true
    }
    
    private func configurePresetMessage(_ text: String, applyAction: @escaping () -> Void) {
        messageLabel.text = text
        messageLabel.textColor = UIDesignSystem.Colors.primaryText
        messageLabel.font = .systemFont(ofSize: 16, weight: .regular)
        
        // 프리셋 추천만의 특별한 색상 적용
        bubbleView.backgroundColor = UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.systemPurple.withAlphaComponent(0.2) // 다크모드에서 보라색 계열
            default:
                return UIColor.systemPurple.withAlphaComponent(0.1) // 라이트모드에서 연한 보라색
            }
        }
        
        applyButton.setTitle("🎵 바로 적용하기", for: .normal)
        applyButton.isHidden = false
        self.applyAction = {
            print("[ChatBubbleCell] 프리셋 적용 버튼 클릭됨")
            applyAction()
        }
        // 버튼 제약조건 활성화
        messageLabelBottomConstraint.isActive = false
        messageLabelToButtonConstraint.isActive = true
        applyButtonBottomConstraint.isActive = true
        leadingConstraint.isActive = true
    }
    
    // 🆕 추천 방식 선택창 스타일 (프리셋 추천과 똑같은 색상)
    private func configureRecommendationSelectorMessage(_ text: String) {
        // 로딩 컨테이너 완전히 숨기고 일반 메시지 표시
        loadingContainer.isHidden = true
        loadingContainer.alpha = 0
        messageLabel.isHidden = false
        
        messageLabel.text = text
        messageLabel.textColor = UIDesignSystem.Colors.primaryText
        messageLabel.font = .systemFont(ofSize: 16, weight: .regular)
        
        // 프리셋 추천과 똑같은 보라색 배경 적용
        bubbleView.backgroundColor = UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.systemPurple.withAlphaComponent(0.2) // 다크모드에서 보라색 계열
            default:
                return UIColor.systemPurple.withAlphaComponent(0.1) // 라이트모드에서 연한 보라색
            }
        }
        
        // 왼쪽 정렬
        leadingConstraint.isActive = true
        messageLabelBottomConstraint.isActive = true
        
        // 부드러운 그림자
        bubbleView.layer.shadowColor = UIColor.systemPurple.cgColor
        bubbleView.layer.shadowOffset = CGSize(width: 0, height: 1)
        bubbleView.layer.shadowOpacity = 0.1
        bubbleView.layer.shadowRadius = 3
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
        
        // 애니메이션 완전 정지
        stopLoadingAnimation()
        
        // 레이어 정리
        bubbleView.layer.sublayers?.removeAll { $0 is CAGradientLayer }
        bubbleView.layer.shadowOpacity = 0
        applyButton.layer.removeAllAnimations()
        
        // 상태 초기화
        applyAction = nil
        applyButton.isHidden = true
        optionButtonStackView.isHidden = true
        clearOptionActions()
        
        // 고양이 상태 초기화
        gifCatView.transform = .identity
        thinkingLabel.alpha = 0
        currentCatPosition = 0
        loadingContainer.isHidden = true
        
        // GIF 재시작을 위한 리셋
        gifCatView.setupGifCat()
        
        optionButtonStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        optionButtonStackView.isHidden = true
    }
    
    // MARK: - ✅ 로딩 애니메이션 관련 함수들
    
    /// 로딩 애니메이션 시작
    func startLoadingAnimation() {
        loadingContainer.isHidden = false
        messageLabel.isHidden = true
        
        // 기존 텍스트들 숨기기
        typingDotsLabel.isHidden = true
        
        // "생각중..." 텍스트를 처음부터 표시
        thinkingLabel.alpha = 1.0
        
        startCatAnimation()
        // typingDotsAnimation은 제거 - thinkingLabel만 사용
    }
    
    /// 로딩 애니메이션 정지
    func stopLoadingAnimation() {
        loadingContainer.isHidden = true
        messageLabel.isHidden = false
        
        catAnimationTimer?.invalidate()
        typingDotsTimer?.invalidate()
        catAnimationTimer = nil
        typingDotsTimer = nil
        
        // 생각중 텍스트 초기화
        thinkingLabel.alpha = 0
        currentCatPosition = 0
        gifCatView.transform = .identity
    }
    
    /// 고양이 오른쪽으로 계속 이동 애니메이션 (답변이 올 때까지)
    private func startCatAnimation() {
        let moveDistance: CGFloat = 2.5 // 한번에 이동할 거리 (기존 5px의 절반)
        
        catAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] timer in
            guard let self = self else { 
                timer.invalidate()
                return 
            }
            
            // 현재 위치에서 계속 오른쪽으로 이동
            self.currentCatPosition += moveDistance
            
            // 부드러운 연속 애니메이션으로 위치 업데이트
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveLinear], animations: {
                self.gifCatView.transform = CGAffineTransform(translationX: self.currentCatPosition, y: 0)
            })
        }
    }
    
    /// 고양이가 멈춘 후 생각중 텍스트 표시 (더이상 사용하지 않음 - 처음부터 표시)
    private func showThinkingText() {
        // 이제 "생각중..." 텍스트는 애니메이션 시작과 함께 표시됨
        thinkingLabel.alpha = 1.0
    }
    
    /// 타이핑 효과 애니메이션 (Claude 스타일)
    private func startTypingDotsAnimation() {
        let phrases = ["생각 중", "분석 중", "응답 생성", "거의 완료"]
        var currentPhrase = ""
        var phraseIndex = 0
        var charIndex = 0
        
        typingDotsTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if charIndex < phrases[phraseIndex].count {
                // 글자 하나씩 추가
                let index = phrases[phraseIndex].index(phrases[phraseIndex].startIndex, offsetBy: charIndex)
                currentPhrase = String(phrases[phraseIndex].prefix(through: index))
                charIndex += 1
            } else {
                // 다음 문구로 이동
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    phraseIndex = (phraseIndex + 1) % phrases.count
                    charIndex = 0
                    currentPhrase = ""
                }
            }
            
            // 타이핑 커서 효과
            let cursor = charIndex % 2 == 0 ? "▊" : ""
            self.typingDotsLabel.text = currentPhrase + cursor
        }
    }
    
    // ✅ 로딩 메시지 구성 (큰 고양이 + 생각중 텍스트)
    private func configureLoadingMessage() {
        // 왼쪽 정렬 (AI 메시지 위치)
        leadingConstraint.isActive = true
        
        // 로딩 컨테이너를 위한 최소한의 크기 설정 (다른 UI에 영향 주지 않도록)
        bubbleView.backgroundColor = UIColor.clear
        messageLabel.text = ""
        messageLabel.isHidden = true
        
        // 다른 UI 요소들 숨기기
        applyButton.isHidden = true
        optionButtonStackView.isHidden = true
        
        // 로딩 컨테이너만 표시
        loadingContainer.isHidden = false
        loadingContainer.alpha = 1.0
        
        // ✅ 로딩일 때만 버블이 로딩 컨테이너 크기에 맞춰지도록
        NSLayoutConstraint.activate([
            loadingContainer.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8)
        ])
        
        // 기존 애니메이션이 있다면 정지
        stopLoadingAnimation()
        
        // 고양이 위치 초기화
        gifCatView.transform = .identity
        currentCatPosition = 0
        
        // 고양이 GIF 시작
        startLoadingAnimation()
    }
    
    // 🆕 퀵 액션 버튼들 구성 - 챗 버블 전체 너비에 맞게 확장
    private func configureQuickActionButtons(_ quickActions: [(String, String)]) {
        // 기존 버튼들 제거
        optionButtonStackView.arrangedSubviews.forEach { subview in
            optionButtonStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        print("[ChatBubbleCell] configureQuickActionButtons - quickActions: \(quickActions)")
        
        // 퀵 액션 버튼들 생성
        for (title, action) in quickActions {
            let button = createQuickActionButton(title: title, action: action)
            print("[ChatBubbleCell] 버튼 생성: \(title), 액션: \(action)")
            optionButtonStackView.addArrangedSubview(button)
        }
        
        // 스택뷰가 전체 너비를 차지하도록 설정
        optionButtonStackView.distribution = .fillEqually
        optionButtonStackView.spacing = 12
        optionButtonStackView.isHidden = false
        leadingConstraint.isActive = true
        messageLabelBottomConstraint.isActive = false
        optionStackBottomConstraint.isActive = true
    }
    
    // 🆕 퀵 액션 버튼 생성 - 채팅 버블과 조화로운 보라색 테마로 개선
    private func createQuickActionButton(title: String, action: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        
        // 채팅 버블과 조화로운 보라색 계열 그라데이션
        let primaryColor: UIColor
        let secondaryColor: UIColor
        
        if title.contains("AI") || title.contains("✨") {
            // AI 관련 - 밝은 보라색~핑크 그라데이션
            primaryColor = UIColor.systemPurple
            secondaryColor = UIColor.systemPink
        } else {
            // 앱 분석 관련 - 깊은 보라색~인디고 그라데이션
            primaryColor = UIColor.systemIndigo
            secondaryColor = UIColor.systemPurple
        }
        
        // 그라데이션 설정
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [primaryColor.cgColor, secondaryColor.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 16
        
        button.layer.insertSublayer(gradientLayer, at: 0)
        button.layer.cornerRadius = 16
        button.layer.shadowColor = primaryColor.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 8
        
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        button.addAction(UIAction { [weak self] _ in
            print("[ChatBubbleCell] 퀵 액션 버튼 클릭됨: \(title) -> \(action)")
            self?.handleQuickAction(action)
        }, for: .touchUpInside)
        
        // 버튼 크기를 더 크고 넓게 설정 - 챗 버블에 맞게 임팩트 있게
        button.heightAnchor.constraint(equalToConstant: 60).isActive = true
        
        // 버튼이 레이아웃된 후 그라데이션 크기 조정
        DispatchQueue.main.async {
            gradientLayer.frame = button.bounds
        }
        
        // 터치 애니메이션 추가
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        return button
    }
    
    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }
    
    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = .identity
        }
    }
    
    // 🆕 퀵 액션 처리
    private func handleQuickAction(_ action: String) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        // 부모 뷰 컨트롤러를 찾아서 액션 전달
        var responder: UIResponder? = self
        while responder != nil {
            if let chatVC = responder as? ChatViewController {
                chatVC.handleQuickActionFromCell(action)
                break
            }
            responder = responder?.next
        }
    }
}
