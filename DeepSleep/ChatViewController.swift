import UIKit


class ChatViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    var messages: [ChatMessage] = []
    var initialUserText: String? = nil
    var onPresetApply: ((RecommendationResponse) -> Void)? = nil

    private var bottomConstraint: NSLayoutConstraint?
    
    private var dailyChatCount: Int {
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        let history = UserDefaults.standard.dictionary(forKey: "chatUsage") as? [String: Int] ?? [:]
        return history[today] ?? 0
    }

    private func incrementDailyChatCount() {
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        var history = UserDefaults.standard.dictionary(forKey: "chatUsage") as? [String: Int] ?? [:]
        history[today] = (history[today] ?? 0) + 1
        UserDefaults.standard.set(history, forKey: "chatUsage")
    }

    struct RecommendationResponse {
        let volumes: [Float]
    }

    private let tableView: UITableView = {
        let tv = UITableView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.separatorStyle = .none
        tv.backgroundColor = .clear
        tv.register(ChatBubbleCell.self, forCellReuseIdentifier: ChatBubbleCell.identifier)
        return tv
    }()

    private let inputContainerView = UIView()
    private let inputTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "메시지를 입력하세요"
        tf.borderStyle = .roundedRect
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()
    
    private let sendButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("전송", for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private let presetButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("🎵 프리셋 추천받기", for: .normal)
        btn.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        btn.layer.cornerRadius = 8
        btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
        setupConstraints()
        if let saved = UserDefaults.standard.array(forKey: "chatHistory") as? [[String: String]] {
            self.messages = saved.compactMap { ChatMessage.from(dictionary: $0) }
            tableView.rowHeight = UITableView.automaticDimension
            tableView.estimatedRowHeight = 100
        }
        tableView.estimatedRowHeight = UITableView.automaticDimension
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100
        sendButton.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)
        presetButton.addTarget(self, action: #selector(presetButtonTapped), for: .touchUpInside)
        setupInitialMessages()

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollToBottom()
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupUI() {
        inputContainerView.translatesAutoresizingMaskIntoConstraints = false
        inputContainerView.addSubview(inputTextField)
        inputContainerView.addSubview(sendButton)

        view.addSubview(tableView)
        view.addSubview(presetButton)
        view.addSubview(inputContainerView)
        
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableView.bottomAnchor.constraint(equalTo: presetButton.topAnchor, constant: -12),

            presetButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            presetButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            presetButton.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor, constant: -12),
            presetButton.heightAnchor.constraint(equalToConstant: 50),

            inputTextField.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 16),
            inputTextField.topAnchor.constraint(equalTo: inputContainerView.topAnchor, constant: 8),
            inputTextField.bottomAnchor.constraint(equalTo: inputContainerView.bottomAnchor, constant: -8),
            inputTextField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),

            sendButton.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -16),
            sendButton.centerYAnchor.constraint(equalTo: inputTextField.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 60)
        ])

        bottomConstraint = inputContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        bottomConstraint?.isActive = true
        NSLayoutConstraint.activate([
            inputContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    @objc private func keyboardWillShow(notification: Notification) {
        if let keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            bottomConstraint?.constant = -keyboardFrame.height + view.safeAreaInsets.bottom
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
                self.scrollToBottom()
            }
        }
    }

    @objc private func keyboardWillHide(notification: Notification) {
        bottomConstraint?.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func scrollToBottom() {
        if !messages.isEmpty {
            let indexPath = IndexPath(row: messages.count - 1, section: 0)
            tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }

    private func setupInitialMessages() {
        if let emoji = initialUserText {
            appendChat(.user("선택한 기분: \(emoji)"))
        } else {
            appendChat(.bot("안녕하세요! 😊\n지금 기분이 어떠세요? 자유롭게 말해보세요."))
        }
    }

    @objc private func presetButtonTapped() {
        guard PresetLimitManager.shared.canUseToday() else {
            appendChat(.bot("❌ 오늘 프리셋 추천 횟수를 모두 사용했어요!"))
            return
        }

        let emoji = initialUserText ?? "😊"
        let systemPrompt = "감정: \(emoji)\n프리셋 요소: ... (생략)"
        appendChat(.user("프리셋 추천해줘!"))
        appendChat(.bot("AI가 맞춤 프리셋을 준비 중이에요... 🔍"))

        ReplicateChatService.shared.sendPrompt(systemPrompt) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let response = result,
                   let parsed = self.parseRecommendation(from: response) {
                    self.appendChat(.presetRecommendation(
                        presetName: "\(emoji) 프리셋",
                        message: "추천 프리셋이 도착했어요! 바로 들어볼까요?",
                        apply: {
                            self.onPresetApply?(parsed)
                            self.navigationController?.popViewController(animated: true)
                        }
                    ))
                    PresetLimitManager.shared.incrementUsage()
                } else {
                    self.appendChat(.bot("❌ 추천 결과 처리 실패"))
                }
            }
        }
    }

    @objc private func sendButtonTapped() {
        guard let text = inputTextField.text, !text.isEmpty else { return }
        inputTextField.text = ""
        appendChat(.user(text))
        if dailyChatCount >= 50 {
            appendChat(.bot("❌ 오늘의 채팅 횟수를 모두 사용하셨어요."))
            return
        } else if dailyChatCount == 40 {
            appendChat(.bot("⚠️ 오늘 채팅 횟수가 10회 남았어요."))
        }
        let isDiary = text.count > 30 || text.contains("오늘")
        let intent = isDiary ? "diary" : "chat"

        ReplicateChatService.shared.sendPrompt(message: text, intent: intent) { [weak self] response in
            DispatchQueue.main.async {
                if let msg = response {
                    self?.appendChat(.bot(msg))
                } else {
                    self?.appendChat(.bot("❌ 응답을 불러오지 못했어요"))
                }
            }
        }
        incrementDailyChatCount()
    }

    private func appendChat(_ message: ChatMessage) {
        messages.append(message)
        tableView.reloadData()
        tableView.beginUpdates()
        tableView.endUpdates()
        scrollToBottom()
        UserDefaults.standard.set(messages.map { $0.toDictionary() }, forKey: "chatHistory")
    }

    func parseRecommendation(from response: String) -> RecommendationResponse? {
        return RecommendationResponse(volumes: [Float](repeating: 50, count: 12)) // 예시
    }

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


enum ChatMessage {
    case user(String)
    case bot(String)
    case presetRecommendation(presetName: String, message: String, apply: () -> Void)

    func toDictionary() -> [String: String] {
        switch self {
        case .user(let msg):
            return ["type": "user", "text": msg]
        case .bot(let msg):
            return ["type": "bot", "text": msg]
        case .presetRecommendation(let presetName, let msg, _):
            return ["type": "preset", "text": msg, "presetName": presetName]
        }
    }

    static func from(dictionary: [String: String]) -> ChatMessage? {
        guard let type = dictionary["type"], let text = dictionary["text"] else { return nil }
        switch type {
        case "user": return .user(text)
        case "bot": return .bot(text)
        case "preset":
            let name = dictionary["presetName"] ?? "추천 프리셋"
            return .presetRecommendation(presetName: name, message: text, apply: {})
        default: return nil
        }
    }
}

// MARK: - PresetLimitManager (프리셋 하루 3회 제한)
class PresetLimitManager {
    static let shared = PresetLimitManager()
    private let key = "presetUsageHistory"

    func canUseToday() -> Bool {
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        let usage = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        return (usage[today] ?? 0) < 3
    }

    func incrementUsage() {
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        var usage = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        usage[today] = (usage[today] ?? 0) + 1
        UserDefaults.standard.set(usage, forKey: key)
    }
}
