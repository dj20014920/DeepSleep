import UIKit
import SwiftUI
import NaturalLanguage

/// 📝 피드백 수집 전담 뷰 컨트롤러
/// 프리셋 적용 후 자동으로 표시되어 사용자 피드백을 수집
@available(iOS 17.0, *)
class FeedbackCollectionViewController: UIViewController {
    
    // MARK: - Properties
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var currentPreset: SoundPreset?
    private var harmonyScore: Float = 0.0
    private var soundCombination: [(soundId: String, version: String, volume: Float)] = []
    
    private var feedbackData: FeedbackData = FeedbackData()
    
    // MARK: - UI Components
    private var titleLabel: UILabel!
    private var subtitleLabel: UILabel!
    private var harmonyScoreView: UIView!
    private var scoreLabel: UILabel!
    private var scoreProgressView: UIProgressView!
    
    // 평점 수집
    private var ratingContainer: UIView!
    private var ratingLabel: UILabel!
    private var ratingButtons: [UIButton] = []
    private var ratingSlider: UISlider!
    private var ratingValueLabel: UILabel!
    
    // 자연어 피드백
    private var naturalFeedbackContainer: UIView!
    private var naturalFeedbackLabel: UILabel!
    private var naturalFeedbackTextView: UITextView!
    private var quickResponseButtons: [UIButton] = []
    
    // 음원 조합 피드백
    private var combinationFeedbackContainer: UIView!
    private var combinationLabel: UILabel!
    private var soundPreferenceButtons: [UIButton] = []
    
    // 선호하지 않는 음원 설정
    private var dislikedSoundsContainer: UIView!
    private var dislikedLabel: UILabel!
    private var dislikedSoundsTableView: UITableView!
    
    // 하단 버튼들
    private var actionButtonsContainer: UIView!
    private var submitButton: UIButton!
    private var skipButton: UIButton!
    private var showVisualizationButton: UIButton!
    
    // MARK: - Data Models
    
    struct FeedbackData {
        var numericRating: Float = 0.0
        var naturalLanguageFeedback: String = ""
        var preferredSounds: [String] = []
        var dislikedSounds: [String] = []
        var quickResponse: String = ""
        var soundCombinationRating: [String: Float] = [:]
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        calculateHarmonyScore()
        configureFeedbackCollection()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 자동으로 5초 후에 표시 (프리셋 적용 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.showFeedbackRequest()
        }
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // 스크롤뷰 설정
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        setupTitleSection()
        setupHarmonyScoreSection()
        setupRatingSection()
        setupNaturalFeedbackSection()
        setupCombinationFeedbackSection()
        setupDislikedSoundsSection()
        setupActionButtons()
        
        setupConstraints()
    }
    
    private func setupTitleSection() {
        titleLabel = UILabel()
        titleLabel.text = "🎵 프리셋 피드백"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        subtitleLabel = UILabel()
        subtitleLabel.text = "방금 적용된 프리셋은 어떠셨나요?"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)
    }
    
    private func setupHarmonyScoreSection() {
        harmonyScoreView = UIView()
        harmonyScoreView.backgroundColor = UIColor.systemGray6
        harmonyScoreView.layer.cornerRadius = 16
        harmonyScoreView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(harmonyScoreView)
        
        let harmonyTitleLabel = UILabel()
        harmonyTitleLabel.text = "🌈 AI 조화도 분석"
        harmonyTitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        harmonyTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        harmonyScoreView.addSubview(harmonyTitleLabel)
        
        scoreLabel = UILabel()
        scoreLabel.text = "\(Int(harmonyScore))점"
        scoreLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        scoreLabel.textColor = getScoreColor(harmonyScore)
        scoreLabel.textAlignment = .center
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        harmonyScoreView.addSubview(scoreLabel)
        
        let maxScoreLabel = UILabel()
        maxScoreLabel.text = "/ 100점"
        maxScoreLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        maxScoreLabel.textColor = .secondaryLabel
        maxScoreLabel.translatesAutoresizingMaskIntoConstraints = false
        harmonyScoreView.addSubview(maxScoreLabel)
        
        scoreProgressView = UIProgressView(progressViewStyle: .default)
        scoreProgressView.progress = harmonyScore / 100.0
        scoreProgressView.progressTintColor = getScoreColor(harmonyScore)
        scoreProgressView.translatesAutoresizingMaskIntoConstraints = false
        harmonyScoreView.addSubview(scoreProgressView)
        
        // 제약 조건 설정
        NSLayoutConstraint.activate([
            harmonyTitleLabel.topAnchor.constraint(equalTo: harmonyScoreView.topAnchor, constant: 16),
            harmonyTitleLabel.centerXAnchor.constraint(equalTo: harmonyScoreView.centerXAnchor),
            
            scoreLabel.topAnchor.constraint(equalTo: harmonyTitleLabel.bottomAnchor, constant: 12),
            scoreLabel.centerXAnchor.constraint(equalTo: harmonyScoreView.centerXAnchor),
            
            maxScoreLabel.leadingAnchor.constraint(equalTo: scoreLabel.trailingAnchor, constant: 4),
            maxScoreLabel.bottomAnchor.constraint(equalTo: scoreLabel.bottomAnchor),
            
            scoreProgressView.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 12),
            scoreProgressView.leadingAnchor.constraint(equalTo: harmonyScoreView.leadingAnchor, constant: 24),
            scoreProgressView.trailingAnchor.constraint(equalTo: harmonyScoreView.trailingAnchor, constant: -24),
            scoreProgressView.bottomAnchor.constraint(equalTo: harmonyScoreView.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupRatingSection() {
        ratingContainer = UIView()
        ratingContainer.backgroundColor = UIColor.systemGray6
        ratingContainer.layer.cornerRadius = 16
        ratingContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(ratingContainer)
        
        ratingLabel = UILabel()
        ratingLabel.text = "⭐ 100점 만점에 몇 점인가요?"
        ratingLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        ratingLabel.translatesAutoresizingMaskIntoConstraints = false
        ratingContainer.addSubview(ratingLabel)
        
        // 슬라이더 평점
        ratingSlider = UISlider()
        ratingSlider.minimumValue = 0
        ratingSlider.maximumValue = 100
        ratingSlider.value = 50
        ratingSlider.translatesAutoresizingMaskIntoConstraints = false
        ratingSlider.addTarget(self, action: #selector(ratingSliderChanged(_:)), for: .valueChanged)
        ratingContainer.addSubview(ratingSlider)
        
        ratingValueLabel = UILabel()
        ratingValueLabel.text = "50점"
        ratingValueLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        ratingValueLabel.textAlignment = .center
        ratingValueLabel.translatesAutoresizingMaskIntoConstraints = false
        ratingContainer.addSubview(ratingValueLabel)
        
        // 빠른 평점 버튼들
        let quickRatings = ["👎 별로예요", "😐 보통이에요", "👍 좋아요", "🌟 최고예요"]
        let quickRatingStack = UIStackView()
        quickRatingStack.axis = .horizontal
        quickRatingStack.distribution = .fillEqually
        quickRatingStack.spacing = 8
        quickRatingStack.translatesAutoresizingMaskIntoConstraints = false
        ratingContainer.addSubview(quickRatingStack)
        
        for (index, rating) in quickRatings.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(rating, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            button.backgroundColor = UIColor.systemGray5
            button.layer.cornerRadius = 8
            button.tag = index
            button.addTarget(self, action: #selector(quickRatingTapped(_:)), for: .touchUpInside)
            quickRatingStack.addArrangedSubview(button)
            ratingButtons.append(button)
        }
        
        NSLayoutConstraint.activate([
            ratingLabel.topAnchor.constraint(equalTo: ratingContainer.topAnchor, constant: 16),
            ratingLabel.leadingAnchor.constraint(equalTo: ratingContainer.leadingAnchor, constant: 16),
            ratingLabel.trailingAnchor.constraint(equalTo: ratingContainer.trailingAnchor, constant: -16),
            
            ratingSlider.topAnchor.constraint(equalTo: ratingLabel.bottomAnchor, constant: 16),
            ratingSlider.leadingAnchor.constraint(equalTo: ratingContainer.leadingAnchor, constant: 24),
            ratingSlider.trailingAnchor.constraint(equalTo: ratingContainer.trailingAnchor, constant: -24),
            
            ratingValueLabel.topAnchor.constraint(equalTo: ratingSlider.bottomAnchor, constant: 8),
            ratingValueLabel.centerXAnchor.constraint(equalTo: ratingContainer.centerXAnchor),
            
            quickRatingStack.topAnchor.constraint(equalTo: ratingValueLabel.bottomAnchor, constant: 16),
            quickRatingStack.leadingAnchor.constraint(equalTo: ratingContainer.leadingAnchor, constant: 16),
            quickRatingStack.trailingAnchor.constraint(equalTo: ratingContainer.trailingAnchor, constant: -16),
            quickRatingStack.bottomAnchor.constraint(equalTo: ratingContainer.bottomAnchor, constant: -16),
            quickRatingStack.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
    
    private func setupNaturalFeedbackSection() {
        naturalFeedbackContainer = UIView()
        naturalFeedbackContainer.backgroundColor = UIColor.systemGray6
        naturalFeedbackContainer.layer.cornerRadius = 16
        naturalFeedbackContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(naturalFeedbackContainer)
        
        naturalFeedbackLabel = UILabel()
        naturalFeedbackLabel.text = "💬 자세한 의견을 들려주세요 (선택사항)"
        naturalFeedbackLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        naturalFeedbackLabel.translatesAutoresizingMaskIntoConstraints = false
        naturalFeedbackContainer.addSubview(naturalFeedbackLabel)
        
        naturalFeedbackTextView = UITextView()
        naturalFeedbackTextView.font = UIFont.systemFont(ofSize: 16)
        naturalFeedbackTextView.backgroundColor = UIColor.systemBackground
        naturalFeedbackTextView.layer.cornerRadius = 8
        naturalFeedbackTextView.layer.borderColor = UIColor.systemGray4.cgColor
        naturalFeedbackTextView.layer.borderWidth = 1
        naturalFeedbackTextView.text = "예: 파도 소리가 너무 크고, 새소리와 잘 어울리지 않아요"
        naturalFeedbackTextView.textColor = .placeholderText
        naturalFeedbackTextView.delegate = self
        naturalFeedbackTextView.translatesAutoresizingMaskIntoConstraints = false
        naturalFeedbackContainer.addSubview(naturalFeedbackTextView)
        
        NSLayoutConstraint.activate([
            naturalFeedbackLabel.topAnchor.constraint(equalTo: naturalFeedbackContainer.topAnchor, constant: 16),
            naturalFeedbackLabel.leadingAnchor.constraint(equalTo: naturalFeedbackContainer.leadingAnchor, constant: 16),
            naturalFeedbackLabel.trailingAnchor.constraint(equalTo: naturalFeedbackContainer.trailingAnchor, constant: -16),
            
            naturalFeedbackTextView.topAnchor.constraint(equalTo: naturalFeedbackLabel.bottomAnchor, constant: 12),
            naturalFeedbackTextView.leadingAnchor.constraint(equalTo: naturalFeedbackContainer.leadingAnchor, constant: 16),
            naturalFeedbackTextView.trailingAnchor.constraint(equalTo: naturalFeedbackContainer.trailingAnchor, constant: -16),
            naturalFeedbackTextView.bottomAnchor.constraint(equalTo: naturalFeedbackContainer.bottomAnchor, constant: -16),
            naturalFeedbackTextView.heightAnchor.constraint(equalToConstant: 80)
        ])
    }
    
    private func setupCombinationFeedbackSection() {
        combinationFeedbackContainer = UIView()
        combinationFeedbackContainer.backgroundColor = UIColor.systemGray6
        combinationFeedbackContainer.layer.cornerRadius = 16
        combinationFeedbackContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(combinationFeedbackContainer)
        
        combinationLabel = UILabel()
        combinationLabel.text = "🎵 어떤 음원 조합이 좋았나요?"
        combinationLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        combinationLabel.translatesAutoresizingMaskIntoConstraints = false
        combinationFeedbackContainer.addSubview(combinationLabel)
        
        // 현재 재생 중인 음원들을 기반으로 버튼 생성
        let combinationStack = UIStackView()
        combinationStack.axis = .vertical
        combinationStack.spacing = 8
        combinationStack.translatesAutoresizingMaskIntoConstraints = false
        combinationFeedbackContainer.addSubview(combinationStack)
        
        // 예시 조합들
        let combinations = ["🌊 파도 + 🐦 새소리", "🌧️ 비 + ⛈️ 천둥", "🔥 모닥불 + 🌿 숲속"]
        for combination in combinations {
            let button = UIButton(type: .system)
            button.setTitle(combination, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            button.backgroundColor = UIColor.systemBackground
            button.layer.cornerRadius = 8
            button.layer.borderColor = UIColor.systemBlue.cgColor
            button.layer.borderWidth = 1
            button.addTarget(self, action: #selector(combinationButtonTapped(_:)), for: .touchUpInside)
            combinationStack.addArrangedSubview(button)
            soundPreferenceButtons.append(button)
            
            NSLayoutConstraint.activate([
                button.heightAnchor.constraint(equalToConstant: 44)
            ])
        }
        
        NSLayoutConstraint.activate([
            combinationLabel.topAnchor.constraint(equalTo: combinationFeedbackContainer.topAnchor, constant: 16),
            combinationLabel.leadingAnchor.constraint(equalTo: combinationFeedbackContainer.leadingAnchor, constant: 16),
            combinationLabel.trailingAnchor.constraint(equalTo: combinationFeedbackContainer.trailingAnchor, constant: -16),
            
            combinationStack.topAnchor.constraint(equalTo: combinationLabel.bottomAnchor, constant: 12),
            combinationStack.leadingAnchor.constraint(equalTo: combinationFeedbackContainer.leadingAnchor, constant: 16),
            combinationStack.trailingAnchor.constraint(equalTo: combinationFeedbackContainer.trailingAnchor, constant: -16),
            combinationStack.bottomAnchor.constraint(equalTo: combinationFeedbackContainer.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupDislikedSoundsSection() {
        dislikedSoundsContainer = UIView()
        dislikedSoundsContainer.backgroundColor = UIColor.systemGray6
        dislikedSoundsContainer.layer.cornerRadius = 16
        dislikedSoundsContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dislikedSoundsContainer)
        
        dislikedLabel = UILabel()
        dislikedLabel.text = "❌ 선호하지 않는 음원 설정"
        dislikedLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        dislikedLabel.translatesAutoresizingMaskIntoConstraints = false
        dislikedSoundsContainer.addSubview(dislikedLabel)
        
        let infoLabel = UILabel()
        infoLabel.text = "체크된 음원은 향후 프리셋에서 제외됩니다"
        infoLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        infoLabel.textColor = .secondaryLabel
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        dislikedSoundsContainer.addSubview(infoLabel)
        
        // 현재 음원들을 체크박스로 표시
        let soundsStack = UIStackView()
        soundsStack.axis = .vertical
        soundsStack.spacing = 8
        soundsStack.translatesAutoresizingMaskIntoConstraints = false
        dislikedSoundsContainer.addSubview(soundsStack)
        
        let availableSounds = ["🌊 파도", "🐦 새소리", "🌧️ 비", "⛈️ 천둥", "🔥 모닥불", "🌿 숲속", "🎵 우주", "🌙 밤"]
        for sound in availableSounds {
            let checkboxView = createCheckboxView(title: sound)
            soundsStack.addArrangedSubview(checkboxView)
        }
        
        NSLayoutConstraint.activate([
            dislikedLabel.topAnchor.constraint(equalTo: dislikedSoundsContainer.topAnchor, constant: 16),
            dislikedLabel.leadingAnchor.constraint(equalTo: dislikedSoundsContainer.leadingAnchor, constant: 16),
            dislikedLabel.trailingAnchor.constraint(equalTo: dislikedSoundsContainer.trailingAnchor, constant: -16),
            
            infoLabel.topAnchor.constraint(equalTo: dislikedLabel.bottomAnchor, constant: 4),
            infoLabel.leadingAnchor.constraint(equalTo: dislikedSoundsContainer.leadingAnchor, constant: 16),
            infoLabel.trailingAnchor.constraint(equalTo: dislikedSoundsContainer.trailingAnchor, constant: -16),
            
            soundsStack.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 12),
            soundsStack.leadingAnchor.constraint(equalTo: dislikedSoundsContainer.leadingAnchor, constant: 16),
            soundsStack.trailingAnchor.constraint(equalTo: dislikedSoundsContainer.trailingAnchor, constant: -16),
            soundsStack.bottomAnchor.constraint(equalTo: dislikedSoundsContainer.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupActionButtons() {
        actionButtonsContainer = UIView()
        actionButtonsContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(actionButtonsContainer)
        
        submitButton = UIButton(type: .system)
        submitButton.setTitle("✅ 피드백 제출", for: .normal)
        submitButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        submitButton.backgroundColor = UIColor.systemBlue
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.layer.cornerRadius = 12
        submitButton.addTarget(self, action: #selector(submitFeedback), for: .touchUpInside)
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        actionButtonsContainer.addSubview(submitButton)
        
        skipButton = UIButton(type: .system)
        skipButton.setTitle("나중에", for: .normal)
        skipButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        skipButton.setTitleColor(.secondaryLabel, for: .normal)
        skipButton.addTarget(self, action: #selector(skipFeedback), for: .touchUpInside)
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        actionButtonsContainer.addSubview(skipButton)
        
        showVisualizationButton = UIButton(type: .system)
        showVisualizationButton.setTitle("📊 조화도 분석 보기", for: .normal)
        showVisualizationButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        showVisualizationButton.backgroundColor = UIColor.systemPurple
        showVisualizationButton.setTitleColor(.white, for: .normal)
        showVisualizationButton.layer.cornerRadius = 10
        showVisualizationButton.addTarget(self, action: #selector(showHarmonyVisualization), for: .touchUpInside)
        showVisualizationButton.translatesAutoresizingMaskIntoConstraints = false
        actionButtonsContainer.addSubview(showVisualizationButton)
        
        NSLayoutConstraint.activate([
            submitButton.topAnchor.constraint(equalTo: actionButtonsContainer.topAnchor),
            submitButton.leadingAnchor.constraint(equalTo: actionButtonsContainer.leadingAnchor),
            submitButton.trailingAnchor.constraint(equalTo: actionButtonsContainer.trailingAnchor),
            submitButton.heightAnchor.constraint(equalToConstant: 50),
            
            showVisualizationButton.topAnchor.constraint(equalTo: submitButton.bottomAnchor, constant: 12),
            showVisualizationButton.leadingAnchor.constraint(equalTo: actionButtonsContainer.leadingAnchor),
            showVisualizationButton.trailingAnchor.constraint(equalTo: actionButtonsContainer.trailingAnchor),
            showVisualizationButton.heightAnchor.constraint(equalToConstant: 44),
            
            skipButton.topAnchor.constraint(equalTo: showVisualizationButton.bottomAnchor, constant: 8),
            skipButton.centerXAnchor.constraint(equalTo: actionButtonsContainer.centerXAnchor),
            skipButton.bottomAnchor.constraint(equalTo: actionButtonsContainer.bottomAnchor),
            skipButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            harmonyScoreView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            harmonyScoreView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            harmonyScoreView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            ratingContainer.topAnchor.constraint(equalTo: harmonyScoreView.bottomAnchor, constant: 20),
            ratingContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            ratingContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            naturalFeedbackContainer.topAnchor.constraint(equalTo: ratingContainer.bottomAnchor, constant: 20),
            naturalFeedbackContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            naturalFeedbackContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            combinationFeedbackContainer.topAnchor.constraint(equalTo: naturalFeedbackContainer.bottomAnchor, constant: 20),
            combinationFeedbackContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            combinationFeedbackContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            dislikedSoundsContainer.topAnchor.constraint(equalTo: combinationFeedbackContainer.bottomAnchor, constant: 20),
            dislikedSoundsContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            dislikedSoundsContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            actionButtonsContainer.topAnchor.constraint(equalTo: dislikedSoundsContainer.bottomAnchor, constant: 24),
            actionButtonsContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            actionButtonsContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            actionButtonsContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }
    
    // MARK: - Helper Methods
    
    private func createCheckboxView(title: String) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let checkbox = UIButton(type: .system)
        checkbox.setImage(UIImage(systemName: "square"), for: .normal)
        checkbox.setImage(UIImage(systemName: "checkmark.square.fill"), for: .selected)
        checkbox.tintColor = .systemBlue
        checkbox.addTarget(self, action: #selector(checkboxTapped(_:)), for: .touchUpInside)
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(checkbox)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            checkbox.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            checkbox.widthAnchor.constraint(equalToConstant: 24),
            checkbox.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            containerView.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        return containerView
    }
    
    private func getScoreColor(_ score: Float) -> UIColor {
        switch score {
        case 0..<50:
            return .systemRed
        case 50..<70:
            return .systemOrange
        case 70..<85:
            return .systemYellow
        default:
            return .systemGreen
        }
    }
    
    private func calculateHarmonyScore() {
        Task {
            if #available(iOS 17.0, *) {
                harmonyScore = await PersonalizedHarmonyLearner.shared.predictHarmonyScore(for: soundCombination)
                
                await MainActor.run {
                    scoreLabel.text = "\(Int(harmonyScore))점"
                    scoreLabel.textColor = getScoreColor(harmonyScore)
                    scoreProgressView.progress = harmonyScore / 100.0
                    scoreProgressView.progressTintColor = getScoreColor(harmonyScore)
                }
            } else {
                harmonyScore = Float.random(in: 60...90)
            }
        }
    }
    
    private func configureFeedbackCollection() {
        // 현재 재생 중인 음원 조합 가져오기
        // TODO: SoundManager에서 현재 조합 가져오기
        soundCombination = [
            (soundId: "wave", version: "basic", volume: 0.8),
            (soundId: "bird", version: "forest", volume: 0.6)
        ]
    }
    
    private func showFeedbackRequest() {
        // 애니메이션과 함께 표시
        view.alpha = 0
        view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [], animations: {
            self.view.alpha = 1
            self.view.transform = .identity
        })
        
        // 햅틱 피드백
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)
    }
    
    // MARK: - Actions
    
    @objc private func ratingSliderChanged(_ slider: UISlider) {
        let value = Int(slider.value)
        ratingValueLabel.text = "\(value)점"
        ratingValueLabel.textColor = getScoreColor(slider.value)
        feedbackData.numericRating = slider.value / 100.0
        
        // 햅틱 피드백
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    @objc private func quickRatingTapped(_ button: UIButton) {
        // 모든 버튼 초기화
        ratingButtons.forEach { $0.backgroundColor = UIColor.systemGray5 }
        
        // 선택된 버튼 강조
        button.backgroundColor = UIColor.systemBlue
        
        // 평점 설정
        let ratings: [Float] = [20, 50, 80, 95]
        let rating = ratings[button.tag]
        
        ratingSlider.value = rating
        ratingValueLabel.text = "\(Int(rating))점"
        ratingValueLabel.textColor = getScoreColor(rating)
        feedbackData.numericRating = rating / 100.0
        feedbackData.quickResponse = button.titleLabel?.text ?? ""
        
        // 햅틱 피드백
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    @objc private func combinationButtonTapped(_ button: UIButton) {
        button.isSelected.toggle()
        
        if button.isSelected {
            button.backgroundColor = UIColor.systemBlue
            button.setTitleColor(.white, for: .normal)
            feedbackData.preferredSounds.append(button.titleLabel?.text ?? "")
        } else {
            button.backgroundColor = UIColor.systemBackground
            button.setTitleColor(.systemBlue, for: .normal)
            if let title = button.titleLabel?.text {
                feedbackData.preferredSounds.removeAll { $0 == title }
            }
        }
        
        // 햅틱 피드백
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    @objc private func checkboxTapped(_ button: UIButton) {
        button.isSelected.toggle()
        
        if button.isSelected {
            feedbackData.dislikedSounds.append(button.accessibilityLabel ?? "")
        } else {
            if let label = button.accessibilityLabel {
                feedbackData.dislikedSounds.removeAll { $0 == label }
            }
        }
        
        // 햅틱 피드백
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    @objc private func submitFeedback() {
        print("📝 [FeedbackCollection] 피드백 제출 시작")
        
        // 자연어 피드백 처리
        processFeedback()
        
        // 피드백 데이터 저장 및 학습
        saveFeedbackAndLearn()
        
        // 성공 메시지 표시
        showSuccessMessage()
        
        // 뷰 닫기
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.dismiss(animated: true)
        }
    }
    
    @objc private func skipFeedback() {
        dismiss(animated: true)
    }
    
    @objc private func showHarmonyVisualization() {
        // 조화도 시각화 화면으로 이동
        if #available(iOS 17.0, *) {
            let harmonyVC = HarmonyVisualizationViewController()
            harmonyVC.modalPresentationStyle = .fullScreen
            present(harmonyVC, animated: true)
        }
    }
    
    // MARK: - Feedback Processing
    
    private func processFeedback() {
        // 자연어 피드백 분석
        if !naturalFeedbackTextView.text.isEmpty && naturalFeedbackTextView.textColor != .placeholderText {
            feedbackData.naturalLanguageFeedback = naturalFeedbackTextView.text
            analyzeNaturalLanguageFeedback(naturalFeedbackTextView.text)
        }
    }
    
    private func analyzeNaturalLanguageFeedback(_ text: String) {
        print("🔍 [FeedbackCollection] 자연어 피드백 분석: \(text)")
        
        // NaturalLanguage 프레임워크로 감정 분석
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        
        let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        
        if let sentimentScore = sentiment?.rawValue, let score = Double(sentimentScore) {
            // 감정 점수를 평점으로 변환 (-1.0 ~ 1.0 → 0 ~ 100)
            let normalizedScore = (score + 1.0) * 50
            feedbackData.numericRating = max(feedbackData.numericRating, Float(normalizedScore) / 100.0)
            print("💭 [FeedbackCollection] 감정 분석 점수: \(score) → \(normalizedScore)점")
        }
        
        // 키워드 기반 분석
        let lowercaseText = text.lowercased()
        let positiveKeywords = ["좋", "최고", "완벽", "만족", "편안", "좋아"]
        let negativeKeywords = ["별로", "나쁘", "시끄럽", "불편", "안좋", "싫"]
        
        let positiveCount = positiveKeywords.reduce(0) { count, keyword in
            count + text.components(separatedBy: keyword).count - 1
        }
        
        let negativeCount = negativeKeywords.reduce(0) { count, keyword in
            count + text.components(separatedBy: keyword).count - 1
        }
        
        if positiveCount > negativeCount {
            feedbackData.numericRating = max(feedbackData.numericRating, 0.7)
        } else if negativeCount > positiveCount {
            feedbackData.numericRating = min(feedbackData.numericRating, 0.4)
        }
    }
    
    private func saveFeedbackAndLearn() {
        // 기본 평점 설정: numericRating이 0 이하일 경우 기본값 할당
        if feedbackData.numericRating <= 0 {
            feedbackData.numericRating = 0.5 // 기본값
        }
        
        print("💾 [FeedbackCollection] 학습 데이터 저장 시작")
        
        Task {
            if #available(iOS 17.0, *) {
                let contextualFactors: [String: Any] = [
                    "timeOfDay": getCurrentTimeOfDayFactor(),
                    "quickResponse": feedbackData.quickResponse,
                    "preferredSounds": feedbackData.preferredSounds,
                    "dislikedSounds": feedbackData.dislikedSounds,
                    "naturalFeedback": feedbackData.naturalLanguageFeedback
                ]
                
                await PersonalizedHarmonyLearner.shared.learnFromFeedback(
                    soundCombination: soundCombination,
                    userRating: feedbackData.numericRating,
                    contextualFactors: contextualFactors,
                    feedbackType: .explicit
                )
                
                print("✅ [FeedbackCollection] 학습 완료")
            }
        }
    }
    
    private func getCurrentTimeOfDayFactor() -> Float {
        let hour = Calendar.current.component(.hour, from: Date())
        return Float(hour) / 24.0
    }
    
    private func showSuccessMessage() {
        let alertController = UIAlertController(
            title: "✅ 피드백 감사합니다!",
            message: "소중한 의견이 AI 학습에 반영되어 더 나은 추천을 제공할게요.",
            preferredStyle: .alert
        )
        
        present(alertController, animated: true)
        
        // 자동으로 1.5초 후 닫기
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alertController.dismiss(animated: true)
        }
    }
}

// MARK: - UITextViewDelegate

@available(iOS 17.0, *)
extension FeedbackCollectionViewController: UITextViewDelegate {
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == .placeholderText {
            textView.text = ""
            textView.textColor = .label
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "예: 파도 소리가 너무 크고, 새소리와 잘 어울리지 않아요"
            textView.textColor = .placeholderText
        }
    }
} 
