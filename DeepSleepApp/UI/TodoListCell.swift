import UIKit

// MARK: - TodoListCellDelegate
protocol TodoListCellDelegate: AnyObject {
    func todoListCell(_ cell: TodoListCell, didToggleItem item: TodoItem, at index: Int)
    func todoListCell(_ cell: TodoListCell, didDeleteItem item: TodoItem, at index: Int)
    func todoListCellDidRequestAddItem(_ cell: TodoListCell)
}

/// 할 일 목록을 표시하는 컬렉션 뷰 셀
class TodoListCell: UICollectionViewCell {
    static let reuseIdentifier = "TodoListCell"
    
    weak var delegate: TodoListCellDelegate?
    private var todoItems: [TodoItem] = []
    
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
    }
    
    private func setupActions() {
        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Configuration
    func configure(with items: [TodoItem]) {
        self.todoItems = items
        tableView.reloadData()
        updateEmptyState()
        
        DebugManager.shared.logTodo("TodoListCell configured with \(items.count) items")
    }
    
    // MARK: - Actions
    @objc private func addButtonTapped() {
        delegate?.todoListCellDidRequestAddItem(self)
        DebugManager.shared.logUI("TodoListCell add button tapped")
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
        return 44
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let item = todoItems[indexPath.row]
            delegate?.todoListCell(self, didDeleteItem: item, at: indexPath.row)
        }
    }
}

// MARK: - TodoItemCellDelegate
extension TodoListCell: TodoItemCellDelegate {
    func todoItemCell(_ cell: TodoItemTableViewCell, didToggleItem item: TodoItem, at index: Int) {
        delegate?.todoListCell(self, didToggleItem: item, at: index)
    }
}

// MARK: - TodoItemTableViewCell
protocol TodoItemCellDelegate: AnyObject {
    func todoItemCell(_ cell: TodoItemTableViewCell, didToggleItem item: TodoItem, at index: Int)
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
        button.tintColor = UIColor.systemBlue
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = UIDesignSystem.Colors.primaryText
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let priorityIndicator: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
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
        contentView.addSubview(priorityIndicator)
        
        NSLayoutConstraint.activate([
            checkboxButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            checkboxButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkboxButton.widthAnchor.constraint(equalToConstant: 24),
            checkboxButton.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: checkboxButton.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: priorityIndicator.leadingAnchor, constant: -8),
            
            priorityIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            priorityIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            priorityIndicator.widthAnchor.constraint(equalToConstant: 8),
            priorityIndicator.heightAnchor.constraint(equalToConstant: 8)
        ])
    }
    
    private func setupActions() {
        checkboxButton.addTarget(self, action: #selector(checkboxTapped), for: .touchUpInside)
    }
    
    // MARK: - Configuration
    func configure(with item: TodoItem, delegate: TodoItemCellDelegate, index: Int) {
        self.todoItem = item
        self.delegate = delegate
        self.itemIndex = index
        
        titleLabel.text = item.title
        checkboxButton.isSelected = item.isCompleted
        
        // 완료 상태에 따른 스타일 적용
        if item.isCompleted {
            titleLabel.textColor = UIDesignSystem.Colors.secondaryText
            titleLabel.alpha = 0.6
            let attributedString = NSAttributedString(
                string: item.title,
                attributes: [NSAttributedString.Key.strikethroughStyle: NSUnderlineStyle.single.rawValue]
            )
            titleLabel.attributedText = attributedString
        } else {
            titleLabel.textColor = UIDesignSystem.Colors.primaryText
            titleLabel.alpha = 1.0
            titleLabel.attributedText = nil
        }
        
        // 우선순위 표시 (Int 타입으로 변경)
        switch item.priority {
        case 2: // high
            priorityIndicator.backgroundColor = UIColor.systemRed
            priorityIndicator.isHidden = false
        case 1: // medium
            priorityIndicator.backgroundColor = UIColor.systemYellow
            priorityIndicator.isHidden = false
        case 0: // low
            priorityIndicator.isHidden = true
        default:
            priorityIndicator.isHidden = true
        }
    }
    
    // MARK: - Actions
    @objc private func checkboxTapped() {
        guard let item = todoItem else { return }
        delegate?.todoItemCell(self, didToggleItem: item, at: itemIndex)
        DebugManager.shared.logTodo("TodoItem toggled: \(item.title)")
    }
    
    // MARK: - Lifecycle
    override func prepareForReuse() {
        super.prepareForReuse()
        todoItem = nil
        titleLabel.attributedText = nil
        titleLabel.text = nil
        checkboxButton.isSelected = false
        priorityIndicator.isHidden = true
    }
} 