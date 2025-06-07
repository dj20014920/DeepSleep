import UIKit

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
    
    // 🧠 Enhanced AI Properties
    private var currentSessionId = UUID()
    private var lastRecommendationTime: Date?
    private var currentEmotion: EnhancedEmotion?
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
        
        // Enhanced Data Manager에 감정 저장
        EnhancedDataManager.shared.saveEnhancedEmotion(enhancedEmotion)
        
        // 기존 처리 로직 호출
        processUserMessageInternal(userMessage)
    }
    
    private func analyzeEnhancedEmotion(from message: String) -> EnhancedEmotion {
        // 🧠 Enterprise-level 감정 분석
        let emotionAnalyzer = EmotionAnalyzer()
        let basicEmotion = emotionAnalyzer.extractBasicEmotion(from: message)
        
        // 감정 강도 계산 (키워드 기반 + 문맥 분석)
        let intensity = calculateEmotionIntensity(from: message)
        
        // 감정 유발 요인 추출
        let triggers = extractEmotionTriggers(from: message)
        
        // 신체 증상 추출
        let physicalSymptoms = extractPhysicalSymptoms(from: message)
        
        // 인지 상태 분석
        let cognitiveState = analyzeCognitiveState(from: message)
        
        // 사회적 맥락 분석
        let socialContext = analyzeSocialContext(from: message)
        
        return EnhancedEmotion(
            id: UUID(),
            emotion: basicEmotion,
            intensity: intensity,
            confidence: 0.85, // 모델 신뢰도
            triggers: triggers,
            physicalSymptoms: physicalSymptoms,
            cognitiveState: cognitiveState,
            socialContext: socialContext,
            timestamp: Date()
        )
    }
    
    private func calculateEmotionIntensity(from message: String) -> Float {
        let intensityKeywords: [String: Float] = [
            "매우": 0.9, "정말": 0.8, "너무": 0.8, "엄청": 0.8, "심하게": 0.9,
            "조금": 0.3, "약간": 0.3, "살짝": 0.2, "가끔": 0.3,
            "완전": 0.9, "진짜": 0.7, "심각": 0.9, "극도로": 1.0
        ]
        
        let messageLower = message.lowercased()
        var maxIntensity: Float = 0.5 // 기본값
        
        for (keyword, intensity) in intensityKeywords {
            if messageLower.contains(keyword) {
                maxIntensity = max(maxIntensity, intensity)
            }
        }
        
        // 메시지 길이와 느낌표 개수도 고려
        let lengthFactor = min(1.0, Float(message.count) / 100.0)
        let exclamationCount = message.filter { $0 == "!" }.count
        let exclamationFactor = min(0.3, Float(exclamationCount) * 0.1)
        
        return min(1.0, maxIntensity + lengthFactor * 0.2 + exclamationFactor)
    }
    
    private func extractEmotionTriggers(from message: String) -> [String] {
        let triggerKeywords: [String: String] = [
            "직장": "work_stress", "업무": "work_stress", "회사": "work_stress",
            "관계": "relationship_issues", "가족": "relationship_issues", "친구": "relationship_issues",
            "건강": "health_concerns", "몸": "health_concerns", "아프": "health_concerns",
            "잠": "sleep_problems", "수면": "sleep_problems", "피곤": "sleep_problems",
            "시간": "time_pressure", "급하": "time_pressure", "바쁘": "time_pressure"
        ]
        
        var triggers: [String] = []
        let messageLower = message.lowercased()
        
        for (keyword, trigger) in triggerKeywords {
            if messageLower.contains(keyword) {
                triggers.append(trigger)
            }
        }
        
        return Array(Set(triggers)) // 중복 제거
    }
    
    private func extractPhysicalSymptoms(from message: String) -> [String] {
        let symptomKeywords: [String: String] = [
            "머리": "headache", "두통": "headache",
            "어깨": "muscle_tension", "목": "muscle_tension", "긴장": "muscle_tension",
            "피곤": "fatigue", "지치": "fatigue", "힘들": "fatigue",
            "답답": "breathing_issues", "숨": "breathing_issues",
            "심장": "heart_racing", "두근": "heart_racing",
            "잠": "insomnia", "못자": "insomnia"
        ]
        
        var symptoms: [String] = []
        let messageLower = message.lowercased()
        
        for (keyword, symptom) in symptomKeywords {
            if messageLower.contains(keyword) {
                symptoms.append(symptom)
            }
        }
        
        return Array(Set(symptoms))
    }
    
    private func analyzeCognitiveState(from message: String) -> EnhancedEmotion.CognitiveState {
        let messageLower = message.lowercased()
        
        // 집중도 분석
        let focusKeywords = ["집중", "몰입", "정신없", "산만", "딴생각"]
        let focusScore = focusKeywords.contains { messageLower.contains($0) } ? 
            (messageLower.contains("집중") || messageLower.contains("몰입") ? 0.8 : 0.3) : 0.5
        
        // 에너지 수준 분석
        let energyKeywords = ["활력", "에너지", "힘", "피곤", "지침"]
        let energyScore = energyKeywords.contains { messageLower.contains($0) } ?
            (messageLower.contains("활력") || messageLower.contains("에너지") ? 0.8 : 0.3) : 0.5
        
        // 동기 수준 분석
        let motivationScore = messageLower.contains("의욕") ? 0.8 : 
            (messageLower.contains("무기력") ? 0.2 : 0.5)
        
        // 정신적 명료도 분석
        let clarityScore = messageLower.contains("혼란") ? 0.3 : 
            (messageLower.contains("명확") ? 0.8 : 0.5)
        
        return EnhancedEmotion.CognitiveState(
            focus: Float(focusScore),
            energy: Float(energyScore),
            motivation: Float(motivationScore),
            clarity: Float(clarityScore)
        )
    }
    
    private func analyzeSocialContext(from message: String) -> EnhancedEmotion.SocialContext {
        let messageLower = message.lowercased()
        
        let isAlone = messageLower.contains("혼자") || messageLower.contains("외로")
        
        var socialActivity: String?
        if messageLower.contains("가족") {
            socialActivity = "가족시간"
        } else if messageLower.contains("친구") {
            socialActivity = "친구만남"
        } else if messageLower.contains("회사") || messageLower.contains("업무") {
            socialActivity = "업무미팅"
        }
        
        var communicationMode: String?
        if messageLower.contains("대화") {
            communicationMode = "대화"
        } else if messageLower.contains("문자") || messageLower.contains("카톡") {
            communicationMode = "텍스트"
        } else if isAlone {
            communicationMode = "혼자"
        }
        
        return EnhancedEmotion.SocialContext(
            isAlone: isAlone,
            socialActivity: socialActivity,
            communicationMode: communicationMode
        )
    }
    
    private func generateEnterpriseRecommendation() -> RecommendationResponse {
        guard let emotion = currentEmotion else {
            return getBasicRecommendation()
        }
        
        // 🧠 Enterprise AI Context 생성
        let context = EnhancedAIContext(
            emotion: emotion.emotion,
            emotionIntensity: emotion.intensity,
            timeOfDay: Calendar.current.component(.hour, from: Date()),
            environmentNoise: getEstimatedEnvironmentNoise(),
            recentActivity: getCurrentActivity(),
            userId: UIDevice.current.identifierForVendor?.uuidString ?? "anonymous",
            weatherMood: getWeatherMood(),
            consecutiveUsage: getConsecutiveUsageCount(),
            userPreference: getUserPreferences()
        )
        
        // 🧠 LocalAIRecommendationEngine 사용
        let aiRecommendation = LocalAIRecommendationEngine.shared.getEnterpriseRecommendation(context: context)
        
        // 성능 메트릭 업데이트
        performanceMetrics.recommendationsGenerated += 1
        performanceMetrics.aiAccuracy = aiRecommendation.overallConfidence
        
        // 추천 시간 기록
        lastRecommendationTime = Date()
        
        // 피드백 대기 목록에 추가
        let presetId = UUID()
        feedbackPendingPresets[presetId] = aiRecommendation.primaryRecommendation.presetName
        
        // 기존 형식으로 변환
        return convertToRecommendationResponse(aiRecommendation)
    }
    
    private func convertToRecommendationResponse(_ aiRecommendation: EnterpriseRecommendation) -> RecommendationResponse {
        // AI 추천을 기존 볼륨 배열로 변환
        let presetName = aiRecommendation.primaryRecommendation.presetName
        
        // SoundPresetCatalog에서 기본 볼륨 가져오기
        let baseVolumes = SoundPresetCatalog.getRecommendedPreset(for: currentEmotion?.emotion ?? "평온")
        
        // AI 추천 신뢰도에 따라 볼륨 조정
        let confidenceMultiplier = aiRecommendation.overallConfidence
        let adjustedVolumes = baseVolumes.map { $0 * confidenceMultiplier }
        
        // 선택된 버전들
        let selectedVersions = Array(repeating: aiRecommendation.primaryRecommendation.selectedVersion, 
                                   count: SoundPresetCatalog.categoryCount)
        
        return RecommendationResponse(
            volumes: adjustedVolumes,
            presetName: presetName,
            selectedVersions: selectedVersions
        )
    }
    
    private func getBasicRecommendation() -> RecommendationResponse {
        // 기존 방식으로 폴백
        let emotion = currentEmotion?.emotion ?? "평온"
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
        guard let presetId = feedbackPendingPresets.first(where: { $0.value == presetName })?.key,
              let startTime = sessionStartTime else { return }
        
        let feedbackVC = EnhancedFeedbackViewController(
            presetId: presetId,
            sessionId: currentSessionId,
            startTime: startTime,
            currentEmotion: currentEmotion
        )
        
        let navController = UINavigationController(rootViewController: feedbackVC)
        present(navController, animated: true)
    }
    
    private func submitQuickFeedback(satisfaction: Float, presetName: String) {
        guard let presetId = feedbackPendingPresets.first(where: { $0.value == presetName })?.key,
              let startTime = sessionStartTime else { return }
        
        // 간단한 피드백 객체 생성
        let quickFeedback = PresetFeedback(
            id: UUID(),
            presetId: presetId,
            userId: UIDevice.current.identifierForVendor?.uuidString ?? "anonymous",
            sessionId: currentSessionId,
            effectiveness: satisfaction,
            relaxation: satisfaction,
            focus: satisfaction * 0.8,
            sleepQuality: satisfaction * 0.7,
            overallSatisfaction: satisfaction,
            usageDuration: Date().timeIntervalSince(startTime),
            intentionalStop: true,
            repeatUsage: false,
            deviceContext: createQuickDeviceContext(),
            environmentContext: createQuickEnvironmentContext(),
            tags: satisfaction > 0.6 ? ["좋음"] : ["개선필요"],
            preferredAdjustments: [],
            moodAfter: satisfaction > 0.6 ? "🙂 좋아짐" : "😐 비슷함",
            wouldRecommend: satisfaction > 0.6,
            timestamp: Date()
        )
        
        EnhancedDataManager.shared.savePresetFeedback(quickFeedback)
        
        // 성공 메시지
        showQuickFeedbackThankYou()
        
        // 피드백 목록에서 제거
        feedbackPendingPresets.removeValue(forKey: presetId)
    }
    
    private func createQuickDeviceContext() -> PresetFeedback.DeviceContext {
        return PresetFeedback.DeviceContext(
            volume: 0.7,
            brightness: Float(UIScreen.main.brightness),
            batteryLevel: UIDevice.current.batteryLevel,
            deviceOrientation: UIDevice.current.orientation.rawValue.description,
            headphonesConnected: false
        )
    }
    
    private func createQuickEnvironmentContext() -> PresetFeedback.EnvironmentContext {
        return PresetFeedback.EnvironmentContext(
            lightLevel: "보통",
            noiseLevel: getEstimatedEnvironmentNoise(),
            weatherCondition: nil,
            location: "앱사용",
            timeOfUse: getCurrentTimeOfUse()
        )
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
    
    // 🆕 AI 추천 처리
    private func handleAIRecommendation() {
        // 🔒 중복 요청 방지
        guard !isProcessingRecommendation else {
            print("⚠️ 추천 요청이 이미 진행 중입니다.")
            return
        }
        
        isProcessingRecommendation = true
        
        let userMessage = ChatMessage(type: .user, text: "고급 AI 분석 추천받기")
        appendChat(userMessage)
        
        // 이전 추천 메시지 제거
        removePreviousRecommendations()
        
        // 로딩 메시지 추가
        appendChat(ChatMessage(type: .loading, text: "고급 신경망이 분석 중..."))
        
        // 🧠 고급 로컬 AI 신경망 분석 (비동기 처리)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Enterprise AI Context 생성
            let context = EnhancedAIContext(
                emotion: self.currentEmotion?.emotion ?? "평온",
                emotionIntensity: self.currentEmotion?.intensity ?? 0.5,
                timeOfDay: Calendar.current.component(.hour, from: Date()),
                environmentNoise: self.getEstimatedEnvironmentNoise(),
                recentActivity: self.getCurrentActivity(),
                userId: UIDevice.current.identifierForVendor?.uuidString ?? "anonymous",
                weatherMood: self.getWeatherMood(),
                consecutiveUsage: self.getConsecutiveUsageCount(),
                userPreference: self.getUserPreferences()
            )
            
            // 🚀 고급 신경망 추론 엔진 실행
            let aiRecommendation = LocalAIRecommendationEngine.shared.getEnterpriseRecommendation(context: context)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // 로딩 메시지 제거
                self.removeLastLoadingMessage()
                
                // 기존 형식으로 변환
                let recommendation = self.convertToRecommendationResponse(aiRecommendation)
                
                // 감정 분석 정보 생성
                let parsedAnalysis = (
                    emotion: context.emotion,
                    intensity: context.emotionIntensity,
                    timeOfDay: self.getCurrentTimeOfDay()
                )
                
                // 🤖 고급 AI 신경망 기반 프리셋 생성
                let poeticName = self.generatePoeticPresetName(
                    emotion: parsedAnalysis.emotion, 
                    timeOfDay: parsedAnalysis.timeOfDay, 
                    isAI: true
                )
                
                let recommendedPreset = (
                    name: poeticName,
                    volumes: recommendation.volumes,
                    description: "\(parsedAnalysis.emotion) 감정에 최적화된 고급 AI 신경망 분석",
                    versions: recommendation.selectedVersions
                )
                
                // 🤗 감정 공감 메시지와 사운드 설명 생성
                let empathyMessage = self.generateEmpathyMessage(
                    emotion: parsedAnalysis.emotion, 
                    timeOfDay: parsedAnalysis.timeOfDay, 
                    intensity: parsedAnalysis.intensity
                )
                let soundDescription = self.generateSoundDescription(
                    volumes: recommendation.volumes, 
                    emotion: parsedAnalysis.emotion
                )
                
                let presetMessage = """
                \(empathyMessage)
                
                **[\(recommendedPreset.name)]**
                \(soundDescription)
                
                🧠 신뢰도: \(String(format: "%.1f", aiRecommendation.overallConfidence * 100))% (고급 신경망 분석)
                """
                
                // 프리셋 적용 메시지 추가
                var chatMessage = ChatMessage(type: .presetRecommendation, text: presetMessage)
                chatMessage.onApplyPreset = { [weak self] in
                    self?.applyLocalPreset(recommendedPreset)
                }
                
                self.appendChat(chatMessage)
                
                // 🆕 고급 AI 추천 기록 저장
                CachedConversationManager.shared.recordLocalAIRecommendation(
                    type: "ai",
                    presetName: poeticName,
                    confidence: aiRecommendation.overallConfidence,
                    context: "\(context.emotion) - 고급분석",
                    volumes: recommendation.volumes,
                    versions: recommendation.selectedVersions
                )
                
                // 🔓 고급 AI 추천 완료
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
    
    // 🆕 프리셋 적용 로직
    private func applyLocalPreset(_ preset: (name: String, volumes: [Float], description: String, versions: [Int])) {
        print("🎵 프리셋 적용 시작: \(preset.name)")
        
        // 🔧 ViewController의 applyPreset 메서드를 사용하여 UI까지 완전히 동기화
        if let mainVC = findMainViewController() {
            DispatchQueue.main.async {
                // 볼륨은 0~100 범위로 변환 (ViewController.applyPreset은 0~100 범위 기대)
                let volumesForUI = preset.volumes.map { $0 } // 이미 0~100 범위
                
                print("🎵 [ChatViewController] ViewController.applyPreset 호출: \(preset.name)")
                print("  - 볼륨: \(volumesForUI)")
                print("  - 버전: \(preset.versions)")
                
                mainVC.applyPreset(volumes: volumesForUI, versions: preset.versions, name: preset.name)
                
                // 메인 탭으로 이동 (사용자가 바로 확인할 수 있도록)
                if let tabBarController = mainVC.tabBarController {
                    tabBarController.selectedIndex = 0
                }
            }
        } else {
            // Fallback: 기존 방식 사용 (하지만 UI 동기화 문제 있음)
            print("⚠️ [ChatViewController] MainViewController를 찾을 수 없어 fallback 방식 사용")
            
            // 1. 기존 사운드 정지
            SoundManager.shared.stopAll()
            
            // 2. 버전 정보 적용
            for (categoryIndex, versionIndex) in preset.versions.enumerated() {
                if categoryIndex < SoundPresetCatalog.categoryCount {
                    SettingsManager.shared.updateSelectedVersion(for: categoryIndex, to: versionIndex)
                }
            }
            
            // 3. 볼륨 설정 적용 (0~1 범위로 변환)
            for (index, volume) in preset.volumes.enumerated() {
                if index < SoundPresetCatalog.categoryCount {
                    SoundManager.shared.setVolume(for: index, volume: volume / 100.0)
                }
            }
            
            // 4. 사운드 재생
            SoundManager.shared.playActiveSounds()
            
            // 5. 메인 화면 UI 업데이트 알림 (버전 정보도 포함)
            let userInfo = [
                "volumes": preset.volumes,
                "versions": preset.versions,
                "name": preset.name
            ] as [String: Any]
            
            NotificationCenter.default.post(
                name: NSNotification.Name("PresetAppliedFromChat"), 
                object: nil, 
                userInfo: userInfo
            )
        }
        
        // 6. 성공 메시지
        let successMessage = ChatMessage(type: .bot, text: "✅ '\(preset.name)' 프리셋이 적용되었습니다! 지금 바로 편안한 사운드를 즐겨보세요. 🎵")
        appendChat(successMessage)
        
        // 7. 메인 화면으로 이동 버튼 제공
        let backToMainMessage = ChatMessage(type: .bot, text: "🏠 메인 화면으로 이동해서 사운드를 조정해보세요!")
        appendChat(backToMainMessage)
        
        print("🎵 프리셋 적용 완료: \(preset.name)")
    }
    
    // 🔍 MainViewController 찾기 헬퍼
    private func findMainViewController() -> ViewController? {
        // 1. parent를 통해 찾기
        if let parentVC = self.parent as? ViewController {
            return parentVC
        }
        
        // 2. navigation stack에서 찾기
        if let navController = self.navigationController {
            for viewController in navController.viewControllers {
                if let mainVC = viewController as? ViewController {
                    return mainVC
                }
            }
        }
        
        // 3. tab bar에서 찾기
        if let tabBarController = self.tabBarController {
            for viewController in tabBarController.viewControllers ?? [] {
                if let mainVC = viewController as? ViewController {
                    return mainVC
                }
                if let navController = viewController as? UINavigationController {
                    for vc in navController.viewControllers {
                        if let mainVC = vc as? ViewController {
                            return mainVC
                        }
                    }
                }
            }
        }
        
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
        let recentPresetsKey = "recent_presets"
        guard let data = UserDefaults.standard.data(forKey: recentPresetsKey),
              let recentPresets = try? JSONDecoder().decode([SoundPreset].self, from: data) else {
            return []
        }
        return recentPresets
    }
}
