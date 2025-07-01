import UIKit
import SwiftUI
import Charts
import SwiftData
import Combine

protocol PresetFeedbackDelegate: AnyObject {
    func didSubmitFeedback(satisfaction: Float, comments: String?)
}

/// 🌈 프리셋 조화도 시각화 및 피드백 수집 전담 뷰 컨트롤러
/// 사용자에게 조화 점수, 문제점, 개선 제안을 시각적으로 제시하고 피드백을 수집
@available(iOS 17.0, *)
class HarmonyVisualizationViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, PresetFeedbackDelegate {
    
    // MARK: - Properties
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var harmonyAnalysis: SoundHarmonyAnalyzer.HarmonyAnalysis?
    private var currentPreset: SoundPreset?
    private var soundCombination: [(soundId: String, version: String, volume: Float)] = []
    
    // MARK: - UI Components
    private var scoreCircleView: UIView!
    private var scoreLabel: UILabel!
    private var scoreDetailLabel: UILabel!
    private var conflictsContainer: UIView!
    private var recommendationsContainer: UIView!
    private var feedbackContainer: UIView!
    
    // MARK: - Charts
    private var harmonyTrendChartView: UIHostingController<HarmonyTrendChart>!
    private var conflictRadarChartView: UIHostingController<ConflictRadarChart>!
    private var improvementSuggestionView: UIHostingController<ImprovementSuggestionView>!
    
    // MARK: - Initialization
    
    init(harmonyAnalysis: SoundHarmonyAnalyzer.HarmonyAnalysis? = nil, 
         preset: SoundPreset? = nil,
         soundCombination: [(soundId: String, version: String, volume: Float)] = []) {
        super.init(nibName: nil, bundle: nil)
        self.harmonyAnalysis = harmonyAnalysis
        self.currentPreset = preset
        self.soundCombination = soundCombination
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCharts()
        setupConstraints()
        
        // 분석이 없으면 현재 프리셋으로 분석 수행
        if harmonyAnalysis == nil && !soundCombination.isEmpty {
            performHarmonyAnalysis()
        }
        
        updateUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 피드백 요청 타이밍 설정
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.triggerFeedbackRequest()
        }
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Navigation
        title = "🌈 조화도 분석"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "완료",
            style: .done,
            target: self,
            action: #selector(dismissViewController)
        )
        
        // Scroll View
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        view.addSubview(scrollView)
        
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        setupScoreSection()
        setupConflictsSection()
        setupRecommendationsSection()
        setupFeedbackSection()
    }
    
    private func setupScoreSection() {
        // 조화도 점수 원형 표시
        scoreCircleView = UIView()
        scoreCircleView.translatesAutoresizingMaskIntoConstraints = false
        scoreCircleView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        scoreCircleView.layer.cornerRadius = 75
        scoreCircleView.layer.borderWidth = 5
        scoreCircleView.layer.borderColor = UIColor.systemBlue.cgColor
        contentView.addSubview(scoreCircleView)
        
        scoreLabel = UILabel()
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        scoreLabel.font = .systemFont(ofSize: 36, weight: .bold)
        scoreLabel.textAlignment = .center
        scoreLabel.textColor = UIColor.systemBlue
        scoreLabel.text = "85"
        scoreCircleView.addSubview(scoreLabel)
        
        scoreDetailLabel = UILabel()
        scoreDetailLabel.translatesAutoresizingMaskIntoConstraints = false
        scoreDetailLabel.font = .systemFont(ofSize: 14, weight: .medium)
        scoreDetailLabel.textAlignment = .center
        scoreDetailLabel.textColor = UIColor.secondaryLabel
        scoreDetailLabel.text = "/ 100점"
        scoreCircleView.addSubview(scoreDetailLabel)
    }
    
    private func setupConflictsSection() {
        conflictsContainer = UIView()
        conflictsContainer.translatesAutoresizingMaskIntoConstraints = false
        conflictsContainer.backgroundColor = UIColor.systemBackground
        conflictsContainer.layer.cornerRadius = 12
        conflictsContainer.layer.shadowColor = UIColor.black.cgColor
        conflictsContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
        conflictsContainer.layer.shadowOpacity = 0.1
        conflictsContainer.layer.shadowRadius = 4
        contentView.addSubview(conflictsContainer)
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.text = "⚠️ 발견된 문제점"
        titleLabel.textColor = UIColor.label
        conflictsContainer.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: conflictsContainer.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: conflictsContainer.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: conflictsContainer.trailingAnchor, constant: -16)
        ])
    }
    
    private func setupRecommendationsSection() {
        recommendationsContainer = UIView()
        recommendationsContainer.translatesAutoresizingMaskIntoConstraints = false
        recommendationsContainer.backgroundColor = UIColor.systemBackground
        recommendationsContainer.layer.cornerRadius = 12
        recommendationsContainer.layer.shadowColor = UIColor.black.cgColor
        recommendationsContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
        recommendationsContainer.layer.shadowOpacity = 0.1
        recommendationsContainer.layer.shadowRadius = 4
        contentView.addSubview(recommendationsContainer)
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.text = "✅ 개선 제안"
        titleLabel.textColor = UIColor.label
        recommendationsContainer.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: recommendationsContainer.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: recommendationsContainer.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: recommendationsContainer.trailingAnchor, constant: -16)
        ])
    }
    
    private func setupFeedbackSection() {
        feedbackContainer = UIView()
        feedbackContainer.translatesAutoresizingMaskIntoConstraints = false
        feedbackContainer.backgroundColor = UIColor.systemBackground
        feedbackContainer.layer.cornerRadius = 12
        feedbackContainer.layer.shadowColor = UIColor.black.cgColor
        feedbackContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
        feedbackContainer.layer.shadowOpacity = 0.1
        feedbackContainer.layer.shadowRadius = 4
        contentView.addSubview(feedbackContainer)
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.text = "📝 피드백을 알려주세요"
        titleLabel.textColor = UIColor.label
        feedbackContainer.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: feedbackContainer.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: feedbackContainer.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: feedbackContainer.trailingAnchor, constant: -16)
        ])
    }
    
    private func setupCharts() {
        // 조화도 트렌드 차트
        let harmonyTrendChart = HarmonyTrendChart()
        harmonyTrendChartView = UIHostingController(rootView: harmonyTrendChart)
        addChild(harmonyTrendChartView)
        harmonyTrendChartView.view.translatesAutoresizingMaskIntoConstraints = false
        harmonyTrendChartView.view.backgroundColor = UIColor.clear
        contentView.addSubview(harmonyTrendChartView.view)
        harmonyTrendChartView.didMove(toParent: self)
        
        // 충돌 레이더 차트
        let conflictRadarChart = ConflictRadarChart()
        conflictRadarChartView = UIHostingController(rootView: conflictRadarChart)
        addChild(conflictRadarChartView)
        conflictRadarChartView.view.translatesAutoresizingMaskIntoConstraints = false
        conflictRadarChartView.view.backgroundColor = UIColor.clear
        contentView.addSubview(conflictRadarChartView.view)
        conflictRadarChartView.didMove(toParent: self)
        
        // 개선 제안 뷰
        let improvementSuggestion = ImprovementSuggestionView()
        improvementSuggestionView = UIHostingController(rootView: improvementSuggestion)
        addChild(improvementSuggestionView)
        improvementSuggestionView.view.translatesAutoresizingMaskIntoConstraints = false
        improvementSuggestionView.view.backgroundColor = UIColor.clear
        contentView.addSubview(improvementSuggestionView.view)
        improvementSuggestionView.didMove(toParent: self)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll View
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content View
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Score Circle
            scoreCircleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            scoreCircleView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            scoreCircleView.widthAnchor.constraint(equalToConstant: 150),
            scoreCircleView.heightAnchor.constraint(equalToConstant: 150),
            
            scoreLabel.centerXAnchor.constraint(equalTo: scoreCircleView.centerXAnchor),
            scoreLabel.centerYAnchor.constraint(equalTo: scoreCircleView.centerYAnchor, constant: -10),
            
            scoreDetailLabel.centerXAnchor.constraint(equalTo: scoreCircleView.centerXAnchor),
            scoreDetailLabel.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 4),
            
            // Harmony Trend Chart
            harmonyTrendChartView.view.topAnchor.constraint(equalTo: scoreCircleView.bottomAnchor, constant: 20),
            harmonyTrendChartView.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            harmonyTrendChartView.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            harmonyTrendChartView.view.heightAnchor.constraint(equalToConstant: 200),
            
            // Conflict Radar Chart
            conflictRadarChartView.view.topAnchor.constraint(equalTo: harmonyTrendChartView.view.bottomAnchor, constant: 20),
            conflictRadarChartView.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            conflictRadarChartView.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            conflictRadarChartView.view.heightAnchor.constraint(equalToConstant: 250),
            
            // Conflicts Container
            conflictsContainer.topAnchor.constraint(equalTo: conflictRadarChartView.view.bottomAnchor, constant: 20),
            conflictsContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            conflictsContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            conflictsContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            
            // Improvement Suggestion View
            improvementSuggestionView.view.topAnchor.constraint(equalTo: conflictsContainer.bottomAnchor, constant: 20),
            improvementSuggestionView.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            improvementSuggestionView.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            improvementSuggestionView.view.heightAnchor.constraint(equalToConstant: 200),
            
            // Recommendations Container
            recommendationsContainer.topAnchor.constraint(equalTo: improvementSuggestionView.view.bottomAnchor, constant: 20),
            recommendationsContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            recommendationsContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            recommendationsContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            
            // Feedback Container
            feedbackContainer.topAnchor.constraint(equalTo: recommendationsContainer.bottomAnchor, constant: 20),
            feedbackContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            feedbackContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            feedbackContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
            feedbackContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Analysis & Update
    
    private func performHarmonyAnalysis() {
        print("🔍 [HarmonyVisualization] 조화도 분석 시작...")
        let combination = soundCombination.map { (soundId: $0.soundId, version: $0.version, volume: $0.volume) }
        Task {
            let analysis = await SoundHarmonyAnalyzer.shared.analyzeHarmony(for: combination)
            self.harmonyAnalysis = analysis
            print("✅ [HarmonyVisualization] 조화도 분석 완료: \(Int(analysis.overallScore))점")
            self.updateUI()
        }
    }
    
    private func updateUI() {
        guard let analysis = harmonyAnalysis else {
            print("⚠️ [HarmonyVisualization] 분석 데이터 없음")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.updateScoreDisplay(analysis)
            self?.updateConflictsDisplay(analysis)
            self?.updateRecommendationsDisplay(analysis)
            self?.setupFeedbackUI()
        }
    }
    
    private func updateScoreDisplay(_ analysis: SoundHarmonyAnalyzer.HarmonyAnalysis) {
        // 전체 점수를 퍼센트로 표시
        let scorePercent = Int(analysis.overallScore)
        scoreLabel.text = "\(scorePercent)%"
        
        // 점수에 따른 색상 변경 (0.0~1.0 범위로 변환)
        let normalizedScore = analysis.overallScore / 100
        let (color, emoji) = getScoreStyle(score: normalizedScore)
        scoreCircleView.layer.borderColor = color.cgColor
        scoreCircleView.backgroundColor = color.withAlphaComponent(0.1)
        scoreLabel.textColor = color
        
        // 애니메이션 효과
        UIView.animate(withDuration: 1.0, delay: 0.2, options: .curveEaseInOut) {
            self.scoreCircleView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        } completion: { _ in
            UIView.animate(withDuration: 0.5) {
                self.scoreCircleView.transform = .identity
            }
        }
    }
    
    private func updateConflictsDisplay(_ analysis: SoundHarmonyAnalyzer.HarmonyAnalysis) {
        // 기존 충돌 정보 제거
        conflictsContainer.subviews.forEach { subview in
            if subview.tag == 999 {
                subview.removeFromSuperview()
            }
        }
        
        let startY: CGFloat = 50
        var currentY = startY
        
        for (index, conflict) in analysis.conflicts.enumerated() {
            let conflictView = createConflictView(conflict: conflict)
            conflictView.tag = 999
            conflictView.translatesAutoresizingMaskIntoConstraints = false
            conflictsContainer.addSubview(conflictView)
            
            NSLayoutConstraint.activate([
                conflictView.topAnchor.constraint(equalTo: conflictsContainer.topAnchor, constant: currentY),
                conflictView.leadingAnchor.constraint(equalTo: conflictsContainer.leadingAnchor, constant: 16),
                conflictView.trailingAnchor.constraint(equalTo: conflictsContainer.trailingAnchor, constant: -16),
                conflictView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
            ])
            
            currentY += 70
        }
        
        // 컨테이너 높이 업데이트
        conflictsContainer.heightAnchor.constraint(equalToConstant: max(100, currentY + 20)).isActive = true
    }
    
    private func updateRecommendationsDisplay(_ analysis: SoundHarmonyAnalyzer.HarmonyAnalysis) {
        // 기존 추천 정보 제거
        recommendationsContainer.subviews.forEach { subview in
            if subview.tag == 888 {
                subview.removeFromSuperview()
            }
        }
        
        let startY: CGFloat = 50
        var currentY = startY
        
        // AI 기반 개선 제안(suggestions) 표시
        for (index, suggestion) in analysis.suggestions.enumerated() {
            let recommendationView = createRecommendationView(recommendation: suggestion.description)
            recommendationView.tag = 888
            recommendationView.translatesAutoresizingMaskIntoConstraints = false
            recommendationsContainer.addSubview(recommendationView)
            
            NSLayoutConstraint.activate([
                recommendationView.topAnchor.constraint(equalTo: recommendationsContainer.topAnchor, constant: currentY),
                recommendationView.leadingAnchor.constraint(equalTo: recommendationsContainer.leadingAnchor, constant: 16),
                recommendationView.trailingAnchor.constraint(equalTo: recommendationsContainer.trailingAnchor, constant: -16),
                recommendationView.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
            ])
            
            currentY += 50
        }
        
        // 컨테이너 높이 업데이트
        recommendationsContainer.heightAnchor.constraint(equalToConstant: max(120, currentY + 20)).isActive = true
    }
    
    // MARK: - Helper Methods
    
    private func getScoreStyle(score: Float) -> (UIColor, String) {
        switch score {
        case 0.9...:
            return (UIColor.systemGreen, "🎉")
        case 0.8..<0.9:
            return (UIColor.systemBlue, "😊")
        case 0.7..<0.8:
            return (UIColor.systemOrange, "🤔")
        case 0.6..<0.7:
            return (UIColor.systemRed, "😰")
        default:
            return (UIColor.systemPurple, "🚨")
        }
    }
    
    private func createConflictView(conflict: SoundHarmonyAnalyzer.HarmonyConflict) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
        container.layer.cornerRadius = 8
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.systemRed.withAlphaComponent(0.3).cgColor
        
        let severityLabel = UILabel()
        severityLabel.font = .systemFont(ofSize: 12, weight: .medium)
        severityLabel.textColor = UIColor.systemRed
        severityLabel.text = "⚠️ \(conflict.type.rawValue)"
        severityLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let descriptionLabel = UILabel()
        descriptionLabel.font = .systemFont(ofSize: 14, weight: .regular)
        descriptionLabel.textColor = UIColor.label
        descriptionLabel.text = conflict.description
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(severityLabel)
        container.addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            severityLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            severityLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            severityLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            
            descriptionLabel.topAnchor.constraint(equalTo: severityLabel.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            descriptionLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            descriptionLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
        
        return container
    }
    
    private func createRecommendationView(recommendation: String) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
        container.layer.cornerRadius = 8
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.systemGreen.withAlphaComponent(0.3).cgColor
        
        let recommendationLabel = UILabel()
        recommendationLabel.font = .systemFont(ofSize: 14, weight: .regular)
        recommendationLabel.textColor = UIColor.label
        recommendationLabel.text = "✅ \(recommendation)"
        recommendationLabel.numberOfLines = 0
        recommendationLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(recommendationLabel)
        
        NSLayoutConstraint.activate([
            recommendationLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            recommendationLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            recommendationLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            recommendationLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
        
        return container
    }
    
    // MARK: - Feedback System
    
    private func setupFeedbackUI() {
        // 숫자 평점 섹션
        let numericalRatingView = createNumericalRatingView()
        numericalRatingView.tag = 777
        numericalRatingView.translatesAutoresizingMaskIntoConstraints = false
        feedbackContainer.addSubview(numericalRatingView)
        
        // 자연어 피드백 섹션
        let naturalLanguageFeedbackView = createNaturalLanguageFeedbackView()
        naturalLanguageFeedbackView.tag = 777
        naturalLanguageFeedbackView.translatesAutoresizingMaskIntoConstraints = false
        feedbackContainer.addSubview(naturalLanguageFeedbackView)
        
        // 선호도 체크박스 섹션
        let preferencesView = createPreferencesView()
        preferencesView.tag = 777
        preferencesView.translatesAutoresizingMaskIntoConstraints = false
        feedbackContainer.addSubview(preferencesView)
        
        NSLayoutConstraint.activate([
            numericalRatingView.topAnchor.constraint(equalTo: feedbackContainer.topAnchor, constant: 50),
            numericalRatingView.leadingAnchor.constraint(equalTo: feedbackContainer.leadingAnchor, constant: 16),
            numericalRatingView.trailingAnchor.constraint(equalTo: feedbackContainer.trailingAnchor, constant: -16),
            numericalRatingView.heightAnchor.constraint(equalToConstant: 50),
            
            naturalLanguageFeedbackView.topAnchor.constraint(equalTo: numericalRatingView.bottomAnchor, constant: 20),
            naturalLanguageFeedbackView.leadingAnchor.constraint(equalTo: feedbackContainer.leadingAnchor, constant: 16),
            naturalLanguageFeedbackView.trailingAnchor.constraint(equalTo: feedbackContainer.trailingAnchor, constant: -16),
            naturalLanguageFeedbackView.heightAnchor.constraint(equalToConstant: 60),
            
            preferencesView.topAnchor.constraint(equalTo: naturalLanguageFeedbackView.bottomAnchor, constant: 20),
            preferencesView.leadingAnchor.constraint(equalTo: feedbackContainer.leadingAnchor, constant: 16),
            preferencesView.trailingAnchor.constraint(equalTo: feedbackContainer.trailingAnchor, constant: -16),
            preferencesView.heightAnchor.constraint(equalToConstant: 80),
            preferencesView.bottomAnchor.constraint(equalTo: feedbackContainer.bottomAnchor, constant: -20)
        ])
    }
    
    private func createNumericalRatingView() -> UIView {
        let container = UIView()
        
        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.text = "이번 프리셋은 100점 만점에 몇 점인가요?"
        titleLabel.textColor = UIColor.label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let buttonsStackView = UIStackView()
        buttonsStackView.axis = .horizontal
        buttonsStackView.distribution = .fillEqually
        buttonsStackView.spacing = 8
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(buttonsStackView)
        
        // 점수 버튼들 (10점 단위)
        for score in stride(from: 100, through: 10, by: -10) {
            let button = UIButton(type: .system)
            button.setTitle("\(score)", for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
            button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
            button.layer.cornerRadius = 8
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
            button.addTarget(self, action: #selector(numericalRatingTapped(_:)), for: .touchUpInside)
            button.tag = score
            buttonsStackView.addArrangedSubview(button)
        }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            buttonsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            buttonsStackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            buttonsStackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            buttonsStackView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createNaturalLanguageFeedbackView() -> UIView {
        let container = UIView()
        
        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.text = "소감을 자유롭게 알려주세요"
        titleLabel.textColor = UIColor.label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let textField = UITextField()
        textField.placeholder = "예: 별로였어, 좋았어, 파도와 새 소리가 잘 어울렸어"
        textField.font = .systemFont(ofSize: 14)
        textField.borderStyle = .roundedRect
        textField.backgroundColor = UIColor.systemGray6
        textField.addTarget(self, action: #selector(naturalLanguageFeedbackChanged(_:)), for: .editingChanged)
        textField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(textField)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            textField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            textField.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textField.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createPreferencesView() -> UIView {
        let container = UIView()
        
        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.text = "앞으로 이런 음원을 제외해주세요"
        titleLabel.textColor = UIColor.label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let checkboxesStackView = UIStackView()
        checkboxesStackView.axis = .horizontal
        checkboxesStackView.distribution = .fillEqually
        checkboxesStackView.spacing = 8
        checkboxesStackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(checkboxesStackView)
        
        // 현재 프리셋의 음원들에 대한 체크박스
        for (index, sound) in soundCombination.enumerated() {
            guard let soundVersion = SoundCatalogManager.shared.findVersion(soundId: sound.soundId, version: sound.version) else { continue }
            
            let checkboxButton = UIButton(type: .system)
            checkboxButton.setTitle("☐ \(soundVersion.displayName)", for: .normal)
            checkboxButton.setTitle("☑️ \(soundVersion.displayName)", for: .selected)
            checkboxButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
            checkboxButton.contentHorizontalAlignment = .left
            checkboxButton.addTarget(self, action: #selector(preferenceCheckboxTapped(_:)), for: .touchUpInside)
            checkboxButton.tag = index
            checkboxesStackView.addArrangedSubview(checkboxButton)
        }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            checkboxesStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            checkboxesStackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            checkboxesStackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            checkboxesStackView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func triggerFeedbackRequest() {
        // 자동 피드백 요청 시스템
        let alert = UIAlertController(
            title: "🎵 프리셋 피드백",
            message: "이번 프리셋은 어떠셨나요? 여러분의 의견이 더 나은 추천을 만듭니다!",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "지금 피드백 남기기", style: .default) { [weak self] _ in
            // 피드백 섹션으로 스크롤
            self?.scrollToFeedbackSection()
        })
        
        alert.addAction(UIAlertAction(title: "나중에", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func scrollToFeedbackSection() {
        let feedbackY = feedbackContainer.frame.origin.y - 20
        scrollView.setContentOffset(CGPoint(x: 0, y: feedbackY), animated: true)
        
        // 피드백 섹션 하이라이트 애니메이션
        UIView.animate(withDuration: 0.3, delay: 0.5, options: .curveEaseInOut) {
            self.feedbackContainer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 0.5, options: .curveEaseInOut) {
                self.feedbackContainer.backgroundColor = UIColor.systemBackground
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func numericalRatingTapped(_ sender: UIButton) {
        let score = sender.tag
        print("🔢 [HarmonyVisualization] 숫자 평점: \(score)점")
        
        // 버튼 선택 상태 업데이트
        if let stackView = sender.superview as? UIStackView {
            stackView.arrangedSubviews.forEach { view in
                if let button = view as? UIButton {
                    button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
                    button.setTitleColor(.systemBlue, for: .normal)
                }
            }
        }
        
        sender.backgroundColor = UIColor.systemBlue
        sender.setTitleColor(.white, for: .normal)
        
        // 피드백 저장
        saveFeedback(numericScore: score)
        
        // 햅틱 피드백
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    @objc private func naturalLanguageFeedbackChanged(_ sender: UITextField) {
        guard let text = sender.text, !text.isEmpty else { return }
        print("💬 [HarmonyVisualization] 자연어 피드백: \(text)")
        
        // AI 기반 감정 분석 및 점수 추출
        processNaturalLanguageFeedback(text)
    }
    
    @objc private func preferenceCheckboxTapped(_ sender: UIButton) {
        sender.isSelected.toggle()
        let soundIndex = sender.tag
        
        if soundIndex < soundCombination.count {
            let sound = soundCombination[soundIndex]
            print("❌ [HarmonyVisualization] 음원 제외 설정: \(sound.soundId) = \(sender.isSelected)")
            
            // 사용자 선호도에 음원 제외 정보 저장
            saveExcludedSoundPreference(soundId: sound.soundId, exclude: sender.isSelected)
        }
        
        // 햅틱 피드백
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    @objc private func dismissViewController() {
        dismiss(animated: true)
    }
    
    // MARK: - Feedback Processing
    
    private func processNaturalLanguageFeedback(_ text: String) {
        // 자연어 처리를 통한 감정 및 점수 추출
        let normalizedText = text.lowercased()
        
        var extractedScore: Int?
        var sentiment: String = "neutral"
        
        // 점수 추출 (정규표현식 사용)
        let scoreRegex = try? NSRegularExpression(pattern: "\\b([0-9]{1,3})점?\\b", options: [])
        if let regex = scoreRegex {
            let range = NSRange(location: 0, length: text.count)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                let scoreRange = match.range(at: 1)
                if let swiftRange = Range(scoreRange, in: text) {
                    extractedScore = Int(String(text[swiftRange]))
                }
            }
        }
        
        // 감정 분석
        if normalizedText.contains("좋") || normalizedText.contains("훌륭") || normalizedText.contains("완벽") || normalizedText.contains("최고") {
            sentiment = "positive"
            if extractedScore == nil { extractedScore = 85 }
        } else if normalizedText.contains("별로") || normalizedText.contains("안좋") || normalizedText.contains("싫") || normalizedText.contains("나쁘") {
            sentiment = "negative"
            if extractedScore == nil { extractedScore = 30 }
        } else if normalizedText.contains("그냥") || normalizedText.contains("보통") || normalizedText.contains("괜찮") {
            sentiment = "neutral"
            if extractedScore == nil { extractedScore = 60 }
        }
        
        // 조합 관련 피드백 분석
        var combinationFeedback: [String: String] = [:]
        if normalizedText.contains("어울") && normalizedText.contains("좋") {
            combinationFeedback["harmony"] = "good"
        } else if normalizedText.contains("안어울") || normalizedText.contains("부조화") {
            combinationFeedback["harmony"] = "bad"
        }
        
        print("🧠 [HarmonyVisualization] NLP 분석 결과 - 감정: \(sentiment), 점수: \(extractedScore ?? 0), 조합: \(combinationFeedback)")
        
        // 피드백 저장
        saveFeedback(
            numericScore: extractedScore,
            naturalLanguage: text,
            sentiment: sentiment,
            combinationFeedback: combinationFeedback
        )
    }
    
    private func saveFeedback(numericScore: Int? = nil, 
                             naturalLanguage: String? = nil,
                             sentiment: String? = nil,
                             combinationFeedback: [String: String]? = nil) {
        
        guard let analysis = harmonyAnalysis else { return }
        
        let feedback = HarmonyFeedback(
            harmonyScore: analysis.overallScore,
            userRating: numericScore,
            naturalLanguageFeedback: naturalLanguage,
            sentiment: sentiment ?? "neutral",
            soundCombination: soundCombination,
            conflicts: analysis.conflicts,
            timestamp: Date(),
            combinationFeedback: combinationFeedback ?? [:]
        )
        
        // PersonalizedHarmonyLearner에 피드백 전달
        if #available(iOS 17.0, *) {
            PersonalizedHarmonyLearner.shared.addFeedback(feedback)
        }
        
        print("💾 [HarmonyVisualization] 피드백 저장 완료")
    }
    
    private func saveExcludedSoundPreference(soundId: String, exclude: Bool) {
        // 사용자 선호도 시스템에 음원 제외 정보 저장
        if #available(iOS 17.0, *) {
            PersonalizedHarmonyLearner.shared.updateSoundExclusion(soundId: soundId, exclude: exclude)
        }
    }
}

// MARK: - Data Models
@available(iOS 17.0, *)
struct HarmonyFeedback {
    let harmonyScore: Float
    let userRating: Int?
    let naturalLanguageFeedback: String?
    let sentiment: String
    let soundCombination: [(soundId: String, version: String, volume: Float)]
    let conflicts: [SoundHarmonyAnalyzer.HarmonyConflict]
    let timestamp: Date
    let combinationFeedback: [String: String]
}

// MARK: - UICollectionViewDataSource
@available(iOS 17.0, *)
extension HarmonyVisualizationViewController {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return harmonyAnalysis?.conflicts.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return UICollectionViewCell()
    }
}

// MARK: - PresetFeedbackDelegate
@available(iOS 17.0, *)
extension HarmonyVisualizationViewController {
    func didSubmitFeedback(satisfaction: Float, comments: String?) {
        // Placeholder
    }
} 
