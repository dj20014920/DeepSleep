import UIKit
import FSCalendar

// MARK: - ChatManager import for unified AI service

// MARK: - ✅ GIF 고양이 로딩 뷰 (ChatBubbleCell에서 가져옴)
class TodoGifCatView: UIView {
    private let imageView = UIImageView()
    private var catDirection: CGFloat = 1
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupImageView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupImageView()
    }
    
    private func setupImageView() {
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = .clear
        addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        setupGifCat()
    }
    
    func setupGifCat() {
        imageView.stopAnimating()
        imageView.animationImages = nil
        
        let searchMethods = [
            ("Bundle 루트", { Bundle.main.path(forResource: "cat", ofType: "gif") }),
            ("Bundle URL", { Bundle.main.url(forResource: "cat", withExtension: "gif")?.path }),
            ("Bundle with extension", { Bundle.main.path(forResource: "cat.gif", ofType: nil) })
        ]
        
        for (method, pathFunc) in searchMethods {
            if let gifPath = pathFunc() {
                print("✅ \(method)에서 GIF 찾음: \(gifPath)")
                if loadGifFromPath(gifPath) {
                    return
                }
            } else {
                print("❌ \(method) 실패")
            }
        }
        
        print("❌ Bundle에서 GIF 파일을 찾을 수 없음")
        imageView.backgroundColor = UIColor.clear
    }
    
    private func loadGifFromPath(_ path: String) -> Bool {
        guard let gifData = NSData(contentsOfFile: path),
              let source = CGImageSourceCreateWithData(gifData, nil) else {
            print("❌ GIF 데이터 로드 실패: \(path)")
            return false
        }
        
        var images: [UIImage] = []
        let count = CGImageSourceGetCount(source)
        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                images.append(UIImage(cgImage: cgImage))
            }
        }
        
        if !images.isEmpty {
            DispatchQueue.main.async {
                self.imageView.animationImages = images
                self.imageView.animationDuration = Double(images.count) * 0.1
                self.imageView.animationRepeatCount = 0
                self.imageView.startAnimating()
                self.imageView.contentMode = .scaleAspectFit
                self.imageView.backgroundColor = .clear
            }
            return true
        } else {
            print("❌ GIF 프레임 변환 실패")
            return false
        }
    }
}

// MARK: - ✅ 로딩 오버레이 뷰
class LoadingOverlayView: UIView {
    private let containerView = UIView()
    private let gifCatView = TodoGifCatView()
    private let thinkingLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.3)
        
        // 컨테이너 뷰 설정
        containerView.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowOpacity = 0.2
        containerView.layer.shadowRadius = 8
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        // 고양이 뷰 설정
        gifCatView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(gifCatView)
        
        // 생각중 라벨 설정
        thinkingLabel.text = "생각중..."
        thinkingLabel.font = .systemFont(ofSize: 16, weight: .medium)
        thinkingLabel.textColor = UIDesignSystem.Colors.primaryText
        thinkingLabel.textAlignment = .center
        thinkingLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(thinkingLabel)
        
        NSLayoutConstraint.activate([
            // 컨테이너 뷰
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 120),
            containerView.heightAnchor.constraint(equalToConstant: 100),
            
            // 고양이 뷰
            gifCatView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            gifCatView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            gifCatView.widthAnchor.constraint(equalToConstant: 48),
            gifCatView.heightAnchor.constraint(equalToConstant: 48),
            
            // 생각중 라벨
            thinkingLabel.topAnchor.constraint(equalTo: gifCatView.bottomAnchor, constant: 8),
            thinkingLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            thinkingLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            thinkingLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
    }
    
    func show(in parentView: UIView) {
        alpha = 0
        parentView.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: parentView.topAnchor),
            leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            bottomAnchor.constraint(equalTo: parentView.bottomAnchor)
        ])
        
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1
        }
    }
    
    func hide() {
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
        }) { _ in
            self.removeFromSuperview()
        }
    }
}

// UITableViewCell을 위한 간단한 커스텀 셀 (Todo 내용을 표시)
class TodoTableViewCell: UITableViewCell {
    static let identifier = "TodoTableViewCell"
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier) // .subtitle 스타일 사용
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with todo: TodoItem) {
        textLabel?.text = todo.title
        detailTextLabel?.text = todo.dueDateString // 마감 시간 표시
        accessoryType = todo.isCompleted ? .checkmark : .none
        textLabel?.alpha = todo.isCompleted ? 0.5 : 1.0 // 완료 시 투명도 조절
        detailTextLabel?.alpha = todo.isCompleted ? 0.5 : 1.0
    }
}

// AddEditTodoDelegate 채택
class TodoCalendarViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, AddEditTodoDelegate {
    
    private var emotionCalendarVC: EmotionCalendarViewController!
    private weak var tableView: UITableView!
    private weak var overallAdviceButtonContainer: UIView!
    private weak var overallAdviceButton: UIButton!
    private weak var overallAdviceActivityIndicator: UIActivityIndicatorView!
    
    private var selectedDateTodos: [TodoItem] = []
    private var selectedDate: Date = Date()
    private var selectedDateDiary: EmotionDiary? // 선택된 날짜의 감정 일기 저장
    private var diaryDataForCalendar: [String: EmotionDiary] = [:]
    private var tableTopTempConstraint: NSLayoutConstraint?
    
    // 🆕 로딩 오버레이 뷰
    private var loadingOverlay: LoadingOverlayView?
    
    // 섹션 정의
    private enum CalendarSection: Int, CaseIterable {
        case diary = 0
        case todos = 1
    }
    
    // 새 탭 요구사항: 할 일 탭에서는 일기 섹션을 숨김
    public var hideDiarySection: Bool = true
    
    // ✅ Todo 목록 페이지네이션 상태
    private var visibleTodos: [TodoItem] = []
    private var todosOffset: Int = 0
    private let todosPageSize: Int = 20
    private var todosHasMore: Bool = true
    private var isLoadingMoreTodos: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("👍 [TodoCalendarViewController] viewDidLoad() - 🚀 최적화된 초기화 시작")
        
        // 🚀 1단계: 필수 UI만 먼저 설정
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        self.title = "내 일정"
        
        setupEmbeddedCalendar()
        setupTableView()
        
        // 🚀 2단계: 나머지는 백그라운드에서 처리
        Task {
            await performAsyncSetup()
        }
        
        // 🚀 3단계: 오늘 날짜 선택은 즉시 (사용자가 바로 볼 수 있도록)
        let today = Date()
        emotionCalendarVC.calendar?.select(today)
        loadData(for: today)
        
        print("✅ TodoCalendarViewController 필수 UI 설정 완료")
        
        // 할 일 변경 실시간 반영
        NotificationCenter.default.addObserver(self, selector: #selector(handleTodosUpdated), name: .todosUpdated, object: nil)
        // 일기 변경 실시간 반영(embedded calendarOnlyMode는 내부 옵저버를 등록하지 않으므로 부모가 수신)
        NotificationCenter.default.addObserver(self, selector: #selector(handleEmotionDiaryUpdated), name: .emotionDiaryUpdated, object: nil)
    }
    
    // 🚀 성능 최적화: 비동기 설정
    @MainActor
    private func performAsyncSetup() async {
        // ⚠️ 크래시 방지: Main Thread에서 직접 처리
        setupAddTodoButtonArea()
        setupOverallAdviceButtonArea()
        setupEmptyStateView()
        
        updateOverallAdviceButtonUI()
        
        // 🔧 Advice 버튼 설정 완료 후 테이블뷰 constraint 업데이트
        updateTableViewConstraints()
        
        print("✅ TodoCalendarViewController 백그라운드 설정 완료")
    }
    
    // 🔧 안전한 셀 등록 메서드
    private func registerTableViewCells() {
        guard let tableView = tableView else {
            print("⚠️ [TodoCalendarViewController] tableView가 nil입니다")
            return
        }
        
        // EmotionDiaryDisplayCell 등록 전 중복 등록 방지
        tableView.register(EmotionDiaryDisplayCell.self, forCellReuseIdentifier: EmotionDiaryDisplayCell.identifier)
        tableView.separatorStyle = .none
        
        print("✅ [TodoCalendarViewController] 테이블뷰 셀 등록 완료")
    }
    
    private func setupEmbeddedCalendar() {
        let child = EmotionCalendarViewController()
        child.calendarOnlyMode = true
        child.onDateSelected = { [weak self] date in
            self?.loadData(for: date)
        }
        addChild(child)
        view.addSubview(child.view)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            child.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
            child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            child.view.heightAnchor.constraint(equalToConstant: 300)
        ])
        child.didMove(toParent: self)
        self.emotionCalendarVC = child
    }
    
    private func setupOverallAdviceButtonArea() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        self.overallAdviceButtonContainer = container
        
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(didTapOverallAdviceButton), for: .touchUpInside)
        container.addSubview(button)
        self.overallAdviceButton = button
        
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        indicator.color = .white
        container.addSubview(indicator)
        self.overallAdviceActivityIndicator = indicator
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: addTodoButtonContainer?.bottomAnchor ?? emotionCalendarVC.view.bottomAnchor, constant: 12),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            container.heightAnchor.constraint(equalToConstant: 50),
            
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            indicator.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
    }
    
    private func setupTableView() {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(TodoTableViewCell.self, forCellReuseIdentifier: TodoTableViewCell.identifier)
        tableView.register(EmotionDiaryDisplayCell.self, forCellReuseIdentifier: EmotionDiaryDisplayCell.identifier)
        tableView.separatorStyle = .none
        
        self.view.addSubview(tableView)
        self.tableView = tableView
        
        // 임시 Top 제약(후에 updateTableViewConstraints에서 해제됨)
        tableTopTempConstraint = tableView.topAnchor.constraint(equalTo: emotionCalendarVC.view.bottomAnchor, constant: 60)
        NSLayoutConstraint.activate([
            tableTopTempConstraint!,
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    // 🔧 Advice 버튼 영역 설정 완료 후 constraint 업데이트
    private func updateTableViewConstraints() {
        guard let tableView = tableView, let container = overallAdviceButtonContainer else { return }
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.deactivate(tableView.constraints)
        if let c = tableTopTempConstraint { c.isActive = false; tableTopTempConstraint = nil }
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: container.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    // MARK: - [+ Todo] 버튼 영역
    private weak var addTodoButtonContainer: UIView?
    private weak var addTodoButton: UIButton?
    
    private func setupAddTodoButtonArea() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        self.addTodoButtonContainer = container
        
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.setTitle("+ Todo", for: .normal)
        // 큰 파란 버튼 스타일로 통일
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(didTapAddButton), for: .touchUpInside)
        container.addSubview(button)
        self.addTodoButton = button
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: emotionCalendarVC.view.bottomAnchor, constant: 16),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            container.heightAnchor.constraint(equalToConstant: 50),
            
            // 큰 버튼로 컨테이너를 가득 채움
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
    }
    
    private func loadData(for date: Date) {
        selectedDate = date
        
        // 할 일 로드
        selectedDateTodos = TodoManager.shared.getTodos(for: date)
        
        // 감정 일기 로드
        let allDiaries = SettingsManager.shared.loadEmotionDiary()
        selectedDateDiary = allDiaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
        // 달력 이모지 표기를 위한 맵 구성
        diaryDataForCalendar.removeAll()
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        for d in allDiaries { diaryDataForCalendar[df.string(from: d.date)] = d }
        
        // 페이지네이션 초기화
        resetTodosPaginationAndReload()
        
        emotionCalendarVC?.calendar?.reloadData() // 이벤트 업데이트
        updateEmptyStateLabelVisibility()
        
        // 수정: 문자열 보간 안전화
        let locale = Locale(identifier: "ko_KR")
        let dateDesc = date.description(with: locale)
        let diaryState = (selectedDateDiary != nil) ? "있음" : "없음"
        print("선택된 날짜 \(dateDesc): 할 일 \(selectedDateTodos.count)개, 일기 \(diaryState)")
        updateOverallAdviceButtonUI()
    }
    
    private func resetTodosPaginationAndReload() {
        todosOffset = 0
        isLoadingMoreTodos = false
        todosHasMore = true
        visibleTodos.removeAll()
        loadMoreTodosIfNeeded(force: true)
        tableView?.reloadData()
    }
    
    private func loadMoreTodosIfNeeded(force: Bool = false) {
        guard force || (!isLoadingMoreTodos && todosHasMore) else { return }
        isLoadingMoreTodos = true
        let start = todosOffset
        let end = min(selectedDateTodos.count, todosOffset + todosPageSize)
        if start < end {
            let nextSlice = Array(selectedDateTodos[start..<end])
            let insertStartIndex = visibleTodos.count
            visibleTodos.append(contentsOf: nextSlice)
            todosOffset = end
            todosHasMore = todosOffset < selectedDateTodos.count
            
            // 부분 삽입
            var indexPaths: [IndexPath] = []
            if hideDiarySection {
                for i in 0..<nextSlice.count { indexPaths.append(IndexPath(row: insertStartIndex + i, section: 0)) }
            } else {
                // todos 섹션은 1번 섹션
                for i in 0..<nextSlice.count { indexPaths.append(IndexPath(row: insertStartIndex + i, section: CalendarSection.todos.rawValue)) }
            }
            tableView?.reloadData()
        } else {
            todosHasMore = false
        }
        isLoadingMoreTodos = false
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .todosUpdated, object: nil)
        NotificationCenter.default.removeObserver(self, name: .emotionDiaryUpdated, object: nil)
    }
    
    @objc private func handleTodosUpdated() {
        loadData(for: selectedDate)
        emotionCalendarVC?.calendar?.reloadData()
        tableView?.reloadData()
    }
    
    @objc private func handleEmotionDiaryUpdated() {
        // 일기 CRUD 변동 시 달력 이모지/점 갱신 및 상단 상태 갱신
        loadData(for: selectedDate)
        emotionCalendarVC?.calendar?.reloadData()
        tableView?.reloadData()
    }
    
    @objc private func didTapAddButton() {
        let addEditVC = AddEditTodoViewController()
        addEditVC.delegate = self
        let navController = UINavigationController(rootViewController: addEditVC)
        present(navController, animated: true, completion: nil)
    }
    
    
    
    
    // 연속 일정 관련 헬퍼 메서드들
    private func isEventStartDate(_ todo: TodoItem, date: Date) -> Bool {
        return Calendar.current.isDate(todo.dueDate, inSameDayAs: date)
    }
    
    private func isEventEndDate(_ todo: TodoItem, date: Date) -> Bool {
        guard let endDate = todo.endDate else { return false }
        return Calendar.current.isDate(endDate, inSameDayAs: date)
    }
    
    private func isDateInEventRange(_ todo: TodoItem, date: Date) -> Bool {
        guard let endDate = todo.endDate else { return false }
        
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: todo.dueDate)
        let endDay = calendar.startOfDay(for: endDate)
        let checkDay = calendar.startOfDay(for: date)
        
        return checkDay >= startDay && checkDay <= endDay
    }
    
    private func priorityColor(for priority: Int) -> UIColor {
        switch priority {
        case 2: return .systemRed      // 높음
        case 1: return .systemOrange   // 보통
        default: return .systemBlue    // 낮음
        }
    }
    
    // MARK: - UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return hideDiarySection ? 1 : CalendarSection.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let currentSection = CalendarSection(rawValue: section) else {
            print("⚠️ [TodoCalendarViewController] numberOfRowsInSection - 잘못된 섹션: \(section)")
            return 0
        }
        
        if hideDiarySection {
            return visibleTodos.count
        } else {
            switch currentSection {
            case .diary:
                let count = selectedDateDiary != nil ? 1 : 0
                print("📊 [TodoCalendarViewController] diary section row count: \(count)")
                return count
            case .todos:
                let count = visibleTodos.count
                print("📊 [TodoCalendarViewController] todos section row count: \(count)")
                return count
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if hideDiarySection == false, let currentSection = CalendarSection(rawValue: indexPath.section), currentSection == .diary {
            // 🔧 안전한 셀 dequeue 및 유효성 검사
            guard let diary = selectedDateDiary else {
                print("⚠️ [TodoCalendarViewController] selectedDateDiary가 nil입니다")
                return UITableViewCell()
            }
            
            guard let cell = tableView.dequeueReusableCell(withIdentifier: EmotionDiaryDisplayCell.identifier, for: indexPath) as? EmotionDiaryDisplayCell else {
                print("⚠️ [TodoCalendarViewController] EmotionDiaryDisplayCell dequeue 실패")
                return UITableViewCell()
            }
            
            cell.configure(with: diary)
            cell.selectionStyle = .none // 일기 셀은 선택 스타일 없음
            return cell
            
        }
        // todos 섹션
        // 🔧 안전한 배열 접근
        guard indexPath.row < visibleTodos.count else {
            print("⚠️ [TodoCalendarViewController] visibleTodos 배열 범위 초과: \(indexPath.row)/\(visibleTodos.count)")
            return UITableViewCell()
        }
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TodoTableViewCell.identifier, for: indexPath) as? TodoTableViewCell else {
            print("⚠️ [TodoCalendarViewController] TodoTableViewCell dequeue 실패")
            return UITableViewCell()
        }
        
        let todo = visibleTodos[indexPath.row]
        cell.configure(with: todo)
        return cell
        
    }
    
    // ✅ 무한스크롤 트리거: 하단 근접 시 다음 페이지 로드
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // diary 섹션 제외
        if !hideDiarySection, indexPath.section == CalendarSection.diary.rawValue { return }
        let threshold = max(0, visibleTodos.count - 3)
        if indexPath.row >= threshold {
            loadMoreTodosIfNeeded()
        }
    }
    
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if hideDiarySection || CalendarSection(rawValue: indexPath.section) == .todos {
            guard indexPath.row < visibleTodos.count else { return }
            let todoItem = visibleTodos[indexPath.row]
            presentAdviceInfo(for: todoItem)
        } else if CalendarSection(rawValue: indexPath.section) == .diary, let diary = selectedDateDiary {
            print("감정 일기 셀 선택됨: \(diary.userMessage)")
            // DiaryWriteViewController를 수정 모드로 열기
            let diaryWriteVC = DiaryWriteViewController()
            diaryWriteVC.diaryToEdit = diary // 수정할 일기 전달
            diaryWriteVC.isModalInPresentation = true // iOS 13+ 아래로 스와이프해서 닫히지 않도록
            // 네비게이션 컨트롤러에 감싸서 표시 (타이틀, 저장/취소 버튼 등)
            let navController = UINavigationController(rootViewController: diaryWriteVC)
            present(navController, animated: true, completion: nil)
        }
        loadData(for: selectedDate)
        updateOverallAdviceButtonUI()
    }
    
    // 최근 AI 조언 정보창 표시 (없으면 생성 유도)
    private func presentAdviceInfo(for todo: TodoItem) {
        if let advice = todo.aiAdvices?.last, !advice.isEmpty {
            self.showAdvice(title: "💡 \(todo.title)", advice: advice)
        } else {
            let alert = UIAlertController(title: "조언 없음", message: "이 할 일에 대한 저장된 조언이 없습니다. 지금 받을까요?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "취소", style: .cancel))
            alert.addAction(UIAlertAction(title: "조언 받기", style: .default, handler: { [weak self] _ in
                self?.requestTodoAdvice(for: todo)
            }))
            present(alert, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return hideDiarySection ? true : CalendarSection(rawValue: indexPath.section) == .todos
    }
    
    // 🆕 스와이프 액션 설정 (조언 기능 추가) - 통합 횟수 관리
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let isTodosSection = hideDiarySection || CalendarSection(rawValue: indexPath.section) == .todos
        guard isTodosSection else { return nil }
        guard indexPath.row < visibleTodos.count else { return nil }
        let todo = visibleTodos[indexPath.row]
        
        // ✏️ 수정 액션
        let editAction = UIContextualAction(style: .normal, title: "수정") { [weak self] (_, _, completion) in
            self?.presentEditTodo(todo)
            completion(true)
        }
        editAction.backgroundColor = UIColor.systemBlue
        editAction.image = UIImage(systemName: "pencil")
        
        // 🗑️ 삭제 액션
        let deleteAction = UIContextualAction(style: .destructive, title: "삭제") { [weak self] (_, _, completion) in
            self?.deleteTodoById(todo.id)
            completion(true)
        }
        deleteAction.image = UIImage(systemName: "trash.fill")
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, editAction])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard (hideDiarySection || CalendarSection(rawValue: indexPath.section) == .todos), editingStyle == .delete else { return }
        guard indexPath.row < visibleTodos.count else { return }
        let todoToDelete = visibleTodos[indexPath.row]
        deleteTodoById(todoToDelete.id)
    }
    
    private func deleteTodoById(_ id: UUID) {
        TodoManager.shared.deleteTodo(withId: id) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if success {
                    // 원본 목록 갱신
                    self.selectedDateTodos.removeAll { $0.id == id }
                    // 페이지네이션 다시 구성
                    self.resetTodosPaginationAndReload()
                    
                    self.emotionCalendarVC?.calendar?.reloadData()
                    self.updateEmptyStateLabelVisibility()
                    self.updateOverallAdviceButtonUI()
                    
                    if let error = error {
                        self.handleTodoManagerError(error, forAction: "삭제 (부분 성공)")
                    }
                } else if let error = error {
                    self.handleTodoManagerError(error, forAction: "삭제")
                } else {
                    self.showAlert(title: "오류", message: "할 일 삭제 중 알 수 없는 오류가 발생했습니다.")
                }
            }
        }
    }
    
    // MARK: - 편집 화면 표시
    private func presentEditTodo(_ todo: TodoItem) {
        let addEditVC = AddEditTodoViewController()
        addEditVC.todoItem = todo
        addEditVC.delegate = self
        let nav = UINavigationController(rootViewController: addEditVC)
        present(nav, animated: true)
    }
    
    // MARK: - AddEditTodoDelegate
    func didSaveTodoItem(_ todoItem: TodoItem) {
        // 저장/삭제 등 변경사항 반영
        loadData(for: selectedDate)
        emotionCalendarVC?.calendar?.reloadData()
        tableView?.reloadData()
        updateOverallAdviceButtonUI()
    }
    
    // MARK: - Error Handling
    private func handleTodoManagerError(_ error: Error, forAction action: String) {
        _ = error as NSError // nsError 미사용
        var message = "할 일 \(action) 중 오류 발생: \(error.localizedDescription)"
        let recoverySuggestion: String? = (error as? TodoManagerError)?.recoverySuggestion
        var alertTitle = "오류"
        
        if let todoError = error as? TodoManagerError {
            alertTitle = "캘린더 연동 오류"
            switch todoError {
            case .calendarAccessDenied(let specificMessage),
                    .calendarAccessRestricted(let specificMessage),
                    .calendarWriteOnlyAccess(let specificMessage),
                    .unknownCalendarAuthorization(let specificMessage):
                message = specificMessage
            case .eventSaveFailed, .eventRemoveFailed, .eventFetchFailed:
                message = todoError.localizedDescription
            }
        }
        
        let alert = UIAlertController(title: alertTitle, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        
        if recoverySuggestion != nil && recoverySuggestion?.contains("설정") == true {
            alert.addAction(UIAlertAction(title: "설정으로 이동", style: .default, handler: { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }))
        }
        present(alert, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    // 조언 표시를 위한 새로운 메서드
    private func showAdvice(title: String, advice: String) {
        // 🔧 다시 alert 사용 (간단하고 안정적)
        let alert = UIAlertController(title: title, message: advice, preferredStyle: .alert)
        
        // 복사 기능 추가
        let copyAction = UIAlertAction(title: "📋 복사하기", style: .default) { _ in
            UIPasteboard.general.string = advice
            // 복사 완료 알림
            let copyAlert = UIAlertController(title: "✅ 복사됨", message: "조언이 클립보드에 복사되었습니다.", preferredStyle: .alert)
            copyAlert.addAction(UIAlertAction(title: "확인", style: .default))
            self.present(copyAlert, animated: true)
        }
        
        let closeAction = UIAlertAction(title: "닫기", style: .default)
        
        alert.addAction(copyAction)
        alert.addAction(closeAction)
        present(alert, animated: true)
    }
    
    // MARK: - UI/UX Enhancements (Empty State, Calendar Dots, Diary Action)
    private var emptyStateLabel: UILabel? // 빈 화면 메시지 레이블
    
    private func setupEmptyStateView() {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.isHidden = true
        tableView.backgroundView = label
        emptyStateLabel = label
    }
    
    // 수정: 함수 이름 변경 및 tableView.reloadData() 호출 제거
    private func updateEmptyStateLabelVisibility() {
        let hasData = (selectedDateDiary != nil || !selectedDateTodos.isEmpty)
        if hasData {
            emptyStateLabel?.isHidden = true
        } else {
            let messages = [
                "오늘의 특별한 계획을 세워볼까요? ✨",
                "오늘은 어떤 즐거운 기록을 남겨볼까요? 📝",
                "하루를 멋지게 계획하고 기록해보세요!",
                "반짝이는 하루를 만들어봐요! 🚀"
            ]
            emptyStateLabel?.text = messages.randomElement() ?? "데이터가 없습니다."
            emptyStateLabel?.isHidden = false
        }
        // tableView.reloadData() // 여기서 호출하지 않음
    }
    
    // MARK: - AI Overall Advice Button Actions (New)
    private func updateOverallAdviceButtonUI() {
        // 🔧 크래시 수정: UI 요소가 아직 초기화되지 않았을 수 있음
        guard let adviceButton = overallAdviceButton,
              let adviceIndicator = overallAdviceActivityIndicator else {
            print("⚠️ [TodoCalendar] 아직 UI 요소가 초기화되지 않음")
            return
        }
        
        let remainingCount = AIUsageManager.shared.getRemainingCount(for: .overallTodoAdvice)
        adviceButton.setTitle("오늘의 전체 조언 보기 (\(remainingCount)회 남음)", for: .normal)
        adviceButton.setTitleColor(.white, for: .normal)
        adviceButton.isEnabled = remainingCount > 0
        if adviceIndicator.isAnimating {
            adviceButton.setTitle("", for: .normal) // 로딩 중에는 텍스트 숨김
        }
    }
    
    @objc private func didTapOverallAdviceButton() {
        guard AIUsageManager.shared.getRemainingCount(for: .overallTodoAdvice) > 0 else {
            showAlert(title: "알림", message: "오늘 사용할 수 있는 전체 할 일 조언 횟수를 모두 사용했습니다.")
            return
        }
        
        guard !selectedDateTodos.isEmpty else {
            showAlert(title: "알림", message: "선택된 날짜에 할 일이 없어 전체 조언을 받을 수 없습니다.")
            return
        }
        
        Task {
            let promptContent = await buildComprehensivePrompt()
            // ✅ AI 조언 요청 로직 통합
            requestTaskAdvice(for: promptContent, title: "✨ 오늘의 전체 조언 ✨", usageType: AIFeatureType.overallTodoAdvice)
        }
    }
    
    // MARK: -  symptômes 할 일 개별/전체 조언 요청 통합 (Root Cause: Context-related mode override)
    private func requestTaskAdvice(for content: String, title: String, usageType: AIFeatureType, todoItem: TodoItem? = nil) {
        // 🛡️ 사용량 체크
        guard AIUsageManager.shared.getRemainingCount(for: usageType) > 0 else {
            let message = (usageType == .overallTodoAdvice) ? "오늘 사용할 수 있는 전체 할 일 조언 횟수를 모두 사용했습니다." : "오늘 사용할 수 있는 개별 할 일 조언 횟수를 모두 사용했습니다."
            showAlert(title: "알림", message: message)
            return
        }
        
        // 🛡️ 개별 할 일의 경우, 아이템별 제한 추가 체크
        if let todo = todoItem, !todo.canReceiveAdvice {
            showAlert(title: "알림", message: "이 할 일에 대한 조언을 모두 사용했습니다. (\(todo.adviceUsageText))")
            return
        }
        
        // 🎨 UI 로딩 상태 시작
        loadingOverlay = LoadingOverlayView()
        loadingOverlay?.show(in: view)
        if usageType == .overallTodoAdvice {
            overallAdviceButton.setTitle("", for: .normal)
            overallAdviceActivityIndicator.startAnimating()
            overallAdviceButton.isEnabled = false
        }
        
        Task {
            do {
                // 🤖 UnifiedAIServiceImpl 직접 호출하여 Context 오염 방지
                let response = try await UnifiedAIServiceImpl.shared.sendMessage(
                    content: content,
                    model: .gemini, // 범용성이 좋은 Gemini 모델로 지정
                    mode: .taskAdvice, // ✅ 핵심: 조언 모드 명시적 지정
                    context: nil, // 독립적인 요청이므로 context 불필요
                    tokenConfig: nil
                )
                let advice = response.content
                
                await MainActor.run {
                    // 💾 사용량 기록 및 데이터 업데이트
                    AIUsageManager.shared.recordUsage(for: usageType)
                    
                    // ✅ 대나무숲 저장을 위한 메시지 생성 및 저장
                    let sessionId = SessionManager.shared.getCurrentSessionId()
                    let userRequestContent = (usageType == .overallTodoAdvice) ? "오늘의 전체 할 일에 대한 조언을 요청했습니다." : "'\(todoItem?.title ?? "")'에 대한 조언을 요청했습니다."
                    
                    let userMessage = StoredChatMessage(id: UUID().uuidString, timestamp: Date(), role: "user", content: userRequestContent, type: .text)
                    let aiMessage = StoredChatMessage(id: UUID().uuidString, timestamp: Date(), role: "assistant", content: advice, type: .text)
                    
                    SessionManager.shared.addChatMessageSafely(to: sessionId, message: userMessage)
                    SessionManager.shared.addChatMessageSafely(to: sessionId, message: aiMessage)
                    
                    if let todo = todoItem {
                        TodoManager.shared.appendAdvice(to: todo.id, advice: advice)
                        if var updatedTodo = self.selectedDateTodos.first(where: { $0.id == todo.id }) {
                            updatedTodo.requestAdvice()
                            TodoManager.shared.updateTodo(updatedTodo) { _,_ in }
                        }
                        self.loadData(for: self.selectedDate) // 데이터 리로드로 UI 갱신
                    }
                    
                    // 🎨 UI 로딩 상태 종료 및 결과 표시
                    self.loadingOverlay?.hide()
                    self.loadingOverlay = nil
                    if usageType == .overallTodoAdvice {
                        self.overallAdviceActivityIndicator.stopAnimating()
                        self.updateOverallAdviceButtonUI()
                    }
                    
                    self.showAdvice(title: title, advice: advice)
                }
                
            } catch {
                await MainActor.run {
                    // 🎨 UI 로딩 상태 종료
                    self.loadingOverlay?.hide()
                    self.loadingOverlay = nil
                    if usageType == .overallTodoAdvice {
                        self.overallAdviceActivityIndicator.stopAnimating()
                        self.updateOverallAdviceButtonUI()
                    }
                    
                    // ⚠️ 오류 처리
                    let errorMessage = error.localizedDescription.contains("일일 사용 한도") ? error.localizedDescription : "AI 조언을 받아오는 데 실패했습니다. (\(error.localizedDescription))"
                    self.showAlert(title: "AI 조언 오류", message: errorMessage)
                }
            }
        }
    }
    
    // MARK: - 종합 프롬프트 생성
    private func buildComprehensivePrompt() async -> String {
        let weekly = SessionManager.shared.buildRichContextForLocalAI().emotionHistory.first?.emotion
        let all = TodoManager.shared.loadTodos()
        return Self.buildOverallAdvicePrompt(date: selectedDate,
                                             todos: selectedDateTodos,
                                             allTodos: all,
                                             weeklyContext: weekly)
    }
    
    // MARK: - 공통화된 날짜별 전체 조언 프롬프트 (DRY)
    static func buildOverallAdvicePrompt(date: Date,
                                         todos: [TodoItem],
                                         allTodos: [TodoItem],
                                         weeklyContext: String?) -> String {
        let currentTime = Date()
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "yyyy년 MM월 dd일 HH시 mm분"
        let currentTimeString = timeFormatter.string(from: currentTime)
        
        let selectedDateFormatter = DateFormatter()
        selectedDateFormatter.dateFormat = "MM월 dd일 (E)"
        selectedDateFormatter.locale = Locale(identifier: "ko_KR")
        let selectedDateString = selectedDateFormatter.string(from: date)
        
        let completedTodos = todos.filter { $0.isCompleted }
        let pendingTodos = todos.filter { !$0.isCompleted }
        let highPriority = todos.filter { $0.priority == 2 }
        let mediumPriority = todos.filter { $0.priority == 1 }
        let lowPriority = todos.filter { $0.priority == 0 }
        let urgentTodos = pendingTodos.filter { $0.dueDate.timeIntervalSince(currentTime) < 24 * 3600 }
        
        var promptContent = """
        📅 대상 날짜: \(selectedDateString)
        🕒 현재 시간: \(currentTimeString)
        
        📊 할 일 현황:
        • 전체 할 일: \(todos.count)개
        • 완료된 할 일: \(completedTodos.count)개
        • 남은 할 일: \(pendingTodos.count)개
        • 긴급한 할 일: \(urgentTodos.count)개 (24시간 이내)
        
        🎯 우선순위별 분류:
        • 높음: \(highPriority.count)개
        • 보통: \(mediumPriority.count)개
        • 낮음: \(lowPriority.count)개
        
        📋 상세 할 일 목록:
        """
        
        // 카테고리·우선순위·시간(간편등록 시 '오늘 중 (시간관계없음)') 포함 표기
        let sortedTodos = todos.sorted { $0.priority > $1.priority }
        for (index, todo) in sortedTodos.enumerated() {
            let statusEmoji = todo.isCompleted ? "✅" : "⏳"
            let urgentMark = urgentTodos.contains(where: { $0.id == todo.id }) ? " 🔥" : ""
            let maskedTitle = SettingsManager.shared.maskPIIForExport(todo.title)
            let maskedNotes = todo.notes.map { SettingsManager.shared.maskPIIForExport($0) }
            let priorityText = ["낮음", "보통", "높음"][todo.priority]
            let categoryText = todo.category?.displayName ?? "미지정"
            
            let cal = Calendar.current
            let startOfDay = cal.startOfDay(for: todo.dueDate)
            let isAllDaySingle = (todo.endDate != nil) && (todo.dueDate == startOfDay) && (cal.startOfDay(for: todo.endDate!) == cal.date(byAdding: .day, value: 1, to: startOfDay))
            let timeText = isAllDaySingle ? "오늘 중 (시간관계없음)" : todo.dueDateString
            
            promptContent += "\n\(index + 1). \(statusEmoji) [\(categoryText)·\(priorityText)] \(maskedTitle) (\(timeText))\(urgentMark)"
            if let notes = maskedNotes, !notes.isEmpty { promptContent += " - 메모: \(notes)" }
        }
        
        // 연속 일정 정보 (끝 경계 배타)
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        var continuousEvents: [String] = []
        for todo in allTodos {
            if let end = todo.endDate {
                let start = calendar.startOfDay(for: todo.dueDate)
                let endDay = calendar.startOfDay(for: end)
                if day >= start && day < endDay {
                    let masked = SettingsManager.shared.maskPIIForExport(todo.title)
                    continuousEvents.append("• \(masked): \(todo.dueDateString) ~ \(DateFormatter.localizedString(from: end, dateStyle: .medium, timeStyle: .short))")
                }
            }
        }
        if !continuousEvents.isEmpty {
            promptContent += "\n\n🗓️ 연속 일정 정보:"
            for info in continuousEvents { promptContent += "\n\(info)" }
        }
        
        if let weekly = weeklyContext, !weekly.isEmpty {
            promptContent += "\n\n사용자 활동 패턴:\n\(weekly)"
        }
        
        promptContent += """
        
        📈 요청사항:
        위 할 일 목록을 종합적으로 분석하여 다음 관점에서 구체적인 조언을 **200자 이내**로 간결하게 해주세요:
        1. 우선순위 조정 및 시간 배분 전략
        2. 효율적인 업무 순서 및 실행 방법
        3. 스트레스 관리 및 동기부여 방안
        
        **중요**: 응답을 200자 이내로 제한하여 모바일 alert에서 잘리지 않도록 해주세요.
        단순한 격려가 아닌, 실제로 실행할 수 있는 구체적인 액션플랜을 제시해주세요.
        """
        
        return promptContent
    }
    
    // MARK: - 개별 할 일 프롬프트 생성
    private func buildIndividualTodoPrompt(for todo: TodoItem) async -> String {
        // 기존 로직을 확장: 카테고리/간편등록 시간 표현 포함
        let currentTime = Date()
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "yyyy년 MM월 dd일 HH시 mm분"
        let currentTimeString = timeFormatter.string(from: currentTime)
        
        let priorityText = ["낮음", "보통", "높음"][todo.priority]
        let statusText = todo.isCompleted ? "완료됨" : "미완료"
        let timeUntilDue = todo.dueDate.timeIntervalSince(currentTime)
        let daysUntilDue = Int(timeUntilDue / (24 * 3600))
        
        var urgencyText = ""
        if timeUntilDue < 0 {
            urgencyText = "마감일이 \(abs(daysUntilDue))일 지났음 (지연됨)"
        } else if timeUntilDue < 24 * 3600 {
            urgencyText = "오늘 마감 (긴급)"
        } else if timeUntilDue < 3 * 24 * 3600 {
            urgencyText = "\(daysUntilDue)일 후 마감 (급함)"
        } else {
            urgencyText = "\(daysUntilDue)일 후 마감"
        }
        
        // 간편등록(하루 종일) 시간 텍스트
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: todo.dueDate)
        let isAllDaySingle = (todo.endDate != nil) && (todo.dueDate == startOfDay) && (cal.startOfDay(for: todo.endDate!) == cal.date(byAdding: .day, value: 1, to: startOfDay))
        let timeText = isAllDaySingle ? "오늘 중 (시간관계없음)" : todo.dueDateString
        
        // 주간 컨텍스트
        let weeklyContext = SessionManager.shared.buildRichContextForLocalAI().emotionHistory.first?.emotion ?? "일반적인 컨텍스트"
        
        var promptContent = """
        🎯 할 일 상세 분석:
        • 제목: \(todo.title)
        • 상태: \(statusText)
        • 카테고리: \(todo.category?.displayName ?? "미지정")
        • 우선순위: \(priorityText)
        • 시간: \(timeText)
        • 긴급도: \(urgencyText)
        • 현재 시간: \(currentTimeString)
        • 조언 횟수: \(todo.adviceRequestCount + 1)/\(todo.maxAdviceCount) (이번이 \(todo.adviceRequestCount + 1)번째)
        """
        
        if let notes = todo.notes, !notes.isEmpty {
            promptContent += "\n• 메모: \(notes)"
        }
        
        promptContent += """
        
        📝 요청사항:
        위 할 일에 대해 다음 관점에서 개인화된 조언을 **150자 이내**로 간결하게 해주세요:
        1. 실행 전략 및 구체적인 첫 번째 액션
        2. 시간 관리 및 효율적인 접근법
        3. 동기부여 및 완료 팁
        
        **중요**: 응답을 150자 이내로 제한하여 모바일 alert에서 잘리지 않도록 해주세요.
        추상적인 격려보다는 실제로 실행할 수 있는 구체적인 방법을 제시해주세요.
        """
        
        return promptContent
    }
    
    // MARK: - 연속 일정 컨텍스트 가져오기
    private func getContinuousEventContext() -> [String] {
        var continuousEvents: [String] = []
        
        let allTodos = TodoManager.shared.loadTodos()
        let rangeEvents = allTodos.filter { todo in
            guard let endDate = todo.endDate, !todo.isCompleted else { return false }
            // 선택된 날짜가 연속 일정 범위에 포함되는지 확인
            return isDateInEventRange(todo, date: selectedDate)
        }
        
        for event in rangeEvents {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            let startStr = formatter.string(from: event.dueDate)
            let endStr = event.endDate != nil ? formatter.string(from: event.endDate!) : ""
            
            let priorityText = ["📌 낮음", "📝 보통", "🔥 높음"][event.priority]
            let eventInfo = "• \(event.title) (\(startStr)~\(endStr)) - \(priorityText)"
            continuousEvents.append(eventInfo)
        }
        
        return continuousEvents
    }
    
    // MARK: - 🆕 할 일 개별 조언 기능 - 통합 횟수 관리
    private func requestTodoAdvice(for todo: TodoItem) {
        Task {
            let promptContent = await buildIndividualTodoPrompt(for: todo)
            // ✅ AI 조언 요청 로직 통합
            requestTaskAdvice(for: promptContent, title: "💡 \(todo.title) 조언", usageType: AIFeatureType.individualTodoAdvice, todoItem: todo)
        }
    }
    
    
    
    
    class SimpleAdviceViewController: UIViewController {
        private let titleText: String
        private let adviceText: String
        
        private let containerView = UIView()
        private let titleLabel = UILabel()
        private let scrollView = UIScrollView()
        private let adviceLabel = UILabel()
        private let buttonStackView = UIStackView()
        private let copyButton = UIButton(type: .system)
        private let closeButton = UIButton(type: .system)
        
        init(titleText: String, adviceText: String) {
            self.titleText = titleText
            self.adviceText = adviceText
            super.init(nibName: nil, bundle: nil)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func viewDidLoad() {
            super.viewDidLoad()
            setupUI()
            configureContent()
        }
        
        private func setupUI() {
            view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            
            // 컨테이너 뷰 설정
            containerView.backgroundColor = .systemBackground
            containerView.layer.cornerRadius = 16
            containerView.layer.shadowColor = UIColor.black.cgColor
            containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
            containerView.layer.shadowOpacity = 0.3
            containerView.layer.shadowRadius = 8
            containerView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(containerView)
            
            // 제목 라벨 설정
            titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
            titleLabel.textColor = .label
            titleLabel.textAlignment = .center
            titleLabel.numberOfLines = 0
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(titleLabel)
            
            // 스크롤뷰 설정
            scrollView.showsVerticalScrollIndicator = true
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(scrollView)
            
            // 조언 라벨 설정
            adviceLabel.font = .systemFont(ofSize: 16)
            adviceLabel.textColor = .label
            adviceLabel.numberOfLines = 0
            adviceLabel.translatesAutoresizingMaskIntoConstraints = false
            scrollView.addSubview(adviceLabel)
            
            // 버튼 스택뷰 설정
            buttonStackView.axis = .horizontal
            buttonStackView.distribution = .fillEqually
            buttonStackView.spacing = 12
            buttonStackView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(buttonStackView)
            
            // 복사 버튼 설정
            copyButton.setTitle("📋 복사하기", for: .normal)
            copyButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
            copyButton.backgroundColor = .systemBlue
            copyButton.setTitleColor(.white, for: .normal)
            copyButton.layer.cornerRadius = 8
            copyButton.addTarget(self, action: #selector(copyAdvice), for: .touchUpInside)
            
            // 닫기 버튼 설정
            closeButton.setTitle("닫기", for: .normal)
            closeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
            closeButton.backgroundColor = .systemGray
            closeButton.setTitleColor(.white, for: .normal)
            closeButton.layer.cornerRadius = 8
            closeButton.addTarget(self, action: #selector(closeAdvice), for: .touchUpInside)
            
            buttonStackView.addArrangedSubview(copyButton)
            buttonStackView.addArrangedSubview(closeButton)
            
            // 제약 조건 설정 (UIScrollView 올바른 오토레이아웃: contentLayoutGuide/frameLayoutGuide 사용)
            NSLayoutConstraint.activate([
                // 컨테이너 뷰
                containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                containerView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
                containerView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
                containerView.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
                containerView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
                containerView.widthAnchor.constraint(lessThanOrEqualToConstant: 380),
                
                // 제목 라벨
                titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
                titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
                titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
                
                // 스크롤뷰
                scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
                scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
                scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
                scrollView.heightAnchor.constraint(lessThanOrEqualToConstant: 400), // 최대 높이 제한
                
                // 조언 라벨 (contentLayoutGuide에 맞춤)
                adviceLabel.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                adviceLabel.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                adviceLabel.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                adviceLabel.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
                adviceLabel.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
                
                // 버튼 스택뷰
                buttonStackView.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 20),
                buttonStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
                buttonStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
                buttonStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),
                buttonStackView.heightAnchor.constraint(equalToConstant: 44)
            ])
        }
        
        private func configureContent() {
            titleLabel.text = titleText
            adviceLabel.text = adviceText
        }
        
        @objc private func copyAdvice() {
            UIPasteboard.general.string = adviceText
            
            // 복사 완료 피드백
            copyButton.setTitle("✅ 복사됨!", for: .normal)
            copyButton.backgroundColor = .systemGreen
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.copyButton.setTitle("📋 복사하기", for: .normal)
                self?.copyButton.backgroundColor = .systemBlue
            }
        }
        
        @objc private func closeAdvice() {
            dismiss(animated: true)
        }
        
        // 배경 터치로 닫기
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            if let touch = touches.first {
                let location = touch.location(in: view)
                if !containerView.frame.contains(location) {
                    dismiss(animated: true)
                }
            }
        }
        
    }
}
