import UIKit

// MARK: - TodoListCellDelegate
protocol TodoListCellDelegate: AnyObject {
    func todoListCell(_ cell: TodoListCell, didToggleItem item: TodoItem, at index: Int)
    func todoListCell(_ cell: TodoListCell, didDeleteItem item: TodoItem, at index: Int)
    func todoListCell(_ cell: TodoListCell, didRequestEditItem item: TodoItem, at index: Int)
    func todoListCellDidRequestAddItem(_ cell: TodoListCell)
    func todoListCellDidRequestDailyAdvice(_ cell: TodoListCell, for items: [TodoItem], on date: Date)
    func todoListCellDidRequestIndividualAdvice(_ cell: TodoListCell, for item: TodoItem)
    func todoListCell(_ cell: TodoListCell, didTapAdviceFor item: TodoItem)
}

/// 할 일 목록을 표시하는 컬렉션 뷰 셀
class TodoListCell: UICollectionViewCell {
    static let reuseIdentifier = "TodoListCell"

    weak var delegate: TodoListCellDelegate?
    private var todoItems: [TodoItem] = []
    private var currentDate: Date = Date()
    
    // MARK: - UI Components
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIDesignSystem.Colors.adaptiveTertiaryBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "오늘의 할 일"
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = UIDesignSystem.Colors.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontForContentSizeCategory = true
        // 버튼 텍스트가 잘리지 않도록 타이틀은 수평 압축 저항을 낮춤
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()
    
    private let addButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("+ 추가", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.setTitleColor(UIDesignSystem.Colors.primaryText, for: .normal)
        button.backgroundColor = UIDesignSystem.Colors.adaptiveSecondaryBackground
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let dailyAdviceButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("오늘 전체 조언 받기", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        button.setTitleColor(UIDesignSystem.Colors.primaryText, for: .normal)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        return button
    }()
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.showsVerticalScrollIndicator = false
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()
    
    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "할 일을 추가해보세요! 😊"
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIDesignSystem.Colors.secondaryText
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupTableView()
        setupActions()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupTableView()
        setupActions()
    }
    
    // MARK: - Setup
    private func setupUI() {
        contentView.addSubview(containerView)
        containerView.addSubview(headerView)
        containerView.addSubview(tableView)
        containerView.addSubview(emptyStateLabel)

        headerView.addSubview(titleLabel)
        headerView.addSubview(dailyAdviceButton)
        headerView.addSubview(addButton)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            headerView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            headerView.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            dailyAdviceButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            dailyAdviceButton.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -8),
            // 너비는 내용에 맞게 자동 확장 (기존 텍스트 잘림 방지)
            dailyAdviceButton.heightAnchor.constraint(equalToConstant: 32),

            addButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            addButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 60),
            addButton.heightAnchor.constraint(equalToConstant: 32),

            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            tableView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),

            emptyStateLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor)
        ])
    }
    
    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(TodoItemTableViewCell.self, forCellReuseIdentifier: TodoItemTableViewCell.reuseIdentifier)
        
        // 테이블뷰 스와이프 액션이 부모 스와이프보다 우선되도록 설정
        tableView.delaysContentTouches = false
        tableView.canCancelContentTouches = true
        
        // 스와이프 액션이 확실히 작동하도록 추가 설정
        tableView.allowsSelection = true
        tableView.isScrollEnabled = true
        tableView.isUserInteractionEnabled = true
        
        // 동적 셀 높이 활성화
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension
        
        // iOS 11+ 스와이프 액션 지원 확인
        if #available(iOS 11.0, *) {
            // iOS 11+에서는 기본적으로 스와이프 액션이 지원됨
            UnifiedLogger.shared.debug("UITableView 스와이프 액션이 활성화되었습니다", category: .ui)
        }
    }
    
    private func setupActions() {
        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        dailyAdviceButton.addTarget(self, action: #selector(dailyAdviceButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Configuration
    func configure(with items: [TodoItem]) {
        self.currentDate = Date()
        configureInternal(with: items)
    }

    func configure(with items: [TodoItem], for date: Date) {
        self.currentDate = date
        configureInternal(with: items)
    }

    private func configureInternal(with items: [TodoItem]) {
        // 제목이 비어있는 항목은 '제목 없음'으로 보정
        self.todoItems = items.map { it in
            var t = it
            if t.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                t.title = "제목 없음"
            }
            return t
        }
        tableView.reloadData()
        updateEmptyState()

        UnifiedLogger.shared.logTodo("TodoListCell configured with \\(self.todoItems.count) items")

        // 스와이프 액션 사용 가능 상태 로깅
        for (index, item) in self.todoItems.enumerated() {
            UnifiedLogger.shared.logTodo("  아이템[\\(index)]: \\(item.title)")
        }

        // 테이블뷰 상태 로깅
        UnifiedLogger.shared.debug("테이블뷰 설정 - 데이터소스: \\(tableView.dataSource != nil), 델리게이트: \\(tableView.delegate != nil)", category: .ui)
        UnifiedLogger.shared.debug("테이블뷰 인터랙션 - 사용자인터랙션: \\(tableView.isUserInteractionEnabled), 선택가능: \\(tableView.allowsSelection)", category: .ui)

        // UX: 오늘 전체 조언 버튼 상태 갱신 (일일 1회 제한 반영)
        let remainingOverall = AIUsageManager.shared.getRemainingCount(for: .overallTodoAdvice)
        if remainingOverall > 0 {
            dailyAdviceButton.isEnabled = true
            dailyAdviceButton.setTitle("오늘 전체 조언 받기", for: .normal)
            dailyAdviceButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
            dailyAdviceButton.setTitleColor(UIDesignSystem.Colors.primaryText, for: .normal)
            dailyAdviceButton.alpha = 1.0
        } else {
            dailyAdviceButton.isEnabled = false
            dailyAdviceButton.setTitle("오늘 전체 조언 사용 완료", for: .disabled)
            dailyAdviceButton.backgroundColor = UIDesignSystem.Colors.adaptiveSecondaryBackground
            dailyAdviceButton.setTitleColor(UIDesignSystem.Colors.secondaryText, for: .disabled)
            dailyAdviceButton.alpha = 0.9
        }
    }
    
    // 외부에서 카드 헤더 타이틀을 동적으로 지정하기 위한 API
    func setHeaderTitle(_ title: String) {
        titleLabel.text = title
    }
    
    @objc private func dailyAdviceButtonTapped() {
        delegate?.todoListCellDidRequestDailyAdvice(self, for: todoItems, on: currentDate)
        UnifiedLogger.shared.debug("TodoListCell daily advice button tapped", category: .ui)
    }

    // MARK: - Actions
    @objc private func addButtonTapped() {
        delegate?.todoListCellDidRequestAddItem(self)
        UnifiedLogger.shared.debug("TodoListCell add button tapped", category: .ui)
    }
    
    // MARK: - Helper Methods
    private func updateEmptyState() {
        let isEmpty = todoItems.isEmpty
        emptyStateLabel.isHidden = !isEmpty
        tableView.isHidden = isEmpty
    }
    
    // MARK: - Lifecycle
    override func prepareForReuse() {
        super.prepareForReuse()
        todoItems.removeAll()
        tableView.reloadData()
        updateEmptyState()
    }
}

// MARK: - UITableViewDataSource
extension TodoListCell: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return todoItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TodoItemTableViewCell.reuseIdentifier, for: indexPath) as! TodoItemTableViewCell
        let item = todoItems[indexPath.row]
        cell.configure(with: item, delegate: self, index: indexPath.row)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension TodoListCell: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    // 스와이프 액션 메뉴 구현 (수정/삭제)
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        UnifiedLogger.shared.debug("스와이프 액션 요청: indexPath=\(indexPath.row), 전체 아이템 \(todoItems.count)개", category: .ui)
        
        guard indexPath.row < todoItems.count else { 
            UnifiedLogger.shared.debug("인덱스 범위 초과: \(indexPath.row) >= \(todoItems.count)", category: .ui)
            return nil 
        }
        
        let item = todoItems[indexPath.row]
        UnifiedLogger.shared.debug("스와이프 액션 대상 아이템: \(item.title)", category: .ui)
        
        // 삭제 액션
        let deleteAction = UIContextualAction(style: .destructive, title: "삭제") { [weak self] _, _, completion in
            UnifiedLogger.shared.debug("삭제 액션 실행: \(item.title)", category: .ui)
            guard let self = self else {
                completion(false)
                return
            }
            self.delegate?.todoListCell(self, didDeleteItem: item, at: indexPath.row)
            completion(true)
        }
        deleteAction.backgroundColor = .systemRed
        deleteAction.image = UIImage(systemName: "trash")
        
        // 수정 액션
        let editAction = UIContextualAction(style: .normal, title: "수정") { [weak self] _, _, completion in
            UnifiedLogger.shared.debug("수정 액션 실행: \(item.title)", category: .ui)
            guard let self = self else {
                completion(false)
                return
            }
            self.delegate?.todoListCell(self, didRequestEditItem: item, at: indexPath.row)
            completion(true)
        }
        editAction.backgroundColor = .systemBlue
        editAction.image = UIImage(systemName: "pencil")
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, editAction])
        configuration.performsFirstActionWithFullSwipe = false // 전체 스와이프로 삭제 방지
        
        UnifiedLogger.shared.debug("스와이프 액션 구성 완료", category: .ui)
        return configuration
    }
}

// MARK: - TodoItemCellDelegate
extension TodoListCell: TodoItemCellDelegate {
    func todoItemCell(_ cell: TodoItemTableViewCell, didToggleItem item: TodoItem, at index: Int) {
        delegate?.todoListCell(self, didToggleItem: item, at: index)
    }

    func todoItemCell(_ cell: TodoItemTableViewCell, didTapTitle item: TodoItem, at index: Int) {
        delegate?.todoListCellDidRequestIndividualAdvice(self, for: item)
    }

    func todoItemCell(_ cell: TodoItemTableViewCell, didTapAdvice item: TodoItem, at index: Int) {
        delegate?.todoListCell(self, didTapAdviceFor: item)
    }
}

// MARK: - TodoItemTableViewCell
protocol TodoItemCellDelegate: AnyObject {
    func todoItemCell(_ cell: TodoItemTableViewCell, didToggleItem item: TodoItem, at index: Int)
    func todoItemCell(_ cell: TodoItemTableViewCell, didTapTitle item: TodoItem, at index: Int)
    func todoItemCell(_ cell: TodoItemTableViewCell, didTapAdvice item: TodoItem, at index: Int)
}

class TodoItemTableViewCell: UITableViewCell {
    static let reuseIdentifier = "TodoItemTableViewCell"
    
    weak var delegate: TodoItemCellDelegate?
    private var todoItem: TodoItem?
    private var itemIndex: Int = 0
    
    // MARK: - UI Components
    private let checkboxButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "circle"), for: .normal)
        button.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .selected)
        button.tintColor = .secondaryLabel // 기본은 회색 톤으로 대비 확보
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = UIDesignSystem.Colors.primaryText
        label.numberOfLines = 0 // 멀티라인 지원
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let priorityIndicator: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let dueDateLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIDesignSystem.Colors.secondaryText
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let adviceButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("조언 받기", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)
        button.setTitleColor(.systemBlue, for: .normal)
        button.layer.cornerRadius = 6
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }()
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        setupActions()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupActions()
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(checkboxButton)
        contentView.addSubview(titleLabel)
        contentView.addSubview(dueDateLabel)
        contentView.addSubview(priorityIndicator)
        contentView.addSubview(adviceButton)
        
        NSLayoutConstraint.activate([
            checkboxButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            checkboxButton.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 12),
            checkboxButton.widthAnchor.constraint(equalToConstant: 24),
            checkboxButton.heightAnchor.constraint(equalToConstant: 24),
            checkboxButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: checkboxButton.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: priorityIndicator.leadingAnchor, constant: -8),
            
            dueDateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dueDateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            dueDateLabel.trailingAnchor.constraint(lessThanOrEqualTo: adviceButton.leadingAnchor, constant: -8),
            dueDateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            priorityIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            priorityIndicator.widthAnchor.constraint(equalToConstant: 8),
            priorityIndicator.heightAnchor.constraint(equalToConstant: 8),
            priorityIndicator.centerYAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor),

            adviceButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            adviceButton.centerYAnchor.constraint(equalTo: dueDateLabel.centerYAnchor)
        ])
    }
    
    private func setupActions() {
        checkboxButton.addTarget(self, action: #selector(checkboxTapped), for: .touchUpInside)

        // 글자 탭 제스처 추가
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(titleLabelTapped))
        titleLabel.addGestureRecognizer(tapGesture)
        titleLabel.isUserInteractionEnabled = true
        adviceButton.addTarget(self, action: #selector(adviceButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Configuration
    func configure(with item: TodoItem, delegate: TodoItemCellDelegate, index: Int) {
        self.todoItem = item
        self.delegate = delegate
        self.itemIndex = index
        
        let rawTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeTitle = rawTitle.isEmpty ? "제목 없음" : rawTitle
        checkboxButton.isSelected = item.isCompleted
        
        // 상태별 텍스트/스타일 지정
        if item.isCompleted {
            // 완료: 취소선 + 흐린 색상
            let attributedString = NSAttributedString(
                string: safeTitle,
                attributes: [
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: UIDesignSystem.Colors.secondaryText
                ]
            )
            titleLabel.attributedText = attributedString
            titleLabel.textColor = UIDesignSystem.Colors.secondaryText
            titleLabel.alpha = 0.8
            dueDateLabel.alpha = 0.7
            checkboxButton.tintColor = .systemGreen
        } else {
            // 미완료: 일반 텍스트 확실하게 노출 (재사용 잔여 속성 초기화)
            titleLabel.attributedText = nil
            titleLabel.text = safeTitle
            titleLabel.textColor = UIDesignSystem.Colors.primaryText
            titleLabel.alpha = 1.0
            dueDateLabel.alpha = 0.95
            checkboxButton.tintColor = .label
        }
        
        // 마감 시간은 한국어 표기로 항상 표시
        dueDateLabel.text = item.dueDateString
        
        // 우선순위 표시 (Int 타입으로 변경)
        switch item.priority {
        case 2: // high
            priorityIndicator.backgroundColor = UIDesignSystem.Colors.error
            priorityIndicator.isHidden = false
        case 1: // medium
            priorityIndicator.backgroundColor = UIDesignSystem.Colors.warning
            priorityIndicator.isHidden = false
        case 0: // low
            priorityIndicator.isHidden = true
        default:
            priorityIndicator.isHidden = true
        }

        // 조언 버튼 상태 갱신
        if let adv = item.aiAdvices?.last, !adv.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            adviceButton.setTitle("조언 내용 보기", for: .normal)
            adviceButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.08)
            adviceButton.setTitleColor(.systemGreen, for: .normal)
        } else {
            adviceButton.setTitle("조언 받기", for: .normal)
            adviceButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)
            adviceButton.setTitleColor(.systemBlue, for: .normal)
        }
    }
    
    // MARK: - Actions
    @objc private func checkboxTapped() {
        guard let item = todoItem else { return }
        delegate?.todoItemCell(self, didToggleItem: item, at: itemIndex)
        UnifiedLogger.shared.logTodo("TodoItem toggled: \(item.title)")
    }

    @objc private func titleLabelTapped() {
        guard let item = todoItem else { return }
        delegate?.todoItemCell(self, didTapTitle: item, at: itemIndex)
        UnifiedLogger.shared.logTodo("TodoItem title tapped: \(item.title)")
    }

    @objc private func adviceButtonTapped() {
        guard let item = todoItem else { return }
        delegate?.todoItemCell(self, didTapAdvice: item, at: itemIndex)
        UnifiedLogger.shared.logTodo("TodoItem advice button tapped: \(item.title)")
    }
    
    // MARK: - Lifecycle
    override func prepareForReuse() {
        super.prepareForReuse()
        todoItem = nil
        titleLabel.attributedText = nil
        titleLabel.text = nil
        checkboxButton.isSelected = false
        priorityIndicator.isHidden = true
        adviceButton.setTitle("조언 받기", for: .normal)
        adviceButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)
        adviceButton.setTitleColor(.systemBlue, for: .normal)
    }
}
