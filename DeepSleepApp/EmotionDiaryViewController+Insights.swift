import UIKit

// MARK: - ✅ Insights Extension with Schedule Dropdown
extension EmotionDiaryViewController {
    
    // MARK: - Insight Generation
    func updateInsightView() {
        // 기존 뷰들 제거
        insightStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        guard !diaryEntries.isEmpty else {
            let emptyLabel = createInsightCard(
                title: "📝 아직 일기가 없어요",
                content: "감정을 기록하기 시작하면\n당신만의 패턴을 분석해드릴게요!",
                color: .systemGray5,
                isDropdownEnabled: false
            )
            insightStackView.addArrangedSubview(emptyLabel)
            return
        }
        
        // 1. 총 기록 수 (드롭다운)
        let totalCard = createInsightCard(
            title: "📊 총 기록",
            content: "\(diaryEntries.count)개의 감정 기록",
            color: .systemBlue.withAlphaComponent(0.1),
            isDropdownEnabled: true,
            dropdownType: .totalRecords
        )
        insightStackView.addArrangedSubview(totalCard)
        
        // 2. 가장 많이 느낀 감정 (드롭다운)
        let mostFrequentEmotion = getMostFrequentEmotion()
        let emotionCard = createInsightCard(
            title: "😊 가장 많이 느낀 감정",
            content: "\(mostFrequentEmotion.emotion) (\(mostFrequentEmotion.count)회)",
            color: .systemGreen.withAlphaComponent(0.1),
            isDropdownEnabled: true,
            dropdownType: .emotionAnalysis
        )
        insightStackView.addArrangedSubview(emotionCard)
        
        // 3. 최근 7일 활동 (드롭다운)
        let recentActivity = getRecentActivity()
        let activityCard = createInsightCard(
            title: "📅 최근 7일",
            content: "\(recentActivity)개의 기록",
            color: .systemOrange.withAlphaComponent(0.1),
            isDropdownEnabled: true,
            dropdownType: .recentActivity
        )
        insightStackView.addArrangedSubview(activityCard)
        
        // 4. AI 추천 프리셋 사용량 (드롭다운)
        let aiPresetUsage = getAIPresetUsage()
        let presetCard = createInsightCard(
            title: "🤖 AI 추천 활용",
            content: "총 \(aiPresetUsage)번 사용",
            color: .systemPurple.withAlphaComponent(0.1),
            isDropdownEnabled: true,
            dropdownType: .aiRecommendations
        )
        insightStackView.addArrangedSubview(presetCard)
        
        // 5. 📅 이번 달 약속/일정 (NEW - 드롭다운)
        let monthlySchedules = getMonthlyScheduleData()
        let scheduleCard = createInsightCard(
            title: "📅 이번 달 약속",
            content: "총 \(monthlySchedules.totalCount)개 일정",
            color: .systemTeal.withAlphaComponent(0.1),
            isDropdownEnabled: true,
            dropdownType: .monthlySchedules
        )
        insightStackView.addArrangedSubview(scheduleCard)
        
        // 6. 🎯 중요한 일정 (NEW - 드롭다운)
        let importantSchedules = getImportantScheduleData()
        let importantCard = createInsightCard(
            title: "🎯 중요한 일정",
            content: "우선순위 높음 \(importantSchedules.count)개",
            color: .systemRed.withAlphaComponent(0.1),
            isDropdownEnabled: true,
            dropdownType: .importantSchedules
        )
        insightStackView.addArrangedSubview(importantCard)
    }
    
    // MARK: - Enhanced Card Creation with Dropdown
    func createInsightCard(title: String, content: String, color: UIColor, isDropdownEnabled: Bool, dropdownType: InsightDropdownType? = nil) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = color
        containerView.layer.cornerRadius = 12
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // 메인 컨텐츠 뷰
        let mainContentView = UIView()
        mainContentView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(mainContentView)
        
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
        
        // 드롭다운 화살표 (있는 경우)
        let dropdownArrow = UILabel()
        if isDropdownEnabled {
            dropdownArrow.text = "▼"
            dropdownArrow.font = .systemFont(ofSize: 12, weight: .medium)
            dropdownArrow.textColor = .systemBlue
            dropdownArrow.translatesAutoresizingMaskIntoConstraints = false
        }
        
        mainContentView.addSubview(titleLabel)
        mainContentView.addSubview(contentLabel)
        if isDropdownEnabled {
            mainContentView.addSubview(dropdownArrow)
        }
        
        // 드롭다운 컨텐츠 뷰 (초기에는 숨김)
        let dropdownContentView = UIView()
        dropdownContentView.backgroundColor = color.withAlphaComponent(0.3)
        dropdownContentView.layer.cornerRadius = 8
        dropdownContentView.translatesAutoresizingMaskIntoConstraints = false
        dropdownContentView.isHidden = true
        containerView.addSubview(dropdownContentView)
        
        let dropdownLabel = UILabel()
        dropdownLabel.font = .systemFont(ofSize: 13, weight: .regular)
        dropdownLabel.textColor = .label
        dropdownLabel.numberOfLines = 0
        dropdownLabel.translatesAutoresizingMaskIntoConstraints = false
        dropdownContentView.addSubview(dropdownLabel)
        
        // 제약조건 설정
        var constraints = [
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            mainContentView.topAnchor.constraint(equalTo: containerView.topAnchor),
            mainContentView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            mainContentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: mainContentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: mainContentView.leadingAnchor, constant: 16),
            
            contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            contentLabel.leadingAnchor.constraint(equalTo: mainContentView.leadingAnchor, constant: 16),
            contentLabel.trailingAnchor.constraint(equalTo: mainContentView.trailingAnchor, constant: -16),
            contentLabel.bottomAnchor.constraint(equalTo: mainContentView.bottomAnchor, constant: -12),
            
            dropdownContentView.topAnchor.constraint(equalTo: mainContentView.bottomAnchor),
            dropdownContentView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            dropdownContentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            dropdownContentView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
            
            dropdownLabel.topAnchor.constraint(equalTo: dropdownContentView.topAnchor, constant: 12),
            dropdownLabel.leadingAnchor.constraint(equalTo: dropdownContentView.leadingAnchor, constant: 12),
            dropdownLabel.trailingAnchor.constraint(equalTo: dropdownContentView.trailingAnchor, constant: -12),
            dropdownLabel.bottomAnchor.constraint(equalTo: dropdownContentView.bottomAnchor, constant: -12)
        ]
        
        if isDropdownEnabled {
            constraints.append(contentsOf: [
                dropdownArrow.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
                dropdownArrow.trailingAnchor.constraint(equalTo: mainContentView.trailingAnchor, constant: -16),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: dropdownArrow.leadingAnchor, constant: -8)
            ])
        } else {
            constraints.append(titleLabel.trailingAnchor.constraint(equalTo: mainContentView.trailingAnchor, constant: -16))
        }
        
        NSLayoutConstraint.activate(constraints)
        
        // 터치 제스처 추가 (드롭다운 가능한 경우)
        if isDropdownEnabled, let dropdownType = dropdownType {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleCardTap(_:)))
            containerView.addGestureRecognizer(tapGesture)
            containerView.isUserInteractionEnabled = true
            
            // 드롭다운 정보 저장
            containerView.tag = dropdownType.rawValue
            dropdownArrow.tag = 999 // 화살표 식별용
            dropdownContentView.tag = 888 // 드롭다운 컨텐츠 식별용
            dropdownLabel.tag = 777 // 드롭다운 라벨 식별용
        }
        
        return containerView
    }
    
    // MARK: - Dropdown Types
    enum InsightDropdownType: Int {
        case totalRecords = 1
        case emotionAnalysis = 2
        case recentActivity = 3
        case aiRecommendations = 4
        case monthlySchedules = 5
        case importantSchedules = 6
    }
    
    // MARK: - Tap Handler
    @objc private func handleCardTap(_ gesture: UITapGestureRecognizer) {
        guard let containerView = gesture.view,
              let dropdownType = InsightDropdownType(rawValue: containerView.tag) else { return }
        
        let dropdownContentView = containerView.viewWithTag(888)!
        let dropdownArrow = containerView.viewWithTag(999) as! UILabel
        let dropdownLabel = containerView.viewWithTag(777) as! UILabel
        
        let isExpanded = !dropdownContentView.isHidden
        
        // 애니메이션으로 드롭다운 토글
        UIView.animate(withDuration: 0.3) {
            dropdownContentView.isHidden = isExpanded
            dropdownArrow.text = isExpanded ? "▼" : "▲"
            
            if !isExpanded {
                // 드롭다운 컨텐츠 설정
                dropdownLabel.text = self.getDropdownContent(for: dropdownType)
            }
        }
    }
    
    // MARK: - Dropdown Content Generation
    private func getDropdownContent(for type: InsightDropdownType) -> String {
        switch type {
        case .totalRecords:
            return generateTotalRecordsDetail()
        case .emotionAnalysis:
            return generateEmotionAnalysisDetail()
        case .recentActivity:
            return generateRecentActivityDetail()
        case .aiRecommendations:
            return generateAIRecommendationsDetail()
        case .monthlySchedules:
            return generateMonthlySchedulesDetail()
        case .importantSchedules:
            return generateImportantSchedulesDetail()
        }
    }
    
    // MARK: - Content Generators
    private func generateTotalRecordsDetail() -> String {
        let emotionCounts = Dictionary(grouping: diaryEntries, by: { $0.selectedEmotion })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        var detail = "감정별 기록 현황:\n"
        for (emotion, count) in emotionCounts.prefix(5) {
            detail += "• \(emotion): \(count)회\n"
        }
        return detail
    }
    
    private func generateEmotionAnalysisDetail() -> String {
        let emotionCounts = Dictionary(grouping: diaryEntries, by: { $0.selectedEmotion })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        var detail = "감정 분석 상세:\n"
        for (index, (emotion, count)) in emotionCounts.enumerated() {
            let percentage = Int((Double(count) / Double(diaryEntries.count)) * 100)
            detail += "\(index + 1). \(emotion): \(count)회 (\(percentage)%)\n"
        }
        return detail
    }
    
    private func generateRecentActivityDetail() -> String {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        let recentEntries = diaryEntries.filter { $0.date >= sevenDaysAgo }
            .sorted { $0.date > $1.date }
        
        var detail = "최근 7일 활동:\n"
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        
        for entry in recentEntries.prefix(5) {
            detail += "• \(formatter.string(from: entry.date)): \(entry.selectedEmotion)\n"
        }
        return detail.isEmpty ? "최근 7일간 기록이 없습니다." : detail
    }
    
    private func generateAIRecommendationsDetail() -> String {
        let allPresets = SettingsManager.shared.loadSoundPresets()
        let aiPresets = allPresets.filter { $0.isAIGenerated }
        
        var detail = "AI 추천 활용 내역:\n"
        for (index, preset) in aiPresets.enumerated() {
            if index < 3 {
                detail += "• \(preset.name): \(preset.description ?? "설명 없음")\n"
            }
        }
        
        if aiPresets.count > 3 {
            detail += "• 외 \(aiPresets.count - 3)개 더..."
        }
        
        return detail.isEmpty ? "AI 추천 사용 내역이 없습니다." : detail
    }
    
    private func generateMonthlySchedulesDetail() -> String {
        let monthlyData = getMonthlyScheduleData()
        
        var detail = "이번 달 일정 상세:\n"
        detail += "• 전체 일정: \(monthlyData.totalCount)개\n"
        detail += "• 완료된 일정: \(monthlyData.completedCount)개\n"
        detail += "• 진행 중인 일정: \(monthlyData.pendingCount)개\n"
        
        if !monthlyData.upcomingTodos.isEmpty {
            detail += "\n다가오는 일정:\n"
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            
            for todo in monthlyData.upcomingTodos.prefix(3) {
                detail += "• \(formatter.string(from: todo.dueDate)): \(todo.title)\n"
            }
        }
        
        return detail
    }
    
    private func generateImportantSchedulesDetail() -> String {
        let importantSchedules = getImportantScheduleData()
        
        var detail = "중요한 일정 상세:\n"
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        
        for (index, todo) in importantSchedules.enumerated() {
            if index < 5 {
                let status = todo.isCompleted ? "[완료]" : "[진행중]"
                detail += "• \(formatter.string(from: todo.dueDate)): \(todo.title) \(status)\n"
            }
        }
        
        if importantSchedules.count > 5 {
            detail += "• 외 \(importantSchedules.count - 5)개 더..."
        }
        
        return detail.isEmpty ? "중요한 일정이 없습니다." : detail
    }
    
    // MARK: - Schedule Data Helpers
    private func getMonthlyScheduleData() -> (totalCount: Int, completedCount: Int, pendingCount: Int, upcomingTodos: [TodoItem]) {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        
        let monthlyTodos = TodoManager.shared.loadTodos().filter {
            let todoMonth = calendar.component(.month, from: $0.dueDate)
            let todoYear = calendar.component(.year, from: $0.dueDate)
            return todoMonth == currentMonth && todoYear == currentYear
        }
        
        let completedCount = monthlyTodos.filter { $0.isCompleted }.count
        let pendingCount = monthlyTodos.count - completedCount
        let upcomingTodos = monthlyTodos.filter { !$0.isCompleted && $0.dueDate > Date() }
            .sorted { $0.dueDate < $1.dueDate }
        
        return (monthlyTodos.count, completedCount, pendingCount, upcomingTodos)
    }
    
    private func getImportantScheduleData() -> [TodoItem] {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        
        return TodoManager.shared.loadTodos().filter {
            let todoMonth = calendar.component(.month, from: $0.dueDate)
            let todoYear = calendar.component(.year, from: $0.dueDate)
            return todoMonth == currentMonth && todoYear == currentYear && $0.priority >= 2
        }.sorted { $0.dueDate < $1.dueDate }
    }
    
    // MARK: - Data Analysis (기존 메서드들)
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
