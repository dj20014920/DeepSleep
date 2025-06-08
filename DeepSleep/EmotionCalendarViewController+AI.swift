import UIKit

// MARK: - EmotionCalendarViewController AI Extension
extension EmotionCalendarViewController {
    
    // MARK: - AI Analysis Implementation
    func showAIAnalysisAlert() {
        let remainingCount = AIUsageManager.shared.getRemainingCount(for: .patternAnalysis)
            
        guard remainingCount > 0 else {
            let limitAlert = UIAlertController(
                title: "📊 일일 감정 패턴 분석 완료",
                message: """
                오늘 감정 패턴 분석을 이미 사용하셨습니다.
                
                깊이 있는 감정 패턴 분석을 위해 하루 1회로 제한하고 있어요.
                대신 충분한 시간 동안 AI와 깊이 있게 대화할 수 있습니다.
                
                내일 다시 이용해보세요! 😊
                
                💡 일반 채팅으로 감정 상담을 받아보시는 건 어떨까요?
                """,
                preferredStyle: .alert
            )
            
            limitAlert.addAction(UIAlertAction(title: "확인", style: .default))
            present(limitAlert, animated: true)
            return
        }
        
        let alert = UIAlertController(
            title: "🔒 개인정보 보호 안내",
            message: """
            AI 감정 패턴 분석 대화를 시작합니다:
            📊 오늘 남은 분석 횟수: \(remainingCount)/1회
            
            • 최근 30일간의 감정 패턴 분석
            • 감정 통계 및 트렌드 파악
            • 개인 맞춤 감정 관리 조언
            • 충분한 시간 동안 깊이 있는 대화 가능
            • 일기 내용은 포함되지 않습니다
            
            개인 식별이 가능한 정보는 전송되지 않으며, 
            대화 종료 후 데이터는 즉시 삭제됩니다.
            
            계속하시겠습니까?
            """,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "AI 패턴 분석 시작", style: .default) { [weak self] _ in
            self?.startAIAnalysisChat()
        })
        
        present(alert, animated: true)
    }
    
    func startAIAnalysisChat() {
        let anonymizedData = generateAnonymizedEmotionData()
        SettingsManager.shared.incrementPatternAnalysisUsage()
        let chatVC = ChatViewController()
        chatVC.title = "감정 패턴 분석 대화"
        
        chatVC.emotionPatternData = anonymizedData
        chatVC.initialUserText = "감정_패턴_분석_모드"
        
        // ✅ 네비게이션 컨트롤러 설정 개선
        let navController = UINavigationController(rootViewController: chatVC)
        
        // 네비게이션 바 스타일 설정
        navController.navigationBar.prefersLargeTitles = false
        navController.navigationBar.tintColor = .systemBlue
        navController.navigationBar.backgroundColor = .systemBackground
        
        // 모달 표시 스타일 설정
        navController.modalPresentationStyle = .fullScreen
        navController.modalTransitionStyle = .coverVertical
        
        // ✅ 네비게이션 바가 확실히 보이도록 설정
        navController.setNavigationBarHidden(false, animated: false)
        
        present(navController, animated: true) {
            // 표시 완료 후 추가 설정
            navController.setNavigationBarHidden(false, animated: false)
        }
    }
    
    func generateAnonymizedEmotionData() -> String {
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!
        
        let recentEntries = diaryEntries.filter { $0.date >= thirtyDaysAgo }
        
        guard !recentEntries.isEmpty else {
            return "최근 30일간 감정 기록이 없습니다."
        }
        
        let emotionCounts = Dictionary(grouping: recentEntries, by: { $0.selectedEmotion })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        var analysisText = "최근 30일 감정 패턴 분석:\n"
        analysisText += "총 \(recentEntries.count)개의 감정 기록\n\n"
        
        for (emotion, count) in emotionCounts {
            let percentage = Int((Float(count) / Float(recentEntries.count)) * 100)
            analysisText += "• \(emotion): \(count)회 (\(percentage)%)\n"
        }
        
        let weeklyPattern = analyzeWeeklyPattern(entries: recentEntries)
        if !weeklyPattern.isEmpty {
            analysisText += "\n주간 패턴:\n\(weeklyPattern)"
        }
        
        // ✅ 추가 분석 정보 제공
        let timePattern = analyzeTimePattern(entries: recentEntries)
        if !timePattern.isEmpty {
            analysisText += "\n시간대별 패턴:\n\(timePattern)"
        }
        
        let emotionTrend = analyzeEmotionTrend(entries: recentEntries)
        if !emotionTrend.isEmpty {
            analysisText += "\n감정 변화 트렌드:\n\(emotionTrend)"
        }
        
        return analysisText
    }
    
    func analyzeWeeklyPattern(entries: [EmotionDiary]) -> String {
        let calendar = Calendar.current
        let weekdayNames = ["일", "월", "화", "수", "목", "금", "토"]
        
        let weekdayGroups = Dictionary(grouping: entries) { entry in
            calendar.component(.weekday, from: entry.date) - 1
        }
        
        var pattern = ""
        for weekday in 0..<7 {
            if let dayEntries = weekdayGroups[weekday], !dayEntries.isEmpty {
                let mostCommonEmotion = Dictionary(grouping: dayEntries, by: { $0.selectedEmotion })
                    .max(by: { $0.value.count < $1.value.count })?.key ?? ""
                pattern += "• \(weekdayNames[weekday])요일: \(mostCommonEmotion) (\(dayEntries.count)회)\n"
            }
        }
        
        return pattern
    }
    
    // ✅ 새로운 분석 메소드들 추가
    func analyzeTimePattern(entries: [EmotionDiary]) -> String {
        let calendar = Calendar.current
        let hourGroups = Dictionary(grouping: entries) { entry in
            calendar.component(.hour, from: entry.date)
        }
        
        var pattern = ""
        let timeRanges = [
            (0...5, "새벽"),
            (6...11, "오전"),
            (12...17, "오후"),
            (18...23, "저녁")
        ]
        
        for (range, label) in timeRanges {
            let rangeEntries = hourGroups.filter { range.contains($0.key) }.values.flatMap { $0 }
            if !rangeEntries.isEmpty {
                let mostCommonEmotion = Dictionary(grouping: rangeEntries, by: { $0.selectedEmotion })
                    .max(by: { $0.value.count < $1.value.count })?.key ?? ""
                pattern += "• \(label): \(mostCommonEmotion) (\(rangeEntries.count)회)\n"
            }
        }
        
        return pattern
    }
    
    func analyzeEmotionTrend(entries: [EmotionDiary]) -> String {
        guard entries.count >= 7 else { return "" }
        
        let sortedEntries = entries.sorted { $0.date < $1.date }
        let midPoint = sortedEntries.count / 2
        
        let firstHalf = Array(sortedEntries.prefix(midPoint))
        let secondHalf = Array(sortedEntries.suffix(midPoint))
        
        let positiveEmotions = ["😊", "😄", "🥰", "🙂"]
        
        let firstPositiveCount = firstHalf.filter { positiveEmotions.contains($0.selectedEmotion) }.count
        let secondPositiveCount = secondHalf.filter { positiveEmotions.contains($0.selectedEmotion) }.count
        
        let firstPositiveRatio = Double(firstPositiveCount) / Double(firstHalf.count)
        let secondPositiveRatio = Double(secondPositiveCount) / Double(secondHalf.count)
        
        let trend: String
        let difference = secondPositiveRatio - firstPositiveRatio
        
        switch difference {
        case 0.1...:
            trend = "긍정적으로 개선되고 있습니다 ↗️"
        case ..<(-0.1):
            trend = "다소 하락하는 경향이 있습니다 ↘️"
        default:
            trend = "안정적인 상태를 유지하고 있습니다 ➡️"
        }
        
        return "• 전체적인 감정 상태: \(trend)\n• 전반기 긍정 감정 비율: \(String(format: "%.1f", firstPositiveRatio * 100))%\n• 후반기 긍정 감정 비율: \(String(format: "%.1f", secondPositiveRatio * 100))%"
    }
}
