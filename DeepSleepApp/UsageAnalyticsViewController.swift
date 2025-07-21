import UIKit
import Core

/// 📊 사용 패턴 분석 화면
/// AI가 분석한 사용자의 음악/프리셋 선호도와 사용 패턴을 표시
class UsageAnalyticsViewController: UIViewController {
    
    // MARK: - UI Components
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIDesignSystem.Colors.primary.withAlphaComponent(0.1)
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "📊 AI가 분석한 나의 패턴"
        label.font = UIFont.boldSystemFont(ofSize: 22)
        label.textColor = UIDesignSystem.Colors.primaryText
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "당신의 음악 취향과 사용 패턴을 AI가 학습하여 분석한 결과입니다"
        label.font = UIFont.systemFont(ofSize: 15)
        label.textColor = UIDesignSystem.Colors.secondaryText
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    // MARK: - Data
    private var analyticsData: UsageAnalyticsData = UsageAnalyticsData()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadAnalyticsData()
        createAnalyticsSections()
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        navigationItem.title = "사용 패턴 분석"
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        setupHeaderSection()
        contentView.addSubview(stackView)
    }
    
    private func setupHeaderSection() {
        contentView.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // ContentView
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // HeaderView
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            subtitleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -20),
            
            // StackView
            stackView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }
    
    // MARK: - Analytics Creation
    
    private func createAnalyticsSections() {
        // 1. 음악 선호도 순위
        let musicRankingCard = createMusicRankingCard()
        stackView.addArrangedSubview(musicRankingCard)
        
        // 2. 프리셋 사용 순위
        let presetRankingCard = createPresetRankingCard()
        stackView.addArrangedSubview(presetRankingCard)
        
        // 3. 시간대별 사용 패턴
        let timePatternCard = createTimePatternCard()
        stackView.addArrangedSubview(timePatternCard)
        
        // 4. 감정 상태별 선호도
        let emotionPatternCard = createEmotionPatternCard()
        stackView.addArrangedSubview(emotionPatternCard)
        
        // 5. AI 추천 성과
        let aiInsightsCard = createAIInsightsCard()
        stackView.addArrangedSubview(aiInsightsCard)
    }
    
    private func createMusicRankingCard() -> UIView {
        let cardView = createAnalyticsCard(title: "🎵 좋아하는 음악 순위", subtitle: "가장 자주 듣는 음악 스타일")
        
        let rankingContainer = UIView()
        rankingContainer.translatesAutoresizingMaskIntoConstraints = false
        
        var lastView: UIView = rankingContainer
        
        for (index, musicData) in analyticsData.musicRankings.enumerated() {
            let rankingItem = createRankingItem(
                rank: index + 1,
                title: musicData.style,
                subtitle: "\(musicData.listenCount)회 재생",
                percentage: musicData.percentage,
                color: getMusicRankingColor(rank: index + 1)
            )
            
            rankingContainer.addSubview(rankingItem)
            
            NSLayoutConstraint.activate([
                rankingItem.leadingAnchor.constraint(equalTo: rankingContainer.leadingAnchor),
                rankingItem.trailingAnchor.constraint(equalTo: rankingContainer.trailingAnchor),
                rankingItem.topAnchor.constraint(equalTo: lastView == rankingContainer ? rankingContainer.topAnchor : lastView.bottomAnchor, constant: lastView == rankingContainer ? 0 : 12),
                rankingItem.heightAnchor.constraint(equalToConstant: 60)
            ])
            
            lastView = rankingItem
        }
        
        if lastView != rankingContainer {
            lastView.bottomAnchor.constraint(equalTo: rankingContainer.bottomAnchor).isActive = true
        }
        
        addContentToCard(cardView, content: rankingContainer)
        return cardView
    }
    
    private func createPresetRankingCard() -> UIView {
        let cardView = createAnalyticsCard(title: "⚙️ 자주 사용하는 프리셋", subtitle: "선호하는 설정 조합")
        
        let rankingContainer = UIView()
        rankingContainer.translatesAutoresizingMaskIntoConstraints = false
        
        var lastView: UIView = rankingContainer
        
        for (index, presetData) in analyticsData.presetRankings.enumerated() {
            let rankingItem = createRankingItem(
                rank: index + 1,
                title: presetData.name,
                subtitle: "\(presetData.useCount)회 사용",
                percentage: presetData.percentage,
                color: getPresetRankingColor(rank: index + 1)
            )
            
            rankingContainer.addSubview(rankingItem)
            
            NSLayoutConstraint.activate([
                rankingItem.leadingAnchor.constraint(equalTo: rankingContainer.leadingAnchor),
                rankingItem.trailingAnchor.constraint(equalTo: rankingContainer.trailingAnchor),
                rankingItem.topAnchor.constraint(equalTo: lastView == rankingContainer ? rankingContainer.topAnchor : lastView.bottomAnchor, constant: lastView == rankingContainer ? 0 : 12),
                rankingItem.heightAnchor.constraint(equalToConstant: 60)
            ])
            
            lastView = rankingItem
        }
        
        if lastView != rankingContainer {
            lastView.bottomAnchor.constraint(equalTo: rankingContainer.bottomAnchor).isActive = true
        }
        
        addContentToCard(cardView, content: rankingContainer)
        return cardView
    }
    
    private func createTimePatternCard() -> UIView {
        let cardView = createAnalyticsCard(title: "⏰ 시간대별 사용 패턴", subtitle: "언제 가장 많이 사용하시나요?")
        
        let patternContainer = UIView()
        patternContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let patterns = [
            ("새벽 (00-06시)", analyticsData.timePatterns.dawn, "🌙"),
            ("아침 (06-12시)", analyticsData.timePatterns.morning, "🌅"),
            ("오후 (12-18시)", analyticsData.timePatterns.afternoon, "☀️"),
            ("저녁 (18-24시)", analyticsData.timePatterns.evening, "🌆")
        ]
        
        var lastView: UIView = patternContainer
        
        for (timeRange, percentage, emoji) in patterns {
            let patternItem = createProgressItem(
                icon: emoji,
                title: timeRange,
                percentage: percentage,
                color: UIDesignSystem.Colors.primary
            )
            
            patternContainer.addSubview(patternItem)
            
            NSLayoutConstraint.activate([
                patternItem.leadingAnchor.constraint(equalTo: patternContainer.leadingAnchor),
                patternItem.trailingAnchor.constraint(equalTo: patternContainer.trailingAnchor),
                patternItem.topAnchor.constraint(equalTo: lastView == patternContainer ? patternContainer.topAnchor : lastView.bottomAnchor, constant: lastView == patternContainer ? 0 : 16),
                patternItem.heightAnchor.constraint(equalToConstant: 50)
            ])
            
            lastView = patternItem
        }
        
        if lastView != patternContainer {
            lastView.bottomAnchor.constraint(equalTo: patternContainer.bottomAnchor).isActive = true
        }
        
        addContentToCard(cardView, content: patternContainer)
        return cardView
    }
    
    private func createEmotionPatternCard() -> UIView {
        let cardView = createAnalyticsCard(title: "😊 감정 상태별 선호도", subtitle: "기분에 따른 음악 취향")
        
        let emotionContainer = UIView()
        emotionContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let emotions = [
            ("스트레스 받을 때", analyticsData.emotionPatterns.stressed, "😤"),
            ("슬플 때", analyticsData.emotionPatterns.sad, "😢"),
            ("행복할 때", analyticsData.emotionPatterns.happy, "😊"),
            ("차분할 때", analyticsData.emotionPatterns.calm, "😌")
        ]
        
        var lastView: UIView = emotionContainer
        
        for (emotion, preferredMusic, emoji) in emotions {
            let emotionItem = createEmotionPreferenceItem(
                icon: emoji,
                emotion: emotion,
                preferredMusic: preferredMusic
            )
            
            emotionContainer.addSubview(emotionItem)
            
            NSLayoutConstraint.activate([
                emotionItem.leadingAnchor.constraint(equalTo: emotionContainer.leadingAnchor),
                emotionItem.trailingAnchor.constraint(equalTo: emotionContainer.trailingAnchor),
                emotionItem.topAnchor.constraint(equalTo: lastView == emotionContainer ? emotionContainer.topAnchor : lastView.bottomAnchor, constant: lastView == emotionContainer ? 0 : 12),
                emotionItem.heightAnchor.constraint(equalToConstant: 50)
            ])
            
            lastView = emotionItem
        }
        
        if lastView != emotionContainer {
            lastView.bottomAnchor.constraint(equalTo: emotionContainer.bottomAnchor).isActive = true
        }
        
        addContentToCard(cardView, content: emotionContainer)
        return cardView
    }
    
    private func createAIInsightsCard() -> UIView {
        let cardView = createAnalyticsCard(title: "🤖 AI 분석 인사이트", subtitle: "당신만의 특별한 패턴")
        
        let insightsContainer = UIView()
        insightsContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let insights = analyticsData.aiInsights
        var lastView: UIView = insightsContainer
        
        for insight in insights {
            let insightItem = createInsightItem(icon: insight.icon, text: insight.text)
            
            insightsContainer.addSubview(insightItem)
            
            NSLayoutConstraint.activate([
                insightItem.leadingAnchor.constraint(equalTo: insightsContainer.leadingAnchor),
                insightItem.trailingAnchor.constraint(equalTo: insightsContainer.trailingAnchor),
                insightItem.topAnchor.constraint(equalTo: lastView == insightsContainer ? insightsContainer.topAnchor : lastView.bottomAnchor, constant: lastView == insightsContainer ? 0 : 12)
            ])
            
            lastView = insightItem
        }
        
        if lastView != insightsContainer {
            lastView.bottomAnchor.constraint(equalTo: insightsContainer.bottomAnchor).isActive = true
        }
        
        addContentToCard(cardView, content: insightsContainer)
        return cardView
    }
    
    // MARK: - Helper Methods
    
    private func createAnalyticsCard(title: String, subtitle: String) -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = UIDesignSystem.Colors.cardBackground
        cardView.layer.cornerRadius = 16
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowRadius = 4
        cardView.layer.shadowOpacity = 0.1
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIDesignSystem.Colors.primaryText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = UIDesignSystem.Colors.secondaryText
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        cardView.addSubview(titleLabel)
        cardView.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20)
        ])
        
        return cardView
    }
    
    private func addContentToCard(_ cardView: UIView, content: UIView) {
        cardView.addSubview(content)
        
        // subtitleLabel을 찾아서 그 아래에 content 배치
        if let subtitleLabel = cardView.subviews.compactMap({ $0 as? UILabel }).last {
            NSLayoutConstraint.activate([
                content.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
                content.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
                content.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
                content.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20)
            ])
        }
    }
    
    private func createRankingItem(rank: Int, title: String, subtitle: String, percentage: Int, color: UIColor) -> UIView {
        let container = UIView()
        container.backgroundColor = color.withAlphaComponent(0.1)
        container.layer.cornerRadius = 12
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let rankLabel = UILabel()
        rankLabel.text = "\(rank)"
        rankLabel.font = UIFont.boldSystemFont(ofSize: 18)
        rankLabel.textColor = color
        rankLabel.textAlignment = .center
        rankLabel.backgroundColor = color.withAlphaComponent(0.2)
        rankLabel.layer.cornerRadius = 15
        rankLabel.layer.masksToBounds = true
        rankLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = UIDesignSystem.Colors.primaryText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 13)
        subtitleLabel.textColor = UIDesignSystem.Colors.secondaryText
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let percentageLabel = UILabel()
        percentageLabel.text = "\(percentage)%"
        percentageLabel.font = UIFont.boldSystemFont(ofSize: 14)
        percentageLabel.textColor = color
        percentageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(rankLabel)
        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)
        container.addSubview(percentageLabel)
        
        NSLayoutConstraint.activate([
            rankLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            rankLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            rankLabel.widthAnchor.constraint(equalToConstant: 30),
            rankLabel.heightAnchor.constraint(equalToConstant: 30),
            
            titleLabel.leadingAnchor.constraint(equalTo: rankLabel.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            
            percentageLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            percentageLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: percentageLabel.leadingAnchor, constant: -8)
        ])
        
        return container
    }
    
    private func createProgressItem(icon: String, title: String, percentage: Int, color: UIColor) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let iconLabel = UILabel()
        iconLabel.text = icon
        iconLabel.font = UIFont.systemFont(ofSize: 20)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = UIDesignSystem.Colors.primaryText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let percentageLabel = UILabel()
        percentageLabel.text = "\(percentage)%"
        percentageLabel.font = UIFont.boldSystemFont(ofSize: 14)
        percentageLabel.textColor = color
        percentageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 프로그레스 바
        let progressBackground = UIView()
        progressBackground.backgroundColor = UIColor.systemGray5
        progressBackground.layer.cornerRadius = 4
        progressBackground.translatesAutoresizingMaskIntoConstraints = false
        
        let progressFill = UIView()
        progressFill.backgroundColor = color
        progressFill.layer.cornerRadius = 4
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        
        progressBackground.addSubview(progressFill)
        
        container.addSubview(iconLabel)
        container.addSubview(titleLabel)
        container.addSubview(percentageLabel)
        container.addSubview(progressBackground)
        
        NSLayoutConstraint.activate([
            iconLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 8),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            
            percentageLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            percentageLabel.centerYAnchor.constraint(equalTo: iconLabel.centerYAnchor),
            
            progressBackground.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            progressBackground.trailingAnchor.constraint(equalTo: percentageLabel.leadingAnchor, constant: -8),
            progressBackground.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            progressBackground.heightAnchor.constraint(equalToConstant: 8),
            
            progressFill.leadingAnchor.constraint(equalTo: progressBackground.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressBackground.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressBackground.bottomAnchor),
            progressFill.widthAnchor.constraint(equalTo: progressBackground.widthAnchor, multiplier: CGFloat(percentage) / 100.0),
            
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: percentageLabel.leadingAnchor, constant: -8)
        ])
        
        return container
    }
    
    private func createEmotionPreferenceItem(icon: String, emotion: String, preferredMusic: String) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.systemGray6
        container.layer.cornerRadius = 12
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let iconLabel = UILabel()
        iconLabel.text = icon
        iconLabel.font = UIFont.systemFont(ofSize: 20)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let emotionLabel = UILabel()
        emotionLabel.text = emotion
        emotionLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        emotionLabel.textColor = UIDesignSystem.Colors.primaryText
        emotionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let musicLabel = UILabel()
        musicLabel.text = "→ \(preferredMusic)"
        musicLabel.font = UIFont.systemFont(ofSize: 13)
        musicLabel.textColor = UIDesignSystem.Colors.primary
        musicLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(iconLabel)
        container.addSubview(emotionLabel)
        container.addSubview(musicLabel)
        
        NSLayoutConstraint.activate([
            iconLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            iconLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            emotionLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 8),
            emotionLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            musicLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            musicLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            emotionLabel.trailingAnchor.constraint(lessThanOrEqualTo: musicLabel.leadingAnchor, constant: -8)
        ])
        
        return container
    }
    
    private func createInsightItem(icon: String, text: String) -> UIView {
        let container = UIView()
        container.backgroundColor = UIDesignSystem.Colors.success.withAlphaComponent(0.1)
        container.layer.cornerRadius = 12
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let iconLabel = UILabel()
        iconLabel.text = icon
        iconLabel.font = UIFont.systemFont(ofSize: 16)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let textLabel = UILabel()
        textLabel.text = text
        textLabel.font = UIFont.systemFont(ofSize: 14)
        textLabel.textColor = UIDesignSystem.Colors.primaryText
        textLabel.numberOfLines = 0
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(iconLabel)
        container.addSubview(textLabel)
        
        NSLayoutConstraint.activate([
            iconLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            iconLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            
            textLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 8),
            textLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            textLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            textLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])
        
        return container
    }
    
    private func getMusicRankingColor(rank: Int) -> UIColor {
        switch rank {
        case 1: return UIDesignSystem.Colors.primary
        case 2: return UIDesignSystem.Colors.success
        case 3: return UIDesignSystem.Colors.warning
        default: return UIDesignSystem.Colors.warning
        }
    }
    
    private func getPresetRankingColor(rank: Int) -> UIColor {
        switch rank {
        case 1: return UIDesignSystem.Colors.accent
        case 2: return UIDesignSystem.Colors.primary
        case 3: return UIDesignSystem.Colors.secondary
        default: return UIColor.systemGray
        }
    }
    
    // MARK: - Data Loading
    
    private func loadAnalyticsData() {
        // 실제 앱에서는 UserDefaults나 Core Data에서 사용 데이터를 로드
        // 여기서는 샘플 데이터를 생성
        analyticsData = generateSampleAnalyticsData()
    }
    
    private func generateSampleAnalyticsData() -> UsageAnalyticsData {
        return UsageAnalyticsData(
            musicRankings: [
                MusicRankingData(style: "로파이", listenCount: 142, percentage: 35),
                MusicRankingData(style: "클래식", listenCount: 98, percentage: 24),
                MusicRankingData(style: "자연소리", listenCount: 76, percentage: 19),
                MusicRankingData(style: "재즈", listenCount: 45, percentage: 11),
                MusicRankingData(style: "앰비언트", listenCount: 31, percentage: 8)
            ],
            presetRankings: [
                PresetRankingData(name: "편안한 밤 🌙", useCount: 89, percentage: 42),
                PresetRankingData(name: "집중 모드 🎯", useCount: 67, percentage: 31),
                PresetRankingData(name: "명상 시간 🧘", useCount: 34, percentage: 16),
                PresetRankingData(name: "커스텀 #1", useCount: 23, percentage: 11)
            ],
            timePatterns: UsageTimePatternData(dawn: 15, morning: 25, afternoon: 20, evening: 40),
            emotionPatterns: EmotionPatternData(stressed: "로파이, 클래식", sad: "클래식, 피아노", happy: "팝, 재즈", calm: "자연소리, 앰비언트"),
            aiInsights: [
                AIInsightData(icon: "🎯", text: "스트레스 받을 때 로파이 음악을 듣고 나면 93% 확률로 긍정적인 감정 변화를 보입니다"),
                AIInsightData(icon: "⏰", text: "저녁 시간대(18-24시)에 가장 활발하게 앱을 사용하며, 이때 클래식 음악을 선호합니다"),
                AIInsightData(icon: "🌙", text: "수면 전 30분 동안 자연소리를 들으면 다음날 기분이 15% 더 좋아지는 패턴을 발견했습니다"),
                AIInsightData(icon: "💡", text: "월요일과 화요일에는 업템포 음악을, 주말에는 차분한 음악을 선호하는 경향이 있습니다")
            ]
        )
    }
}

// MARK: - Data Models

struct UsageAnalyticsData {
    let musicRankings: [MusicRankingData]
    let presetRankings: [PresetRankingData]
    let timePatterns: UsageTimePatternData
    let emotionPatterns: EmotionPatternData
    let aiInsights: [AIInsightData]
    
    init(musicRankings: [MusicRankingData] = [],
         presetRankings: [PresetRankingData] = [],
         timePatterns: UsageTimePatternData = UsageTimePatternData(dawn: 0, morning: 0, afternoon: 0, evening: 0),
         emotionPatterns: EmotionPatternData = EmotionPatternData(stressed: "", sad: "", happy: "", calm: ""),
         aiInsights: [AIInsightData] = []) {
        self.musicRankings = musicRankings
        self.presetRankings = presetRankings
        self.timePatterns = timePatterns
        self.emotionPatterns = emotionPatterns
        self.aiInsights = aiInsights
    }
}

struct MusicRankingData {
    let style: String
    let listenCount: Int
    let percentage: Int
}

struct PresetRankingData {
    let name: String
    let useCount: Int
    let percentage: Int
}


struct UsageTimePatternData {
    let dawn: Int      // 0-6시
    let morning: Int   // 6-12시
    let afternoon: Int // 12-18시
    let evening: Int   // 18-24시
}

struct EmotionPatternData {
    let stressed: String
    let sad: String
    let happy: String
    let calm: String
}

struct AIInsightData {
    let icon: String
    let text: String
}