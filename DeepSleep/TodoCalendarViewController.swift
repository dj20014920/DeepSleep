import UIKit
import FSCalendar

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
    
    // 🆕 로딩 오버레이 뷰
    private var loadingOverlay: LoadingOverlayView?

    // 섹션 정의
    private enum CalendarSection: Int, CaseIterable {
        case diary = 0
        case todos = 1
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        self.title = "내 일정"
        
        setupCalendar()
        setupOverallAdviceButtonArea()
        setupTableView()
        setupEmptyStateView() // 빈 화면 처리 뷰 설정
        
        // 새 셀 등록
        tableView.register(EmotionDiaryDisplayCell.self, forCellReuseIdentifier: EmotionDiaryDisplayCell.identifier)
        tableView.separatorStyle = .none // 구분선 없음. EmotionDiaryDisplayCell에서 자체적인 간격/디자인 처리.
        
        // 캘린더의 초기 선택 날짜를 오늘로 설정
        let today = Date()
        calendar.select(today) // 오늘 날짜를 프로그램적으로 선택
        // FSCalendar의 select(_:) 메소드는 delegate의 didSelect를 호출하지 않을 수 있으므로,
        // 명시적으로 데이터 로드 함수도 호출해줍니다.
        // 또한, 캘린더가 사용자 인터랙션 없이 날짜를 변경할 때 didSelect가 호출되도록 설정해야 할 수 있습니다.
        // calendar.allowsSelection = true // 기본적으로 true
        loadData(for: today)
        updateOverallAdviceButtonUI()
        
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(didTapAddButton))
        addButton.tintColor = UIDesignSystem.Colors.primaryText
        navigationItem.rightBarButtonItem = addButton
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    private func setupCalendar() {
        let calendar = FSCalendar(frame: .zero)
        calendar.translatesAutoresizingMaskIntoConstraints = false
        calendar.dataSource = self
        calendar.delegate = self
        
        calendar.appearance.headerDateFormat = "YYYY년 M월"
        calendar.appearance.weekdayTextColor = UIDesignSystem.Colors.primary
        calendar.appearance.headerTitleColor = UIDesignSystem.Colors.primaryText
        calendar.appearance.titleDefaultColor = UIDesignSystem.Colors.primaryText
        calendar.appearance.titleWeekendColor = UIDesignSystem.Colors.error
        calendar.appearance.todayColor = .systemOrange
        calendar.appearance.selectionColor = UIColor.darkGray
        calendar.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.placeholderType = .none

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
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        button.backgroundColor = UIColor.secondarySystemGroupedBackground
        button.setTitleColor(UIDesignSystem.Colors.primaryText, for: .normal)
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
            container.topAnchor.constraint(equalTo: calendar.bottomAnchor, constant: 8),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            container.heightAnchor.constraint(equalToConstant: 44),
            
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
        
        self.view.addSubview(tableView)
        self.tableView = tableView
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: overallAdviceButtonContainer.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func loadData(for date: Date) {
        selectedDate = date
        
        // 할 일 로드
        selectedDateTodos = TodoManager.shared.getTodos(for: date)
        
        // 감정 일기 로드
        let allDiaries = SettingsManager.shared.loadEmotionDiary()
        selectedDateDiary = allDiaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
        
        calendar.reloadData() // 이벤트 점 표시 업데이트
        
        // 수정: updateEmptyStateView -> updateEmptyStateLabelVisibility 호출 후 tableView.reloadData() 명시적 호출
        updateEmptyStateLabelVisibility() 
        tableView.reloadData() // 데이터 로드 후 테이블 전체 새로고침

        // 수정: 문자열 보간 오류 수정
        print("선택된 날짜 \(date.description(with: Locale(identifier: "ko_KR"))): 할 일 \(selectedDateTodos.count)개, 일기 \(selectedDateDiary != nil ? "있음" : "없음")")
        updateOverallAdviceButtonUI()
    }
    
    @objc private func didTapAddButton() {
        let addEditVC = AddEditTodoViewController()
        addEditVC.delegate = self
        let navController = UINavigationController(rootViewController: addEditVC)
        present(navController, animated: true, completion: nil)
    }

    // MARK: - FSCalendarDataSource
    func calendar(_ calendar: FSCalendar, numberOfEventsFor date: Date) -> Int {
        // 이 함수는 점의 *개수*만 반환. 색상 커스터마이징을 위해서는 appearance delegate 필요.
        // 여기서는 일단 단순 존재 유무로 1개 또는 0개 반환.
        let hasTodo = !TodoManager.shared.getTodos(for: date).filter { !$0.isCompleted }.isEmpty
        let hasDiary = SettingsManager.shared.loadEmotionDiary().contains(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
        
        return (hasTodo || hasDiary) ? 1 : 0
    }

    // MARK: - FSCalendarDelegateAppearance (For Dot Colors)
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, eventDefaultColorsFor date: Date) -> [UIColor]? {
        var eventColors: [UIColor] = []
        let todos = TodoManager.shared.getTodos(for: date)
        let hasIncompleteTodo = todos.contains { !$0.isCompleted }
        let hasCompletedTodo = todos.contains { $0.isCompleted }
        let hasDiary = SettingsManager.shared.loadEmotionDiary().contains(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })

        // 10대/20대 타겟: 좀 더 다채롭고 의미있는 색상 사용 고려
        // 순서가 중요: 여러 조건 만족 시 어떤 색을 우선할지?
        // 여기서는 미완료 할일 > 일기 > 완료된 할일 순으로 색을 정하고, 중복 시 하나만 표시되도록 함.
        // FSCalendar는 기본적으로 여러 점을 표시할 수 있으나, 여기서는 색상으로 구분 시도.
        // 또는, numberOfEventsFor에서 1,2,3 등을 반환하고, 아래에서 순서대로 다른 색을 지정할 수도 있음.

        if hasIncompleteTodo && hasDiary {
            eventColors.append(UIColor.systemPurple) // 둘 다: 보라색
        } else if hasIncompleteTodo {
            eventColors.append(UIColor.systemBlue)   // 할 일만: 파란색
        } else if hasDiary {
            eventColors.append(UIColor.systemGreen)  // 일기만: 초록색
        } else if hasCompletedTodo {
            eventColors.append(UIColor.systemGray4) // 완료된 할 일만: 연한 회색
        }
        
        // eventColors가 비어있으면 nil을 반환해야 기본 점 색상이 사용됨 (또는 점이 안 찍힘)
        return eventColors.isEmpty ? nil : eventColors
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
    
    // MARK: - UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return CalendarSection.allCases.count // 일기, 할 일 두 섹션
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let currentSection = CalendarSection(rawValue: section) else { return 0 }
        
        switch currentSection {
        case .diary:
            return selectedDateDiary != nil ? 1 : 0 // 일기가 있으면 1개, 없으면 0개
        case .todos:
            return selectedDateTodos.count // 할 일 개수
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let currentSection = CalendarSection(rawValue: indexPath.section) else {
            fatalError("Invalid section")
        }
        
        switch currentSection {
        case .diary:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: EmotionDiaryDisplayCell.identifier, for: indexPath) as? EmotionDiaryDisplayCell,
                  let diary = selectedDateDiary else {
                // 이 부분은 호출되지 않아야 함 (numberOfRowsInSection에서 처리)
                return UITableViewCell()
            }
            cell.configure(with: diary)
            cell.selectionStyle = .none // 일기 셀은 선택 스타일 없음
            return cell
        case .todos:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: TodoTableViewCell.identifier, for: indexPath) as? TodoTableViewCell else {
                return UITableViewCell()
            }
            let todo = selectedDateTodos[indexPath.row]
            cell.configure(with: todo)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let currentSection = CalendarSection(rawValue: section) else { return nil }
        
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
        guard let currentSection = CalendarSection(rawValue: indexPath.section) else { return }

        if currentSection == .todos {
            let todoItem = selectedDateTodos[indexPath.row]
            // 여기서 toggleCompletion 대신 수정화면으로 바로 이동
            let addEditVC = AddEditTodoViewController()
            addEditVC.delegate = self
            addEditVC.todoToEdit = todoItem
            let navController = UINavigationController(rootViewController: addEditVC)
            present(navController, animated: true, completion: nil)
            
        } else if currentSection == .diary, let diary = selectedDateDiary {
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
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return CalendarSection(rawValue: indexPath.section) == .todos
    }
    
    // 🆕 스와이프 액션 설정 (조언 기능 추가)
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard CalendarSection(rawValue: indexPath.section) == .todos else { return nil }
        
        let todo = selectedDateTodos[indexPath.row]
        
        // 조언 액션
        let adviceAction = UIContextualAction(style: .normal, title: "조언") { [weak self] (action, view, completionHandler) in
            self?.requestTodoAdvice(for: todo)
            completionHandler(true)
        }
        adviceAction.backgroundColor = UIColor.systemBlue
        adviceAction.image = UIImage(systemName: "lightbulb.fill")
        
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
    func didSaveTodo() {
        loadData(for: self.selectedDate) // 저장 후 현재 선택된 날짜의 데이터 새로고침
        // 마이그레이션 함수 호출은 앱 시작 시점으로 이동 고려
        // TodoManager.shared.migrateExistingTodosToCalendar { migratedCount, errors in
        //     if !errors.isEmpty {
        //         print("캘린더 마이그레이션 중 오류 발생: \(errors)")
        //         // 사용자에게 알림 필요 시 여기에 로직 추가
        //     }
        //     if migratedCount > 0 {
        //         print("\\(migratedCount)개의 기존 할 일이 캘린더에 추가되었습니다.")
        //         self.loadData(for: self.selectedDate) // 마이그레이션 후 데이터 다시 로드
        //     }
        // }
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
            case .eventSaveFailed(_), .eventRemoveFailed(_), .eventFetchFailed(_):
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
        let remainingCount = AIUsageManager.shared.getRemainingCount(for: .overallTodoAdvice)
        overallAdviceButton.setTitle("오늘의 전체 조언 보기 (\(remainingCount)회 남음)", for: .normal)
        overallAdviceButton.setTitleColor(UIDesignSystem.Colors.primaryText, for: .normal)
        overallAdviceButton.isEnabled = remainingCount > 0
        if overallAdviceActivityIndicator.isAnimating {
             overallAdviceButton.setTitle("", for: .normal) // 로딩 중에는 텍스트 숨김
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
        let weeklyContext = CachedConversationManager.shared.getFormattedWeeklyHistory()
        
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
        
        promptContent += """
        
        📈 요청사항:
        위 할 일 목록을 종합적으로 분석하여 다음 관점에서 구체적인 조언을 3-4문장으로 해주세요:
        1. 우선순위 조정 및 시간 배분 전략
        2. 효율적인 업무 순서 및 실행 방법
        3. 스트레스 관리 및 동기부여 방안
        
        단순한 격려가 아닌, 실제로 실행할 수 있는 구체적인 액션플랜을 제시해주세요.
        """
        
        let systemPrompt = """
        당신은 경험이 풍부한 생산성 컨설턴트이자 시간 관리 전문가입니다. 사용자의 할 일 패턴을 분석하여 개인화된 실행 전략을 제공하세요.
        
        분석 기준:
        1. 긴급성 vs 중요성 매트릭스 적용  
        2. 에너지 레벨과 시간대별 최적 작업 배치
        3. 멀티태스킹 vs 단일집중 전략 선택
        4. 휴식과 재충전 시점 고려
        5. 현실적이고 달성 가능한 목표 설정
        
        사용자 활동 패턴:
        \(weeklyContext)
        
        위 데이터를 활용하여 사용자의 작업 스타일에 맞는 맞춤형 조언을 제공하세요.
        구체적인 시간 배분, 작업 순서, 실행 팁을 포함해주세요.
        """

        // 🔧 기존 로딩 표시 제거하고 새로운 오버레이 로딩 표시
        overallAdviceButton.setTitle("", for: .normal)
        overallAdviceActivityIndicator.stopAnimating()
        overallAdviceButton.isEnabled = false
        
        // 🆕 로딩 오버레이 표시
        loadingOverlay = LoadingOverlayView()
        loadingOverlay?.show(in: view)

        Task {
            do {
                let advice = try await ReplicateChatService.shared.getAIAdvice(prompt: promptContent, systemPrompt: systemPrompt)
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // 🔧 로딩 오버레이 숨기기
                    self.loadingOverlay?.hide()
                    self.loadingOverlay = nil
                    
                    self.overallAdviceActivityIndicator.stopAnimating()
                    self.showAlert(title: "✨ 오늘의 전체 조언 ✨", message: advice)
                    AIUsageManager.shared.recordUsage(for: .overallTodoAdvice)
                    self.updateOverallAdviceButtonUI() // 성공 후 버튼 UI 업데이트
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // 🔧 로딩 오버레이 숨기기
                    self.loadingOverlay?.hide()
                    self.loadingOverlay = nil
                    
                    self.overallAdviceActivityIndicator.stopAnimating()
                    
                    // 구체적인 오류 메시지 제공
                    var errorMessage = "전체 조언을 받아오는 데 실패했습니다."
                    if let serviceError = error as? ReplicateChatService.ServiceError {
                        switch serviceError {
                        case .invalidAPIKey:
                            errorMessage = "API 키 설정에 문제가 있습니다. 개발자에게 문의하세요."
                        case .predictionTimeout:
                            errorMessage = "응답 시간이 초과되었습니다. 잠시 후 다시 시도해주세요."
                        case .replicateAPIError(let detail):
                            errorMessage = "API 오류: \(detail)"
                        default:
                            errorMessage = serviceError.localizedDescription
                        }
                    } else {
                        errorMessage += " (\(error.localizedDescription))"
                    }
                    
                    self.showAlert(title: "AI 조언 오류", message: errorMessage)
                    self.updateOverallAdviceButtonUI() // 실패 후 버튼 UI 업데이트 (다시 활성화 등)
                }
            }
        }
    }
    
    // MARK: - 🆕 할 일 개별 조언 기능
    private func requestTodoAdvice(for todo: TodoItem) {
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
        let weeklyContext = CachedConversationManager.shared.getFormattedWeeklyHistory()
        
        var promptContent = """
        🎯 할 일 상세 분석:
        • 제목: \(todo.title)
        • 상태: \(statusText)
        • 우선순위: \(priorityText)
        • 마감일: \(todo.dueDateString)
        • 긴급도: \(urgencyText)
        • 현재 시간: \(currentTimeString)
        """
        
        if let notes = todo.notes, !notes.isEmpty {
            promptContent += "\n• 메모: \(notes)"
        }
        
        promptContent += """
        
        📝 요청사항:
        위 할 일에 대해 다음 관점에서 개인화된 조언을 2-3문장으로 해주세요:
        1. 실행 전략 및 구체적인 첫 번째 액션
        2. 시간 관리 및 효율적인 접근법
        3. 동기부여 및 완료 팁
        
        추상적인 격려보다는 실제로 실행할 수 있는 구체적인 방법을 제시해주세요.
        """
        
        let systemPrompt = """
        당신은 개인 생산성 전문가이자 실행력 코치입니다. 사용자의 특정 할 일에 대해 맞춤형 실행 전략을 제공하세요.
        
        분석 기준:
        1. 긴급성과 중요성을 고려한 우선순위 조정
        2. 작업의 복잡도에 따른 분해 전략  
        3. 개인의 에너지 패턴과 시간 활용법
        4. 동기 유지 및 완료율 향상 방법
        5. 스트레스 관리 및 번아웃 예방
        
        사용자 활동 패턴:
        \(weeklyContext)
        
        위 데이터를 바탕으로 사용자에게 가장 적합한 개별 할 일 실행 전략을 제안하세요.
        구체적이고 즉시 실행 가능한 조언을 해주세요.
        """
        
        Task {
            do {
                let advice = try await ReplicateChatService.shared.getAIAdvice(prompt: promptContent, systemPrompt: systemPrompt)
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // 🔧 로딩 오버레이 숨기기
                    self.loadingOverlay?.hide()
                    self.loadingOverlay = nil
                    
                    self.showAlert(title: "💡 \(todo.title) 조언", message: advice)
                    AIUsageManager.shared.recordUsage(for: .individualTodoAdvice)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // 🔧 로딩 오버레이 숨기기
                    self.loadingOverlay?.hide()
                    self.loadingOverlay = nil
                    
                    // 구체적인 오류 메시지 제공
                    var errorMessage = "할 일 조언을 받아오는 데 실패했습니다."
                    if let serviceError = error as? ReplicateChatService.ServiceError {
                        switch serviceError {
                        case .invalidAPIKey:
                            errorMessage = "API 키 설정에 문제가 있습니다. 개발자에게 문의하세요."
                        case .predictionTimeout:
                            errorMessage = "응답 시간이 초과되었습니다. 잠시 후 다시 시도해주세요."
                        case .replicateAPIError(let detail):
                            errorMessage = "API 오류: \(detail)"
                        default:
                            errorMessage = serviceError.localizedDescription
                        }
                    } else {
                        errorMessage += " (\(error.localizedDescription))"
                    }
                    
                    self.showAlert(title: "AI 조언 오류", message: errorMessage)
                }
            }
        }
    }
    
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
} 