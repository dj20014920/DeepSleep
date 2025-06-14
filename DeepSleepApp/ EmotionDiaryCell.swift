import UIKit

// MARK: - EmotionDiaryCell (분리된 파일)
class EmotionDiaryCell: UITableViewCell {
    static let identifier = "EmotionDiaryCell"
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray5.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let emotionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .systemGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let userMessageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let aiResponseLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.numberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
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
        
        contentView.addSubview(containerView)
        [emotionLabel, dateLabel, userMessageLabel, aiResponseLabel].forEach {
            containerView.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            emotionLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            emotionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            dateLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            dateLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            userMessageLabel.topAnchor.constraint(equalTo: emotionLabel.bottomAnchor, constant: 8),
            userMessageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            userMessageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            aiResponseLabel.topAnchor.constraint(equalTo: userMessageLabel.bottomAnchor, constant: 8),
            aiResponseLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            aiResponseLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            aiResponseLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with entry: EmotionDiary) {
        emotionLabel.text = entry.selectedEmotion
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        dateLabel.text = formatter.string(from: entry.date)
        
        userMessageLabel.text = entry.userMessage    // ✅ userMessage 사용
        aiResponseLabel.text = "AI: " + entry.aiResponse  // ✅ aiResponse 사용
    }
}
