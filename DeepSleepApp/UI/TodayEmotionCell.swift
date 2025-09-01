import UIKit

final class TodayEmotionCell: UICollectionViewCell {
    static let reuseIdentifier = "TodayEmotionCell"
    
    // MARK: - Callbacks
    var onWriteAction: (() -> Void)?
    
    // MARK: - UI
    private let containerView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIDesignSystem.Colors.adaptiveTertiaryBackground
        v.layer.cornerRadius = UIDesignSystem.CornerRadius.large
        v.layer.borderWidth = 1
        v.layer.borderColor = UIDesignSystem.Colors.border.cgColor
        return v
    }()
    
    private let emojiLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 32)
        l.textAlignment = .center
        l.numberOfLines = 1
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.6
        l.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return l
    }()
    
    private let nameLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = UIDesignSystem.Colors.primaryText
        l.textAlignment = .center
        return l
    }()
    
    private let guidanceLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 14)
        l.textColor = UIDesignSystem.Colors.secondaryText
        l.textAlignment = .center
        l.numberOfLines = 0
        l.isHidden = true
        return l
    }()
    
    private let writeButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("일기 쓰기", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        b.backgroundColor = .systemBlue
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 10
        b.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        b.isHidden = true
        return b
    }()
    
    private let stack: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .vertical
        s.alignment = .center
        s.spacing = 8
        return s
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        contentView.addSubview(containerView)
        containerView.addSubview(stack)
        
        [emojiLabel, nameLabel, guidanceLabel, writeButton].forEach { stack.addArrangedSubview($0) }
        
        writeButton.addTarget(self, action: #selector(handleWrite), for: .touchUpInside)
        
        // 은은한 그림자 적용 (기존 카드 스타일 복원)
        containerView.applyShadow(UIDesignSystem.Shadow.small())
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            stack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            emojiLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        emojiLabel.text = nil
        nameLabel.text = nil
        guidanceLabel.text = nil
        guidanceLabel.isHidden = true
        writeButton.isHidden = true
        onWriteAction = nil
    }
    
    func configure(with diary: EmotionDiary?, isToday: Bool) {
        if let diary = diary {
            // 오늘의 감정 존재 → 감정색 기반 파스텔 카드 스타일
            let emoji = diary.selectedEmotion // 저장된 값이 이모지라 가정
            emojiLabel.text = emoji
            let name = CommonUtilities.shared.mapEmojiToEmotionName(emoji)
            nameLabel.text = name
            guidanceLabel.isHidden = true
            writeButton.isHidden = true
            
            // 감정 색상 적용 (배경은 연하게, 보더는 원색)
            let tone = CommonUtilities.shared.getEmotionColor(emotion: name)
            containerView.backgroundColor = tone.withAlphaComponent(0.12)
            containerView.layer.borderColor = tone.cgColor
        } else {
            // 감정 미기록
            emojiLabel.text = isToday ? "📝" : "📭"
            nameLabel.text = isToday ? "오늘 감정 미입력" : "기록 없음"
            guidanceLabel.text = isToday ? "아직 오늘의 감정을 알려주시지 않았어요!\n입력하러 가볼까요?" : "이 날짜에는 감정 일기를 작성하지 않으셨어요."
            guidanceLabel.isHidden = false
            writeButton.isHidden = !isToday
            
            // 미기록 색상 (오늘: 강조, 과거: 중립)
            if isToday {
                containerView.backgroundColor = UIDesignSystem.Colors.accentLight
                containerView.layer.borderColor = UIDesignSystem.Colors.accent.cgColor
            } else {
                containerView.backgroundColor = UIDesignSystem.Colors.adaptiveTertiaryBackground
                containerView.layer.borderColor = UIDesignSystem.Colors.border.cgColor
            }
        }
    }
    
    @objc private func handleWrite() {
        onWriteAction?()
    }
}

