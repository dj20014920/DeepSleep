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
class TodoCalendarViewController: UIViewController, FSCalendarDelegate, FSCalendarDataSource, UITableViewDelegate, UITableViewDataSource, AddEditTodoDelegate {

    private weak var calendar: FSCalendar!
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
    public var hideDiarySection: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        print("👍 [TodoCalendarViewController] viewDidLoad() - 🚀 최적화된 초기화 시작")
        
        // 🚀 1단계: 필수 UI만 먼저 설정
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        self.title = "내 일정"
        
        setupCalendar()
        setupTableView()
        
        // 🚀 2단계: 나머지는 백그라운드에서 처리
        Task {
            await performAsyncSetup()
        }
        
        // 🚀 3단계: 오늘 날짜 선택은 즉시 (사용자가 바로 볼 수 있도록)
        let today = Date()
        calendar.select(today)
        loadData(for: today)
        
        print("✅ TodoCalendarViewController 필수 UI 설정 완료")

        // 할 일 변경 실시간 반영
        NotificationCenter.default.addObserver(self, selector: #selector(handleTodosUpdated), name: .todosUpdated, object: nil)
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
    
    private func setupCalendar() {
        let calendar = FSCalendar(frame: .zero)
        calendar.translatesAutoresizingMaskIntoConstraints = false
        calendar.dataSource = self
        calendar.delegate = self
        
        // 캘린더 셀: EmotionCalendarViewController와 동일한 셀 사용(이모지+그라데이션 링)
        calendar.register(EmotionCalendarDayCell.self, forCellReuseIdentifier: "EmotionCalendarDayCell")
        
        calendar.appearance.headerDateFormat = "yyyy년 MM월"
        calendar.appearance.weekdayTextColor = .label
        calendar.appearance.headerTitleColor = .label
        calendar.appearance.titleDefaultColor = .label
        calendar.appearance.titleWeekendColor = .label
        // 기본 하이라이트(선택/오늘) 원 제거
        calendar.appearance.titleTodayColor = .label
        calendar.appearance.todayColor = .clear
        calendar.appearance.selectionColor = .clear
        calendar.appearance.borderSelectionColor = .clear
        calendar.appearance.titleSelectionColor = .label
        calendar.appearance.eventDefaultColor = .systemGreen
        calendar.backgroundColor = .systemBackground
        calendar.locale = Locale(identifier: "en_US")
        // EmotionCalendarViewController와 동일하게 이전/다음 달 날짜도 표시(흐릿하게)
        calendar.placeholderType = .fillSixRows

        self.view.addSubview(calendar)
        self.calendar = calendar

        NSLayoutConstraint.activate([
            calendar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
            calendar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            calendar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
            calendar.heightAnchor.constraint(equalToConstant: 300)
        ])
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
            container.topAnchor.constraint(equalTo: addTodoButtonContainer?.bottomAnchor ?? calendar.bottomAnchor, constant: 12),
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
        tableTopTempConstraint = tableView.topAnchor.constraint(equalTo: calendar.bottomAnchor, constant: 60)
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
            container.topAnchor.constraint(equalTo: calendar.bottomAnchor, constant: 16),
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
        
        calendar.reloadData() // 이벤트 점 표시 업데이트
        
        // 수정: updateEmptyStateView -> updateEmptyStateLabelVisibility 호출 후 tableView.reloadData() 명시적 호출
        updateEmptyStateLabelVisibility() 
        tableView.reloadData() // 데이터 로드 후 테이블 전체 새로고침

        // 수정: 문자열 보간 오류 수정
        print("선택된 날짜 \(date.description(with: Locale(identifier: "ko_KR"))): 할 일 \(selectedDateTodos.count)개, 일기 \(selectedDateDiary != nil ? "있음" : "없음")")
        updateOverallAdviceButtonUI()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .todosUpdated, object: nil)
    }

    @objc private func handleTodosUpdated() {
        loadData(for: selectedDate)
        calendar?.reloadData()
        tableView?.reloadData()
    }
    
    @objc private func didTapAddButton() {
        let addEditVC = AddEditTodoViewController()
        addEditVC.delegate = self
        let navController = UINavigationController(rootViewController: addEditVC)
        present(navController, animated: true, completion: nil)
    }

    // MARK: - FSCalendarDataSource
    func calendar(_ calendar: FSCalendar, numberOfEventsFor date: Date) -> Int {
        // EmotionCalendarViewController와 동일: 일기가 있는 날짜만 1점 표시
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let key = df.string(from: date)
        return diaryDataForCalendar[key] != nil ? 1 : 0
    }

    // MARK: - FSCalendarDelegateAppearance (For Dot Colors)
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, eventDefaultColorsFor date: Date) -> [UIColor]? {
        // EmotionCalendarViewController와 동일: 기본 색상(.systemGreen) 사용
        return nil
    }

    // 선택된 날짜의 이벤트 점 색상 (선택사항)
    // func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, eventSelectionColorsFor date: Date) -> [UIColor]? {
    //     return appearance.eventDefaultColorsFor(date) // 기본 색상과 동일하게 유지 또는 다르게 설정
    // }

    // MARK: - FSCalendarDelegate
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        // 사용자가 캘린더에서 날짜를 직접 선택했을 때만 페이지 이동 고려
        if monthPosition == .current {
            loadData(for: date)
        } else {
            // 다른 달의 날짜를 선택하면 해당 월로 캘린더를 부드럽게 이동
            // 이 때, 이동 후 자동으로 didSelect가 다시 호출되지는 않으므로, 여기서 loadData도 호출.
            calendar.setCurrentPage(date, animated: true)
            loadData(for: date) // 페이지 이동 후 데이터 로드
        }
        updateOverallAdviceButtonUI()
    }
    
    // EmotionCalendar와 동일한 셀(이모지+그라데이션 링) 적용
    func calendar(_ calendar: FSCalendar, cellFor date: Date, at position: FSCalendarMonthPosition) -> FSCalendarCell {
        let cell = calendar.dequeueReusableCell(withIdentifier: "EmotionCalendarDayCell", for: date, at: position) as! EmotionCalendarDayCell
        // 오늘 표시: 우상단 모서리 접힘 마크
        cell.setTodayCornerVisible(Calendar.current.isDate(date, inSameDayAs: Date()))
        let todos = TodoManager.shared.getTodos(for: date)
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

    // 날짜 타이틀(이모지) 표시: EmotionCalendar와 동일 로직
    func calendar(_ calendar: FSCalendar, titleFor date: Date) -> String? {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        if let diary = diaryDataForCalendar[df.string(from: date)] {
            return CommonUtilities.shared.mapEmotionToEmoji(diary.selectedEmotion)
        }
        return nil
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
            return selectedDateTodos.count
        } else {
            switch currentSection {
            case .diary:
                let count = selectedDateDiary != nil ? 1 : 0
                print("📊 [TodoCalendarViewController] diary section row count: \(count)")
                return count
            case .todos:
                let count = selectedDateTodos.count
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
            guard indexPath.row < selectedDateTodos.count else {
                print("⚠️ [TodoCalendarViewController] todos 배열 범위 초과: \(indexPath.row)/\(selectedDateTodos.count)")
                return UITableViewCell()
            }
            
            guard let cell = tableView.dequeueReusableCell(withIdentifier: TodoTableViewCell.identifier, for: indexPath) as? TodoTableViewCell else {
                print("⚠️ [TodoCalendarViewController] TodoTableViewCell dequeue 실패")
                return UITableViewCell()
            }
            
            let todo = selectedDateTodos[indexPath.row]
            cell.configure(with: todo)
            return cell
        
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let currentSection = CalendarSection(rawValue: section) else { return nil }
        
        if hideDiarySection { return selectedDateTodos.isEmpty ? "📌 할 일 (없음)" : "📌 할 일 목록" }
        switch currentSection {
        case .diary:
            return selectedDateDiary != nil ? "💭 그날의 감정 기록" : nil
        case .todos:
            return selectedDateTodos.isEmpty && selectedDateDiary == nil ? nil : (selectedDateTodos.isEmpty ? "📌 할 일 (없음)" : "📌 할 일 목록")
        }
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if hideDiarySection || CalendarSection(rawValue: indexPath.section) == .todos {
            let todoItem = selectedDateTodos[indexPath.row]
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
        return CalendarSection(rawValue: indexPath.section) == .todos
    }
    
    // 🆕 스와이프 액션 설정 (조언 기능 추가) - 통합 횟수 관리
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard CalendarSection(rawValue: indexPath.section) == .todos else { return nil }
        
        let todo = selectedDateTodos[indexPath.row]
        
        // 🛡️ 조언 액션 - 할 일별 횟수 체크
        let canReceiveAdvice = todo.canReceiveAdvice
        let adviceTitle = canReceiveAdvice ? "조언\n(\(todo.adviceUsageText))" : "조언 완료"
        
        let adviceAction = UIContextualAction(style: .normal, title: adviceTitle) { [weak self] (action, view, completionHandler) in
            guard canReceiveAdvice else {
                self?.showAlert(title: "알림", message: "이 할 일에 대한 조언을 모두 사용했습니다. (\(todo.adviceUsageText))")
                completionHandler(false)
                return
            }
            
            self?.requestTodoAdvice(for: todo)
            completionHandler(true)
        }
        
        // 🛡️ 조언 가능 여부에 따른 시각적 피드백
        if canReceiveAdvice {
            adviceAction.backgroundColor = UIColor.systemBlue
            adviceAction.image = UIImage(systemName: "lightbulb.fill")
        } else {
            adviceAction.backgroundColor = UIColor.systemGray
            adviceAction.image = UIImage(systemName: "checkmark.circle.fill")
        }
        
        // 삭제 액션
        let deleteAction = UIContextualAction(style: .destructive, title: "삭제") { [weak self] (action, view, completionHandler) in
            self?.deleteTodo(at: indexPath)
            completionHandler(true)
        }
        deleteAction.image = UIImage(systemName: "trash.fill")
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, adviceAction])
        configuration.performsFirstActionWithFullSwipe = false // 전체 스와이프로 자동 삭제 방지
        return configuration
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard CalendarSection(rawValue: indexPath.section) == .todos, editingStyle == .delete else { return }
        
        let todoToDelete = selectedDateTodos[indexPath.row] // 삭제할 아이템 미리 참조
        
        TodoManager.shared.deleteTodo(withId: todoToDelete.id) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if success {
                    // 1. 데이터 소스 업데이트 (배열에서 아이템 제거)
                    // indexPath.row 대신 todoToDelete.id로 다시 찾는 것이 더 안전할 수 있으나,
                    // commit editingStyle의 indexPath는 삭제 직전의 유효한 인덱스여야 함.
                    // 만약 selectedDateTodos가 다른 곳에서 동시에 변경될 가능성이 있다면 id로 찾는 것이 더 안전.
                    // 여기서는 tableView가 제공한 indexPath를 신뢰하고 사용하되, 범위 체크를 추가할 수 있음.
                    if self.selectedDateTodos.indices.contains(indexPath.row) && self.selectedDateTodos[indexPath.row].id == todoToDelete.id {
                        self.selectedDateTodos.remove(at: indexPath.row)
                        // 2. UITableView 애니메이션과 함께 특정 행 삭제
        tableView.deleteRows(at: [indexPath], with: .fade)
                    } else {
                        // 데이터 불일치 또는 이미 삭제된 경우 등 예외 상황, 테이블 전체 리로드로 안전하게 처리
                        print("⚠️ 삭제하려는 항목이 예상 위치에 없거나 ID가 다릅니다. 테이블을 전체 리로드합니다.")
                        // 이 경우 loadData를 다시 호출하여 selectedDateTodos를 최신화하고 tableView.reloadData()를 유도
                        self.loadData(for: self.selectedDate) // loadData가 tableView.reloadData() 호출
                        // 부분 성공에 대한 에러 처리는 여기서도 필요할 수 있음
                        if let error = error {
                           self.handleTodoManagerError(error, forAction: "삭제 (부분 성공, 데이터 불일치)")
                        }
                        return // 추가 UI 업데이트는 loadData가 처리하므로 여기서 종료
                    }
                    
                    // 3. 캘린더 이벤트 점 업데이트
                    self.calendar.reloadData()
                    
                    // 4. 빈 상태 레이블 가시성 업데이트 (reloadData 없이)
                    self.updateEmptyStateLabelVisibility()
                    
                    // 5. 할 일 섹션 헤더 업데이트 (전체 reloadData 대신 섹션만 리로드)
                    if let todosSection = CalendarSection.todos.rawValue as Int? {
                         tableView.reloadSections(IndexSet(integer: todosSection), with: .none)
                    }
                    
                    // 6. 전체 조언 버튼 UI 업데이트 (선택적)
                    self.updateOverallAdviceButtonUI()
                    
                    if let error = error { // 로컬 삭제는 성공했으나, 캘린더 연동 등에 문제가 있었을 경우
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
    
    // MARK: - AddEditTodoDelegate
    func didSaveTodoItem(_ todoItem: TodoItem) {
        // Handle saving from Add/Edit view
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
        
        // 🆕 향상된 분석을 위한 할 일 분류 및 컨텍스트 수집
        let allTodos = selectedDateTodos
        let completedTodos = allTodos.filter { $0.isCompleted }
        let pendingTodos = allTodos.filter { !$0.isCompleted }
        
        // 🆕 연속 일정 분석 (장기 여행 등의 정보 수집)
        let continuousEvents = getContinuousEventContext()
        
        guard !allTodos.isEmpty else {
            showAlert(title: "알림", message: "선택된 날짜에 할 일이 없어 전체 조언을 받을 수 없습니다.")
            return
        }
        
        // 현재 시간 및 날짜 정보
        let currentTime = Date()
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "yyyy년 MM월 dd일 HH시 mm분"
        let currentTimeString = timeFormatter.string(from: currentTime)
        
        let selectedDateFormatter = DateFormatter()
        selectedDateFormatter.dateFormat = "MM월 dd일 (E)"
        selectedDateFormatter.locale = Locale(identifier: "ko_KR")
        let selectedDateString = selectedDateFormatter.string(from: selectedDate)
        
        // 할 일 우선순위별 분류
        let highPriorityTodos = allTodos.filter { $0.priority == 2 }
        let mediumPriorityTodos = allTodos.filter { $0.priority == 1 }
        let lowPriorityTodos = allTodos.filter { $0.priority == 0 }
        
        // 긴급성 분석 (마감일 기준)
        let urgentTodos = pendingTodos.filter {
            $0.dueDate.timeIntervalSince(currentTime) < 24 * 3600 // 24시간 이내
        }
        
        // 주간 컨텍스트
        let weeklyContext = SessionManager.shared.buildRichContextForLocalAI().emotionHistory.first?.emotion ?? "일반적인 컨텍스트"
        
        var promptContent = """
        📅 날짜: \(selectedDateString)
        🕒 현재 시간: \(currentTimeString)
        
        📊 할 일 현황:
        • 전체 할 일: \(allTodos.count)개
        • 완료된 할 일: \(completedTodos.count)개
        • 남은 할 일: \(pendingTodos.count)개
        • 긴급한 할 일: \(urgentTodos.count)개 (24시간 이내)
        
        🎯 우선순위별 분류:
        • 높음: \(highPriorityTodos.count)개
        • 보통: \(mediumPriorityTodos.count)개  
        • 낮음: \(lowPriorityTodos.count)개
        
        📋 상세 할 일 목록:
        """
        
        // 우선순위 높은 순으로 정렬하여 표시
        let sortedTodos = allTodos.sorted { $0.priority > $1.priority }
        for (index, todo) in sortedTodos.enumerated() {
            let priorityEmoji = ["📌", "📝", "📄"][todo.priority]
            let statusEmoji = todo.isCompleted ? "✅" : "⏳"
            let urgentMark = urgentTodos.contains(where: { $0.id == todo.id }) ? " 🔥" : ""
            
            promptContent += "\n\(index + 1). \(statusEmoji) \(priorityEmoji) \(todo.title) (\(todo.dueDateString))\(urgentMark)"
            if let notes = todo.notes, !notes.isEmpty {
                promptContent += " - 메모: \(notes)"
            }
        }
        
        // 🆕 연속 일정 정보 추가
        if !continuousEvents.isEmpty {
            promptContent += "\n\n🗓️ 연속 일정 정보:"
            for eventInfo in continuousEvents {
                promptContent += "\n\(eventInfo)"
            }
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
        
        let _ = """
        당신은 경험이 풍부한 생산성 컨설턴트이자 시간 관리 전문가입니다. 사용자의 할 일 패턴을 분석하여 개인화된 실행 전략을 제공하세요.
        
        **🔥 중요한 제약 조건**:
        - 응답은 반드시 **200자 이내**로 작성해야 합니다
        - 모바일 alert 창에서 잘리지 않도록 간결하게 작성하세요
        - 불필요한 인사말이나 부가설명은 제외하고 핵심만 전달하세요
        
        분석 기준:
        1. 긴급성 vs 중요성 매트릭스 적용  
        2. 에너지 레벨과 시간대별 최적 작업 배치
        3. 멀티태스킹 vs 단일집중 전략 선택
        4. 휴식과 재충전 시점 고려
        5. 현실적이고 달성 가능한 목표 설정
        
        사용자 활동 패턴:
        \(weeklyContext)
        
        위 데이터를 활용하여 사용자의 작업 스타일에 맞는 맞춤형 조언을 **200자 이내**로 제공하세요.
        구체적인 시간 배분, 작업 순서, 실행 팁을 포함해주세요.
        """

        // 🔧 기존 로딩 표시 제거하고 새로운 오버레이 로딩 표시
        guard let adviceButton = overallAdviceButton,
              let adviceIndicator = overallAdviceActivityIndicator else {
            print("⚠️ [TodoCalendar] UI 요소가 초기화되지 않아 조언 요청 불가")
            return
        }
        
        adviceButton.setTitle("", for: .normal)
        adviceIndicator.stopAnimating()
        adviceButton.isEnabled = false
        
        // 🆕 로딩 오버레이 표시
        loadingOverlay = LoadingOverlayView()
        loadingOverlay?.show(in: view)

        Task {
            let promptContent = await self.buildComprehensivePrompt()
            
            do {
                // 🤖 SessionManager로 전체 할일 조언 호출 (저장 안 함)
                let advice = try await SessionManager.shared.sendMessage(
                    content: promptContent,
                    model: .openAI,
                    mode: .taskAdvice,
                    saveMessages: false
                )
                
                await MainActor.run {
                    // 🔧 로딩 오버레이 숨기기
                    self.loadingOverlay?.hide()
                    self.loadingOverlay = nil
                    self.overallAdviceActivityIndicator?.stopAnimating()
                    
                    self.showAdvice(title: "✨ 오늘의 전체 조언 ✨", advice: advice)
                    AIUsageManager.shared.recordUsage(for: .overallTodoAdvice)
                    self.updateOverallAdviceButtonUI() // 성공 후 버튼 UI 업데이트
                }
                
            } catch {
                await MainActor.run {
                    // 🔧 로딩 오버레이 숨기기
                    self.loadingOverlay?.hide()
                    self.loadingOverlay = nil
                    self.overallAdviceActivityIndicator?.stopAnimating()
                    
                    // 사용량 제한 초과 에러 처리
                    let errorMessage: String
                    if error.localizedDescription.contains("일일 사용 한도") {
                        errorMessage = error.localizedDescription
                    } else {
                        errorMessage = "전체 조언을 받아오는 데 실패했습니다. (\(error.localizedDescription))"
                    }
                    
                    self.showAlert(title: "AI 조언 오류", message: errorMessage)
                    self.updateOverallAdviceButtonUI() // 실패 후 버튼 UI 업데이트
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

        let sortedTodos = todos.sorted { $0.priority > $1.priority }
        for (index, todo) in sortedTodos.enumerated() {
            let priorityEmoji = ["📌", "📝", "📄"][todo.priority]
            let statusEmoji = todo.isCompleted ? "✅" : "⏳"
            let urgentMark = urgentTodos.contains(where: { $0.id == todo.id }) ? " 🔥" : ""
            let maskedTitle = SettingsManager.shared.maskPIIForExport(todo.title)
            let maskedNotes = todo.notes.map { SettingsManager.shared.maskPIIForExport($0) }
            promptContent += "\n\(index + 1). \(statusEmoji) \(priorityEmoji) \(maskedTitle) (\(todo.dueDateString))\(urgentMark)"
            if let notes = maskedNotes, !notes.isEmpty { promptContent += " - 메모: \(notes)" }
        }

        // 연속 일정 정보
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        var continuousEvents: [String] = []
        for todo in allTodos {
            if let end = todo.endDate {
                let start = calendar.startOfDay(for: todo.dueDate)
                let endDay = calendar.startOfDay(for: end)
                if day >= start && day <= endDay {
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
        // 할 일 상세 정보 분석
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
        
        // 주간 컨텍스트
        let weeklyContext = SessionManager.shared.buildRichContextForLocalAI().emotionHistory.first?.emotion ?? "일반적인 컨텍스트"
        
        var promptContent = """
        🎯 할 일 상세 분석:
        • 제목: \(todo.title)
        • 상태: \(statusText)
        • 우선순위: \(priorityText)
        • 마감일: \(todo.dueDateString)
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
        // 🛡️ 할 일별 조언 횟수 체크 (통합 관리)
        guard todo.canReceiveAdvice else {
            showAlert(title: "알림", message: "이 할 일에 대한 조언을 모두 사용했습니다. (\(todo.adviceUsageText))")
            return
        }
        
        // 🛡️ 전체 일일 제한도 함께 체크
        guard AIUsageManager.shared.getRemainingCount(for: .individualTodoAdvice) > 0 else {
            showAlert(title: "알림", message: "오늘 사용할 수 있는 개별 할 일 조언 횟수를 모두 사용했습니다.")
            return
        }
        
        // 🆕 로딩 오버레이 표시
        loadingOverlay = LoadingOverlayView()
        loadingOverlay?.show(in: view)
        
        // 할 일 상세 정보 분석
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
        
        // 주간 컨텍스트
        let weeklyContext = SessionManager.shared.buildRichContextForLocalAI().emotionHistory.first?.emotion ?? "일반적인 컨텍스트"
        
        var promptContent = """
        🎯 할 일 상세 분석:
        • 제목: \(todo.title)
        • 상태: \(statusText)
        • 우선순위: \(priorityText)
        • 마감일: \(todo.dueDateString)
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
        
        let systemPrompt = """
        당신은 개인 생산성 전문가이자 실행력 코치입니다. 사용자의 특정 할 일에 대해 맞춤형 실행 전략을 제공하세요.
        
        **🔥 중요한 제약 조건**:
        - 응답은 반드시 **150자 이내**로 작성해야 합니다
        - 모바일 alert 창에서 잘리지 않도록 간결하게 작성하세요
        - 불필요한 인사말이나 부가설명은 제외하고 핵심만 전달하세요
        
        분석 기준:
        1. 긴급성과 중요성을 고려한 우선순위 조정
        2. 작업의 복잡도에 따른 분해 전략  
        3. 개인의 에너지 패턴과 시간 활용법
        4. 동기 유지 및 완료율 향상 방법
        5. 스트레스 관리 및 번아웃 예방
        
        사용자 활동 패턴:
        \(weeklyContext)
        
        위 데이터를 바탕으로 사용자에게 가장 적합한 개별 할 일 실행 전략을 **150자 이내**로 제안하세요.
        구체적이고 즉시 실행 가능한 조언을 해주세요.
        """
        
        Task {
            let promptContent = await self.buildIndividualTodoPrompt(for: todo)
            
            do {
                // 🤖 SessionManager로 개별 할일 조언 호출 (저장 안 함)
                let advice = try await SessionManager.shared.sendMessage(
                    content: promptContent,
                    model: .openAI,
                    mode: .taskAdvice,
                    saveMessages: false
                )
                
                await MainActor.run {
                    // 🔧 로딩 오버레이 숨기기
                    self.loadingOverlay?.hide()
                    self.loadingOverlay = nil
                    
                    // 🛡️ 할 일 조언 횟수 증가 (통합 관리)
                    if let todoIndex = self.selectedDateTodos.firstIndex(where: { $0.id == todo.id }) {
                        var updatedTodo = self.selectedDateTodos[todoIndex]
                        if updatedTodo.requestAdvice() {
                            // 할 일 업데이트
                            self.selectedDateTodos[todoIndex] = updatedTodo
                            
                            // 저장소에도 업데이트
                            TodoManager.shared.updateTodo(updatedTodo) { (_, error) in
                                if let error = error {
                                    print("⚠️ 할 일 조언 횟수 업데이트 실패: \(error.localizedDescription)")
                                } else {
                                    print("✅ 할 일 조언 횟수 업데이트 완료: \(updatedTodo.adviceUsageText)")
                                }
                            }
                            
                            // 테이블 뷰 업데이트
                            self.tableView.reloadData()
                        }
                        
                        AIUsageManager.shared.recordUsage(for: .individualTodoAdvice)
                    }
                    
                    // 조언 저장 및 표시
                    TodoManager.shared.appendAdvice(to: todo.id, advice: advice)
                    self.showAdvice(title: "💡 \(todo.title) 조언", advice: advice)
                }
                
            } catch {
                await MainActor.run {
                    // 🔧 로딩 오버레이 숨기기
                    self.loadingOverlay?.hide()
                    self.loadingOverlay = nil
                    
                    // 사용량 제한 초과 에러 처리
                    let errorMessage: String
                    if error.localizedDescription.contains("일일 사용 한도") {
                        errorMessage = error.localizedDescription
                    } else {
                        errorMessage = "개별 할 일 조언을 받아오는 데 실패했습니다. (\(error.localizedDescription))"
                    }
                    
                    self.showAlert(title: "AI 조언 오류", message: errorMessage)
                }
            }
        }
    }
    
    // MARK: - UI Helper Methods
    // These methods are already defined earlier in the file
    
    // MARK: - 🔧 삭제 기능 분리
    private func deleteTodo(at indexPath: IndexPath) {
        let todoToDelete = selectedDateTodos[indexPath.row]
        
        TodoManager.shared.deleteTodo(withId: todoToDelete.id) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if success {
                    if self.selectedDateTodos.indices.contains(indexPath.row) && self.selectedDateTodos[indexPath.row].id == todoToDelete.id {
                        self.selectedDateTodos.remove(at: indexPath.row)
                        self.tableView.deleteRows(at: [indexPath], with: .fade)
                    } else {
                        print("⚠️ 삭제하려는 항목이 예상 위치에 없거나 ID가 다릅니다. 테이블을 전체 리로드합니다.")
                        self.loadData(for: self.selectedDate)
                        if let error = error {
                           self.handleTodoManagerError(error, forAction: "삭제 (부분 성공, 데이터 불일치)")
                        }
                        return
                    }
                    
                    self.calendar.reloadData()
                    self.updateEmptyStateLabelVisibility()
                    
                    if let todosSection = CalendarSection.todos.rawValue as Int? {
                         self.tableView.reloadSections(IndexSet(integer: todosSection), with: .none)
                    }
                    
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

    // MARK: - 🆕 연속 일정 컨텍스트 분석
    // This method is already defined earlier in the file
 
    // MARK: - 🧠 AI 조언 기능 (리팩토링 완료)
 
    private func getAIAdvice(for date: Date) {
        let todosForDate = TodoManager.shared.getTodos(for: date)
        guard !todosForDate.isEmpty else {
            presentAlert(title: "✅", message: "선택한 날짜에 할 일이 없어 조언을 드릴 수 없어요.")
            return
        }

        // 로딩 UI 시작
        showLoadingOverlay()

        Task {
            let todoTitles = todosForDate.map { $0.title }
            
            do {
                // 🤖 SessionManager로 날짜별 AI 조언 호출 (저장 안 함)
                let advice = try await SessionManager.shared.sendMessage(
                    content: """
                    다음 할 일 목록에 대한 실용적인 조언을 제공해주세요:
                    
                    할 일 목록: \(todoTitles.joined(separator: ", "))
                    
                    요구사항:
                    - 간결하고 실용적인 조언
                    - 우선순위나 순서 제안
                    - 효율적인 수행 방법 제안
                    - 3-4문장 이내로 작성
                    """,
                    model: .openAI,
                    mode: .taskAdvice,
                    saveMessages: false
                )
                
                await MainActor.run {
                    self.hideLoadingOverlay()
                    self.presentAlert(title: "💡 AI 조언", message: advice)
                }
                
            } catch {
                await MainActor.run {
                    self.hideLoadingOverlay()
                    
                    // 사용량 제한 초과 에러 처리
                    let errorMessage: String
                    if error.localizedDescription.contains("일일 사용 한도") {
                        errorMessage = error.localizedDescription
                    } else {
                        errorMessage = "AI 조언을 가져오는 데 실패했습니다: \(error.localizedDescription)"
                    }
                    
                    self.presentAlert(title: "오류", message: errorMessage)
                }
            }
        }
    }
    
    // 🆕 로딩 오버레이 표시/숨김
    private func showLoadingOverlay() {
        // ... existing code ...
    }

    @objc private func addAITaskButtonTapped() {
        let currentTaskTitles = selectedDateTodos.map { $0.title }
        
        let promptContent = """
        현재 할 일 목록: \(currentTaskTitles.joined(separator: ", "))
        
        위 목록을 고려하여 사용자가 다음으로 하면 좋을 만한 창의적이고 실용적인 할 일 아이템 하나를 제안해주세요.
        
        요구사항:
        - 기존 할 일과 보완적이거나 연과된 작업
        - 즉시 실행 가능한 구체적인 작업
        - 형식: '작업명: 간략한 설명 (1줄)'
        """
        
        Task {
            do {
                // 🤖 SessionManager를 통해 AI 작업 추천 호출 (저장 안 함, 단일 경로)
                let suggestion = try await SessionManager.shared.sendMessage(
                    content: promptContent,
                    model: .openAI,
                    mode: .taskAdvice,
                    saveMessages: false
                )
                
                await MainActor.run {
                    // AI가 제안한 작업을 파싱하고 목록에 추가하는 로직 (향후 구현 예매)
                    // 예: self.parseAndAddNewTask(suggestion)
                    self.showAlert(title: "🤖 AI 추천 작업", message: suggestion)
                }
                
            } catch {
                await MainActor.run {
                    // 사용량 제한 초과 에러 처리
                    let errorMessage: String
                    if error.localizedDescription.contains("일일 사용 한도") {
                        errorMessage = error.localizedDescription
                    } else {
                        errorMessage = "AI 추천을 가져오는 데 실패했습니다. (\(error.localizedDescription))"
                    }
                    
                    self.showAlert(title: "오류", message: errorMessage)
                }
            }
        }
    }

    // MARK: - Helper Stubs
    private var currentTasks: [String] { return [] }
    
    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Loading Overlay Helpers
    private func hideLoadingOverlay() {
        loadingOverlay?.hide()
    }
}

// MARK: - 연속 일정 표시를 위한 커스텀 캘린더 셀
class TodoRangeCalendarCell: FSCalendarCell {
    private let rangeIndicatorView = UIView()
    private let startIndicatorView = UIView()
    private let endIndicatorView = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupRangeViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupRangeViews()
    }
    
    private func setupRangeViews() {
        // 연속 게이지 배경 - 더 부드러운 모서리
        rangeIndicatorView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
        rangeIndicatorView.layer.cornerRadius = 4 // 더 둥근 모서리
        rangeIndicatorView.isHidden = true
        rangeIndicatorView.clipsToBounds = false // 확장된 영역도 보이도록
        contentView.insertSubview(rangeIndicatorView, at: 0)
        
        // 시작점 표시 - 더 눈에 띄게
        startIndicatorView.backgroundColor = UIColor.systemBlue
        startIndicatorView.layer.cornerRadius = 5 // 크기에 맞게 조정
        startIndicatorView.isHidden = true
        startIndicatorView.layer.shadowColor = UIColor.black.cgColor
        startIndicatorView.layer.shadowOffset = CGSize(width: 0, height: 1)
        startIndicatorView.layer.shadowOpacity = 0.3
        startIndicatorView.layer.shadowRadius = 2
        contentView.addSubview(startIndicatorView)
        
        // 끝점 표시 - 더 눈에 띄게
        endIndicatorView.backgroundColor = UIColor.systemBlue
        endIndicatorView.layer.cornerRadius = 5 // 크기에 맞게 조정
        endIndicatorView.isHidden = true
        endIndicatorView.layer.shadowColor = UIColor.black.cgColor
        endIndicatorView.layer.shadowOffset = CGSize(width: 0, height: 1)
        endIndicatorView.layer.shadowOpacity = 0.3
        endIndicatorView.layer.shadowRadius = 2
        contentView.addSubview(endIndicatorView)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let cellHeight = bounds.height
        let cellWidth = bounds.width
        let indicatorHeight: CGFloat = 8 // 더 두꺼운 게이지
        let indicatorY = cellHeight - indicatorHeight - 4
        
        // 연속 게이지 - 셀 간격을 무시하고 확장하여 연속성 확보
        let extensionWidth: CGFloat = 2 // 좌우로 확장
        rangeIndicatorView.frame = CGRect(x: -extensionWidth, y: indicatorY, width: cellWidth + (extensionWidth * 2), height: indicatorHeight)
        
        // 시작/끝 표시는 좌우 끝에, 더 눈에 잘 띄게
        let dotSize: CGFloat = 10
        startIndicatorView.frame = CGRect(x: 4, y: indicatorY - 1, width: dotSize, height: dotSize)
        endIndicatorView.frame = CGRect(x: cellWidth - dotSize - 4, y: indicatorY - 1, width: dotSize, height: dotSize)
        
        // 시작/끝 표시의 cornerRadius도 업데이트
        startIndicatorView.layer.cornerRadius = dotSize / 2
        endIndicatorView.layer.cornerRadius = dotSize / 2
    }
    
    func configureRangeDisplay(isStart: Bool = false, isEnd: Bool = false, isInRange: Bool = false, color: UIColor = .systemBlue) {
        // 연속 일정 배경 게이지 표시
        rangeIndicatorView.isHidden = !isInRange
        startIndicatorView.isHidden = !isStart
        endIndicatorView.isHidden = !isEnd
        
        if isInRange {
            // 연속 게이지 스타일링
            rangeIndicatorView.backgroundColor = color.withAlphaComponent(0.5)
            rangeIndicatorView.layer.borderWidth = 1
            rangeIndicatorView.layer.borderColor = color.withAlphaComponent(0.8).cgColor
            
            // 그라데이션 효과 추가 (선택적)
            rangeIndicatorView.layer.shadowColor = color.cgColor
            rangeIndicatorView.layer.shadowOffset = CGSize(width: 0, height: 0)
            rangeIndicatorView.layer.shadowOpacity = 0.2
            rangeIndicatorView.layer.shadowRadius = 1
        }
        
        if isStart {
            startIndicatorView.backgroundColor = color
            startIndicatorView.layer.borderWidth = 2
            startIndicatorView.layer.borderColor = UIColor.white.cgColor
        }
        
        if isEnd {
            endIndicatorView.backgroundColor = color
            endIndicatorView.layer.borderWidth = 2
            endIndicatorView.layer.borderColor = UIColor.white.cgColor
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        rangeIndicatorView.isHidden = true
        startIndicatorView.isHidden = true
        endIndicatorView.isHidden = true
    }
}

// MARK: - 조언 표시를 위한 간단한 커스텀 뷰 컨트롤러 (글자 수 제한 없음)
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
