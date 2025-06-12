import UIKit

protocol AddEditTodoDelegate: AnyObject {
    func didSaveTodo() // 저장 후 목록 새로고침 등을 위한 delegate
}

class AddEditTodoViewController: UIViewController, UITextViewDelegate {

    weak var delegate: AddEditTodoDelegate?
    var todoToEdit: TodoItem? // 수정 모드일 경우 전달받을 TodoItem
    private var currentTodoAdvices: [String] = [] // 화면에 표시될 조언들 (로드/실시간 추가)

    // UI 요소들
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "할 일 제목:"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        return label
    }()
    private let titleTextField: UITextField = {
        let textField = UITextField()
        textField.borderStyle = .roundedRect
        textField.placeholder = "예: 프로젝트 회의"
        return textField
    }()

    private let dueDateLabel: UILabel = {
        let label = UILabel()
        label.text = "시작일시:"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        return label
    }()
    private let dueDatePicker: UIDatePicker = {
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .dateAndTime // 날짜와 시간 모두 선택
        if #available(iOS 13.4, *) {
            datePicker.preferredDatePickerStyle = .wheels
        }
        datePicker.locale = Locale(identifier: "ko_KR")
        datePicker.minuteInterval = 5
        return datePicker
    }()
    
    // 기간 설정 섹션 (다일 일정 지원)
    private let durationLabel: UILabel = {
        let label = UILabel()
        label.text = "기간 설정:"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        return label
    }()
    
    private let hasEndDateSwitch: UISwitch = {
        let endDateSwitch = UISwitch()
        return endDateSwitch
    }()
    
    private let hasEndDateContainer: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        
        let label = UILabel()
        label.text = "연속 일정"
        label.font = .systemFont(ofSize: 14)
        
        return stackView
    }()
    
    private let endDateLabel: UILabel = {
        let label = UILabel()
        label.text = "종료일:"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        return label
    }()
    
    private let endDatePicker: UIDatePicker = {
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .dateAndTime
        if #available(iOS 13.4, *) {
            datePicker.preferredDatePickerStyle = .compact
        }
        datePicker.locale = Locale(identifier: "ko_KR")
        datePicker.minuteInterval = 5
        return datePicker
    }()
    
    private let durationSettingsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.isHidden = true
        return stackView
    }()

    private let notesLabel: UILabel = {
        let label = UILabel()
        label.text = "메모:"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        return label
    }()
    private let notesTextView: UITextView = {
        let textView = UITextView()
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.layer.borderWidth = 1.0
        textView.layer.cornerRadius = 5.0
        textView.font = .systemFont(ofSize: 14)
        return textView
    }()
    
    private let priorityLabel: UILabel = {
        let label = UILabel()
        label.text = "중요도:"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        return label
    }()
    private let prioritySegmentedControl: UISegmentedControl = {
        let items = ["낮음", "보통", "높음"]
        let sc = UISegmentedControl(items: items)
        sc.selectedSegmentIndex = 1 // 기본값 '보통'
        return sc
    }()

    private let saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("저장", for: .normal)
        // 다크모드에서는 파란색 배경에 흰색 텍스트, 일반모드에서는 파란색 배경에 흰색 텍스트
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        return button
    }()
    
    // 스크롤을 위한 전체 스택 뷰
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        return sv
    }()
    private let mainStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        return stackView
    }()

    // MARK: - AI 조언 UI
    private let aiHelpButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("AI에게 조언 구하기 🤔", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        // AI 버튼은 그린 색상으로 구분
        button.backgroundColor = UIColor.systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        return button
    }()

    private let aiAdviceStackView: UIStackView = { // 여러 조언을 표시할 스택뷰
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.isHidden = true // 초기에는 숨김
        return stackView
    }()
    
    private let aiHelpActivityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = todoToEdit == nil ? "새 할 일 추가" : "할 일 수정"

        setupUI()
        configureScreenForTodo() // 함수 이름 변경 및 로직 통합
        setupNavigationBar()
        
        saveButton.addTarget(self, action: #selector(didTapSaveButton), for: .touchUpInside)
        aiHelpButton.addTarget(self, action: #selector(didTapAIHelpButton), for: .touchUpInside)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        let tapGesture = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        view.addGestureRecognizer(tapGesture)
        tapGesture.cancelsTouchesInView = false
        
        notesTextView.delegate = self
        
        // updateAIHelpUI()는 configureScreenForTodo 내부에서 호출되도록 이동
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupNavigationBar() {
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(didTapCancelButton))
        cancelButton.tintColor = UIDesignSystem.Colors.primaryText
        navigationItem.leftBarButtonItem = cancelButton
    }

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(mainStackView)
        mainStackView.translatesAutoresizingMaskIntoConstraints = false

        mainStackView.addArrangedSubview(titleLabel)
        mainStackView.addArrangedSubview(titleTextField)
        mainStackView.setCustomSpacing(4, after: titleLabel) // 제목과 텍스트필드 간 간격 줄임
        
        mainStackView.addArrangedSubview(dueDateLabel)
        mainStackView.addArrangedSubview(dueDatePicker)
        mainStackView.setCustomSpacing(4, after: dueDateLabel)
        
        // 기간 설정 섹션 추가
        setupDurationSettingsContainer()
        mainStackView.addArrangedSubview(durationLabel)
        mainStackView.addArrangedSubview(hasEndDateContainer)
        mainStackView.addArrangedSubview(durationSettingsStackView)
        mainStackView.setCustomSpacing(4, after: durationLabel)
        mainStackView.setCustomSpacing(8, after: hasEndDateContainer)
        
        mainStackView.addArrangedSubview(priorityLabel)
        mainStackView.addArrangedSubview(prioritySegmentedControl)
        mainStackView.setCustomSpacing(4, after: priorityLabel)
        
        mainStackView.addArrangedSubview(notesLabel)
        mainStackView.addArrangedSubview(notesTextView)
        mainStackView.setCustomSpacing(4, after: notesLabel)
        
        // AI 조언 섹션 추가
        mainStackView.addArrangedSubview(aiHelpButton)
        mainStackView.setCustomSpacing(8, after: aiHelpButton)
        mainStackView.addArrangedSubview(aiHelpActivityIndicator) // 인디케이터 추가
        mainStackView.addArrangedSubview(aiAdviceStackView) // 스택뷰 추가
        mainStackView.setCustomSpacing(4, after: aiHelpActivityIndicator)
        mainStackView.setCustomSpacing(16, after: aiAdviceStackView) // 스택뷰와 저장 버튼 간 간격 추가
        
        mainStackView.addArrangedSubview(saveButton)
        mainStackView.setCustomSpacing(30, after: notesTextView) // 저장 버튼 위 간격 추가

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            mainStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            mainStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            mainStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            mainStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            mainStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
            
            notesTextView.heightAnchor.constraint(equalToConstant: 100),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            aiHelpButton.heightAnchor.constraint(equalToConstant: 44) // AI 버튼 높이 제약
        ])
    }
    
    // 시간 설정 컨테이너 설정
    private func setupDurationSettingsContainer() {
        // 스위치 컨테이너 설정
        let switchLabel = UILabel()
        switchLabel.text = "연속 일정"
        switchLabel.font = .systemFont(ofSize: 14)
        
        hasEndDateContainer.addArrangedSubview(switchLabel)
        hasEndDateContainer.addArrangedSubview(hasEndDateSwitch)
        
        // 기간 설정 스택뷰 설정
        durationSettingsStackView.addArrangedSubview(endDateLabel)
        durationSettingsStackView.addArrangedSubview(endDatePicker)
        
        // 스위치 액션 추가
        hasEndDateSwitch.addTarget(self, action: #selector(endDateSwitchChanged), for: .valueChanged)
        
        // 시작일 변경 시 종료일 자동 조정
        dueDatePicker.addTarget(self, action: #selector(startDateChanged), for: .valueChanged)
    }
    
    @objc private func endDateSwitchChanged() {
        durationSettingsStackView.isHidden = !hasEndDateSwitch.isOn
        
        if hasEndDateSwitch.isOn {
            // 여러 날 일정을 켰을 때 종료일을 다음날로 설정
            let startDate = dueDatePicker.date
            let calendar = Calendar.current
            
            // 종료일을 시작일 다음날 같은 시간으로 설정
            let nextDay = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
            endDatePicker.date = nextDay
        }
    }
    
    @objc private func startDateChanged() {
        // 시작일이 변경되면 종료일이 시작일보다 빠르지 않도록 조정
        if hasEndDateSwitch.isOn && endDatePicker.date < dueDatePicker.date {
            let calendar = Calendar.current
            let nextDay = calendar.date(byAdding: .day, value: 1, to: dueDatePicker.date) ?? dueDatePicker.date
            endDatePicker.date = nextDay
        }
    }

    // 수정: configureForEditing -> configureScreenForTodo로 변경하고 조언 로드 로직 추가
    private func configureScreenForTodo() {
        if let todo = todoToEdit {
            titleTextField.text = todo.title
            dueDatePicker.date = todo.dueDate
            notesTextView.text = todo.notes
            prioritySegmentedControl.selectedSegmentIndex = todo.priority
            
            // 기간 설정 로드
            if let endDate = todo.endDate {
                hasEndDateSwitch.isOn = true
                durationSettingsStackView.isHidden = false
                endDatePicker.date = endDate
            } else {
                hasEndDateSwitch.isOn = false
                durationSettingsStackView.isHidden = true
            }
            
            // 저장된 AI 조언 로드
            self.currentTodoAdvices = todo.aiAdvices ?? []
            populateAdvicesInStackView() // 로드된 조언 UI에 표시
            
        } else {
            // 새 할 일
            dueDatePicker.date = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
            hasEndDateSwitch.isOn = false
            durationSettingsStackView.isHidden = true
            self.currentTodoAdvices = [] // 새 할 일에는 조언 없음
            populateAdvicesInStackView() // UI 초기화 (숨김 처리 등)
        }
        updateAIHelpUI() // AI 버튼 상태 및 조언 UI 업데이트
    }
    
    // 새 함수: AI 조언들을 스택뷰에 표시
    private func populateAdvicesInStackView() {
        // 기존 뷰들 제거
        aiAdviceStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if currentTodoAdvices.isEmpty {
            aiAdviceStackView.isHidden = true
            return
        }

        aiAdviceStackView.isHidden = false
        for adviceText in currentTodoAdvices {
            let adviceLabel = UILabel()
            adviceLabel.text = "💡 " + adviceText // 아이콘 추가
            adviceLabel.numberOfLines = 0
            adviceLabel.font = .systemFont(ofSize: 14)
            adviceLabel.textColor = .darkGray
            
            // 롱프레스 제스처 추가 (클립보드 복사)
            adviceLabel.isUserInteractionEnabled = true
            let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressOnAdvice(_:)))
            adviceLabel.addGestureRecognizer(longPressRecognizer)
            
            aiAdviceStackView.addArrangedSubview(adviceLabel)
        }
    }
    
    // 기존 롱프레스 핸들러 (UILabel에서 직접 텍스트 가져오도록 수정 가능)
    @objc private func handleLongPressOnAdvice(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            guard let label = gestureRecognizer.view as? UILabel, let textToCopy = label.text else { return }
            
            // "💡 " 접두사 제거 후 복사
            let actualAdvice = textToCopy.starts(with: "💡 ") ? String(textToCopy.dropFirst(3)) : textToCopy
            
            UIPasteboard.general.string = actualAdvice
            showAlert(title: "복사됨", message: "AI 조언이 클립보드에 복사되었습니다.")
        }
    }

    @objc private func didTapCancelButton() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func didTapSaveButton() {
        guard let title = titleTextField.text, !title.isEmpty else {
            showAlert(title: "오류", message: "할 일 제목을 입력해주세요.")
            return
        }

        let dueDate = dueDatePicker.date
        let notes = notesTextView.text
        let priority = prioritySegmentedControl.selectedSegmentIndex
        
        // 기간 설정 처리
        var endDate: Date? = nil
        
        if hasEndDateSwitch.isOn {
            endDate = endDatePicker.date
            
            // 종료일이 시작일보다 빠르면 조정
            if endDate! < dueDate {
                endDate = Calendar.current.date(byAdding: .day, value: 1, to: dueDate)
            }
        }

        if var todo = todoToEdit { // 수정 모드
            todo.title = title
            todo.dueDate = dueDate
            todo.endDate = endDate
            todo.notes = notes
            todo.priority = priority
            todo.aiAdvices = self.currentTodoAdvices 

            TodoManager.shared.updateTodo(todo) { [weak self] (updatedItem: TodoItem?, error: Error?) in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if let error = error {
                        self.handleTodoManagerError(error, forAction: "수정")
                    } else if updatedItem != nil {
                        self.delegate?.didSaveTodo()
                        self.dismiss(animated: true, completion: nil)
                    } else {
                        self.showAlert(title: "오류", message: "할 일 수정에 실패했습니다. (알 수 없는 원인)")
                    }
                }
            }
        } else { // 새 할 일 추가 모드
            TodoManager.shared.addTodo(
                title: title,
                dueDate: dueDate,
                startTime: nil, // startTime 사용하지 않음
                endTime: endDate, // endDate를 endTime으로 전달
                notes: notes,
                priority: priority
            ) { [weak self] (newTodo: TodoItem?, error: Error?) in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.handleTodoManagerError(error, forAction: "추가")
                    } else if newTodo != nil {
                        self?.delegate?.didSaveTodo()
                        self?.dismiss(animated: true, completion: nil)
                    } else {
                        self?.showAlert(title: "오류", message: "할 일 추가에 실패했습니다. (알 수 없는 원인)")
                    }
                }
            }
        }
    }
    
    private func handleTodoManagerError(_ error: Error, forAction action: String) {
        _ = error as NSError // nsError 미사용
        var message = "할 일 \(action) 중 오류 발생: \(error.localizedDescription)"
        let recoverySuggestion: String? = (error as? TodoManagerError)?.recoverySuggestion
        
        // TodoManagerError의 특정 케이스에 따라 메시지 커스터마이징 가능
        if let todoError = error as? TodoManagerError {
            switch todoError {
            case .calendarAccessDenied(let specificMessage), 
                 .calendarAccessRestricted(let specificMessage),
                 .calendarWriteOnlyAccess(let specificMessage),
                 .unknownCalendarAuthorization(let specificMessage):
                message = specificMessage // TodoManagerError에 정의된 메시지 사용
            case .eventSaveFailed(_), .eventRemoveFailed(_), .eventFetchFailed(_):
                message = todoError.localizedDescription // TodoManagerError에 정의된 메시지 사용
            }
        }
        
        let alert = UIAlertController(title: "캘린더 연동 오류", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        
        if recoverySuggestion != nil && (error as? TodoManagerError)?.recoverySuggestion?.contains("설정") == true {
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
    
    // MARK: - Keyboard Handling
    @objc func keyboardWillShow(notification: NSNotification) {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
           return
        }
        var contentInset:UIEdgeInsets = self.scrollView.contentInset
        contentInset.bottom = keyboardSize.height - view.safeAreaInsets.bottom // safeArea 고려
        scrollView.contentInset = contentInset
        scrollView.scrollIndicatorInsets = contentInset
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        let contentInsets = UIEdgeInsets.zero
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
    }

    // MARK: - UITextViewDelegate
    func textViewDidBeginEditing(_ textView: UITextView) {
        // notesTextView가 편집 시작될 때, 해당 텍스트뷰가 보이도록 스크롤
        if textView == notesTextView {
            // mainStackView 내에서 notesTextView의 프레임을 scrollView 기준으로 변환
            let textViewFrameInScrollView = mainStackView.convert(notesTextView.frame, to: scrollView)
            scrollView.scrollRectToVisible(textViewFrameInScrollView, animated: true)
        }
    }

    // MARK: - AI 조언 기능 - 통합 횟수 관리
    private func updateAIHelpUI() {
        guard let currentTodo = todoToEdit else {
            // 새 할 일 추가 모드: AI 버튼 비활성화
            aiHelpButton.isEnabled = false
            aiHelpButton.setTitle("AI 조언 (저장 후 가능)", for: .disabled)
            aiHelpButton.backgroundColor = .systemGray
            return
        }

        // 🛡️ 통합된 조언 횟수 관리
        if !currentTodo.canReceiveAdvice {
            aiHelpButton.isEnabled = false
            aiHelpButton.setTitle("✔️ 이 할 일 조언 완료 (\(currentTodo.adviceUsageText))", for: .disabled)
            aiHelpButton.backgroundColor = .systemGray
        } else {
            let remainingDailyCount = AIUsageManager.shared.getRemainingCount(for: .individualTodoAdvice)
            if remainingDailyCount > 0 {
                aiHelpButton.isEnabled = true
                aiHelpButton.setTitle("AI에게 조언 구하기 (\(currentTodo.adviceUsageText), 오늘 \(remainingDailyCount)회 남음)", for: .normal)
                aiHelpButton.backgroundColor = .systemGreen
            } else {
                aiHelpButton.isEnabled = false
                aiHelpButton.setTitle("오늘 AI 조언 모두 사용 (총 3회)", for: .disabled)
                aiHelpButton.backgroundColor = .systemGray
            }
        }
    }

    @objc private func didTapAIHelpButton() {
        guard var currentTodo = todoToEdit else {
            showAlert(title: "알림", message: "할 일을 먼저 저장한 후 AI 조언을 받을 수 있습니다.")
            return
        }

        // 🛡️ 통합된 조언 횟수 체크
        guard currentTodo.canReceiveAdvice else {
             showAlert(title: "알림", message: "이 할 일에 대한 조언을 모두 사용했습니다. (\(currentTodo.adviceUsageText))")
            return
        }
        
        guard AIUsageManager.shared.getRemainingCount(for: .individualTodoAdvice) > 0 else {
            showAlert(title: "알림", message: "오늘 사용할 수 있는 AI 조언 횟수를 모두 사용했습니다.")
            return
        }

        // 🆕 향상된 컨텍스트 정보 수집
        let weeklyContext = CachedConversationManager.shared.getFormattedWeeklyHistory()
        let currentTime = Date()
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "yyyy년 MM월 dd일 HH시 mm분"
        let currentTimeString = timeFormatter.string(from: currentTime)
        
        // 현재 사용자의 다른 할 일들 가져오기
        let otherTodos = TodoManager.shared.getTodos(for: todoToEdit?.dueDate ?? Date())
            .filter { $0.id != todoToEdit?.id }
            .prefix(3) // 최대 3개만
        
        let otherTodosText = otherTodos.isEmpty ? "다른 할 일 없음" : 
            otherTodos.map { "• \($0.title) (\($0.dueDateString))" }.joined(separator: "\n")
        
        // 우선순위 텍스트 변환
        let priorityText = ["낮음", "보통", "높음"][todoToEdit?.priority ?? 0]
        
        // 마감일까지 남은 시간 계산
        let timeUntilDue = todoToEdit?.dueDate.timeIntervalSince(currentTime) ?? 0
        let hoursUntilDue = timeUntilDue / 3600
        let timeUrgencyText: String
        if hoursUntilDue < 1 {
            timeUrgencyText = "⚡️ 매우 급함 (1시간 이내)"
        } else if hoursUntilDue < 24 {
            timeUrgencyText = "🔥 오늘 내 완료"
        } else if hoursUntilDue < 72 {
            timeUrgencyText = "⏰ 이번 주 내"
        } else {
            timeUrgencyText = "📅 여유 있음"
        }
        
        let prompt = """
        📋 할 일 정보:
        • 제목: \(todoToEdit?.title ?? "알 수 없음")
        • 마감일: \(todoToEdit?.dueDateString ?? "알 수 없음") (\(timeUrgencyText))
        • 우선순위: \(priorityText)
        • 메모: \(todoToEdit?.notes?.isEmpty == false ? todoToEdit!.notes! : "없음")
        
        🕒 현재 시간: \(currentTimeString)
        
        📌 같은 날의 다른 할 일들:
        \(otherTodosText)
        
        이 할 일을 효율적으로 완료하기 위한 구체적이고 실행 가능한 조언을 2-3문장으로 해주세요. 
        시간 관리, 실행 전략, 동기부여 중에서 가장 중요한 것을 중심으로 조언해주세요.
        """
        
        let systemPrompt = """
        당신은 생산성 전문가이자 할 일 관리 코치입니다. 사용자의 구체적인 상황을 분석하여 실행 가능한 조언을 제공하세요.

        조언 가이드라인:
        1. 마감일까지의 시간을 고려한 실행 전략 제시
        2. 우선순위와 다른 할 일들과의 관계 고려
        3. 구체적인 행동 단계나 시간 배분 제안
        4. 동기부여와 실용적 팁을 균형있게 제공
        5. 친근하면서도 전문적인 톤 유지

        사용자 활동 패턴 참고:
        \(weeklyContext)
        
        이 정보를 바탕으로 개인화된 조언을 해주세요.
        """

        aiHelpActivityIndicator.startAnimating()
        aiHelpButton.isEnabled = false

        Task {
            do {
                let advice = try await ReplicateChatService.shared.getAIAdvice(prompt: prompt, systemPrompt: systemPrompt)
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.aiHelpActivityIndicator.stopAnimating()
                    
                    // 🛡️ 통합된 조언 횟수 관리
                    if currentTodo.requestAdvice() {
                        // 현재 조언을 저장
                        self.currentTodoAdvices.append(advice)
                        self.populateAdvicesInStackView() // UI 업데이트
                        
                        // 🛡️ 조언 저장 및 횟수 업데이트
                        currentTodo.hasReceivedAIAdvice = true // 하위 호환성 유지
                        currentTodo.aiAdvices = self.currentTodoAdvices // 현재 조언 목록으로 업데이트
                        currentTodo.aiAdvicesGeneratedAt = Date() // 생성 시간 기록
                        
                        // 업데이트된 할 일을 다시 설정
                        self.todoToEdit = currentTodo
                        
                        // 저장소에 업데이트
                        TodoManager.shared.updateTodo(currentTodo) { (updatedItem, error) in
                            if let error = error {
                                print("⚠️ AI 조언 저장 실패: \(error.localizedDescription)")
                            } else if updatedItem != nil {
                                print("✅ AI 조언 및 횟수가 성공적으로 저장되었습니다. (\(currentTodo.adviceUsageText))")
                            } else {
                                print("⚠️ AI 조언 저장/업데이트 후 nil이 반환되었습니다.")
                            }
                        }
                        
                        // 전체 일일 제한 횟수도 기록
                        AIUsageManager.shared.recordUsage(for: .individualTodoAdvice)
                        
                        // UI 업데이트
                        self.updateAIHelpUI() // 버튼 상태 등 UI 업데이트
                    } else {
                        print("⚠️ 조언 횟수 초과로 인해 요청이 거부되었습니다.")
                        self.showAlert(title: "알림", message: "이 할 일에 대한 조언을 모두 사용했습니다.")
                    }
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.aiHelpActivityIndicator.stopAnimating()
                    self.aiHelpButton.isEnabled = true // 실패 시 다시 활성화
                    self.updateAIHelpUI() // 원래 버튼 텍스트로 복원 등
                    
                    let errorMessage: String
                    if let serviceError = error as? ReplicateChatService.ServiceError {
                        errorMessage = serviceError.localizedDescription
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    self.showAlert(title: "AI 조언 오류", message: "조언을 받아오는 데 실패했습니다. (\(errorMessage))")
                    print("AI 조언 받기 실패: \(error)")
                }
            }
        }
    }
} 
