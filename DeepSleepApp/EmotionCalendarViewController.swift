import UIKit
import FSCalendar
import EventKit

class EmotionCalendarViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
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
    
    // MARK: - FSCalendar Integration
    private let calendar: FSCalendar = {
        let calendar = FSCalendar()
        calendar.translatesAutoresizingMaskIntoConstraints = false
        calendar.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        calendar.appearance.headerTitleColor = UIDesignSystem.Colors.primaryText
        calendar.appearance.weekdayTextColor = UIDesignSystem.Colors.secondaryText
        calendar.appearance.titleDefaultColor = UIDesignSystem.Colors.primaryText
        calendar.appearance.selectionColor = UIDesignSystem.Colors.primary
        calendar.appearance.todayColor = UIDesignSystem.Colors.warning
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.firstWeekday = 1 // 일요일부터 시작
        return calendar
    }()
    
    // MARK: - Content Display Section
    private let contentSectionView: UIView = {
        let view = UIView()
        view.backgroundColor = UIDesignSystem.Colors.adaptiveSecondaryBackground
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["감정일기", "할일", "AI조언"])
        control.selectedSegmentIndex = 0
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        tableView.layer.cornerRadius = 8
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        return tableView
    }()
    
    // MARK: - Todo Management UI
    private let addTodoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("+ 할일 추가", for: .normal)
        button.backgroundColor = UIDesignSystem.Colors.primary
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Calendar Integration Features
    private let calendarSyncButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("📱 아이폰 캘린더 연동", for: .normal)
        button.backgroundColor = UIDesignSystem.Colors.info
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
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
        label.text = "이번 달 통계"
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
        button.setTitle("AI와 감정 분석 대화하기", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Properties
    internal var emotionData: [String: String] = [:]
    internal var diaryEntries: [EmotionDiary] = []
    private var currentDate = Date()
    internal var calendarDates: [Date?] = []
    private var selectedDate = Date()
    
    // Todo Management Properties
    private var selectedDateTodos: [TodoItem] = []
    private var selectedDateDiary: EmotionDiary?
    private var selectedDateAdvices: [String] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        setupActions()
        loadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
        refreshSelectedDateContent()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        title = "감정 & 일정"
        
        setupScrollView()
        setupHeader()
        setupCalendar()
        setupContentSection()
        setupMonthlyStats()
        setupConstraints()
        updateCalendarDisplay()
    }
    
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.bounces = true
        scrollView.alwaysBounceVertical = true
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }
    
    private func setupHeader() {
        contentView.addSubview(headerView)
        headerView.addSubview(monthLabel)
        headerView.addSubview(prevButton)
        headerView.addSubview(nextButton)
        
        headerView.backgroundColor = UIDesignSystem.Colors.adaptiveSecondaryBackground
        monthLabel.textColor = UIDesignSystem.Colors.primaryText
        prevButton.setTitleColor(UIDesignSystem.Colors.primary, for: .normal)
        nextButton.setTitleColor(UIDesignSystem.Colors.primary, for: .normal)
    }
    
    private func setupCalendar() {
        contentView.addSubview(calendar)
        calendar.delegate = self
        calendar.dataSource = self
        
        // 다크모드 호환
        calendar.appearance.headerTitleColor = UIDesignSystem.Colors.primaryText
        calendar.appearance.weekdayTextColor = UIDesignSystem.Colors.secondaryText
        calendar.appearance.titleDefaultColor = UIDesignSystem.Colors.primaryText
    }
    
    private func setupContentSection() {
        contentView.addSubview(contentSectionView)
        contentSectionView.addSubview(segmentedControl)
        contentSectionView.addSubview(tableView)
        contentSectionView.addSubview(addTodoButton)
        contentSectionView.addSubview(calendarSyncButton)
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        
        // 셀 등록
        tableView.register(EmotionDiaryDisplayCell.self, forCellReuseIdentifier: EmotionDiaryDisplayCell.identifier)
        tableView.register(TodoTableViewCell.self, forCellReuseIdentifier: TodoTableViewCell.identifier)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "AdviceCell")
        
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = UIDesignSystem.Colors.separator
    }
    
    private func setupActions() {
        prevButton.addTarget(self, action: #selector(prevMonthTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextMonthTapped), for: .touchUpInside)
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        addTodoButton.addTarget(self, action: #selector(addTodoTapped), for: .touchUpInside)
        calendarSyncButton.addTarget(self, action: #selector(calendarSyncTapped), for: .touchUpInside)
        aiAnalysisButton.addTarget(self, action: #selector(aiAnalysisTapped), for: .touchUpInside)
    }
    
    private func setupMonthlyStats() {
        contentView.addSubview(monthlyStatsView)
        monthlyStatsView.addSubview(monthlyStatsLabel)
        monthlyStatsView.addSubview(statsStackView)
        contentView.addSubview(aiAnalysisButton)
        
        monthlyStatsView.backgroundColor = UIDesignSystem.Colors.adaptiveSecondaryBackground
        monthlyStatsLabel.textColor = UIDesignSystem.Colors.primaryText
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Header
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            headerView.heightAnchor.constraint(equalToConstant: 60),
            
            prevButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            prevButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            prevButton.widthAnchor.constraint(equalToConstant: 40),
            
            nextButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            nextButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 40),
            
            monthLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            monthLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            monthLabel.leadingAnchor.constraint(greaterThanOrEqualTo: prevButton.trailingAnchor, constant: 8),
            monthLabel.trailingAnchor.constraint(lessThanOrEqualTo: nextButton.leadingAnchor, constant: -8),
            
            // Calendar
            calendar.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16),
            calendar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            calendar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            calendar.heightAnchor.constraint(equalToConstant: 300),
            
            // Content Section
            contentSectionView.topAnchor.constraint(equalTo: calendar.bottomAnchor, constant: 16),
            contentSectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contentSectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            contentSectionView.heightAnchor.constraint(equalToConstant: 400),
            
            segmentedControl.topAnchor.constraint(equalTo: contentSectionView.topAnchor, constant: 16),
            segmentedControl.leadingAnchor.constraint(equalTo: contentSectionView.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: contentSectionView.trailingAnchor, constant: -16),
            segmentedControl.heightAnchor.constraint(equalToConstant: 32),
            
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: contentSectionView.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: contentSectionView.trailingAnchor, constant: -16),
            tableView.bottomAnchor.constraint(equalTo: addTodoButton.topAnchor, constant: -16),
            
            addTodoButton.leadingAnchor.constraint(equalTo: contentSectionView.leadingAnchor, constant: 16),
            addTodoButton.trailingAnchor.constraint(equalTo: contentSectionView.trailingAnchor, constant: -16),
            addTodoButton.bottomAnchor.constraint(equalTo: calendarSyncButton.topAnchor, constant: -8),
            addTodoButton.heightAnchor.constraint(equalToConstant: 44),
            
            calendarSyncButton.leadingAnchor.constraint(equalTo: contentSectionView.leadingAnchor, constant: 16),
            calendarSyncButton.trailingAnchor.constraint(equalTo: contentSectionView.trailingAnchor, constant: -16),
            calendarSyncButton.bottomAnchor.constraint(equalTo: contentSectionView.bottomAnchor, constant: -16),
            calendarSyncButton.heightAnchor.constraint(equalToConstant: 36),
            
            // Monthly Stats
            monthlyStatsView.topAnchor.constraint(equalTo: contentSectionView.bottomAnchor, constant: 16),
            monthlyStatsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            monthlyStatsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            monthlyStatsView.heightAnchor.constraint(greaterThanOrEqualToConstant: 150),
            
            monthlyStatsLabel.topAnchor.constraint(equalTo: monthlyStatsView.topAnchor, constant: 16),
            monthlyStatsLabel.leadingAnchor.constraint(equalTo: monthlyStatsView.leadingAnchor, constant: 16),
            monthlyStatsLabel.trailingAnchor.constraint(equalTo: monthlyStatsView.trailingAnchor, constant: -16),
            
            statsStackView.topAnchor.constraint(equalTo: monthlyStatsLabel.bottomAnchor, constant: 12),
            statsStackView.leadingAnchor.constraint(equalTo: monthlyStatsView.leadingAnchor, constant: 16),
            statsStackView.trailingAnchor.constraint(equalTo: monthlyStatsView.trailingAnchor, constant: -16),
            statsStackView.bottomAnchor.constraint(equalTo: monthlyStatsView.bottomAnchor, constant: -16),
            
            // AI Analysis Button
            aiAnalysisButton.topAnchor.constraint(equalTo: monthlyStatsView.bottomAnchor, constant: 16),
            aiAnalysisButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            aiAnalysisButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            aiAnalysisButton.heightAnchor.constraint(equalToConstant: 44),
            aiAnalysisButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Data Loading
    private func loadData() {
        loadEmotionData()
        refreshSelectedDateContent()
        updateMonthlyStats()
    }
    
    private func refreshSelectedDateContent() {
        // 선택된 날짜의 감정 일기 로드
        selectedDateDiary = diaryEntries.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
        
        // 선택된 날짜의 할일 로드
        selectedDateTodos = TodoManager.shared.getTodos(for: selectedDate)
        
        // 선택된 날짜의 AI 조언 로드 (할일에서 추출)
        selectedDateAdvices = selectedDateTodos.compactMap { $0.aiAdvices }.flatMap { $0 }
        
        // 테이블뷰 새로고침
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.updateButtonVisibility()
        }
    }
    
    private func updateButtonVisibility() {
        let currentSegment = segmentedControl.selectedSegmentIndex
        addTodoButton.isHidden = currentSegment != 1 // 할일 탭에서만 표시
        calendarSyncButton.isHidden = currentSegment != 1 // 할일 탭에서만 표시
    }
    
    // MARK: - Action Methods
         @objc internal func prevMonthTapped() {
         calendar.setCurrentPage(Calendar.current.date(byAdding: .month, value: -1, to: calendar.currentPage) ?? calendar.currentPage, animated: true)
         updateCalendarDisplay()
     }
     
     @objc internal func nextMonthTapped() {
         calendar.setCurrentPage(Calendar.current.date(byAdding: .month, value: 1, to: calendar.currentPage) ?? calendar.currentPage, animated: true)
         updateCalendarDisplay()
     }
    
    @objc private func segmentChanged() {
        refreshSelectedDateContent()
        updateButtonVisibility()
    }
    
    @objc private func addTodoTapped() {
        let addEditVC = AddEditTodoViewController()
        addEditVC.delegate = self
        
        // 선택된 날짜로 dueDatePicker 설정
        addEditVC.loadViewIfNeeded()
        addEditVC.dueDatePicker.date = selectedDate
        
        let navController = UINavigationController(rootViewController: addEditVC)
        present(navController, animated: true)
    }
    
    @objc private func calendarSyncTapped() {
        TodoManager.shared.requestCalendarAccessIfNeeded { [weak self] granted, error in
            DispatchQueue.main.async {
                if granted {
                    self?.showCalendarSyncOptions()
                } else {
                    self?.showCalendarAccessDeniedAlert()
                }
            }
        }
    }
    
    @objc private func aiAnalysisTapped() {
        let emotionAnalysisVC = EmotionAnalysisChatViewController()
        let navController = UINavigationController(rootViewController: emotionAnalysisVC)
        present(navController, animated: true)
    }
    
         // MARK: - Helper Methods
     internal func updateCalendarDisplay() {
         let formatter = DateFormatter()
         formatter.locale = Locale(identifier: "ko_KR")
         formatter.dateFormat = "yyyy년 M월"
         monthLabel.text = formatter.string(from: calendar.currentPage)
         
         currentDate = calendar.currentPage
         updateMonthlyStats()
     }
    
         internal func updateMonthlyStats() {
         statsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
         
         let currentMonth = Calendar.current.component(.month, from: currentDate)
         let currentYear = Calendar.current.component(.year, from: currentDate)
         
         // 이번 달 감정 통계
         let monthlyEmotions = diaryEntries.filter {
             let entryMonth = Calendar.current.component(.month, from: $0.date)
             let entryYear = Calendar.current.component(.year, from: $0.date)
             return entryMonth == currentMonth && entryYear == currentYear
         }
         
         // 이번 달 할일 통계
         let monthlyTodos = TodoManager.shared.loadTodos().filter {
             let todoMonth = Calendar.current.component(.month, from: $0.dueDate)
             let todoYear = Calendar.current.component(.year, from: $0.dueDate)
             return todoMonth == currentMonth && todoYear == currentYear
         }
         
         let emotionStats = createStatLabel("감정 기록: \(monthlyEmotions.count)개")
         let todoStats = createStatLabel("할일: \(monthlyTodos.count)개 (완료: \(monthlyTodos.filter { $0.isCompleted }.count)개)")
         let highPriorityTodos = monthlyTodos.filter { $0.priority >= 2 }.count
         let priorityStats = createStatLabel("중요한 일정: \(highPriorityTodos)개")
         
         statsStackView.addArrangedSubview(emotionStats)
         statsStackView.addArrangedSubview(todoStats)
         statsStackView.addArrangedSubview(priorityStats)
         
         if !monthlyEmotions.isEmpty {
             let mostFrequentEmotion = getMostFrequentEmotion(from: monthlyEmotions)
             let emotionTrend = createStatLabel("주요 감정: \(mostFrequentEmotion)")
             statsStackView.addArrangedSubview(emotionTrend)
         }
     }
    
    private func createStatLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIDesignSystem.Colors.secondaryText
        label.numberOfLines = 0
        return label
    }
    
    private func getMostFrequentEmotion(from entries: [EmotionDiary]) -> String {
        let emotionCounts = Dictionary(grouping: entries, by: { $0.selectedEmotion })
            .mapValues { $0.count }
        
        guard let mostFrequent = emotionCounts.max(by: { $0.value < $1.value }) else {
            return "😊"
        }
        
        return mostFrequent.key
    }
    
    private func showCalendarSyncOptions() {
        let alert = UIAlertController(title: "캘린더 연동", message: "아이폰 캘린더와 연동하시겠습니까?", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "기존 할일을 캘린더로 이동", style: .default) { _ in
            self.migrateExistingTodos()
        })
        
        alert.addAction(UIAlertAction(title: "캘린더 연동 설정", style: .default) { _ in
            self.openCalendarSettings()
        })
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showCalendarAccessDeniedAlert() {
        let alert = UIAlertController(title: "캘린더 접근 권한 필요", message: "설정에서 캘린더 접근 권한을 허용해주세요.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "설정으로 이동", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        present(alert, animated: true)
    }
    
    private func migrateExistingTodos() {
        TodoManager.shared.migrateExistingTodosToCalendar { migratedCount, errors in
            DispatchQueue.main.async {
                let message = errors.isEmpty 
                    ? "성공적으로 \(migratedCount)개의 할일을 캘린더로 이동했습니다."
                    : "일부 오류가 발생했습니다. \(migratedCount)개 성공, \(errors.count)개 실패"
                
                let alert = UIAlertController(title: "마이그레이션 완료", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "확인", style: .default))
                self.present(alert, animated: true)
                
                self.refreshSelectedDateContent()
            }
        }
    }
    
    private func openCalendarSettings() {
        if let settingsURL = URL(string: "calshow://") {
            UIApplication.shared.open(settingsURL) { success in
                if !success {
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "알림", message: "캘린더 앱을 직접 열어주세요.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "확인", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
}

// MARK: - Data Loading
extension EmotionCalendarViewController {
    private func loadEmotionData() {
        diaryEntries = SettingsManager.shared.loadEmotionDiary()
        emotionData.removeAll()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for entry in diaryEntries {
            let dateKey = dateFormatter.string(from: entry.date)
            emotionData[dateKey] = entry.selectedEmotion
        }
        
        calendar.reloadData()
        updateMonthlyStats()
        
    }
}

// MARK: - Calendar Logic
extension EmotionCalendarViewController {
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
    
    private func createStatRow(rank: Int, emotion: String, count: Int, total: Int) -> UIView {
        let containerView = UIView()
        
        let rankLabel = UILabel()
        rankLabel.text = "\(rank)."
        rankLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        rankLabel.textColor = UIDesignSystem.Colors.secondaryText
        rankLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let emotionLabel = UILabel()
        emotionLabel.text = emotion
        emotionLabel.font = .systemFont(ofSize: 20)
        emotionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let countLabel = UILabel()
        countLabel.text = "\(count)회"
        countLabel.font = .systemFont(ofSize: 14, weight: .medium)
        countLabel.textColor = UIDesignSystem.Colors.primaryText
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let percentageLabel = UILabel()
        let percentage = Int((Float(count) / Float(total)) * 100)
        percentageLabel.text = "\(percentage)%"
        percentageLabel.font = .systemFont(ofSize: 14, weight: .medium)
        percentageLabel.textColor = UIDesignSystem.Colors.primary
        percentageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        [rankLabel, emotionLabel, countLabel, percentageLabel].forEach {
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
}

// MARK: - FSCalendar Delegate & DataSource
extension EmotionCalendarViewController: FSCalendarDelegate, FSCalendarDataSource {
    
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        selectedDate = date
        refreshSelectedDateContent()
        print("📅 선택된 날짜: \(date)")
    }
    
    func calendar(_ calendar: FSCalendar, numberOfEventsFor date: Date) -> Int {
        // 감정 일기와 할일 개수 표시
        let emotionCount = diaryEntries.contains { Calendar.current.isDate($0.date, inSameDayAs: date) } ? 1 : 0
        let todoCount = TodoManager.shared.getTodos(for: date).count
        return emotionCount + todoCount
    }
    
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, eventDefaultColorsFor date: Date) -> [UIColor]? {
        var colors: [UIColor] = []
        
        // 감정 일기가 있으면 감정에 따른 색상
        if let emotion = emotionData[dateKey(from: date)] {
            switch emotion {
            case "😊": colors.append(.systemYellow)
            case "😢": colors.append(.systemBlue)
            case "😡": colors.append(.systemRed)
            case "😴": colors.append(.systemPurple)
            case "😰": colors.append(.systemOrange)
            default: colors.append(.systemGreen)
            }
        }
        
        // 할일이 있으면 회색 점 추가
        if !TodoManager.shared.getTodos(for: date).isEmpty {
            colors.append(.systemGray)
        }
        
        return colors.isEmpty ? nil : colors
    }
    
    func calendar(_ calendar: FSCalendar, titleFor date: Date) -> String? {
        let day = Calendar.current.component(.day, from: date)
        return "\(day)"
    }
    
    private func dateKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - TableView Delegate & DataSource
extension EmotionCalendarViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch segmentedControl.selectedSegmentIndex {
        case 0: // 감정일기
            return selectedDateDiary != nil ? 1 : 0
        case 1: // 할일
            return selectedDateTodos.count
        case 2: // AI조언
            return selectedDateAdvices.count
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch segmentedControl.selectedSegmentIndex {
        case 0: // 감정일기
            guard let cell = tableView.dequeueReusableCell(withIdentifier: EmotionDiaryDisplayCell.identifier, for: indexPath) as? EmotionDiaryDisplayCell,
                  let diary = selectedDateDiary else {
                return UITableViewCell()
            }
            cell.configure(with: diary)
            return cell
            
        case 1: // 할일
            guard let cell = tableView.dequeueReusableCell(withIdentifier: TodoTableViewCell.identifier, for: indexPath) as? TodoTableViewCell else {
                return UITableViewCell()
            }
            let todo = selectedDateTodos[indexPath.row]
            cell.configure(with: todo)
            return cell
            
        case 2: // AI조언
            let cell = tableView.dequeueReusableCell(withIdentifier: "AdviceCell", for: indexPath)
            cell.textLabel?.text = selectedDateAdvices[indexPath.row]
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.font = .systemFont(ofSize: 14)
            cell.backgroundColor = UIDesignSystem.Colors.adaptiveSecondaryBackground
            return cell
            
        default:
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch segmentedControl.selectedSegmentIndex {
        case 0: // 감정일기
            if let diary = selectedDateDiary {
                showDiaryDetail(diary)
            }
        case 1: // 할일
            let todo = selectedDateTodos[indexPath.row]
            editTodo(todo)
        case 2: // AI조언
            // AI 조언 상세보기 (선택적)
            showAdviceDetail(selectedDateAdvices[indexPath.row])
        default:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return segmentedControl.selectedSegmentIndex == 1 // 할일만 편집 가능
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete && segmentedControl.selectedSegmentIndex == 1 {
            deleteTodo(at: indexPath.row)
        }
    }
    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard segmentedControl.selectedSegmentIndex == 1 else { return nil }
        
        let todo = selectedDateTodos[indexPath.row]
        let completeAction = UIContextualAction(style: .normal, title: todo.isCompleted ? "미완료" : "완료") { [weak self] _, _, completion in
            self?.toggleTodoCompletion(at: indexPath.row)
            completion(true)
        }
        completeAction.backgroundColor = todo.isCompleted ? .systemOrange : .systemGreen
        
        return UISwipeActionsConfiguration(actions: [completeAction])
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard segmentedControl.selectedSegmentIndex == 1 else { return nil }
        
        let todo = selectedDateTodos[indexPath.row]
        
        let adviceAction = UIContextualAction(style: .normal, title: "AI조언") { [weak self] _, _, completion in
            self?.requestTodoAdvice(for: todo)
            completion(true)
        }
        adviceAction.backgroundColor = .systemBlue
        
        let deleteAction = UIContextualAction(style: .destructive, title: "삭제") { [weak self] _, _, completion in
            self?.deleteTodo(at: indexPath.row)
            completion(true)
        }
        
        return UISwipeActionsConfiguration(actions: [deleteAction, adviceAction])
    }
    
    // MARK: - Todo Management Methods
    private func editTodo(_ todo: TodoItem) {
        let addEditVC = AddEditTodoViewController()
        addEditVC.todoToEdit = todo
        addEditVC.delegate = self
        let navController = UINavigationController(rootViewController: addEditVC)
        present(navController, animated: true)
    }
    
    private func deleteTodo(at index: Int) {
        let todo = selectedDateTodos[index]
        TodoManager.shared.deleteTodo(withId: todo.id) { [weak self] success, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showErrorAlert("할일 삭제 실패", message: error.localizedDescription)
                } else if success {
                    self?.refreshSelectedDateContent()
                    self?.updateMonthlyStats()
                    self?.calendar.reloadData()
                }
            }
        }
    }
    
    private func toggleTodoCompletion(at index: Int) {
        let todo = selectedDateTodos[index]
        TodoManager.shared.toggleCompletion(for: todo.id) { [weak self] _, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showErrorAlert("상태 변경 실패", message: error.localizedDescription)
                } else {
                    self?.refreshSelectedDateContent()
                }
            }
        }
    }
    
    private func requestTodoAdvice(for todo: TodoItem) {
        // AI 조언 요청 로직 (기존 TodoCalendarViewController에서 가져옴)
        let prompt = """
        다음 할일에 대한 조언을 해주세요:
        제목: \(todo.title)
        마감일: \(todo.dueDateString)
        우선순위: \(todo.priority == 2 ? "높음" : todo.priority == 1 ? "보통" : "낮음")
        메모: \(todo.notes ?? "없음")
        
        이 할일을 효과적으로 완수하기 위한 구체적인 조언을 해주세요.
        """
        
        // ChatManager를 통한 AI 조언 요청
        // ChatManager.shared.appendChat(role: "user", content: prompt)
        
        // 임시로 간단한 AI 조언 생성
        let randomAdvices = [
            "이 할일을 작은 단위로 나누어 진행해보세요.",
            "우선순위를 고려하여 중요한 부분부터 시작하세요.",
            "시간을 정해두고 집중적으로 작업해보세요.",
            "필요한 리소스나 도구를 미리 준비하세요.",
            "완료 후 보상을 설정하여 동기를 부여하세요."
        ]
        let advice = randomAdvices.randomElement() ?? "계획적으로 진행하시면 좋을 것 같습니다."
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showAdviceResult(for: todo, advice: advice)
        }
    }
    
    private func showAdviceResult(for todo: TodoItem, advice: String) {
        let alert = UIAlertController(title: "AI 조언", message: advice, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    private func showDiaryDetail(_ diary: EmotionDiary) {
        let alert = UIAlertController(title: "감정 일기", message: diary.userMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "수정", style: .default) { _ in
            self.editDiary(diary)
        })
        alert.addAction(UIAlertAction(title: "닫기", style: .cancel))
        present(alert, animated: true)
    }
    
    private func editDiary(_ diary: EmotionDiary) {
        let editVC = EditDiaryViewController()
        editVC.diaryToEdit = diary
        let navController = UINavigationController(rootViewController: editVC)
        present(navController, animated: true)
    }
    
    private func showAdviceDetail(_ advice: String) {
        let alert = UIAlertController(title: "AI 조언 상세", message: advice, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    private func showErrorAlert(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - AddEditTodoDelegate
extension EmotionCalendarViewController: AddEditTodoDelegate {
    func didSaveTodo() {
        refreshSelectedDateContent()
        updateMonthlyStats()
        calendar.reloadData()
    }
    
    func didDeleteTodo() {
        refreshSelectedDateContent()
        updateMonthlyStats()
        calendar.reloadData()
    }
}

