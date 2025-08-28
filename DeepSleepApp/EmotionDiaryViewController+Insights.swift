import UIKit

// MARK: - ✅ Insights Extension with Schedule Dropdown
extension EmotionDiaryViewController {
    
    // MARK: - Insight Generation
    func updateInsightView() {
        // 🔧 메인 스레드에서 UI 업데이트 보장
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.updateInsightView()
            }
            return
        }
        
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
        
        // 🔧 스페이서 추가: 남은 공간을 채워서 카드들이 늘어나지 않도록 함
        let spacerView = UIView()
        spacerView.translatesAutoresizingMaskIntoConstraints = false
        spacerView.setContentHuggingPriority(.init(1), for: .vertical) // 가장 낮은 우선순위
        spacerView.setContentCompressionResistancePriority(.init(1), for: .vertical) // 가장 낮은 우선순위
        spacerView.backgroundColor = .clear
        insightStackView.addArrangedSubview(spacerView)
        
        // 🔧 인사이트 뷰 업데이트 후 스크롤 크기 즉시 조정
        updateInsightScrollViewContentSize()
        
    }
    
    // MARK: - Enhanced Card Creation with Dropdown
    func createInsightCard(title: String, content: String, color: UIColor, isDropdownEnabled: Bool, dropdownType: InsightDropdownType? = nil) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = color
        containerView.layer.cornerRadius = 12
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.clipsToBounds = true
        
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
            // 🔧 컨테이너는 최소 높이만 지정, 최대는 제한 없음
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            mainContentView.topAnchor.constraint(equalTo: containerView.topAnchor),
            mainContentView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            mainContentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            // 🔧 mainContentView 고정 높이 설정 (압축 방지)
            mainContentView.heightAnchor.constraint(equalToConstant: 80),
            
            titleLabel.topAnchor.constraint(equalTo: mainContentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: mainContentView.leadingAnchor, constant: 16),
            
            contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            contentLabel.leadingAnchor.constraint(equalTo: mainContentView.leadingAnchor, constant: 16),
            contentLabel.trailingAnchor.constraint(equalTo: mainContentView.trailingAnchor, constant: -16),
            contentLabel.bottomAnchor.constraint(lessThanOrEqualTo: mainContentView.bottomAnchor, constant: -12), // 🔧 lessThanOrEqualTo로 변경
            
            dropdownContentView.topAnchor.constraint(equalTo: mainContentView.bottomAnchor),
            dropdownContentView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            dropdownContentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            
            dropdownLabel.topAnchor.constraint(equalTo: dropdownContentView.topAnchor, constant: 12),
            dropdownLabel.leadingAnchor.constraint(equalTo: dropdownContentView.leadingAnchor, constant: 12),
            dropdownLabel.trailingAnchor.constraint(equalTo: dropdownContentView.trailingAnchor, constant: -12),
            dropdownLabel.bottomAnchor.constraint(equalTo: dropdownContentView.bottomAnchor, constant: -12)
        ]
        
        // PERF-WARNING: 동적 제약조건 관리 - 메모리 누수 방지를 위해 height constraint 사용
        var dropdownHeightConstraint: NSLayoutConstraint?
        
        if isDropdownEnabled {
            // 드롭다운이 활성화된 경우 높이 제약조건 설정
            dropdownHeightConstraint = dropdownContentView.heightAnchor.constraint(equalToConstant: 0)
            dropdownHeightConstraint?.isActive = true
            
            constraints.append(contentsOf: [
                dropdownContentView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
                dropdownArrow.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
                dropdownArrow.trailingAnchor.constraint(equalTo: mainContentView.trailingAnchor, constant: -16),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: dropdownArrow.leadingAnchor, constant: -8)
            ])
        } else {
            // 드롭다운이 없는 경우 기본 제약조건
            constraints.append(contentsOf: [
                titleLabel.trailingAnchor.constraint(equalTo: mainContentView.trailingAnchor, constant: -16),
                mainContentView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
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
            
            // 높이 제약조건 저장 (뷰에 연결)
            if let constraint = dropdownHeightConstraint {
                containerView.addConstraint(constraint)
            }
        }
        
        // 🔧 카드가 필요 이상으로 늘어나지 않도록 설정 (더 강한 우선순위)
        containerView.setContentHuggingPriority(.init(999), for: .vertical)  // 매우 높은 우선순위
        containerView.setContentCompressionResistancePriority(.init(1000), for: .vertical)  // 최고 우선순위
        
        // 🔧 mainContentView는 절대 압축되지 않도록 설정
        mainContentView.setContentHuggingPriority(.init(999), for: .vertical)  // 매우 높은 우선순위
        mainContentView.setContentCompressionResistancePriority(.init(1000), for: .vertical)  // 최고 우선순위
        
        // 🔧 제목과 내용 라벨도 압축 방지
        titleLabel.setContentCompressionResistancePriority(.init(1000), for: .vertical)
        contentLabel.setContentCompressionResistancePriority(.init(1000), for: .vertical)
        
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
        
        guard let dropdownContentView = containerView.viewWithTag(888),
              let dropdownArrow = containerView.viewWithTag(999) as? UILabel,
              let dropdownLabel = containerView.viewWithTag(777) as? UILabel else {
            print("❌ 드롭다운 UI 요소를 찾을 수 없습니다")
            return
        }
        
        // 높이 제약조건 찾기 (firstAnchor가 dropdownContentView인 height constraint)
        let dropdownHeightConstraint = containerView.constraints.first { constraint in
            constraint.firstAnchor == dropdownContentView.heightAnchor
        }
        
        let isExpanded = !dropdownContentView.isHidden
        
        // 드롭다운 컨텐츠 설정
        if !isExpanded {
            dropdownLabel.text = self.getDropdownContent(for: dropdownType)
        }
        
        // 🎨 부드러운 애니메이션을 위한 스크롤 비활성화
        let scrollView = self.insightStackView.superview as? UIScrollView
        scrollView?.isScrollEnabled = false
        
        // 제약조건 전환 및 애니메이션
        if isExpanded {
            // 축소: 드롭다운 컨텐츠 숨기기
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: [.curveEaseInOut, .allowUserInteraction], animations: {
                dropdownHeightConstraint?.constant = 0
                dropdownArrow.text = "▼"
                
                // 스크롤뷰의 contentOffset 고정
                let currentOffset = scrollView?.contentOffset ?? .zero
                
                // 레이아웃 업데이트
                self.view.layoutIfNeeded()
                
                // contentOffset 복원 (스크롤 위치 유지)
                scrollView?.contentOffset = currentOffset
                
            }) { _ in
                dropdownContentView.isHidden = true
                
                // 🔧 즉시 스크롤뷰 업데이트 - 비동기 제거
                self.updateInsightScrollViewContentSize()
                scrollView?.isScrollEnabled = true
            }
        } else {
            // 확장: 드롭다운 컨텐츠 표시
            dropdownContentView.isHidden = false
            
            // 먼저 적절한 높이 계산
            let tempLabel = UILabel()
            tempLabel.text = dropdownLabel.text
            tempLabel.font = dropdownLabel.font
            tempLabel.numberOfLines = 0
            let maxSize = CGSize(width: max(300, dropdownContentView.frame.width - 24), height: CGFloat.greatestFiniteMagnitude)
            let neededHeight = tempLabel.sizeThatFits(maxSize).height + 24 // 패딩 추가
            
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: [.curveEaseInOut, .allowUserInteraction], animations: {
                dropdownHeightConstraint?.constant = neededHeight
                dropdownArrow.text = "▲"
                
                // 스크롤뷰의 contentOffset 고정
                let currentOffset = scrollView?.contentOffset ?? .zero
                
                // 레이아웃 업데이트
                self.view.layoutIfNeeded()
                
                // contentOffset 복원 (스크롤 위치 유지)
                scrollView?.contentOffset = currentOffset
                
            }) { _ in
                // 🔧 즉시 스크롤뷰 업데이트 - 비동기 제거
                self.updateInsightScrollViewContentSize()
                scrollView?.isScrollEnabled = true
                
                // 🎯 드롭다운이 화면에서 벗어나면 자동 스크롤
                if let scrollView = scrollView {
                    let containerFrame = containerView.convert(containerView.bounds, to: scrollView)
                    let dropdownBottom = containerFrame.maxY
                    let scrollViewVisibleHeight = scrollView.frame.height
                    let currentOffset = scrollView.contentOffset.y
                    
                    if dropdownBottom > currentOffset + scrollViewVisibleHeight {
                        let targetOffset = dropdownBottom - scrollViewVisibleHeight + 30
                        let maxOffset = max(0, scrollView.contentSize.height - scrollViewVisibleHeight)
                        let finalOffset = min(targetOffset, maxOffset)
                        
                        print("🔍 [자동스크롤] dropdownBottom: \(dropdownBottom), finalOffset: \(finalOffset)")
                        
                        scrollView.setContentOffset(CGPoint(x: 0, y: finalOffset), animated: true)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    internal func updateInsightScrollViewContentSize() {
        guard self.currentView == 2 else { return }
        
        // Let Auto Layout drive the scrollView contentSize via contentLayoutGuide/bottom constraints
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
    }
    
    // 🔧 NEW: 실제 프레임 기반 높이 계산 메서드
    private func calculateRealContentHeight() -> CGFloat {
        var totalHeight: CGFloat = 40 // 상하 여백 20씩
        
        // 각 카드의 실제 높이 계산
        for (index, arrangedSubview) in insightStackView.arrangedSubviews.enumerated() {
            var cardHeight: CGFloat = 80 // 기본 카드 높이
            
            // 드롭다운이 펼쳐진 경우 추가 높이 계산
            if let dropdownView = arrangedSubview.viewWithTag(888), !dropdownView.isHidden {
                // 드롭다운 높이 제약조건에서 실제 값 가져오기
                let dropdownConstraints = arrangedSubview.constraints.filter { 
                    $0.firstAnchor == dropdownView.heightAnchor 
                }
                
                if let heightConstraint = dropdownConstraints.first {
                    let dropdownHeight = heightConstraint.constant
                    cardHeight += dropdownHeight + 16 // 드롭다운 높이 + 여백
                    print("🔍 [높이 계산] 카드 \(index) 드롭다운 높이: \(dropdownHeight)")
                } else {
                    // 제약조건을 찾을 수 없는 경우 실제 프레임 높이 사용
                    let dropdownHeight = dropdownView.frame.height
                    cardHeight += dropdownHeight + 16
                    print("🔍 [높이 계산] 카드 \(index) 프레임 높이: \(dropdownHeight)")
                }
            }
            
            totalHeight += cardHeight + 16 // 카드 높이 + 스택 간격
            print("🔍 [높이 계산] 카드 \(index) 총 높이: \(cardHeight)")
        }
        
        // AI 분석 버튼 높이 추가 (대략 100pt)
        totalHeight += 100
        
        // 최소 스크롤뷰 높이 보장하되, 무제한 확장 허용
        let minHeight = (insightStackView.superview as? UIScrollView)?.bounds.height ?? 600
        let finalHeight = max(totalHeight, minHeight)
        
        print("🔍 [높이 계산] 총 높이: \(totalHeight), 최종: \(finalHeight)")
        return finalHeight
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
