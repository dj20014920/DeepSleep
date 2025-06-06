import UIKit

class EmotionAnalysisChatViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .onDrag
        return scrollView
    }()
    
    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let summaryView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue.withAlphaComponent(0.1)
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let summaryLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let messageInputContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.separator.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let messageTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "감정에 대해 더 궁금한 점이 있나요?"
        textField.borderStyle = .none
        textField.font = .systemFont(ofSize: 16)
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let sendButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("전송", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // MARK: - Properties
    var emotionPatternData: String = ""
    private var chatHistory: [(isUser: Bool, message: String)] = []
    private var isWaitingForResponse = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardNotifications()
        startInitialAnalysis()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        title = "🤖 감정 패턴 분석"
        
        // 닫기 버튼
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "닫기",
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        
        setupScrollView()
        setupSummaryView()
        setupInputContainer()
        setupConstraints()
    }
    
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
    }
    
    private func setupSummaryView() {
        contentStackView.addArrangedSubview(summaryView)
        summaryView.addSubview(summaryLabel)
        
        NSLayoutConstraint.activate([
            summaryLabel.topAnchor.constraint(equalTo: summaryView.topAnchor, constant: 16),
            summaryLabel.leadingAnchor.constraint(equalTo: summaryView.leadingAnchor, constant: 16),
            summaryLabel.trailingAnchor.constraint(equalTo: summaryView.trailingAnchor, constant: -16),
            summaryLabel.bottomAnchor.constraint(equalTo: summaryView.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupInputContainer() {
        view.addSubview(messageInputContainer)
        messageInputContainer.addSubview(messageTextField)
        messageInputContainer.addSubview(sendButton)
        messageInputContainer.addSubview(loadingIndicator)
        
        messageTextField.delegate = self
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 스크롤뷰
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: messageInputContainer.topAnchor),
            
            // 콘텐츠 스택뷰
            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
            
            // 입력 컨테이너
            messageInputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            messageInputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            messageInputContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            messageInputContainer.heightAnchor.constraint(equalToConstant: 60),
            
            // 메시지 텍스트필드
            messageTextField.leadingAnchor.constraint(equalTo: messageInputContainer.leadingAnchor, constant: 16),
            messageTextField.centerYAnchor.constraint(equalTo: messageInputContainer.centerYAnchor),
            messageTextField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -12),
            
            // 전송 버튼
            sendButton.trailingAnchor.constraint(equalTo: messageInputContainer.trailingAnchor, constant: -16),
            sendButton.centerYAnchor.constraint(equalTo: messageInputContainer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 60),
            sendButton.heightAnchor.constraint(equalToConstant: 36),
            
            // 로딩 인디케이터
            loadingIndicator.centerXAnchor.constraint(equalTo: sendButton.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: sendButton.centerYAnchor)
        ])
    }
    
    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    // MARK: - Initial Analysis
    private func startInitialAnalysis() {
        // 감정 패턴 데이터를 요약해서 표시
        summaryLabel.text = """
        📊 분석 중인 데이터:
        \(emotionPatternData.isEmpty ? "최근 감정 기록이 없습니다." : emotionPatternData)
        
        💬 AI가 당신의 감정 패턴을 분석하고 있어요...
        """
        
        // AI 초기 분석 시작
        performInitialAnalysis()
    }
    
    private func performInitialAnalysis() {
        guard !emotionPatternData.isEmpty else {
            addAIMessage("아직 감정 기록이 충분하지 않네요. 일기를 더 작성해주시면 더 정확한 분석을 도와드릴 수 있어요! 😊")
            return
        }
        
        setLoading(true)
        
        // ✅ 최적화된 감정 분석 메서드 사용
        ReplicateChatService.shared.analyzeEmotionPattern(data: emotionPatternData) { [weak self] response in
            DispatchQueue.main.async {
                self?.setLoading(false)
                if let response = response {
                    self?.addAIMessage(response)
                    self?.addQuickActionButtons()
                } else {
                    self?.addAIMessage("죄송해요, 분석 중 문제가 발생했습니다. 네트워크 연결을 확인해주세요.")
                }
            }
        }
    }
    
    // MARK: - Optimized Prompt Creation
    private func createOptimizedAnalysisPrompt() -> String {
        // 토큰을 최소화하면서 핵심 정보만 전달
        let lines = emotionPatternData.components(separatedBy: "\n")
        let summary = lines.prefix(10).joined(separator: "\n") // 첫 10줄만
        
        return """
        감정패턴:\(summary)
        
        간단분석+3가지조언+질문 요청
        """
    }
    
    // MARK: - Chat Management
    private func addUserMessage(_ message: String) {
        chatHistory.append((isUser: true, message: message))
        
        let messageView = createMessageBubble(message: message, isUser: true)
        contentStackView.addArrangedSubview(messageView)
        
        scrollToBottom()
    }
    
    private func addAIMessage(_ message: String) {
        chatHistory.append((isUser: false, message: message))
        
        let messageView = createMessageBubble(message: message, isUser: false)
        contentStackView.addArrangedSubview(messageView)
        
        scrollToBottom()
    }
    
    private func createMessageBubble(message: String, isUser: Bool) -> UIView {
        let containerView = UIView()
        
        let bubbleView = UIView()
        bubbleView.backgroundColor = isUser ? .systemBlue : .systemGray5
        bubbleView.layer.cornerRadius = 16
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = .systemFont(ofSize: 16)
        messageLabel.textColor = isUser ? .white : .label
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(bubbleView)
        bubbleView.addSubview(messageLabel)
        
        let leadingConstraint = isUser ?
            bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 60) :
            bubbleView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor)
        
        let trailingConstraint = isUser ?
            bubbleView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor) :
            bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -60)
        
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: containerView.topAnchor),
            bubbleView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            leadingConstraint,
            trailingConstraint,
            
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12)
        ])
        
        return containerView
    }
    
    private func addQuickActionButtons() {
        let buttonStackView = UIStackView()
        buttonStackView.axis = .vertical
        buttonStackView.spacing = 8
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        
        let quickActions = [
            ("🎯 개선 방법이 궁금해요", "improvement_tips"),
            ("📈 감정 변화 추이 설명해주세요", "trend_analysis"),
            ("💡 스트레스 관리 조언 주세요", "stress_management"),
            ("🎵 지금 기분에 맞는 사운드 추천받기", "preset_recommendation")
        ]
        
        for (title, intent) in quickActions {
            let button = createQuickActionButton(title: title, intent: intent)
            buttonStackView.addArrangedSubview(button)
        }
        
        contentStackView.addArrangedSubview(buttonStackView)
        scrollToBottom()
    }
    
    private func createQuickActionButton(title: String, intent: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.backgroundColor = .systemBlue.withAlphaComponent(0.1)
        button.setTitleColor(.systemBlue, for: .normal)
        button.layer.cornerRadius = 8
        button.titleLabel?.font = .systemFont(ofSize: 14)
        
        // contentEdgeInsets 대신 UIButton.Configuration 사용
        if #available(iOS 15.0, *) {
            var config = button.configuration ?? UIButton.Configuration.plain() // 기본 plain 스타일 사용
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
            button.configuration = config
        } else {
            // iOS 15 미만에서는 기존 방식 사용
            button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        }
        
        button.addAction(UIAction { [weak self] _ in
            self?.handleQuickAction(title: title, intent: intent)
        }, for: .touchUpInside)
        
        return button
    }
    
    private func handleQuickAction(title: String, intent: String) {
        addUserMessage(title)
        
        setLoading(true)
        
        // 🆕 프리셋 추천 인텐트 처리
        if intent == "preset_recommendation" {
            handlePresetRecommendation()
            return
        }
        
        // ✅ 최적화된 빠른 팁 메서드 사용
        let emotionSummary = extractRecentEmotions()
        let tipType = mapIntentToTipType(intent)
        
        ReplicateChatService.shared.getQuickEmotionTip(
            emotion: emotionSummary,
            type: tipType
        ) { [weak self] response in
            DispatchQueue.main.async {
                self?.setLoading(false)
                if let response = response {
                    self?.addAIMessage(response)
                } else {
                    self?.addAIMessage("죄송해요, 응답 중 문제가 발생했습니다.")
                }
            }
        }
    }
    
    // 🆕 프리셋 추천 처리 메서드
    private func handlePresetRecommendation() {
        guard AIUsageManager.shared.canUse(feature: .presetRecommendation) else {
            let limitMessage = "오늘의 추천 횟수를 모두 사용했어요. 내일 새로운 추천을 받아보세요! ✨"
            addAIMessage(limitMessage)
            return
        }
        
        addUserMessage("🎵 지금 기분에 맞는 사운드 추천받기")
        setLoading(true)
        
        // 🆕 하이브리드 방식: AI는 감정 분석만, 프리셋은 로컬에서
        ReplicateChatService.shared.sendPrompt(
            message: "지금 기분에 맞는 사운드 프리셋을 추천해주세요",
            intent: "emotion_analysis_for_preset"
        ) { [weak self] response in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.setLoading(false)
                
                if let analysisResult = response, !analysisResult.isEmpty {
                    // AI 분석 결과 파싱
                    let parsedAnalysis = self.parseEmotionAnalysis(analysisResult)
                    
                    // 로컬 추천 시스템으로 프리셋 생성
                    let recommendedPreset = SoundPresetCatalog.getRecommendedPreset(
                        emotion: parsedAnalysis.emotion,
                        timeOfDay: parsedAnalysis.timeOfDay,
                        previousRecommendations: [],
                        intensity: parsedAnalysis.intensity
                    )
                    
                    // 사용자 친화적인 메시지 생성
                    let presetMessage = self.createUserFriendlyPresetMessage(
                        analysis: parsedAnalysis,
                        preset: recommendedPreset
                    )
                    
                    // 프리셋 적용 메시지 추가
                    self.addPresetRecommendationMessage(presetMessage, preset: recommendedPreset)
                    AIUsageManager.shared.recordUsage(for: .presetRecommendation)
                    
                } else {
                    // AI 분석 실패 시 기본 추천
                    let fallbackPreset = SoundPresetCatalog.getRecommendedPreset(
                        emotion: "평온",
                        timeOfDay: self.getCurrentTimeOfDay()
                    )
                    
                    let fallbackMessage = "🎵 [평온한 기본 추천] 현재 시간에 맞는 균형잡힌 사운드 조합입니다."
                    
                    self.addPresetRecommendationMessage(fallbackMessage, preset: fallbackPreset)
                    AIUsageManager.shared.recordUsage(for: .presetRecommendation)
                }
            }
        }
    }
    
    // 🆕 프리셋 추천 메시지 추가 (버튼 포함)
    private func addPresetRecommendationMessage(_ message: String, preset: (name: String, volumes: [Float], description: String, versions: [Int])) {
        addAIMessage(message)
        
        // 프리셋 적용 버튼 추가
        let applyButton = UIButton(type: .system)
        applyButton.setTitle("🎵 이 프리셋 적용하기", for: .normal)
        applyButton.backgroundColor = .systemBlue
        applyButton.setTitleColor(.white, for: .normal)
        applyButton.layer.cornerRadius = 12
        applyButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        
        if #available(iOS 15.0, *) {
            var config = applyButton.configuration ?? UIButton.Configuration.filled()
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
            applyButton.configuration = config
        } else {
            applyButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        }
        
        applyButton.addAction(UIAction { [weak self] _ in
            self?.applyLocalPreset(preset)
        }, for: .touchUpInside)
        
        contentStackView.addArrangedSubview(applyButton)
        scrollToBottom()
    }
    
    // 🆕 프리셋 파싱 (ChatViewController+Actions.swift와 동일)
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
    
    // 🆕 사용자 친화적 메시지 생성
    private func createUserFriendlyPresetMessage(
        analysis: (emotion: String, timeOfDay: String, intensity: Float),
        preset: (name: String, volumes: [Float], description: String, versions: [Int])
    ) -> String {
        let intensityText = analysis.intensity > 1.2 ? "강한" : analysis.intensity < 0.8 ? "부드러운" : "적절한"
        
        return """
        💭 **감정 분석 완료**
        현재 상태: \(analysis.emotion) (\(intensityText) 강도)
        시간대: \(analysis.timeOfDay)
        
        🎵 **[\(preset.name)]**
        \(preset.description)
        
        이 조합은 현재 기분에 특별히 맞춰 선별된 사운드들입니다. 바로 적용해보세요! ✨
        """
    }
    
    // 🆕 로컬 프리셋 적용
    private func applyLocalPreset(_ preset: (name: String, volumes: [Float], description: String, versions: [Int])) {
        // 1. 버전 정보 적용
        for (categoryIndex, versionIndex) in preset.versions.enumerated() {
            if categoryIndex < SoundPresetCatalog.categoryCount {
                SettingsManager.shared.updateSelectedVersion(for: categoryIndex, to: versionIndex)
            }
        }
        
        // 2. 볼륨 설정 적용
        for (index, volume) in preset.volumes.enumerated() {
            if index < SoundPresetCatalog.categoryCount {
                SoundManager.shared.setVolume(for: index, volume: volume / 100.0)
            }
        }
        
        // 3. 메인 화면 UI 업데이트 알림
        NotificationCenter.default.post(name: NSNotification.Name("SoundVolumesUpdated"), object: nil)
        
        // 4. 성공 메시지
        let successMessage = "✅ '\(preset.name)' 프리셋이 적용되었습니다! 지금 바로 편안한 사운드를 즐겨보세요. 🎵"
        addAIMessage(successMessage)
        
        // 5. 메인 화면으로 이동 옵션
        let backButton = UIButton(type: .system)
        backButton.setTitle("🏠 메인 화면으로 이동", for: .normal)
        backButton.backgroundColor = .systemGreen
        backButton.setTitleColor(.white, for: .normal)
        backButton.layer.cornerRadius = 10
        
        if #available(iOS 15.0, *) {
            var config = backButton.configuration ?? UIButton.Configuration.filled()
            config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
            backButton.configuration = config
        } else {
            backButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        }
        
        backButton.addAction(UIAction { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        }, for: .touchUpInside)
        
        contentStackView.addArrangedSubview(backButton)
        scrollToBottom()
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
    
    // MARK: - Actions
    @objc private func sendTapped() {
        sendMessage()
    }
    
    private func sendMessage() {
        guard let message = messageTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !message.isEmpty,
              !isWaitingForResponse else { return }
        
        addUserMessage(message)
        messageTextField.text = ""
        
        // 맥락을 고려한 응답 생성
        let contextualPrompt = "\(message)\n감정공감+조언"
        sendAIRequest(prompt: contextualPrompt, intent: "diary")
    }
    
    private func sendAIRequest(prompt: String, intent: String) {
        setLoading(true)
        
        // ✅ 대화 맥락을 고려한 최적화된 응답
        let conversationContext = chatHistory.suffix(3).map { $0.message }.joined(separator: " ")
        
        ReplicateChatService.shared.respondToEmotionQuery(
            query: prompt,
            context: conversationContext
        ) { [weak self] response in
            DispatchQueue.main.async {
                self?.setLoading(false)
                if let response = response {
                    self?.addAIMessage(response)
                } else {
                    self?.addAIMessage("죄송해요, 응답 중 문제가 발생했습니다.")
                }
            }
        }
    }
    
    private func setLoading(_ loading: Bool) {
        isWaitingForResponse = loading
        sendButton.isHidden = loading
        messageTextField.isEnabled = !loading
        
        if loading {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    // MARK: - Keyboard Handling
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        
        let keyboardHeight = keyboardFrame.cgRectValue.height
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.3
        
        UIView.animate(withDuration: duration) {
            self.view.frame.origin.y = -keyboardHeight + self.view.safeAreaInsets.bottom
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.3
        
        UIView.animate(withDuration: duration) {
            self.view.frame.origin.y = 0
        }
    }
    
    // MARK: - Utilities
    private func scrollToBottom() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let bottomOffset = CGPoint(x: 0, y: max(0, self.scrollView.contentSize.height - self.scrollView.bounds.height))
            self.scrollView.setContentOffset(bottomOffset, animated: true)
        }
    }
    
    private func mapIntentToTipType(_ intent: String) -> String {
        switch intent {
        case "improvement_tips":
            return "improvement"
        case "trend_analysis":
            return "trend"
        case "stress_management":
            return "stress"
        default:
            return "general"
        }
    }
    
    private func extractRecentEmotions() -> String {
        let lines = emotionPatternData.components(separatedBy: "\n")
        return lines.prefix(3).joined(separator: ",")
    }
}

// MARK: - UITextFieldDelegate
extension EmotionAnalysisChatViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendMessage()
        return true
    }
}
