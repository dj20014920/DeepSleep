//
//  EmotionCalendarViewController.swift
//  DeepSleep
//
//  Created by dj on 2024/06/18.
//

import UIKit
import FSCalendar
import CoreData
import Combine

class EmotionCalendarViewController: UIViewController {
    
    enum SectionType {
        case insight(String)
        case todo([TodoItem])
        
        var title: String {
            switch self {
            case .insight:
                return "AI Insight"
            case .todo:
                return "To-Do List"
            }
        }
        
        var isTodoSection: Bool {
            if case .todo = self { return true }
            return false
        }
        
        var isInsightSection: Bool {
            if case .insight = self { return true }
            return false
        }
    }
    
    // MARK: - Properties
    
    var calendar: FSCalendar!
    private var collectionView: UICollectionView!
    private var headerLabel: UILabel!
    
    var selectedDate: Date = Date()
    private var sections: [SectionType] = []
    
    private let todoManager = TodoManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    var diaryEntries: [EmotionDiary] = []
    var diaryDataForCalendar: [String: EmotionDiary] = [:]
    
    // MARK: - CoreData
    var container: NSPersistentContainer!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        self.container = appDelegate.persistentContainer
        
        // UI setup needs to be restored later
        view.backgroundColor = .systemBackground
        title = "Emotion Calendar"
        
        // TODO: setupCalendar() and other UI setup calls should be placed here
        // For now, we focus on merging and fixing logic.
        loadDiaryData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Data loading needs to be restored later
        calendar.reloadData()
    }
    
    private func loadDiaryData() {
        diaryEntries = SettingsManager.shared.loadEmotionDiary()
        diaryDataForCalendar.removeAll()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        for entry in diaryEntries {
            let dateString = formatter.string(from: entry.date)
            diaryDataForCalendar[dateString] = entry
        }
        if calendar != nil {
            calendar.reloadData()
        }
    }
    
    // MARK: - UICollectionViewDataSource
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch sections[section] {
        case .insight:
            return 1
        case .todo(let items):
            return items.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch sections[indexPath.section] {
        case .insight(let text):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: InsightCell.reuseIdentifier, for: indexPath) as! InsightCell
            cell.configure(with: text)
            return cell
        case .todo(let items):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TodoListCell.reuseIdentifier, for: indexPath) as! TodoListCell
            cell.configure(with: items)
            cell.delegate = self
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SectionHeaderView", for: indexPath) as! SectionHeaderView
        let section = sections[indexPath.section]
        header.titleLabel.text = section.title
        header.addButton.isHidden = !section.isTodoSection // 투두 섹션일 때만 버튼 보이기
        header.addButton.tag = indexPath.section
        header.addButton.addTarget(self, action: #selector(addButtonTapped(_:)), for: .touchUpInside)
        return header
    }
    
    // MARK: - Actions
    
    @objc private func addButtonTapped(_ sender: UIButton) {
    }
}

// MARK: - FSCalendarDelegate, FSCalendarDataSource

extension EmotionCalendarViewController: FSCalendarDelegate, FSCalendarDataSource {
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        selectedDate = date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        if let entry = diaryDataForCalendar[dateString] {
            showDiaryDetail(for: entry.date, emotion: entry.selectedEmotion)
        }
        // TODO: reload insight/todo data for the selected date
        // loadData(for: date)
    }
    
    func calendar(_ calendar: FSCalendar, numberOfEventsFor date: Date) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        return diaryDataForCalendar[dateString] != nil ? 1 : 0
    }
}

// MARK: - TodoListCellDelegate
extension EmotionCalendarViewController: TodoListCellDelegate {
    func todoListCellDidSelectTodoItem(_ item: TodoItem) {
    }
    
    func todoListCellDidToggleComplete(for item: TodoItem, isCompleted: Bool) {
        var updatedItem = item
        updatedItem.isCompleted = isCompleted
        todoManager.updateTodoItem(updatedItem)
    }
}

// MARK: - 📝 AI Functions for Calendar
extension EmotionCalendarViewController {
    
    private func requestAIInsightForDate(date: Date) {
        // TODO: Implement AI insight logic for the selected date.
        // This could involve fetching sleep data, diary entries, etc.
        // and sending it to an AI service for analysis.
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        let dateString = dateFormatter.string(from: date)
        
        let _ = """
        Analyze the user's data for \(dateString).
        - Sleep data: ...
        - Diary entries: ...
        - Completed todos: ...
        Provide a brief insight into their well-being and suggest one positive action.
        """
        
        // Example:
        // Task {
        //     let insight = await aIGenerateInsight(prompt: prompt)
        //     updateInsightSection(with: insight)
        // }
    }
    
    private func updateInsightSection(with text: String) {
        if let index = sections.firstIndex(where: { $0.isInsightSection }) {
            sections[index] = .insight(text)
            collectionView.reloadSections(IndexSet(integer: index))
        } else {
            sections.insert(.insight(text), at: 0)
            collectionView.insertSections(IndexSet(integer: 0))
        }
    }
}

// MARK: - AddEditTodoDelegate
// extension EmotionCalendarViewController: AddEditTodoDelegate {
//    func didSaveTodoItem(_ todoItem: TodoItem) {
//        if let existingIndex = todoManager.getTodoItems(for: selectedDate).firstIndex(where: { $0.id == todoItem.id }) {
//            // Update existing
//            todoManager.updateTodoItem(todoItem)
//        } else {
//            // Add new
//            todoManager.addTodoItem(todoItem)
//        }
//        loadData(for: selectedDate) // Reload data to show changes
//    }
// }

// =====================================================================
// MARK: - Merged content from EmotionCalendarViewController+AI.swift
// =====================================================================

// MARK: - EmotionCalendarViewController AI Extension
extension EmotionCalendarViewController {
    
    // MARK: - AI Analysis Implementation
    func showAIAnalysisAlert() {
        let remainingCount = AIUsageManager.shared.getRemainingCount(for: .patternAnalysis)
        let totalLimit = 3 // AIUsageManager에서 설정된 patternAnalysis 일일 제한
            
        guard remainingCount > 0 else {
            let limitAlert = UIAlertController(
                title: "📊 일일 감정 패턴 분석 완료",
                message: """
                오늘 감정 패턴 분석을 모두 사용하셨습니다.
                
                깊이 있는 감정 패턴 분석을 위해 하루 \(totalLimit)회로 제한하고 있어요.
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
            📊 오늘 남은 분석 횟수: \(remainingCount)/\(totalLimit)회
            
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
        // ✅ 사용 횟수 기록 (실제 분석 시작 시점에)
        AIUsageManager.shared.recordUsage(for: .patternAnalysis)
        
        let chatVC = ChatViewController()
        // ✅ 타이틀 제거 - ChatViewController에서 통일된 타이틀 설정
        
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
        
        // ✅ swipe back 제스처 활성화
        navController.interactivePopGestureRecognizer?.isEnabled = true
        navController.interactivePopGestureRecognizer?.delegate = nil
        
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

// =====================================================================
// MARK: - Merged content from EmotionCalendarViewcontroller+Diary.swift
// =====================================================================

// MARK: - EmotionCalendarViewController Diary Extension
extension EmotionCalendarViewController {
    
    // MARK: - ✅ 일기 상세보기 - 남은 횟수 표시 추가
    func showDiaryDetail(for date: Date, emotion: String) {
        let calendar = Calendar.current
        let targetEntries = diaryEntries.filter {
            calendar.isDate($0.date, inSameDayAs: date)
        }
        
        guard let entry = targetEntries.first else { return }
        
        let dateString = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
        
        let alert = UIAlertController(
            title: "\(emotion) \(dateString)",
            message: entry.userMessage,
            preferredStyle: .alert
        )
        
        // AI 응답 보기 버튼
        alert.addAction(UIAlertAction(title: "AI 응답 보기", style: .default) { _ in
            let responseAlert = UIAlertController(
                title: "AI 응답",
                message: entry.aiResponse,
                preferredStyle: .alert
            )
            responseAlert.addAction(UIAlertAction(title: "확인", style: .default))
            self.present(responseAlert, animated: true)
        })
        
        // ✅ 일기 분석 대화 버튼 - 남은 횟수 표시
        let remainingCount = AIUsageManager.shared.getRemainingCount(for: .diaryAnalysis)
        let diaryAnalysisTitle = remainingCount > 0 ?
            "💬 이 일기를 AI와 깊이 분석 (남은 횟수: \(remainingCount))" :
            "💬 일기 분석 대화 (오늘 사용 완료)"
        
        alert.addAction(UIAlertAction(title: diaryAnalysisTitle, style: .default) { _ in
            self.startDiaryConversation(with: entry)
        })
        
        // 일기 전체 내용 보기 버튼 (긴 일기인 경우)
        if entry.userMessage.count > 100 {
            alert.addAction(UIAlertAction(title: "📖 전체 내용 보기", style: .default) { _ in
                self.showFullDiaryContent(entry: entry)
            })
        }
        
        alert.addAction(UIAlertAction(title: "닫기", style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - ✅ 일기 대화 시작 - 하루 1회 제한 추가 & 안전한 데이터 전달
    func startDiaryConversation(with entry: EmotionDiary) {
        // ✅ 하루 1회 제한 체크
        let remainingCount = AIUsageManager.shared.getRemainingCount(for: .diaryAnalysis)
        
        guard remainingCount > 0 else {
            let limitAlert = UIAlertController(
                title: "📝 일일 일기 분석 완료",
                message: """
                오늘 일기 분석 대화를 이미 사용하셨습니다.
                
                깊이 있는 일기 분석을 위해 하루 1회로 제한하고 있어요.
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
        
        // 🛡️ 안전한 데이터 검증 및 준비
        guard !entry.userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let errorAlert = UIAlertController(
                title: "오류",
                message: "일기 내용이 비어있어 AI와 대화할 수 없습니다.",
                preferredStyle: .alert
            )
            errorAlert.addAction(UIAlertAction(title: "확인", style: .default))
            present(errorAlert, animated: true)
            return
        }
        
        // 🛡️ 필수 데이터 확인
        let verifiedEmotion = entry.selectedEmotion.isEmpty ? "😐" : entry.selectedEmotion
        let verifiedMessage = entry.userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let verifiedAIResponse = entry.aiResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🔍 [일기 대화 시작] 데이터 검증:")
        print("  - 감정: \(verifiedEmotion)")
        print("  - 일기 길이: \(verifiedMessage.count)자")
        print("  - AI 응답 길이: \(verifiedAIResponse.count)자")
        print("  - 날짜: \(entry.date)")
        
        // ✅ 사용 횟수 증가 (실제 대화 시작 직전에)
        AIUsageManager.shared.recordUsage(for: .diaryAnalysis)
        
        // 🛡️ ChatViewController 생성 및 안전한 데이터 설정
        let chatVC = ChatRouter.chatViewController()
        
        // 🛡️ 확실한 일기 컨텍스트 생성
        let safeEntry = EmotionDiary(
            selectedEmotion: verifiedEmotion,
            userMessage: verifiedMessage,
            aiResponse: verifiedAIResponse,
            date: entry.date
        )
        
        // 🛡️ 여러 방법으로 데이터 전달 (안전성 보장)
        let diaryContext = DiaryContext(from: safeEntry)
        chatVC.diaryContext = diaryContext
        
        // 🛡️ 초기 사용자 텍스트 설정
        chatVC.initialUserText = "일기_분석_모드_확인"
        
        // 🛡️ 타이틀 통일
        // chatVC.title = "#Todays_Mood"
        
        // 🛡️ 프리셋 적용 콜백 설정
        chatVC.onPresetApply = { [weak self] preset in
            self?.applyPresetFromCalendar(preset)
        }
        
        // 🛡️ 네비게이션 설정 및 표시
        let navController = UINavigationController(rootViewController: chatVC)
        navController.navigationBar.prefersLargeTitles = false
        navController.navigationBar.tintColor = .systemBlue
        navController.modalPresentationStyle = .fullScreen
        navController.modalTransitionStyle = .coverVertical
        
        present(navController, animated: true) {
            // 🛡️ 표시 완료 후 데이터 전달 재확인
            print("✅ [일기 대화] ChatViewController 표시 완료")
            print("  - diaryContext 설정됨: \(chatVC.diaryContext != nil)")
            print("  - initialUserText: \(chatVC.initialUserText ?? "없음")")
        }
    }
    private func applyPresetFromCalendar(_ preset: SoundPreset) {
        NotificationCenter.default.post(
            name: NSNotification.Name("ApplyPresetFromChat"),
            object: nil,
            userInfo: [
                "volumes": preset.volumes,
                "presetName": preset.name,
                "versions": preset.compatibleVersions
            ]
        )
    }
    func showFullDiaryContent(entry: EmotionDiary) {
        let detailVC = UIViewController()
        detailVC.title = "일기 상세"
        detailVC.view.backgroundColor = .systemBackground
        
        let scrollView = UIScrollView()
        let textView = UITextView()
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        textView.text = """
        날짜: \(DateFormatter.localizedString(from: entry.date, dateStyle: .full, timeStyle: .short))
        감정: \(entry.selectedEmotion)
        
        일기 내용:
        \(entry.userMessage)
        
        AI 응답:
        \(entry.aiResponse)
        """
        
        textView.font = .systemFont(ofSize: 16)
        textView.isEditable = false
        textView.backgroundColor = .systemBackground
        
        detailVC.view.addSubview(scrollView)
        scrollView.addSubview(textView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: detailVC.view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: detailVC.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: detailVC.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: detailVC.view.safeAreaLayoutGuide.bottomAnchor),
            
            textView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            textView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
        
        let closeButton = UIBarButtonItem(title: "닫기", style: .plain, target: self, action: #selector(closeDiaryDetail))
        
        // ✅ AI 대화 버튼도 제한 체크
        let remainingCount = AIUsageManager.shared.getRemainingCount(for: .diaryAnalysis)
        let chatButtonTitle = remainingCount > 0 ? "💬 AI 분석" : "💬 분석 완료"
        let chatButton = UIBarButtonItem(title: chatButtonTitle, style: .plain, target: self, action: #selector(startChatFromDetail))
        
        detailVC.navigationItem.leftBarButtonItem = closeButton
        detailVC.navigationItem.rightBarButtonItem = chatButton
        
        objc_setAssociatedObject(detailVC, "diaryEntry", entry, .OBJC_ASSOCIATION_RETAIN)
        
        let navController = UINavigationController(rootViewController: detailVC)
        present(navController, animated: true)
    }
    
    @objc func closeDiaryDetail() {
        dismiss(animated: true)
    }
    
    @objc func startChatFromDetail() {
        guard let presentedNav = presentedViewController as? UINavigationController,
              let detailVC = presentedNav.topViewController,
              let entry = objc_getAssociatedObject(detailVC, "diaryEntry") as? EmotionDiary else { return }
        
        presentedNav.dismiss(animated: true) { [weak self] in
            self?.startDiaryConversation(with: entry)
        }
    }
}
