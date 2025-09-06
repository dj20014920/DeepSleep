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
import ObjectiveC

// MARK: - Section Header View (Local Implementation)
final class SectionHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "SectionHeaderView"
    let titleLabel = UILabel()
    let addButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        addSubview(titleLabel)

        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.setTitle("추가", for: .normal)
        addButton.setTitleColor(tintColor, for: .normal)
        addSubview(addButton)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            addButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            addButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: addButton.leadingAnchor, constant: -8)
        ])
    }
}

// MARK: - Calendar Host Cell (FSCalendar inside collection view)
final class CalendarHostCell: UICollectionViewCell {
    static let reuseIdentifier = "CalendarHostCell"

    func attach(calendar: FSCalendar) {
        if calendar.superview !== contentView {
            calendar.removeFromSuperview()
            calendar.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(calendar)
            NSLayoutConstraint.activate([
                calendar.topAnchor.constraint(equalTo: contentView.topAnchor),
                calendar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                calendar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                calendar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }
    }
}

class EmotionCalendarViewController: UIViewController, UICollectionViewDataSource {

    // 외부에서 날짜 선택 이벤트를 수신하기 위한 콜백
    public var onDateSelected: ((Date) -> Void)?
    // 캘린더만 표시(헤더/컬렉션 미표시) 모드
    public var calendarOnlyMode: Bool = false

    enum SectionType {
        case calendar
        case todayEmotion(EmotionDiary?)
        case insight(String)
        case todo([TodoItem])

        var title: String {
            switch self {
            case .calendar:
                return ""
        case .todayEmotion:
                return "오늘의 감정"
            case .insight:
                return "대나무숲 친구 대화"
            case .todo:
                return "할 일 목록"
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

    var selectedDate: Date = Date()
    // 캘린더 화면에서 Todo 섹션 노출 여부(감정 일기 화면의 캘린더 탭에서는 false로 설정)
    var showsTodoSection: Bool = true
    // 섹션 노출 설정
    var showTodayEmotionSection: Bool = true
    var showInsightSection: Bool = true
    private var sections: [SectionType] = []

    private let todoManager = TodoManager.shared
    private var cancellables = Set<AnyCancellable>()

    var diaryEntries: [EmotionDiary] = []
    var diaryDataForCalendar: [String: EmotionDiary] = [:]

    // MARK: - CoreData
    var container: NSPersistentContainer!

    // ✅ 인사이트 페이지네이션 상태
    private var loadedAnalyses: [SettingsManager.DiaryAnalysisRecord] = []
    private var analysisOffset: Int = 0
    private let analysisPageSize: Int = 5
    private var analysisHasMore: Bool = false
    private var isLoadingMoreAnalysis: Bool = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // AppDelegate 타입 안전한 접근으로 수정
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            self.container = appDelegate.persistentContainer
        } else {
            // Fallback: 새로운 컨테이너 생성
            container = NSPersistentContainer(name: "DeepSleep")
            container.loadPersistentStores { _, error in
                if let error = error {
                    print("❌ Core Data 오류: \(error)")
                }
            }
        }

        // UI setup
        view.backgroundColor = .systemBackground
        title = "감정 캘린더"

        // UI 구성
        if calendarOnlyMode {
            // 캘린더 전용 모드: 기존처럼 상단 고정 캘린더만 사용
            setupCalendar()
        } else {
            // 통합 스크롤 모드: 컬렉션뷰 하나로 모두 스크롤
            setupCollectionView()
        }

        // 데이터 로드
        loadDiaryData()

        if !calendarOnlyMode {
            resetInsightPaginationAndLoadFirstPage(for: selectedDate)
            // 실시간 반영 알림 구독 (calendarOnlyMode에서는 불필요하므로 등록하지 않음)
            NotificationCenter.default.addObserver(self, selector: #selector(handleTodosUpdated), name: .todosUpdated, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleEmotionDiaryUpdated(_:)), name: .emotionDiaryUpdated, object: nil)
            // 📡 오늘의 일기 분석 로그 갱신 수신 → 인사이트 즉시 반영
            NotificationCenter.default.addObserver(self, selector: #selector(handleDiaryAnalysisUpdated(_:)), name: .diaryAnalysisUpdated, object: nil)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 일기 데이터 새로고침
        loadDiaryData()
        // 현재 선택된 날짜 데이터 새로고침 (calendarOnlyMode에서는 스킵)
        if !calendarOnlyMode {
            resetInsightPaginationAndLoadFirstPage(for: selectedDate)
        }
        // 캘린더 새로고침
        if calendar != nil {
            calendar.reloadData()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .todosUpdated, object: nil)
        NotificationCenter.default.removeObserver(self, name: .emotionDiaryUpdated, object: nil)
        NotificationCenter.default.removeObserver(self, name: .diaryAnalysisUpdated, object: nil)
    }

    @objc private func handleTodosUpdated() {
        loadData(for: selectedDate)
        calendar?.reloadData()
        if !calendarOnlyMode { collectionView.reloadData() }
    }

    @objc private func handleEmotionDiaryUpdated(_ note: Notification) {
        // 일기 변경 즉시 동기화 (오늘/선택일 모두 반영)
        loadDiaryData()
        loadData(for: selectedDate)
        calendar?.reloadData()
        if !calendarOnlyMode { collectionView.reloadData() }
    }

    @objc private func handleDiaryAnalysisUpdated(_ note: Notification) {
        // 오늘/선택일의 분석 로그 변경 즉시 인사이트 반영
        guard !calendarOnlyMode else { return }
        resetInsightPaginationAndLoadFirstPage(for: selectedDate)
        collectionView.reloadData()
    }

    private func loadDiaryData() {
        diaryEntries = SettingsManager.shared.loadEmotionDiary()
        diaryDataForCalendar.removeAll()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        // 🔍 디버깅용 로그 추가
        print("🔍 [loadDiaryData] 로드된 일기 항목 수: \(diaryEntries.count)")

        for entry in diaryEntries {
            let dateString = formatter.string(from: entry.date)
            diaryDataForCalendar[dateString] = entry

            // 🔍 특정 날짜(7월 4일) 데이터 로깅
            if dateString.contains("2025-07-04") {
                print("🔍 [loadDiaryData] 7월 4일 데이터 발견:")
                print("  - 날짜: \(dateString)")
                print("  - 감정: '\(entry.selectedEmotion)'")
                print("  - 메시지: '\(entry.userMessage.prefix(50))'")
            }
        }

        if calendar != nil {
            calendar.reloadData()
        }
    }

    // MARK: - UI Setup Methods

    private func setupCalendar() {
        calendar = FSCalendar()
        calendar.delegate = self
        calendar.dataSource = self
        calendar.translatesAutoresizingMaskIntoConstraints = false
        calendar.locale = Locale(identifier: "en_US")

        // 캘린더 스타일 설정
        calendar.backgroundColor = .systemBackground
        calendar.appearance.headerTitleColor = .label
        calendar.appearance.weekdayTextColor = .label
        calendar.appearance.titleDefaultColor = .label
        // 기본 하이라이트(선택/오늘) 원 제거
        calendar.appearance.titleTodayColor = .label
        calendar.appearance.todayColor = .clear
        calendar.appearance.selectionColor = .clear
        calendar.appearance.borderSelectionColor = .clear
        calendar.appearance.titleSelectionColor = .label
        calendar.appearance.eventDefaultColor = .systemGreen
        calendar.appearance.headerDateFormat = "yyyy년 MM월"

        // 커스텀 데이 셀 등록 (이모지 + 그라데이션 테두리)
        calendar.register(EmotionCalendarDayCell.self, forCellReuseIdentifier: "EmotionCalendarDayCell")

        view.addSubview(calendar)

        NSLayoutConstraint.activate([
            calendar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            calendar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            calendar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            calendar.heightAnchor.constraint(equalToConstant: 300)
        ])
    }

    // 캘린더가 컬렉션뷰 셀 안에 필요할 때(통합 스크롤 모드) 초기화만 수행
    private func ensureCalendarInitialized() {
        if calendar == nil {
            calendar = FSCalendar()
            calendar.delegate = self
            calendar.dataSource = self
            calendar.translatesAutoresizingMaskIntoConstraints = false
            calendar.locale = Locale(identifier: "en_US")
            calendar.backgroundColor = .systemBackground
            calendar.appearance.headerTitleColor = .label
            calendar.appearance.weekdayTextColor = .label
            calendar.appearance.titleDefaultColor = .label
            calendar.appearance.titleTodayColor = .label
            calendar.appearance.todayColor = .clear
            calendar.appearance.selectionColor = .clear
            calendar.appearance.borderSelectionColor = .clear
            calendar.appearance.titleSelectionColor = .label
            calendar.appearance.eventDefaultColor = .systemGreen
            calendar.appearance.headerDateFormat = "yyyy년 MM월"
            calendar.register(EmotionCalendarDayCell.self, forCellReuseIdentifier: "EmotionCalendarDayCell")
        }
    }


    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 16
        layout.minimumInteritemSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        collectionView.dataSource = self
        collectionView.delegate = self

        // 셀 등록
        collectionView.register(CalendarHostCell.self, forCellWithReuseIdentifier: CalendarHostCell.reuseIdentifier)
        collectionView.register(TodayEmotionCell.self, forCellWithReuseIdentifier: TodayEmotionCell.reuseIdentifier)
        collectionView.register(InsightCell.self, forCellWithReuseIdentifier: InsightCell.reuseIdentifier)
        collectionView.register(TodoListCell.self, forCellWithReuseIdentifier: TodoListCell.reuseIdentifier)
        collectionView.register(SectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "SectionHeaderView")

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func loadData(for date: Date) {
        sections.removeAll()

        // 섹션 구성(최종 요구): 캘린더 → 오늘의 할 일 → 오늘의 감정 → 인사이트
        if !calendarOnlyMode { sections.append(.calendar) }
        if showsTodoSection {
            let todos = todoManager.getTodos(for: date)
            sections.append(.todo(todos))
        }
        let diaryForDate = diaryFor(date: date)
        if showTodayEmotionSection { sections.append(.todayEmotion(diaryForDate)) }
        if showInsightSection { sections.append(.insight(buildInsightText())) }

        if !calendarOnlyMode { collectionView.reloadData() }
    }

    private func diaryFor(date: Date) -> EmotionDiary? {
        let dateKeyFormatter = DateFormatter(); dateKeyFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateKeyFormatter.string(from: date)
        return diaryDataForCalendar[dateKey]
    }

    // MARK: - Insight Pagination Helpers
    private func resetInsightPaginationAndLoadFirstPage(for date: Date) {
        // calendarOnlyMode에서는 인사이트/컬렉션 뷰가 없으므로 스킵
        if calendarOnlyMode { return }

        loadedAnalyses.removeAll()
        analysisOffset = 0
        analysisHasMore = true
        isLoadingMoreAnalysis = false
        // 초기 섹션 구성
        loadData(for: date)
        loadMoreAnalysesIfNeeded(force: true)
    }

    private func buildInsightText() -> String {
        var blocks: [String] = []
        // 1) 일기 분석
        do {
            var diaryLines: [String] = []
            if loadedAnalyses.isEmpty {
                let (records, hasMore) = SettingsManager.shared.loadDiaryAnalyses(for: selectedDate, offset: 0, limit: 1)
                analysisHasMore = hasMore
                if records.isEmpty {
                    // 일기 없음이면 아예 블록을 추가하지 않음
                } else {
                    diaryLines.append(contentsOf: records.map { "• " + $0.text.trimmingCharacters(in: .whitespacesAndNewlines) })
                }
            } else {
                for rec in loadedAnalyses {
                    let t = rec.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    diaryLines.append("• " + t)
                }
                if analysisHasMore { diaryLines.append("… 외 추가 분석이 더 있어요") }
            }
            if !diaryLines.isEmpty { blocks.append("일기:\n" + diaryLines.joined(separator: "\n")) }
        }
        // 2) 할 일 조언(오늘 날짜의 각 Todo의 최신 조언 노출)
        do {
            let todos = todoManager.getTodos(for: selectedDate)
            var adviceLines: [String] = []
            for t in todos {
                if let adv = TodoManager.latestIndividualAdvice(in: t.aiAdvices), !adv.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    adviceLines.append("• \(t.title): \(adv)")
                }
            }
            if !adviceLines.isEmpty { blocks.append("할 일 조언:\n" + adviceLines.joined(separator: "\n")) }
        }
        if blocks.isEmpty {
            // 기본 문구
            return "아직 대화 내역이 없습니다. 일기를 작성하거나 오늘의 할 일에 대해 조언을 받아보세요."
        }
        return blocks.joined(separator: "\n\n")
    }

    private func loadMoreAnalysesIfNeeded(force: Bool = false) {
        guard force || (!isLoadingMoreAnalysis && analysisHasMore) else { return }
        isLoadingMoreAnalysis = true
        let (page, hasMore) = SettingsManager.shared.loadDiaryAnalyses(for: selectedDate, offset: analysisOffset, limit: analysisPageSize)
        analysisOffset += page.count
        analysisHasMore = hasMore
        if !page.isEmpty {
            loadedAnalyses.append(contentsOf: page)
            updateInsightSection()
        }
        isLoadingMoreAnalysis = false
    }

    private func updateInsightSection() {
        // calendarOnlyMode에서는 컬렉션 뷰가 없으므로 UI 업데이트 스킵
        guard !calendarOnlyMode, let collectionView = collectionView else { return }

        // 항상 메인 스레드에서 UI 갱신
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.updateInsightSection() }
            return
        }

        let text = buildInsightText()
        if let idx = sections.firstIndex(where: { if case .insight = $0 { return true } else { return false } }) {
            // 기존 인사이트 섹션 갱신 → 섹션 리로드만 사용(배치 삽입 없음)
            sections[idx] = .insight(text)
            collectionView.reloadSections(IndexSet(integer: idx))
        } else {
            // 새 인사이트 섹션 추가
            let insertIndex = computeInsightInsertIndex()
            // 데이터소스를 먼저 갱신한 뒤 전체 리로드로 KISS/안정성 우선
            // PERF-WARNING: 배치 삽입 대신 reloadData 사용 → 스크롤 위치 변동 가능성. 필요 시 DiffableDataSource로 개선.
            sections.insert(.insight(text), at: min(insertIndex, sections.count))
            collectionView.reloadData()
        }
    }

    private func computeInsightInsertIndex() -> Int {
        // 할 일, 오늘의 감정, 캘린더 중 마지막 섹션 다음 위치
        var lastIndex = -1
        for (idx, s) in sections.enumerated() {
            switch s {
            case .todayEmotion, .todo, .calendar:
                lastIndex = idx
            default: break
            }
        }
        return max(0, lastIndex + 1)
    }

    // MARK: - UICollectionViewDataSource

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }

    @objc func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch sections[section] {
        case .calendar:
            return 1
        case .todayEmotion:
            return 1
        case .insight:
            return 1
        case .todo:
            return 1
        }
    }

    @objc func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch sections[indexPath.section] {
        case .calendar:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CalendarHostCell.reuseIdentifier, for: indexPath) as! CalendarHostCell
            ensureCalendarInitialized()
            cell.attach(calendar: calendar)
            return cell
        case .todayEmotion(let diary):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TodayEmotionCell.reuseIdentifier, for: indexPath) as! TodayEmotionCell
            cell.onWriteAction = { [weak self] in self?.openDiaryWriteFromCalendar() }
            let isToday = Calendar.current.isDate(selectedDate, inSameDayAs: Date())
            cell.configure(with: diary, isToday: isToday)
            return cell
        case .insight:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: InsightCell.reuseIdentifier, for: indexPath) as! InsightCell
            // 분석 리스트 모드로 구성 (타이틀 숨김) + CTA (오늘/선택일 일기 O & 분석 없음)
            let isToday = Calendar.current.isDate(selectedDate, inSameDayAs: Date())
            let diaryForDate = diaryFor(date: selectedDate)
            let showCTA = (diaryForDate != nil) && loadedAnalyses.isEmpty && isToday
            cell.onPrimaryAction = { [weak self] in
                if let entry = diaryForDate { self?.startDiaryConversation(with: entry) }
            }
            cell.configureAnalysisList(buildInsightText(), showCTA: showCTA, ctaTitle: "오늘 일기 분석 시작")
            return cell
        case .todo(let items):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TodoListCell.reuseIdentifier, for: indexPath) as! TodoListCell
            cell.configure(with: items, for: selectedDate)
            // 동적 헤더 타이틀 구성: 오늘이면 "오늘의 할 일", 아니면 "M.d일의 할 일"
            let isToday = Calendar.current.isDate(selectedDate, inSameDayAs: Date())
            if isToday {
                cell.setHeaderTitle("오늘의 할 일")
            } else {
                let fmt = DateFormatter()
                fmt.locale = Locale(identifier: "ko_KR")
                fmt.dateFormat = "M.d"
                cell.setHeaderTitle("\(fmt.string(from: selectedDate))일의 할 일")
            }
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
        // Todo 섹션의 외부 헤더 텍스트는 숨김 (카드 내부의 "오늘의 할 일" 헤더만 사용)
        switch section {
        case .todo:
            header.titleLabel.text = ""
        default:
            header.titleLabel.text = section.title
        }
        // 상단 섹션 헤더의 [+추가]는 사용하지 않음 (카드 내부 버튼만 유지)
        header.addButton.isHidden = true
        return header
    }

    // MARK: - Actions

    private func openDiaryWriteFromCalendar() {
        let diaryWriteVC = DiaryWriteViewController()
        diaryWriteVC.onDiarySaved = { [weak self] in
            // 저장 직후 즉시 동기화 (알림도 오지만 안전하게 직접 반영)
            self?.loadDiaryData()
            if let selected = self?.selectedDate {
                self?.loadData(for: selected)
            }
            self?.calendar?.reloadData()
            self?.collectionView?.reloadData()
        }
        let nav = UINavigationController(rootViewController: diaryWriteVC)
        present(nav, animated: true)
    }

    @objc private func addButtonTapped(_ sender: UIButton) {
        UnifiedLogger.shared.logTodo("Add button tapped from section header")
        presentAddEditTodoViewController(todoItem: nil)
    }

    // MARK: - Todo Management
    private func presentAddEditTodoViewController(todoItem: TodoItem?) {
        let addEditVC = AddEditTodoViewController()
        addEditVC.delegate = self
        addEditVC.todoItem = todoItem

        let navController = UINavigationController(rootViewController: addEditVC)
        navController.modalPresentationStyle = .formSheet
        present(navController, animated: true)
    }
}

// MARK: - FSCalendarDelegate, FSCalendarDataSource

extension EmotionCalendarViewController: FSCalendarDelegate, FSCalendarDataSource {
    func calendar(_ calendar: FSCalendar, cellFor date: Date, at position: FSCalendarMonthPosition) -> FSCalendarCell {
        let cell = calendar.dequeueReusableCell(withIdentifier: "EmotionCalendarDayCell", for: date, at: position) as! EmotionCalendarDayCell
        // 오늘 표시: 우상단 모서리 접힘 마크
        cell.setTodayCornerVisible(Calendar.current.isDate(date, inSameDayAs: Date()))
        // 날짜별 할 일 상태를 계산하여 그라데이션 테두리 지정
        let todos = todoManager.getTodos(for: date)
        let state = CalendarDayDecorLogic.state(for: date, todosForDate: todos)
        switch state {
        case .none:
            cell.setTodoRingVisible(false)
        case .premiumRing:
            cell.setPalette(.premium)
            cell.setTodoRingVisible(true)
        case .freeRing:
            cell.setPalette(.free)
            cell.setTodoRingVisible(true)
        }
        return cell
    }
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        selectedDate = date

        // calendarOnlyMode인 경우 상위에서 날짜 변경을 처리하도록 콜백만 호출
        if calendarOnlyMode {
            onDateSelected?(date)
            return
        }

        // 선택 날짜 변경 시 데이터/인사이트 갱신만 수행 (별도 시트는 띄우지 않음)
        resetInsightPaginationAndLoadFirstPage(for: date)
        collectionView.reloadData()

        // UX: Todo 섹션으로 스크롤(존재 시)
        if let todoSectionIndex = sections.firstIndex(where: { if case .todo = $0 { return true } else { return false } }) {
            let indexPath = IndexPath(item: 0, section: todoSectionIndex)
            collectionView.scrollToItem(at: indexPath, at: .top, animated: true)
        }
    }

    private func presentTodosSheet(for date: Date, todos: [TodoItem]) {
        let vc = TodoListSheetViewController(date: date, todos: todos, allTodosProvider: { TodoManager.shared.loadTodos() })
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
        }
        present(nav, animated: true)
    }

    func calendar(_ calendar: FSCalendar, numberOfEventsFor date: Date) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        return diaryDataForCalendar[dateString] != nil ? 1 : 0
    }

    // 날짜별 감정 이모지 표시
    func calendar(_ calendar: FSCalendar, titleFor date: Date) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        // 🔍 특정 날짜(7월 4일) 데이터 로깅
        if dateString.contains("2025-07-04") {
            print("🔍 [calendar titleFor] 7월 4일 캘린더 표시 요청:")
            print("  - 날짜 문자열: \(dateString)")
            print("  - 일기 데이터 존재: \(diaryDataForCalendar[dateString] != nil)")
            if let diary = diaryDataForCalendar[dateString] {
                print("  - 저장된 감정: '\(diary.selectedEmotion)'")
                let emoji = getEmotionEmoji(for: diary.selectedEmotion)
                print("  - 변환된 이모지: '\(emoji)'")
                return emoji
            }
        }

        if let diary = diaryDataForCalendar[dateString] {
            return getEmotionEmoji(for: diary.selectedEmotion)
        }

        return nil // 기본 날짜 숫자 표시
    }

    // 공통 유틸을 통한 감정→이모지 변환
    private func getEmotionEmoji(for emotion: String) -> String {
        let emoji = CommonUtilities.shared.mapEmotionToEmoji(emotion)
        print("🔍 [getEmotionEmoji] 결과 이모지: '\(emoji)'")
        return emoji
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension EmotionCalendarViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.frame.width - 32 // 양쪽 패딩
        switch sections[indexPath.section] {
        case .calendar:
            return CGSize(width: width, height: 300)
        case .todayEmotion(let diary):
            let isToday = Calendar.current.isDate(selectedDate, inSameDayAs: Date())
            let height = estimatedTodayEmotionHeight(diary: diary, isToday: isToday, width: width)
            return CGSize(width: width, height: height)
        case .insight(let text):
            let height = estimatedInsightHeight(for: text, width: width)
            return CGSize(width: width, height: height)
        case .todo(let items):
            // 동적 행 높이 계산: 제목 멀티라인 + 마감시간 서브타이틀 반영
            let headerHeight: CGFloat = 40 // TodoListCell.headerView 고정 높이
            let topPadding: CGFloat = 16
            let betweenHeaderAndTable: CGFloat = 8
            let bottomPadding: CGFloat = 16

            // 텍스트 가용 폭 계산 (컨테이너 좌우 16, 셀 내부 체크박스/인디케이터 여백 고려)
            let containerInnerLR: CGFloat = 32 // 16 + 16
            let checkboxAndGaps: CGFloat = 8 + 24 + 12 // 좌측 여백 + 체크 + 간격
            let indicatorAndRight: CGFloat = 8 + 8 // 인디케이터 + 우측 여백
            let textWidth = max(80, width - containerInnerLR - checkboxAndGaps - indicatorAndRight)

            let titleFont = UIFont.systemFont(ofSize: 16, weight: .regular)
            let dueFont = UIFont.systemFont(ofSize: 12, weight: .regular)
            var rowsTotal: CGFloat = 0
            for item in items {
                let title = item.title as NSString
                let due = item.dueDateString as NSString
                let titleBox = title.boundingRect(
                    with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: titleFont],
                    context: nil
                )
                let dueBox = due.boundingRect(
                    with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: dueFont],
                    context: nil
                )
                let rowBaseSpacing: CGFloat = 8 + 4 + 8 // top + between + bottom
                let rowHeight = max(56, ceil(titleBox.height) + ceil(dueBox.height) + rowBaseSpacing)
                rowsTotal += rowHeight
            }
            // 빈 목록일 경우 최소 높이 확보(빈 상태 라벨 노출)
            if items.isEmpty { rowsTotal = 60 }

            let computed = topPadding + headerHeight + betweenHeaderAndTable + rowsTotal + bottomPadding
            let height = max(120, computed)
            return CGSize(width: width, height: height)
        }
    }

    // 동적 높이 계산: 오늘의 감정 카드
    private func estimatedTodayEmotionHeight(diary: EmotionDiary?, isToday: Bool, width: CGFloat) -> CGFloat {
        let contentWidth = width - 48 // 내부 패딩 보정 (24*2)
        var total: CGFloat = 0
        // 이모지 + 감정명 기본 높이
        total += 32 /*emoji*/ + 8 + 20 /*name*/

        if diary == nil {
            // 안내문 텍스트 높이 (동적 계산으로 개선)
            let text = isToday ? "아직 오늘의 감정을 알려주시지 않았어요!\n입력하러 가볼까요?" : "이 날짜에는 감정 일기를 작성하지 않으셨어요."
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.lineBreakMode = .byWordWrapping
                    style.alignment = .center
                    return style
                }()
            ]
            let box = (text as NSString).boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs,
                context: nil
            )
            // 텍스트 높이에 충분한 여백 추가
            total += 8 + ceil(box.height) + 8 // 위아래 여백 추가
            if isToday {
                total += 8 + 44 // 버튼 영역 + 여백
            }
        }
        // 컨테이너 상하 여백 (16*2)
        total += 32
        // 최소 높이를 120으로 설정하되, 계산된 높이가 더 크면 그 값 사용
        return max(120, total)
    }

    // 동적 높이 계산: 인사이트 텍스트 길이에 따라 높이를 유연하게 조정
    private func estimatedInsightHeight(for text: String, width: CGFloat) -> CGFloat {
        // InsightCell 내부 패딩 및 구성 요소 높이를 고려한 대략치
        let contentWidth = width - 24 // container 내부 좌우 여백 보정
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14)
        ]
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        // 기본 요소 높이: 아이콘(32) + 타이틀(20) + 간격(8*3) + 컨테이너 여백(32)
        let base: CGFloat = 32 + 20 + (8 * 3) + 32
        let total = base + ceil(bounding.height)
        return max(120, total)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        switch sections[section] {
        case .calendar:
            return .zero
        case .todayEmotion:
            return CGSize(width: collectionView.frame.width, height: 50)
        case .todo:
            return .zero // 카드 내부 헤더만 사용하므로 숨김
        default:
            return CGSize(width: collectionView.frame.width, height: 50)
        }
    }
}

// MARK: - 무한 스크롤 트리거
extension EmotionCalendarViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == collectionView else { return }
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let height = scrollView.bounds.size.height
        // 하단 200pt 근접 시 로드
        if offsetY > contentHeight - height - 200 {
            loadMoreAnalysesIfNeeded()
        }
    }
}

// MARK: - TodoListCellDelegate
extension EmotionCalendarViewController: TodoListCellDelegate {
    func todoListCell(_ cell: TodoListCell, didToggleItem item: TodoItem, at index: Int) {
        var updatedItem = item
        updatedItem.isCompleted.toggle()
        todoManager.updateTodoItem(updatedItem)

        // 데이터 새로고침
        collectionView.reloadData()
        UnifiedLogger.shared.logTodo("Todo item toggled: \(item.title)")
    }

    func todoListCell(_ cell: TodoListCell, didDeleteItem item: TodoItem, at index: Int) {
        todoManager.deleteTodo(withId: item.id) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.collectionView.reloadData()
                    UnifiedLogger.shared.logTodo("Todo item deleted: \(item.title)")
                } else if let error = error {
                    UnifiedLogger.shared.error("Failed to delete todo: \(error.localizedDescription)")
                }
            }
        }
    }

    func todoListCell(_ cell: TodoListCell, didRequestEditItem item: TodoItem, at index: Int) {
        UnifiedLogger.shared.logTodo("Edit todo item requested: \(item.title)")
        presentAddEditTodoViewController(todoItem: item)
    }

    func todoListCellDidRequestAddItem(_ cell: TodoListCell) {
        UnifiedLogger.shared.logTodo("Add todo item requested")
        presentAddEditTodoViewController(todoItem: nil)
    }

    func todoListCellDidRequestDailyAdvice(_ cell: TodoListCell, for items: [TodoItem], on date: Date) {
        UnifiedLogger.shared.logTodo("Daily advice requested for \(items.count) items on \(date)")

        // 원래 로직 준수: 오늘의 할 일 조언 버튼은 '할 일 정보'만 전송(일기 포함 금지), 없으면 주간 컨텍스트로만 보강
        let weeklyContext = SessionManager.shared.buildRichContextForLocalAI().emotionHistory.first?.emotion
        let allTodos = todoManager.loadTodos()
        let prompt = TodoManager.buildOverallAdvicePrompt(
            date: date,
            todos: items,
            allTodos: allTodos,
            weeklyContext: weeklyContext,
            diaryEmotion: nil,
            diaryExcerpt: nil
        )

        requestOverallTodoAdvice(prompt: prompt, applyTo: items)
    }

    func todoListCellDidRequestIndividualAdvice(_ cell: TodoListCell, for item: TodoItem) {
        // 본문 탭 시 바로 수정 화면으로 이동
        UnifiedLogger.shared.logTodo("Body tapped (edit) for item: \(item.title)")
        presentAddEditTodoViewController(todoItem: item)
    }

    func todoListCell(_ cell: TodoListCell, didTapAdviceFor item: TodoItem) {
        // 버튼 직접 동작: 조언이 있으면 보기, 없으면 생성
        if let indiv = TodoManager.latestIndividualAdvice(in: item.aiAdvices), !indiv.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let vc = SimpleAdviceViewController(titleText: "'\(item.title)' 조언", adviceText: indiv)
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: true)
        } else {
            requestIndividualTodoAdvice(for: item)
        }
    }

    private func requestOverallTodoAdvice(prompt: String, applyTo items: [TodoItem]) {
        let remaining = AIUsageManager.shared.getRemainingCount(for: .overallTodoAdvice)
        guard remaining > 0 else {
            let alert = UIAlertController(title: "AI 조언 한도 초과", message: "오늘의 AI 조언 사용 한도를 모두 사용하셨습니다.\n내일 다시 이용해주세요.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default))
            present(alert, animated: true)
            return
        }
        LoadingOverlay.show(in: self)
        Task { [weak self] in
            do {
                let advice = try await SessionManager.shared.sendMessage(
                    content: prompt,
                    model: .gemini,
                    mode: .taskAdviceOverall,
                    saveMessages: false,
                    policyMeta: [
                        "keyedFeature": "todo_overall_advice"
                    ]
                )
                TodoManager.distributeOverallAdvice(advice, to: items)
                await MainActor.run {
                    LoadingOverlay.hide(from: self)
                    let vc = SimpleAdviceViewController(titleText: "💡 오늘의 할 일 조언", adviceText: advice)
                    vc.modalPresentationStyle = .overFullScreen
                    self?.present(vc, animated: true)
                    self?.updateInsightSection()
                    // UX: 전체 조언 1회 사용 후 버튼 상태 갱신을 위해 목록 리로드
                    self?.collectionView?.reloadData()
                }
            } catch {
                await MainActor.run {
                    LoadingOverlay.hide(from: self)
                    let alert = UIAlertController(title: "AI 조언 오류", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "확인", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }

    private func requestIndividualTodoAdvice(for item: TodoItem) {
        let remaining = AIUsageManager.shared.getRemainingCount(for: .individualTodoAdvice)
        guard remaining > 0 else {
            let alert = UIAlertController(title: "AI 조언 한도 초과", message: "오늘의 AI 조언 사용 한도를 모두 사용하셨습니다.\n내일 다시 이용해주세요.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default))
            present(alert, animated: true)
            return
        }
        // per-item today check 제거: fingerprint 기반 제한만 사용
        let fp = TodoManager.adviceFingerprint(for: item)
        if UsageLimitManager.shared.hasUsedDailyFingerprint(namespace: "todo_individual_advice", fingerprint: fp) {
            let alert = UIAlertController(title: "오늘은 이미 유사한 할 일의 조언을 받았습니다", message: "삭제 후 재등록 방식은 1일 1회 제한에 포함됩니다.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default))
            present(alert, animated: true)
            return
        }
        let prompt = TodoManager.buildIndividualAdvicePrompt(item: item)

        LoadingOverlay.show(in: self)
        Task { [weak self] in
            do {
                let advice = try await SessionManager.shared.sendMessage(
                    content: prompt,
                    model: .gemini,
                    mode: .taskAdvice,
                    saveMessages: false,
                    policyMeta: [
                        "feature": "task_advice",
                        "fingerprint": fp
                    ]
                )
                TodoManager.shared.appendAdvice(to: item.id, advice: advice)
                UsageLimitManager.shared.markDailyFingerprintUsed(namespace: "todo_individual_advice", fingerprint: fp)
                await MainActor.run {
                    LoadingOverlay.hide(from: self)
                    let vc = SimpleAdviceViewController(titleText: "'\(item.title)' 조언", adviceText: advice)
                    vc.modalPresentationStyle = .overFullScreen
                    self?.present(vc, animated: true)
                    self?.updateInsightSection()
                    // UX: 개별 조언 생성 직후 버튼 레이블 즉시 반영
                    self?.collectionView?.reloadData()
                }
            } catch {
                await MainActor.run {
                    LoadingOverlay.hide(from: self)
                    let alert = UIAlertController(title: "AI 조언 오류", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "확인", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
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
        guard let collectionView = collectionView else { return }
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.updateInsightSection(with: text) }
            return
        }
        if let index = sections.firstIndex(where: { $0.isInsightSection }) {
            sections[index] = .insight(text)
            collectionView.reloadSections(IndexSet(integer: index))
        } else {
            let insertIndex = computeInsightInsertIndex()
            sections.insert(.insight(text), at: min(insertIndex, sections.count))
            collectionView.reloadData()
        }
    }
}

// MARK: - AddEditTodoDelegate 채택으로 저장 후 새로고침
extension EmotionCalendarViewController: AddEditTodoDelegate {
    func didSaveTodoItem(_ todoItem: TodoItem) {
        // 저장/삭제 후 목록 갱신
        loadData(for: selectedDate)
        calendar?.reloadData()
        collectionView?.reloadData()
    }
}

// =====================================================================
// MARK: - Merged content from EmotionCalendarViewcontroller+Diary.swift
// =====================================================================

// MARK: - EmotionCalendarViewController Diary Extension
extension EmotionCalendarViewController {

    private struct AssociatedKeys {
        static var diaryEntryKey: UInt8 = 0
    }

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

        // ✅ 일기 분석 대화 버튼 - 카운트 표기 제거
        let remainingCount = AIUsageManager.shared.getRemainingCount(for: .diaryAnalysis)
        let diaryAnalysisAction = UIAlertAction(title: remainingCount > 0 ? "💬 이 일기를 AI와 깊이 분석" : "💬 일기 분석 대화 (오늘 사용 완료)", style: .default) { _ in
            if remainingCount > 0 { self.startDiaryConversation(with: entry) }
        }
        if remainingCount <= 0 { diaryAnalysisAction.isEnabled = false }
        alert.addAction(diaryAnalysisAction)

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
        // ✅ 일일 제한 체크
        let remainingCount = AIUsageManager.shared.getRemainingCount(for: .diaryAnalysis)
        let totalCount = AIUsageManager.shared.getTotalLimit(for: .diaryAnalysis)

        guard remainingCount > 0 else {
            let limitAlert = UIAlertController(
                title: "📝 일기 분석 한도 도달",
                message: """
                오늘 일기 분석 대화의 일일 한도(총 \(totalCount)회)를 모두 사용하셨습니다.

                내일 다시 이용해 주세요. 😊

                💡 더 많은 대화를 원하시면 일반 채팅을 이용해 보세요.
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
                message: "일기 내용이 비어있어 대나무숲에서 이야기할 수 없습니다.",
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

        // ⏳ 최근 3일 제한 확인
        let cal = Calendar.current
        if let threeDaysAgo = cal.date(byAdding: .day, value: -3, to: Date()), entry.date < threeDaysAgo {
            let alert = UIAlertController(title: "최근 3일 제한", message: "최근 3일 이내의 일기만 대나무숲에서 분석할 수 있어요.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default))
            present(alert, animated: true)
            return
        }

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

        // 🛡️ 초기 사용자 텍스트 설정(SSoT 트리거 키)
        chatVC.initialUserText = "일기_분석_모드"

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

        // ✅ 대나무숲 버튼도 제한 체크
        let remainingCount = AIUsageManager.shared.getRemainingCount(for: .diaryAnalysis)
        let chatButtonTitle = remainingCount > 0 ? "💬 대나무숲 분석" : "💬 분석 완료"
        let chatButton = UIBarButtonItem(title: chatButtonTitle, style: .plain, target: self, action: #selector(startChatFromDetail))
        chatButton.isEnabled = remainingCount > 0

        detailVC.navigationItem.leftBarButtonItem = closeButton
        detailVC.navigationItem.rightBarButtonItem = chatButton

        // 연관 객체 저장 (안전한 키 사용)
        objc_setAssociatedObject(detailVC, &AssociatedKeys.diaryEntryKey, entry, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        let navController = UINavigationController(rootViewController: detailVC)
        present(navController, animated: true)
    }

    @objc func closeDiaryDetail() {
        dismiss(animated: true)
    }

    @objc func startChatFromDetail() {
        guard let presentedNav = presentedViewController as? UINavigationController,
              let detailVC = presentedNav.topViewController,
              let entry = objc_getAssociatedObject(detailVC, &AssociatedKeys.diaryEntryKey) as? EmotionDiary else { return }

        presentedNav.dismiss(animated: true) { [weak self] in
            self?.startDiaryConversation(with: entry)
        }
    }
}
