import UIKit

/// 📊 사용 패턴 분석 화면 (SessionManager 기반)
/// SessionManager에서 실제 사용자 데이터를 가져와 분석 결과를 표시
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
        label.text = "📊 대나무숲 친구가 분석한 나의 패턴"
        label.font = UIFont.boldSystemFont(ofSize: 22)
        label.textColor = UIDesignSystem.Colors.primaryText
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "SessionManager에서 수집된 실제 사용 데이터를 기반으로 분석한 결과입니다"
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
        
        // 구독 상태 바인딩 (중앙형 패턴)
        _ = SubscriptionUIBinder.attach(to: self) { [weak self] _ in
            self?.reloadAnalyticsUI()
        }
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
        // 1. 프리셋 사용 순위
        let presetRankingCard = createPresetRankingCard()
        stackView.addArrangedSubview(presetRankingCard)
        
        // 2. 시간대별 사용 패턴
        let timePatternCard = createTimePatternCard()
        stackView.addArrangedSubview(timePatternCard)
        
        // 3. AI 인사이트
        let aiInsightsCard = createAIInsightsCard()
        stackView.addArrangedSubview(aiInsightsCard)
    }
    
    private func createPresetRankingCard() -> UIView {
        let cardView = createAnalyticsCard(title: "⚙️ 자주 사용하는 프리셋", subtitle: "SessionManager 데이터 기반")
        
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
    
    private func createAIInsightsCard() -> UIView {
        let cardView = createAnalyticsCard(title: "🧠 대나무숲 분석 인사이트", subtitle: "SessionManager 데이터 기반 분석")
        
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
    
    private func reloadAnalyticsUI() {
        // 간단히 스택을 비우고 다시 구성 (YAGNI: 최소 구현)
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        createAnalyticsSections()
    }
    
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
    
    private func getPresetRankingColor(rank: Int) -> UIColor {
        switch rank {
        case 1: return UIDesignSystem.Colors.accent
        case 2: return UIDesignSystem.Colors.primary
        case 3: return UIDesignSystem.Colors.secondary
        default: return UIColor.systemGray
        }
    }
    
    // MARK: - Data Loading (SessionManager 기반)
    
    private func loadAnalyticsData() {
        // SessionManager에서 실제 데이터 로드
        let sessions = SessionManager.shared.getRecentSessions(limit: AppConfig.Pagination.usageAnalyticsSessionLimit)
        let behaviorEvents = SessionManager.shared.getRecentBehaviorEvents(limit: AppConfig.Pagination.usageAnalyticsSessionLimit)
        
        if !sessions.isEmpty {
            analyticsData = createAnalyticsDataFromSessions(sessions, behaviorEvents: behaviorEvents)
            print("✅ [UsageAnalytics] SessionManager 데이터 로드 완료: \(sessions.count)개 세션")
        } else {
            // 데이터가 없을 때만 샘플 데이터 사용
            analyticsData = generateSampleAnalyticsData()
            print("⚠️ [UsageAnalytics] 실제 데이터 없음 - 샘플 데이터 사용")
        }
    }
    
    /// SessionManager 데이터를 분석 데이터로 변환
    private func createAnalyticsDataFromSessions(_ sessions: [UnifiedSession], behaviorEvents: [BehaviorEvent]) -> UsageAnalyticsData {
        let presetRankings = createPresetRankingsFromSessions(sessions)
        let timePatterns = createTimePatternFromSessions(sessions)
        let aiInsights = generateAIInsightsFromSessions(sessions, behaviorEvents: behaviorEvents)
        
        return UsageAnalyticsData(
            musicRankings: [], // 음악 순위는 현재 사용하지 않음
            presetRankings: presetRankings,
            timePatterns: timePatterns,
            emotionPatterns: EmotionPatternData(
                stressed: "자연음",
                sad: "클래식",
                happy: "업비트",
                calm: "백색소음"
            ),
            aiInsights: aiInsights
        )
    }
    
    /// 세션 데이터에서 프리셋 순위 생성
    private func createPresetRankingsFromSessions(_ sessions: [UnifiedSession]) -> [PresetRankingData] {
        // 피드백 데이터에서 프리셋 이름 추출
        var presetNames: [String] = []
        for session in sessions {
            for feedback in session.feedbackData {
                presetNames.append(feedback.presetName ?? "기본 프리셋")
            }
        }
        
        let presetCounts = Dictionary(grouping: presetNames, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(5)
        
        let totalCount = presetNames.count
        
        return Array(presetCounts.enumerated().map { index, element in
            PresetRankingData(
                name: element.key,
                useCount: element.value,
                percentage: totalCount > 0 ? Int((Double(element.value) / Double(totalCount)) * 100) : 0
            )
        })
    }
    
    /// 세션 데이터에서 시간대별 패턴 생성
    private func createTimePatternFromSessions(_ sessions: [UnifiedSession]) -> UsageTimePatternData {
        let calendar = Calendar.current
        
        let dawnSessions = sessions.filter { 
            let hour = calendar.component(.hour, from: $0.createdAt)
            return hour >= 0 && hour < 6
        }.count
        
        let morningSessions = sessions.filter { 
            let hour = calendar.component(.hour, from: $0.createdAt)
            return hour >= 6 && hour < 12
        }.count
        
        let afternoonSessions = sessions.filter { 
            let hour = calendar.component(.hour, from: $0.createdAt)
            return hour >= 12 && hour < 18
        }.count
        
        let eveningSessions = sessions.filter { 
            let hour = calendar.component(.hour, from: $0.createdAt)
            return hour >= 18 && hour < 24
        }.count
        
        let totalSessions = sessions.count
        
        return UsageTimePatternData(
            dawn: totalSessions > 0 ? Int((Double(dawnSessions) / Double(totalSessions)) * 100) : 0,
            morning: totalSessions > 0 ? Int((Double(morningSessions) / Double(totalSessions)) * 100) : 0,
            afternoon: totalSessions > 0 ? Int((Double(afternoonSessions) / Double(totalSessions)) * 100) : 0,
            evening: totalSessions > 0 ? Int((Double(eveningSessions) / Double(totalSessions)) * 100) : 0
        )
    }
    
    /// SessionManager 데이터에서 AI 인사이트 생성
    private func generateAIInsightsFromSessions(_ sessions: [UnifiedSession], behaviorEvents: [BehaviorEvent]) -> [AIInsightData] {
        var insights: [AIInsightData] = []
        
        // 세션 수 기반 인사이트
        if sessions.count > 10 {
            insights.append(AIInsightData(
                icon: "🎯",
                text: "총 \(sessions.count)개의 세션을 완료했습니다. 꾸준한 사용 패턴을 보이고 있어요!"
            ))
        }
        
        // 가장 인기 있는 프리셋 인사이트 (피드백 데이터 기반)
        var allPresetNames: [String] = []
        for session in sessions {
            for feedback in session.feedbackData {
                allPresetNames.append(feedback.presetName ?? "기본 프리셋")
            }
        }
        
        if let mostUsedPreset = Dictionary(grouping: allPresetNames, by: { $0 })
            .max(by: { $0.value.count < $1.value.count }) {
            insights.append(AIInsightData(
                icon: "⭐",
                text: "'\(mostUsedPreset.key)' 프리셋을 가장 선호하시네요! (\(mostUsedPreset.value.count)회 사용)"
            ))
        }
        
        // 평균 세션 활동 시간 인사이트
        let totalDuration = sessions.reduce(0.0) { result, session in
            return result + session.lastActivityAt.timeIntervalSince(session.createdAt)
        }
        let avgDuration = totalDuration / Double(max(sessions.count, 1))
        if avgDuration > 0 {
            let minutes = Int(avgDuration / 60)
            insights.append(AIInsightData(
                icon: "⏱️",
                text: "평균 세션 활동 시간은 \(minutes)분입니다."
            ))
        }
        
        // 행동 이벤트 기반 인사이트
        let feedbackEvents = behaviorEvents.filter { $0.type == .feedback }.count
        if feedbackEvents > 0 {
            insights.append(AIInsightData(
                icon: "💬",
                text: "\(feedbackEvents)개의 피드백을 남겨주셨습니다. 소중한 의견 감사합니다!"
            ))
        }
        
        return insights.isEmpty ? [AIInsightData(icon: "💡", text: "사용 데이터를 더 수집하면 개인화된 인사이트를 제공할 수 있습니다.")] : insights
    }
    
    /// 샘플 데이터 생성 (실제 데이터가 없을 때만 사용)
    private func generateSampleAnalyticsData() -> UsageAnalyticsData {
        return UsageAnalyticsData(
            musicRankings: [],
            presetRankings: [
                PresetRankingData(name: "기본 프리셋", useCount: 15, percentage: 45),
                PresetRankingData(name: "집중 모드", useCount: 10, percentage: 30),
                PresetRankingData(name: "휴식 모드", useCount: 8, percentage: 25)
            ],
            timePatterns: UsageTimePatternData(dawn: 10, morning: 30, afternoon: 35, evening: 25),
            emotionPatterns: EmotionPatternData(
                stressed: "자연음",
                sad: "클래식",
                happy: "업비트",
                calm: "백색소음"
            ),
            aiInsights: [
                AIInsightData(icon: "💡", text: "아직 충분한 데이터가 수집되지 않았습니다. 더 사용하시면 개인화된 분석을 제공할 수 있어요!")
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