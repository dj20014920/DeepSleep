import UIKit

// MARK: - ✅ Insights Extension
extension EmotionDiaryViewController {
    
    // MARK: - Insight Generation
    func updateInsightView() {
        // 기존 뷰들 제거
        insightStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        guard !diaryEntries.isEmpty else {
            let emptyLabel = createInsightCard(
                title: "📝 아직 일기가 없어요",
                content: "감정을 기록하기 시작하면\n당신만의 패턴을 분석해드릴게요!",
                color: .systemGray5
            )
            insightStackView.addArrangedSubview(emptyLabel)
            return
        }
        
        // 1. 총 기록 수
        let totalCard = createInsightCard(
            title: "📊 총 기록",
            content: "\(diaryEntries.count)개의 감정 기록",
            color: .systemBlue.withAlphaComponent(0.1)
        )
        insightStackView.addArrangedSubview(totalCard)
        
        // 2. 가장 많이 느낀 감정
        let mostFrequentEmotion = getMostFrequentEmotion()
        let emotionCard = createInsightCard(
            title: "😊 가장 많이 느낀 감정",
            content: "\(mostFrequentEmotion.emotion) (\(mostFrequentEmotion.count)회)",
            color: .systemGreen.withAlphaComponent(0.1)
        )
        insightStackView.addArrangedSubview(emotionCard)
        
        // 3. 최근 7일 활동
        let recentActivity = getRecentActivity()
        let activityCard = createInsightCard(
            title: "📅 최근 7일",
            content: "\(recentActivity)개의 기록",
            color: .systemOrange.withAlphaComponent(0.1)
        )
        insightStackView.addArrangedSubview(activityCard)
        
        // 4. AI 추천 프리셋 사용량
        let aiPresetUsage = getAIPresetUsage()
        let presetCard = createInsightCard(
            title: "AI 추천 활용",
            content: "총 \(aiPresetUsage)번 사용",
            color: .systemPurple.withAlphaComponent(0.1)
        )
        insightStackView.addArrangedSubview(presetCard)
    }
    
    func createInsightCard(title: String, content: String, color: UIColor) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = color
        containerView.layer.cornerRadius = 12
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let contentLabel = UILabel()
        contentLabel.text = content
        contentLabel.font = .systemFont(ofSize: 14, weight: .regular)
        contentLabel.textColor = .secondaryLabel
        contentLabel.numberOfLines = 0
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(contentLabel)
        
        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            contentLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            contentLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            contentLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])
        
        return containerView
    }
    
    // MARK: - Data Analysis
    func getMostFrequentEmotion() -> (emotion: String, count: Int) {
        let emotionCounts = Dictionary(grouping: diaryEntries, by: { $0.selectedEmotion })
            .mapValues { $0.count }
        
        guard let mostFrequent = emotionCounts.max(by: { $0.value < $1.value }) else {
            return ("😊", 0)
        }
        
        return (mostFrequent.key, mostFrequent.value)
    }
    
    func getRecentActivity() -> Int {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        
        return diaryEntries.filter { $0.date >= sevenDaysAgo }.count
    }
    
    func getAIPresetUsage() -> Int {
        let allPresets = SettingsManager.shared.loadSoundPresets()
        return allPresets.filter { $0.isAIGenerated }.count
    }
}
