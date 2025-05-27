import UIKit

class EmotionCalendarViewController: UIViewController {
    
    // MARK: - UI Components
    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let monthLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let prevButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("◀", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let nextButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("▶", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let weekdayStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let calendarCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 1
        layout.minimumLineSpacing = 1
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private let monthlyStatsView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let monthlyStatsLabel: UILabel = {
        let label = UILabel()
        label.text = "이번 달 감정 분석"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let statsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let aiAnalysisButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("🤖 AI와 감정 분석 대화하기", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Properties
    private var emotionData: [String: String] = [:]
    private var diaryEntries: [EmotionDiary] = []
    private var currentDate = Date()
    private var calendarDates: [Date?] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadEmotionData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadEmotionData()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "감정 캘린더"
        
        setupHeader()
        setupWeekdays()
        setupCalendarCollection()
        setupMonthlyStats()
        setupConstraints()
        updateCalendarDisplay()
    }
    
    private func setupHeader() {
        view.addSubview(headerView)
        headerView.addSubview(monthLabel)
        headerView.addSubview(prevButton)
        headerView.addSubview(nextButton)
        
        prevButton.addTarget(self, action: #selector(prevMonthTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextMonthTapped), for: .touchUpInside)
    }
    
    private func setupWeekdays() {
        view.addSubview(weekdayStackView)
        
        let weekdays = ["일", "월", "화", "수", "목", "금", "토"]
        for (index, weekday) in weekdays.enumerated() {
            let label = UILabel()
            label.text = weekday
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 14, weight: .medium)
            label.textColor = index == 0 ? .systemRed : (index == 6 ? .systemBlue : .label)
            weekdayStackView.addArrangedSubview(label)
        }
    }
    
    private func setupCalendarCollection() {
        view.addSubview(calendarCollectionView)
        
        calendarCollectionView.delegate = self
        calendarCollectionView.dataSource = self
        calendarCollectionView.register(CalendarDayCell.self, forCellWithReuseIdentifier: CalendarDayCell.identifier)
    }
    
    private func setupMonthlyStats() {
        view.addSubview(monthlyStatsView)
        view.addSubview(aiAnalysisButton)
        
        monthlyStatsView.addSubview(monthlyStatsLabel)
        monthlyStatsView.addSubview(statsStackView)
        
        aiAnalysisButton.addTarget(self, action: #selector(showAIAnalysisAlert), for: .touchUpInside)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 헤더
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            headerView.heightAnchor.constraint(equalToConstant: 50),
            
            prevButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            prevButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            prevButton.widthAnchor.constraint(equalToConstant: 30),
            
            monthLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            monthLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            nextButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            nextButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 30),
            
            // 요일
            weekdayStackView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16),
            weekdayStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            weekdayStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            weekdayStackView.heightAnchor.constraint(equalToConstant: 30),
            
            // 캘린더
            calendarCollectionView.topAnchor.constraint(equalTo: weekdayStackView.bottomAnchor, constant: 8),
            calendarCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            calendarCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            calendarCollectionView.heightAnchor.constraint(equalToConstant: 240),
            
            // 월간 통계
            monthlyStatsView.topAnchor.constraint(equalTo: calendarCollectionView.bottomAnchor, constant: 20),
            monthlyStatsView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            monthlyStatsView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            monthlyStatsView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            
            monthlyStatsLabel.topAnchor.constraint(equalTo: monthlyStatsView.topAnchor, constant: 16),
            monthlyStatsLabel.leadingAnchor.constraint(equalTo: monthlyStatsView.leadingAnchor, constant: 16),
            monthlyStatsLabel.trailingAnchor.constraint(equalTo: monthlyStatsView.trailingAnchor, constant: -16),
            
            statsStackView.topAnchor.constraint(equalTo: monthlyStatsLabel.bottomAnchor, constant: 12),
            statsStackView.leadingAnchor.constraint(equalTo: monthlyStatsView.leadingAnchor, constant: 16),
            statsStackView.trailingAnchor.constraint(equalTo: monthlyStatsView.trailingAnchor, constant: -16),
            statsStackView.bottomAnchor.constraint(equalTo: monthlyStatsView.bottomAnchor, constant: -16),
            
            // AI 분석 버튼
            aiAnalysisButton.topAnchor.constraint(equalTo: monthlyStatsView.bottomAnchor, constant: 20),
            aiAnalysisButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            aiAnalysisButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            aiAnalysisButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - Data Loading
    private func loadEmotionData() {
        diaryEntries = SettingsManager.shared.loadEmotionDiary()
        emotionData.removeAll()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for entry in diaryEntries {
            let dateKey = dateFormatter.string(from: entry.date)
            emotionData[dateKey] = entry.selectedEmotion
        }
        
        calendarCollectionView.reloadData()
        updateMonthlyStats()
    }
    
    // MARK: - Calendar Logic
    private func updateCalendarDisplay() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월"
        monthLabel.text = formatter.string(from: currentDate)
        
        generateCalendarDates()
        calendarCollectionView.reloadData()
    }
    
    private func generateCalendarDates() {
        calendarDates.removeAll()
        
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: currentDate)!.start
        let endOfMonth = calendar.dateInterval(of: .month, for: currentDate)!.end
        
        let firstWeekday = calendar.component(.weekday, from: startOfMonth) - 1
        let daysInMonth = calendar.component(.day, from: calendar.date(byAdding: .day, value: -1, to: endOfMonth)!)
        
        // 빈 날짜들 추가
        for _ in 0..<firstWeekday {
            calendarDates.append(nil)
        }
        
        // 실제 날짜들 추가
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                calendarDates.append(date)
            }
        }
        
        // 6주 완성을 위한 빈 날짜들
        while calendarDates.count < 42 {
            calendarDates.append(nil)
        }
    }
    
    @objc private func prevMonthTapped() {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .month, value: -1, to: currentDate) {
            currentDate = newDate
            updateCalendarDisplay()
        }
    }
    
    @objc private func nextMonthTapped() {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .month, value: 1, to: currentDate) {
            currentDate = newDate
            updateCalendarDisplay()
        }
    }
    
    // MARK: - Monthly Statistics
    private func updateMonthlyStats() {
        statsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        
        let currentMonthEntries = diaryEntries.filter { entry in
            let entryMonth = calendar.component(.month, from: entry.date)
            let entryYear = calendar.component(.year, from: entry.date)
            return entryMonth == currentMonth && entryYear == currentYear
        }
        
        guard !currentMonthEntries.isEmpty else {
            let emptyLabel = UILabel()
            emptyLabel.text = "이번 달 감정 기록이 없습니다"
            emptyLabel.textColor = .systemGray
            emptyLabel.textAlignment = .center
            statsStackView.addArrangedSubview(emptyLabel)
            return
        }
        
        let emotionCounts = Dictionary(grouping: currentMonthEntries, by: { $0.selectedEmotion })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        for (index, (emotion, count)) in emotionCounts.prefix(3).enumerated() {
            let statView = createStatRow(
                rank: index + 1,
                emotion: emotion,
                count: count,
                total: currentMonthEntries.count
            )
            statsStackView.addArrangedSubview(statView)
        }
        
        let totalLabel = UILabel()
        totalLabel.text = "총 \(currentMonthEntries.count)개의 감정 기록"
        totalLabel.font = .systemFont(ofSize: 14, weight: .medium)
        totalLabel.textColor = .systemGray
        totalLabel.textAlignment = .center
        statsStackView.addArrangedSubview(totalLabel)
    }
    
    private func createStatRow(rank: Int, emotion: String, count: Int, total: Int) -> UIView {
        let containerView = UIView()
        
        let rankLabel = UILabel()
        rankLabel.text = "\(rank)."
        rankLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        rankLabel.textColor = .systemGray
        rankLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let emotionLabel = UILabel()
        emotionLabel.text = emotion
        emotionLabel.font = .systemFont(ofSize: 20)
        
        let countLabel = UILabel()
        countLabel.text = "\(count)회"
        countLabel.font = .systemFont(ofSize: 14, weight: .medium)
        countLabel.textColor = .label
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let percentageLabel = UILabel()
        let percentage = Int((Float(count) / Float(total)) * 100)
        percentageLabel.text = "\(percentage)%"
        percentageLabel.font = .systemFont(ofSize: 14, weight: .medium)
        percentageLabel.textColor = .systemBlue
        percentageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        [rankLabel, emotionLabel, countLabel, percentageLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalToConstant: 30),
            
            rankLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            rankLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            rankLabel.widthAnchor.constraint(equalToConstant: 20),
            
            emotionLabel.leadingAnchor.constraint(equalTo: rankLabel.trailingAnchor, constant: 8),
            emotionLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            countLabel.leadingAnchor.constraint(equalTo: emotionLabel.trailingAnchor, constant: 12),
            countLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            percentageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            percentageLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
        
        return containerView
    }
    
    // MARK: - ✅ 완전히 수정된 AI Analysis 부분
    @objc private func showAIAnalysisAlert() {
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
    
    // ✅ 완전히 수정된 startAIAnalysisChat
    private func startAIAnalysisChat() {
        let anonymizedData = generateAnonymizedEmotionData()
        
        let chatVC = ChatViewController()
        chatVC.title = "감정 패턴 분석 대화"
        
        // ✅ 감정 패턴 데이터를 ChatViewController에 전달
        chatVC.emotionPatternData = anonymizedData
        chatVC.initialUserText = "감정_패턴_분석_모드"
        
        // ✅ 네비게이션 방식 개선
        let navController = UINavigationController(rootViewController: chatVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    // ✅ 개선된 generateAnonymizedEmotionData
    private func generateAnonymizedEmotionData() -> String {
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
        
        // 주간 패턴 분석 추가
        let weeklyPattern = analyzeWeeklyPattern(entries: recentEntries)
        if !weeklyPattern.isEmpty {
            analysisText += "\n주간 패턴:\n\(weeklyPattern)"
        }
        
        return analysisText
    }
    
    // ✅ 주간 패턴 분석 메소드
    private func analyzeWeeklyPattern(entries: [EmotionDiary]) -> String {
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

// MARK: - UICollectionView DataSource & Delegate
extension EmotionCalendarViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return calendarDates.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CalendarDayCell.identifier, for: indexPath) as! CalendarDayCell
        
        let date = calendarDates[indexPath.item]
        cell.configure(with: date, emotionData: emotionData)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.frame.width - 6) / 7
        return CGSize(width: width, height: 40)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let date = calendarDates[indexPath.item] else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateFormatter.string(from: date)
        
        if let emotion = emotionData[dateKey] {
            showDiaryDetail(for: date, emotion: emotion)
        }
    }
    
    // MARK: - ✅ 완전히 수정된 showDiaryDetail (일기 재열람 기능)
    private func showDiaryDetail(for date: Date, emotion: String) {
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
        
        // ✅ AI 응답 보기 버튼
        alert.addAction(UIAlertAction(title: "🤖 AI 응답 보기", style: .default) { _ in
            let responseAlert = UIAlertController(
                title: "AI 응답",
                message: entry.aiResponse,
                preferredStyle: .alert
            )
            responseAlert.addAction(UIAlertAction(title: "확인", style: .default))
            self.present(responseAlert, animated: true)
        })
        
        // ✅ 새로운 AI 대화 시작 버튼
        alert.addAction(UIAlertAction(title: "💬 이 일기로 AI와 새 대화", style: .default) { _ in
            self.startDiaryConversation(with: entry)
        })
        
        // ✅ 일기 전체 내용 보기 버튼 (긴 일기인 경우)
        if entry.userMessage.count > 100 {
            alert.addAction(UIAlertAction(title: "📖 전체 내용 보기", style: .default) { _ in
                self.showFullDiaryContent(entry: entry)
            })
        }
        
        alert.addAction(UIAlertAction(title: "닫기", style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - ✅ 특정 일기로 AI 대화 시작
    private func startDiaryConversation(with entry: EmotionDiary) {
        let chatVC = ChatViewController()
        chatVC.title = "일기 대화 - \(DateFormatter.localizedString(from: entry.date, dateStyle: .short, timeStyle: .none))"
        
        // DiaryContext 생성
        chatVC.diaryContext = DiaryContext(
            emotion: entry.selectedEmotion,
            content: entry.userMessage,
            date: entry.date
        )
        
        chatVC.initialUserText = "일기_분석_모드"
        
        let navController = UINavigationController(rootViewController: chatVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    // MARK: - ✅ 일기 전체 내용 보기
    private func showFullDiaryContent(entry: EmotionDiary) {
        let detailVC = UIViewController()
        detailVC.title = "일기 상세"
        detailVC.view.backgroundColor = .systemBackground
        
        // 스크롤 가능한 텍스트 뷰로 전체 내용 표시
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
        
        // AI와 대화하기 버튼 추가
        let closeButton = UIBarButtonItem(title: "닫기", style: .plain, target: self, action: #selector(closeDiaryDetail))
        let chatButton = UIBarButtonItem(title: "💬 AI 대화", style: .plain, target: self, action: #selector(startChatFromDetail))
        
        detailVC.navigationItem.leftBarButtonItem = closeButton
        detailVC.navigationItem.rightBarButtonItem = chatButton
        
        // 임시로 entry 저장
        objc_setAssociatedObject(detailVC, "diaryEntry", entry, .OBJC_ASSOCIATION_RETAIN)
        
        let navController = UINavigationController(rootViewController: detailVC)
        present(navController, animated: true)
    }
    
    @objc private func closeDiaryDetail() {
        dismiss(animated: true)
    }
    
    @objc private func startChatFromDetail() {
        // 현재 presented된 뷰 컨트롤러에서 entry 가져오기
        guard let presentedNav = presentedViewController as? UINavigationController,
              let detailVC = presentedNav.topViewController,
              let entry = objc_getAssociatedObject(detailVC, "diaryEntry") as? EmotionDiary else { return }
        
        presentedNav.dismiss(animated: true) { [weak self] in
            self?.startDiaryConversation(with: entry)
        }
    }
}

// MARK: - CalendarDayCell
class CalendarDayCell: UICollectionViewCell {
    static let identifier = "CalendarDayCell"
    
    private let dayLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let emotionLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(dayLabel)
        contentView.addSubview(emotionLabel)
        
        NSLayoutConstraint.activate([
            dayLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            dayLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            dayLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            dayLabel.heightAnchor.constraint(equalToConstant: 20),
            
            emotionLabel.topAnchor.constraint(equalTo: dayLabel.bottomAnchor),
            emotionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            emotionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            emotionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2)
        ])
        
        layer.cornerRadius = 8
    }
    
    func configure(with date: Date?, emotionData: [String: String]) {
        guard let date = date else {
            dayLabel.text = ""
            emotionLabel.text = ""
            backgroundColor = .clear
            return
        }
        
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        dayLabel.text = "\(day)"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateFormatter.string(from: date)
        
        if let emotion = emotionData[dateKey] {
            emotionLabel.text = emotion
            backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        } else {
            emotionLabel.text = ""
            backgroundColor = .clear
        }
        
        // 오늘 날짜 표시
        if calendar.isDateInToday(date) {
            layer.borderWidth = 2
            layer.borderColor = UIColor.systemBlue.cgColor
        } else {
            layer.borderWidth = 0
        }
        
        // 주말 색상
        let weekday = calendar.component(.weekday, from: date)
        if weekday == 1 {
            dayLabel.textColor = .systemRed
        } else if weekday == 7 {
            dayLabel.textColor = .systemBlue
        } else {
            dayLabel.textColor = .label
        }
    }
}
