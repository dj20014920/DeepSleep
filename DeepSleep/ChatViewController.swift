import UIKit

enum ChatMessage {
    case user(text: String)
    case bot(text: String)
    case presetRecommendation(preset: Preset, message: String)
}

class ChatViewController: UIViewController {
    private let tableView = UITableView()
    private let inputField = UITextField()
    private let sendButton = UIButton(type: .system)
    private let inputContainer = UIView()

    private var messages: [ChatMessage] = []
    var onPresetApply: ((Preset) -> Void)?
    var initialUserText: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "AI 대화"

        setupTableView()
        setupInputBar()
        registerKeyboardEvents()

        if let text = initialUserText {
            append(.user(text: text))
            requestRecommendation(for: text)
        }
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        tableView.register(ChatBubbleCell.self, forCellReuseIdentifier: ChatBubbleCell.identifier)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -60)
        ])
    }

    private func setupInputBar() {
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.backgroundColor = .secondarySystemBackground
        view.addSubview(inputContainer)

        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.placeholder = "오늘 기분이나 일기를 입력하세요"
        inputField.borderStyle = .roundedRect

        sendButton.setTitle("전송", for: .normal)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false

        inputContainer.addSubview(inputField)
        inputContainer.addSubview(sendButton)

        NSLayoutConstraint.activate([
            inputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            inputContainer.heightAnchor.constraint(equalToConstant: 60),

            inputField.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 16),
            inputField.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            inputField.heightAnchor.constraint(equalToConstant: 36),

            sendButton.leadingAnchor.constraint(equalTo: inputField.trailingAnchor, constant: 8),
            sendButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -16),
            sendButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 60),

            inputField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8)
        ])
    }

    @objc private func sendTapped() {
        guard let txt = inputField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !txt.isEmpty else { return }
        append(.user(text: txt))
        inputField.text = ""
        requestRecommendation(for: txt)
    }

    private func requestRecommendation(for text: String) {
        ChatService.requestRecommendation(userText: text) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .failure:
                    self.append(.bot(text: "죄송해요, 응답에 실패했어요."))
                case .success(let rec):
                    self.append(.bot(text: "\(rec.empathy)\n\n오늘의 운세: \(rec.fortune)"))
                    let preset = Preset(name: rec.presetName, volumes: rec.volumes)
                    self.append(.presetRecommendation(preset: preset, message: rec.presetName))
                }
            }
        }
    }

    private func append(_ msg: ChatMessage) {
        messages.append(msg)
        tableView.reloadData()
        let index = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: index, at: .bottom, animated: true)
    }

    @objc private func applyTapped(_ sender: UIButton) {
        if case .presetRecommendation(let preset, _) = messages[sender.tag] {
            onPresetApply?(preset)
        }
    }

    private func registerKeyboardEvents() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        // 생략 가능: 추가할 경우 height 조정
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        // 생략 가능: 원상복귀
    }
}

// MARK: - UITableViewDataSource & Delegate
extension ChatViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let msg = messages[ip.row]
        let cell = tv.dequeueReusableCell(withIdentifier: ChatBubbleCell.identifier, for: ip) as! ChatBubbleCell
        cell.configure(with: msg)

        if case .presetRecommendation = msg {
            let btn = UIButton(type: .system)
            btn.setTitle("적용하기", for: .normal)
            btn.sizeToFit()
            btn.tag = ip.row
            btn.addTarget(self, action: #selector(applyTapped(_:)), for: .touchUpInside)
            cell.accessoryView = btn
        } else {
            cell.accessoryView = nil
        }

        return cell
    }
}
