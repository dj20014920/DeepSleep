import UIKit

class EmotionDiaryViewController: UIViewController {
    
    // MARK: - UI Components
    private let segmentedControl: UISegmentedControl = {
        let items = ["일기", "캘린더", "인사이트"]
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 0
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    
    // 일기 뷰
    internal let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(EmotionDiaryCell.self, forCellReuseIdentifier: EmotionDiaryCell.identifier)
        tableView.register(EmotionDiaryDisplayCell.self, forCellReuseIdentifier: EmotionDiaryDisplayCell.identifier)  // 🔧 추가 등록
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
    internal let insightStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.distribution = .fill  // 각 요소가 자신의 크기 유지
        stackView.alignment = .fill      // 가로 전체 채우기
        stackView.translatesAutoresizingMaskIntoConstraints = false
        // 🔧 스택뷰 자체는 필요한 크기만 차지하도록 설정
        stackView.setContentHuggingPriority(.init(1000), for: .vertical)
        stackView.setContentCompressionResistancePriority(.init(1000), for: .vertical)
        return stackView
    }()
    
    // 대나무숲 분석 버튼들
    private let aiAnalyzeSelectedDiaryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("선택 일기 대나무숲 분석", for: .normal)
        button.isEnabled = false // 처음에는 비활성화
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let aiAnalyzeMonthlyEmotionsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("최근 30일 감정 대나무숲 분석", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Properties
    internal var diaryEntries: [EmotionDiary] = []
    internal var currentView: Int = 0 // 익스텐션에서 접근 가능하도록 internal로 변경
    private var selectedDiaryForAnalysis: EmotionDiary? // 선택된 일기 저장
    private var recommendationHistory: [RecommendationData] = []
    
    // 🔧 단순화된 제약조건 시스템 - 하나의 동적 제약조건만 사용
    internal var dynamicHeightConstraint: NSLayoutConstraint?
    
    // UI 컴포넌트들을 internal로 변경하여 익스텐션에서 접근 가능하게 함
    internal let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentInsetAdjustmentBehavior = .never // 자동 inset 조정 비활성화
        scrollView.alwaysBounceVertical = false // 수직 바운스 비활성화
        return scrollView
    }()
    
    internal let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
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
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        title = "감정 일기"
        
        let writeButton = UIBarButtonItem(title: "일기 쓰기", style: .plain, target: self, action: #selector(writeNewDiary))
        let deleteButton = UIBarButtonItem(title: "전체 삭제", style: .plain, target: self, action: #selector(clearAllData))
        
        writeButton.tintColor = UIDesignSystem.Colors.primaryText
        deleteButton.tintColor = UIDesignSystem.Colors.primaryText
        
        navigationItem.rightBarButtonItems = [writeButton, deleteButton]
        
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
        
        // 🔧 단순화된 제약조건 시스템 - 최소 높이만 보장
        dynamicHeightConstraint = contentView.heightAnchor.constraint(
            greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor
        )
        dynamicHeightConstraint?.priority = .init(750) // 중간 우선순위
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            // 🔧 단일 동적 제약조건 활성화
            dynamicHeightConstraint!
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
        addChild(calendarViewController)
        contentView.addSubview(calendarViewController.view)
        calendarViewController.didMove(toParent: self)
        calendarViewController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            calendarViewController.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            calendarViewController.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            calendarViewController.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            // 👇 여기에 높이 명시
            calendarViewController.view.heightAnchor.constraint(equalToConstant: 750),
            
            calendarViewController.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    private func setupInsightView() {
        contentView.addSubview(insightStackView)
        
        // AI 분석 버튼 액션 연결
        aiAnalyzeSelectedDiaryButton.addTarget(self, action: #selector(analyzeSelectedDiaryTapped), for: .touchUpInside)
        aiAnalyzeMonthlyEmotionsButton.addTarget(self, action: #selector(analyzeMonthlyEmotionsTapped), for: .touchUpInside)

        // 버튼들을 스택뷰에 추가
        let aiButtonStackView = UIStackView(arrangedSubviews: [aiAnalyzeSelectedDiaryButton, aiAnalyzeMonthlyEmotionsButton])
        aiButtonStackView.axis = .vertical
        aiButtonStackView.spacing = 10
        aiButtonStackView.distribution = .fillEqually
        
        insightStackView.addArrangedSubview(aiButtonStackView) // 기존 인사이트 뷰 스택에 추가
        
        // 🔧 insightStackView의 크기가 contentView를 결정하도록 우선순위 설정
        let bottomConstraint = insightStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        bottomConstraint.priority = .init(999) // 높은 우선순위로 설정
        
        NSLayoutConstraint.activate([
            insightStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20), // 여백 추가
            insightStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            insightStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            bottomConstraint
        ])
    }
    
    // MARK: - Data Loading
    internal func loadDiaryData() {
        // 🔧 메인 스레드에서 실행 보장
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.loadDiaryData()
            }
            return
        }
        
        self.diaryEntries = SettingsManager.shared.loadEmotionDiary()
        self.tableView.reloadData()
        self.updateInsightView()
    }
    
    // MARK: - View Switching
    @objc private func segmentChanged() {
        currentView = segmentedControl.selectedSegmentIndex
        // 🔧 메인 스레드에서 실행 보장
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.segmentChanged()
            }
            return
        }
        
        showCurrentView()
    }
    
    private func showCurrentView() {
        // 🔧 UI 업데이트를 메인 스레드에서 보장
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.showCurrentView()
            }
            return
        }
        
        // 모든 뷰 숨기기
        tableView.isHidden = true
        calendarViewController.view.isHidden = true
        insightStackView.isHidden = true
        
        // 🔧 단순화된 탭 전환 처리 - 더 이상 복잡한 제약조건 전환 불필요
        print("🔍 [탭 전환] 현재 탭: \(currentView)")
        
        // 선택된 뷰만 보이기
        switch currentView {
        case 0: // 일기
            tableView.isHidden = false
        case 1: // 캘린더
            calendarViewController.view.isHidden = false
        case 2: // 인사이트
            insightStackView.isHidden = false
        default:
            break
        }
        
        updateScrollViewContentSize()
    }
    
    func updateScrollViewContentSize() {
        // 🔧 UI 업데이트를 메인 스레드에서 보장
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.updateScrollViewContentSize()
            }
            return
        }
        
        // 인사이트 탭에서는 Auto Layout이 자동으로 처리
        if currentView == 2 {
            updateInsightScrollViewContentSize()
            return
        }
        
        // 다른 탭에서는 기본 처리
        var contentHeight: CGFloat = 0
        
        switch currentView {
        case 0: // 일기
            contentHeight = max(tableView.contentSize.height, scrollView.bounds.height)
        case 1: // 캘린더
            contentHeight = max(calendarViewController.view.frame.height, scrollView.bounds.height)
        default:
            contentHeight = scrollView.bounds.height
        }
        
        scrollView.contentSize = CGSize(width: scrollView.bounds.width, height: contentHeight)
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
            // 감정 일기 데이터 삭제
            SettingsManager.shared.resetAllDiaryEntries() // (가정) SettingsManager에 해당 함수 필요
            self?.loadDiaryData()
            self?.selectedDiaryForAnalysis = nil // 선택된 일기 초기화
            self?.aiAnalyzeSelectedDiaryButton.isEnabled = false // 버튼 비활성화
            print("🗑️ 모든 일기 삭제됨")
        })
        
        present(alert, animated: true)
    }
    
    internal func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - AI 분석 액션

    @objc private func analyzeSelectedDiaryTapped() {
        guard let diary = selectedDiaryForAnalysis else {
            // 사용자에게 알림 (예: print)
            print("분석할 일기를 먼저 선택해주세요.")
            return
        }

        // ChatRouter를 사용하여 ChatViewController 생성 (내부에서 ChatManager 자동 설정)
        let chatVC = ChatRouter.chatViewController(context: .diaryAnalysis(diary: diary))
        chatVC.initialUserText = "선택된 일기 심층 분석"
        
        // 프리셋 적용 콜백 설정
        chatVC.onPresetApply = { [weak self] preset in
            self?.applyRecommendationAndReturn(preset)
        }

        navigationController?.pushViewController(chatVC, animated: true)
    }

    @objc private func analyzeMonthlyEmotionsTapped() {
        let allEntries = SettingsManager.shared.loadEmotionDiary()
        let calendar = Calendar.current
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) else {
            print("날짜 계산 오류")
            return
        }

        let recentEntries = allEntries.filter { $0.date >= thirtyDaysAgo }
        if recentEntries.isEmpty {
            print("최근 30일간의 일기 데이터가 없습니다.")
            return
        }

        // emotionPatternData 생성 (예: "2023-10-27:😊,2023-10-26:😢")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let patternData = recentEntries.map { "\(dateFormatter.string(from: $0.date)):\($0.selectedEmotion)" }.joined(separator: ",")

        // ChatRouter를 사용하여 ChatViewController 생성 (내부에서 ChatManager 자동 설정)
        let chatVC = ChatRouter.chatViewController(context: .monthlyPattern(data: patternData))
        chatVC.initialUserText = "최근 30일 감정 패턴 분석"
        
        // 프리셋 적용 콜백 설정
        chatVC.onPresetApply = { [weak self] preset in
            self?.applyRecommendationAndReturn(preset)
        }
        
        navigationController?.pushViewController(chatVC, animated: true)
    }

    private func applyRecommendationAndReturn(_ preset: SoundPreset) {
        print("✅ 프리셋 적용 콜백 수신:", preset.presetName)
        
        // ChatVC를 pop하여 이전 화면으로 돌아감
        navigationController?.popViewController(animated: true)
        
        // 전역 함수를 호출하여 메인 VC에 프리셋 적용
        forceSyncViewControllerPreset(
            volumes: preset.volumes,
            versions: preset.compatibleVersions,
            name: preset.presetName
        )
    }

    private func handleRecommendation(_ recommendation: RecommendationResponse) {
        // 추천 응답 처리
        let recommendationData = RecommendationData(
            title: recommendation.title,
            description: recommendation.description,
            soundIds: recommendation.soundIds,
            presetId: recommendation.presetId,
            versions: [], // versions 속성 제거
            timestamp: Date()
        )
        
        // 추천 데이터 저장
        recommendationHistory.append(recommendationData)
        saveRecommendationHistory()
        
        // UI 업데이트
        updateRecommendationUI(with: recommendationData)
    }
    
    // MARK: - Recommendation Methods
    private func saveRecommendationHistory() {
        if let encoded = try? JSONEncoder().encode(recommendationHistory) {
            UserDefaults.standard.set(encoded, forKey: "recommendationHistory")
        }
    }
    
    private func loadRecommendationHistory() {
        if let data = UserDefaults.standard.data(forKey: "recommendationHistory"),
           let decoded = try? JSONDecoder().decode([RecommendationData].self, from: data) {
            recommendationHistory = decoded
        }
    }
    
    private func updateRecommendationUI(with recommendation: RecommendationData) {
        // UI 업데이트 로직
        DispatchQueue.main.async {
            // 여기에 UI 업데이트 코드 추가
        }
    }
}
