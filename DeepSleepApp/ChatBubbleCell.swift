import UIKit
import Foundation

// ChatMessage 타입 접근성 확보를 위한 참조
fileprivate let _chatMessageRef: ChatMessage? = nil

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

class ChatBubbleCell: UITableViewCell, UIEditMenuInteractionDelegate {
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
        
        // 🎯 채팅 스타일: 텍스트 크기에 딱 맞게 조절
        label.setContentHuggingPriority(.required, for: .horizontal) // 텍스트 크기에 꽉 맞게
        label.setContentHuggingPriority(.defaultLow, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .horizontal) // 텍스트 잘리지 않게
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
        stackView.distribution = .fillProportionally
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.isHidden = true
        stackView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
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
    // teachAction 제거됨(미사용)
    // private var originalUserMessageForTeachable: String?
    
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
        bubbleView.addSubview(optionButtonStackView)
        
        // 로딩 컨테이너 설정
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
        
        // 로딩 관련 컴포넌트들 설정
        loadingContainer.translatesAutoresizingMaskIntoConstraints = false
        gifCatView.translatesAutoresizingMaskIntoConstraints = false
        loadingTextLabel.translatesAutoresizingMaskIntoConstraints = false
        typingDotsLabel.translatesAutoresizingMaskIntoConstraints = false
        thinkingLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // GIF 고양이 뷰 설정
        gifCatView.backgroundColor = .clear
        
        // 로딩 텍스트 라벨 설정 (숨김)
        loadingTextLabel.isHidden = true
        
        // 타이핑 텍스트 라벨 설정 (Claude 스타일)
        typingDotsLabel.text = "생각 중▊"
        typingDotsLabel.font = .systemFont(ofSize: 11, weight: .regular)
        typingDotsLabel.textColor = .systemGray
        typingDotsLabel.textAlignment = .left
        
        // 생각중 라벨 설정
        thinkingLabel.text = "생각중..."
        thinkingLabel.font = .systemFont(ofSize: 14, weight: .medium)
        thinkingLabel.textColor = .systemGray
        thinkingLabel.textAlignment = .left
        thinkingLabel.alpha = 0 // 처음에는 숨김
        
        // 🎯 채팅 스타일 제약조건 - 처음부터 깔끔하게 재설계
        setupChatStyleConstraints()
        
        // 초기 상태에서 로딩 컨테이너 숨김
        loadingContainer.isHidden = true
        
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)
    }
    
    // 🎯 채팅 스타일 제약조건 설정 (깔끔한 분리)
    private func setupChatStyleConstraints() {
        // 기본 제약조건들 저장
        messageLabelBottomConstraint = messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12)
        // 고정 높이 대신 최소 높이로 설정하여 AutoLayout 경고 방지
        applyButtonHeightConstraint = applyButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        applyButtonHeightConstraint.priority = .defaultLow
        messageLabelToButtonConstraint = applyButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 12)
        applyButtonBottomConstraint = applyButton.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12)
        optionStackBottomConstraint = optionButtonStackView.bottomAnchor.constraint(lessThanOrEqualTo: bubbleView.bottomAnchor, constant: -16)
        optionStackBottomConstraint.priority = .defaultHigh
        
        // 버블뷰 기본 제약조건 (동적으로 변경될 예정)
        leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        
        // 공통 제약조건들 활성화
        NSLayoutConstraint.activate([
            // BubbleView 기본 위치
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            // MessageLabel 기본 위치 (내부 여백)
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            
            // ApplyButton 기본 설정
            applyButton.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            applyButton.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            applyButtonHeightConstraint,
            
            // OptionButtonStackView 기본 설정
            optionButtonStackView.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 12),
            optionButtonStackView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            optionButtonStackView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            
            // 로딩 컨테이너 제약조건
            loadingContainer.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            loadingContainer.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            loadingContainer.widthAnchor.constraint(equalToConstant: 200),
            
            gifCatView.leadingAnchor.constraint(equalTo: loadingContainer.leadingAnchor),
            gifCatView.topAnchor.constraint(equalTo: loadingContainer.topAnchor),
            gifCatView.widthAnchor.constraint(equalToConstant: 48),
            gifCatView.heightAnchor.constraint(equalToConstant: 48),
            
            thinkingLabel.leadingAnchor.constraint(equalTo: loadingContainer.leadingAnchor),
            thinkingLabel.topAnchor.constraint(equalTo: gifCatView.bottomAnchor, constant: 4),
            thinkingLabel.trailingAnchor.constraint(lessThanOrEqualTo: loadingContainer.trailingAnchor, constant: -16)
        ])
        contentView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        
        // 로딩 컨테이너 최소 높이(우선순위 낮춤)로 초기 계산 단계 경고 방지
        let loadingMinHeight = loadingContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        loadingMinHeight.priority = .defaultHigh // 750
        loadingMinHeight.isActive = true
        
        thinkingLabel.numberOfLines = 1
        thinkingLabel.lineBreakMode = .byTruncatingTail
    }

    private func setupGestureRecognizers() {
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        bubbleView.addGestureRecognizer(longPressGesture)
        bubbleView.isUserInteractionEnabled = true
    }
    
    @objc private func handleLongPress(gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        // 모든 채팅 버블(사용자/AI)에서 길게 누르기 메뉴 제공
        becomeFirstResponder()
        
        // iOS 16+ 방식: UIEditMenuInteraction 사용
        if #available(iOS 16.0, *) {
            let interaction = UIEditMenuInteraction(delegate: self)
            bubbleView.addInteraction(interaction)
            
            let configuration = UIEditMenuConfiguration(
                identifier: "chat-bubble-menu",
                sourcePoint: CGPoint(x: bubbleView.bounds.midX, y: bubbleView.bounds.midY)
            )
            interaction.presentEditMenu(with: configuration)
        } else {
            // iOS 15 이하 방식: UIMenuController 사용 (기억하기/복사하기/공유하기)
            let rememberItem = UIMenuItem(title: "기억하기", action: #selector(rememberTapped))
            let copyItem = UIMenuItem(title: "복사하기", action: #selector(copyTapped))
            let shareItem = UIMenuItem(title: "공유하기", action: #selector(shareTapped))
            
            UIMenuController.shared.menuItems = [rememberItem, copyItem, shareItem]
            UIMenuController.shared.showMenu(from: bubbleView, rect: bubbleView.bounds)
        }
    }

    @objc private func rememberTapped() {
        guard let text = messageLabel.text, !text.isEmpty else { return }
        if MemoryManager.shared.canAddMemory() {
            _ = MemoryManager.shared.addMemory(text, importance: 3)
        } else {
            NotificationCenter.default.post(name: .aiUsageLimitWarning, object: nil, userInfo: ["mode": "coreMemory", "current": 0, "limit": MemoryTier.free.slotLimit])
        }
        resignFirstResponder()
    }
    
    @objc private func shareTapped() {
        guard let vc = findViewController() else { return }
        let rawText = messageLabel.text ?? ""
        let masked = SettingsManager.shared.maskPIIForExport(rawText)
        let activityVC = UIActivityViewController(activityItems: [masked], applicationActivities: nil)
        if let pop = activityVC.popoverPresentationController {
            pop.sourceView = bubbleView
            pop.sourceRect = bubbleView.bounds
        }
        vc.present(activityVC, animated: true)
    }

    @objc private func copyTapped() {
        UIPasteboard.general.string = messageLabel.text
        resignFirstResponder()
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return action == #selector(copyTapped) || action == #selector(rememberTapped) || action == #selector(shareTapped)
    }
    
    func configure(with message: ChatMessage, isUserMessage: Bool, originalUserMessage: String? = nil) {
        // "가르치기" 컨텍스트는 더 이상 사용하지 않음
        
        // 메시지 타입에 따라 UI 분기
        switch message.type {
        case .user:
            configureUserMessage(message.text ?? "")
        case .bot, .aiResponse:
            configureBotMessage(message.text ?? "")
            // '가르치기' 버튼 표시 로직 (AI의 응답에만 해당)
            setupTeachButton(for: message.type, originalUserMessage: originalUserMessage)
            // 🆕 퀵 액션이 있는 메시지인지 확인
            if let quickActions = message.quickActions {
                let quickActionTuples = quickActions.map { ($0.title, $0.action) }
                setupOptionButtons(with: quickActionTuples)
            }
        case .system:
            configureSystemMessage(message.text ?? "")
        case .presetRecommendation:
            configurePresetMessage(message.text ?? "") {
                // 프리셋 적용 액션을 ChatViewController로 전달
                var responder: UIResponder? = self
                while responder != nil {
                    if let chatVC = responder as? ChatViewController {
                        chatVC.applyRecommendedPreset(messageId: message.id)
                        break
                    }
                    responder = responder?.next
                }
            }
        case .recommendationSelector:
            configureRecommendationSelectorMessage(message.text ?? "")
            // 🆕 퀵 액션이 있는 메시지인지 확인
            if let quickActions = message.quickActions {
                let quickActionTuples = quickActions.map { ($0.title, $0.action) }
                setupOptionButtons(with: quickActionTuples)
            }
        case .presetOptions, .postPresetOptions:
            configureBotMessage(message.text ?? "")
            if let quickActions = message.quickActions {
                let quickActionTuples = quickActions.map { ($0.title, $0.action) }
                setupOptionButtons(with: quickActionTuples)
            }
        case .loading:
            configureLoadingMessage(message.text ?? "")
        case .error:
            configureBotMessage(message.text ?? "") // 에러 메시지도 봇 스타일로 표시
        case .text:
            // ✅ 저장 시 .text로 들어오는 경우, 보낸이 기준으로 좌/우 정렬
            if isUserMessage {
                configureUserMessage(message.text ?? "")
            } else {
                configureBotMessage(message.text ?? "")
            }
        }
        
        // 로딩 상태에 따른 애니메이션 처리
        if message.type == .loading {
            startLoadingAnimation()
        } else {
            stopLoadingAnimation()
        }
        
        // ⚠️ 중복 방지: configure 함수들에서 이미 applyChatStyleLayout() 호출됨
        // updateBubbleConstraints() 호출 제거로 이중 실행 방지
        layoutIfNeeded()
    }
    
    // 🎯 채팅 스타일 레이아웃 적용 (prepareForReuse에서 정리됨)
    private func applyChatStyleLayout(isUserMessage: Bool) {
        // 기존 제약조건들 전부 비활성화
        leadingConstraint.isActive = false
        trailingConstraint.isActive = false
        messageLabelBottomConstraint.isActive = false
        messageLabelToButtonConstraint.isActive = false
        applyButtonBottomConstraint.isActive = false
        optionStackBottomConstraint.isActive = false
        
        // 💬 채팅 스타일: 텍스트 길이에 맞는 동적 크기 + 위치 조정
        if isUserMessage {
            // 🟦 사용자 메시지 (오른쪽 정렬, 텍스트 크기에 맞게)
            leadingConstraint.constant = 16 // 최소 여백만 확보
            leadingConstraint.priority = .init(250) // 낮은 우선순위 (늘어날 수 있음)
            trailingConstraint.constant = -16
            trailingConstraint.priority = .required // 높은 우선순위 (고정)
            
            leadingConstraint.isActive = true
            trailingConstraint.isActive = true
        } else {
            // 🟩 AI 메시지 (왼쪽 정렬, 텍스트 크기에 맞게)
            leadingConstraint.constant = 16
            leadingConstraint.priority = .required // 높은 우선순위 (고정)
            trailingConstraint.constant = -16 // 최소 여백만 확보
            trailingConstraint.priority = .init(250) // 낮은 우선순위 (늘어날 수 있음)
            
            leadingConstraint.isActive = true
            trailingConstraint.isActive = true
        }
        
        // 🎯 채팅 스타일: 최대 너비만 제한, 최소 너비는 텍스트에 맞게
        let maxWidthConstraint = bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.8)
        let minWidthConstraint = bubbleView.widthAnchor.constraint(greaterThanOrEqualToConstant: 44) // 최소 크기만 (아이콘 크기)
        
        NSLayoutConstraint.activate([
            maxWidthConstraint,
            minWidthConstraint
        ])
        
        // 기본 메시지 bottom 제약조건 활성화 (버튼이나 옵션이 없는 경우)
        messageLabelBottomConstraint.isActive = true
        
        // 로딩 관련 초기화
        loadingContainer.isHidden = true
        loadingContainer.alpha = 0
        messageLabel.isHidden = false
        stopLoadingAnimation()
        
        // 고양이 위치 및 상태 완전 초기화
        gifCatView.transform = .identity
        thinkingLabel.alpha = 0
        currentCatPosition = 0
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
        // 🎯 채팅 스타일 레이아웃 적용 (사용자 = 오른쪽)
        applyChatStyleLayout(isUserMessage: true)
        
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
        messageLabel.textAlignment = .left
        
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
        // 🎯 채팅 스타일 레이아웃 적용 (AI = 왼쪽)
        applyChatStyleLayout(isUserMessage: false)
        
        // AI 메시지 스타일 - 다크모드 호환
        bubbleView.backgroundColor = UIDesignSystem.Colors.adaptiveTertiaryBackground
        messageLabel.textColor = UIDesignSystem.Colors.primaryText
        messageLabel.text = text
        messageLabel.font = .systemFont(ofSize: 16, weight: .regular)
        messageLabel.textAlignment = .left
        
        // 부드러운 그림자
        bubbleView.layer.shadowColor = UIColor.black.cgColor
        bubbleView.layer.shadowOffset = CGSize(width: 0, height: 1)
        bubbleView.layer.shadowOpacity = 0.05
        bubbleView.layer.shadowRadius = 3
    }
    
    private func configureSystemMessage(_ text: String) {
        // 🎯 시스템 메시지는 중앙 정렬 (예외적으로 특별 처리)
        // 기존 제약조건들 전부 비활성화
        leadingConstraint.isActive = false
        trailingConstraint.isActive = false
        messageLabelBottomConstraint.isActive = false
        messageLabelToButtonConstraint.isActive = false
        applyButtonBottomConstraint.isActive = false
        optionStackBottomConstraint.isActive = false
        
        // 로딩 관련 초기화
        loadingContainer.isHidden = true
        loadingContainer.alpha = 0
        messageLabel.isHidden = false
        stopLoadingAnimation()
        
        // 고양이 위치 및 상태 완전 초기화
        gifCatView.transform = .identity
        thinkingLabel.alpha = 0
        currentCatPosition = 0
        
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
        
        // 🎯 시스템 메시지: 텍스트 크기에 맞게 + 중앙 정렬
        leadingConstraint.constant = 60 // 최소 여백
        leadingConstraint.priority = .init(250) // 낮은 우선순위 (늘어날 수 있음)
        trailingConstraint.constant = -60 // 최소 여백
        trailingConstraint.priority = .init(250) // 낮은 우선순위 (늘어날 수 있음)
        
        leadingConstraint.isActive = true
        trailingConstraint.isActive = true
        messageLabelBottomConstraint.isActive = true
        
        // 🎯 시스템 메시지: 중앙 정렬 제약조건 추가
        let centerConstraint = bubbleView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        centerConstraint.priority = .init(999) // 중앙 정렬 우선순위 높음
        
        // 시스템 메시지 너비 제약조건
        let systemMaxWidthConstraint = bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.7)
        let systemMinWidthConstraint = bubbleView.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        
        NSLayoutConstraint.activate([
            centerConstraint,
            systemMaxWidthConstraint,
            systemMinWidthConstraint
        ])
    }
    
    private func configurePresetMessage(_ text: String, applyAction: @escaping () -> Void = {}) {
        // 🎯 채팅 스타일 레이아웃 적용 (프리셋 = AI 왼쪽)
        applyChatStyleLayout(isUserMessage: false)
        
        messageLabel.text = text
        messageLabel.textColor = UIDesignSystem.Colors.primaryText
        messageLabel.font = .systemFont(ofSize: 16, weight: .regular)
        messageLabel.textAlignment = .left
        
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
        
        // 전달받은 applyAction을 저장
        self.applyAction = applyAction
        
        // 🎯 프리셋 메시지는 버튼이 있으므로 bottom 제약조건 변경
        messageLabelBottomConstraint.isActive = false
        messageLabelToButtonConstraint.isActive = true
        applyButtonBottomConstraint.isActive = true
    }
    
    // 🆕 추천 방식 선택창 스타일 (프리셋 추천과 똑같은 색상)
    private func configureRecommendationSelectorMessage(_ text: String) {
        // 🎯 채팅 스타일 레이아웃 적용 (추천 선택 = AI 왼쪽)
        applyChatStyleLayout(isUserMessage: false)
        
        messageLabel.text = text
        messageLabel.textColor = UIDesignSystem.Colors.primaryText
        messageLabel.font = .systemFont(ofSize: 16, weight: .regular)
        messageLabel.textAlignment = .left
        
        // 프리셋 추천과 똑같은 보라색 배경 적용
        bubbleView.backgroundColor = UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.systemPurple.withAlphaComponent(0.2) // 다크모드에서 보라색 계열
            default:
                return UIColor.systemPurple.withAlphaComponent(0.1) // 라이트모드에서 연한 보라색
            }
        }
        
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
        
        // 🛡️ 동적 제약조건 완전 정리 (중복 방지의 핵심)
        bubbleView.constraints.forEach { constraint in
            if constraint.firstAttribute == .width || constraint.firstAttribute == .centerX {
                bubbleView.removeConstraint(constraint)
            }
        }
        
        // contentView의 중앙 정렬 제약조건도 정리
        contentView.constraints.forEach { constraint in
            if constraint.firstItem === bubbleView && constraint.firstAttribute == .centerX {
                contentView.removeConstraint(constraint)
            }
        }
        
        // 기존 제약조건들 비활성화
        leadingConstraint.isActive = false
        trailingConstraint.isActive = false
        messageLabelBottomConstraint.isActive = false
        messageLabelToButtonConstraint.isActive = false
        applyButtonBottomConstraint.isActive = false
        optionStackBottomConstraint.isActive = false
        
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
    private func configureLoadingMessage(_ text: String) {
        // 🎯 채팅 스타일 레이아웃 적용 (로딩 = AI 왼쪽)
        applyChatStyleLayout(isUserMessage: false)
        
        // 로딩 컨테이너를 위한 최소한의 크기 설정 (다른 UI에 영향 주지 않도록)
        bubbleView.backgroundColor = UIColor.clear
        messageLabel.text = text
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
    
    // 🆕 퀵 액션 버튼들 구성 - 안정적이고 일관성 있게 재설계
    private func setupOptionButtons(with quickActions: [(String, String)]) {
        // 🛡️ 중복 호출 방지: 이미 같은 버튼들이 있으면 무시
        let existingActions = optionButtonStackView.arrangedSubviews.compactMap { view in
            (view as? UIButton)?.titleLabel?.text
        }
        let newActions = quickActions.map { $0.0 }
        
        if existingActions == newActions && !optionButtonStackView.isHidden {
            print("[ChatBubbleCell] 동일한 퀵액션 이미 존재, 스킵")
            return
        }
        
        // 기존 버튼들 완전 제거
        optionButtonStackView.arrangedSubviews.forEach { subview in
            optionButtonStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        print("[ChatBubbleCell] setupOptionButtons - quickActions: \(quickActions)")
        
        // 퀵 액션 버튼들 생성
        for (title, action) in quickActions {
            let button = createQuickActionButton(title: title, action: action)
            print("[ChatBubbleCell] 버튼 생성: \(title), 액션: \(action)")
            optionButtonStackView.addArrangedSubview(button)
        }
        
        // 🎯 퀵액션이 있는 경우 bottom 제약조건 변경 (채팅 스타일 유지)
        if !quickActions.isEmpty {
            messageLabelBottomConstraint.isActive = false
            optionStackBottomConstraint.isActive = true
            
            // 스택뷰 설정
            optionButtonStackView.distribution = .fillEqually
            optionButtonStackView.spacing = 12
            optionButtonStackView.isHidden = false
        }
    }
    
    // 🆕 퀵 액션 버튼 생성 - 채팅 버블과 조화로운 보라색 테마로 개선
    private func createQuickActionButton(title: String, action: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        
        // UIDesignSystem의 전역 색상 사용
        let primaryColor: UIColor
        let secondaryColor: UIColor
        
        if title.contains("AI") || title.contains("✨") {
            // AI 관련 - 메인 테마색 ~ 보조색 그라데이션
            primaryColor = UIDesignSystem.Colors.accent
            secondaryColor = UIDesignSystem.Colors.secondary
        } else {
            // 앱 분석 관련 - 진한 테마색 ~ 메인 테마색 그라데이션
            primaryColor = UIDesignSystem.Colors.accentDark
            secondaryColor = UIDesignSystem.Colors.accent
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
        
        // 버튼 최소 높이만 보장(완화): 초기 레이아웃 추정 높이 충돌 방지를 위해 36로 하향
        let minH = button.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        minH.priority = .defaultLow
        minH.isActive = true
        button.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        
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

// MARK: - Compiler Fix Stubs
private extension ChatBubbleCell {
    func setupTeachButton(for messageType: ChatMessageType, originalUserMessage: String?) {
        // Stub implementation
    }

    func updateBubbleConstraints(isUserMessage: Bool) {
        // 🎯 이제 applyChatStyleLayout()으로 대체됨
        applyChatStyleLayout(isUserMessage: isUserMessage)
    }

    func findViewController() -> UIViewController? {
        // Non-recursive stub to fix build errors.
        var responder: UIResponder? = self
        while responder != nil {
            if let viewController = responder as? UIViewController {
                return viewController
            }
            responder = responder?.next
        }
        return nil
    }
}

// MARK: - Accessibility Support
extension ChatBubbleCell {
    override var accessibilityLabel: String? {
        get {
            guard !(messageLabel.text?.isEmpty ?? true) else {
                return nil
            }
            
            let messageText = messageLabel.text ?? ""
            let isUserMessage = leadingConstraint.isActive == false && trailingConstraint.isActive == true
            let sender = isUserMessage ? "나" : "AI"
            
            return "\(sender)의 메시지: \(messageText)"
        }
        set { }
    }
    
    override var accessibilityTraits: UIAccessibilityTraits {
        get { .staticText }
        set { }
    }
    
    override var accessibilityHint: String? {
        get {
            if !applyButton.isHidden {
                return "바로 적용하기 버튼을 사용할 수 있습니다"
            } else if !optionButtonStackView.isHidden {
                return "추가 옵션 버튼들을 사용할 수 있습니다"
            }
            return nil
        }
        set { }
    }
    
    override func accessibilityActivate() -> Bool {
        if !applyButton.isHidden {
            applyButton.sendActions(for: .touchUpInside)
            return true
        }
        return false
    }
}

// MARK: - UIEditMenuInteractionDelegate (iOS 16+)
@available(iOS 16.0, *)
extension ChatBubbleCell {
    func editMenuInteraction(_ interaction: UIEditMenuInteraction, menuFor configuration: UIEditMenuConfiguration, suggestedActions: [UIMenuElement]) -> UIMenu? {
        var actions: [UIAction] = []
        
        // 기억하기 액션 추가 (길게 눌러 핵심 기억 저장)
        if let text = messageLabel.text, !text.isEmpty {
            let rememberAction = UIAction(title: "기억하기", image: UIImage(systemName: "star")) { _ in
                if MemoryManager.shared.canAddMemory() {
                    _ = MemoryManager.shared.addMemory(text, importance: 3)
                } else {
                    NotificationCenter.default.post(name: .aiUsageLimitWarning, object: nil, userInfo: ["mode": "coreMemory", "current": 0, "limit": MemoryTier.free.slotLimit])
                }
            }
            actions.append(rememberAction)
        }
        
        // 복사하기 액션 추가
        let copyAction = UIAction(title: "복사하기", image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
            self?.copyTapped()
        }
        actions.append(copyAction)
        
        // 공유하기 액션 추가 (iOS 네이티브 공유 시트)
        let shareAction = UIAction(title: "공유하기", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
            guard let self = self, let vc = self.findViewController() else { return }
            let rawText = self.messageLabel.text ?? ""
            let masked = SettingsManager.shared.maskPIIForExport(rawText)
            let activityVC = UIActivityViewController(activityItems: [masked], applicationActivities: nil)
            if let pop = activityVC.popoverPresentationController {
                pop.sourceView = self.bubbleView
                pop.sourceRect = self.bubbleView.bounds
            }
            vc.present(activityVC, animated: true)
        }
        actions.append(shareAction)
        
        return UIMenu(children: actions)
    }
}
