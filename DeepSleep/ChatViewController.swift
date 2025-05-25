import UIKit

class ChatViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {    var messages: [ChatMessage] = []
    var initialUserText: String? = nil
    var onPresetApply: ((RecommendationResponse) -> Void)? = nil
    
    private let tableView: UITableView = {
        let tv = UITableView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.separatorStyle = .none
        tv.backgroundColor = .clear
        tv.register(ChatBubbleCell.self, forCellReuseIdentifier: ChatBubbleCell.identifier)
        return tv
    }()

    private let inputTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "메시지를 입력하세요"
        textField.borderStyle = .roundedRect
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let sendButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("전송", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let loadingLabel: UILabel = {
        let label = UILabel()
        label.text = "모델 로딩 중..."
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .gray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupViews()
        setupConstraints()
        setupActions()
        loadChatService()
    }
    
    private func loadChatService() {
        loadingLabel.isHidden = true
        sendButton.isEnabled = true
        inputTextField.isEnabled = true
        appendChat(.bot("AI와의 대화를 시작해보세요."))
        // 초기 텍스트 처리
        if let initialText = self.initialUserText {
            self.inputTextField.text = initialText
            self.initialUserText = nil
        }
    }
   
    private func setupViews() {
        view.addSubview(inputTextField)
        view.addSubview(sendButton)
        view.addSubview(loadingLabel)
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableView.bottomAnchor.constraint(equalTo: inputTextField.topAnchor, constant: -12),

            inputTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            inputTextField.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            inputTextField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            inputTextField.heightAnchor.constraint(equalToConstant: 40),

            sendButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            sendButton.bottomAnchor.constraint(equalTo: inputTextField.bottomAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 60),
            sendButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    private func setupActions() {
        sendButton.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)
        inputTextField.addTarget(self, action: #selector(textFieldReturn), for: .editingDidEndOnExit)
    }
    
    @objc private func textFieldReturn() {
        sendButtonTapped()
    }

    @objc private func sendButtonTapped() {
        guard let userInput = inputTextField.text, !userInput.isEmpty else { return }

        inputTextField.text = ""
        appendChat(.user(userInput))
        
        sendButton.isEnabled = false
        inputTextField.isEnabled = false

        ReplicateChatService.shared.sendPrompt(userInput) { response in
            DispatchQueue.main.async {
                if let response = response {
                    self.appendChat(.bot(response))
                } else {
                    self.appendChat(.bot("❌ AI 응답을 불러오지 못했어요."))
                }
                self.sendButton.isEnabled = true
                self.inputTextField.isEnabled = true
                self.inputTextField.becomeFirstResponder()
            }
        }
    }

    private func appendChat(_ message: ChatMessage) {
        messages.append(message)
        tableView.reloadData()
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }
}


extension ChatViewController {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ChatBubbleCell.identifier, for: indexPath) as? ChatBubbleCell else {
            return UITableViewCell()
        }
        cell.configure(with: messages[indexPath.row])
        return cell
    }
}
