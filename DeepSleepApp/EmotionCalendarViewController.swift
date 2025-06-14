import UIKit

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
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
    }
   
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
        collectionView.isScrollEnabled = false
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
        button.setTitle("AI와 감정 분석 대화하기", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Properties - Extension에서 접근 가능하도록 internal
    internal var emotionData: [String: String] = [:]
    internal var diaryEntries: [EmotionDiary] = []
    private var currentDate = Date()
    internal var calendarDates: [Date?] = []
    
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
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        title = "감정 캘린더"
        
        setupScrollView()
        setupHeader()
        setupWeekdays()
        setupCalendarCollection()
        setupMonthlyStats()
        setupConstraints()
        updateCalendarDisplay()
    }
    
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // 스크롤뷰 설정
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.bounces = true
        scrollView.alwaysBounceVertical = true
        
        NSLayoutConstraint.activate([
            // 스크롤뷰를 전체 화면에 맞춤
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // contentView 제약조건 - 핵심 수정!
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            
            // contentView의 너비를 scrollView의 frameLayoutGuide에 맞춤
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }
    
    private func setupHeader() {
        contentView.addSubview(headerView)
        headerView.addSubview(monthLabel)
        headerView.addSubview(prevButton)
        headerView.addSubview(nextButton)
        
        // 다크모드 호환 색상 적용
        headerView.backgroundColor = UIDesignSystem.Colors.adaptiveSecondaryBackground
        monthLabel.textColor = UIDesignSystem.Colors.primaryText
        prevButton.setTitleColor(UIDesignSystem.Colors.primary, for: .normal)
        nextButton.setTitleColor(UIDesignSystem.Colors.primary, for: .normal)
        
        prevButton.addTarget(self, action: #selector(prevMonthTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextMonthTapped), for: .touchUpInside)
    }
    
    private func setupWeekdays() {
        contentView.addSubview(weekdayStackView)
        
        let weekdays = ["일", "월", "화", "수", "목", "금", "토"]
        for (index, weekday) in weekdays.enumerated() {
            let label = UILabel()
            label.text = weekday
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 14, weight: .medium)
            // 다크모드 호환 색상 적용
            if index == 0 {
                label.textColor = UIDesignSystem.Colors.error // 일요일
            } else if index == 6 {
                label.textColor = UIDesignSystem.Colors.primary // 토요일
            } else {
                label.textColor = UIDesignSystem.Colors.primaryText
            }
            weekdayStackView.addArrangedSubview(label)
        }
    }
    
    private func setupCalendarCollection() {
        contentView.addSubview(calendarCollectionView)
        
        // 다크모드 호환 배경색 적용
        calendarCollectionView.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        
        calendarCollectionView.delegate = self
        calendarCollectionView.dataSource = self
        calendarCollectionView.register(CalendarDayCell.self, forCellWithReuseIdentifier: CalendarDayCell.identifier)
    }
    
    private func setupMonthlyStats() {
        contentView.addSubview(monthlyStatsView)
        contentView.addSubview(aiAnalysisButton)
        
        monthlyStatsView.addSubview(monthlyStatsLabel)
        monthlyStatsView.addSubview(statsStackView)
        
        // 다크모드 호환 색상 적용
        monthlyStatsView.backgroundColor = UIDesignSystem.Colors.adaptiveSecondaryBackground
        monthlyStatsLabel.textColor = UIDesignSystem.Colors.primaryText
        
        aiAnalysisButton.addTarget(self, action: #selector(aiAnalysisButtonTapped), for: .touchUpInside)
    }
    @objc private func aiAnalysisButtonTapped() {
        showAIAnalysisAlert()
    }
    
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 헤더
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
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
            weekdayStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            weekdayStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            weekdayStackView.heightAnchor.constraint(equalToConstant: 30),
            
            // 캘린더 - 높이 고정
            calendarCollectionView.topAnchor.constraint(equalTo: weekdayStackView.bottomAnchor, constant: 8),
            calendarCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            calendarCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            calendarCollectionView.heightAnchor.constraint(equalToConstant: 280),
            
            // 월간 통계 - 최소 높이 설정
            monthlyStatsView.topAnchor.constraint(equalTo: calendarCollectionView.bottomAnchor, constant: 20),
            monthlyStatsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            monthlyStatsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            monthlyStatsView.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),
            
            monthlyStatsLabel.topAnchor.constraint(equalTo: monthlyStatsView.topAnchor, constant: 16),
            monthlyStatsLabel.leadingAnchor.constraint(equalTo: monthlyStatsView.leadingAnchor, constant: 16),
            monthlyStatsLabel.trailingAnchor.constraint(equalTo: monthlyStatsView.trailingAnchor, constant: -16),
            
            statsStackView.topAnchor.constraint(equalTo: monthlyStatsLabel.bottomAnchor, constant: 12),
            statsStackView.leadingAnchor.constraint(equalTo: monthlyStatsView.leadingAnchor, constant: 16),
            statsStackView.trailingAnchor.constraint(equalTo: monthlyStatsView.trailingAnchor, constant: -16),
            statsStackView.bottomAnchor.constraint(lessThanOrEqualTo: monthlyStatsView.bottomAnchor, constant: -16),
            
            // AI 분석 버튼 - 마지막 요소로 스크롤 범위 결정
            aiAnalysisButton.topAnchor.constraint(equalTo: monthlyStatsView.bottomAnchor, constant: 20),
            aiAnalysisButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            aiAnalysisButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            aiAnalysisButton.heightAnchor.constraint(equalToConstant: 60),
            
            // ✅ 핵심: AI 버튼이 contentView의 bottom을 결정하도록 설정
            aiAnalysisButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -50)
        ])
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
        
        calendarCollectionView.reloadData()
        updateMonthlyStats()
        
    }
}

// MARK: - Calendar Logic
extension EmotionCalendarViewController {
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
            updateMonthlyStats()
        }
    }
    
    @objc private func nextMonthTapped() {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .month, value: 1, to: currentDate) {
            currentDate = newDate
            updateCalendarDisplay()
            updateMonthlyStats()
        }
    }
}

// MARK: - Monthly Statistics
extension EmotionCalendarViewController {
    private func updateMonthlyStats() {
        statsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: currentDate)
        let currentYear = calendar.component(.year, from: currentDate)
        
        let currentMonthEntries = diaryEntries.filter { entry in
            let entryMonth = calendar.component(.month, from: entry.date)
            let entryYear = calendar.component(.year, from: entry.date)
            return entryMonth == currentMonth && entryYear == currentYear
        }
        
        guard !currentMonthEntries.isEmpty else {
            let emptyLabel = UILabel()
            emptyLabel.text = "이 달 감정 기록이 없습니다"
            emptyLabel.textColor = UIDesignSystem.Colors.secondaryText
            emptyLabel.textAlignment = .center
            statsStackView.addArrangedSubview(emptyLabel)
            
            // 레이아웃 업데이트
            DispatchQueue.main.async {
                self.view.layoutIfNeeded()
            }
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
        totalLabel.textColor = UIDesignSystem.Colors.secondaryText
        totalLabel.textAlignment = .center
        statsStackView.addArrangedSubview(totalLabel)
        
        // ✅ 통계 업데이트 후 레이아웃 강제 업데이트
        DispatchQueue.main.async {
            self.view.layoutIfNeeded()
            self.scrollView.contentSize = CGSize(
                width: self.scrollView.frame.width,
                height: max(self.contentView.frame.height, self.scrollView.frame.height + 200)
            )
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

