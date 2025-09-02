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

class EmotionCalendarViewController: UIViewController, UICollectionViewDataSource {
    
    enum SectionType {
        case todayEmotion(EmotionDiary?)
        case insight(String)
        case todo([TodoItem])
        
        var title: String {
            switch self {
            case .todayEmotion:
                return "" // 컬렉션 헤더는 숨김 (상단 고정 라벨 사용)
            case .insight:
                return "대나무숲 친구 대화"
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
    // 캘린더 화면에서 Todo 섹션 노출 여부(감정 일기 화면의 캘린더 탭에서는 false로 설정)
    var showsTodoSection: Bool = true
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
        setupCalendar()
        setupHeaderLabel()
        setupCollectionView()
        
        // 데이터 로드
        loadDiaryData()
        resetInsightPaginationAndLoadFirstPage(for: selectedDate)

        // 실시간 반영 알림 구독
        NotificationCenter.default.addObserver(self, selector: #selector(handleTodosUpdated), name: .todosUpdated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleEmotionDiaryUpdated(_:)), name: .emotionDiaryUpdated, object: nil)
        // 📡 오늘의 일기 분석 로그 갱신 수신 → 인사이트 즉시 반영
        NotificationCenter.default.addObserver(self, selector: #selector(handleDiaryAnalysisUpdated(_:)), name: .diaryAnalysisUpdated, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 일기 데이터 새로고침
        loadDiaryData()
        // 현재 선택된 날짜 데이터 새로고침
        resetInsightPaginationAndLoadFirstPage(for: selectedDate)
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
        collectionView.reloadData()
    }
    
    @objc private func handleEmotionDiaryUpdated(_ note: Notification) {
        // 일기 변경 즉시 동기화 (오늘/선택일 모두 반영)
        loadDiaryData()
        loadData(for: selectedDate)
        calendar?.reloadData()
        collectionView.reloadData()
    }
    
    @objc private func handleDiaryAnalysisUpdated(_ note: Notification) {
        // 오늘/선택일의 분석 로그 변경 즉시 인사이트 반영
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
    
    private func setupHeaderLabel() {
        headerLabel = UILabel()
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        headerLabel.textColor = .label
        headerLabel.text = "오늘의 감정"
        
        view.addSubview(headerLabel)
        
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: calendar.bottomAnchor, constant: 16),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
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
        collectionView.register(TodayEmotionCell.self, forCellWithReuseIdentifier: TodayEmotionCell.reuseIdentifier)
        collectionView.register(InsightCell.self, forCellWithReuseIdentifier: InsightCell.reuseIdentifier)
        collectionView.register(TodoListCell.self, forCellWithReuseIdentifier: TodoListCell.reuseIdentifier)
        collectionView.register(SectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "SectionHeaderView")
        
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func loadData(for date: Date) {
        sections.removeAll()
        
        // 섹션 구성: 오늘의 감정 카드 → 대나무숲 친구 대화 → Todo
        let diaryForDate = diaryFor(date: date)
        sections.append(.todayEmotion(diaryForDate))
        
        // 인사이트 텍스트는 loadedAnalyses 기반
        let insightText = buildInsightText()
        sections.append(.insight(insightText))
        
        // Todo 섹션은 설정에 따라 표시
        if showsTodoSection {
            let todos = todoManager.getTodos(for: date)
            sections.append(.todo(todos))
        }
        
        collectionView.reloadData()
    }
    
    private func diaryFor(date: Date) -> EmotionDiary? {
        let dateKeyFormatter = DateFormatter(); dateKeyFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateKeyFormatter.string(from: date)
        return diaryDataForCalendar[dateKey]
    }
    
    // MARK: - Insight Pagination Helpers
    private func resetInsightPaginationAndLoadFirstPage(for date: Date) {
        loadedAnalyses.removeAll()
        analysisOffset = 0
        analysisHasMore = true
        isLoadingMoreAnalysis = false
        // 초기 섹션 구성
        loadData(for: date)
        loadMoreAnalysesIfNeeded(force: true)
    }
    
    private func buildInsightText() -> String {
        guard !loadedAnalyses.isEmpty else {
            // 비어있으면 기본 문구 구성
            let (records, hasMore) = SettingsManager.shared.loadDiaryAnalyses(for: selectedDate, offset: 0, limit: 1)
            analysisHasMore = hasMore
            if diaryFor(date: selectedDate) == nil {
                return "아직 분석 내역이 없습니다. 일기를 작성하고 대나무숲에서 이야기해보세요."
            }
            return records.isEmpty ? "아직 분석 내역이 없습니다. 일기를 작성하고 대나무숲에서 이야기해보세요." : "• \(records.first!.text)"
        }
        var lines: [String] = []
        for rec in loadedAnalyses {
            let t = rec.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let preview = t.count > 180 ? String(t.prefix(180)) + "…" : t
            lines.append("• " + preview)
        }
        if analysisHasMore { lines.append("… 외 추가 분석이 더 있어요") }
        return lines.joined(separator: "\n")
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
        let text = buildInsightText()
        if let idx = sections.firstIndex(where: { if case .insight = $0 { return true } else { return false } }) {
            sections[idx] = .insight(text)
            collectionView.reloadSections(IndexSet(integer: idx))
        } else {
            sections.insert(.insight(text), at: 1)
            collectionView.insertSections(IndexSet(integer: 1))
        }
    }
    
    // MARK: - UICollectionViewDataSource
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }
    
    @objc func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch sections[section] {
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
    
    private func openDiaryWriteFromCalendar() {
        let diaryWriteVC = DiaryWriteViewController()
        diaryWriteVC.onDiarySaved = { [weak self] in
            // 저장 직후 즉시 동기화 (알림도 오지만 안전하게 직접 반영)
            self?.loadDiaryData()
            if let selected = self?.selectedDate {
                self?.loadData(for: selected)
            }
            self?.calendar?.reloadData()
            self?.collectionView.reloadData()
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
        // 선택 날짜 변경 시 인사이트 페이지네이션 리셋
        resetInsightPaginationAndLoadFirstPage(for: date)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: date)

        let todos = todoManager.getTodos(for: date)
        let hasTodos = !todos.isEmpty
        let diary = diaryDataForCalendar[dateKey]

        // 우선순위: 일기 + 할일이 둘 다 있으면 선택지를 제공, 아니면 각각 단일 액션
        if let diary = diary, hasTodos {
            let sheet = UIAlertController(title: "무엇을 보실까요?", message: nil, preferredStyle: .actionSheet)
            sheet.addAction(UIAlertAction(title: "💭 일기 보기", style: .default, handler: { [weak self] _ in
                self?.showDiaryDetail(for: diary.date, emotion: diary.selectedEmotion)
            }))
            sheet.addAction(UIAlertAction(title: "📋 할 일 + 조언", style: .default, handler: { [weak self] _ in
                self?.presentTodosSheet(for: date, todos: todos)
            }))
            sheet.addAction(UIAlertAction(title: "취소", style: .cancel))
            present(sheet, animated: true)
        } else if let diary = diary {
            showDiaryDetail(for: diary.date, emotion: diary.selectedEmotion)
        } else if hasTodos {
            presentTodosSheet(for: date, todos: todos)
        }
        // 선택 날짜의 데이터 새로고침
        // loadData(for: date)
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
        case .todayEmotion(let diary):
            let isToday = Calendar.current.isDate(selectedDate, inSameDayAs: Date())
            let height = estimatedTodayEmotionHeight(diary: diary, isToday: isToday, width: width)
            return CGSize(width: width, height: height)
        case .insight(let text):
            let height = estimatedInsightHeight(for: text, width: width)
            return CGSize(width: width, height: height)
        case .todo(let items):
            // 기존: 고정 80 → 내장 테이블뷰(row 44pt)와 헤더/패딩을 반영한 동적 높이
            let rows = max(items.count, 0)
            let headerHeight: CGFloat = 40 // TodoListCell.headerView 고정 높이
            let topPadding: CGFloat = 16
            let betweenHeaderAndTable: CGFloat = 8
            let bottomPadding: CGFloat = 16
            let rowHeight: CGFloat = 44
            // 최소 높이(비어있을 때 empty state 레이블 표시를 위한 여유)
            let minHeight: CGFloat = 100
            let computed = topPadding + headerHeight + betweenHeaderAndTable + (CGFloat(rows) * rowHeight) + bottomPadding
            let height = max(minHeight, computed)
            return CGSize(width: width, height: height)
        }
    }
    
    // 동적 높이 계산: 오늘의 감정 카드
    private func estimatedTodayEmotionHeight(diary: EmotionDiary?, isToday: Bool, width: CGFloat) -> CGFloat {
        let contentWidth = width - 24 // 내부 패딩 보정
        var total: CGFloat = 0
        // 이모지 + 감정명 기본 높이
        total += 32 /*emoji*/ + 8 + 20 /*name*/
        
        if diary == nil {
            // 안내문 텍스트 높이
            let text = isToday ? "아직 오늘의 감정을 알려주시지 않았어요!\n입력하러 가볼까요?" : "이 날짜에는 감정 일기를 작성하지 않으셨어요."
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 14)]
            let box = (text as NSString).boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs,
                context: nil
            )
            total += 8 + ceil(box.height)
            if isToday {
                total += 8 + 40 // 버튼 영역 대략치
            }
        }
        // 컨테이너 상하 여백
        total += 32
        return max(100, total)
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
        case .todayEmotion:
            return .zero // 상단 고정 라벨이 있으므로 헤더 숨김
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

// MARK: - AddEditTodoDelegate 채택으로 저장 후 새로고침
extension EmotionCalendarViewController: AddEditTodoDelegate {
    func didSaveTodoItem(_ todoItem: TodoItem) {
        // 저장/삭제 후 목록 갱신
        loadData(for: selectedDate)
        calendar?.reloadData()
        collectionView.reloadData()
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
        
        // ✅ 일기 분석 대화 버튼 - 남은 횟수 표시 (n/total 형식 통일)
        let remainingCount = AIUsageManager.shared.getRemainingCount(for: .diaryAnalysis)
        let totalCount = AIUsageManager.shared.getTotalLimit(for: .diaryAnalysis)
        let diaryAnalysisTitle = remainingCount > 0 ?
            "💬 이 일기를 AI와 깊이 분석 (\(remainingCount)/\(totalCount))" :
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
        let totalCount = AIUsageManager.shared.getTotalLimit(for: .diaryAnalysis)
        let chatButtonTitle = remainingCount > 0 ? "💬 대나무숲 분석 (\(remainingCount)/\(totalCount))" : "💬 분석 완료"
        let chatButton = UIBarButtonItem(title: chatButtonTitle, style: .plain, target: self, action: #selector(startChatFromDetail))
        
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
