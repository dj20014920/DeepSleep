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
        let presetName: String
        
        init(volumes: [Float], presetName: String = "맞춤 프리셋") {
            self.volumes = volumes
            self.presetName = presetName
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

    private let inputContainerView = UIView()
    private let inputTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "대화를 입력해보세요..."
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

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
        setupConstraints()
        loadChatHistory()
        setupTableView()
        setupTargets()
        setupInitialMessages()
        setupNotifications()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollToBottom()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup Methods
    private func loadChatHistory() {
        if let saved = UserDefaults.standard.array(forKey: "chatHistory") as? [[String: String]] {
            self.messages = saved.compactMap { ChatMessage.from(dictionary: $0) }
        }
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

    // MARK: - Keyboard Handling
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

    // MARK: - Initial Messages
    private func setupInitialMessages() {
        if let emoji = initialUserText {
            appendChat(.user("선택한 기분: \(emoji)"))
            // 감정에 따른 맞춤 첫 인사
            let greeting = getEmotionalGreeting(for: emoji)
            appendChat(.bot(greeting))
        } else {
            appendChat(.bot("안녕하세요! 😊\n오늘 하루는 어떠셨나요? 마음 편하게 이야기해보세요."))
        }
    }

    // MARK: - Emotional Response
    private func getEmotionalGreeting(for emoji: String) -> String {
        switch emoji {
        case "😢", "😞", "😔":
            return "힘든 하루였나 봐요... 😔\n괜찮아요, 여기서 마음껏 털어놓으세요. 제가 들어드릴게요."
        case "😰", "😱", "😨":
            return "많이 불안하셨겠어요 😰\n깊게 숨을 쉬어보세요. 천천히 이야기해주시면 도움이 될 거예요."
        case "😴", "😪":
            return "많이 피곤하신 것 같네요 😴\n편안한 사운드로 마음을 달래드릴게요."
        case "😊", "😄", "🥰":
            return "좋은 기분이시네요! 😊\n오늘의 기쁜 순간들을 더 들려주세요."
        case "😡", "😤":
            return "화가 많이 나셨나 봐요 😤\n속상한 마음을 충분히 표현해보세요. 들어드릴게요."
        default:
            return "지금 기분을 더 자세히 말해주세요 💝\n어떤 하루를 보내셨는지 궁금해요."
        }
    }

    // MARK: - Preset Recommendation (개선됨)
    @objc private func presetButtonTapped() {
        guard PresetLimitManager.shared.canUseToday() else {
            appendChat(.bot("❌ 오늘 프리셋 추천 횟수를 모두 사용했어요!\n내일 다시 만나요 😊"))
            return
        }

        let recentMessages = messages.suffix(5).compactMap { message in
            switch message {
            case .user(let text): return "사용자: \(text)"
            case .bot(let text): return "AI: \(text)"
            default: return nil
            }
        }.joined(separator: "\n")

        let emotionContext = initialUserText ?? "일반적인 기분"
        
        appendChat(.user("지금 기분에 맞는 사운드 추천해줘! 🎵"))
        appendChat(.bot("AI가 당신의 마음을 읽고 있어요... 🔍\n완벽한 사운드 조합을 찾는 중이에요."))

        // ReplicateChatService의 recommendPreset 사용
        ReplicateChatService.shared.recommendPreset(emotion: "\(emotionContext)\n최근 대화: \(recentMessages)") { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let response = result,
                   let parsed = self.parseRecommendation(from: response) {
                    
                    let presetName = parsed.presetName
                    let encouragingMessage = self.getEncouragingMessage(for: emotionContext)
                    
                    self.appendChat(.presetRecommendation(
                        presetName: presetName,
                        message: "🎵 \(presetName)이 준비되었어요!\n\(encouragingMessage)",
                        apply: {
                            // 사운드 적용
                            SoundManager.shared.applyPreset(volumes: parsed.volumes)
                            
                            // 프리셋 저장 (선택적)
                            self.saveRecommendedPreset(parsed)
                            
                            self.navigationController?.popViewController(animated: true)
                        }
                    ))
                    PresetLimitManager.shared.incrementUsage()
                } else {
                    self.appendChat(.bot("❌ 추천 과정에서 문제가 생겼어요.\n잠시 후 다시 시도해주세요."))
                }
            }
        }
    }

    private func buildEmotionalPrompt(emotion: String, recentChat: String) -> String {
        return """
        당신은 감정을 이해하고 위로해주는 AI 사운드 큐레이터입니다.
        
        현재 사용자 감정: \(emotion)
        최근 대화 내용:
        \(recentChat)
        
        위 정보를 바탕으로 12가지 사운드의 볼륨을 0-100으로 추천해주세요.
        사운드 목록 (순서대로): Rain, Thunder, Ocean, Fire, Steam, WindowRain, Forest, Wind, Night, Lullaby, Fan, WhiteNoise
        
        각 사운드 설명:
        - Rain: 빗소리 (평온, 집중)
        - Thunder: 천둥소리 (강렬함, 드라마틱)
        - Ocean: 파도소리 (자연, 휴식)
        - Fire: 모닥불소리 (따뜻함, 포근함)
        - Steam: 증기소리 (부드러움)
        - WindowRain: 창가 빗소리 (아늑함)
        - Forest: 숲새소리 (자연, 생동감)
        - Wind: 찬바람소리 (시원함, 청량함)
        - Night: 여름밤소리 (로맨틱, 평화)
        - Lullaby: 자장가 (수면, 위로)
        - Fan: 선풍기소리 (집중, 화이트노이즈)
        - WhiteNoise: 백색소음 (집중, 차단)
        
        응답 형식: [감정에 맞는 프리셋 이름] Rain:80, Thunder:10, Ocean:60, Fire:0, Steam:20, WindowRain:40, Forest:70, Wind:30, Night:50, Lullaby:0, Fan:20, WhiteNoise:30
        
        사용자의 감정에 진심으로 공감하며, 그 감정을 달래거나 증진시킬 수 있는 사운드 조합을 추천해주세요.
        """
    }

    private func getEncouragingMessage(for emotion: String) -> String {
        switch emotion {
        case let e where e.contains("😢") || e.contains("😞"):
            return "이 소리들이 마음을 달래줄 거예요. 천천히 들어보세요 💙"
        case let e where e.contains("😰") || e.contains("😱"):
            return "불안한 마음이 점점 편안해질 거예요. 깊게 숨 쉬어보세요 🌿"
        case let e where e.contains("😴") || e.contains("😪"):
            return "편안한 잠에 빠져보세요. 꿈 속에서도 평온하시길 ✨"
        default:
            return "지금 이 순간을 온전히 느껴보세요 🎶"
        }
    }

    // MARK: - Chat Sending
    @objc private func sendButtonTapped() {
        guard let text = inputTextField.text, !text.isEmpty else { return }
        inputTextField.text = ""
        appendChat(.user(text))
        
        if dailyChatCount >= 50 {
            appendChat(.bot("❌ 오늘의 채팅 횟수를 모두 사용하셨어요.\n내일 다시 만나요! 😊"))
            return
        } else if dailyChatCount == 40 {
            appendChat(.bot("⚠️ 오늘 채팅 횟수가 10회 남았어요.\n소중한 시간이니 천천히 대화해요 💝"))
        }
        
        let isDiary = text.count > 30 || text.contains("오늘") || text.contains("하루")
        let intent = isDiary ? "diary" : "chat"
        
        // 감정 맥락을 포함한 메시지 구성
        let contextualMessage = buildContextualMessage(userText: text, isDiary: isDiary)

        ReplicateChatService.shared.sendPrompt(message: contextualMessage, intent: intent) { [weak self] response in
            DispatchQueue.main.async {
                if let msg = response {
                    self?.appendChat(.bot(msg))
                    
                    // 감정 일기 저장 (선택적)
                    if isDiary {
                        self?.saveEmotionDiary(userMessage: text, aiResponse: msg)
                    }
                } else {
                    self?.appendChat(.bot("❌ 지금 응답을 불러올 수 없어요.\n잠시 후 다시 시도해주세요."))
                }
            }
        }
        incrementDailyChatCount()
    }
    private func saveEmotionDiary(userMessage: String, aiResponse: String) {
        let entry = EmotionDiary(
            date: Date(),
            emotion: initialUserText ?? "😊",
            userMessage: userMessage,
            aiResponse: aiResponse,
            recommendedPreset: nil
        )
        
        EmotionDiaryManager.shared.saveEntry(entry)
        print("감정 일기 저장 완료")
    }
    private func buildChatPrompt(userMessage: String, isDiary: Bool) -> String {
        let basePrompt = """
        당신은 감정을 깊이 이해하고 진심으로 위로해주는 AI 친구입니다.
        사용자의 감정에 공감하고, 따뜻하고 자연스러운 한국어로 대화해주세요.
        
        대화 스타일:
        - 진심어린 공감과 위로
        - 부드럽고 따뜻한 어조
        - 적절한 이모지 사용 (과하지 않게)
        - 사용자의 감정을 인정하고 수용
        - 실용적이면서도 감정적인 조언
        
        사용자 메시지: \(userMessage)
        """
        
        if isDiary {
            return basePrompt + "\n\n이것은 일기 형태의 긴 이야기인 것 같습니다. 충분히 들어주고 깊이 공감해주세요."
        }
        
        return basePrompt
    }

    private func appendChat(_ message: ChatMessage) {
        messages.append(message)
        tableView.reloadData()
        DispatchQueue.main.async {
            self.scrollToBottom()
        }
        saveChatHistory()
    }

    private func saveChatHistory() {
        let dictionaries = messages.map { $0.toDictionary() }
        UserDefaults.standard.set(dictionaries, forKey: "chatHistory")
    }

    // MARK: - Preset Parsing (실제 SoundManager 연동)
    func parseRecommendation(from response: String) -> RecommendationResponse? {
        // [프리셋이름] Rain:80, Wind:60... 형식 파싱
        let pattern = #"\[([^\]]+)\]\s*(.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)) else {
            // 기본 파싱 실패 시 폴백
            return parseBasicFormat(from: response)
        }
        
        let presetName = String(response[Range(match.range(at: 1), in: response)!])
        let valuesString = String(response[Range(match.range(at: 2), in: response)!])
        
        var volumes: [Float] = Array(repeating: 0, count: 12)
        
        // 실제 SoundManager의 사운드 순서에 맞게 매핑
        let soundMapping: [String: Int] = [
            "Rain": 0, "Thunder": 1, "Ocean": 2, "Fire": 3,
            "Steam": 4, "WindowRain": 5, "Forest": 6, "Wind": 7,
            "Night": 8, "Lullaby": 9, "Fan": 10, "WhiteNoise": 11,
            // 추가 매핑 (다양한 표현 허용)
            "Wave": 2, "Bonfire": 3, "ColdWind": 7, "SummerNight": 8,
            "WhiteNoise": 11, "BrownNoise": 11, "PinkNoise": 11
        ]
        
        let pairs = valuesString.components(separatedBy: ",")
        for pair in pairs {
            let components = pair.trimmingCharacters(in: .whitespaces).components(separatedBy: ":")
            if components.count == 2,
               let soundName = components.first?.trimmingCharacters(in: .whitespaces),
               let index = soundMapping[soundName],
               let value = Float(components[1].trimmingCharacters(in: .whitespaces)) {
                volumes[index] = min(100, max(0, value))
            }
        }
        
        return RecommendationResponse(volumes: volumes, presetName: presetName)
    }
    private func getEmotionContext(for emoji: String) -> String {
        switch emoji {
        case "😢", "😞", "😔": return "슬픔, 우울함"
        case "😰", "😱", "😨": return "불안, 걱정"
        case "😴", "😪": return "피곤함, 졸림"
        case "😊", "😄", "🥰": return "기쁨, 행복"
        case "😡", "😤": return "화남, 짜증"
        default: return "일반적인 상태"
        }
    }
    private func parseBasicFormat(from response: String) -> RecommendationResponse? {
        // 기본 포맷이 실패했을 때의 감정별 기본 프리셋
        let emotion = initialUserText ?? "😊"
        
        switch emotion {
        case "😢", "😞", "😔":
            // 슬픔: Rain, Ocean, Forest, Lullaby 중심
            return RecommendationResponse(
                volumes: [60, 10, 70, 0, 0, 20, 80, 30, 25, 60, 20, 40],
                presetName: "위로의 소리"
            )
        case "😰", "😱", "😨":
            // 불안: Rain, WhiteNoise, Forest 중심, Thunder 제거
            return RecommendationResponse(
                volumes: [80, 0, 40, 0, 0, 30, 70, 20, 30, 50, 30, 60],
                presetName: "안정의 소리"
            )
        case "😴", "😪":
            // 피곤함: Lullaby, WhiteNoise, Fan 중심
            return RecommendationResponse(
                volumes: [40, 0, 30, 0, 0, 60, 40, 40, 50, 90, 50, 70],
                presetName: "깊은 잠의 소리"
            )
        case "😊", "😄", "🥰":
            // 기쁨: Forest, Ocean, Rain 중심, 밝은 소리들
            return RecommendationResponse(
                volumes: [50, 10, 50, 20, 20, 20, 70, 40, 40, 40, 20, 30],
                presetName: "기쁨의 소리"
            )
        case "😡", "😤":
            // 화남: Ocean, Wind, Thunder로 감정 해소
            return RecommendationResponse(
                volumes: [70, 30, 60, 10, 0, 40, 50, 60, 30, 30, 40, 50],
                presetName: "마음 달래는 소리"
            )
        default:
            // 기본: 균형잡힌 자연 소리
            return RecommendationResponse(
                volumes: [50, 10, 40, 10, 10, 30, 60, 40, 50, 40, 30, 40],
                presetName: "평온의 소리"
            )
        }
    }

    // MARK: - TableView DataSource
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
    private func saveRecommendedPreset(_ response: RecommendationResponse) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        let presetName = "\(response.presetName) (\(timestamp))"
        
        PresetManager.shared.savePreset(name: presetName, volumes: response.volumes)
        print("프리셋 저장 완료: \(presetName)")
    }
    // MARK: - Helper Methods
    private func buildContextualMessage(userText: String, isDiary: Bool) -> String {
        let emotion = initialUserText ?? "😊"
        let emotionContext = getEmotionContext(for: emotion)
        
        let baseMessage = """
        사용자 감정 상태: \(emotion) (\(emotionContext))
        사용자 메시지: \(userText)
        
        위 내용을 바탕으로 따뜻하고 공감적인 응답을 해주세요.
        """
        
        if isDiary {
            return baseMessage + "\n\n이것은 일기 형태의 긴 이야기입니다. 충분히 들어주고 깊이 공감해주세요."
        }
        
        return baseMessage
    }
    
}

// MARK: - ChatMessage enum (동일)
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

// MARK: - PresetLimitManager (동일)
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

struct EmotionDiary: Codable {
    let date: Date
    let emotion: String
    let userMessage: String
    let aiResponse: String
    let recommendedPreset: String?
}

class EmotionDiaryManager {
    static let shared = EmotionDiaryManager()
    private let key = "emotionDiary"
    
    func saveEntry(_ entry: EmotionDiary) {
        var entries = loadEntries()
        entries.append(entry)
        
        // 최대 100개 항목만 유지
        if entries.count > 100 {
            entries = Array(entries.suffix(100))
        }
        
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func loadEntries() -> [EmotionDiary] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let entries = try? JSONDecoder().decode([EmotionDiary].self, from: data) else {
            return []
        }
        return entries
    }
}
