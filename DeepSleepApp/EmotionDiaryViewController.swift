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
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    // AI 분석 버튼들
    private let aiAnalyzeSelectedDiaryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("선택 일기 AI 분석", for: .normal)
        button.isEnabled = false // 처음에는 비활성화
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let aiAnalyzeMonthlyEmotionsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("최근 30일 감정 AI 분석", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Properties
    internal var diaryEntries: [EmotionDiary] = []
    private var currentView: Int = 0
    private var selectedDiaryForAnalysis: EmotionDiary? // 선택된 일기 저장
    
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
        
        NSLayoutConstraint.activate([
            insightStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20), // 여백 추가
            insightStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            insightStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            insightStackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Data Loading
    internal func loadDiaryData() {
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
            // 인사이트 뷰가 표시될 때 선택된 일기 분석 버튼 상태 업데이트
            aiAnalyzeSelectedDiaryButton.isEnabled = selectedDiaryForAnalysis != nil
        }
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
    
    // 스크롤 뷰 콘텐츠 사이즈 업데이트 메서드 추가
    internal func updateScrollViewContentSize() {
        scrollView.layoutIfNeeded()
    }
    
    // MARK: - AI 분석 액션

    @objc private func analyzeSelectedDiaryTapped() {
        guard let diary = selectedDiaryForAnalysis else {
            // 사용자에게 알림 (예: 토스트 메시지)
            showSimpleToast(message: "분석할 일기를 먼저 선택해주세요.")
            return
        }

        let chatVC = ChatViewController()
        // EmotionDiary 객체에서 DiaryContext를 생성하는 편의 생성자 사용
        let diaryContext = DiaryContext(from: diary) // 'diary'는 EmotionDiary 타입이어야 함
        chatVC.diaryContext = diaryContext
        chatVC.initialUserText = "선택된 일기 심층 분석"

        configureChatVCPresetCallback(for: chatVC)
        navigationController?.pushViewController(chatVC, animated: true)
    }

    @objc private func analyzeMonthlyEmotionsTapped() {
        let allEntries = SettingsManager.shared.loadEmotionDiary()
        let calendar = Calendar.current
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) else {
            showSimpleToast(message: "날짜 계산 오류")
            return
        }

        let recentEntries = allEntries.filter { $0.date >= thirtyDaysAgo }
        if recentEntries.isEmpty {
            showSimpleToast(message: "최근 30일간의 일기 데이터가 없습니다.")
            return
        }

        // emotionPatternData 생성 (예: "2023-10-27:😊,2023-10-26:😢")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let patternData = recentEntries.map { "\(dateFormatter.string(from: $0.date)):\($0.selectedEmotion)" }.joined(separator: ",")

        let chatVC = ChatViewController()
        chatVC.emotionPatternData = patternData
        chatVC.initialUserText = "최근 30일 감정 패턴 분석"
        
        configureChatVCPresetCallback(for: chatVC)
        navigationController?.pushViewController(chatVC, animated: true)
    }

    private func configureChatVCPresetCallback(for chatVC: ChatViewController) {
        // 네비게이션 스택에서 ViewController (메인 화면) 인스턴스를 찾습니다.
        guard let navigationController = self.navigationController else {
            print("⚠️ NavigationController가 없습니다.")
            return
        }

        // 네비게이션 스택의 모든 뷰 컨트롤러를 확인
        print("📱 현재 네비게이션 스택:")
        navigationController.viewControllers.forEach { print("- \(type(of: $0))") }

        // 메인 ViewController 찾기 (스택의 맨 아래에서부터 찾기)
        if let mainVC = navigationController.viewControllers.first(where: { $0 is MainViewController }) as? MainViewController {
            print("✅ Main ViewController 찾음")
            
            // 약한 참조로 클로저 캡처
            chatVC.onPresetApply = { [weak mainVC, weak navigationController] recommendation in
                guard let mainVC = mainVC else {
                    print("⚠️ Main ViewController가 해제되었습니다.")
                    return
                }
                
                print("🎵 프리셋 적용 시작: \(recommendation.presetName)")
                print("볼륨: \(recommendation.volumes)")
                print("버전: \(recommendation.selectedVersions ?? [])")
                
                mainVC.applyPreset(
                    volumes: recommendation.volumes,
                    versions: recommendation.selectedVersions,
                    name: recommendation.presetName
                )
                
                // 메인 화면으로 돌아가기 전에 잠시 대기
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    navigationController?.popToViewController(mainVC, animated: true)
                }
                
                print("✅ 프리셋 적용 완료")
            }
        } else {
            print("⚠️ Main ViewController를 찾을 수 없습니다.")
        }
    }
    
    // 간단한 토스트 메시지 (ViewController의 showToast 활용)
    private func showSimpleToast(message: String) {
        if let mainVC = navigationController?.viewControllers.first(where: { $0 is MainViewController }) as? MainViewController {
            mainVC.showToast(message: message)
        } else {
            // ViewController를 찾지 못한 경우의 대체 처리 (예: print 또는 자체 간단 토스트)
            print("Toast: \(message) (MainVC not found)")
        }
    }
}
