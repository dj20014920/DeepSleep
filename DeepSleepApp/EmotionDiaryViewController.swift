//  EmotionDiaryViewController.swift
//  EmoZleep
//
//  Created on 2025-01-20.

import UIKit

class EmotionDiaryViewController: UIViewController {
    
    // MARK: - UI Components
    private let segmentedControl: UISegmentedControl = {
        let items = ["일기", "캘린더", "Todo", "인사이트"]
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
    
    // 캘린더 뷰 - 동적 로딩(모듈명 자동 감지)으로 안정화
    private let calendarViewController: UIViewController = {
        let moduleName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "DeepSleep"
        let fullName = "\(moduleName).EmotionCalendarViewController"
        if let cls = NSClassFromString(fullName) as? UIViewController.Type {
            let vc = cls.init()
            if let cal = vc as? EmotionCalendarViewController { cal.showsTodoSection = false }
            return vc
        } else {
            // Fallback: lightweight placeholder to keep layout stable
            let vc = UIViewController()
            vc.view.backgroundColor = .clear
            let label = UILabel()
            label.text = "캘린더 로드 실패: 타깃 멤버십/링킹 확인 필요"
            label.textColor = .secondaryLabel
            label.textAlignment = .center
            label.numberOfLines = 2
            label.translatesAutoresizingMaskIntoConstraints = false
            vc.view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor)
            ])
            print("⚠️ [EmotionDiaryViewController] EmotionCalendarViewController 동적 로딩 실패 - \(fullName). 타깃 멤버십 또는 FSCalendar 링크를 확인하세요.")
            return vc
        }
    }()

    // 할 일 탭 컨텐츠: 캘린더 + 할 일 목록(통합 스크롤)
    private let todoTabViewController: EmotionCalendarViewController = {
        let vc = EmotionCalendarViewController()
        vc.calendarOnlyMode = false
        vc.showsTodoSection = true
        vc.showTodayEmotionSection = false
        vc.showInsightSection = false
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
    // ✅ 무한스크롤 표시용 가시 리스트(페이지네이션)
    internal var visibleDiaryEntries: [EmotionDiary] = []
    private let diaryPageSize: Int = 20
    private var diaryOffset: Int = 0
    private var isLoadingMoreDiaries: Bool = false
    private var hasMoreDiaries: Bool = true

    internal var currentView: Int = 0 // 익스텐션에서 접근 가능하도록 internal로 변경
    private var selectedDiaryForAnalysis: EmotionDiary? // 선택된 일기 저장
    private var recommendationHistory: [RecommendationData] = []
    
    // 🔧 단순화된 제약조건 시스템 - 하나의 동적 제약조건만 사용
    internal var dynamicHeightConstraint: NSLayoutConstraint?
    
    // 🔧 Bottom constraints for each segment; activate only the one for the visible view
    internal var tableBottomConstraint: NSLayoutConstraint?
    internal var calendarBottomConstraint: NSLayoutConstraint?
    internal var todoBottomConstraint: NSLayoutConstraint?
    internal var insightBottomConstraint: NSLayoutConstraint?
    
    // ✅ 화면 높이 고정용(탭별 내부 스크롤 활성화)
    private var calendarHeightConstraint: NSLayoutConstraint?
    private var diaryHeightConstraint: NSLayoutConstraint?
    private var todoHeightConstraint: NSLayoutConstraint?
    
    // Insights 탭 전용 내부 스크롤뷰 구성 요소
    internal let insightScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.alwaysBounceVertical = true
        sv.contentInsetAdjustmentBehavior = .never
        return sv
    }()
    internal let insightContentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private var insightHeightConstraint: NSLayoutConstraint?
    
    // UI 컴포넌트들을 internal로 변경하여 익스텐션에서 접근 가능하게 함
    internal let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentInsetAdjustmentBehavior = .never // 자동 inset 조정 비활성화
        scrollView.alwaysBounceVertical = true // 수직 바운스 활성화
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
        updateAIButtonsRemainingLabels()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // 튜토리얼 표시 (최초 방문 시)
        showTutorialIfNeeded()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        title = "미니 다이어리"
        
        // 상단 버튼은 일기 탭에서만 노출 (showCurrentView에서 설정)
        
        setupSegmentedControl()
        setupScrollView()
        setupTableView()
        setupCalendarView()
        setupTodoTabView()
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
        
        // Prepare bottom constraint to activate only when the Diary tab is visible
        tableBottomConstraint = tableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        tableBottomConstraint?.isActive = false
        
        // ✅ 일기 탭 내부 스크롤 활성화를 위해 화면 높이 제약 사전 생성(활성화는 탭 전환 시)
        diaryHeightConstraint = tableView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        diaryHeightConstraint?.isActive = false
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: contentView.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }
    
    private func setupCalendarView() {
        addChild(calendarViewController)
        contentView.addSubview(calendarViewController.view)
        calendarViewController.didMove(toParent: self)
        calendarViewController.view.translatesAutoresizingMaskIntoConstraints = false

        // Prepare bottom constraint to activate only when the Calendar tab is visible
        calendarBottomConstraint = calendarViewController.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        calendarBottomConstraint?.isActive = false
        
        // ✅ 고정값(750) 제거하고 화면 높이와 동일하게(활성화는 탭 전환 시)
        calendarHeightConstraint = calendarViewController.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        calendarHeightConstraint?.isActive = false
        
        NSLayoutConstraint.activate([
            calendarViewController.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            calendarViewController.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            calendarViewController.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }

    private func setupTodoTabView() {
        addChild(todoTabViewController)
        contentView.addSubview(todoTabViewController.view)
        todoTabViewController.didMove(toParent: self)
        todoTabViewController.view.translatesAutoresizingMaskIntoConstraints = false

        todoBottomConstraint = todoTabViewController.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        todoBottomConstraint?.isActive = false

        // ✅ 할 일 탭도 내부 스크롤 사용을 위해 화면 높이와 동일하게(활성화는 탭 전환 시)
        todoHeightConstraint = todoTabViewController.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        todoHeightConstraint?.isActive = false

        NSLayoutConstraint.activate([
            todoTabViewController.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            todoTabViewController.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            todoTabViewController.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }
    
    private func setupInsightView() {
        // 내부 스크롤 뷰 트리 구성: contentView → insightScrollView → insightContentView → insightStackView
        contentView.addSubview(insightScrollView)
        insightScrollView.addSubview(insightContentView)
        insightContentView.addSubview(insightStackView)
        
        // AI 분석 버튼 액션 연결
        aiAnalyzeSelectedDiaryButton.addTarget(self, action: #selector(analyzeSelectedDiaryTapped), for: .touchUpInside)
        aiAnalyzeMonthlyEmotionsButton.addTarget(self, action: #selector(analyzeMonthlyEmotionsTapped), for: .touchUpInside)

        // 버튼들을 스택뷰에 추가
        let aiButtonStackView = UIStackView(arrangedSubviews: [aiAnalyzeSelectedDiaryButton, aiAnalyzeMonthlyEmotionsButton])
        aiButtonStackView.axis = .vertical
        aiButtonStackView.spacing = 10
        aiButtonStackView.distribution = .fillEqually
        insightStackView.addArrangedSubview(aiButtonStackView)
        
        // Bottom 연결은 스크롤뷰 기준으로 contentView와 연결해 컨텐츠 높이 결정
        insightBottomConstraint = insightScrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        insightBottomConstraint?.priority = .init(999)
        insightBottomConstraint?.isActive = false
        
        // 내부 스크롤 활성화를 위한 높이 고정 (탭 전환 시 활성화)
        insightHeightConstraint = insightScrollView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        insightHeightConstraint?.isActive = false
        
        NSLayoutConstraint.activate([
            // insightScrollView 크기
            insightScrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            insightScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            insightScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            // insightContentView는 스크롤뷰 contentLayout에 붙임
            insightContentView.topAnchor.constraint(equalTo: insightScrollView.contentLayoutGuide.topAnchor),
            insightContentView.leadingAnchor.constraint(equalTo: insightScrollView.contentLayoutGuide.leadingAnchor),
            insightContentView.trailingAnchor.constraint(equalTo: insightScrollView.contentLayoutGuide.trailingAnchor),
            insightContentView.bottomAnchor.constraint(equalTo: insightScrollView.contentLayoutGuide.bottomAnchor),
            insightContentView.widthAnchor.constraint(equalTo: insightScrollView.frameLayoutGuide.widthAnchor),
            
            // insightStackView는 콘텐츠 내부에 여백을 두고 배치
            insightStackView.topAnchor.constraint(equalTo: insightContentView.topAnchor, constant: 20),
            insightStackView.leadingAnchor.constraint(equalTo: insightContentView.leadingAnchor, constant: 16),
            insightStackView.trailingAnchor.constraint(equalTo: insightContentView.trailingAnchor, constant: -16),
            insightStackView.bottomAnchor.constraint(equalTo: insightContentView.bottomAnchor, constant: -20)
        ])

        // 초기 버튼 타이틀에 남은 횟수 표시 적용
        updateAIButtonsRemainingLabels()
    }

    // 중복된 viewWillAppear 제거: 위에서 일괄 처리

    /// 남은 횟수 라벨을 버튼 타이틀에 반영(일관된 UX)
    private func updateAIButtonsRemainingLabels() {
        // 일기 개별 분석(일일 한도)
        let remainDiary = AIUsageManager.shared.getRemainingCount(for: .diaryAnalysis)
        let totalDiary = AIUsageManager.shared.getTotalLimit(for: .diaryAnalysis)
        let diaryTitle = remainDiary > 0 ? "선택 일기 대나무숲 분석 (\(remainDiary)/\(totalDiary))" : "선택 일기 대나무숲 분석 (오늘 사용 완료)"
        aiAnalyzeSelectedDiaryButton.setTitle(diaryTitle, for: .normal)
        aiAnalyzeSelectedDiaryButton.isEnabled = remainDiary > 0 && selectedDiaryForAnalysis != nil

        // 최근 30일 감정 패턴 분석(주간 1회)
        let weekly = UsageLimitManager.shared.canUseWeeklyLimitedFeature(anchor: .kstMonday, key: "monthly_statistics")
        let monthTitle = weekly.canUse ? "최근 30일 감정 대나무숲 분석 (이번주 \(weekly.remaining)/1)" : "최근 30일 감정 대나무숲 분석 (이번주 사용 완료)"
        aiAnalyzeMonthlyEmotionsButton.setTitle(monthTitle, for: .normal)
        aiAnalyzeMonthlyEmotionsButton.isEnabled = weekly.canUse
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
        
        // 전체 데이터 로드
        self.diaryEntries = SettingsManager.shared.loadEmotionDiary()
        // 최신순 정렬(필요시) 후 페이지네이션 초기화
        // self.diaryEntries.sort { $0.date > $1.date }
        resetDiaryPaginationAndLoadFirstPage()
        
        self.tableView.reloadData()
        self.updateInsightView()
    }
    
    // ✅ 페이지네이션 초기화 및 첫 페이지 로드
    private func resetDiaryPaginationAndLoadFirstPage() {
        diaryOffset = 0
        isLoadingMoreDiaries = false
        hasMoreDiaries = true
        visibleDiaryEntries.removeAll()
        
        // ✅ 기존 셀 상태를 즉시 0행으로 동기화(초기 로드/리셋 시 필수)
        tableView.reloadData()
        
        loadMoreDiariesIfNeeded(force: true)
    }
    
    // ✅ 추가 페이지 로드
    internal func loadMoreDiariesIfNeeded(force: Bool = false) {
        guard force || (!isLoadingMoreDiaries && hasMoreDiaries) else { return }
        isLoadingMoreDiaries = true
        
        let start = diaryOffset
        let end = min(diaryEntries.count, diaryOffset + diaryPageSize)
        if start < end {
            let nextSlice = Array(diaryEntries[start..<end])
            let startIndex = visibleDiaryEntries.count
            visibleDiaryEntries.append(contentsOf: nextSlice)
            diaryOffset = end
            hasMoreDiaries = diaryOffset < diaryEntries.count
            
            // ✅ 초기 로드(0에서 시작)일 때는 insertRows 대신 reload로 일관성 보장
            if startIndex == 0 {
                tableView.reloadData()
            } else {
                var indexPaths: [IndexPath] = []
                for i in 0..<nextSlice.count { indexPaths.append(IndexPath(row: startIndex + i, section: 0)) }
                tableView.performBatchUpdates({
                    tableView.insertRows(at: indexPaths, with: .automatic)
                }, completion: nil)
            }
        } else {
            hasMoreDiaries = false
        }
        isLoadingMoreDiaries = false
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
        todoTabViewController.view.isHidden = true
        insightScrollView.isHidden = true
        
        // 🔧 단순화된 탭 전환 처리 - 더 이상 복잡한 제약조건 전환 불필요
        print("🔍 [탭 전환] 현재 탭: \(currentView)")
        
        // 선택된 뷰만 보이기
        switch currentView {
        case 0: tableView.isHidden = false
        case 1: calendarViewController.view.isHidden = false
        case 2: todoTabViewController.view.isHidden = false
        case 3: insightScrollView.isHidden = false
        default: break
        }
        
        // 🔧 Activate only the bottom constraint for the visible view to let Auto Layout drive content height
        tableBottomConstraint?.isActive = false
        calendarBottomConstraint?.isActive = false
        todoBottomConstraint?.isActive = false
        insightBottomConstraint?.isActive = false
        
        // ✅ 탭별 내부 스크롤 동작 설정
        configureScrollingForCurrentTab()

        view.setNeedsLayout()
        view.layoutIfNeeded()

        updateScrollViewContentSize()

        // 네비게이션 버튼: 일기 탭에서만 표시
        if currentView == 0 {
            let writeButton = UIBarButtonItem(title: "일기 쓰기", style: .plain, target: self, action: #selector(writeNewDiary))
            let deleteButton = UIBarButtonItem(title: "전체 삭제", style: .plain, target: self, action: #selector(clearAllData))
            writeButton.tintColor = UIDesignSystem.Colors.primaryText
            deleteButton.tintColor = UIDesignSystem.Colors.primaryText
            navigationItem.rightBarButtonItems = [writeButton, deleteButton]
        } else {
            navigationItem.rightBarButtonItems = nil
        }
    }
    
    private func configureScrollingForCurrentTab() {
        // 부모 스크롤 활성/비활성 및 높이 제약 활성화로 자식 스크롤 독립 동작
        switch currentView {
        case 0: // Diary
            scrollView.isScrollEnabled = false
            diaryHeightConstraint?.isActive = true
            calendarHeightConstraint?.isActive = false
            todoHeightConstraint?.isActive = false
            insightHeightConstraint?.isActive = false
            tableBottomConstraint?.isActive = true
        case 1: // Calendar
            scrollView.isScrollEnabled = false
            diaryHeightConstraint?.isActive = false
            calendarHeightConstraint?.isActive = true
            todoHeightConstraint?.isActive = false
            insightHeightConstraint?.isActive = false
            calendarBottomConstraint?.isActive = true
        case 2: // Todo
            scrollView.isScrollEnabled = false
            diaryHeightConstraint?.isActive = false
            calendarHeightConstraint?.isActive = false
            todoHeightConstraint?.isActive = true
            insightHeightConstraint?.isActive = false
            todoBottomConstraint?.isActive = true
        case 3: // Insight
            scrollView.isScrollEnabled = false
            diaryHeightConstraint?.isActive = false
            calendarHeightConstraint?.isActive = false
            todoHeightConstraint?.isActive = false
            insightHeightConstraint?.isActive = true
            insightBottomConstraint?.isActive = true
        default:
            break
        }
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
        if currentView == 3 {
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

    // MARK: - 🎯 튜토리얼 시스템

    private func showTutorialIfNeeded() {
        // 온보딩이 완료된 후에만 튜토리얼 표시
        guard OnboardingManager.shared.isOnboardingCompleted else { return }

        let hasShownTutorial = UserDefaults.standard.bool(forKey: "HasShownDiaryTutorial")
        guard !hasShownTutorial else { return }

        // 튜토리얼 표시
        showDiaryTutorial()
    }

    private func showDiaryTutorial() {
        let alert = UIAlertController(
            title: "📔 감정 일기 시작하기",
            message: """
            감정을 기록하고 대나무숲 친구와 함께 분석해보세요!

            ✨ 주요 기능:
            • 일기 쓰기 및 감정 기록
            • 캘린더에서 감정 추이 확인
            • 할 일 관리 및 리마인더
            • 대나무숲 친구 인사이트 및 추천

            💡 팁: 꾸준한 기록으로 자신의 감정 패턴을 발견해보세요!
            """,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "알겠어요", style: .default) { _ in
            UserDefaults.standard.set(true, forKey: "HasShownDiaryTutorial")
        })

        // 잠시 후 표시하여 자연스럽게
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.present(alert, animated: true)
        }
    }
}
