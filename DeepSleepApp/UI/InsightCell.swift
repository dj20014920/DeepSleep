import UIKit

/// 감정 분석 결과를 표시하는 컬렉션 뷰 셀
class InsightCell: UICollectionViewCell {
    static let reuseIdentifier = "InsightCell"
    
    // MARK: - UI Components
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIDesignSystem.Colors.adaptiveTertiaryBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let iconLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 24)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = UIDesignSystem.Colors.primaryText
        label.textAlignment = .center
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let contentLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIDesignSystem.Colors.secondaryText
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    private func setupUI() {
        contentView.addSubview(containerView)
        containerView.addSubview(stackView)
        
        stackView.addArrangedSubview(iconLabel)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(contentLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            iconLabel.heightAnchor.constraint(equalToConstant: 32),
            titleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 20)
        ])
    }
    
    // MARK: - Configuration
    func configure(with text: String) {
        // 텍스트에서 감정 정보 추출 및 표시
        parseAndDisplayInsight(text)
    }
    
    func configure(with emotion: String, intensity: Float, description: String) {
        iconLabel.text = getEmotionIcon(for: emotion)
        titleLabel.text = emotion
        contentLabel.text = description
        
        // 강도에 따른 색상 조정
        let intensityColor = getIntensityColor(for: intensity)
        containerView.backgroundColor = intensityColor.withAlphaComponent(0.1)
        containerView.layer.borderColor = intensityColor.cgColor
        containerView.layer.borderWidth = 1
    }
    
    func configure(with insight: EmotionInsight) {
        iconLabel.text = getEmotionIcon(for: insight.emotion)
        titleLabel.text = insight.emotion
        contentLabel.text = insight.description
        
        let intensityColor = getIntensityColor(for: insight.intensity)
        containerView.backgroundColor = intensityColor.withAlphaComponent(0.1)
        containerView.layer.borderColor = intensityColor.cgColor
        containerView.layer.borderWidth = 1
    }
    
    // MARK: - Helper Methods
    private func parseAndDisplayInsight(_ text: String) {
        // 간단한 텍스트 파싱으로 감정 정보 추출
        let lowercased = text.lowercased()
        
        var emotion = "평온"
        var intensity: Float = 0.5
        
        if lowercased.contains("행복") || lowercased.contains("기쁨") {
            emotion = "행복"
            intensity = 0.8
        } else if lowercased.contains("슬픔") || lowercased.contains("우울") {
            emotion = "슬픔"
            intensity = 0.7
        } else if lowercased.contains("불안") || lowercased.contains("걱정") {
            emotion = "불안"
            intensity = 0.6
        } else if lowercased.contains("스트레스") || lowercased.contains("압박") {
            emotion = "스트레스"
            intensity = 0.8
        } else if lowercased.contains("평온") || lowercased.contains("차분") {
            emotion = "평온"
            intensity = 0.4
        }
        
        configure(with: emotion, intensity: intensity, description: text)
    }
    
    private func getEmotionIcon(for emotion: String) -> String {
        switch emotion.lowercased() {
        case "행복", "기쁨":
            return "😊"
        case "슬픔", "우울":
            return "😔"
        case "불안", "걱정":
            return "😰"
        case "스트레스", "압박":
            return "😤"
        case "평온", "차분":
            return "😌"
        case "피곤", "지침":
            return "😴"
        case "활력", "에너지":
            return "⚡"
        default:
            return "🙂"
        }
    }
    
    private func getIntensityColor(for intensity: Float) -> UIColor {
        switch intensity {
        case 0.0..<0.3:
            return UIColor.systemGreen
        case 0.3..<0.6:
            return UIColor.systemYellow
        case 0.6..<0.8:
            return UIColor.systemOrange
        case 0.8...1.0:
            return UIColor.systemRed
        default:
            return UIColor.systemGray
        }
    }
    
    // MARK: - Lifecycle
    override func prepareForReuse() {
        super.prepareForReuse()
        iconLabel.text = nil
        titleLabel.text = nil
        contentLabel.text = nil
        containerView.backgroundColor = UIDesignSystem.Colors.adaptiveTertiaryBackground
        containerView.layer.borderWidth = 0
    }
}

// MARK: - Supporting Types
struct EmotionInsight {
    let emotion: String
    let intensity: Float
    let description: String
    let timestamp: Date
    
    init(emotion: String, intensity: Float, description: String) {
        self.emotion = emotion
        self.intensity = intensity
        self.description = description
        self.timestamp = Date()
    }
} 