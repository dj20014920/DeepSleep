import UIKit
import FSCalendar

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

    // 섹션 정의
    private enum CalendarSection: Int, CaseIterable {
        case diary = 0
        case todos = 1
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
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
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(didTapAddButton))
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
        calendar.appearance.weekdayTextColor = .systemBlue
        calendar.appearance.headerTitleColor = .label
        calendar.appearance.todayColor = .systemOrange
        calendar.appearance.selectionColor = .systemBlue
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
        button.backgroundColor = UIColor.systemPurple
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
        
        // tableView.reloadData() // updateEmptyStateView 내부 또는 말미에서 호출됨
        calendar.reloadData() // 이벤트 점 표시 업데이트
        updateEmptyStateView() // 데이터 로드 후 빈 화면 상태 업데이트
        
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

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard CalendarSection(rawValue: indexPath.section) == .todos, editingStyle == .delete else { return }
        
        let todoToDelete = selectedDateTodos[indexPath.row]
        
        // TodoManager를 통해 삭제하고 에러 처리
        TodoManager.shared.deleteTodo(withId: todoToDelete.id) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if success {
                    // 로컬 데이터 소스에서도 삭제 및 테이블뷰 업데이트
                    self.selectedDateTodos.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                    self.calendar.reloadData() // 이벤트 점 업데이트
                    
                    // 만약 삭제 후 해당 날짜에 아무 데이터도 없다면 빈 화면 처리 업데이트
                    self.updateEmptyStateView()
                    
                    if let error = error { // 로컬 삭제는 성공했으나, 캘린더 연동 등에 문제가 있었을 경우
                        self.handleTodoManagerError(error, forAction: "삭제 (부분 성공)")
                    }
                } else if let error = error {
                    self.handleTodoManagerError(error, forAction: "삭제")
                } else {
                    // success false인데 error도 nil인 경우 (예상치 못한 상황)
                    self.showAlert(title: "오류", message: "할 일 삭제 중 알 수 없는 오류가 발생했습니다.")
                }
            }
        }
        loadData(for: selectedDate)
        updateOverallAdviceButtonUI()
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
        let nsError = error as NSError
        var message = "할 일 \(action) 중 오류 발생: \(error.localizedDescription)"
        var recoverySuggestion: String? = (error as? TodoManagerError)?.recoverySuggestion
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
        // 초기에는 숨김
        label.isHidden = true 
        tableView.backgroundView = label
        emptyStateLabel = label
    }

    private func updateEmptyStateView() {
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
        // 테이블뷰 헤더도 데이터 유무에 따라 업데이트 (예: "할 일 (없음)" 등)
        tableView.reloadData() // 섹션 헤더 업데이트 위해
    }

    // MARK: - AI Overall Advice Button Actions (New)
    private func updateOverallAdviceButtonUI() {
        let remainingCount = AIUsageManager.shared.getRemainingDailyOverallAdviceCount()
        overallAdviceButton.setTitle("오늘의 전체 조언 보기 (\(remainingCount)회 남음)", for: .normal)
        overallAdviceButton.isEnabled = remainingCount > 0
        if overallAdviceActivityIndicator.isAnimating {
             overallAdviceButton.setTitle("", for: .normal) // 로딩 중에는 텍스트 숨김
        }
    }

    @objc private func didTapOverallAdviceButton() {
        guard AIUsageManager.shared.getRemainingDailyOverallAdviceCount() > 0 else {
            showAlert(title: "알림", message: "오늘 사용할 수 있는 전체 할 일 조언 횟수를 모두 사용했습니다.")
            return
        }
        
        // 완료되지 않은 오늘의 할 일만 가져오기 (선택 사항, 여기서는 모든 할 일 사용)
        let todosForAdvice = selectedDateTodos // .filter { !$0.isCompleted }
        
        guard !todosForAdvice.isEmpty else {
            showAlert(title: "알림", message: "선택된 날짜에 할 일이 없어 전체 조언을 받을 수 없습니다.")
            return
        }
        
        var promptContent = "다음은 오늘 나의 할 일 목록입니다:\n"
        for todo in todosForAdvice {
            var todoDescription = "- \(todo.title) (\(todo.dueDateString))"
            if let notes = todo.notes, !notes.isEmpty {
                todoDescription += ", 메모: \(notes)"
            }
            todoDescription += "\n"
            promptContent += todoDescription
        }
        promptContent += "\n이 목록을 바탕으로 오늘 하루를 더 생산적이고 효과적으로 보낼 수 있도록, 우선순위 설정, 시간 관리, 또는 동기 부여에 대한 전반적인 조언을 1-2문장으로 간결하고 친근하게 해주세요."
        
        let systemPrompt = "당신은 사용자의 하루 계획을 검토하고 종합적인 조언을 제공하는 유능한 AI 코치입니다. 각 할 일에 대한 세부 조언보다는 전체적인 그림을 보고 격려와 방향을 제시해주세요."

        overallAdviceButton.setTitle("", for: .normal)
        overallAdviceActivityIndicator.startAnimating()
        overallAdviceButton.isEnabled = false

        Task {
            do {
                let advice = try await ReplicateChatService.shared.getAIAdvice(prompt: promptContent, systemPrompt: systemPrompt)
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.overallAdviceActivityIndicator.stopAnimating()
                    self.showAlert(title: "✨ 오늘의 전체 조언 ✨", message: advice)
                    AIUsageManager.shared.recordOverallAdviceUsed()
                    self.updateOverallAdviceButtonUI() // 성공 후 버튼 UI 업데이트
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.overallAdviceActivityIndicator.stopAnimating()
                    self.showAlert(title: "AI 조언 오류", message: "전체 조언을 받아오는 데 실패했습니다: \(error.localizedDescription)")
                    self.updateOverallAdviceButtonUI() // 실패 후 버튼 UI 업데이트 (다시 활성화 등)
                }
            }
        }
    }
} 