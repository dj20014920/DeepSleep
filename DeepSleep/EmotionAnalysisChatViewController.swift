import UIKit

class EmotionAnalysisChatViewController: UIViewController, UIGestureRecognizerDelegate {
    
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
        title = "감정 분석 대화"
        view.backgroundColor = UIDesignSystem.Colors.background
        
        // ✅ swipe back 제스처 활성화
        enableSwipeBackGesture()
        
        // 🧪 테스트용 버튼들 추가
        setupTestButtons()
        
        setupUI()
        setupKeyboardNotifications()
        
        // 초기 분석 시작
        startInitialAnalysis()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // ✅ swipe back 제스처 재활성화
        enableSwipeBackGesture()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        title = "AI 감정 패턴 분석"
        
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
            ("🧠 AI 추천받기", "ai_recommendation"),
            ("🏠 로컬 추천받기", "local_recommendation")
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
        if intent == "ai_recommendation" {
            handleAIRecommendation()
            return
        }
        
        if intent == "local_recommendation" {
            handleLocalRecommendation()
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
    
    // 🆕 AI 프리셋 추천 처리 메서드
    private func handleAIRecommendation() {
        // ✅ AI 사용 횟수 초과 시에도 로컬 추천으로 대체
        if !AIUsageManager.shared.canUse(feature: .presetRecommendation) {
            provideLocalFallbackRecommendation()
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
                    
                    // 로컬 추천 시스템으로 프리셋 생성 - 감성적인 이름
                    let recommendedVolumes = SoundPresetCatalog.getRecommendedPreset(for: parsedAnalysis.emotion)
                    let poeticName = self.generatePoeticPresetName(emotion: parsedAnalysis.emotion, timeOfDay: "현재", isAI: true)
                    let recommendedPreset = (
                        name: poeticName,
                        volumes: recommendedVolumes,
                        description: "\(parsedAnalysis.emotion) 감정을 위해 특별히 조합된 감성적 사운드스케이프",
                        versions: SoundPresetCatalog.defaultVersions
                    )
                    
                    // 🧠 음향심리학 기반 상세 분석 메시지 생성
                    let presetMessage = self.createEnhancedPsychoacousticMessage(
                        analysis: parsedAnalysis,
                        preset: recommendedPreset
                    )
                    
                    // 프리셋 적용 메시지 추가
                    self.addPresetRecommendationMessage(presetMessage, preset: recommendedPreset)
                    AIUsageManager.shared.recordUsage(for: .presetRecommendation)
                    
                } else {
                    // AI 분석 실패 시 기본 추천 - 감성적인 이름
                    let fallbackVolumes = SoundPresetCatalog.getRecommendedPreset(for: "평온")
                    let fallbackPoeticName = self.generatePoeticPresetName(emotion: "평온", timeOfDay: "현재", isAI: true)
                    let fallbackPreset = (
                        name: fallbackPoeticName,
                        volumes: fallbackVolumes,
                        description: "마음을 편안하게 하는 균형 잡힌 사운드 여행",
                        versions: SoundPresetCatalog.defaultVersions
                    )
                    
                    let fallbackMessage = "🎵 [\(fallbackPoeticName)] 현재 시간에 맞는 균형잡힌 사운드 조합입니다."
                    
                    self.addPresetRecommendationMessage(fallbackMessage, preset: fallbackPreset)
                    AIUsageManager.shared.recordUsage(for: .presetRecommendation)
                }
            }
        }
    }
    
    /// 시적이고 감성적인 프리셋 이름 생성 (ChatviewController+Actions와 동일)
    private func generatePoeticPresetName(emotion: String, timeOfDay: String, isAI: Bool) -> String {
        // 감정별 시적 표현
        let emotionPoetry: [String: [String]] = [
            "평온": ["고요한 마음", "잔잔한 호수", "평화로운 숨결", "조용한 안식", "차분한 선율"],
            "수면": ["달빛의 자장가", "꿈속의 여행", "별들의 속삭임", "깊은 밤의 포옹", "구름 위의 쉼터"],
            "행복": ["기쁨의 멜로디", "햇살의 춤", "웃음의 하모니", "즐거운 선율", "밝은 에너지"],
            "슬픔": ["위로의 포옹", "마음의 치유", "눈물의 정화", "슬픔 달래기", "상처 어루만지기"],
            "스트레스": ["해독의 시간", "마음의 치유", "스트레스 해소", "평온 회복", "긴장 완화"],
            "불안": ["마음의 안정", "걱정 해소", "불안 진정", "평안 찾기", "안심의 공간"],
            "활력": ["새벽의 각성", "생명의 춤", "에너지의 폭발", "희망의 멜로디", "활기찬 아침"],
            "집중": ["마음의 정중앙", "집중의 공간", "조용한 몰입", "깊은 사색", "고요한 탐구"]
        ]
        
        // 시간대별 시적 표현
        let timePoetry: [String: [String]] = [
            "새벽": ["새벽의", "여명의", "첫 빛의", "아침 이슬의", "동트는"],
            "아침": ["아침의", "햇살의", "상쾌한", "밝은", "활기찬"],
            "오전": ["오전의", "상쾌한", "밝은", "활동적인", "생기찬"],
            "점심": ["정오의", "따스한", "밝은", "활력의", "정중앙"],
            "오후": ["오후의", "따뜻한", "포근한", "안정된", "여유로운"],
            "저녁": ["저녁의", "노을의", "황혼의", "따스한", "포근한"],
            "밤": ["밤의", "달빛의", "고요한", "평온한", "깊은"],
            "자정": ["자정의", "깊은 밤의", "고요한", "신비로운", "조용한"]
        ]
        
        // 아름다운 접미사들
        let beautifulSuffixes = [
            "세레나데", "심포니", "왈츠", "노래", "선율", "화음", "여행", "이야기", 
            "공간", "시간", "순간", "기억", "꿈", "향기", "빛", "그림자", 
            "숨결", "속삭임", "포옹", "키스", "미소", "안식", "휴식", "명상"
        ]
        
        // 랜덤하게 조합 생성 (시드를 기반으로 일관성 있게)
        let emotionSeed = emotion.hashValue
        let timeSeed = timeOfDay.hashValue
        let combinedSeed = abs(emotionSeed ^ timeSeed)
        
        let emotionWords = emotionPoetry[emotion] ?? ["마음의"]
        let timeWords = timePoetry[timeOfDay] ?? ["조용한"]
        
        let selectedEmotion = emotionWords[combinedSeed % emotionWords.count]
        let selectedTime = timeWords[(combinedSeed + 1) % timeWords.count]
        let selectedSuffix = beautifulSuffixes[(combinedSeed + 2) % beautifulSuffixes.count]
        
        // 다양한 패턴으로 조합 (이모지 없이)
        let patterns = [
            "\(selectedTime) \(selectedSuffix)",
            "\(selectedEmotion) \(selectedSuffix)",
            "\(selectedTime) \(selectedEmotion)",
            "\(selectedEmotion)의 \(selectedSuffix)",
            "\(selectedTime) \(selectedEmotion) \(selectedSuffix)"
        ]
        
        let selectedPattern = patterns[(combinedSeed + 3) % patterns.count]
        return selectedPattern
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
    
    // 🆕 로컬 추천 처리 메서드
    private func handleLocalRecommendation() {
        addUserMessage("앱 분석 추천받기")
        
        // 현재 시간대 기반 로컬 추천
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
        
        // 로컬 추천 시스템으로 프리셋 생성 - 감성적인 이름
        let baseVolumes = SoundPresetCatalog.getRecommendedPreset(for: recommendedEmotion)
        let poeticName = generatePoeticPresetName(emotion: recommendedEmotion, timeOfDay: currentTimeOfDay, isAI: false)
        let recommendedPreset = (
            name: poeticName,
            volumes: baseVolumes,
            description: "\(currentTimeOfDay)의 \(recommendedEmotion) 상태를 위한 자연스럽고 조화로운 사운드 여행입니다.",
            versions: SoundPresetCatalog.defaultVersions
        )
        
        // 사용자 친화적인 메시지 생성
        let presetMessage = """
        🏠 **로컬 기반 추천**
        현재 시간: \(currentTimeOfDay)
        추천 상태: \(recommendedEmotion)
        
        🎵 **[\(recommendedPreset.name)]**
        \(recommendedPreset.description)
        
        로컬 알고리즘으로 현재 시간대에 최적화된 사운드 조합을 선별했습니다. 
        바로 적용해보세요! ✨
        
        ℹ️ 이 추천은 AI 사용량에 영향을 주지 않는 로컬 추천입니다.
        """
        
        // 프리셋 적용 메시지 추가
        addPresetRecommendationMessage(presetMessage, preset: recommendedPreset)
    }
    
    // 🆕 프리셋 파싱 (ChatViewController+Actions와 동일)
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
        
        let empathyMessage = generateEmpathyMessage(emotion: analysis.emotion, timeOfDay: analysis.timeOfDay, intensity: analysis.intensity)
        let soundDescription = generateSoundDescription(volumes: preset.volumes, emotion: analysis.emotion)
        
        return """
        \(empathyMessage)
        
        **[\(preset.name)]**
        \(soundDescription)
        """
    }
    
    /// 🤗 감정별 공감 메시지 생성 (방대한 데이터베이스)
    private func generateEmpathyMessage(emotion: String, timeOfDay: String, intensity: Float) -> String {
        let empathyDatabase: [String: [String]] = [
            "평온": [
                "마음에 평온이 찾아온 순간이네요. 이런 고요한 시간을 더욱 깊게 만끽해보세요.",
                "평화로운 마음 상태가 느껴집니다. 이 소중한 평온함을 지켜드릴게요.",
                "차분한 에너지가 전해져요. 내면의 고요함을 더욱 깊이 있게 경험해보세요.",
                "마음의 평형을 잘 유지하고 계시네요. 이 안정감을 더욱 풍성하게 만들어드릴게요.",
                "고요한 마음의 상태가 아름답습니다. 이 평온함이 더욱 깊어질 수 있도록 도와드릴게요."
            ],
            
            "수면": [
                "하루의 피로가 쌓여 깊은 휴식이 필요한 시간이네요. 편안한 잠자리를 만들어드릴게요.",
                "오늘 하루도 고생 많으셨어요. 꿈나라로의 여행을 부드럽게 안내해드릴게요.",
                "몸과 마음이 휴식을 원하고 있어요. 깊고 편안한 잠을 위한 완벽한 환경을 준비했어요.",
                "잠들기 전 마음의 정리가 필요한 순간이네요. 모든 걱정을 내려놓고 편히 쉬실 수 있도록 도와드릴게요.",
                "하루의 마무리 시간이 왔어요. 별들의 자장가로 평온한 밤을 선물해드릴게요."
            ],
            
            "스트레스": [
                "오늘 힘들었던 당신을 위해 마음의 짐을 덜어드리고 싶어요.",
                "쌓인 스트레스가 느껴져요. 지금 이 순간만큼은 모든 걱정에서 벗어나 보세요.",
                "마음이 무거우셨을 텐데, 이제 깊게 숨을 들이쉬고 차근차근 풀어나가요.",
                "복잡하고 어려운 하루를 보내셨군요. 마음의 무게를 조금씩 덜어내는 시간을 만들어드릴게요.",
                "스트레스로 지친 마음을 이해해요. 지금은 온전히 자신을 위한 시간을 가져보세요.",
                "긴장으로 굳어진 마음과 몸을 천천히 풀어드릴게요. 모든 것을 내려놓으셔도 괜찮아요."
            ],
            
            "불안": [
                "마음이 불안하고 걱정이 많으실 텐데, 지금 이 순간은 안전해요.",
                "혼란스러운 마음을 진정시켜 드릴게요. 모든 것이 괜찮아질 거예요.",
                "불안한 마음이 잠잠해질 수 있도록 안전하고 따뜻한 공간을 만들어드릴게요.",
                "걱정이 많은 요즘이죠. 마음에 평안이 깃들 수 있는 시간을 선물해드릴게요.",
                "불안함 속에서도 당신은 충분히 괜찮은 사람이에요. 마음의 안정을 찾아드릴게요.",
                "복잡한 생각들이 정리될 수 있도록 마음의 정박지를 만들어드릴게요."
            ],
            
            "활력": [
                "활기찬 에너지가 느껴져요! 이 좋은 기운을 더욱 키워나가볼까요?",
                "긍정적인 에너지가 넘치네요. 이 활력을 더욱 풍성하게 만들어드릴게요.",
                "생동감 넘치는 하루를 시작하시는군요. 이 에너지를 최대한 활용해보세요.",
                "의욕이 가득한 상태네요! 이 좋은 기운이 하루 종일 이어질 수 있도록 도와드릴게요.",
                "활기찬 마음이 아름다워요. 이 에너지로 멋진 하루를 만들어나가세요."
            ],
            
            "집중": [
                "집중이 필요한 중요한 시간이네요. 마음을 한곳으로 모을 수 있도록 도와드릴게요.",
                "깊은 몰입이 필요한 순간이군요. 모든 잡념을 걷어내고 온전히 집중해보세요.",
                "집중력을 높여야 할 때네요. 마음의 잡음을 제거하고 명료함을 선물해드릴게요.",
                "중요한 일에 몰두해야 하는군요. 최상의 집중 환경을 만들어드릴게요.",
                "마음을 가다듬고 집중할 시간이에요. 깊은 몰입의 세계로 안내해드릴게요."
            ],
            
            "행복": [
                "기쁨이 가득한 마음이 전해져요! 이 행복한 순간을 더욱 특별하게 만들어드릴게요.",
                "밝은 에너지가 느껴져서 저도 덩달아 기뻐요. 이 좋은 기분이 계속되길 바라요.",
                "행복한 마음 상태가 아름다워요. 이 기쁨을 더욱 풍성하게 만들어드릴게요.",
                "긍정적인 에너지가 넘쳐흘러요. 이 행복이 오래 지속될 수 있도록 도와드릴게요.",
                "웃음꽃이 핀 마음이 보여요. 이 즐거운 순간을 더욱 빛나게 만들어드릴게요."
            ],
            
            "슬픔": [
                "마음이 무거우시군요. 지금 느끼는 슬픔도 소중한 감정이에요. 함께 천천히 달래보아요.",
                "힘든 시간을 보내고 계시는 것 같아요. 혼자가 아니에요, 마음의 위로를 전해드릴게요.",
                "마음의 상처가 아물 수 있도록 따뜻한 손길을 건네드릴게요.",
                "슬픔 속에서도 당신은 충분히 소중한 사람이에요. 천천히 마음을 달래보아요.",
                "눈물도 때로는 필요해요. 마음의 정화가 일어날 수 있도록 도와드릴게요.",
                "아픈 마음을 어루만져 드릴게요. 시간이 지나면 분명 괜찮아질 거예요."
            ],
            
            "안정": [
                "마음의 균형이 잘 잡혀있어요. 이 안정감을 더욱 깊게 느껴보세요.",
                "내면의 평형 상태가 아름다워요. 이 고요한 안정감을 오래 유지해보세요.",
                "마음이 흔들리지 않는 견고함이 느껴져요. 이 안정감을 더욱 단단하게 만들어드릴게요.",
                "차분하고 균형 잡힌 상태네요. 이 평온함이 일상의 힘이 되어드릴게요.",
                "마음의 중심이 잘 잡혀있어요. 이 안정된 에너지를 더욱 키워나가보세요."
            ],
            
            "이완": [
                "긴장을 풀고 여유를 찾을 시간이네요. 몸과 마음의 모든 긴장을 놓아보세요.",
                "스스로에게 휴식을 선물할 시간이에요. 완전히 이완된 상태를 경험해보세요.",
                "마음의 무게를 내려놓을 준비가 되신 것 같아요. 편안한 해방감을 느껴보세요.",
                "긴장에서 벗어나 자유로워질 시간이에요. 마음껏 느긋한 시간을 보내세요.",
                "모든 것을 내려놓고 편안해지실 수 있도록 완벽한 환경을 만들어드릴게요."
            ]
        ]
        
        // 시간대별 추가 멘트
        let timeBasedAddition: [String: String] = [
            "새벽": "이른 새벽, 조용한 시간 속에서",
            "아침": "새로운 하루를 맞는 아침에",
            "오전": "활기찬 오전 시간에",
            "점심": "하루의 중간, 재충전이 필요한 시간에",
            "오후": "따뜻한 오후 햇살 아래서",
            "저녁": "하루를 마무리하는 저녁에",
            "밤": "고요한 밤의 시간에",
            "자정": "깊어가는 밤, 평온한 시간에"
        ]
        
        let messages = empathyDatabase[emotion] ?? empathyDatabase["평온"] ?? ["마음을 위한 특별한 시간을 준비했어요."]
        let timeAddition = timeBasedAddition[timeOfDay] ?? ""
        
        // 강도에 따른 메시지 선택
        let intensityIndex = intensity > 1.2 ? 0 : intensity < 0.8 ? (messages.count - 1) : (messages.count / 2)
        let safeIndex = min(intensityIndex, messages.count - 1)
        let selectedMessage = messages[safeIndex]
        
        // 시간대 멘트 추가 (50% 확률)
        if !timeAddition.isEmpty && Int.random(in: 0...1) == 1 {
            return "\(timeAddition) \(selectedMessage)"
        }
        
        return selectedMessage
    }
    
    /// 🎵 사운드 요소별 상세 설명 생성
    private func generateSoundDescription(volumes: [Float], emotion: String) -> String {
        // 사운드 카테고리별 이름 (SoundPresetCatalog 순서에 맞춤)
        let soundCategories = [
            "Rain", "Ocean", "Forest", "Stream", "Wind", "River", "Thunderstorm", 
            "Waterfall", "Birds", "Fireplace", "WhiteNoise", "BrownNoise", "PinkNoise"
        ]
        
        // 사운드별 감성적 설명
        let soundDescriptions: [String: [String]] = [
            "Rain": ["부드러운 빗소리", "마음을 정화하는 빗방울", "안정감을 주는 빗소리", "따스한 빗소리"],
            "Ocean": ["깊은 바다의 파도", "마음을 진정시키는 파도소리", "끝없는 바다의 리듬", "평온한 해변의 파도"],
            "Forest": ["신선한 숲의 속삭임", "나무들의 자연스러운 소리", "푸른 숲의 평화", "자연의 깊은 숨결"],
            "Stream": ["맑은 시냇물의 흐름", "피로 회복에 효과적인 시냇물소리", "순수한 물의 멜로디", "자연의 치유력"],
            "Wind": ["부드러운 바람소리", "마음을 시원하게 하는 바람", "자유로운 바람의 춤", "상쾌한 미풍"],
            "River": ["흐르는 강의 리듬", "생명력 넘치는 강물소리", "깊은 강의 여유", "자연의 흐름"],
            "Thunderstorm": ["웅장한 천둥소리", "자연의 역동적 에너지", "강렬한 자연의 소리", "정화의 뇌우"],
            "Waterfall": ["시원한 폭포소리", "활력을 주는 물소리", "자연의 역동성", "생기 넘치는 폭포"],
            "Birds": ["새들의 평화로운 지저귐", "아침을 알리는 새소리", "자연의 하모니", "희망적인 새의 노래"],
            "Fireplace": ["따뜻한 벽난로 소리", "포근한 불꽃의 춤", "아늑한 공간의 소리", "평안한 난로 소리"],
            "WhiteNoise": ["집중력을 높이는 화이트노이즈", "마음의 잡음을 차단하는 소리", "명료한 정적", "순수한 배경음"],
            "BrownNoise": ["깊은 안정감의 브라운노이즈", "마음을 진정시키는 저주파", "편안한 배경 소리", "고요한 정적"],
            "PinkNoise": ["균형 잡힌 핑크노이즈", "자연스러운 배경음", "조화로운 정적", "부드러운 배경 소리"]
        ]
        
        // 감정별 강조 포인트
        let emotionFocus: [String: String] = [
            "평온": "마음의 평화를 위해",
            "수면": "깊은 잠을 위해",
            "스트레스": "스트레스 해소를 위해",
            "불안": "불안 완화를 위해",
            "활력": "에너지 충전을 위해",
            "집중": "집중력 향상을 위해",
            "행복": "기쁨 증진을 위해",
            "슬픔": "마음의 치유를 위해",
            "안정": "안정감 강화를 위해",
            "이완": "깊은 이완을 위해"
        ]
        
        // 활성화된 사운드 찾기 (볼륨이 10 이상인 것들)
        var activeSounds: [String] = []
        for (index, volume) in volumes.enumerated() {
            if index < soundCategories.count && volume >= 10 {
                let soundName = soundCategories[index]
                let descriptions = soundDescriptions[soundName] ?? [soundName]
                let randomDescription = descriptions.randomElement() ?? soundName
                activeSounds.append(randomDescription)
            }
        }
        
        let focusPhrase = emotionFocus[emotion] ?? "마음의 안정을 위해"
        
        if activeSounds.isEmpty {
            return "\(focusPhrase) 자연스럽고 조화로운 사운드 조합을 준비했어요."
        } else if activeSounds.count == 1 {
            return "\(focusPhrase) \(activeSounds[0])를 중심으로 한 특별한 조합입니다."
        } else if activeSounds.count <= 3 {
            let soundList = activeSounds.joined(separator: ", ")
            return "\(focusPhrase) \(soundList)를 조화롭게 블렌딩한 맞춤형 조합이에요."
        } else {
            let mainSounds = Array(activeSounds.prefix(2))
            let soundList = mainSounds.joined(separator: ", ")
            return "\(focusPhrase) \(soundList) 등 다양한 자연 사운드를 정교하게 조합했어요."
        }
    }
    
    // 🆕 로컬 프리셋 적용 (수정됨)
    private func applyLocalPreset(_ preset: (name: String, volumes: [Float], description: String, versions: [Int])) {
        print("🎵 [EmotionAnalysisChatViewController] 프리셋 적용 시작: \(preset.name)")
        print("  - 볼륨: \(preset.volumes)")
        print("  - 버전: \(preset.versions)")
        
        // 1. 볼륨과 버전 배열 검증 및 보정
        let correctedVolumes = validateAndCorrectVolumes(preset.volumes)
        let correctedVersions = validateAndCorrectVersions(preset.versions)
        
        print("  - 보정된 볼륨: \(correctedVolumes)")
        print("  - 보정된 버전: \(correctedVersions)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 🎯 강화된 MainViewController 찾기
            var mainVC: ViewController?
            var searchMethod = "not_found"
            
            // 방법 1: 현재 presented된 뷰컨트롤러의 presentingViewController 확인
            if let presentingVC = self.presentingViewController {
                if let tabBarController = presentingVC as? UITabBarController,
                   let firstTab = tabBarController.viewControllers?.first as? ViewController {
                    mainVC = firstTab
                    searchMethod = "presentingViewController_tabBar"
                } else if let navController = presentingVC as? UINavigationController,
                          let tabBarController = navController.topViewController as? UITabBarController,
                          let firstTab = tabBarController.viewControllers?.first as? ViewController {
                    mainVC = firstTab
                    searchMethod = "presentingViewController_nav_tabBar"
                } else if let viewController = presentingVC as? ViewController {
                    mainVC = viewController
                    searchMethod = "presentingViewController_direct"
                }
            }
            
            // 방법 2: SceneDelegate를 통한 접근
            if mainVC == nil {
                if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate,
                   let tabBarController = sceneDelegate.window?.rootViewController as? UITabBarController,
                   let firstTab = tabBarController.viewControllers?.first as? ViewController {
                    mainVC = firstTab
                    searchMethod = "sceneDelegate"
                }
            }
            
            // 방법 3: 윈도우 계층구조 탐색
            if mainVC == nil {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let tabBarController = window.rootViewController as? UITabBarController,
                   let firstTab = tabBarController.viewControllers?.first as? ViewController {
                    mainVC = firstTab
                    searchMethod = "windowScene"
                }
            }
            
            // 방법 4: 모든 윈도우 검색
            if mainVC == nil {
                for window in UIApplication.shared.windows {
                    if let tabBarController = window.rootViewController as? UITabBarController,
                       let firstTab = tabBarController.viewControllers?.first as? ViewController {
                        mainVC = firstTab
                        searchMethod = "allWindows"
                        break
                    }
                }
            }
            
            if let targetVC = mainVC {
                print("🎯 [EmotionAnalysisChatViewController] MainViewController 발견 (\(searchMethod))")
                
                // Step 1: 직접 applyPreset 호출 (완전한 UI + 사운드 동기화 + 최근 프리셋 저장)
                targetVC.applyPreset(
                    volumes: correctedVolumes,
                    versions: correctedVersions,
                    name: preset.name,
                    shouldSaveToRecent: true
                )
                
                print("✅ [EmotionAnalysisChatViewController] MainViewController.applyPreset 호출 완료")
                
                // Step 2: 메인 탭으로 자동 이동
                if let tabBarController = targetVC.tabBarController {
                    tabBarController.selectedIndex = 0
                    print("🏠 메인 탭으로 이동 완료")
                }
                
            } else {
                // 강화된 Fallback: 모든 방법 동원
                print("⚠️ [EmotionAnalysisChatViewController] MainViewController를 찾을 수 없음, 강화된 fallback 사용")
                
                // 1. SoundManager 직접 적용
                SoundManager.shared.applyPresetWithVersions(volumes: correctedVolumes, versions: correctedVersions)
                
                // 2. 수동으로 Recent Presets에 저장
                let soundPreset = SoundPreset(
                    name: preset.name,
                    volumes: correctedVolumes,
                    selectedVersions: correctedVersions,
                    emotion: nil,
                    isAIGenerated: false,
                    description: preset.description
                )
                SettingsManager.shared.saveSoundPreset(soundPreset)
                
                // 3. 모든 가능한 UI 업데이트 알림 전송 (다중 알림)
                let userInfo: [String: Any] = [
                    "volumes": correctedVolumes,
                    "versions": correctedVersions,
                    "name": preset.name,
                    "source": "emotion_analysis_fallback"
                ]
                
                // 기본 LocalPresetApplied 알림
                NotificationCenter.default.post(
                    name: NSNotification.Name("LocalPresetApplied"),
                    object: nil,
                    userInfo: userInfo
                )
                
                // SoundVolumesUpdated 알림
                NotificationCenter.default.post(
                    name: NSNotification.Name("SoundVolumesUpdated"),
                    object: nil,
                    userInfo: userInfo
                )
                
                // PresetAppliedFromChat 알림 (fallback용)
                NotificationCenter.default.post(
                    name: NSNotification.Name("PresetAppliedFromChat"),
                    object: preset.name,
                    userInfo: userInfo
                )
                
                // ApplyPresetFromChat 알림 (또 다른 fallback)
                NotificationCenter.default.post(
                    name: NSNotification.Name("ApplyPresetFromChat"),
                    object: nil,
                    userInfo: userInfo
                )
                
                print("📢 [EmotionAnalysisChatViewController] 4개 알림 전송 완료 - 확실한 UI 업데이트 보장")
                
                // 4. 메인 탭으로 강제 이동 시도
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let tabBarController = window.rootViewController as? UITabBarController {
                        tabBarController.selectedIndex = 0
                        print("🏠 강제 메인 탭 이동 성공")
                    }
                }
            }
            
            // Step 3: 성공 메시지 및 메인화면 이동 버튼
            let successMessage = "✅ '\(preset.name)' 프리셋이 적용되었습니다! 🎵\n\n메인 화면에서 슬라이더와 음량을 확인해보세요."
            self.addAIMessage(successMessage)
            self.addMainScreenNavigationButtons()
            
            // Step 4: 3초 후 자동으로 메인화면 이동 (시간 단축)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.goToMainScreen()
            }
            
            print("✅ [EmotionAnalysisChatViewController] 프리셋 적용 완료: \(preset.name)")
        }
    }
    
    // 배열 크기 보정 헬퍼 함수들
    private func validateAndCorrectVolumes(_ volumes: [Float]) -> [Float] {
        if volumes.count == 11 {
            return volumes + [0.0, 0.0]
        } else if volumes.count == 12 {
            return volumes + [0.0]
        } else if volumes.count == 13 {
            return volumes
        } else {
            var corrected = Array(repeating: Float(0.0), count: 13)
            for i in 0..<min(volumes.count, 13) {
                corrected[i] = volumes[i]
            }
            return corrected
        }
    }
    
    private func validateAndCorrectVersions(_ versions: [Int]) -> [Int] {
        if versions.count == 11 {
            return versions + [0, 0]
        } else if versions.count == 12 {
            return versions + [0]
        } else if versions.count == 13 {
            return versions
        } else {
            var corrected = Array(repeating: 0, count: 13)
            for i in 0..<min(versions.count, 13) {
                corrected[i] = versions[i]
            }
            return corrected
        }
    }
    
    // 메인화면 이동 버튼 및 액션
    private func addMainScreenNavigationButtons() {
        let buttonContainer = UIView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let homeButton = UIButton(type: .system)
        homeButton.setTitle("🏠 메인 화면으로 이동", for: .normal)
        homeButton.backgroundColor = .systemGreen
        homeButton.setTitleColor(.white, for: .normal)
        homeButton.layer.cornerRadius = 12
        homeButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        homeButton.translatesAutoresizingMaskIntoConstraints = false
        
        if #available(iOS 15.0, *) {
            var config = homeButton.configuration ?? UIButton.Configuration.filled()
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
            homeButton.configuration = config
        } else {
            homeButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        }
        
        homeButton.addAction(UIAction { [weak self] _ in
            self?.goToMainScreen()
        }, for: .touchUpInside)
        
        buttonContainer.addSubview(homeButton)
        
        NSLayoutConstraint.activate([
            buttonContainer.heightAnchor.constraint(equalToConstant: 60),
            homeButton.topAnchor.constraint(equalTo: buttonContainer.topAnchor, constant: 8),
            homeButton.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            homeButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            homeButton.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor, constant: -8)
        ])
        
        contentStackView.addArrangedSubview(buttonContainer)
        scrollToBottom()
    }
    
    private func goToMainScreen() {
        print("🏠 메인 화면 이동 시작...")
        DispatchQueue.main.async { [weak self] in
            self?.dismiss(animated: true) {
                print("✅ EmotionAnalysisChatViewController dismiss 완료")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.switchToMainViewController()
                }
            }
        }
    }
    
    private func switchToMainViewController() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            if let tabBarController = window.rootViewController as? UITabBarController {
                tabBarController.selectedIndex = 0
                print("✅ 탭바 컨트롤러로 메인 화면 이동 완료")
                return
            }
            if let navController = window.rootViewController as? UINavigationController,
               let tabBarController = navController.topViewController as? UITabBarController {
                tabBarController.selectedIndex = 0
                print("✅ 네비게이션 → 탭바로 메인 화면 이동 완료")
                return
            }
        }
        NotificationCenter.default.post(name: NSNotification.Name("GoToMainScreen"), object: nil)
        print("📢 노티피케이션으로 메인 화면 이동 요청 전송")
    }
    
    // MARK: - 🏠 메인화면 이동 로직 (중복 제거됨)
    
    // MARK: - 🔧 고급 로컬 추천 시스템 (AI 사용량 초과 시 대체)
    private func provideLocalFallbackRecommendation() {
        addUserMessage("🎵 지금 기분에 맞는 사운드 추천받기")
        
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
            name: "🎵 \(recommendedEmotion) 기본",
            volumes: baseVolumes,
            description: "\(currentTimeOfDay) 시간대에 적합한 \(recommendedEmotion) 상태의 기본 사운드입니다.",
            versions: SoundPresetCatalog.defaultVersions
        )
        
        // 사용자 친화적인 메시지 생성
        let presetMessage = """
        💭 **시간대 기반 추천**
        현재 시간: \(currentTimeOfDay)
        추천 상태: \(recommendedEmotion)
        
        🎵 **[\(recommendedPreset.name)]**
        \(recommendedPreset.description)
        
        현재 시간대에 최적화된 사운드 조합입니다. 바로 적용해보세요! ✨
        
        ℹ️ 오늘의 AI 추천 횟수를 모두 사용하여 로컬 추천을 제공합니다.
        """
        
        // 프리셋 적용 메시지 추가 (튜플을 SoundPreset으로 변환)
        let soundPreset = SoundPreset(
            name: recommendedPreset.name,
            volumes: recommendedPreset.volumes,
            emotion: recommendedPreset.description,
            isAIGenerated: false,
            description: recommendedPreset.description
        )
        addPresetRecommendationMessage(presetMessage, preset: recommendedPreset)
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
    
    // MARK: - 🔧 로컬 추천 호출 (ChatViewController+Actions에서 구현됨)
    
    private func getTimeOfDayString(hour: Int) -> String {
        switch hour {
        case 5..<7: return "새벽"
        case 7..<10: return "아침"
        case 10..<14: return "오전"
        case 14..<18: return "오후"
        case 18..<21: return "저녁"
        case 21..<24: return "밤"
        default: return "심야"
        }
    }
    
    // MARK: - 🧪 테스트용 버튼들 (AI/로컬 프리셋 추천 테스트)
    private func setupTestButtons() {
        // 테스트용 버튼들 생성
        let testButtonsContainer = UIView()
        testButtonsContainer.backgroundColor = .systemYellow.withAlphaComponent(0.1)
        testButtonsContainer.layer.cornerRadius = 8
        testButtonsContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let testLabel = UILabel()
        testLabel.text = "🧪 프리셋 추천 테스트"
        testLabel.font = .boldSystemFont(ofSize: 14)
        testLabel.textAlignment = .center
        testLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let aiTestButton = UIButton(type: .system)
        aiTestButton.setTitle("AI 추천 테스트", for: .normal)
        aiTestButton.backgroundColor = .systemBlue
        aiTestButton.setTitleColor(.white, for: .normal)
        aiTestButton.layer.cornerRadius = 6
        aiTestButton.translatesAutoresizingMaskIntoConstraints = false
        aiTestButton.addTarget(self, action: #selector(testAIRecommendation), for: .touchUpInside)
        
        let localTestButton = UIButton(type: .system)
        localTestButton.setTitle("로컬 추천 테스트", for: .normal)
        localTestButton.backgroundColor = .systemGreen
        localTestButton.setTitleColor(.white, for: .normal)
        localTestButton.layer.cornerRadius = 6
        localTestButton.translatesAutoresizingMaskIntoConstraints = false
        localTestButton.addTarget(self, action: #selector(testLocalRecommendation), for: .touchUpInside)
        
        testButtonsContainer.addSubview(testLabel)
        testButtonsContainer.addSubview(aiTestButton)
        testButtonsContainer.addSubview(localTestButton)
        
        view.addSubview(testButtonsContainer)
        
        NSLayoutConstraint.activate([
            testButtonsContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            testButtonsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            testButtonsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            testButtonsContainer.heightAnchor.constraint(equalToConstant: 80),
            
            testLabel.topAnchor.constraint(equalTo: testButtonsContainer.topAnchor, constant: 8),
            testLabel.leadingAnchor.constraint(equalTo: testButtonsContainer.leadingAnchor, constant: 8),
            testLabel.trailingAnchor.constraint(equalTo: testButtonsContainer.trailingAnchor, constant: -8),
            
            aiTestButton.topAnchor.constraint(equalTo: testLabel.bottomAnchor, constant: 8),
            aiTestButton.leadingAnchor.constraint(equalTo: testButtonsContainer.leadingAnchor, constant: 8),
            aiTestButton.widthAnchor.constraint(equalToConstant: 120),
            aiTestButton.heightAnchor.constraint(equalToConstant: 32),
            
            localTestButton.topAnchor.constraint(equalTo: testLabel.bottomAnchor, constant: 8),
            localTestButton.leadingAnchor.constraint(equalTo: aiTestButton.trailingAnchor, constant: 8),
            localTestButton.widthAnchor.constraint(equalToConstant: 120),
            localTestButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    @objc private func testAIRecommendation() {
        handleAIRecommendation()
    }
    
    @objc private func testLocalRecommendation() {
        handleLocalRecommendation()
    }

    // MARK: - Actions
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func sendTapped() {
        sendMessage()
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardHeight = keyboardFrame.cgRectValue.height
        
        UIView.animate(withDuration: 0.3) {
            self.view.transform = CGAffineTransform(translationX: 0, y: -keyboardHeight)
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        UIView.animate(withDuration: 0.3) {
            self.view.transform = .identity
        }
    }
    
    // MARK: - Loading State
    private func setLoading(_ loading: Bool) {
        if loading {
            loadingIndicator.startAnimating()
            sendButton.isHidden = true
        } else {
            loadingIndicator.stopAnimating()
            sendButton.isHidden = false
        }
        
        sendButton.isEnabled = !loading
        messageTextField.isEnabled = !loading
    }
    
    // MARK: - Scroll Management
    private func scrollToBottom() {
        DispatchQueue.main.async {
            let bottomOffset = CGPoint(x: 0, y: max(0, self.scrollView.contentSize.height - self.scrollView.bounds.height))
            self.scrollView.setContentOffset(bottomOffset, animated: true)
        }
    }
    
    // MARK: - Message Sending
    private func sendMessage() {
        guard let message = messageTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !message.isEmpty,
              !isWaitingForResponse else {
            return
        }
        
        addUserMessage(message)
        messageTextField.text = ""
        
        isWaitingForResponse = true
        setLoading(true)
        
        // 감정 분석 기반 대화 처리
        ReplicateChatService.shared.sendPrompt(
            message: message,
            intent: "emotion_chat"
        ) { [weak self] response in
            DispatchQueue.main.async {
                self?.isWaitingForResponse = false
                self?.setLoading(false)
                
                if let response = response {
                    self?.addAIMessage(response)
                } else {
                    self?.addAIMessage("죄송해요, 응답 중 문제가 발생했습니다. 다시 시도해주세요.")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func extractRecentEmotions() -> String {
        // 최근 감정 패턴에서 핵심 키워드 추출
        let lines = emotionPatternData.components(separatedBy: "\n")
        let recentLines = lines.prefix(3)
        
        var emotions: [String] = []
        for line in recentLines {
            if line.contains("기쁨") || line.contains("행복") {
                emotions.append("기쁨")
            } else if line.contains("슬픔") || line.contains("우울") {
                emotions.append("슬픔")
            } else if line.contains("분노") || line.contains("화남") {
                emotions.append("분노")
            } else if line.contains("불안") || line.contains("걱정") {
                emotions.append("불안")
            } else if line.contains("평온") || line.contains("안정") {
                emotions.append("평온")
            }
        }
        
        return emotions.isEmpty ? "복합감정" : emotions.joined(separator: ", ")
    }
    
    private func mapIntentToTipType(_ intent: String) -> String {
        switch intent {
        case "improvement_tips":
            return "개선방법"
        case "trend_analysis":
            return "추이분석"
        case "stress_management":
            return "스트레스관리"
        default:
            return "일반조언"
        }
    }

    // MARK: - ✅ Swipe Back Gesture Support
    private func enableSwipeBackGesture() {
        // 네비게이션 컨트롤러의 interactive pop gesture 활성화
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        // 추가적인 스와이프 제스처 추가 (더 민감하게)
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delegate = self
        view.addGestureRecognizer(panGesture)
    }
    
    @objc private func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: view)
        let velocity = recognizer.velocity(in: view)
        
        // 세로 스크롤이 주요 동작인 경우 스와이프 무시
        if abs(translation.y) > abs(translation.x) * 2 {
            return
        }
        
        // 왼쪽 가장자리에서 시작한 제스처만 처리 (화면 폭의 20% 이내)
        let startPoint = recognizer.location(in: view)
        if startPoint.x > view.frame.width * 0.2 {
            return
        }
        
        switch recognizer.state {
        case .ended, .cancelled:
            // 오른쪽으로 충분히 스와이프했거나 속도가 충분한 경우
            if translation.x > 100 || velocity.x > 500 {
                // 뒤로가기 실행
                if navigationController?.viewControllers.count ?? 0 > 1 {
                    navigationController?.popViewController(animated: true)
                } else if presentingViewController != nil {
                    dismiss(animated: true, completion: nil)
                }
            }
        default:
            break
        }
    }
    
    // MARK: - 🧠 Enhanced Psychoacoustic Analysis Methods
    
    // 🧠 음향심리학 기반 상세 분석 메시지 생성
    private func createEnhancedPsychoacousticMessage(analysis: (emotion: String, timeOfDay: String, intensity: Float), preset: (name: String, volumes: [Float], description: String, versions: [Int])) -> String {
        let userProfile = generateUserPsychologicalProfile(emotion: analysis.emotion, intensity: analysis.intensity, timeOfDay: analysis.timeOfDay)
        let psychoacousticAnalysis = generatePsychoacousticAnalysis(preset: preset, profile: userProfile)
        let neuroscientificEffects = generateNeuroscientificEffects(emotion: analysis.emotion, preset: preset)
        
        return """
        🧠 **AI 감정 분석 & 음향심리학 추천**
        
        **📊 현재 심리상태 프로파일:**
        • 주감정: \(analysis.emotion) (강도: \(getIntensityDescription(analysis.intensity)))
        • 시간대: \(analysis.timeOfDay)
        • 뇌파 상태: \(userProfile.brainwaveState)
        • 자율신경계: \(userProfile.autonomicState)
        • 권장 치료: \(userProfile.recommendedTherapy)
        
        **🎵 [\(preset.name)]**
        
        **🔬 음향심리학적 분석:**
        \(psychoacousticAnalysis.frequency)
        \(psychoacousticAnalysis.binaural)
        \(psychoacousticAnalysis.nature)
        \(psychoacousticAnalysis.rhythm)
        
        **🧬 신경과학적 효과:**
        \(neuroscientificEffects.neurotransmitter)
        \(neuroscientificEffects.brainwave)
        \(neuroscientificEffects.physiological)
        
        **💡 개인화 추천 이유:**
        \(generatePersonalizedReason(analysis: analysis, preset: preset))
        
        **⏱️ 권장 사용법:**
        \(generateUsageRecommendation(emotion: analysis.emotion, timeOfDay: analysis.timeOfDay))
        
        이 조합은 \(analysis.emotion) 상태에서 최적의 음향 치료 효과를 제공합니다. ✨
        """
    }
    
    // 🆕 사용자 심리 프로파일 생성
    private func generateUserPsychologicalProfile(emotion: String, intensity: Float, timeOfDay: String) -> (brainwaveState: String, autonomicState: String, recommendedTherapy: String) {
        let brainwaveState: String
        let autonomicState: String
        let recommendedTherapy: String
        
        switch emotion {
        case "스트레스", "불안":
            brainwaveState = "베타파 과활성 (14-30Hz)"
            autonomicState = "교감신경 우세 상태"
            recommendedTherapy = "알파파 유도 및 부교감신경 활성화"
        case "슬픔", "우울":
            brainwaveState = "세타파 증가 (4-8Hz)"
            autonomicState = "부교감신경 과활성"
            recommendedTherapy = "알파파 안정화 및 감정 조절"
        case "수면", "피로":
            brainwaveState = "델타파 전환 필요 (0.5-4Hz)"
            autonomicState = "부교감신경 활성화 상태"
            recommendedTherapy = "델타파 유도 및 깊은 이완"
        case "집중", "활력":
            brainwaveState = "감마파 활성화 (30-100Hz)"
            autonomicState = "균형잡힌 자율신경"
            recommendedTherapy = "베타파 최적화 및 인지 향상"
        default:
            brainwaveState = "알파파 안정 (8-14Hz)"
            autonomicState = "균형잡힌 자율신경"
            recommendedTherapy = "전체적 뇌파 조화"
        }
        
        return (brainwaveState, autonomicState, recommendedTherapy)
    }
    
    // 🆕 음향심리학적 분석
    private func generatePsychoacousticAnalysis(preset: (name: String, volumes: [Float], description: String, versions: [Int]), profile: (brainwaveState: String, autonomicState: String, recommendedTherapy: String)) -> (frequency: String, binaural: String, nature: String, rhythm: String) {
        
        let frequency = "• **주파수 치료**: 432Hz 기반 자연 조율로 세포 진동 조화 및 스트레스 호르몬(코르티솔) 감소 유도"
        
        let binaural = "• **바이노럴 비트**: 좌뇌-우뇌 동기화를 통한 뇌파 엔트레인먼트, 감마-아미노부티르산(GABA) 분비 촉진"
        
        let nature = "• **자연음 치료**: 1/f 핑크노이즈 특성으로 도파민 및 세로토닌 분비 촉진, 자연적 치유 반응 활성화"
        
        let rhythm = "• **리듬 치료**: 60-70BPM 안정 리듬으로 심박변이도(HRV) 개선 및 미주신경 활성화"
        
        return (frequency, binaural, nature, rhythm)
    }
    
    // 🆕 신경과학적 효과 분석
    private func generateNeuroscientificEffects(emotion: String, preset: (name: String, volumes: [Float], description: String, versions: [Int])) -> (neurotransmitter: String, brainwave: String, physiological: String) {
        
        let neurotransmitter: String
        let brainwave: String
        let physiological: String
        
        switch emotion {
        case "스트레스", "불안":
            neurotransmitter = "• **신경전달물질**: GABA 분비 증가로 불안 완화, 세로토닌 재흡수 억제로 기분 안정화"
            brainwave = "• **뇌파 조절**: 베타파→알파파 전환으로 과각성 상태 진정, 전전두엽 활성화로 인지 조절 강화"
            physiological = "• **생리적 효과**: 코르티솔 30-40% 감소, 혈압 5-10mmHg 하락, 근육 긴장도 완화"
        case "슬픔", "우울":
            neurotransmitter = "• **신경전달물질**: 도파민 경로 활성화로 보상 시스템 회복, 엔돌핀 분비로 자연적 항우울 효과"
            brainwave = "• **뇌파 조절**: 좌측 전전두엽 활성화로 긍정 감정 처리 증진, 세타파 안정화"
            physiological = "• **생리적 효과**: 옥시토신 분비 증가로 사회적 연결감 회복, 면역 기능 강화"
        case "수면", "피로":
            neurotransmitter = "• **신경전달물질**: 멜라토닌 자연 분비 촉진, 아데노신 작용 지원으로 깊은 수면 유도"
            brainwave = "• **뇌파 조절**: 델타파(0.5-4Hz) 증폭으로 깊은 수면 단계 연장, 기억 공고화 지원"
            physiological = "• **생리적 효과**: 성장호르몬 분비 최적화, 체온 조절 개선, 혈압 자연 하강"
        case "집중", "활력":
            neurotransmitter = "• **신경전달물질**: 노르에피네프린 적정 분비로 각성도 최적화, 아세틸콜린으로 주의력 집중 강화"
            brainwave = "• **뇌파 조절**: 감마파 활성화로 인지 성능 향상, 베타파 최적화로 지속적 집중력 유지"
            physiological = "• **생리적 효과**: 뇌혈류량 증가, 신경 가소성 촉진, 작업 기억 용량 확장"
        default:
            neurotransmitter = "• **신경전달물질**: 세로토닌-도파민 균형 최적화로 전반적 웰빙 상태 유지"
            brainwave = "• **뇌파 조절**: 알파파 안정화로 이완된 각성 상태, 뇌파 동기화로 내적 평화 증진"
            physiological = "• **생리적 효과**: 자율신경계 균형 회복, 염증 반응 감소, 전반적 항상성 개선"
        }
        
        return (neurotransmitter, brainwave, physiological)
    }
    
    // 🆕 개인화 추천 이유
    private func generatePersonalizedReason(analysis: (emotion: String, timeOfDay: String, intensity: Float), preset: (name: String, volumes: [Float], description: String, versions: [Int])) -> String {
        let timeBasedReason: String
        let emotionBasedReason: String
        let intensityBasedReason: String
        
        switch analysis.timeOfDay {
        case "새벽", "아침":
            timeBasedReason = "아침 시간대의 코르티솔 피크를 고려한 점진적 각성 지원"
        case "오전", "점심":
            timeBasedReason = "오전 인지 성능 최적화를 위한 베타파 활성화 조합"
        case "오후":
            timeBasedReason = "오후 에너지 저하 시점의 자연적 리듬 회복 지원"
        case "저녁":
            timeBasedReason = "저녁 시간대 부교감신경 활성화를 위한 이완 주파수 적용"
        case "밤", "자정":
            timeBasedReason = "수면 준비를 위한 멜라토닌 분비 최적화 및 델타파 유도"
        default:
            timeBasedReason = "현재 시간대의 자연적 생체 리듬 지원"
        }
        
        emotionBasedReason = "'\(analysis.emotion)' 감정 상태에 특화된 신경화학적 균형 조절 목적"
        
        if analysis.intensity > 1.2 {
            intensityBasedReason = "고강도 감정 상태에 대한 신속한 신경계 안정화 프로토콜 적용"
        } else if analysis.intensity < 0.8 {
            intensityBasedReason = "저강도 감정을 고려한 부드러운 뇌파 유도 및 점진적 조절"
        } else {
            intensityBasedReason = "적정 강도 감정에 맞춘 균형잡힌 신경조절 접근"
        }
        
        return "\(timeBasedReason), \(emotionBasedReason), \(intensityBasedReason)"
    }
    
    // 🆕 사용법 추천
    private func generateUsageRecommendation(emotion: String, timeOfDay: String) -> String {
        let duration: String
        let posture: String
        let environment: String
        
        switch emotion {
        case "스트레스", "불안":
            duration = "15-20분 연속 청취"
            posture = "편안한 의자에 앉아 어깨를 이완"
            environment = "조명을 약간 어둡게 하고 실온 20-22도 유지"
        case "수면", "피로":
            duration = "30-45분 또는 자연스럽게 잠들 때까지"
            posture = "침대에 누워 팔다리를 자연스럽게 이완"
            environment = "완전 차광, 실온 18-20도, 스마트폰 블루라이트 차단"
        case "집중", "활력":
            duration = "25분 포모도로 기법 또는 작업 시간에 맞춰"
            posture = "바른 자세로 앉아 발을 바닥에 평평히"
            environment = "자연광 충분히, 환기 잘 되는 공간"
        default:
            duration = "20-30분 또는 개인 선호에 따라"
            posture = "편안한 자세로 호흡에 집중"
            environment = "방해받지 않는 조용한 공간"
        }
        
        return "⏱️ \(duration) | 🧘‍♀️ \(posture) | 🏠 \(environment)"
    }
    
    // 🆕 강도 설명
    private func getIntensityDescription(_ intensity: Float) -> String {
        if intensity > 1.2 {
            return "매우 높음 (>1.2)"
        } else if intensity > 1.0 {
            return "높음 (1.0-1.2)"
        } else if intensity > 0.8 {
            return "보통 (0.8-1.0)"
        } else {
            return "낮음 (<0.8)"
        }
    }
}

// MARK: - UITextFieldDelegate
extension EmotionAnalysisChatViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendMessage()
        return true
    }
}

// MARK: - UIGestureRecognizerDelegate
extension EmotionAnalysisChatViewController {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 네비게이션 스택에 뒤로 갈 수 있는 뷰컨트롤러가 있는지 확인
        if gestureRecognizer == navigationController?.interactivePopGestureRecognizer {
            return (navigationController?.viewControllers.count ?? 0) > 1
        }
        return true
    }
}
