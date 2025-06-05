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
        label.text = "마감일/시간:"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        return label
    }()
    private let dueDatePicker: UIDatePicker = {
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .dateAndTime // 날짜와 시간 모두 선택
        if #available(iOS 13.4, *) {
            datePicker.preferredDatePickerStyle = .wheels // 또는 .inline, .compact
        } else {
            // Fallback on earlier versions
        }
        datePicker.locale = Locale(identifier: "ko_KR")
        // 분 단위를 5분 간격으로 설정 (선택적)
        // datePicker.minuteInterval = 5
        return datePicker
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
        button.backgroundColor = .systemBlue
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
        button.backgroundColor = .systemGreen
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
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(didTapCancelButton))
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

    // 수정: configureForEditing -> configureScreenForTodo로 변경하고 조언 로드 로직 추가
    private func configureScreenForTodo() {
        if let todo = todoToEdit {
            titleTextField.text = todo.title
            dueDatePicker.date = todo.dueDate
            notesTextView.text = todo.notes
            prioritySegmentedControl.selectedSegmentIndex = todo.priority
            
            // 저장된 AI 조언 로드
            self.currentTodoAdvices = todo.aiAdvices ?? []
            populateAdvicesInStackView() // 로드된 조언 UI에 표시
            
        } else {
            // 새 할 일
            dueDatePicker.date = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
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

        // AI 조언은 didTapAIHelpButton에서 todoToEdit에 이미 반영되었거나,
        // 새 할 일의 경우 여기서 반영할 필요 없음 (저장 후 조언 가능)
        // 따라서 여기서 aiAdvices를 직접 건드릴 필요는 없음.
        // todoToEdit가 생성/수정될 때 이미 aiAdvices 필드를 가지고 있음.

        if var todo = todoToEdit { // 수정 모드
            todo.title = title
            todo.dueDate = dueDate
            todo.notes = notes
            todo.priority = priority
            // todo.aiAdvices는 AI 조언 받을 때 이미 self.todoToEdit에 업데이트되었으므로
            // 이 todo 변수에 다시 할당할 필요 없이 TodoManager가 알아서 처리.
            // (만약 todoToEdit이 class가 아닌 struct 복사본이라면 여기서 todo.aiAdvices = self.currentTodoAdvices 필요)
            // TodoItem이 struct이므로 아래와 같이 명시적 할당 필요
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
            // 새 TodoItem 생성 시 aiAdvices는 nil 또는 빈 배열로 초기화됨 (TodoItem 기본값)
            // AI 조언은 저장 후에만 가능하므로, 여기서 aiAdvices를 설정할 필요 없음.
            TodoManager.shared.addTodo(
                title: title,
                dueDate: dueDate,
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
        let nsError = error as NSError
        var message = "할 일 \(action) 중 오류 발생: \(error.localizedDescription)"
        var recoverySuggestion: String? = (error as? TodoManagerError)?.recoverySuggestion
        
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

    // MARK: - AI 조언 기능
    private func updateAIHelpUI() {
        guard let currentTodo = todoToEdit else {
            // 새 할 일 추가 모드: AI 버튼 비활성화
            aiHelpButton.isEnabled = false
            aiHelpButton.setTitle("AI 조언 (저장 후 가능)", for: .disabled)
            aiHelpButton.backgroundColor = .systemGray
            return
        }

        if currentTodo.hasReceivedAIAdvice {
            aiHelpButton.isEnabled = false
            aiHelpButton.setTitle("✔️ 이 할 일 조언 완료", for: .disabled)
            aiHelpButton.backgroundColor = .systemGray
        } else {
            let remainingDailyCount = AIUsageManager.shared.getRemainingDailyIndividualAdviceCount()
            if remainingDailyCount > 0 {
                aiHelpButton.isEnabled = true
                aiHelpButton.setTitle("AI에게 조언 구하기 (오늘 \\(remainingDailyCount)회 남음)", for: .normal)
                aiHelpButton.backgroundColor = .systemGreen
            } else {
                aiHelpButton.isEnabled = false
                aiHelpButton.setTitle("오늘 AI 조언 모두 사용 (총 2회)", for: .disabled)
                aiHelpButton.backgroundColor = .systemGray
            }
        }
    }

    @objc private func didTapAIHelpButton() {
        guard todoToEdit != nil else {
            showAlert(title: "알림", message: "할 일을 먼저 저장한 후 AI 조언을 받을 수 있습니다.")
            return
        }

        guard todoToEdit?.hasReceivedAIAdvice == false else {
             showAlert(title: "알림", message: "이 할 일에 대한 AI 조언을 이미 받았습니다.")
            return
        }
        
        guard AIUsageManager.shared.getRemainingDailyIndividualAdviceCount() > 0 else {
            showAlert(title: "알림", message: "오늘 사용할 수 있는 AI 조언 횟수를 모두 사용했습니다.")
            return
        }

        let weeklyContext = CachedConversationManager.shared.getFormattedWeeklyHistory() // 주간 컨텍스트 로드
        let prompt = "다음 할 일에 대한 구체적이고 실행 가능한 조언을 1-2문장으로 짧고 친근하게 해줘: \n제목: \(todoToEdit?.title ?? "알 수 없음")\n마감일: \(todoToEdit?.dueDateString ?? "알 수 없음")\n메모: \(todoToEdit?.notes ?? "없음")"
        let systemPrompt = """
        당신은 사용자의 할 일 관리를 돕는 친절한 AI 어시스턴트입니다. 할 일을 더 잘 완료할 수 있도록 동기를 부여하고 실용적인 팁을 제공해주세요.

        다음은 사용자의 지난 활동 요약입니다. 이를 참고하여 조언해주세요:
        \(weeklyContext)
        """

        aiHelpActivityIndicator.startAnimating()
        aiHelpButton.isEnabled = false

        Task {
            do {
                let advice = try await ReplicateChatService.shared.getAIAdvice(prompt: prompt, systemPrompt: systemPrompt)
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.aiHelpActivityIndicator.stopAnimating()
                    
                    self.currentTodoAdvices.append(advice)
                    self.populateAdvicesInStackView() // UI 업데이트
                    
                    // 조언 저장
                    self.todoToEdit?.hasReceivedAIAdvice = true // 조언 받음 플래그 설정
                    self.todoToEdit?.aiAdvices = self.currentTodoAdvices // 현재 조언 목록으로 업데이트
                    self.todoToEdit?.aiAdvicesGeneratedAt = Date() // 이 줄 추가
                    
                    if let todoToUpdateWithAdvice = self.todoToEdit {
                        TodoManager.shared.updateTodo(todoToUpdateWithAdvice) { (updatedItem, error) in
                            if let error = error {
                                print("AI 조언 저장 실패: \(error.localizedDescription)")
                            } else if updatedItem != nil {
                                print("AI 조언이 성공적으로 저장 및 업데이트되었습니다.")
                            } else {
                                print("AI 조언 저장/업데이트 후 nil이 반환되었습니다.")
                            }
                        }
                    }
                    
                    AIUsageManager.shared.recordIndividualAdviceUsed() // 수정: recordAdviceUsed -> recordIndividualAdviceUsed
                    self.updateAIHelpUI() // 버튼 상태 등 UI 업데이트
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
