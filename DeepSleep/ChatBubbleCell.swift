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
        print("🔍 Bundle에서 cat.gif 찾기 시작...")
        
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
                print("✅ \(method)에서 GIF 찾음: \(gifPath)")
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
        print("✅ GIF 프레임 수: \(count)")
        
        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                images.append(UIImage(cgImage: cgImage))
            }
        }
        
        if !images.isEmpty {
            print("✅ GIF 애니메이션 설정 성공! 프레임: \(images.count)개")
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

        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            messageLabelBottomConstraint,
            
            applyButton.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            applyButton.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            applyButtonHeightConstraint,
            
            // ✅ 옵션 버튼 스택뷰 제약 조건
            optionButtonStackView.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 12),
            optionButtonStackView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            optionButtonStackView.trailingAnchor.constraint(lessThanOrEqualTo: bubbleView.trailingAnchor, constant: -16),
            optionButtonStackView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -16),
            optionButtonStackView.heightAnchor.constraint(equalToConstant: 200) // 4개 버튼 * 50 높이
        ])

        // ✅ 로딩 컨테이너 제약조건 (2배 크게 + 생각중 텍스트) - bottomAnchor 제거로 다른 버블에 영향 안 줌
        NSLayoutConstraint.activate([
            loadingContainer.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            loadingContainer.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            loadingContainer.widthAnchor.constraint(equalToConstant: 120), // 2배 크게 + 텍스트 공간
            loadingContainer.heightAnchor.constraint(equalToConstant: 60), // 2배 크게 + 여유 공간
            // ✅ bottomAnchor 제거 - 다른 버블에 영향주지 않도록
            
            // ✅ 고양이 뷰 (2배 크게)
            gifCatView.leadingAnchor.constraint(equalTo: loadingContainer.leadingAnchor),
            gifCatView.topAnchor.constraint(equalTo: loadingContainer.topAnchor),
            gifCatView.widthAnchor.constraint(equalToConstant: 48), // 24 * 2
            gifCatView.heightAnchor.constraint(equalToConstant: 48), // 24 * 2
            
            // ✅ 생각중 라벨 (고양이 시작 위치 왼쪽 밑에)
            thinkingLabel.leadingAnchor.constraint(equalTo: loadingContainer.leadingAnchor),
            thinkingLabel.topAnchor.constraint(equalTo: gifCatView.bottomAnchor, constant: 4),
            thinkingLabel.trailingAnchor.constraint(lessThanOrEqualTo: loadingContainer.trailingAnchor, constant: -8)
        ])
        
        // bubbleView 제약조건 복원
        leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2)
        ])
        
        // 최대 너비 제한
        let bubbleWidthConstraint = bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.85)
        
        // 초기 상태에서 로딩 컨테이너 숨김
        loadingContainer.isHidden = true
        
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
        stopLoadingAnimation() // ✅ 기존 로딩 애니메이션 정지

        switch message.type {
        case .user:
            configureUserMessage(message.text)
        case .bot:
            configureBotMessage(message.text)
        case .loading: // ✅ 로딩 케이스 처리
            configureLoadingMessage()
        case .error:
            configureBotMessage(message.text) // 에러 메시지도 봇 스타일로 표시
        case .presetRecommendation:
            configurePresetMessage(message.text) {
                message.onApplyPreset?()
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
        
        // 오른쪽 정렬
        trailingConstraint.isActive = true
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
        // 로딩 컨테이너 완전히 숨기고 프리셋 메시지 표시
        loadingContainer.isHidden = true
        loadingContainer.alpha = 0
        messageLabel.isHidden = false
        
        // 🆕 프리셋 형식 정보 숨기고 설명 부분만 표시
        let displayMessage = extractDescriptionFromPresetMessage(msg)
        
        // 프리셋 추천 메시지 스타일 - 다크모드에서 오렌지 계열
        let presetMessageColor = UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.systemOrange.withAlphaComponent(0.8)
            default:
                return UIColor.systemGreen.withAlphaComponent(0.8)
            }
        }
        
        bubbleView.backgroundColor = presetMessageColor
        messageLabel.textColor = .white
        messageLabel.text = displayMessage  // 🆕 수정된 메시지 사용
        messageLabel.font = .systemFont(ofSize: 16, weight: .medium)
        
        // 왼쪽 정렬 + 버튼 표시
        leadingConstraint.isActive = true
        applyButton.isHidden = false
        applyButtonHeightConstraint.constant = 36
        messageLabelToButtonConstraint.isActive = true
        applyButtonBottomConstraint.isActive = true
        applyAction = action
        
        // 특별한 그라데이션 효과 (다크모드에서 오렌지)
        let gradientColor1 = UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.systemOrange.withAlphaComponent(0.8)
            default:
                return UIColor.systemGreen
            }
        }
        
        let gradientColor2 = UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.systemOrange.withAlphaComponent(0.6)
            default:
                return UIColor.systemGreen.withAlphaComponent(0.8)
            }
        }
        
        addGradientToBubble(colors: [
            gradientColor1.cgColor,
            gradientColor2.cgColor
        ])
        
        // 버튼 애니메이션 효과
        applyButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.3, delay: 0.1, options: [.curveEaseOut], animations: {
            self.applyButton.transform = .identity
        })
        
        // 맥동 효과 (선택적)
        addPulseAnimation()
    }
    
    // 🆕 프리셋 메시지에서 설명 부분만 추출하는 메서드
    private func extractDescriptionFromPresetMessage(_ message: String) -> String {
        // 1. 프리셋 이름 추출
        let presetName = extractPresetName(from: message)
        
        // 2. ] 이후의 텍스트에서 간단한 설명 찾기
        if let endBracket = message.range(of: "]") {
            let afterBracket = String(message[endBracket.upperBound...])
            
            // 3. 모든 볼륨 설정과 특수 문자들을 제거하고 깔끔한 설명만 추출
            let cleanText = afterBracket
                .replacingOccurrences(of: "[가-힣a-zA-Z0-9\\s]*:\\d+", with: "", options: .regularExpression)  // 볼륨 설정 제거
                .replacingOccurrences(of: ",+", with: "", options: .regularExpression)  // 연속된 쉼표 제거
                .replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression)  // 괄호 내용 제거
                .replacingOccurrences(of: "[\\w가-힣]+-", with: "", options: .regularExpression)  // 하이픈 단어 제거
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)  // 중복 공백 정리
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 4. 의미있는 설명이 있으면 사용, 없으면 기본 메시지
            if !cleanText.isEmpty && cleanText.count > 5 && !cleanText.contains(":") {
                return "🎵 [\(presetName)] \(cleanText)"
            }
        }
        
        // 5. 설명이 없거나 추출 실패 시 기본 메시지
        return "🎵 [\(presetName)] 이 프리셋으로 편안한 시간을 보내보세요. 🌙"
    }
    
    // 🆕 프리셋 이름 추출 헬퍼 메서드
    private func extractPresetName(from message: String) -> String {
        if let nameMatch = message.range(of: "\\[(.+?)\\]", options: .regularExpression) {
            return String(message[nameMatch]).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        }
        return "맞춤 추천"
    }
    
    // ✅ 새로운 postPresetOptions 구성 메서드
    private func configurePostPresetOptions(
        presetName: String,
        onSave: @escaping () -> Void,
        onFeedback: @escaping () -> Void,
        onGoToMain: @escaping () -> Void,
        onContinueChat: @escaping () -> Void
    ) {
        // AI 메시지 스타일 기본 적용 - 다크모드 호환
        bubbleView.backgroundColor = UIDesignSystem.Colors.adaptiveTertiaryBackground
        messageLabel.textColor = UIDesignSystem.Colors.primaryText
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
        
        // 4개의 옵션 버튼 생성 - 다크모드 호환 색상
        let saveButton = createOptionButton(
            title: "💾 저장하기",
            backgroundColor: UIDesignSystem.Colors.primary.withAlphaComponent(0.8),
            action: #selector(saveOptionTapped)
        )
        
        let feedbackButton = createOptionButton(
            title: "💬 피드백",
            backgroundColor: UIColor.systemOrange.withAlphaComponent(0.8),
            action: #selector(feedbackOptionTapped)
        )
        
        let continueButton = createOptionButton(
            title: "💭 계속 대화",
            backgroundColor: UIColor.systemGreen.withAlphaComponent(0.8),
            action: #selector(continueOptionTapped)
        )
        
        let mainButton = createOptionButton(
            title: "🏠 메인으로",
            backgroundColor: UIColor.systemGray.withAlphaComponent(0.8),
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
        
        print("🐱 로딩 메시지 설정 완료 - 고양이 GIF 시작")
    }
}
