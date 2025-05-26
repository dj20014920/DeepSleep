enum ChatMessage {
    case user(String)
    case bot(String)
    case presetRecommendation(presetName: String, message: String, apply: () -> Void)
}

import UIKit

class ChatViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    var messages: [ChatMessage] = []
    var initialUserText: String? = nil
    var onPresetApply: ((RecommendationResponse) -> Void)? = nil
    
    struct RecommendationResponse {
        let volumes: [Float]
        
        init(volumes: [Float]) {
            self.volumes = volumes
        }
    }
    
    private let tableView: UITableView = {
        let tv = UITableView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.separatorStyle = .none
        tv.backgroundColor = .clear
        tv.register(ChatBubbleCell.self, forCellReuseIdentifier: ChatBubbleCell.identifier)
        return tv
    }()

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
        
        tableView.delegate = self
        tableView.dataSource = self
        
        sendButton.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)
        presetButton.addTarget(self, action: #selector(presetButtonTapped), for: .touchUpInside)
        
        // 초기 설정 및 인사말
        setupInitialMessages()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    private func setupUI() {
        view.addSubview(tableView)
        view.addSubview(presetButton)
        view.addSubview(inputTextField)
        view.addSubview(sendButton)
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        let bottomInset = keyboardFrame.height - view.safeAreaInsets.bottom
        tableView.contentInset.bottom = bottomInset + 120
        tableView.verticalScrollIndicatorInsets.bottom = bottomInset + 120
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        tableView.contentInset.bottom = 0
        tableView.verticalScrollIndicatorInsets.bottom = 0
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // TableView
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableView.bottomAnchor.constraint(equalTo: presetButton.topAnchor, constant: -12),
            
            // Preset Button
            presetButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            presetButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            presetButton.bottomAnchor.constraint(equalTo: inputTextField.topAnchor, constant: -12),
            presetButton.heightAnchor.constraint(equalToConstant: 50),

            // Input TextField
            inputTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            inputTextField.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            inputTextField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            inputTextField.heightAnchor.constraint(equalToConstant: 40),

            // Send Button
            sendButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            sendButton.bottomAnchor.constraint(equalTo: inputTextField.bottomAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 60),
            sendButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    private func getMoodText(for emoji: String) -> String {
        switch emoji {
        case "😊": return "기쁨"
        case "😢": return "슬픔"
        case "😠": return "화남"
        case "😰": return "불안"
        case "😴": return "피곤함"
        default: return "평온"
        }
    }
    private func setupInitialMessages() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let emoji = self.initialUserText {
                let moodText = self.getMoodText(for: emoji)
                self.appendChat(.user("선택한 기분: \(emoji) \(moodText)"))

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    let prompt = "지금 사용자의 기분은 \(emoji) \(moodText)야. 이 기분에 공감하면서 따뜻하게 말을 건네줘. 너무 길지 않게 2~3줄 정도로 자연스럽게 대답해줘."
                    
                    ReplicateChatService.shared.sendPrompt(prompt) { response in
                        DispatchQueue.main.async {
                            if let msg = response {
                                self.appendChat(.bot(msg))
                            } else {
                                self.appendChat(.bot("말을 준비하는 데 문제가 생겼어요 😢"))
                            }
                        }
                    }
                }
            } else {
                self.appendChat(.bot("안녕하세요! 😊\n\n지금 기분이 어떠세요? 자유롭게 말씀해주시거나 바로 '프리셋 추천받기' 버튼을 눌러보세요! 🎵"))
            }
        }
    }
    
    @objc private func presetButtonTapped() {
        guard PresetLimitManager.shared.canUseToday() else {
            appendChat(.bot("❌ 오늘은 프리셋 추천 횟수를 모두 사용하셨어요! 내일 다시 이용해주세요 🙏"))
            return
        }

        let selectedEmoji = initialUserText ?? "😊"
        let moodText = getMoodText(for: selectedEmoji)

        // ✅ 사용자에게는 간단한 메시지만 표시
        appendChat(.user("프리셋 추천해줘!"))

        // ✅ 시스템 프롬프트 (사용자에겐 보이지 않음)
        let systemPrompt = """
        감정: \(selectedEmoji)
        프리셋 요소: \(SoundPresetCatalog.labels.prefix(12).joined(separator: ", "))
        응답 형식 예시: [프리셋 이름] Rain:80, Wind:60, Fan:40 ...
        설명 없이 이 형식만 출력해줘.
        """

        appendChat(.bot("AI가 맞춤 프리셋을 준비 중이에요... 🔍"))

        ReplicateChatService.shared.sendPrompt(systemPrompt) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                // 로딩 메시지 제거
                if !self.messages.isEmpty, case .bot = self.messages.last {
                    self.messages.removeLast()
                    self.tableView.reloadData()
                }

                guard let response = result else {
                    self.appendChat(.bot("❌ 추천을 받아오는 데 문제가 생겼어요. 다시 시도해주세요."))
                    return
                }

                PresetLimitManager.shared.incrementUsage()

                // ✅ 추천 결과 파싱
                if let parsed = self.parseRecommendation(from: response) {
                    let recommendation = ChatMessage.presetRecommendation(
                        presetName: "\(selectedEmoji) 프리셋",
                        message: "추천 프리셋이 도착했어요! 바로 들어볼까요?",
                        apply: {
                            self.onPresetApply?(parsed)
                            self.navigationController?.popViewController(animated: true)
                        }
                    )
                    self.appendChat(recommendation)
                } else {
                    self.appendChat(.bot("❌ 추천 결과를 처리하는 데 문제가 발생했어요."))
                }
            }
        }
    }

    @objc private func sendButtonTapped() {
        guard let text = inputTextField.text, !text.isEmpty else { return }
        
        inputTextField.text = ""
        appendChat(.user(text))
        
        // 일반적인 대화 처리
        ReplicateChatService.shared.sendPrompt(text) { response in
            DispatchQueue.main.async {
                if let msg = response {
                    self.appendChat(.bot(msg))
                } else {
                    self.appendChat(.bot("답변을 불러오지 못했어요 😢"))
                }
            }
        }
    }

    private func appendChat(_ message: ChatMessage) {
        messages.append(message)
        DispatchQueue.main.async {
            self.tableView.reloadData()
            if !self.messages.isEmpty {
                let indexPath = IndexPath(row: self.messages.count - 1, section: 0)
                self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            }
        }
    }

    func parseRecommendation(from response: String) -> RecommendationResponse? {
        var volumes: [Float] = Array(repeating: 0, count: SoundPresetCatalog.labels.count)
        let pattern = "([A-Za-z]+):(\\d{1,3})"

        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let nsString = response as NSString
            let matches = regex.matches(in: response, range: NSRange(location: 0, length: nsString.length))

            for match in matches {
                if let nameRange = Range(match.range(at: 1), in: response),
                   let valueRange = Range(match.range(at: 2), in: response) {
                    let name = String(response[nameRange])
                    let value = Int(response[valueRange]) ?? 0
                    if let index = SoundPresetCatalog.labels.firstIndex(of: name) {
                        volumes[index] = Float(min(100, max(0, value)))
                    }
                }
            }
            return RecommendationResponse(volumes: volumes)
        } catch {
            print("❌ 파싱 실패: \(error)")
            return nil
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ChatBubbleCell.identifier, for: indexPath) as? ChatBubbleCell else {
            return UITableViewCell()
        }
        let msg = messages[indexPath.row]
        cell.configure(with: msg)
        return cell
    }
}

class PresetLimitManager {
    static let shared = PresetLimitManager()

    private let key = "presetUsageHistory"

    func canUseToday() -> Bool {
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        let usage = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        let count = usage[today] ?? 0
        return count < 3
    }

    func incrementUsage() {
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        var usage = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        usage[today] = (usage[today] ?? 0) + 1
        UserDefaults.standard.set(usage, forKey: key)
    }
}
