import UIKit

// MARK: - RecommendationResponse (파일 최상단에 정의)
struct RecommendationResponse {
    let volumes: [Float]
    let presetName: String
    
    init(volumes: [Float], presetName: String = "맞춤 프리셋") {
        self.volumes = volumes
        self.presetName = presetName
    }
}

class ChatViewController: UIViewController {
    // MARK: - Properties
    var messages: [ChatMessage] = []
    var initialUserText: String? = nil
    var diaryContext: DiaryContext? = nil
    var emotionPatternData: String? = nil
    var onPresetApply: ((RecommendationResponse) -> Void)? = nil
    private var sessionStartTime: Date?
    private var messageCount = 0
    private let maxMessages = 75
    private var bottomConstraint: NSLayoutConstraint?
    var chatHistory: [(isUser: Bool, message: String)] = []
    
    // MARK: - UI Components
    private let tableView: UITableView = {
        let tv = UITableView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.separatorStyle = .none
        tv.backgroundColor = .clear
        tv.register(ChatBubbleCell.self, forCellReuseIdentifier: ChatBubbleCell.identifier)
        return tv
    }()
    
    private let inputContainerView = UIView()
    let inputTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "마음을 편하게 말해보세요..."
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
        btn.setTitle("🎵 지금 기분에 맞는 사운드 추천받기", for: .normal)
        btn.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        btn.layer.cornerRadius = 8
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    // MARK: - Computed Properties
    private var dailyChatCount: Int {
        let todayStats = SettingsManager.shared.getTodayStats()
        return todayStats.chatCount
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupNavigationBar()
        setupUI()
        setupConstraints()
        setupTableView()
        setupTargets()
        setupNotifications()
        
        // ✅ 캐시 시스템 초기화
        initializeCacheSystem()
        
        // 토큰 추적기 초기화
        TokenTracker.shared.resetIfNewDay()
        
        // 기존 대화 로드
        loadChatHistory()
        
        // 초기 메시지 설정
        setupInitialMessages()
        
        // 초기 사용자 텍스트 처리
        if let initialText = initialUserText {
            handleInitialUserText(initialText)
        }
        
        #if DEBUG
        setupDebugGestures()
        #endif
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
        scrollToBottom()
        
        // ✅ 세션 시작 시간 기록
        sessionStartTime = Date()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 네비게이션 바가 숨겨져 있다면 다시 표시
        if navigationController?.isNavigationBarHidden == true {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
        refreshCacheStatus()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
        recordSessionTime()
    }
    
    // ✅ 세션 시간 기록
    private func recordSessionTime() {
        guard let startTime = sessionStartTime else { return }
        let sessionDuration = Date().timeIntervalSince(startTime)
        
        // 최소 10초 이상의 세션만 기록
        if sessionDuration > 10 {
            SettingsManager.shared.addSessionTime(sessionDuration)
            
            #if DEBUG
            print("⏱️ 세션 시간 기록: \(Int(sessionDuration))초")
            #endif
        }
        
        sessionStartTime = nil
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        
        // ✅ 최종 세션 시간 기록
        recordSessionTime()
        
        #if DEBUG
        print("🗑️ ChatViewController 메모리 해제")
        #endif
    }
}

// MARK: - Setup Methods
extension ChatViewController {
    private func loadChatHistory() {
        if let saved = UserDefaults.standard.array(forKey: "chatHistory") as? [[String: String]] {
            self.messages = saved.compactMap { ChatMessage.from(dictionary: $0) }
        }
    }
    
    private func setupNavigationBar() {
        // 네비게이션 바 표시 설정
        navigationController?.setNavigationBarHidden(false, animated: false)
        
        // 뒤로가기 버튼 설정
        if navigationController?.viewControllers.count ?? 0 > 1 {
            // 스택에 다른 뷰컨트롤러가 있는 경우 (push로 온 경우)
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "← 뒤로",
                style: .plain,
                target: self,
                action: #selector(backButtonTapped)
            )
        } else {
            // 모달로 표시된 경우
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "✕ 닫기",
                style: .plain,
                target: self,
                action: #selector(closeButtonTapped)
            )
        }
        
        // 타이틀 설정 (이미 있는 title 사용)
        if title == nil || title?.isEmpty == true {
            title = "AI 대화"
        }
        
        // 네비게이션 바 스타일
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.tintColor = .systemBlue
    }
    
    // ✅ 캐시 시스템 초기화
    private func initializeCacheSystem() {
        // 캐시 매니저 초기화
        CachedConversationManager.shared.initialize()
        
        // 만료된 캐시들 정리
        UserDefaults.standard.cleanExpiredCaches()
        UserDefaults.standard.cleanOldData(olderThanDays: 7)
        
        #if DEBUG
        print("🗄️ 캐시 시스템 초기화 완료")
        let debugInfo = CachedConversationManager.shared.getDebugInfo()
        print(debugInfo)
        #endif
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100
    }
    
    private func setupTargets() {
        sendButton.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)
        presetButton.addTarget(self, action: #selector(presetButtonTapped), for: .touchUpInside)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
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
    
    private func setupInitialMessages() {
        if let diary = diaryContext {
            appendChat(.user("📝 이 일기를 분석해주세요"))
            
            let initialResponse = """
            📖 \(diary.emotion) 이런 기분으로 일기를 써주셨군요 😊
            
            차근차근 마음 이야기를 나눠볼까요? 
            어떤 부분이 가장 마음에 남으셨나요? 💭
            """
            
            appendChat(.bot(initialResponse))
            requestDiaryAnalysisWithTracking(diary: diary)
            
        } else if let patternData = emotionPatternData {
            appendChat(.user("📊 최근 감정 패턴을 분석해주세요"))
            
            let initialResponse = """
            📈 최근 30일간의 감정 패턴을 분석해드릴게요 😊
            
            패턴을 살펴보고 있어요... 잠시만 기다려주세요! 💭
            """
            
            appendChat(.bot(initialResponse))
            requestPatternAnalysisWithTracking(patternData: patternData)
            
        } else if let userText = initialUserText,
                  userText != "일기_분석_모드" && userText != "감정_패턴_분석_모드" {
            appendChat(.user("선택한 기분: \(userText)"))
            let greeting = getEmotionalGreeting(for: userText)
            appendChat(.bot(greeting))
        } else {
            appendChat(.bot("안녕하세요! 😊\n오늘 하루는 어떠셨나요? 마음 편하게 이야기해보세요 ✨"))
        }
    }
    
    // ✅ 캐시 상태 새로고침
    private func refreshCacheStatus() {
        // 캐시가 유효한지 확인하고 필요시 업데이트
        let weeklyMemory = CachedConversationManager.shared.loadWeeklyMemory()
        
        #if DEBUG
        print("🔄 캐시 상태 새로고침: \(weeklyMemory.totalMessages)개 메시지 기반")
        #endif
        
        // 주간 메모리 백그라운드 업데이트
        CachedConversationManager.shared.updateWeeklyMemoryAsync()
    }
    
    private func handleInitialUserText(_ text: String) {
        switch text {
        case "감정_패턴_분석_모드":
            startEmotionPatternAnalysis()
        case "일기_분석_모드":
            startDiaryAnalysis()
        default:
            break
        }
    }
    
    private func startEmotionPatternAnalysis() {
        guard let emotionData = emotionPatternData, !emotionData.isEmpty else {
            appendChat(.bot("아직 감정 기록이 충분하지 않네요 😊 일기를 더 작성해주시면 더 정확한 분석을 도와드릴 수 있어요!"))
            return
        }
        
        appendChat(.bot("📊 최근 30일간의 감정 패턴을 분석하고 있어요... ✨"))
        
        ReplicateChatService.shared.analyzeEmotionPattern(data: emotionData) { [weak self] response in
            DispatchQueue.main.async {
                if let response = response {
                    self?.appendChat(.bot(response))
                    self?.addQuickEmotionButtons()
                } else {
                    self?.appendChat(.bot("죄송해요, 분석 중 문제가 발생했습니다 😅 네트워크 연결을 확인해주세요."))
                }
            }
        }
    }
    
    private func startDiaryAnalysis() {
        guard let diaryData = diaryContext else { return }
        
        let analysisText = """
        오늘의 감정: \(diaryData.emotion) 
        일기 내용을 바탕으로 감정을 분석해드릴게요 😊
        """
        
        appendChat(.bot(analysisText))
        
        ReplicateChatService.shared.sendPrompt(
            message: diaryData.content,
            intent: "diary_analysis"
        ) { [weak self] response in
            DispatchQueue.main.async {
                if let response = response {
                    self?.appendChat(.bot(response))
                } else {
                    self?.appendChat(.bot("죄송해요, 분석 중 문제가 발생했습니다 😅"))
                }
            }
        }
    }
    
    private func addQuickEmotionButtons() {
        appendChat(.bot("💡 더 자세한 분석을 원하시나요?\n\n🎯 개선 방법\n📈 감정 변화 추이\n💡 스트레스 관리\n\n위 키워드로 질문해보세요! ✨"))
    }

}

// MARK: - Helper Methods
extension ChatViewController {
    func incrementDailyChatCount() {
        SettingsManager.shared.incrementChatUsage()
    }
    
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func closeButtonTapped() {
        if let presentingViewController = presentingViewController {
            dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    // ✅ appendChat 메서드
    func appendChat(_ message: ChatMessage) {
        messages.append(message)
        
        tableView.reloadData()
        DispatchQueue.main.async {
            self.scrollToBottom()
        }
        
        // 기존 히스토리 저장
        saveChatHistory()
    }
    
    func saveChatHistory() {
        let dictionaries = messages.map { $0.toDictionary() }
        UserDefaults.standard.set(dictionaries, forKey: "chatHistory")
    }
    
    func scrollToBottom() {
        if !messages.isEmpty {
            let indexPath = IndexPath(row: messages.count - 1, section: 0)
            tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }
}

// MARK: - Keyboard Handling
extension ChatViewController {
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
}

// MARK: - Debug Features
extension ChatViewController {
    #if DEBUG
    private func setupDebugGestures() {
        let debugTap = UITapGestureRecognizer(target: self, action: #selector(debugTenTap))
        debugTap.numberOfTapsRequired = 10
        view.addGestureRecognizer(debugTap)
    }
    
    @objc private func debugTenTap() {
        showPasswordPrompt()
    }
    
    private func showPasswordPrompt() {
        let alert = UIAlertController(title: "🔐 개발자 모드", message: "비밀번호를 입력하세요", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "비밀번호"
            textField.isSecureTextEntry = true
        }
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "확인", style: .default) { [weak self] _ in
            if let password = alert.textFields?.first?.text {
                self?.checkPassword(password)
            }
        })
        
        present(alert, animated: true)
    }
    
    private func checkPassword(_ password: String) {
        if password == "492000!" {
            debugShowTokenUsage()
        } else {
            let errorAlert = UIAlertController(title: "❌ 접근 거부", message: "잘못된 비밀번호입니다", preferredStyle: .alert)
            errorAlert.addAction(UIAlertAction(title: "확인", style: .default))
            present(errorAlert, animated: true)
        }
    }
    
    private func debugShowTokenUsage() {
        let stats = TokenTracker.shared.getTodayDetailedUsage()
        let monthlyProjection = TokenTracker.shared.getMonthlyProjectedCost()
        
        let alertMessage = """
        📊 개인 토큰 사용량 (오늘):
        
        🔢 토큰 현황:
        • 총 사용: \(stats.tokens)개
        • 입력: \(stats.inputTokens)개 | 출력: \(stats.outputTokens)개
        
        💰 비용 현황:
        • 오늘: ₩\(stats.costKRW) ($\(String(format: "%.4f", stats.costUSD)))
        • 월간 예상: ₩\(monthlyProjection.krw)
        
        ℹ️ 개인 사용량만 추적됩니다
        """
        
        let alert = UIAlertController(title: "🔐 개발자 토큰 분석", message: alertMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        alert.addAction(UIAlertAction(title: "상세 로그", style: .destructive) { _ in
            TokenTracker.shared.forceLogCurrentStats()
        })
        present(alert, animated: true)
    }
    #endif
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension ChatViewController: UITableViewDataSource, UITableViewDelegate {
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
