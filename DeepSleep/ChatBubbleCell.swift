import UIKit

class ChatBubbleCell: UITableViewCell {
    static let identifier = "ChatBubbleCell"
    
    private let bubbleView = UIView()
    private let messageLabel = UILabel()
    private let applyButton = UIButton(type: .system)
    private var onApplyAction: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        backgroundColor = .clear
        selectionStyle = .none
        
        // Bubble View 설정
        bubbleView.layer.cornerRadius = 16
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)
        
        // Message Label 설정
        messageLabel.numberOfLines = 0
        messageLabel.font = .systemFont(ofSize: 16)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(messageLabel)
        
        // Apply Button 설정
        applyButton.setTitle("✅ 적용하기", for: .normal)
        applyButton.backgroundColor = .systemGreen
        applyButton.setTitleColor(.white, for: .normal)
        applyButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        applyButton.layer.cornerRadius = 12
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        applyButton.addTarget(self, action: #selector(applyButtonTapped), for: .touchUpInside)
        applyButton.isHidden = true
        bubbleView.addSubview(applyButton)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        // 기본 제약 조건 - 메시지 라벨과 버튼
        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            
            applyButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 12),
            applyButton.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            applyButton.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            applyButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    func configure(with message: ChatMessage) {
        // 기존 제약 조건들 제거
        bubbleView.removeFromSuperview()
        contentView.addSubview(bubbleView)
        
        switch message {
        case .user(let text):
            configureAsUser(text: text)
            
        case .bot(let text):
            configureAsBot(text: text)
            
        case .presetRecommendation(let presetName, let text, let onApply):
            configureAsPresetRecommendation(presetName: presetName, text: text, onApply: onApply)
        }
    }
    
    private func configureAsUser(text: String) {
        messageLabel.text = text
        messageLabel.textColor = .white
        bubbleView.backgroundColor = .systemBlue
        applyButton.isHidden = true
        
        // 사용자 메시지는 오른쪽 정렬
        updateConstraintsForUser()
    }
    
    private func configureAsBot(text: String) {
        messageLabel.text = text
        messageLabel.textColor = .label
        bubbleView.backgroundColor = .systemGray5
        applyButton.isHidden = true
        
        // AI 메시지는 왼쪽 정렬
        updateConstraintsForBot()
    }
    
    private func configureAsPresetRecommendation(presetName: String, text: String, onApply: @escaping () -> Void) {
        messageLabel.text = text
        messageLabel.textColor = .label
        bubbleView.backgroundColor = .systemBlue.withAlphaComponent(0.1)
        applyButton.isHidden = false
        onApplyAction = onApply
        
        // AI 메시지는 왼쪽 정렬
        updateConstraintsForBot()
        
        // 버튼 애니메이션
        applyButton.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.3, delay: 0.1, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.applyButton.transform = .identity
        }
    }
    
    private func updateConstraintsForUser() {
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 60),
            bubbleView.widthAnchor.constraint(lessThanOrEqualToConstant: 280),
            
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12)
        ])
    }
    
    private func updateConstraintsForBot() {
        if applyButton.isHidden {
            // 일반 봇 메시지 (적용 버튼 없음)
            NSLayoutConstraint.activate([
                bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
                bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
                bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -60),
                bubbleView.widthAnchor.constraint(lessThanOrEqualToConstant: 320),
                
                messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
                messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
                messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
                messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12)
            ])
        } else {
            // 프리셋 추천 메시지 (적용 버튼 있음)
            NSLayoutConstraint.activate([
                bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
                bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
                bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -60),
                bubbleView.widthAnchor.constraint(lessThanOrEqualToConstant: 320),
                
                messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
                messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
                messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
                
                applyButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 12),
                applyButton.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
                applyButton.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
                applyButton.heightAnchor.constraint(equalToConstant: 44),
                applyButton.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12)
            ])
        }
    }
    
    @objc private func applyButtonTapped() {
        // 버튼 누름 애니메이션
        UIView.animate(withDuration: 0.1, animations: {
            self.applyButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.applyButton.transform = .identity
            }
        }
        
        // 햅틱 피드백
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
        
        // 버튼 비활성화 (중복 클릭 방지)
        applyButton.isEnabled = false
        applyButton.setTitle("✅ 적용됨", for: .normal)
        applyButton.backgroundColor = .systemGray
        
        // 액션 실행
        onApplyAction?()
        
        // 1초 후 버튼 다시 활성화
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.applyButton.isEnabled = true
            self.applyButton.setTitle("✅ 적용하기", for: .normal)
            self.applyButton.backgroundColor = .systemGreen
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        onApplyAction = nil
        applyButton.isHidden = true
        applyButton.isEnabled = true
        applyButton.setTitle("✅ 적용하기", for: .normal)
        applyButton.backgroundColor = .systemGreen
        
        // 제약 조건 초기화
        bubbleView.removeFromSuperview()
        contentView.addSubview(bubbleView)
    }
}
