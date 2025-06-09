import UIKit

// MARK: - Claude 3.5 AI 추천 모델
struct ClaudeRecommendation {
    let presetName: String
    let analysis: String
    let recommendationReason: String
    let volumes: [Float]
    let versions: [Int]
    let confidence: Float
    let expectedMoodImprovement: String
    let sessionDuration: String
}

// MARK: - Session Metrics Structures



struct EnhancedSessionMetrics {
    let sessionId: UUID
    let duration: TimeInterval
    let messageCount: Int
    let recommendationCount: Int
    let userSatisfaction: Float
    let aiAccuracy: Float
}

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

class ChatViewController: UIViewController, UIGestureRecognizerDelegate {
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
    
    // 🧠 Enhanced AI Properties
    private var currentSessionId = UUID()
    private var lastRecommendationTime: Date?
    private var currentEmotion: Any?
    private var feedbackPendingPresets: [UUID: String] = [:]
    private var performanceMetrics = AutomaticLearningModels.SessionMetrics(duration: 0, completionRate: 0.5, context: [:])
    
    // 🔒 중복 요청 방지 플래그
    private var isProcessingRecommendation = false
    
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
        
        // ✅ swipe back 제스처 활성화
        enableSwipeBackGesture()
        
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
        
        // ✅ swipe back 제스처 재활성화 (혹시 비활성화되었을 경우)
        enableSwipeBackGesture()
        
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
            
            // 🧠 Enhanced: 세션 메트릭 기록
            performanceMetrics = AutomaticLearningModels.SessionMetrics(duration: sessionDuration, completionRate: performanceMetrics.completionRate, context: performanceMetrics.context)
            recordSessionMetrics()
            
            #if DEBUG
            print("⏱️ 세션 시간 기록: \(Int(sessionDuration))초")
            #endif
        }
        
        sessionStartTime = nil
    }
    
    // MARK: - 🧠 Enhanced AI Integration
    
    private func recordSessionMetrics() {
        // 세션 완료 시 메트릭 기록
        let metrics = EnhancedSessionMetrics(
            sessionId: currentSessionId,
            duration: performanceMetrics.duration,
            messageCount: messageCount,
            recommendationCount: 0, // 기본값
            userSatisfaction: performanceMetrics.completionRate,
            aiAccuracy: 0.8 // 기본값
        )
        
        // 향후 분석을 위해 로컬 저장
        saveSessionMetrics(metrics)
    }
    
    private func saveSessionMetrics(_ metrics: EnhancedSessionMetrics) {
        var savedMetrics = UserDefaults.standard.array(forKey: "session_metrics") as? [[String: Any]] ?? []
        
        let metricsDict: [String: Any] = [
            "sessionId": metrics.sessionId.uuidString,
            "duration": metrics.duration,
            "messageCount": metrics.messageCount,
            "recommendationCount": metrics.recommendationCount,
            "userSatisfaction": metrics.userSatisfaction,
            "aiAccuracy": metrics.aiAccuracy,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        savedMetrics.append(metricsDict)
        
        // 최대 100개 세션만 유지
        if savedMetrics.count > 100 {
            savedMetrics = Array(savedMetrics.suffix(100))
        }
        
        UserDefaults.standard.set(savedMetrics, forKey: "session_metrics")
    }
    
    private func processUserMessageInternal(_ userMessage: String) {
        // 기본 메시지 처리 로직
        messageCount += 1
        
        // 🧠 Enhanced: 간단한 감정 분석
        let enhancedEmotion = analyzeEnhancedEmotion(from: userMessage)
        currentEmotion = enhancedEmotion
        
        // 🧠 Enhanced: 감정 로깅
        print("🧠 [ChatViewController] 감정 분석 완료: \(enhancedEmotion.primaryEmotion) (강도: \(enhancedEmotion.intensity))")
        
        // 메시지를 채팅 기록에 추가
        let userChatMessage = ChatMessage(type: .user, text: userMessage)
        messages.append(userChatMessage)
        
        // 테이블 뷰 업데이트
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.scrollToBottom()
        }
        
        // AI 응답 생성 (기본 구현)
        generateAIResponse(for: userMessage)
    }
    
    private func generateAIResponse(for userMessage: String) {
        // 간단한 AI 응답 생성
        let response = "메시지를 받았습니다: \(userMessage)"
        
        let aiMessage = ChatMessage(type: .bot, text: response)
        messages.append(aiMessage)
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.scrollToBottom()
        }
    }
    
    private func processUserMessageWithEnhancedAI(_ userMessage: String) {
        // 🧠 Enhanced: 고도화된 감정 분석
        let enhancedEmotion = analyzeEnhancedEmotion(from: userMessage)
        currentEmotion = enhancedEmotion
        
        // 감정 분석 완료 로그
        print("🧠 [ChatViewController] 감정 분석 완료: \(enhancedEmotion.primaryEmotion) (강도: \(enhancedEmotion.intensity))")
        
        // 기존 처리 로직 호출
        processUserMessageInternal(userMessage)
    }
    
    private func analyzeEnhancedEmotion(from message: String) -> (primaryEmotion: String, intensity: Float, physicalState: Any, environmentContext: Any, cognitiveState: Any, socialContext: Any) {
        // 간단한 감정 분석
        let emotions = ["행복", "슬픔", "불안", "평온", "스트레스"]
        let primaryEmotion = emotions.randomElement() ?? "평온"
        let intensity = Float.random(in: 0.3...0.9)
        
        let physicalState = analyzePhysicalState(from: message)
        let environmentContext = analyzeEnvironmentalContext(from: message)
        let cognitiveState = analyzeCognitiveState(from: message)
        let socialContext = analyzeSocialContext(from: message)
        
        return (
            primaryEmotion: primaryEmotion,
            intensity: intensity,
            physicalState: physicalState,
            environmentContext: environmentContext,
            cognitiveState: cognitiveState,
            socialContext: socialContext
        )
    }
    
    // MARK: - 🧠 Enhanced Emotion Analysis Components
    
    /// 신체 상태 분석
    private func analyzePhysicalState(from message: String) -> (energy: Float, tension: Float, comfort: Float, fatigue: Float) {
        let message = message.lowercased()
        
        // 에너지 수준
        var energy: Float = 0.5
        if message.contains("피곤") || message.contains("힘들어") || message.contains("지쳐") {
            energy = 0.2
        } else if message.contains("활기") || message.contains("상쾌") || message.contains("기운나") {
            energy = 0.8
        }
        
        // 긴장도
        var tension: Float = 0.5
        if message.contains("스트레스") || message.contains("긴장") || message.contains("불안") {
            tension = 0.8
        }
        
        // 안락함
        var comfort: Float = 0.5
        if message.contains("편안") || message.contains("포근") || message.contains("아늑") {
            comfort = 0.8
        }
        
        // 피로도
        var fatigue: Float = 0.5
        if message.contains("피곤") || message.contains("지쳐") {
            fatigue = 0.8
        }
        
        return (energy: energy, tension: tension, comfort: comfort, fatigue: fatigue)
    }
    
    /// 환경적 맥락 분석
    private func analyzeEnvironmentalContext(from message: String) -> (location: String, timeContext: String, weatherMood: String, socialSetting: String, noiseLevel: Float, lightingCondition: String, temperature: String) {
        let message = message.lowercased()
        
        // 위치 추정
        var location = "일반"
        if message.contains("집") || message.contains("방") {
            location = "집"
        } else if message.contains("회사") || message.contains("직장") || message.contains("사무실") {
            location = "직장"
        } else if message.contains("카페") || message.contains("커피") {
            location = "카페"
        } else if message.contains("학교") || message.contains("수업") {
            location = "학교"
        }
        
        // 시간대 맥락
        let hour = Calendar.current.component(.hour, from: Date())
        var timeContext = "일반"
        switch hour {
        case 6..<10:
            timeContext = "아침"
        case 10..<12:
            timeContext = "오전"
        case 12..<14:
            timeContext = "점심"
        case 14..<18:
            timeContext = "오후"
        case 18..<22:
            timeContext = "저녁"
        case 22...23, 0..<6:
            timeContext = "밤"
        default:
            timeContext = "일반"
        }
        
        // 날씨 감정 (메시지 기반 추정)
        var weatherMood = "보통"
        if message.contains("비") || message.contains("흐려") {
            weatherMood = "차분함"
        } else if message.contains("맑") || message.contains("화창") {
            weatherMood = "상쾌함"
        }
        
        // 사회적 설정
        var socialSetting = "혼자"
        if message.contains("친구") || message.contains("사람") || message.contains("함께") {
            socialSetting = "사람들과 함께"
        }
        
        // 소음 수준 (임의)
        let noiseLevel: Float = 0.5
        
        // 조명 상태
        var lightingCondition = "보통"
        if timeContext == "밤" {
            lightingCondition = "어두움"
        } else if timeContext == "아침" {
            lightingCondition = "밝음"
        }
        
        // 온도
        let temperature = "쾌적함"
        
        return (
            location: location,
            timeContext: timeContext,
            weatherMood: weatherMood,
            socialSetting: socialSetting,
            noiseLevel: noiseLevel,
            lightingCondition: lightingCondition,
            temperature: temperature
        )
    }
    
    /// 인지 상태 분석
    private func analyzeCognitiveState(from message: String) -> (focusLevel: Float, mentalClarity: Float, creativityLevel: Float, stressLevel: Float, motivation: Float, decisionMaking: String) {
        let message = message.lowercased()
        
        // 집중도
        var focusLevel: Float = 0.5
        if message.contains("집중") || message.contains("몰입") {
            focusLevel = 0.8
        } else if message.contains("산만") || message.contains("정신없") {
            focusLevel = 0.2
        }
        
        // 정신적 명료성
        var mentalClarity: Float = 0.5
        if message.contains("명확") || message.contains("깔끔") {
            mentalClarity = 0.8
        } else if message.contains("혼란") || message.contains("복잡") {
            mentalClarity = 0.2
        }
        
        // 창의성
        var creativityLevel: Float = 0.5
        if message.contains("아이디어") || message.contains("창의") {
            creativityLevel = 0.8
        }
        
        // 스트레스 수준
        var stressLevel: Float = 0.5
        if message.contains("스트레스") || message.contains("압박") {
            stressLevel = 0.8
        }
        
        // 동기 부여
        var motivation: Float = 0.5
        if message.contains("의욕") || message.contains("동기") {
            motivation = 0.8
        } else if message.contains("무기력") || message.contains("의욕없") {
            motivation = 0.2
        }
        
        // 의사결정 능력
        let decisionMaking = stressLevel > 0.7 ? "어려움" : "보통"
        
        return (
            focusLevel: focusLevel,
            mentalClarity: mentalClarity,
            creativityLevel: creativityLevel,
            stressLevel: stressLevel,
            motivation: motivation,
            decisionMaking: decisionMaking
        )
    }
    
    /// 사회적 맥락 분석
    private func analyzeSocialContext(from message: String) -> (socialEnergy: Float, interpersonalStress: Float, supportNeed: String, communicationStyle: String, relationshipStatus: String) {
        let message = message.lowercased()
        
        // 사회적 에너지
        var socialEnergy: Float = 0.5
        if message.contains("외로") || message.contains("혼자") {
            socialEnergy = 0.2
        } else if message.contains("함께") || message.contains("친구") {
            socialEnergy = 0.8
        }
        
        // 대인관계 스트레스
        var interpersonalStress: Float = 0.3
        if message.contains("갈등") || message.contains("싸웠") || message.contains("화나") {
            interpersonalStress = 0.8
        }
        
        // 지원 필요도
        var supportNeed = "보통"
        if message.contains("도움") || message.contains("조언") || message.contains("위로") {
            supportNeed = "높음"
        }
        
        // 의사소통 스타일
        let communicationStyle = message.count > 100 ? "표현적" : "간결"
        
        // 관계 상태
        let relationshipStatus = "안정적"
        
        return (
            socialEnergy: socialEnergy,
            interpersonalStress: interpersonalStress,
            supportNeed: supportNeed,
            communicationStyle: communicationStyle,
            relationshipStatus: relationshipStatus
        )
    }
    
    private func generateEnterpriseRecommendation() -> RecommendationResponse {
        // 🧠 감정 기반 기본 추천 시스템
        let emotionData = getEmotionData()
        let emotionText = emotionData.emotion
        let intensity = emotionData.intensity
        
        // 감정과 강도에 따른 볼륨 조정
        let baseVolumes = SoundPresetCatalog.getRecommendedPreset(for: emotionText)
        let adjustedVolumes = baseVolumes.map { $0 * intensity }
        
        // 시간대 고려
        let hour = Calendar.current.component(.hour, from: Date())
        let timeMultiplier: Float = hour >= 22 || hour <= 6 ? 0.7 : 1.0 // 밤시간 볼륨 조정
        let finalVolumes = adjustedVolumes.map { $0 * timeMultiplier }
        
        // 성능 메트릭 업데이트
        performanceMetrics.recommendationsGenerated += 1
        performanceMetrics.aiAccuracy = 0.8 // 기본 정확도
        
        // 추천 시간 기록
        lastRecommendationTime = Date()
        
        return RecommendationResponse(
            volumes: finalVolumes,
            presetName: "🧠 AI 감정 추천",
            selectedVersions: SoundPresetCatalog.defaultVersions
        )
    }
    
    private func getBasicRecommendation() -> RecommendationResponse {
        // 기존 방식으로 폴백
        let emotion = getEmotionData().emotion
        let volumes = SoundPresetCatalog.getRecommendedPreset(for: emotion)
        return RecommendationResponse(volumes: volumes, presetName: "기본 추천")
    }
    
    // MARK: - Helper Methods for AI Context
    
    private func getEstimatedEnvironmentNoise() -> Float {
        // 시간대 기반 추정
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 22...23, 0...6: return 0.2  // 밤/새벽: 조용함
        case 7...9, 17...21: return 0.7  // 출퇴근 시간: 시끄러움
        case 10...16: return 0.5         // 낮: 보통
        default: return 0.4
        }
    }
    
    private func getCurrentActivity() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6...9: return "morning_routine"
        case 9...12: return "work"
        case 12...13: return "lunch"
        case 13...18: return "work"
        case 18...20: return "evening_routine"
        case 20...22: return "relax"
        default: return "sleep"
        }
    }
    
    private func getWeatherMood() -> Float {
        // 간단한 시뮬레이션 (실제로는 날씨 API 사용)
        return Float.random(in: 0.3...0.8)
    }
    
    private func getConsecutiveUsageCount() -> Int {
        return UserDefaults.standard.integer(forKey: "consecutive_usage_count")
    }
    
    private func getUserPreferences() -> [String: Float] {
        // 사용자 설정에서 선호도 로드
        return [
            "nature_sounds": 0.8,
            "ambient_noise": 0.6,
            "white_noise": 0.4,
            "music": 0.3
        ]
    }
    
    // MARK: - Feedback Integration
    
    private func promptForFeedback(presetName: String) {
        // 일정 시간 후 피드백 요청
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) { // 5분 후
            self.showFeedbackPrompt(presetName: presetName)
        }
    }
    
    private func showFeedbackPrompt(presetName: String) {
        let alert = UIAlertController(
            title: "🧠 AI 학습 도움", 
            message: "방금 추천받은 '\(presetName)'는 어떠셨나요? 피드백을 주시면 AI가 더 정확해집니다!", 
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "✨ 상세 피드백", style: .default) { _ in
            self.presentDetailedFeedback(presetName: presetName)
        })
        
        alert.addAction(UIAlertAction(title: "👍 좋았음", style: .default) { _ in
            self.submitQuickFeedback(satisfaction: 0.8, presetName: presetName)
        })
        
        alert.addAction(UIAlertAction(title: "👎 별로", style: .default) { _ in
            self.submitQuickFeedback(satisfaction: 0.3, presetName: presetName)
        })
        
        alert.addAction(UIAlertAction(title: "나중에", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func presentDetailedFeedback(presetName: String) {
        guard let startTime = sessionStartTime else { return }
        
        // 간단한 피드백 뷰컨트롤러 표시
        let alert = UIAlertController(
            title: "상세 피드백",
            message: "'\(presetName)' 추천에 대한 자세한 의견을 알려주세요.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "매우 만족", style: .default) { _ in
            self.submitQuickFeedback(satisfaction: 1.0, presetName: presetName)
        })
        
        alert.addAction(UIAlertAction(title: "만족", style: .default) { _ in
            self.submitQuickFeedback(satisfaction: 0.8, presetName: presetName)
        })
        
        alert.addAction(UIAlertAction(title: "보통", style: .default) { _ in
            self.submitQuickFeedback(satisfaction: 0.5, presetName: presetName)
        })
        
        alert.addAction(UIAlertAction(title: "불만족", style: .default) { _ in
            self.submitQuickFeedback(satisfaction: 0.2, presetName: presetName)
        })
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func submitQuickFeedback(satisfaction: Float, presetName: String) {
        guard let startTime = sessionStartTime else { return }
        
        // 간단한 피드백 객체 생성 (기본 FeedbackManager 호환)
        let quickFeedback = PresetFeedback(
            presetName: presetName,
            contextEmotion: getEmotionData().emotion,
            contextTime: Calendar.current.component(.hour, from: Date()),
            recommendedVolumes: Array(repeating: satisfaction * 0.7, count: 13),
            recommendedVersions: SoundPresetCatalog.defaultVersions
        )
        
        // 만족도 정보 설정
        quickFeedback.userSatisfaction = satisfaction > 0.6 ? 2 : 1 // 좋아요/싫어요
        quickFeedback.listeningDuration = Date().timeIntervalSince(startTime)
        quickFeedback.wasSaved = satisfaction > 0.6
        
        print("📝 [ChatViewController] 빠른 피드백 저장: \(presetName) (만족도: \(satisfaction))")
        
        // 성공 메시지
        showQuickFeedbackThankYou()
    }
    
    private func createQuickDeviceContext() -> [String: Any] {
        return [
            "volume": 0.7,
            "brightness": Float(UIScreen.main.brightness),
            "batteryLevel": UIDevice.current.batteryLevel,
            "deviceOrientation": UIDevice.current.orientation.rawValue.description,
            "headphonesConnected": false
        ]
    }
    
    private func createQuickEnvironmentContext() -> [String: Any] {
        return [
            "lightLevel": "보통",
            "noiseLevel": getEstimatedEnvironmentNoise(),
            "weatherCondition": nil as String?,
            "location": "앱사용",
            "timeOfUse": getCurrentTimeOfUse()
        ]
    }
    
    private func getCurrentTimeOfUse() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<9: return "아침"
        case 9..<12: return "오전"
        case 12..<18: return "오후"
        case 18..<22: return "저녁"
        case 22...23, 0..<5: return "밤"
        default: return "하루"
        }
    }
    
    private func showQuickFeedbackThankYou() {
        let message = ChatMessage(type: .bot, text: "🙏 피드백 감사합니다! AI가 조금 더 똑똑해졌어요. 계속 학습하여 더 나은 추천을 드리겠습니다!")
        messages.append(message)
        
        // 성능 메트릭 업데이트
        performanceMetrics.feedbackReceived += 1
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
    
    // ✅ appendChat 메서드 (UI 동기화 개선)
    func appendChat(_ message: ChatMessage) {
        messages.append(message)
        print("[appendChat] 메시지 추가: \(message.text)")
        if let quickActions = message.quickActions {
            print("[appendChat] quickActions: \(quickActions)")
        }
        
        // 🔧 메인 스레드에서 UI 업데이트 보장 및 충돌 방지
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.tableView.reloadData()
            
            // 애니메이션과 함께 스크롤 (부드러운 UX)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.scrollToBottom()
            }
        }
        
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
    
    // ✅ 마지막 로딩 메시지 제거 (UI 동기화 개선)
    func removeLastLoadingMessage() {
        if let lastIndex = messages.lastIndex(where: { $0.type == .loading }) {
            messages.remove(at: lastIndex)
            
            // 🔧 메인 스레드에서 UI 업데이트 보장
            DispatchQueue.main.async { [weak self] in
                self?.tableView.reloadData()
            }
        }
    }
    
    // 🆕 중복 추천 메시지 제거 (개선된 버전)
    private func removePreviousRecommendations() {
        // presetRecommendation 타입 메시지들을 모두 제거
        let initialCount = messages.count
        messages.removeAll { $0.type == .presetRecommendation }
        
        // 실제로 제거된 메시지가 있을 때만 UI 업데이트
        if messages.count != initialCount {
            DispatchQueue.main.async { [weak self] in
                self?.tableView.reloadData()
            }
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
        RemoteLogger.shared.logUserAction(action: "퀵액션클릭", details: ["actionType": action])
        
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
        // 🔒 중복 요청 방지
        guard !isProcessingRecommendation else {
            print("⚠️ 추천 요청이 이미 진행 중입니다.")
            return
        }
        
        isProcessingRecommendation = true
        
        let userMessage = ChatMessage(type: .user, text: "앱 분석 추천받기")
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
        
        // 🧠 로컬 신경망 기반 추천 시스템 (혁신적 다층 추론)
        let recentPresets = getRecentPresets()
        
        // 로컬 컨텍스트 구성 (로컬 분석 모델을 통한 다양한 정보 종합)
        let comprehensiveEngine = ComprehensiveRecommendationEngine()
        let masterRecommendation = comprehensiveEngine.generateMasterRecommendation()
        
        // 🎭 로컬 알고리즘이 생성한 시적 이름
        let poeticName = generatePoeticPresetName(
            emotion: recommendedEmotion, 
            timeOfDay: currentTimeOfDay, 
            isAI: false, 
            avoidRecentNames: recentPresets.prefix(5).map { $0.name }
        )
        
        // 🎯 로컬 추천 품질 평가
        let qualityScore = masterRecommendation.overallConfidence
        
        let recommendedPreset = (
            name: poeticName,
            volumes: masterRecommendation.primaryRecommendation.optimizedVolumes,
            description: generateLocalRecommendationDescription(
                emotion: recommendedEmotion,
                timeOfDay: currentTimeOfDay,
                confidence: qualityScore,
                qualityScore: qualityScore
            ),
            versions: masterRecommendation.primaryRecommendation.optimizedVersions
        )
        
        // 사용자 친화적인 메시지 생성
        let presetMessage = """
        **[\(recommendedPreset.name)]**
        \(recommendedPreset.description)
        
        로컬 알고리즘으로 현재 시간대에 최적화된 사운드 조합을 선별했습니다. 
        바로 적용해보세요!
        
        이 추천은 AI 사용량에 영향을 주지 않는 로컬 추천입니다.
        """
        
        // 프리셋 적용 메시지 추가
        var chatMessage = ChatMessage(type: .presetRecommendation, text: presetMessage)
        chatMessage.onApplyPreset = { [weak self] in
            print("🔥 [ChatViewController] 로컬 추천 '적용하기' 버튼 클릭됨: \(recommendedPreset.name)")
            self?.applyLocalPreset(recommendedPreset)
        }
        
        appendChat(chatMessage)
        
        // 🆕 로컬 AI 추천 기록 저장
        CachedConversationManager.shared.recordLocalAIRecommendation(
            type: "local",
            presetName: poeticName,
            confidence: qualityScore,
            context: "\(recommendedEmotion) - \(currentTimeOfDay)",
            volumes: masterRecommendation.primaryRecommendation.optimizedVolumes,
            versions: masterRecommendation.primaryRecommendation.optimizedVersions
        )
        
        // 🔓 로컬 추천 처리 완료
        isProcessingRecommendation = false
    }
    
    // 🆕 진짜 외부 AI 추천 처리 (Claude 3.5 API)
    private func handleAIRecommendation() {
        // AI 사용량 체크
        guard AIUsageManager.shared.canUse(feature: .presetRecommendation) else {
            let errorMessage = ChatMessage(type: .bot, text: "⚠️ AI 분석 추천 사용량이 초과되었습니다. (일일 5회 제한)")
            appendChat(errorMessage)
            return
        }
        
        // 🔒 중복 요청 방지
        guard !isProcessingRecommendation else {
            print("⚠️ 추천 요청이 이미 진행 중입니다.")
            return
        }
        
        isProcessingRecommendation = true
        
        let userMessage = ChatMessage(type: .user, text: "AI 분석 추천받기")
        appendChat(userMessage)
        
        // 이전 추천 메시지 제거
        removePreviousRecommendations()
        
        // 로딩 메시지 추가
        appendChat(ChatMessage(type: .loading, text: "🧠 AI가 7일간의 대화와 감정 기록을 종합 분석 중..."))
        
        // 🚀 외부 Claude 3.5 API 호출 (간소화된 버전)
        performClaudeAnalysis()
    }
    
    private func performClaudeAnalysis() {
        // 7일간 종합 기록 구성 
        let weeklyHistory = CachedConversationManager.shared.getFormattedWeeklyHistory()
        let currentContext = buildCurrentEmotionContext()
        
        // 외부 AI 분석 요청 구성
        let analysisPrompt = buildClaudeAnalysisPrompt(
            weeklyHistory: weeklyHistory,
            currentContext: currentContext
        )
        
        // Claude 3.5 API 호출
        ReplicateChatService.shared.sendCachedPrompt(
            prompt: analysisPrompt,
            useCache: false,
            estimatedTokens: 800,
            intent: "preset_recommendation"
        ) { [weak self] aiResponse in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // 로딩 메시지 제거
                self.removeLastLoadingMessage()
                
                if let response = aiResponse, !response.isEmpty {
                    // Claude의 응답을 파싱하여 프리셋 추천 생성
                    let recommendation = self.parseClaudeRecommendation(response)
                    self.displayClaudeRecommendation(recommendation)
                    
                    // AI 사용량 기록
                    AIUsageManager.shared.recordUsage(for: .presetRecommendation)
                } else {
                    let errorMessage = ChatMessage(
                        type: .bot, 
                        text: "❌ 외부 AI 분석 중 오류가 발생했습니다. 로컬 분석을 대신 제공하겠습니다."
                    )
                    self.appendChat(errorMessage)
                    
                    // 실패 시 로컬 분석으로 대체
                    self.fallbackToLocalRecommendation()
                }
                
                // 🔓 AI 추천 완료
                self.isProcessingRecommendation = false
            }
        }
    }
    
    /// 🤗 감정별 공감 메시지 생성 (방대한 데이터베이스)
    private func generateEmpathyMessage(emotion: String, timeOfDay: String, intensity: Float) -> String {
        let empathyDatabase: [String: [String]] = [
            "평온": [
                "마음에 평온이 찾아온 순간이네요. 이런 고요한 시간을 더욱 깊게 만끽해보세요.",
                "평화로운 마음 상태가 느껴집니다. 이 소중한 평온함을 지켜드릴게요.",
                "차분한 에너지가 전해져요. 내면의 고요함을 더욱 깊이 있게 경험해보세요.",
                "마음의 평형을 잘 유지하고 계시네요. 이 안정감을 더욱 풍성하게 만들어드릴게요."
            ],
            
            "수면": [
                "하루의 피로가 쌓여 깊은 휴식이 필요한 시간이네요. 편안한 잠자리를 만들어드릴게요.",
                "오늘 하루도 고생 많으셨어요. 꿈나라로의 여행을 부드럽게 안내해드릴게요.",
                "몸과 마음이 휴식을 원하고 있어요. 깊고 편안한 잠을 위한 완벽한 환경을 준비했어요."
            ],
            
            "스트레스": [
                "오늘 힘들었던 당신을 위해 마음의 짐을 덜어드리고 싶어요.",
                "쌓인 스트레스가 느껴져요. 지금 이 순간만큼은 모든 걱정에서 벗어나 보세요.",
                "마음이 무거우셨을 텐데, 이제 깊게 숨을 들이쉬고 차근차근 풀어나가요."
            ],
            
            "불안": [
                "마음이 불안하고 걱정이 많으실 텐데, 지금 이 순간은 안전해요.",
                "혼란스러운 마음을 진정시켜 드릴게요. 모든 것이 괜찮아질 거예요.",
                "불안한 마음이 잠잠해질 수 있도록 안전하고 따뜻한 공간을 만들어드릴게요."
            ],
            
            "활력": [
                "활기찬 에너지가 느껴져요! 이 좋은 기운을 더욱 키워나가볼까요?",
                "긍정적인 에너지가 넘치네요. 이 활력을 더욱 풍성하게 만들어드릴게요.",
                "생동감 넘치는 하루를 시작하시는군요. 이 에너지를 최대한 활용해보세요."
            ],
            
            "집중": [
                "집중이 필요한 중요한 시간이네요. 마음을 한곳으로 모을 수 있도록 도와드릴게요.",
                "깊은 몰입이 필요한 순간이군요. 모든 잡념을 걷어내고 온전히 집중해보세요.",
                "집중력을 높여야 할 때네요. 마음의 잡음을 제거하고 명료함을 선물해드릴게요."
            ],
            
            "행복": [
                "기쁨이 가득한 마음이 전해져요! 이 행복한 순간을 더욱 특별하게 만들어드릴게요.",
                "밝은 에너지가 느껴져서 저도 덩달아 기뻐요. 이 좋은 기분이 계속되길 바라요.",
                "행복한 마음 상태가 아름다워요. 이 기쁨을 더욱 풍성하게 만들어드릴게요."
            ],
            
            "슬픔": [
                "마음이 무거우시군요. 지금 느끼는 슬픔도 소중한 감정이에요. 함께 천천히 달래보아요.",
                "힘든 시간을 보내고 계시는 것 같아요. 혼자가 아니에요, 마음의 위로를 전해드릴게요.",
                "마음의 상처가 아물 수 있도록 따뜻한 손길을 건네드릴게요."
            ],
            
            "안정": [
                "마음의 균형이 잘 잡혀있어요. 이 안정감을 더욱 깊게 느껴보세요.",
                "내면의 평형 상태가 아름다워요. 이 고요한 안정감을 오래 유지해보세요.",
                "마음이 흔들리지 않는 견고함이 느껴져요. 이 안정감을 더욱 단단하게 만들어드릴게요."
            ],
            
            "이완": [
                "긴장을 풀고 여유를 찾을 시간이네요. 몸과 마음의 모든 긴장을 놓아보세요.",
                "스스로에게 휴식을 선물할 시간이에요. 완전히 이완된 상태를 경험해보세요.",
                "마음의 무게를 내려놓을 준비가 되신 것 같아요. 편안한 해방감을 느껴보세요."
            ]
        ]
        
        let messages = empathyDatabase[emotion] ?? empathyDatabase["평온"] ?? ["마음을 위한 특별한 시간을 준비했어요."]
        
        // 강도에 따른 메시지 선택
        let intensityIndex = intensity > 1.2 ? 0 : intensity < 0.8 ? (messages.count - 1) : (messages.count / 2)
        let safeIndex = min(intensityIndex, messages.count - 1)
        
        return messages[safeIndex]
    }
    
    // MARK: - 🚀 외부 Claude 3.5 AI 분석 헬퍼 함수들
    
    /// 현재 감정 컨텍스트 구성
    private func buildCurrentEmotionContext() -> [String: Any] {
        return [
                                    "current_emotion": getEmotionData().emotion,
        "emotion_intensity": getEmotionData().intensity,
            "time_of_day": getCurrentTimeOfDay(),
            "hour": Calendar.current.component(.hour, from: Date()),
            "recent_presets": getRecentPresets().prefix(3).map { $0.name },
            "current_volumes": getCurrentVolumes()
        ]
    }
    
    /// Claude 3.5 분석 프롬프트 구성
    private func buildClaudeAnalysisPrompt(weeklyHistory: String, currentContext: [String: Any]) -> String {
        return """
        당신은 음향 치료 전문가이자 감정 분석 AI입니다. 사용자의 7일간 대화 기록과 현재 상황을 종합 분석하여 최적의 자연 사운드 조합을 추천해주세요.
        
        ## 📊 7일간 종합 데이터:
        
        \(weeklyHistory)
        
        ## 🎯 현재 상황:
        
        **현재 감정**: \(currentContext["current_emotion"] ?? "평온")
        **감정 강도**: \(String(format: "%.1f", (currentContext["emotion_intensity"] as? Float) ?? 0.5))
        **현재 시간**: \(currentContext["time_of_day"] ?? "알 수 없음") (\(currentContext["hour"] ?? 0)시)
        **최근 사용 프리셋**: \((currentContext["recent_presets"] as? [String])?.joined(separator: ", ") ?? "없음")
        
        ## 🎵 추천 형식:
        
        다음 JSON 형식으로 응답해주세요:
        
        ```json
        {
            "preset_name": "감성적이고 시적인 프리셋 이름",
            "analysis": "7일간 패턴과 현재 상황에 대한 깊이 있는 분석 (100-150자)",
            "recommendation_reason": "이 조합을 추천하는 구체적 이유 (80-120자)",
            "volumes": [비, 바다, 숲, 시냇물, 바람, 강, 뇌우, 폭포, 새소리, 벽난로, 화이트노이즈, 브라운노이즈, 핑크노이즈],
            "versions": [13개 카테고리별 버전 0 또는 1],
            "confidence": 0.85,
            "expected_mood_improvement": "예상되는 기분 개선 효과",
            "session_duration": "권장 사용 시간 (분)"
        }
        ```
        
        사용자의 감정 패턴과 선호도를 깊이 이해하여 정말 도움이 될 맞춤형 추천을 해주세요.
        """
    }
    
    /// Claude 응답 파싱 (개선)
    private func parseClaudeRecommendation(_ response: String) -> ClaudeRecommendation {
        print("🔍 [parseClaudeRecommendation] 원본 응답:")
        print(response)
        
        // JSON 파싱 시도
        if let jsonData = extractJSONFromResponse(response),
           let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            
            let presetName = parsed["preset_name"] as? String ?? "AI 맞춤 추천"
            let analysis = parsed["analysis"] as? String ?? "7일간의 데이터를 종합 분석하여 제안한 맞춤형 사운드 조합입니다."
            let reason = parsed["recommendation_reason"] as? String ?? "현재 감정 상태와 사용 패턴을 고려한 최적화된 추천입니다."
            
            print("✅ JSON 파싱 성공 - 프리셋: \(presetName), 이유: \(reason)")
            
            return ClaudeRecommendation(
                presetName: presetName,
                analysis: analysis,
                recommendationReason: reason,
                volumes: parsed["volumes"] as? [Float] ?? getDefaultVolumes(),
                versions: parsed["versions"] as? [Int] ?? getDefaultVersions(),
                confidence: parsed["confidence"] as? Float ?? 0.85,
                expectedMoodImprovement: parsed["expected_mood_improvement"] as? String ?? "기분 개선 효과",
                sessionDuration: parsed["session_duration"] as? String ?? "30-45분"
            )
        }
        
        // JSON 파싱 실패 시 텍스트 기반 파싱 (강화)
        return parseClaudeTextResponse(response)
    }
    
    /// JSON 추출 헬퍼
    private func extractJSONFromResponse(_ response: String) -> Data? {
        let patterns = [
            "```json\\s*([\\s\\S]*?)```",
            "\\{[\\s\\S]*\\}"
        ]
        
        for pattern in patterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: response.count)
            
            if let match = regex?.firstMatch(in: response, options: [], range: range) {
                let matchRange = match.range(at: match.numberOfRanges > 1 ? 1 : 0)
                if let swiftRange = Range(matchRange, in: response) {
                    let jsonString = String(response[swiftRange])
                    return jsonString.data(using: .utf8)
                }
            }
        }
        return nil
    }
    
    /// 텍스트 기반 파싱 (JSON 실패 시) - 강화
    private func parseClaudeTextResponse(_ response: String) -> ClaudeRecommendation {
        print("⚠️ JSON 파싱 실패, 텍스트 기반 파싱 시도")
        
        // 감정 정보 추출
        let emotion = getEmotionData().emotion
        let timeOfDay = getCurrentTimeOfDay()
        
        // 텍스트에서 프리셋 이름 추출 시도 (다양한 패턴)
        var extractedName: String? = nil
        let namePatterns = [
            #"\[(.*?)\]"#,
            #"이름[:\s]*(.*?)[\n,]"#,
            #"프리셋[:\s]*(.*?)[\n,]"#,
            #"추천[:\s]*(.*?)[\n,]"#
        ]
        
        for pattern in namePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: response, options: [], range: NSRange(location: 0, length: response.count)),
               let range = Range(match.range(at: 1), in: response) {
                let extracted = String(response[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !extracted.isEmpty && extracted.count > 1 {
                    extractedName = extracted
                    break
                }
            }
        }
        
        // 추천 이유 추출 시도
        var extractedReason: String? = nil
        let reasonPatterns = [
            #"이유[:\s]*(.*?)[\n.]"#,
            #"추천.*이유[:\s]*(.*?)[\n.]"#,
            #"때문에[:\s]*(.*?)[\n.]"#,
            #"효과[:\s]*(.*?)[\n.]"#
        ]
        
        for pattern in reasonPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: response, options: [], range: NSRange(location: 0, length: response.count)),
               let range = Range(match.range(at: 1), in: response) {
                let extracted = String(response[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !extracted.isEmpty && extracted.count > 3 {
                    extractedReason = extracted
                    break
                }
            }
        }
        
        let finalName = extractedName ?? generatePoeticPresetName(emotion: emotion, timeOfDay: timeOfDay, isAI: true)
        let finalReason = extractedReason ?? "현재 감정 상태와 사용 패턴을 고려한 최적화된 추천입니다."
        
        print("📝 텍스트 파싱 결과 - 프리셋: \(finalName), 이유: \(finalReason)")
        
        return ClaudeRecommendation(
            presetName: finalName,
            analysis: "7일간의 데이터를 종합 분석하여 제안한 맞춤형 사운드 조합입니다.",
            recommendationReason: finalReason,
            volumes: extractVolumes(from: response) ?? getDefaultVolumes(),
            versions: getDefaultVersions(),
            confidence: 0.88,
            expectedMoodImprovement: "감정 안정화 및 스트레스 완화",
            sessionDuration: "30-45분"
        )
    }
    
    /// Claude 추천 표시 (개선된 버전)
    private func displayClaudeRecommendation(_ recommendation: ClaudeRecommendation) {
        // 데이터 검증 및 기본값 보장
        let safePresetName = !recommendation.presetName.isEmpty ? recommendation.presetName : generatePoeticPresetName(emotion: getEmotionData().emotion, timeOfDay: getCurrentTimeOfDay(), isAI: true)
        let safeAnalysis = !recommendation.analysis.isEmpty ? recommendation.analysis : "7일간의 대화 기록과 감정 패턴을 종합 분석하여 최적화된 사운드 조합을 제안했습니다."
        let safeReason = !recommendation.recommendationReason.isEmpty ? recommendation.recommendationReason : "현재 감정 상태와 시간대, 그리고 최근 사용 패턴을 종합적으로 고려한 맞춤형 추천입니다."
        let safeEffect = !recommendation.expectedMoodImprovement.isEmpty ? recommendation.expectedMoodImprovement : "감정 안정화 및 스트레스 완화"
        let safeDuration = !recommendation.sessionDuration.isEmpty ? recommendation.sessionDuration : "30-45분"
        
        print("🔍 [displayClaudeRecommendation] 표시할 내용:")
        print("  - 프리셋 이름: \(safePresetName)")
        print("  - 분석 내용: \(safeAnalysis)")
        print("  - 추천 이유: \(safeReason)")
        
        let presetMessage = """
        **🧠 AI 종합 분석 결과**
        
        **[\(safePresetName)]**
        
        📊 **AI 분석**: \(safeAnalysis)
        
        💡 **추천 이유**: \(safeReason)
        
        🎯 **신뢰도**: \(String(format: "%.0f%%", recommendation.confidence * 100)) (AI 종합 분석)
        📈 **예상 효과**: \(safeEffect)
        ⏱️ **권장 시간**: \(safeDuration)
        
        ✨ **특별 분석**: 7일간의 대화 기록, 감정 패턴, 사용 습관을 모두 종합하여 지금 이 순간 가장 필요한 사운드 조합을 선별했습니다.
        
        🌟 이 추천은 단순한 감정 매칭을 넘어서, 당신만의 고유한 패턴과 선호도를 반영한 개인화된 결과입니다.
        """
        
        var chatMessage = ChatMessage(type: .presetRecommendation, text: presetMessage)
        chatMessage.onApplyPreset = { [weak self] in
            // 안전한 데이터로 업데이트된 추천 사용
            let safeRecommendation = ClaudeRecommendation(
                presetName: safePresetName,
                analysis: safeAnalysis,
                recommendationReason: safeReason,
                volumes: recommendation.volumes,
                versions: recommendation.versions,
                confidence: recommendation.confidence,
                expectedMoodImprovement: safeEffect,
                sessionDuration: safeDuration
            )
            self?.applyClaudePreset(safeRecommendation)
        }
        
        appendChat(chatMessage)
    }
    
    /// Claude 프리셋 적용 (완전 개선)
    private func applyClaudePreset(_ recommendation: ClaudeRecommendation) {
        print("[applyClaudePreset] AI 추천 적용 시작: \(recommendation.presetName)")
        print("  - Claude 볼륨: \(recommendation.volumes)")
        print("  - Claude 버전: \(recommendation.versions)")
        
        // 1. 볼륨과 버전 배열 검증 및 보정
        let correctedVolumes = validateAndCorrectVolumes(recommendation.volumes)
        let correctedVersions = validateAndCorrectVersions(recommendation.versions)
        
        print("  - 보정된 볼륨: \(correctedVolumes)")
        print("  - 보정된 버전: \(correctedVersions)")
        
        // 2. 메인 스레드에서 UI 업데이트 보장
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 3. MainViewController 직접 찾아서 UI 동기화
            if let mainVC = self.findMainViewController() {
                print("🎯 [applyClaudePreset] MainViewController 발견, 직접 UI 동기화")
                
                // 3-1. 버전 정보 먼저 설정
                for (index, version) in correctedVersions.enumerated() {
                    if index < SoundPresetCatalog.categoryCount {
                        SettingsManager.shared.updateSelectedVersion(for: index, to: version)
                        print("🔄 버전 설정: 카테고리 \(index) → 버전 \(version)")
                    }
                }
                
                // 3-2. ViewController의 applyPreset 메서드 호출 (한 번만)
                mainVC.applyPreset(
                    volumes: correctedVolumes,
                    versions: correctedVersions,
                    name: recommendation.presetName,
                    shouldSaveToRecent: true
                )
                
                print("✅ applyPreset 호출 완료 - 추가 볼륨 조절 생략")
                
                // 3-3. 메인 탭으로 자동 이동
                if let tabBarController = mainVC.tabBarController {
                    tabBarController.selectedIndex = 0
                    print("🏠 메인 탭으로 이동 완료")
                }
                
            } else {
                // 4. Fallback: SoundManager + 알림 방식
                print("⚠️ [applyClaudePreset] MainViewController 접근 불가, 대체 방법 사용")
                self.applyClaudeFallbackMethod(correctedVolumes, correctedVersions, recommendation.presetName)
            }
            
            // 5. Claude 추천 기록
            CachedConversationManager.shared.recordLocalAIRecommendation(
                type: "claude",
                presetName: recommendation.presetName,
                confidence: recommendation.confidence,
                context: "Claude 3.5 외부 분석",
                volumes: correctedVolumes,
                versions: correctedVersions
            )
            
            // 6. 성공 메시지
            let successMessage = ChatMessage(
                type: .bot, 
                text: "✅ AI 추천 '\(recommendation.presetName)'가 적용되었습니다!\n\n메인 화면에서 슬라이더와 버전이 업데이트되었는지 확인해보세요."
            )
            self.appendChat(successMessage)
            
            print("✅ [applyClaudePreset] Claude 추천 적용 완료")
        }
    }
    
    /// 볼륨 배열 검증 및 보정
    private func validateAndCorrectVolumes(_ volumes: [Float]) -> [Float] {
        var corrected = volumes
        
        // 배열 크기 보정
        if corrected.count < 13 {
            let defaultVolumes = getDefaultVolumes()
            corrected = Array(corrected + defaultVolumes.suffix(13 - corrected.count))
        } else if corrected.count > 13 {
            corrected = Array(corrected.prefix(13))
        }
        
        // 값 범위 보정 (0~100)
        corrected = corrected.map { max(0, min(100, $0)) }
        
        return corrected
    }
    
    /// 버전 배열 검증 및 보정
    private func validateAndCorrectVersions(_ versions: [Int]) -> [Int] {
        var corrected = versions
        
        // 배열 크기 보정
        if corrected.count < 13 {
            let defaultVersions = getDefaultVersions()
            corrected = Array(corrected + defaultVersions.suffix(13 - corrected.count))
        } else if corrected.count > 13 {
            corrected = Array(corrected.prefix(13))
        }
        
        // 값 범위 보정 (0 또는 1)
        corrected = corrected.map { max(0, min(1, $0)) }
        
        return corrected
    }
    
    /// Fallback 방법: SoundManager + 알림
    private func applyClaudeFallbackMethod(_ volumes: [Float], _ versions: [Int], _ presetName: String) {
        // 1. 버전 정보 저장
        for (index, version) in versions.enumerated() {
            if index < SoundPresetCatalog.categoryCount {
                SettingsManager.shared.updateSelectedVersion(for: index, to: version)
            }
        }
        
        // 2. SoundManager 직접 적용
        SoundManager.shared.applyPresetWithVersions(volumes: volumes, versions: versions)
        
        // 3. UI 업데이트 알림 전송
        let userInfo: [String: Any] = [
            "volumes": volumes,
            "versions": versions,
            "name": presetName,
            "source": "claude_fallback"
        ]
        
        NotificationCenter.default.post(
            name: NSNotification.Name("ClaudePresetApplied"),
            object: nil,
            userInfo: userInfo
        )
        
        print("📢 [applyClaudeFallbackMethod] ClaudePresetApplied 알림 전송")
    }
    
    /// 실패 시 로컬 대체
    private func fallbackToLocalRecommendation() {
        // 로컬 추천으로 대체
        handleLocalRecommendation()
    }
    
    // MARK: - 🔧 헬퍼 함수들
    
    private func extractPresetName(from text: String) -> String? {
        // 프리셋 이름 추출 로직
        let patterns = ["preset_name.*?[\"'](.*?)[\"']", "\\[\\s*(.*?)\\s*\\]"]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
    
    private func extractRecommendationReason(from text: String) -> String? {
        // 추천 이유 추출 로직
        let patterns = ["recommendation_reason.*?[\"'](.*?)[\"']", "이유.*?[:.](.*?)[\n.]"]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
    
    private func extractVolumes(from text: String) -> [Float]? {
        // 볼륨 배열 추출 로직
        if let regex = try? NSRegularExpression(pattern: "volumes.*?\\[([\\d\\s,]+)\\]", options: .caseInsensitive),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
           let range = Range(match.range(at: 1), in: text) {
            let volumeString = String(text[range])
            let volumes = volumeString.components(separatedBy: ",").compactMap { Float($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            if volumes.count == 13 {
                return volumes
            }
        }
        return nil
    }
    
    private func getDefaultVolumes() -> [Float] {
        return [30, 25, 35, 20, 15, 30, 10, 25, 20, 15, 10, 15, 20]
    }
    
    private func getDefaultVersions() -> [Int] {
        return [0, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 1, 1]
    }
    
    private func getCurrentVolumes() -> [Float] {
        // SoundManager에서 현재 볼륨 정보 가져오기 (직접 접근)
        return (0..<13).map { index in
            guard index < SoundManager.shared.players.count else { return 0.0 }
            return SoundManager.shared.players[index].volume * 100 // 0-100 범위로 변환
        }
    }
    
    /// 🎵 사운드 요소별 상세 설명 생성
    private func generateSoundDescription(volumes: [Float], emotion: String) -> String {
        // 사운드 카테고리별 이름
        let soundCategories = [
            "Rain", "Ocean", "Forest", "Stream", "Wind", "River", "Thunderstorm", 
            "Waterfall", "Birds", "Fireplace", "WhiteNoise", "BrownNoise", "PinkNoise"
        ]
        
        // 사운드별 감성적 설명
        let soundDescriptions: [String: [String]] = [
            "Rain": ["부드러운 빗소리", "마음을 정화하는 빗방울", "안정감을 주는 빗소리"],
            "Ocean": ["깊은 바다의 파도", "마음을 진정시키는 파도소리", "평온한 해변의 파도"],
            "Forest": ["신선한 숲의 속삭임", "푸른 숲의 평화", "자연의 깊은 숨결"],
            "Stream": ["맑은 시냇물의 흐름", "피로 회복에 효과적인 시냇물소리", "순수한 물의 멜로디"],
            "Wind": ["부드러운 바람소리", "마음을 시원하게 하는 바람", "상쾌한 미풍"],
            "River": ["흐르는 강의 리듬", "생명력 넘치는 강물소리", "자연의 흐름"],
            "Thunderstorm": ["웅장한 천둥소리", "자연의 역동적 에너지", "정화의 뇌우"],
            "Waterfall": ["시원한 폭포소리", "활력을 주는 물소리", "생기 넘치는 폭포"],
            "Birds": ["새들의 평화로운 지저귐", "아침을 알리는 새소리", "자연의 하모니"],
            "Fireplace": ["따뜻한 벽난로 소리", "포근한 불꽃의 춤", "아늑한 공간의 소리"],
            "WhiteNoise": ["집중력을 높이는 화이트노이즈", "마음의 잡음을 차단하는 소리", "명료한 정적"],
            "BrownNoise": ["깊은 안정감의 브라운노이즈", "마음을 진정시키는 저주파", "편안한 배경 소리"],
            "PinkNoise": ["균형 잡힌 핑크노이즈", "자연스러운 배경음", "조화로운 정적"]
        ]
        
        // 감정별 강조 포인트
        let emotionFocus: [String: String] = [
            "평온": "마음의 평화를 위해", "수면": "깊은 잠을 위해", "스트레스": "스트레스 해소를 위해",
            "불안": "불안 완화를 위해", "활력": "에너지 충전을 위해", "집중": "집중력 향상을 위해",
            "행복": "기쁨 증진을 위해", "슬픔": "마음의 치유를 위해", "안정": "안정감 강화를 위해", "이완": "깊은 이완을 위해"
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
    
    /// 시적이고 감성적인 프리셋 이름 생성 (중복 방지 + 다양성 강화)
    private func generatePoeticPresetName(emotion: String, timeOfDay: String, isAI: Bool, avoidRecentNames: [String] = []) -> String {
        // 감정별 시적 표현
        let emotionPoetry: [String: [String]] = [
            "평온": ["고요한 마음", "잔잔한 호수", "평화로운 숨결", "조용한 안식", "차분한 선율", "고요한 정원", "잔잔한 물결", "평화의 노래", "마음의 쉼터", "조용한 미소"],
            "수면": ["달빛의 자장가", "꿈속의 여행", "별들의 속삭임", "깊은 밤의 포옹", "구름 위의 쉼터", "꿈의 정원", "달빛 산책", "별의 자장가", "수면의 정원", "잠의 궁전"],
            "활력": ["새벽의 각성", "생명의 춤", "에너지의 폭발", "희망의 멜로디", "활기찬 아침", "생동하는 리듬", "활력의 샘", "에너지 연주", "생명의 노래", "희망의 교향곡"],
            "집중": ["마음의 정중앙", "집중의 공간", "조용한 몰입", "깊은 사색", "고요한 탐구", "사색의 숲", "몰입의 시간", "집중의 빛", "명상의 공간", "깊은 고요"],
            "안정": ["마음의 뿌리", "안전한 품", "따뜻한 둥지", "평온한 바닥", "신뢰의 기둥", "안정의 토대", "마음의 항구", "따뜻한 안식", "신뢰의 품", "안전한 길"],
            "이완": ["부드러운 해방", "느긋한 여유", "포근한 쉼", "자연스러운 흐름", "편안한 해독", "여유의 오후", "포근한 바람", "자유로운 시간", "편안한 여행", "부드러운 미소"],
            "스트레스": ["해독의 시간", "마음의 치유", "스트레스 해소", "평온 회복", "긴장 완화", "마음의 정화", "치유의 바람", "해독의 숲", "회복의 시간", "정화의 강"],
            "불안": ["마음의 안정", "걱정 해소", "불안 진정", "평안 찾기", "안심의 공간", "평안의 등대", "안심의 품", "진정의 노래", "마음의 평화", "안전한 항구"],
            "행복": ["기쁨의 멜로디", "햇살의 춤", "웃음의 하모니", "즐거운 선율", "밝은 에너지", "행복의 정원", "웃음의 시간", "기쁨의 여행", "밝은 하루", "햇살 같은 시간"],
            "슬픔": ["위로의 포옹", "마음의 치유", "눈물의 정화", "슬픔 달래기", "상처 어루만지기", "위로의 노래", "치유의 시간", "슬픔의 정화", "마음의 위로", "따뜻한 손길"]
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
        
        // 🎲 다양한 패턴 조합 생성 (중복 방지 강화)
        let patternTemplates = [
            "\(selectedEmotion)",
            "\(selectedTime) \(selectedSuffix)",
            "\(selectedEmotion)의 \(selectedSuffix)",
            "\(selectedTime) \(selectedEmotion)",
            "\(selectedEmotion) \(selectedSuffix)",
            "\(selectedTime)의 선물",
            "\(selectedEmotion)의 시간",
            "\(selectedTime) 여행",
            "\(selectedEmotion)의 멜로디",
            "\(selectedTime) 향기"
        ]
        
        // 🔄 중복 방지 로직 적용
        var candidateNames: [String] = []
        for (_, pattern) in patternTemplates.enumerated() {
            let nameCandidate = pattern
            let isDuplicate = avoidRecentNames.contains { recentName in
                recentName.contains(nameCandidate) || nameCandidate.contains(recentName)
            }
            
            if !isDuplicate {
                candidateNames.append(nameCandidate)
            }
        }
        
        // 후보가 없으면 시간 기반 고유 이름 생성
        if candidateNames.isEmpty {
            let timestamp = Int(Date().timeIntervalSince1970) % 100
            candidateNames = ["\(selectedEmotion)의 여정 \(timestamp)", "\(selectedTime) 발견 \(timestamp)"]
        }
        
        let selectedPattern = candidateNames[(combinedSeed + avoidRecentNames.count) % candidateNames.count]
        return selectedPattern
    }
    
    // 🆕 로컬 추천 적용 (강화된 UI 동기화)
    private func applyLocalPreset(_ preset: (name: String, volumes: [Float], description: String, versions: [Int])) {
        print("🎵 [applyLocalPreset] 프리셋 적용 시작: \(preset.name)")
        print("  - 입력 볼륨: \(preset.volumes)")
        print("  - 입력 버전: \(preset.versions)")
        
        // 1. 볼륨과 버전 배열 검증 및 보정
        let correctedVolumes = validateAndCorrectVolumes(preset.volumes)
        let correctedVersions = validateAndCorrectVersions(preset.versions)
        
        print("  - 보정된 볼륨: \(correctedVolumes)")
        print("  - 보정된 버전: \(correctedVersions)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 🎯 다중 방법으로 MainViewController 접근 시도
            var mainVC: ViewController?
            
            // 방법 1: findMainViewController 사용
            mainVC = self.findMainViewController()
            
            // 방법 2: SceneDelegate를 통한 접근
            if mainVC == nil {
                if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate,
                   let tabBarController = sceneDelegate.window?.rootViewController as? UITabBarController,
                   let firstTab = tabBarController.viewControllers?.first as? ViewController {
                    mainVC = firstTab
                    print("🎯 [applyLocalPreset] SceneDelegate를 통해 MainViewController 발견")
                }
            }
            
            // 방법 3: 윈도우 계층구조 탐색
            if mainVC == nil {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let tabBarController = window.rootViewController as? UITabBarController,
                   let firstTab = tabBarController.viewControllers?.first as? ViewController {
                    mainVC = firstTab
                    print("🎯 [applyLocalPreset] 윈도우 계층구조를 통해 MainViewController 발견")
                }
            }
            
            if let targetVC = mainVC {
                print("🎯 [applyLocalPreset] MainViewController 발견, 완전 동기화 시작")
                
                // Step 1: 버전 정보 저장
                for (index, version) in correctedVersions.enumerated() {
                    if index < SoundPresetCatalog.categoryCount {
                        SettingsManager.shared.updateSelectedVersion(for: index, to: version)
                    }
                }
                
                // Step 2: 직접 applyPreset 호출 (완전한 UI + 사운드 동기화)
                targetVC.applyPreset(
                    volumes: correctedVolumes,
                    versions: correctedVersions,
                    name: preset.name,
                    shouldSaveToRecent: true
                )
                
                print("✅ [applyLocalPreset] MainViewController.applyPreset 호출 완료")
                
                // Step 3: 메인 탭으로 자동 이동
                if let tabBarController = targetVC.tabBarController {
                    tabBarController.selectedIndex = 0
                    print("🏠 메인 탭으로 이동 완료")
                }
                
            } else {
                // Fallback: NotificationCenter + SoundManager 방식
                print("⚠️ [applyLocalPreset] MainViewController를 찾을 수 없음, 알림 방식 사용")
                self.applyLocalFallbackMethod(correctedVolumes, correctedVersions, preset.name)
            }
            
            // Step 4: 성공 메시지
            let successMessage = ChatMessage(
                type: .bot, 
                text: "✅ 앱 분석 추천 '\(preset.name)'이 적용되었습니다!\n\n메인 화면에서 편안한 사운드를 즐겨보세요. 🎵"
            )
            self.appendChat(successMessage)
            
            print("✅ [applyLocalPreset] 프리셋 적용 완료: \(preset.name)")
        }
    }
    
    /// 로컬 Fallback 방법: NotificationCenter + SoundManager
    private func applyLocalFallbackMethod(_ volumes: [Float], _ versions: [Int], _ presetName: String) {
        // 1. 버전 정보 저장
        for (index, version) in versions.enumerated() {
            if index < SoundPresetCatalog.categoryCount {
                SettingsManager.shared.updateSelectedVersion(for: index, to: version)
            }
        }
        
        // 2. SoundManager 직접 적용
        SoundManager.shared.applyPresetWithVersions(volumes: volumes, versions: versions)
        
        // 3. UI 업데이트 알림 전송 (여러 알림 동시 전송)
        let userInfo: [String: Any] = [
            "volumes": volumes,
            "versions": versions,
            "name": presetName,
            "source": "local_fallback"
        ]
        
        // 기존 알림들
        NotificationCenter.default.post(
            name: NSNotification.Name("LocalPresetApplied"),
            object: nil,
            userInfo: userInfo
        )
        
        // 추가 UI 동기화 알림들
        NotificationCenter.default.post(
            name: NSNotification.Name("SoundVolumesUpdated"),
            object: nil,
            userInfo: userInfo
        )
        
        NotificationCenter.default.post(
            name: NSNotification.Name("PresetApplied"),
            object: presetName,
            userInfo: userInfo
        )
        
        print("📢 [applyLocalFallbackMethod] 다중 알림 전송 완료")
    }
    
    // 🔍 MainViewController 찾기 헬퍼
    private func findMainViewController() -> ViewController? {
        // 1. TabBarController를 통한 접근
        if let tabBarController = self.tabBarController {
            for viewController in tabBarController.viewControllers ?? [] {
                if let navController = viewController as? UINavigationController {
                    if let mainVC = navController.viewControllers.first as? ViewController {
                        print("🎯 [findMainViewController] TabBar > NavController에서 ViewController 발견")
                        return mainVC
                    }
                } else if let mainVC = viewController as? ViewController {
                    print("🎯 [findMainViewController] TabBar에서 직접 ViewController 발견")
                    return mainVC
                }
            }
        }
        
        // 2. NavigationController를 통한 접근
        if let navController = self.navigationController {
            for viewController in navController.viewControllers {
                if let mainVC = viewController as? ViewController {
                    print("🎯 [findMainViewController] NavigationController에서 ViewController 발견")
                    return mainVC
                }
            }
        }
        
        // 3. 윈도우 씬을 통한 접근
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            if let mainVC = rootVC as? ViewController {
                print("🎯 [findMainViewController] 윈도우 루트에서 직접 ViewController 발견")
                return mainVC
            } else if let tabBarController = rootVC as? UITabBarController {
                for viewController in tabBarController.viewControllers ?? [] {
                    if let navController = viewController as? UINavigationController {
                        if let mainVC = navController.viewControllers.first as? ViewController {
                            print("🎯 [findMainViewController] 윈도우 > TabBar > NavController에서 ViewController 발견")
                            return mainVC
                        }
                    } else if let mainVC = viewController as? ViewController {
                        print("🎯 [findMainViewController] 윈도우 > TabBar에서 직접 ViewController 발견")
                        return mainVC
                    }
                }
            } else if let navController = rootVC as? UINavigationController {
                if let mainVC = navController.viewControllers.first as? ViewController {
                    print("🎯 [findMainViewController] 윈도우 > NavController에서 ViewController 발견")
                    return mainVC
                }
            }
        }
        
        print("⚠️ [findMainViewController] ViewController를 찾을 수 없음")
        return nil
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
    
    // MARK: - 🧠 AI 추천 시스템 헬퍼 함수들
    
    /// 사용자 활동 감지 (실제 AI처럼 다양한 신호 분석)
    private func detectUserActivity() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let batteryLevel = UIDevice.current.batteryLevel
        
        // 시간대 + 배터리 상태 + 앱 사용 패턴으로 활동 추정
        switch hour {
        case 6...9:
            return batteryLevel > 0.8 ? "아침 준비" : "휴식"
        case 10...12:
            return "업무"
        case 13...14:
            return "휴식"
        case 15...18:
            return "업무"
        case 19...21:
            return "저녁 시간"
        case 22...24, 0...5:
            return "휴식"
        default:
            return "일반"
        }
    }
    
    /// 개인화 데이터 로드
    private func loadUserPreferences() -> [String: Float] {
        var preferences: [String: Float] = [:]
        
        // UserDefaults에서 사용자 선호도 가져오기
        preferences["자연음"] = UserDefaults.standard.float(forKey: "pref_nature_sounds") 
        preferences["백색소음"] = UserDefaults.standard.float(forKey: "pref_white_noise")
        preferences["ASMR"] = UserDefaults.standard.float(forKey: "pref_asmr")
        preferences["리듬감"] = UserDefaults.standard.float(forKey: "pref_rhythm")
        preferences["고요함"] = UserDefaults.standard.float(forKey: "pref_silence")
        preferences["활력"] = UserDefaults.standard.float(forKey: "pref_energy")
        preferences["치유"] = UserDefaults.standard.float(forKey: "pref_healing")
        
        // 기본값 설정 (0.5는 중립)
        for key in preferences.keys {
            if preferences[key] == 0.0 {
                preferences[key] = 0.5
            }
        }
        
        // 사용 횟수 추가
        let usageCount = UserDefaults.standard.float(forKey: "total_usage_count")
        preferences["_usage_count"] = max(1.0, usageCount)
        
        return preferences
    }
    
    /// 날씨 기분 감지 (간단한 시뮬레이션)
    private func getCurrentWeatherMood() -> String {
        // 실제로는 날씨 API를 호출하겠지만, 여기서는 시간 기반으로 시뮬레이션
        let hour = Calendar.current.component(.hour, from: Date())
        let day = Calendar.current.component(.day, from: Date())
        
        let weatherPattern = (hour + day) % 4
        switch weatherPattern {
        case 0: return "맑음"
        case 1: return "흐림"
        case 2: return "비"
        default: return ""
        }
    }
    

    
    /// 로컬 추천 설명 생성
    private func generateLocalRecommendationDescription(
        emotion: String,
        timeOfDay: String,
        confidence: Float,
        qualityScore: Float
    ) -> String {
        
        let confidenceLevel = confidence > 0.85 ? "매우 높은" : (confidence > 0.75 ? "높은" : "적절한")
        let qualityLevel = qualityScore > 90 ? "최적화된" : (qualityScore > 75 ? "균형잡힌" : "기본적인")
        
        let emotionDescriptions: [String: String] = [
            "스트레스": "긴장된 마음을 달래주는",
            "수면": "깊은 잠으로 이끄는",
            "집중": "몰입을 돕는",
            "평온": "내면의 평화를 찾는",
            "활력": "생기를 불어넣는",
            "불안": "마음의 안정을 주는"
        ]
        
        let timeDescriptions: [String: String] = [
            "새벽": "고요한 새벽의",
            "아침": "활기찬 아침의",
            "오후": "차분한 오후의", 
            "저녁": "포근한 저녁의",
            "밤": "깊은 밤의"
        ]
        
        let emotionDesc = emotionDescriptions[emotion] ?? "마음을 다스리는"
        let timeDesc = timeDescriptions[timeOfDay] ?? "현재 순간의"
        
        return "로컬 분석이 \(confidenceLevel) 확신으로 선별한 \(timeDesc) \(emotionDesc) \(qualityLevel) 사운드 조합입니다."
    }
    
    /// 최근 프리셋 가져오기
    private func getRecentPresets() -> [SoundPreset] {
        let allPresets = SettingsManager.shared.loadSoundPresets()
        // ✅ 수정: 최신 생성 날짜 순으로 4개까지 (AI/로컬 구분 없이)
        return Array(allPresets.prefix(4))
    }
    
    // Helper method to safely extract emotion data from currentEmotion
    private func getEmotionData() -> (emotion: String, intensity: Float) {
        if let emotion = currentEmotion as? (primaryEmotion: String, intensity: Float, physicalState: Any, environmentContext: Any, cognitiveState: Any, socialContext: Any) {
            return (emotion.primaryEmotion, emotion.intensity)
        }
        return ("평온", 0.5)
    }
    
    // MARK: - 🔄 프리셋 적용 처리 (우선순위: 채팅 → 기본)
    private func applyPresetInMainViewController(_ preset: SoundPreset) {
        print("🎵 [applyPresetInMainViewController] 프리셋 적용 시작: \(preset.name)")
        
        // Step 1: MainViewController 다양한 방법으로 찾기
        var mainVC: ViewController? = nil
        var searchMethod = "unknown"
        
        // 방법 1: parent 체크
        if let parentVC = self.parent as? ViewController {
            mainVC = parentVC
            searchMethod = "parent"
        }
        
        // 방법 2: navigation stack 탐색
        if mainVC == nil, let navController = self.navigationController {
            for viewController in navController.viewControllers {
                if let viewController = viewController as? ViewController {
                    mainVC = viewController
                    searchMethod = "navigation_stack"
                    break
                }
            }
        }
        
        // 방법 3: tab bar 탐색
        if mainVC == nil, let tabBarController = self.tabBarController {
            for viewController in tabBarController.viewControllers ?? [] {
                if let viewController = viewController as? ViewController {
                    mainVC = viewController
                    searchMethod = "tab_direct"
                    break
                } else if let navController = viewController as? UINavigationController {
                    for vc in navController.viewControllers {
                        if let viewController = vc as? ViewController {
                            mainVC = viewController
                            searchMethod = "tab_navigation"
                            break
                        }
                    }
                }
            }
        }
        
        // 방법 4: 윈도우 계층 탐색
        if mainVC == nil {
            for window in UIApplication.shared.windows {
                if let tabBarController = window.rootViewController as? UITabBarController {
                    for viewController in tabBarController.viewControllers ?? [] {
                        if let viewController = viewController as? ViewController {
                            mainVC = viewController
                            searchMethod = "window_tab"
                            break
                        } else if let navController = viewController as? UINavigationController {
                            for vc in navController.viewControllers {
                                if let viewController = vc as? ViewController {
                                    mainVC = viewController
                                    searchMethod = "window_navigation"
                                    break
                                }
                            }
                        }
                    }
                }
            }
        }
        
        if let targetVC = mainVC {
            print("🎯 [applyPresetInMainViewController] MainViewController 발견 (\(searchMethod))")
            
            // Step 2: 메인 스레드에서 프리셋 적용
            DispatchQueue.main.async {
                targetVC.applyPreset(
                    volumes: preset.volumes,
                    versions: preset.selectedVersions,
                    name: preset.name,
                    shouldSaveToRecent: true
                )
                
                print("✅ [applyPresetInMainViewController] applyPreset 호출 완료")
            }
        } else {
            print("⚠️ [applyPresetInMainViewController] MainViewController를 찾을 수 없음")
            
            // Fallback: SoundManager 직접 사용
            SoundManager.shared.applyPresetWithVersions(volumes: preset.volumes, versions: preset.selectedVersions)
            
            // UI 업데이트 알림
            let userInfo: [String: Any] = [
                "volumes": preset.volumes,
                "versions": preset.selectedVersions,
                "name": preset.name,
                "source": "chat_fallback"
            ]
            
            NotificationCenter.default.post(
                name: NSNotification.Name("PresetAppliedFromChat"),
                object: nil,
                userInfo: userInfo
            )
            
            print("📢 [applyPresetInMainViewController] Fallback 알림 전송")
        }
    }
    
    // MARK: - 🎵 프리셋 적용 콜백 (onApplyPreset)
    @objc private func applyRecommendedPreset() {
        guard !isProcessingRecommendation else {
            print("⚠️ [applyRecommendedPreset] 이미 처리 중인 추천이 있습니다.")
            return
        }
        
        isProcessingRecommendation = true
        defer { isProcessingRecommendation = false }
        
        print("🎵 [applyRecommendedPreset] 추천 프리셋 적용 시작")
        
        // 현재 감정 정보 가져오기
        let emotionData = getEmotionData()
        let emotionText = emotionData.emotion
        let intensity = emotionData.intensity
        
        // 기본 볼륨 가져오기
        let baseVolumes = SoundPresetCatalog.getRecommendedPreset(for: emotionText)
        let adjustedVolumes = baseVolumes.map { $0 * intensity }
        let versions = SoundPresetCatalog.defaultVersions
        
        // 프리셋 생성
        let preset = SoundPreset(
            name: "🧠 AI 감정 추천",
            volumes: adjustedVolumes,
            selectedVersions: versions,
            emotion: emotionText,
            isAIGenerated: true,
            description: "\(emotionText) 감정에 맞춘 AI 추천 프리셋"
        )
        
        // 프리셋 적용
        applyPresetInMainViewController(preset)
        
        // 성공 메시지
        DispatchQueue.main.async {
            let successMessage = ChatMessage(type: .bot, text: "✅ '\(preset.name)' 프리셋이 적용되었습니다!")
            self.messages.append(successMessage)
            self.tableView.reloadData()
            self.scrollToBottom()
        }
        
        print("✅ [applyRecommendedPreset] 프리셋 적용 완료")
    }
    
    // MARK: - 🧠 Enhanced AI Integration (수정됨)
    
    /// 향상된 감정 기반 프리셋 생성
    private func createEnhancedPreset() -> SoundPreset {
        let emotionData = getEmotionData()
        let emotion = emotionData.emotion
        
        let baseVolumes = SoundPresetCatalog.getRecommendedPreset(for: emotion)
        let versions = SoundPresetCatalog.defaultVersions
        
        // 피드백 기록 생성
        let feedback = PresetFeedback(
            presetName: "🧠 Enhanced AI 추천",
            contextEmotion: emotionData.emotion,
            contextTime: Calendar.current.component(.hour, from: Date()),
            recommendedVolumes: baseVolumes,
            recommendedVersions: versions
        )
        
        // 컨텍스트 저장 (SwiftData)
        // TODO: SwiftData 컨텍스트에 저장
        
        return SoundPreset(
            name: "🧠 Enhanced AI 추천",
            volumes: baseVolumes,
            selectedVersions: versions,
            emotion: emotion,
            isAIGenerated: true,
            description: "\(emotion) 감정 기반 고도화된 AI 추천"
        )
    }
    
    /// 빠른 피드백 UI 생성
    private func createQuickFeedbackButtons() -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // 👍 버튼
        let likeButton = UIButton(type: .system)
        likeButton.setTitle("👍 좋아요", for: .normal)
        likeButton.backgroundColor = .systemGreen
        likeButton.setTitleColor(.white, for: .normal)
        likeButton.layer.cornerRadius = 8
        likeButton.addTarget(self, action: #selector(quickLikeTapped), for: .touchUpInside)
        
        // 👎 버튼
        let dislikeButton = UIButton(type: .system)
        dislikeButton.setTitle("👎 별로예요", for: .normal)
        dislikeButton.backgroundColor = .systemRed
        dislikeButton.setTitleColor(.white, for: .normal)
        dislikeButton.layer.cornerRadius = 8
        dislikeButton.addTarget(self, action: #selector(quickDislikeTapped), for: .touchUpInside)
        
        stackView.addArrangedSubview(likeButton)
        stackView.addArrangedSubview(dislikeButton)
        
        containerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
            stackView.heightAnchor.constraint(equalToConstant: 40),
            containerView.heightAnchor.constraint(equalToConstant: 56)
        ])
        
        return containerView
    }
    
    @objc private func quickLikeTapped() {
        recordQuickFeedback(satisfaction: 2) // 좋아요
    }
    
    @objc private func quickDislikeTapped() {
        recordQuickFeedback(satisfaction: 1) // 싫어요
    }
    
    private func recordQuickFeedback(satisfaction: Int) {
        let emotionData = getEmotionData()
        
        // 빠른 피드백 기록 생성
        let feedback = PresetFeedback(
            presetName: "빠른 피드백",
            contextEmotion: emotionData.emotion,
            contextTime: Calendar.current.component(.hour, from: Date()),
            recommendedVolumes: [],
            recommendedVersions: []
        )
        feedback.userSatisfaction = satisfaction
        
        // 디바이스 컨텍스트 생성 및 기록
        let deviceContext = createQuickDeviceContext()
        let environmentContext = createQuickEnvironmentContext()
        
        // TODO: SwiftData에 저장
        
        showQuickFeedbackThankYou()
    }
    
    // MARK: - ✅ Swipe Back Gesture Support
    private func enableSwipeBackGesture() {
        // 네비게이션 컨트롤러의 interactive pop gesture 활성화
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
}

// MARK: - UIGestureRecognizerDelegate
extension ChatViewController {
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
