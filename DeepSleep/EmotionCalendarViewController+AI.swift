import UIKit

// MARK: - EmotionCalendarViewController AI Extension
extension EmotionCalendarViewController {
    
    // MARK: - AI Analysis Implementation
    func showAIAnalysisAlert() {
        let alert = UIAlertController(
            title: "🔒 개인정보 보호 안내",
            message: """
            AI와 대화하기 위해 다음 정보가 전송됩니다:
            
            • 최근 30일간의 감정 패턴
            • 감정 통계 (개인 식별 불가)
            • 일기 내용은 포함되지 않습니다
            
            개인 식별이 가능한 정보는 전송되지 않으며, 
            대화 종료 후 데이터는 즉시 삭제됩니다.
            
            계속하시겠습니까?
            """,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "AI와 대화하기", style: .default) { [weak self] _ in
            self?.startAIAnalysisChat()
        })
        
        present(alert, animated: true)
    }
    
    func startAIAnalysisChat() {
        let anonymizedData = generateAnonymizedEmotionData()
        
        let chatVC = ChatViewController()
        chatVC.title = "🤖 감정 패턴 분석 대화"
        
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
}
