import UIKit

protocol AddEditTodoDelegate: AnyObject {
    func didSaveTodoItem(_ todoItem: TodoItem)
}

class AddEditTodoViewController: UIViewController {
    weak var delegate: AddEditTodoDelegate?
    var todoItem: TodoItem?
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let titleLabel = UILabel()
    private let titleTextField = UITextField()
    
    private let dueDateLabel = UILabel()
    private let dueDatePicker = UIDatePicker()
    
    private let endDateLabel = UILabel()
    private let endDateSwitch = UISwitch()
    private let endDatePicker = UIDatePicker()
    
    private let priorityLabel = UILabel()
    private let prioritySegmentedControl = UISegmentedControl(items: ["낮음", "보통", "높음"])
    
    private let categoryLabel = UILabel()
    private let categorySegmentedControl = UISegmentedControl(items: ["수면", "웰니스", "업무", "개인", "건강"])
    
    private let notesLabel = UILabel()
    private let notesTextView = UITextView()
    
    private var isLoading = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupNavigationBar()
        populateFields()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = todoItem == nil ? "할 일 추가" : "할 일 편집"
        
        // Scroll View
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        view.addSubview(scrollView)
        
        // Content View
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Title
        titleLabel.text = "제목 *"
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        titleTextField.borderStyle = .roundedRect
        titleTextField.placeholder = "할 일을 입력하세요"
        titleTextField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleTextField)
        
        // Due Date
        dueDateLabel.text = "시작 날짜"
        dueDateLabel.font = .systemFont(ofSize: 16, weight: .medium)
        dueDateLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dueDateLabel)
        
        dueDatePicker.datePickerMode = .dateAndTime
        dueDatePicker.preferredDatePickerStyle = .compact
        dueDatePicker.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dueDatePicker)
        
        // End Date
        endDateLabel.text = "종료 날짜 (연속 일정)"
        endDateLabel.font = .systemFont(ofSize: 16, weight: .medium)
        endDateLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(endDateLabel)
        
        endDateSwitch.translatesAutoresizingMaskIntoConstraints = false
        endDateSwitch.addTarget(self, action: #selector(endDateSwitchChanged), for: .valueChanged)
        contentView.addSubview(endDateSwitch)
        
        endDatePicker.datePickerMode = .dateAndTime
        endDatePicker.preferredDatePickerStyle = .compact
        endDatePicker.translatesAutoresizingMaskIntoConstraints = false
        endDatePicker.isHidden = true
        contentView.addSubview(endDatePicker)
        
        // Priority
        priorityLabel.text = "우선순위"
        priorityLabel.font = .systemFont(ofSize: 16, weight: .medium)
        priorityLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(priorityLabel)
        
        prioritySegmentedControl.selectedSegmentIndex = 1 // 기본값: 보통
        prioritySegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(prioritySegmentedControl)
        
        // Category
        categoryLabel.text = "카테고리"
        categoryLabel.font = .systemFont(ofSize: 16, weight: .medium)
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(categoryLabel)
        
        categorySegmentedControl.selectedSegmentIndex = 0 // 기본값: 수면
        categorySegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(categorySegmentedControl)
        
        // Notes
        notesLabel.text = "메모"
        notesLabel.font = .systemFont(ofSize: 16, weight: .medium)
        notesLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(notesLabel)
        
        notesTextView.layer.borderColor = UIColor.systemGray4.cgColor
        notesTextView.layer.borderWidth = 1
        notesTextView.layer.cornerRadius = 8
        notesTextView.font = .systemFont(ofSize: 16)
        notesTextView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(notesTextView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll View
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content View
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            titleTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            titleTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // Due Date
            dueDateLabel.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 24),
            dueDateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            dueDateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            dueDatePicker.topAnchor.constraint(equalTo: dueDateLabel.bottomAnchor, constant: 8),
            dueDatePicker.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            dueDatePicker.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // End Date
            endDateLabel.topAnchor.constraint(equalTo: dueDatePicker.bottomAnchor, constant: 24),
            endDateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            endDateSwitch.centerYAnchor.constraint(equalTo: endDateLabel.centerYAnchor),
            endDateSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            endDatePicker.topAnchor.constraint(equalTo: endDateLabel.bottomAnchor, constant: 8),
            endDatePicker.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            endDatePicker.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Priority
            priorityLabel.topAnchor.constraint(equalTo: endDatePicker.bottomAnchor, constant: 24),
            priorityLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            priorityLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            prioritySegmentedControl.topAnchor.constraint(equalTo: priorityLabel.bottomAnchor, constant: 8),
            prioritySegmentedControl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            prioritySegmentedControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Category
            categoryLabel.topAnchor.constraint(equalTo: prioritySegmentedControl.bottomAnchor, constant: 24),
            categoryLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            categoryLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            categorySegmentedControl.topAnchor.constraint(equalTo: categoryLabel.bottomAnchor, constant: 8),
            categorySegmentedControl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            categorySegmentedControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Notes
            notesLabel.topAnchor.constraint(equalTo: categorySegmentedControl.bottomAnchor, constant: 24),
            notesLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            notesLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            notesTextView.topAnchor.constraint(equalTo: notesLabel.bottomAnchor, constant: 8),
            notesTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            notesTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            notesTextView.heightAnchor.constraint(equalToConstant: 100),
            notesTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupNavigationBar() {
        let cancelButton = UIBarButtonItem(title: "취소", style: .plain, target: self, action: #selector(cancelButtonTapped))
        let saveButton = UIBarButtonItem(title: "저장", style: .done, target: self, action: #selector(saveButtonTapped))
        
        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.rightBarButtonItem = saveButton
        
        // 편집 모드일 때 삭제 버튼 추가
        if todoItem != nil {
            let deleteButton = UIBarButtonItem(title: "삭제", style: .plain, target: self, action: #selector(deleteButtonTapped))
            deleteButton.tintColor = .systemRed
            navigationItem.leftBarButtonItems = [cancelButton, deleteButton]
        }
    }
    
    private func populateFields() {
        guard let todoItem = todoItem else { return }
        
        titleTextField.text = todoItem.title
        dueDatePicker.date = todoItem.dueDate
        
        if let endDate = todoItem.endDate {
            endDateSwitch.isOn = true
            endDatePicker.isHidden = false
            endDatePicker.date = endDate
        }
        
        prioritySegmentedControl.selectedSegmentIndex = todoItem.priority
        
        if let category = todoItem.category {
            switch category {
            case .sleep: categorySegmentedControl.selectedSegmentIndex = 0
            case .wellness: categorySegmentedControl.selectedSegmentIndex = 1
            case .work: categorySegmentedControl.selectedSegmentIndex = 2
            case .personal: categorySegmentedControl.selectedSegmentIndex = 3
            case .health: categorySegmentedControl.selectedSegmentIndex = 4
            }
        }
        
        notesTextView.text = todoItem.notes
    }
    
    // MARK: - Actions
    @objc private func endDateSwitchChanged() {
        endDatePicker.isHidden = !endDateSwitch.isOn
        
        if endDateSwitch.isOn {
            // 종료 날짜를 시작 날짜보다 나중으로 설정
            let calendar = Calendar.current
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: dueDatePicker.date) {
                endDatePicker.date = nextDay
            }
        }
    }
    
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func deleteButtonTapped() {
        guard let todoItem = todoItem else { return }
        
        let alert = UIAlertController(
            title: "할 일 삭제",
            message: "'\(todoItem.title)'을(를) 삭제하시겠습니까?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "삭제", style: .destructive) { [weak self] _ in
            self?.performDelete(todoItem)
        })
        
        present(alert, animated: true)
    }
    
    private func performDelete(_ todoItem: TodoItem) {
        isLoading = true
        navigationItem.rightBarButtonItem?.isEnabled = false
        
        TodoManager.shared.deleteTodo(withId: todoItem.id) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.navigationItem.rightBarButtonItem?.isEnabled = true
                
                if success {
                    self?.delegate?.didSaveTodoItem(todoItem) // 삭제도 변경사항이므로 알림
                    self?.dismiss(animated: true)
                } else {
                    let errorMessage = error?.localizedDescription ?? "알 수 없는 오류가 발생했습니다."
                    self?.showAlert(message: "삭제 실패: \(errorMessage)")
                }
            }
        }
    }
    
    @objc private func saveButtonTapped() {
        guard !isLoading else { return }
        
        // 강화된 입력 검증
        guard let title = titleTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            showAlert(message: "제목을 입력해주세요.")
            titleTextField.becomeFirstResponder()
            return
        }
        
        // 종료 날짜 검증
        if endDateSwitch.isOn && endDatePicker.date <= dueDatePicker.date {
            showAlert(message: "종료 날짜는 시작 날짜보다 늦어야 합니다.")
            return
        }
        
        isLoading = true
        navigationItem.rightBarButtonItem?.isEnabled = false
        
        let priority = prioritySegmentedControl.selectedSegmentIndex
        let endDate = endDateSwitch.isOn ? endDatePicker.date : nil
        let notes = notesTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesText = notes?.isEmpty == true ? nil : notes
        
        // 카테고리 매핑
        let categories: [TodoItem.Category] = [.sleep, .wellness, .work, .personal, .health]
        let selectedCategory = categories[categorySegmentedControl.selectedSegmentIndex]
        
        if let existingTodo = todoItem {
            // 기존 할 일 수정
            var updatedTodo = existingTodo
            updatedTodo.title = title
            updatedTodo.dueDate = dueDatePicker.date
            updatedTodo.endDate = endDate
            updatedTodo.priority = priority
            updatedTodo.category = selectedCategory
            updatedTodo.notes = notesText
            
            TodoManager.shared.updateTodo(updatedTodo) { [weak self] todo, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.navigationItem.rightBarButtonItem?.isEnabled = true
                    
                    if let error = error {
                        self?.showAlert(message: "저장 실패: \(error.localizedDescription)")
                    } else if let todo = todo {
                        self?.delegate?.didSaveTodoItem(todo)
                        self?.dismiss(animated: true)
                    }
                }
            }
        } else {
            // 새 할 일 추가
            TodoManager.shared.addTodo(
                title: title,
                dueDate: dueDatePicker.date,
                startTime: nil,
                endTime: endDate,
                notes: notesText,
                priority: priority
            ) { [weak self] todo, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.navigationItem.rightBarButtonItem?.isEnabled = true
                    
                    if let error = error {
                        self?.showAlert(message: "저장 실패: \(error.localizedDescription)")
                    } else if let todo = todo {
                        // 카테고리 설정 (TodoManager.addTodo에서 지원하지 않으므로 별도 업데이트)
                        var updatedTodo = todo
                        updatedTodo.category = selectedCategory
                        
                        TodoManager.shared.updateTodo(updatedTodo) { [weak self] finalTodo, updateError in
                            DispatchQueue.main.async {
                                if let updateError = updateError {
                                    print("카테고리 업데이트 실패: \(updateError)")
                                }
                                self?.delegate?.didSaveTodoItem(finalTodo ?? updatedTodo)
                                self?.dismiss(animated: true)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "알림", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Keyboard Handling
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardHeight = keyboardFrame.cgRectValue.height
        scrollView.contentInset.bottom = keyboardHeight
        scrollView.scrollIndicatorInsets.bottom = keyboardHeight
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        scrollView.contentInset.bottom = 0
        scrollView.scrollIndicatorInsets.bottom = 0
    }
} 
