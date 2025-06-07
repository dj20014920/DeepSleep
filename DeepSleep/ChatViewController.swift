import UIKit

// MARK: - RecommendationResponse (파일 최상단에 정의)
struct RecommendationResponse {
    let volumes: [Float]
    let presetName: String
    let selectedVersions: [Int]
    
    init(volumes: [Float], presetName: String = "맞춤 프리셋", selectedVersions: [Int]? = nil) {
        self.volumes = volumes
        self.presetName = presetName
        self.selectedVersions = selectedVersions ?? Array(repeating: 0, count: SoundPresetCatalog.categoryCount)
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
        tf.backgroundColor = UIDesignSystem.Colors.adaptiveTertiaryBackground
        tf.textColor = UIDesignSystem.Colors.primaryText
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()
    
    private let sendButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("전송", for: .normal)
        btn.setTitleColor(UIDesignSystem.Colors.primaryText, for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private let presetButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("🎵 지금 기분에 맞는 사운드 추천받기", for: .normal)
        btn.backgroundColor = UIDesignSystem.Colors.adaptiveTertiaryBackground
        btn.setTitleColor(UIDesignSystem.Colors.primaryText, for: .normal)
        btn.layer.cornerRadius = 8
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    // ✅ 화면 하단 로딩 시스템 제거 (채팅 버블 내 고양이로 대체)
    
    // MARK: - Computed Properties
    private var dailyChatCount: Int {
        let todayStats = SettingsManager.shared.getTodayStats()
        return todayStats.chatCount
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
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
        if let saved = UserDefaults.standard.array(forKey: "chatHistory") as? [[String: Any]] {
            self.messages = saved.compactMap { dict -> ChatMessage? in
                guard let typeString = dict["type"] as? String,
                      let type = ChatMessageType(rawValue: typeString),
                      let text = dict["text"] as? String else { return nil }
                
                let presetName = dict["presetName"] as? String
                let message = ChatMessage(type: type, text: text, presetName: presetName)
                
                // ✅ 프리셋 적용 완료 메시지 필터링 로직 추가
                if type == .bot && text.hasPrefix("✅ ") && text.contains("프리셋이 적용되었습니다!") {
                    return nil // 이 메시지는 로드하지 않음
                }
                return message
            }
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
        
        // ✅ 화면 하단 로딩 시스템 제거됨
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
            appendChat(ChatMessage(type: .user, text: "📝 이 일기를 분석해주세요"))
            
            let initialResponse = """
            📖 \(diary.emotion) 이런 기분으로 일기를 써주셨군요 😊
            
            차근차근 마음 이야기를 나눠볼까요? 
            어떤 부분이 가장 마음에 남으셨나요? 💭
            """
            
            appendChat(ChatMessage(type: .bot, text: initialResponse))
            requestDiaryAnalysisWithTracking(diary: diary)
            
        } else if let patternData = emotionPatternData {
            appendChat(ChatMessage(type: .user, text: "📊 최근 감정 패턴을 분석해주세요"))
            
            let initialResponse = """
            📈 최근 30일간의 감정 패턴을 분석해드릴게요 😊
            
            패턴을 살펴보고 있어요... 잠시만 기다려주세요! 💭
            """
            
            appendChat(ChatMessage(type: .bot, text: initialResponse))
            requestPatternAnalysisWithTracking(patternData: patternData)
            
        } else if let userText = initialUserText,
                  userText != "일기_분석_모드" && userText != "감정_패턴_분석_모드" {
            appendChat(ChatMessage(type: .user, text: "선택한 기분: \(userText)"))
            let greeting = getEmotionalGreeting(for: userText)
            appendChat(ChatMessage(type: .bot, text: greeting))
        } else {
            appendChat(ChatMessage(type: .bot, text: "안녕하세요! 😊\n오늘 하루는 어떠셨나요? 마음 편하게 이야기해보세요 ✨"))
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
            appendChat(ChatMessage(type: .bot, text: "아직 감정 기록이 충분하지 않네요 😊 일기를 더 작성해주시면 더 정확한 분석을 도와드릴 수 있어요!"))
            return
        }
        
        appendChat(ChatMessage(type: .bot, text: "📊 최근 30일간의 감정 패턴을 분석하고 있어요... ✨"))
        
        ReplicateChatService.shared.analyzeEmotionPattern(data: emotionData) { [weak self] response in
            DispatchQueue.main.async {
                if let response = response {
                    self?.appendChat(ChatMessage(type: .bot, text: response))
                    self?.addQuickEmotionButtons()
                } else {
                    self?.appendChat(ChatMessage(type: .bot, text: "죄송해요, 분석 중 문제가 발생했습니다 😅 네트워크 연결을 확인해주세요."))
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
        
        appendChat(ChatMessage(type: .bot, text: analysisText))
        
        ReplicateChatService.shared.sendPrompt(
            message: diaryData.content,
            intent: "diary_analysis"
        ) { [weak self] response in
            DispatchQueue.main.async {
                if let response = response {
                    self?.appendChat(ChatMessage(type: .bot, text: response))
                } else {
                    self?.appendChat(ChatMessage(type: .bot, text: "죄송해요, 분석 중 문제가 발생했습니다 😅"))
                }
            }
        }
    }
    
    private func addQuickEmotionButtons() {
        appendChat(ChatMessage(type: .bot, text: "💡 더 자세한 분석을 원하시나요?\n\n🎯 개선 방법\n📈 감정 변화 추이\n💡 스트레스 관리\n\n위 키워드로 질문해보세요! ✨"))
    }

}

// MARK: - Helper Methods
extension ChatViewController {
    func incrementDailyChatCount() {
        SettingsManager.shared.incrementChatUsage()
    }
    
    // ✅ 화면 하단 로딩 시스템 제거됨 (채팅 버블 내 고양이로 대체)
    
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    // ✅ appendChat 메서드
    func appendChat(_ message: ChatMessage) {
        messages.append(message)
        print("[appendChat] 메시지 추가: \(message.text)")
        if let quickActions = message.quickActions {
            print("[appendChat] quickActions: \(quickActions)")
        }
        tableView.reloadData()
        scrollToBottom()
        
        // 기존 히스토리 저장 (로딩 메시지는 저장하지 않음)
        if message.type != .loading {
            saveChatHistory()
        }
    }
    
    func saveChatHistory() {
        let dictionaries = messages.map { message in
            var dict: [String: Any] = [
                "type": message.type.rawValue,
                "text": message.text
            ]
            if let presetName = message.presetName {
                dict["presetName"] = presetName
            }
            return dict
        }
        UserDefaults.standard.set(dictionaries, forKey: "chatHistory")
    }
    
    func scrollToBottom() {
        if !messages.isEmpty {
            let indexPath = IndexPath(row: messages.count - 1, section: 0)
            tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }
    
    // ✅ 마지막 로딩 메시지 제거
    func removeLastLoadingMessage() {
        if let lastIndex = messages.lastIndex(where: { $0.type == .loading }) {
            messages.remove(at: lastIndex)
            tableView.reloadData()
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
    
    // 🆕 퀵 액션 처리 메서드
    func handleQuickActionFromCell(_ action: String) {
        switch action {
        case "local_recommendation":
            handleLocalRecommendation()
        case "ai_recommendation":
            handleAIRecommendation()
        default:
            print("알 수 없는 퀵 액션: \(action)")
        }
    }
    
    // 🆕 로컬 추천 처리
    private func handleLocalRecommendation() {
        let userMessage = ChatMessage(type: .user, text: "🏠 로컬 기반으로 추천받기")
        appendChat(userMessage)
        
        // 현재 시간대 기반 추천
        let currentTimeOfDay = getCurrentTimeOfDay()
        var recommendedEmotion = "평온"
        
        // 시간대별 기본 감정 추천
        switch currentTimeOfDay {
        case "새벽", "자정":
            recommendedEmotion = "수면"
        case "아침":
            recommendedEmotion = "활력"
        case "오전", "점심":
            recommendedEmotion = "집중"
        case "오후":
            recommendedEmotion = "안정"
        case "저녁":
            recommendedEmotion = "이완"
        case "밤":
            recommendedEmotion = "수면"
        default:
            recommendedEmotion = "평온"
        }
        
        // 로컬 추천 시스템으로 프리셋 생성
        let baseVolumes = SoundPresetCatalog.getRecommendedPreset(for: recommendedEmotion)
        let recommendedPreset = (
            name: "🏠 \(recommendedEmotion) 로컬 추천",
            volumes: baseVolumes,
            description: "\(currentTimeOfDay) 시간대에 적합한 \(recommendedEmotion) 상태의 로컬 추천 사운드입니다.",
            versions: SoundPresetCatalog.defaultVersions
        )
        
        // 사용자 친화적인 메시지 생성
        let presetMessage = """
        🏠 **로컬 기반 추천**
        현재 시간: \(currentTimeOfDay)
        추천 상태: \(recommendedEmotion)
        
        🎵 **[\(recommendedPreset.name)]**
        \(recommendedPreset.description)
        
        로컬 알고리즘으로 현재 시간대에 최적화된 사운드 조합을 선별했습니다. 바로 적용해보세요! ✨
        
        ℹ️ 이 추천은 AI 사용량에 영향을 주지 않는 로컬 추천입니다.
        """
        
        // 프리셋 적용 메시지 추가
        var chatMessage = ChatMessage(type: .presetRecommendation, text: presetMessage)
        chatMessage.onApplyPreset = { [weak self] in
            self?.applyLocalPreset(recommendedPreset)
        }
        
        appendChat(chatMessage)
    }
    
    // 🆕 AI 추천 처리
    private func handleAIRecommendation() {
        // AI 사용량 확인
        if !AIUsageManager.shared.canUse(feature: .presetRecommendation) {
            let limitMessage = ChatMessage(type: .bot, text: "오늘의 AI 추천 횟수를 모두 사용했어요. 로컬 추천을 이용해보세요! 😊")
            appendChat(limitMessage)
            return
        }
        
        let userMessage = ChatMessage(type: .user, text: "🤖 AI에게 추천받기")
        appendChat(userMessage)
        
        // 로딩 메시지 추가
        appendChat(ChatMessage(type: .loading, text: "AI가 분석 중..."))
        
        // AI 분석 요청
        ReplicateChatService.shared.sendPrompt(
            message: "지금 기분에 맞는 사운드 프리셋을 추천해주세요",
            intent: "emotion_analysis_for_preset"
        ) { [weak self] response in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // 로딩 메시지 제거
                self.removeLastLoadingMessage()
                
                if let analysisResult = response, !analysisResult.isEmpty {
                    // AI 분석 결과 파싱
                    let parsedAnalysis = self.parseEmotionAnalysis(analysisResult)
                    
                    // 로컬 추천 시스템으로 프리셋 생성
                    let recommendedVolumes = SoundPresetCatalog.getRecommendedPreset(for: parsedAnalysis.emotion)
                    let recommendedPreset = (
                        name: "\(parsedAnalysis.emotion) AI 추천",
                        volumes: recommendedVolumes,
                        description: "\(parsedAnalysis.emotion) 감정에 최적화된 AI 추천 사운드 조합",
                        versions: SoundPresetCatalog.defaultVersions
                    )
                    
                    // 사용자 친화적인 메시지 생성
                    let presetMessage = """
                    🤖 **AI 분석 완료**
                    감정 상태: \(parsedAnalysis.emotion)
                    시간대: \(parsedAnalysis.timeOfDay)
                    
                    🎵 **[\(recommendedPreset.name)]**
                    \(recommendedPreset.description)
                    
                    AI가 현재 상황을 종합적으로 분석하여 선별한 최적의 사운드 조합입니다! ✨
                    """
                    
                    // 프리셋 적용 메시지 추가
                    var chatMessage = ChatMessage(type: .presetRecommendation, text: presetMessage)
                    chatMessage.onApplyPreset = { [weak self] in
                        self?.applyLocalPreset(recommendedPreset)
                    }
                    
                    self.appendChat(chatMessage)
                    AIUsageManager.shared.recordUsage(for: .presetRecommendation)
                    
                } else {
                    // AI 분석 실패 시 기본 추천
                    let fallbackVolumes = SoundPresetCatalog.getRecommendedPreset(for: "평온")
                    let fallbackPreset = (
                        name: "평온 기본 추천",
                        volumes: fallbackVolumes,
                        description: "편안하고 균형잡힌 기본 사운드 조합",
                        versions: SoundPresetCatalog.defaultVersions
                    )
                    
                    let fallbackMessage = "🎵 [평온한 기본 추천] 현재 시간에 맞는 균형잡힌 사운드 조합입니다."
                    
                    var chatMessage = ChatMessage(type: .presetRecommendation, text: fallbackMessage)
                    chatMessage.onApplyPreset = { [weak self] in
                        self?.applyLocalPreset(fallbackPreset)
                    }
                    
                    self.appendChat(chatMessage)
                    AIUsageManager.shared.recordUsage(for: .presetRecommendation)
                }
            }
        }
    }
    
    // 🆕 프리셋 적용 로직
    private func applyLocalPreset(_ preset: (name: String, volumes: [Float], description: String, versions: [Int])) {
        print("🎵 프리셋 적용 시작: \(preset.name)")
        
        // 1. 기존 사운드 정지
        SoundManager.shared.stopAll()
        
        // 2. 버전 정보 적용
        for (categoryIndex, versionIndex) in preset.versions.enumerated() {
            if categoryIndex < SoundPresetCatalog.categoryCount {
                SettingsManager.shared.updateSelectedVersion(for: categoryIndex, to: versionIndex)
            }
        }
        
        // 3. 볼륨 설정 적용
        for (index, volume) in preset.volumes.enumerated() {
            if index < SoundPresetCatalog.categoryCount {
                SoundManager.shared.setVolume(for: index, volume: volume / 100.0)
            }
        }
        
        // 4. 사운드 재생
        SoundManager.shared.playActiveSounds()
        
        // 5. 메인 화면 UI 업데이트 알림
        NotificationCenter.default.post(name: NSNotification.Name("SoundVolumesUpdated"), object: nil)
        
        // 6. 성공 메시지
        let successMessage = ChatMessage(type: .bot, text: "✅ '\(preset.name)' 프리셋이 적용되었습니다! 지금 바로 편안한 사운드를 즐겨보세요. 🎵")
        appendChat(successMessage)
        
        // 7. 메인 화면으로 이동 버튼 제공
        let backToMainMessage = ChatMessage(type: .bot, text: "🏠 메인 화면으로 이동해서 사운드를 조정해보세요!")
        appendChat(backToMainMessage)
        
        print("🎵 프리셋 적용 완료: \(preset.name)")
    }
    
    // 🆕 감정 분석 결과 파싱
    private func parseEmotionAnalysis(_ analysis: String) -> (emotion: String, timeOfDay: String, intensity: Float) {
        var emotion = "평온"
        let timeOfDay = getCurrentTimeOfDay()
        var intensity: Float = 1.0
        
        // 감정 파싱
        if let emotionMatch = analysis.range(of: #"감정:\s*([가-힣]+)"#, options: .regularExpression) {
            emotion = String(analysis[emotionMatch]).replacingOccurrences(of: "감정:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let mainEmotionMatch = analysis.range(of: #"주감정:\s*([가-힣]+)"#, options: .regularExpression) {
            emotion = String(analysis[mainEmotionMatch]).replacingOccurrences(of: "주감정:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 강도 파싱
        if analysis.contains("강도: 높음") || analysis.contains("강도: 5") {
            intensity = 1.5
        } else if analysis.contains("강도: 보통") || analysis.contains("강도: 3") || analysis.contains("강도: 4") {
            intensity = 1.0
        } else if analysis.contains("강도: 낮음") || analysis.contains("강도: 1") || analysis.contains("강도: 2") {
            intensity = 0.7
        }
        
        return (emotion, timeOfDay, intensity)
    }
    
    // 🆕 현재 시간대 확인
    private func getCurrentTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<7: return "새벽"
        case 7..<10: return "아침"
        case 10..<12: return "오전"
        case 12..<14: return "점심"
        case 14..<18: return "오후"
        case 18..<21: return "저녁"
        case 21..<24: return "밤"
        default: return "자정"
        }
    }
}
