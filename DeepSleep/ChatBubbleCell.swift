import UIKit

class ChatBubbleCell: UITableViewCell {
  static let identifier = "ChatBubbleCell"
  
  private let bubbleView: UIView = {
    let v = UIView()
    v.layer.cornerRadius = 16
    v.translatesAutoresizingMaskIntoConstraints = false
    return v
  }()
  
  private let messageLabel: UILabel = {
    let l = UILabel()
    l.numberOfLines = 0
    l.translatesAutoresizingMaskIntoConstraints = false
    return l
  }()
  
  // 제약은 미리 만들어 두고 activate/deactivate
  private var leadingConstraint: NSLayoutConstraint!
  private var trailingConstraint: NSLayoutConstraint!
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    backgroundColor = .clear
    contentView.addSubview(bubbleView)
    bubbleView.addSubview(messageLabel)
    
    // 공통 제약
    NSLayoutConstraint.activate([
      messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
      messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),
      messageLabel.widthAnchor.constraint(lessThanOrEqualToConstant: UIScreen.main.bounds.width * 0.7),
      
      bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
      bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
    ])
    
    // 왼쪽·오른쪽 위치 토글용 제약
    leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
    trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
    
    // label 내부 좌우
    NSLayoutConstraint.activate([
      messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
      messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12)
    ])
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func configure(with msg: ChatMessage) {
    switch msg {
    case .user(let text):
      bubbleView.backgroundColor = UIColor.systemBlue
      messageLabel.textColor  = .white
      messageLabel.text       = text
      leadingConstraint.isActive  = false
      trailingConstraint.isActive = true
      
    case .bot(let text):
      bubbleView.backgroundColor = UIColor(white: 0.90, alpha: 1)
      messageLabel.textColor  = .black
      messageLabel.text       = text
      trailingConstraint.isActive = false
      leadingConstraint.isActive  = true
      
    case .presetRecommendation(let preset, let message):
      bubbleView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.9)
      messageLabel.textColor  = .white
      messageLabel.text       = "🎵 \(message)"
      trailingConstraint.isActive = false
      leadingConstraint.isActive  = true
    }
  }
}
