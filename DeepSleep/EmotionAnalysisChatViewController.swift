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
        title = "감정 분석 대화"
        view.backgroundColor = UIDesignSystem.Colors.background
        
        // 🧪 테스트용 버튼들 추가
        setupTestButtons()
        
        setupUI()
        setupKeyboardNotifications()
        
        // 초기 분석 시작
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
                    
                    // 사용자 친화적인 메시지 생성
                    let presetMessage = self.createUserFriendlyPresetMessage(
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
    
    // 🆕 로컬 프리셋 적용 (강화된 로직)
    private func applyLocalPreset(_ preset: (name: String, volumes: [Float], description: String, versions: [Int])) {
        print("🔧 프리셋 적용 시작: \(preset.name)")
        print("📊 볼륨 데이터: \(preset.volumes)")
        print("🔄 버전 데이터: \(preset.versions)")
        print("🏭 SoundPresetCatalog.categoryCount: \(SoundPresetCatalog.categoryCount)")
        
        // 0. 먼저 기존 사운드를 모두 정지
        SoundManager.shared.stopAllPlayers()
        print("⏹️ 기존 사운드 정지 완료")
        
        // 1. 버전 정보 적용 (안전한 범위 체크 및 강화된 로깅)
        for (categoryIndex, versionIndex) in preset.versions.enumerated() {
            if categoryIndex < SoundPresetCatalog.categoryCount && versionIndex >= 0 && versionIndex < 3 {
                let previousVersion = SettingsManager.shared.getSelectedVersion(for: categoryIndex)
                SettingsManager.shared.updateSelectedVersion(for: categoryIndex, to: versionIndex)
                let updatedVersion = SettingsManager.shared.getSelectedVersion(for: categoryIndex)
                print("✅ 버전 업데이트: 카테고리 \(categoryIndex) → 이전: \(previousVersion), 설정: \(versionIndex), 현재: \(updatedVersion)")
            } else {
                print("⚠️ 버전 설정 건너뜀: 카테고리 \(categoryIndex), 버전 \(versionIndex) (범위 초과)")
            }
        }
        
        // 2. 볼륨 설정 적용 (정규화된 값 사용 및 재생 트리거)
        for (index, volume) in preset.volumes.enumerated() {
            if index < SoundPresetCatalog.categoryCount {
                let normalizedVolume = max(0.0, min(1.0, volume / 100.0))  // 0.0~1.0 범위로 정규화
                
                // 이전 볼륨 확인
                let previousVolume = SoundManager.shared.getVolume(for: index)
                
                // 볼륨 설정
                SoundManager.shared.setVolume(for: index, volume: normalizedVolume)
                
                // 설정 후 볼륨 확인
                let currentVolume = SoundManager.shared.getVolume(for: index)
                
                print("🔊 볼륨 설정: 카테고리 \(index) → 이전: \(previousVolume), 설정: \(normalizedVolume), 현재: \(currentVolume)")
                
                // 볼륨이 0보다 크면 재생 상태 확인
                if normalizedVolume > 0 {
                    let isPlaying = SoundManager.shared.isPlaying(for: index)
                    print("▶️ 카테고리 \(index) 재생 상태: \(isPlaying)")
                }
            }
        }
        
        // 3. SoundManager에 프리셋 이름 전달 (NowPlaying 업데이트)
        SoundManager.shared.updateNowPlayingInfo(presetName: preset.name, isPlayingOverride: true)
        print("🎵 NowPlaying 정보 업데이트: \(preset.name)")
        
        // 4. 메인 화면 UI 업데이트 알림 (복수 알림 및 지연 처리)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("SoundVolumesUpdated"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("PresetApplied"), object: preset.name)
            print("📢 UI 업데이트 알림 전송 완료")
        }
        
        // 5. 강화된 재생 상태 업데이트 (여러 단계로 확실하게)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            print("🔍 1차 재생 트리거 시작")
            SoundManager.shared.playActiveSounds()
            
            // 추가 UI 업데이트 알림
            NotificationCenter.default.post(name: NSNotification.Name("SoundVolumesUpdated"), object: nil)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🔍 2차 상태 확인 및 재생 트리거")
            
            var hasActiveSound = false
            var detailedLog = "📊 최종 상태 확인:\n"
            
            for i in 0..<min(preset.volumes.count, SoundPresetCatalog.categoryCount) {
                let currentVolume = SoundManager.shared.getVolume(for: i)
                let isPlaying = SoundManager.shared.isPlaying(for: i)
                detailedLog += "  카테고리 \(i): 설정값 \(preset.volumes[i]/100.0) → 현재값 \(currentVolume), 재생중: \(isPlaying)\n"
                
                if currentVolume > 0 {
                    hasActiveSound = true
                }
            }
            
            print(detailedLog)
            
            // 활성 사운드가 있으면 강제 재생
            if hasActiveSound {
                SoundManager.shared.playActiveSounds()
                print("▶️ 2차 활성 사운드 재생 트리거 완료")
                
                // 메인 화면 사운드 컨트롤 업데이트
                NotificationCenter.default.post(name: NSNotification.Name("ForceUpdateSoundControls"), object: nil)
            } else {
                print("⚠️ 활성 사운드가 없어서 재생하지 않음")
            }
        }
        
        // 6. 성공 메시지
        let successMessage = "✅ '\(preset.name)' 프리셋이 적용되었습니다! 지금 바로 편안한 사운드를 즐겨보세요. 🎵"
        addAIMessage(successMessage)
        
        // 7. 🎯 메인화면으로 이동 (사운드 재생 확인 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            // 성공 메시지 추가 및 메인화면 이동 버튼 표시
            self?.addMainScreenNavigationButtons()
        }
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
    

    
    private func addPresetApplicationButton(preset: SoundPreset) {
        let buttonContainer = UIView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let applyButton = UIButton(type: .system)
        applyButton.setTitle("🎵 바로 적용하기", for: .normal)
        applyButton.backgroundColor = .systemBlue
        applyButton.setTitleColor(.white, for: .normal)
        applyButton.layer.cornerRadius = 12
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        
        let homeButton = UIButton(type: .system)
        homeButton.setTitle("🏠 메인 화면으로 이동", for: .normal)
        homeButton.backgroundColor = .systemGreen
        homeButton.setTitleColor(.white, for: .normal)
        homeButton.layer.cornerRadius = 12
        homeButton.translatesAutoresizingMaskIntoConstraints = false
        
        applyButton.addAction(UIAction { [weak self] _ in
            self?.applyPreset(preset)
            self?.addAIMessage("✅ 프리셋이 적용되었습니다! 사운드가 재생됩니다.")
        }, for: .touchUpInside)
        
        homeButton.addAction(UIAction { [weak self] _ in
            self?.goToMainScreen()
        }, for: .touchUpInside)
        
        buttonContainer.addSubview(applyButton)
        buttonContainer.addSubview(homeButton)
        
        NSLayoutConstraint.activate([
            buttonContainer.heightAnchor.constraint(equalToConstant: 100),
            
            applyButton.topAnchor.constraint(equalTo: buttonContainer.topAnchor, constant: 8),
            applyButton.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            applyButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            applyButton.heightAnchor.constraint(equalToConstant: 40),
            
            homeButton.topAnchor.constraint(equalTo: applyButton.bottomAnchor, constant: 8),
            homeButton.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            homeButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            homeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        contentStackView.addArrangedSubview(buttonContainer)
        scrollToBottom()
    }
    
    private func applyPreset(_ preset: SoundPreset) {
        // 사운드 매니저를 통해 프리셋 적용 (싱글톤 사용)
        SoundManager.shared.applyPreset(volumes: preset.volumes)
        SoundManager.shared.playAll()
        print("🎵 프리셋 적용 완료: \(preset.name)")
    }
    
    // MARK: - 🏠 메인 화면 이동
    private func goToMainScreen() {
        print("🏠 메인 화면 이동 시작...")
        
        // 즉시 dismiss 실행
        DispatchQueue.main.async { [weak self] in
            self?.dismiss(animated: true) {
                print("✅ EmotionAnalysisChatViewController dismiss 완료")
                
                // 메인 뷰 컨트롤러로 전환 (다양한 방법 시도)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.switchToMainViewController()
                }
            }
        }
    }
    
    private func switchToMainViewController() {
        // 방법 1: 앱의 윈도우 씬에서 탭바 컨트롤러 찾기
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            
            if let tabBarController = window.rootViewController as? UITabBarController {
                tabBarController.selectedIndex = 0
                print("✅ 방법1: 탭바 컨트롤러로 메인 화면 이동 완료")
                return
            }
            
            if let navController = window.rootViewController as? UINavigationController,
               let tabBarController = navController.topViewController as? UITabBarController {
                tabBarController.selectedIndex = 0
                print("✅ 방법2: 네비게이션 → 탭바로 메인 화면 이동 완료")
                return
            }
        }
        
        // 방법 2: 노티피케이션을 통한 메인 화면 전환 요청
        NotificationCenter.default.post(name: NSNotification.Name("GoToMainScreen"), object: nil)
        print("📢 방법3: 노티피케이션으로 메인 화면 이동 요청 전송")
    }
    
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
        
        // 5초 후 자동으로 메인화면으로 이동
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.addAIMessage("⏰ 잠시 후 자동으로 메인 화면으로 이동합니다...")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.goToMainScreen()
            }
        }
    }
    
    // MARK: - 🎲 랜덤화 헬퍼 메서드들은 ChatViewController+Actions에서 구현됨
    
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
    
    // 🧪 테스트용 버튼 설정
    private func setupTestButtons() {
        let localTestButton = UIBarButtonItem(
            title: "🎲 로컬",
            style: .plain,
            target: self,
            action: #selector(testLocalRecommendation)
        )
        
        let aiTestButton = UIBarButtonItem(
            title: "🤖 AI",
            style: .plain,
            target: self,
            action: #selector(testAIRecommendation)
        )
        
        navigationItem.rightBarButtonItems = [localTestButton, aiTestButton]
    }
    
    @objc private func testLocalRecommendation() {
        addUserMessage("🎲 로컬 추천 테스트")
        addAIMessage("🔧 로컬 기반 추천 시스템을 테스트합니다. 실제 로컬 추천은 메인 채팅에서 사용할 수 있습니다.")
    }
    
    @objc private func testAIRecommendation() {
        addUserMessage("🎵 지금 기분에 맞는 사운드 추천받기")
        sendAIRequest(prompt: "현재 시간과 상황에 맞는 최적의 사운드 조합을 추천해주세요.", intent: "preset")
    }
    

    

}

// MARK: - UITextFieldDelegate
extension EmotionAnalysisChatViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendMessage()
        return true
    }
}
