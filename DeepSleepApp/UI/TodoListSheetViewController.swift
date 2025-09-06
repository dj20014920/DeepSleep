import UIKit

/// 선택한 날짜의 할 일 목록을 보여주고, AI 조언을 요청할 수 있는 간단한 시트
final class TodoListSheetViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let date: Date
    private var todos: [TodoItem]
    private let allTodosProvider: () -> [TodoItem]

    private let tableView = UITableView()
    private let adviceButton = UIButton(type: .system)

    init(date: Date, todos: [TodoItem], allTodosProvider: @escaping () -> [TodoItem]) {
        self.date = date
        self.todos = todos
        self.allTodosProvider = allTodosProvider
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        title = "할 일 목록"

        setupTable()
        setupAdviceButton()
    }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        // UITableViewCell의 기본 스타일 사용
        tableView.separatorStyle = .singleLine
        view.addSubview(tableView)
    }

    private func setupAdviceButton() {
        adviceButton.translatesAutoresizingMaskIntoConstraints = false
        adviceButton.setTitle("💡 할 일 조언 받기", for: .normal)
        adviceButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        adviceButton.backgroundColor = .systemBlue
        adviceButton.setTitleColor(.white, for: .normal)
        adviceButton.layer.cornerRadius = 10
        adviceButton.addTarget(self, action: #selector(didTapAdvice), for: .touchUpInside)
        view.addSubview(adviceButton)

        NSLayoutConstraint.activate([
            adviceButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            adviceButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            adviceButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            adviceButton.heightAnchor.constraint(equalToConstant: 48),

            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: adviceButton.topAnchor, constant: -12)
        ])
    }

    // MARK: - UITableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { todos.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TodoCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "TodoCell")
        let todo = todos[indexPath.row]

        cell.textLabel?.text = todo.title
        cell.detailTextLabel?.text = "마감: \(DateFormatter.localizedString(from: todo.dueDate, dateStyle: .short, timeStyle: .short))"
        cell.accessoryType = todo.isCompleted ? .checkmark : .none
        cell.textLabel?.textColor = todo.isCompleted ? .systemGray : .label

        return cell
    }

    // MARK: - Actions
    @objc private func didTapAdvice() {
        // 이미 오늘 생성된 전체 조언이 있으면 바로 보기로 전환
        if TodoManager.hasOverallAdviceToday(in: todos, on: date),
           let content = TodoManager.latestOverallAdviceContent(from: todos) {
            let vc = SimpleAdviceViewController(titleText: "💡 오늘의 할 일 조언", adviceText: content)
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: true)
            return
        }

        // 권한 및 사용량은 SessionManager/AIUsageManager 내부에서 처리
        let weeklyContext = SessionManager.shared.buildRichContextForLocalAI().emotionHistory.first?.emotion
        let prompt = TodoManager.buildOverallAdvicePrompt(date: date,
                                                         todos: todos,
                                                         allTodos: allTodosProvider(),
                                                         weeklyContext: weeklyContext)
        Task {
            do {
                let advice = try await SessionManager.shared.sendMessage(
                    content: prompt,
                    model: .gemini,
                    mode: .taskAdviceOverall,
                    saveMessages: false,
                    policyMeta: [
                        "keyedFeature": "todo_overall_advice"
                    ]
                )
                // 전체 조언 저장: 공용 유틸리티로 일원화
                TodoManager.distributeOverallAdvice(advice, to: todos)
                await MainActor.run {
                    let vc = SimpleAdviceViewController(titleText: "💡 오늘의 할 일 조언", adviceText: advice)
                    vc.modalPresentationStyle = .overFullScreen
                    self.present(vc, animated: true)
                }
            } catch {
                await MainActor.run {
                    let alert = UIAlertController(title: "AI 조언 오류", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "확인", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
}
