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
        button.setTitle("프리셋 적용", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()
    
    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    
    private var applyAction: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
            contentView.addSubview(bubbleView)
            bubbleView.addSubview(messageLabel)
            bubbleView.addSubview(applyButton)
            messageLabelBottomConstraint = messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8)
            applyButtonHeightConstraint = applyButton.heightAnchor.constraint(equalToConstant: 28)
            messageLabelToButtonConstraint = applyButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 8)
            applyButtonBottomConstraint = applyButton.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8)

            NSLayoutConstraint.activate([
                messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
                messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
                messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
                messageLabelBottomConstraint,
                applyButton.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
                applyButtonHeightConstraint
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

        // ⚠️ AutoLayout 충돌 방지를 위해 우선순위 낮춤
        let bubbleWidthConstraint = bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75)
        bubbleWidthConstraint.priority = .required // 높임
        bubbleWidthConstraint.isActive = true
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)
    }

    func configure(with message: ChatMessage) {
        // 초기화
        applyButton.isHidden = true
        applyAction = nil
        leadingConstraint.isActive = false
        trailingConstraint.isActive = false
        messageLabelBottomConstraint.isActive = false
        messageLabelToButtonConstraint.isActive = false
        applyButtonBottomConstraint.isActive = false

        switch message {
        case .user(let text):
            bubbleView.backgroundColor = .systemBlue
            messageLabel.textColor = .white
            messageLabel.text = text
            trailingConstraint.isActive = true
            messageLabelBottomConstraint.isActive = true
            messageLabelToButtonConstraint.isActive = false
            applyButtonBottomConstraint.isActive = false
        case .bot(let text):
            bubbleView.backgroundColor = UIColor(white: 0.90, alpha: 1)
            messageLabel.textColor = .black
            messageLabel.text = text
            leadingConstraint.isActive = true
            messageLabelBottomConstraint.isActive = true
            messageLabelToButtonConstraint.isActive = false
            applyButtonBottomConstraint.isActive = false

        case .presetRecommendation(_, let msg, let action):
            bubbleView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.9)
            messageLabel.textColor = .white
            messageLabel.text = "🎵 \(msg)"
            leadingConstraint.isActive = true
            applyButton.isHidden = false
            applyButtonHeightConstraint.constant = 28
            messageLabelToButtonConstraint.isActive = true
            applyButtonBottomConstraint.isActive = true
            applyAction = action
        }
    }

    @objc private func applyTapped() {
        applyAction?()
    }
}
