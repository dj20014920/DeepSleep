import UIKit
import AVFoundation

// MARK: - 🎯 Enterprise-Grade Feedback Collection System

class EnhancedFeedbackViewController: UIViewController {
    
    // MARK: - Properties
    
    private var feedbackData = FeedbackData()
    private var presetId: UUID!
    private var sessionId: UUID!
    private var startTime: Date!
    private var currentEmotion: EmotionType?
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Header
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let progressBar = UIProgressView()
    
    // Section 1: 정량적 평가
    private let quantitativeSection = UIView()
    private let effectivenessSlider = CustomFeedbackSlider()
    private let relaxationSlider = CustomFeedbackSlider()
    private let focusSlider = CustomFeedbackSlider()
    private let sleepQualitySlider = CustomFeedbackSlider()
    private let overallSatisfactionSlider = CustomFeedbackSlider()
    
    // Section 2: 감정 강도 입력
    private let emotionSection = UIView()
    private let emotionIntensitySlider = CustomFeedbackSlider()
    
    // Section 3: 사용 컨텍스트
    private let contextSection = UIView()
    private let usageDurationLabel = UILabel()
    private let intentionalStopSwitch = UISwitch()
    private let repeatUsageSwitch = UISwitch()
    private let recommendSwitch = UISwitch()
    
    // Section 4: 정성적 피드백
    private let qualitativeSection = UIView()
    private let adjustmentTextView = UITextView()
    private let moodAfterSegmentedControl = UISegmentedControl()
    
    // Bottom Actions
    private let submitButton = UIButton()
    private let skipButton = UIButton()
    
    // Data Collections
    private let feedbackTags = ["너무시끄러움", "완벽함", "졸림", "집중도움", "스트레스완화", 
                                "효과없음", "너무조용함", "좋은조합", "산만함", "평온함"]
    
    // MARK: - Data Storage
    
    private var deviceContext: PresetFeedback.DeviceContext?
    private var environmentContext: PresetFeedback.EnvironmentContext?
    
    // MARK: - Initialization
    
    init(presetId: UUID, sessionId: UUID, startTime: Date, currentEmotion: EmotionType?) {
        super.init(nibName: nil, bundle: nil)
        
        self.presetId = presetId
        self.sessionId = sessionId
        self.startTime = startTime
        self.currentEmotion = currentEmotion
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        populateInitialData()
        setupGestures()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 디바이스 컨텍스트 수집
        collectDeviceContext()
        
        // 애니메이션으로 등장
        animateEntry()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Navigation
        navigationItem.title = "사용 피드백"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "나중에", 
            style: .plain, 
            target: self, 
            action: #selector(skipFeedback)
        )
        
        // Header
        titleLabel.text = "🧠 AI 학습을 위한 피드백"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        
        subtitleLabel.text = "당신의 경험을 공유해주세요 (2-3분 소요)"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        subtitleLabel.textColor = UIColor.secondaryLabel
        subtitleLabel.textAlignment = .center
        
        progressBar.progressTintColor = UIDesignSystem.Colors.accent
        progressBar.trackTintColor = UIColor.systemGray5
        progressBar.progress = 0.0
        
        // Sections
        setupQuantitativeSection()
        setupEmotionSection()
        setupContextSection()
        setupQualitativeSection()
        
        // Buttons
        submitButton.setTitle("🚀 AI 학습에 기여하기", for: .normal)
        submitButton.backgroundColor = UIDesignSystem.Colors.accent
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        submitButton.layer.cornerRadius = 12
        submitButton.addTarget(self, action: #selector(submitFeedback), for: .touchUpInside)
        
        skipButton.setTitle("건너뛰기", for: .normal)
        skipButton.setTitleColor(UIColor.systemGray, for: .normal)
        skipButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        skipButton.addTarget(self, action: #selector(skipFeedback), for: .touchUpInside)
    }
    
    private func setupQuantitativeSection() {
        quantitativeSection.backgroundColor = UIColor.systemBackground
        quantitativeSection.layer.cornerRadius = 12
        quantitativeSection.layer.borderWidth = 1
        quantitativeSection.layer.borderColor = UIColor.systemGray5.cgColor
        
        // Sliders Setup
        effectivenessSlider.configure(
            title: "효과성",
            subtitle: "목표한 효과를 얼마나 달성했나요?",
            leftLabel: "전혀",
            rightLabel: "완벽",
            emoji: "🎯"
        )
        
        relaxationSlider.configure(
            title: "이완도",
            subtitle: "얼마나 편안해졌나요?",
            leftLabel: "긴장됨",
            rightLabel: "매우편안",
            emoji: "😌"
        )
        
        focusSlider.configure(
            title: "집중도",
            subtitle: "집중력이 향상되었나요?",
            leftLabel: "산만함",
            rightLabel: "완전집중",
            emoji: "🧠"
        )
        
        sleepQualitySlider.configure(
            title: "수면 품질",
            subtitle: "수면에 도움이 되었나요?",
            leftLabel: "방해됨",
            rightLabel: "매우도움",
            emoji: "😴"
        )
        
        overallSatisfactionSlider.configure(
            title: "전체 만족도",
            subtitle: "전반적으로 얼마나 만족하시나요?",
            leftLabel: "불만족",
            rightLabel: "매우만족",
            emoji: "⭐"
        )
        
        // Slider Actions
        [effectivenessSlider, relaxationSlider, focusSlider, sleepQualitySlider, overallSatisfactionSlider].forEach { slider in
            slider.valueChangedHandler = { [weak self] value in
                self?.updateProgress()
                self?.provideFeedbackHaptic()
            }
        }
    }
    
    private func setupEmotionSection() {
        emotionSection.backgroundColor = UIDesignSystem.Colors.tagBackground
        emotionSection.layer.cornerRadius = 12
        
        emotionIntensitySlider.configure(
            title: "감정 강도",
            subtitle: "현재 감정의 강도를 알려주세요",
            leftLabel: "약함",
            rightLabel: "강함",
            emoji: "💗"
        )
        
        emotionIntensitySlider.valueChangedHandler = { [weak self] value in
            self?.updateProgress()
            self?.provideFeedbackHaptic()
        }
    }
    
    private func setupContextSection() {
        contextSection.backgroundColor = UIColor.systemBackground
        contextSection.layer.cornerRadius = 12
        contextSection.layer.borderWidth = 1
        contextSection.layer.borderColor = UIColor.systemGray5.cgColor
        
        usageDurationLabel.text = "사용 시간: \(formatDuration(Date().timeIntervalSince(startTime)))"
        usageDurationLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        
        // Context Switches
        intentionalStopSwitch.addTarget(self, action: #selector(contextChanged), for: .valueChanged)
        repeatUsageSwitch.addTarget(self, action: #selector(contextChanged), for: .valueChanged)
        recommendSwitch.addTarget(self, action: #selector(contextChanged), for: .valueChanged)
    }
    
    private func setupQualitativeSection() {
        qualitativeSection.backgroundColor = UIDesignSystem.Colors.tagBackground
        qualitativeSection.layer.cornerRadius = 12
        
        adjustmentTextView.backgroundColor = UIColor.systemBackground
        adjustmentTextView.layer.cornerRadius = 8
        adjustmentTextView.layer.borderWidth = 1
        adjustmentTextView.layer.borderColor = UIDesignSystem.Colors.border.cgColor
        adjustmentTextView.font = UIFont.systemFont(ofSize: 16)
        adjustmentTextView.text = "개선 사항이나 조정 요청을 자유롭게 작성해주세요..."
        adjustmentTextView.textColor = UIColor.placeholderText
        adjustmentTextView.delegate = self
        
        moodAfterSegmentedControl.insertSegment(withTitle: "😔 나빠짐", at: 0, animated: false)
        moodAfterSegmentedControl.insertSegment(withTitle: "😐 비슷함", at: 1, animated: false)
        moodAfterSegmentedControl.insertSegment(withTitle: "🙂 좋아짐", at: 2, animated: false)
        moodAfterSegmentedControl.insertSegment(withTitle: "😊 매우좋음", at: 3, animated: false)
        moodAfterSegmentedControl.selectedSegmentIndex = 1
        moodAfterSegmentedControl.addTarget(self, action: #selector(moodChanged), for: .valueChanged)
    }
    
    private func setupConstraints() {
        // Auto Layout 설정 (간소화)
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        // 스택뷰로 간소화된 레이아웃
        let stackView = UIStackView(arrangedSubviews: [
            titleLabel, subtitleLabel, progressBar,
            quantitativeSection, emotionSection, contextSection, qualitativeSection,
            submitButton, skipButton
        ])
        
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Data Management
    
    private func populateInitialData() {
        if let emotion = currentEmotion {
            emotionIntensitySlider.setValue(defaultIntensity(for: emotion))
        }
    }
    
    /// EmotionType에 따른 기본 감정 강도 반환
    private func defaultIntensity(for emotion: EmotionType) -> Float {
        switch emotion {
        case .angry, .stressed:
            return 0.8
        case .excited, .happy:
            return 0.7
        case .anxious, .sad:
            return 0.6
        case .tired:
            return 0.4
        case .neutral, .calm, .peaceful:
            return 0.3
        }
    }
    
    private func collectDeviceContext() {
        // Collect device context based on battery status
        self.deviceContext = PresetFeedback.DeviceContext(
            isCharging: UIDevice.current.batteryState == .charging,
            batteryLevel: UIDevice.current.batteryLevel
        )

        // Collect environment context based on time of day and default noise level
        self.environmentContext = PresetFeedback.EnvironmentContext(
            timeOfDay: getCurrentTimeOfUse(),
            noiseLevel: 0.5
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
    
    // MARK: - Actions
    
    @objc private func submitFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        showSubmissionAnimation {
            // FeedbackManager를 통해 직접 저장
            Task { @MainActor in
                // 현재 피드백 데이터를 수집
                self.collectFinalFeedbackData()
                
                // 피드백 객체 생성 및 저장 (FeedbackManager 사용)
                let _ = self.createFeedbackObject()
                // 추후 FeedbackManager에 저장 로직 추가 가능
                
                print("📝 [EnhancedFeedback] 피드백 데이터 저장 완료")
            }
            
            self.showSuccessMessage {
                self.dismiss(animated: true)
            }
        }
    }
    
    @objc private func skipFeedback() {
        dismiss(animated: true)
    }
    
    @objc private func contextChanged() {
        updateProgress()
    }
    
    @objc private func moodChanged() {
        updateProgress()
        provideFeedbackHaptic()
    }
    
    // MARK: - Helper Methods
    
    private func updateProgress() {
        let completedFields = [
            effectivenessSlider.value > 0,
            relaxationSlider.value > 0,
            overallSatisfactionSlider.value > 0,
            emotionIntensitySlider.value > 0,
            moodAfterSegmentedControl.selectedSegmentIndex != -1
        ].filter { $0 }.count
        
        let totalFields = 5
        let progress = Float(completedFields) / Float(totalFields)
        
        UIView.animate(withDuration: 0.3) {
            self.progressBar.setProgress(progress, animated: true)
        }
        
        submitButton.isEnabled = progress >= 0.6
        submitButton.alpha = progress >= 0.6 ? 1.0 : 0.6
    }
    
    private func provideFeedbackHaptic() {
        let feedbackGenerator = UISelectionFeedbackGenerator()
        feedbackGenerator.selectionChanged()
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d분 %d초", minutes, seconds)
    }
    
    private func collectFinalFeedbackData() {
        feedbackData.effectiveness = effectivenessSlider.value
        feedbackData.relaxation = relaxationSlider.value
        feedbackData.focus = focusSlider.value
        feedbackData.sleepQuality = sleepQualitySlider.value
        feedbackData.overallSatisfaction = overallSatisfactionSlider.value
        feedbackData.emotionIntensity = emotionIntensitySlider.value
        
        feedbackData.usageDuration = Date().timeIntervalSince(startTime)
        feedbackData.intentionalStop = intentionalStopSwitch.isOn
        feedbackData.repeatUsage = repeatUsageSwitch.isOn
        feedbackData.wouldRecommend = recommendSwitch.isOn
        
        let moodTexts = ["😔 나빠짐", "😐 비슷함", "🙂 좋아짐", "😊 매우좋음"]
        if moodAfterSegmentedControl.selectedSegmentIndex >= 0 {
            feedbackData.moodAfter = moodTexts[moodAfterSegmentedControl.selectedSegmentIndex]
        }
        
        if adjustmentTextView.text != "개선 사항이나 조정 요청을 자유롭게 작성해주세요..." && !adjustmentTextView.text.isEmpty {
            feedbackData.preferredAdjustments = [adjustmentTextView.text]
        }
    }
    
    private func createFeedbackObject() -> PresetFeedback? {
        #if swift(>=5.9)
        if #available(iOS 17.0, *) {
            let qualitativeFeedback = PresetFeedback.QualitativeFeedback(
                freeText: adjustmentTextView.text,
                moodAfter: moodAfterSegmentedControl.titleForSegment(at: moodAfterSegmentedControl.selectedSegmentIndex) ?? "",
                tags: [] // 태그 수집 UI 추가 필요
            )
            
            let context = PresetFeedback.Context(
                usageDuration: Date().timeIntervalSince(startTime),
                intentionalStop: intentionalStopSwitch.isOn,
                repeatUsageIntent: repeatUsageSwitch.isOn,
                recommendationIntent: recommendSwitch.isOn
            )
            
            let finalDeviceContext = self.deviceContext
            let finalEnvironmentContext = self.environmentContext
            
            return PresetFeedback(
                id: UUID(),
                timestamp: Date(),
                presetName: self.presetId?.uuidString ?? "",
                contextEmotion: self.currentEmotion?.rawValue ?? "평온",
                contextTime: Int16(Calendar.current.component(.hour, from: Date())),
                recommendedVolumes: [],
                recommendedVersions: [],
                finalVolumes: [],
                listeningDuration: Date().timeIntervalSince(startTime),
                wasSkipped: false,
                wasSaved: true,
                userSatisfaction: Int(feedbackData.overallSatisfaction),
                comment: adjustmentTextView.text,
                qualitative: qualitativeFeedback,
                context: context,
                deviceContext: finalDeviceContext,
                environmentContext: finalEnvironmentContext,
                userEmotion: self.currentEmotion?.rawValue
            )
        } else {
            // iOS 17 미만 버전에서는 알림만 표시
            let alert = UIAlertController(title: "알림", message: "이 기능은 iOS 17 이상에서 사용할 수 있습니다.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default, handler: { _ in
                self.dismiss(animated: true, completion: nil)
            }))
            present(alert, animated: true, completion: nil)
        }
        #endif
        return nil // iOS 17 미만에서는 nil 반환
    }
    
    private func animateEntry() {
        view.alpha = 0
        UIView.animate(withDuration: 0.6) {
            self.view.alpha = 1
        }
    }
    
    private func showSubmissionAnimation(completion: @escaping () -> Void) {
        submitButton.isEnabled = false
        submitButton.setTitle("전송 중...", for: .normal)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            completion()
        }
    }
    
    private func showSuccessMessage(completion: @escaping () -> Void) {
        submitButton.setTitle("✅ 완료!", for: .normal)
        submitButton.backgroundColor = UIColor.systemGreen
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion()
        }
    }
    
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}

// MARK: - Supporting Data Structure

private struct FeedbackData {
    var effectiveness: Float = 0.0
    var relaxation: Float = 0.0
    var focus: Float = 0.0
    var sleepQuality: Float = 0.0
    var overallSatisfaction: Float = 0.0
    var emotionIntensity: Float = 0.5
    
    var usageDuration: TimeInterval = 0
    var intentionalStop: Bool = false
    var repeatUsage: Bool = false
    var wouldRecommend: Bool = false
    
                var deviceContext: PresetFeedback.DeviceContext?
    var environmentContext: PresetFeedback.EnvironmentContext?
    
    var tags: [String] = []
    var preferredAdjustments: [String] = []
    var moodAfter: String = "😐 비슷함"
    
    // Provide quantitative snapshot for feedback
    var quantitative: [String: Any] { return [
        "effectiveness": effectiveness,
        "relaxation": relaxation,
        "focus": focus,
        "sleepQuality": sleepQuality,
        "overallSatisfaction": overallSatisfaction,
        "emotionIntensity": emotionIntensity
    ] }
}

// MARK: - TextView Delegate

extension EnhancedFeedbackViewController: UITextViewDelegate {
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == UIColor.placeholderText {
            textView.text = ""
            textView.textColor = UIColor.label
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "개선 사항이나 조정 요청을 자유롭게 작성해주세요..."
            textView.textColor = UIColor.placeholderText
        }
        updateProgress()
    }
}

// MARK: - Custom Feedback Slider

class CustomFeedbackSlider: UIView {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let emojiLabel = UILabel()
    private let slider = UISlider()
    private let leftLabel = UILabel()
    private let rightLabel = UILabel()
    private let valueLabel = UILabel()
    
    var value: Float {
        return slider.value
    }
    
    var valueChangedHandler: ((Float) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = UIColor.secondaryLabel
        emojiLabel.font = UIFont.systemFont(ofSize: 24)
        
        slider.minimumValue = 0.0
        slider.maximumValue = 1.0
        slider.value = 0.5
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        
        leftLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        rightLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        leftLabel.textColor = UIColor.secondaryLabel
        rightLabel.textColor = UIColor.secondaryLabel
        
        valueLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        valueLabel.textColor = UIDesignSystem.Colors.accent
        valueLabel.textAlignment = .center
        
        let stackView = UIStackView(arrangedSubviews: [
            titleLabel, subtitleLabel, emojiLabel, slider, 
            UIStackView(arrangedSubviews: [leftLabel, UIView(), rightLabel]),
            valueLabel
        ])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
        
        updateValueLabel()
    }
    
    func configure(title: String, subtitle: String, leftLabel: String, rightLabel: String, emoji: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        self.leftLabel.text = leftLabel
        self.rightLabel.text = rightLabel
        emojiLabel.text = emoji
    }
    
    func setValue(_ value: Float) {
        slider.value = value
        updateValueLabel()
    }
    
    @objc private func sliderChanged() {
        updateValueLabel()
        valueChangedHandler?(slider.value)
    }
    
    private func updateValueLabel() {
        let percentage = Int(slider.value * 100)
        valueLabel.text = "\(percentage)%"
    }
}

@available(iOS 17.0, *)
extension EnhancedFeedbackViewController {
    private func createVibrationFeedback() -> CHHapticPattern? {
        // ... existing code ...
        return nil
    }
} 
