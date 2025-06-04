import UIKit

class EmotionDiaryDisplayCell: UITableViewCell {
    static let identifier = "EmotionDiaryDisplayCell"

    private let emotionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 28) // 이모티콘 크기 키움
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .light)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private let diaryContentLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.numberOfLines = 0 // 여러 줄 표시
        label.textColor = .label
        return label
    }()
    
    private let aiResponseLabel: UILabel = {
        let label = UILabel()
        label.font = .italicSystemFont(ofSize: 14)
        label.numberOfLines = 0
        label.textColor = .systemGray
        return label
    }()
    
    private let containerView: UIView = { // 내부 컨텐츠를 감싸는 뷰
        let view = UIView()
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 10
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear // 셀 자체 배경은 투명하게
        contentView.backgroundColor = .clear
        
        contentView.addSubview(containerView)
        
        let stackView = UIStackView(arrangedSubviews: [emotionLabel, dateLabel, diaryContentLabel, aiResponseLabel])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            // ContainerView를 contentView에 대해 여백을 두고 배치
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            // StackView를 containerView 내부에 여백을 두고 배치
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with diary: EmotionDiary) {
        emotionLabel.text = diary.selectedEmotion // 이모티콘 문자열
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm 작성"
        dateLabel.text = formatter.string(from: diary.date)
        
        diaryContentLabel.text = "\(diary.userMessage)"
        if !diary.aiResponse.isEmpty {
            aiResponseLabel.text = "AI 조언: \(diary.aiResponse)"
            aiResponseLabel.isHidden = false
        } else {
            aiResponseLabel.isHidden = true
        }
    }
} 