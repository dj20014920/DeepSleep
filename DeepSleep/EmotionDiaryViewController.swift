import UIKit
import Charts // Charts 라이브러리 필요 (나중에 추가)

class EmotionDiaryViewController: UIViewController {
    
    // MARK: - UI Components
    private let segmentedControl: UISegmentedControl = {
        let items = ["일기", "캘린더", "인사이트"]
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 0
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // 일기 뷰
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(EmotionDiaryCell.self, forCellReuseIdentifier: EmotionDiaryCell.identifier)
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        return tableView
    }()
    
    // 캘린더 뷰
    private let calendarViewController: EmotionCalendarViewController = {
        let vc = EmotionCalendarViewController()
        return vc
    }()
    
    // 인사이트 뷰
    private let insightStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    // MARK: - Properties
    private var diaryEntries: [EmotionDiary] = []
    private var currentView: Int = 0
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadDiaryData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadDiaryData()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "감정 일기"
        
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "일기 쓰기", style: .plain, target: self, action: #selector(writeNewDiary)),
            UIBarButtonItem(title: "전체 삭제", style: .plain, target: self, action: #selector(clearAllData))
        ]
        
        setupSegmentedControl()
        setupScrollView()
        setupTableView()
        setupCalendarView()
        setupInsightView()
        
        showCurrentView()
    }
    
    private func setupSegmentedControl() {
        view.addSubview(segmentedControl)
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
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
    
    private func setupTableView() {
        contentView.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: contentView.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            tableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            tableView.heightAnchor.constraint(greaterThanOrEqualToConstant: 400)
        ])
    }
    
    private func setupCalendarView() {
        // 캘린더 뷰컨트롤러를 자식으로 추가
        addChild(calendarViewController)
        contentView.addSubview(calendarViewController.view)
        calendarViewController.didMove(toParent: self)
        
        calendarViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            calendarViewController.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            calendarViewController.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            calendarViewController.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            calendarViewController.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    private func setupInsightView() {
        contentView.addSubview(insightStackView)
        
        NSLayoutConstraint.activate([
            insightStackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            insightStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            insightStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            insightStackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Data Loading
    private func loadDiaryData() {
        diaryEntries = SettingsManager.shared.loadEmotionDiary()
        tableView.reloadData()
        updateInsightView()
    }
    
    // MARK: - View Switching
    @objc private func segmentChanged() {
        currentView = segmentedControl.selectedSegmentIndex
        showCurrentView()
    }
    
    private func showCurrentView() {
        tableView.isHidden = currentView != 0
        calendarViewController.view.isHidden = currentView != 1
        insightStackView.isHidden = currentView != 2
        
        if currentView == 2 {
            updateInsightView()
        }
    }
    
    // MARK: - Insight Generation
    private func updateInsightView() {
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
            title: "🤖 AI 추천 활용",
            content: "총 \(aiPresetUsage)번 사용",
            color: .systemPurple.withAlphaComponent(0.1)
        )
        insightStackView.addArrangedSubview(presetCard)
    }
    
    private func createInsightCard(title: String, content: String, color: UIColor) -> UIView {
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
    private func getMostFrequentEmotion() -> (emotion: String, count: Int) {
        let emotionCounts = Dictionary(grouping: diaryEntries, by: { $0.selectedEmotion })
            .mapValues { $0.count }
        
        guard let mostFrequent = emotionCounts.max(by: { $0.value < $1.value }) else {
            return ("😊", 0)
        }
        
        return (mostFrequent.key, mostFrequent.value)
    }
    
    private func getRecentActivity() -> Int {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        
        return diaryEntries.filter { $0.date >= sevenDaysAgo }.count
    }
    
    private func getAIPresetUsage() -> Int {
        let allPresets = SettingsManager.shared.loadSoundPresets()
        return allPresets.filter { $0.isAIGenerated }.count
    }
    
    // MARK: - Actions
    @objc private func writeNewDiary() {
        let diaryWriteVC = DiaryWriteViewController()
        diaryWriteVC.onDiarySaved = { [weak self] in
            self?.loadDiaryData()
        }
        let navController = UINavigationController(rootViewController: diaryWriteVC)
        present(navController, animated: true)
    }
    
    @objc private func clearAllData() {
        let alert = UIAlertController(
            title: "⚠️ 전체 삭제",
            message: "모든 감정 일기를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "삭제", style: .destructive) { [weak self] _ in
            // 감정 일기 데이터 삭제 (SettingsManager에 메소드 추가 필요)
            UserDefaults.standard.removeObject(forKey: "emotionDiary")
            self?.loadDiaryData()
            
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
        })
        
        present(alert, animated: true)
    }
}

// MARK: - TableView DataSource & Delegate
extension EmotionDiaryViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return diaryEntries.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: EmotionDiaryCell.identifier, for: indexPath) as? EmotionDiaryCell else {
            return UITableViewCell()
        }
        
        let entry = diaryEntries[indexPath.row]
        cell.configure(with: entry)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
}

// MARK: - EmotionDiaryCell
class EmotionDiaryCell: UITableViewCell {
    static let identifier = "EmotionDiaryCell"
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray5.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let emotionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .systemGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let userMessageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let aiResponseLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.numberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(containerView)
        [emotionLabel, dateLabel, userMessageLabel, aiResponseLabel].forEach {
            containerView.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            emotionLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            emotionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            dateLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            dateLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            userMessageLabel.topAnchor.constraint(equalTo: emotionLabel.bottomAnchor, constant: 8),
            userMessageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            userMessageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            aiResponseLabel.topAnchor.constraint(equalTo: userMessageLabel.bottomAnchor, constant: 8),
            aiResponseLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            aiResponseLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            aiResponseLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with entry: EmotionDiary) {
        emotionLabel.text = entry.selectedEmotion
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        dateLabel.text = formatter.string(from: entry.date)
        
        userMessageLabel.text = entry.userMessage
        aiResponseLabel.text = "AI: " + entry.aiResponse
    }
}
