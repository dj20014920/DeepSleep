import UIKit
import Core

class EmotionAnalysisChatViewController: UIViewController, UIGestureRecognizerDelegate, UITextFieldDelegate {
    
    // MARK: - Properties
    private var tableView: UITableView!
    private var inputTextField: UITextField!
    private var sendButton: UIButton!
    private var inputContainerView: UIView!
    private var quickActionView: EmotionAnalysisQuickActionView!
    
    private var chatMessages: [Core.ChatMessage] = []
    private var isLoading = false
    
    private let emotionService: EmotionAnalysisServiceProtocol = EmotionAnalysisService()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        setupInputView()
        setupQuickActions()
        setupNavigationBar()
        setupKeyboardHandling()
        
        // 초기 메시지 추가
        addInitialMessage()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        inputTextField.becomeFirstResponder()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        title = "감정 분석 채팅"
    }
    
    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )
    }
    
    private func setupTableView() {
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = UIColor.systemBackground
        tableView.estimatedRowHeight = 80
        tableView.rowHeight = UITableView.automaticDimension
        
        // ChatBubbleCell 등록
        tableView.register(ChatBubbleCell.self, forCellReuseIdentifier: "ChatBubbleCell")
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupInputView() {
        inputContainerView = UIView()
        inputContainerView.translatesAutoresizingMaskIntoConstraints = false
        inputContainerView.backgroundColor = UIColor.systemBackground
        inputContainerView.layer.borderWidth = 0.5
        inputContainerView.layer.borderColor = UIColor.separator.cgColor
        
        inputTextField = UITextField()
        inputTextField.translatesAutoresizingMaskIntoConstraints = false
        inputTextField.placeholder = "감정을 입력해보세요..."
        inputTextField.borderStyle = .roundedRect
        inputTextField.delegate = self
        inputTextField.returnKeyType = .send
        
        sendButton = UIButton(type: .system)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle("전송", for: .normal)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
    
        inputContainerView.addSubview(inputTextField)
        inputContainerView.addSubview(sendButton)
        view.addSubview(inputContainerView)
        
        NSLayoutConstraint.activate([
            inputContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            inputContainerView.heightAnchor.constraint(equalToConstant: 60),
            
            inputTextField.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 16),
            inputTextField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -12),
            inputTextField.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            inputTextField.heightAnchor.constraint(equalToConstant: 36),
            
            sendButton.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -16),
            sendButton.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 60)
        ])
        
        // TableView bottom constraint 업데이트
        tableView.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor).isActive = true
    }
    
    private func setupQuickActions() {
        quickActionView = EmotionAnalysisQuickActionView()
        quickActionView.translatesAutoresizingMaskIntoConstraints = false
        quickActionView.delegate = self
        
        view.addSubview(quickActionView)
        
        NSLayoutConstraint.activate([
            quickActionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            quickActionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            quickActionView.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor, constant: -8),
            quickActionView.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupKeyboardHandling() {
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
    
    // MARK: - Initial Message
    private func addInitialMessage() {
        let welcomeMessage = Core.ChatMessage(
            text: "안녕하세요! 지금 기분이 어떠신가요? 감정을 자유롭게 표현해보세요. 😊",
            sender: .ai,
            type: .bot
        )
        chatMessages.append(welcomeMessage)
        tableView.reloadData()
    }
    
    // MARK: - Message Handling
    private func sendMessage() {
        guard let text = inputTextField.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // 사용자 메시지 추가
        let userMessage = Core.ChatMessage(
            text: text,
            sender: .user,
            type: .user
        )
        chatMessages.append(userMessage)
        
        // 입력 필드 클리어
        inputTextField.text = ""
        
        // UI 업데이트
        tableView.reloadData()
        scrollToBottom()
        
        // 로딩 표시
        setLoading(true)
        
        // 감정 분석 요청
        Task {
            await analyzeEmotion(text)
        }
    }
    
    private func analyzeEmotion(_ text: String) async {
        do {
            let response = try await emotionService.analyzeEmotion(text: text)
                
                await MainActor.run {
                setLoading(false)
                
                let aiMessage = Core.ChatMessage(
                    text: formatEmotionResponse(response),
                    sender: .ai,
                    type: .bot,
                    quickActions: createQuickActions(for: response)
                )
                
                chatMessages.append(aiMessage)
                tableView.reloadData()
        scrollToBottom()
    }
        } catch {
            await MainActor.run {
                setLoading(false)
                addErrorMessage("감정 분석 중 오류가 발생했습니다: \(error.localizedDescription)")
            }
        }
    }
    
    private func formatEmotionResponse(_ response: EmotionAnalysisModels.EmotionAnalysisResponse) -> String {
        var result = "🎭 감정 분석 결과\n\n"
        
        result += "**주요 감정**: \(response.primaryEmotion)\n"
        result += "**강도**: \(String(format: "%.1f", response.intensity * 100))%\n"
        
        if !response.secondaryEmotions.isEmpty {
            result += "**기타 감정**: \(response.secondaryEmotions.joined(separator: ", "))\n"
        }
        
        if let suggestion = response.suggestion {
            result += "\n💡 **제안**: \(suggestion)"
        }
        
        return result
    }
    
    private func createQuickActions(for response: EmotionAnalysisModels.EmotionAnalysisResponse) -> [Core.QuickAction] {
        return [
            Core.QuickAction(
                title: "더 자세히",
                action: "detail_analysis"
            ),
            Core.QuickAction(
                title: "음악 추천",
                action: "music_recommendation"
            ),
            Core.QuickAction(
                title: "조언 받기",
                action: "get_advice"
            )
        ]
    }
    
    private func addErrorMessage(_ error: String) {
        let errorMessage = Core.ChatMessage(
            text: "❌ \(error)",
            sender: .ai,
            type: .error
        )
        chatMessages.append(errorMessage)
        tableView.reloadData()
        scrollToBottom()
    }
    
    private func setLoading(_ loading: Bool) {
        isLoading = loading
        
        if loading {
            let loadingMessage = Core.ChatMessage(
                text: "분석 중...",
                sender: .ai,
                type: .loading
            )
            chatMessages.append(loadingMessage)
        } else {
            // 로딩 메시지 제거
            if let lastMessage = chatMessages.last, lastMessage.text == "분석 중..." {
                chatMessages.removeLast()
            }
        }
        
        tableView.reloadData()
        scrollToBottom()
    }
    
    private func scrollToBottom() {
        guard !chatMessages.isEmpty else { return }
        let indexPath = IndexPath(row: chatMessages.count - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }

    // MARK: - Actions
    @objc private func closeTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func sendTapped() {
        sendMessage()
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardHeight = keyboardFrame.cgRectValue.height
        
        UIView.animate(withDuration: 0.3) {
            self.view.transform = CGAffineTransform(translationX: 0, y: -keyboardHeight + self.view.safeAreaInsets.bottom)
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        UIView.animate(withDuration: 0.3) {
            self.view.transform = .identity
        }
    }
    
    // MARK: - TextField Delegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendMessage()
        return true
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension EmotionAnalysisChatViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chatMessages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChatBubbleCell", for: indexPath) as! ChatBubbleCell
        
        let message = chatMessages[indexPath.row]
        let isUserMessage = message.sender == .user
        
        // ChatBubbleCell의 configure 메서드 사용
        cell.configure(with: message, isUserMessage: isUserMessage)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}

// MARK: - EmotionAnalysisQuickActionViewDelegate
extension EmotionAnalysisChatViewController: EmotionAnalysisQuickActionViewDelegate {
    func quickActionView(_ view: EmotionAnalysisQuickActionView, didSelectEmotion emotion: String) {
        inputTextField.text = emotion
        sendMessage()
    }
}