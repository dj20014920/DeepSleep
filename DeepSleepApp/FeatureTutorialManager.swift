//
//  FeatureTutorialManager.swift
//  DeepSleep
//
//  Created on 2025-01-20.
//

import UIKit

/// 🎯 기능별 튜토리얼 관리자
class FeatureTutorialManager {
    static let shared = FeatureTutorialManager()

    // 튜토리얼 타입
    enum TutorialType: String, CaseIterable {
        case emotionDiary = "emotionDiaryTutorial"
        case soundPlayer = "soundPlayerTutorial"
        case aiChat = "aiChatTutorial"
        case calendar = "calendarTutorial"
        case todo = "todoTutorial"

        var title: String {
            switch self {
            case .emotionDiary: return "감정 일기 작성"
            case .soundPlayer: return "수면 사운드"
            case .aiChat: return "대나무숲 친구와 대화"
            case .calendar: return "감정 캘린더"
            case .todo: return "할 일 관리"
            }
        }

        var steps: [TutorialStep] {
            switch self {
            case .emotionDiary:
                return [
                    TutorialStep(title: "감정 선택", description: "현재 기분을 이모지로 선택하세요", icon: "face.smiling"),
                    TutorialStep(title: "일기 작성", description: "오늘의 감정과 생각을 자유롭게 적어보세요", icon: "pencil"),
                    TutorialStep(title: "감정 분석", description: "대나무숲 친구가 당신의 감정을 분석하고 공감해드립니다", icon: "brain.head.profile"),
                    TutorialStep(title: "캘린더 저장", description: "작성한 일기는 캘린더에 저장되어 추적할 수 있습니다", icon: "calendar")
                ]
            case .soundPlayer:
                return [
                    TutorialStep(title: "사운드 선택", description: "원하는 수면 사운드를 선택하세요", icon: "speaker.wave.2"),
                    TutorialStep(title: "볼륨 조절", description: "각 사운드의 볼륨을 개별적으로 조절할 수 있습니다", icon: "slider.horizontal.3"),
                    TutorialStep(title: "타이머 설정", description: "수면 시간을 설정하면 자동으로 종료됩니다", icon: "timer"),
                    TutorialStep(title: BrandingCopy.recommendationName, description: "현재 감정에 맞는 사운드를 대나무숲 친구가 추천해드립니다", icon: "sparkles")
                ]
            case .aiChat:
                return [
                    TutorialStep(title: "대나무숲 친구 선택", description: "대화할 대나무숲 친구를 선택하세요", icon: "person.fill"),
                    TutorialStep(title: "자유로운 대화", description: "마음의 이야기를 자유롭게 털어놓으세요", icon: "message"),
                    TutorialStep(title: "핵심 기억", description: "중요한 대화를 길게 눌러 기억으로 저장하세요", icon: "star.fill"),
                    TutorialStep(title: "맞춤 추천", description: "대나무숲 친구가 당신의 상황에 맞는 사운드를 추천합니다", icon: "music.note")
                ]
            case .calendar:
                return [
                    TutorialStep(title: "감정 추적", description: "캘린더에서 과거 감정을 한눈에 볼 수 있습니다", icon: "calendar"),
                    TutorialStep(title: "패턴 분석", description: "대나무숲 친구가 감정 패턴을 분석하여 인사이트를 제공합니다", icon: "chart.bar"),
                    TutorialStep(title: "특별한 날", description: "기억하고 싶은 날짜를 즐겨찾기로 지정하세요", icon: "heart.fill"),
                    TutorialStep(title: "월간 리뷰", description: "한 달의 감정 흐름을 리뷰해보세요", icon: "calendar.badge.clock")
                ]
            case .todo:
                return [
                    TutorialStep(title: "할 일 추가", description: "해야 할 일을 간단하게 추가하세요", icon: "plus.circle"),
                    TutorialStep(title: "우선순위 설정", description: "중요한 일에 별표를 표시하세요", icon: "star"),
                    TutorialStep(title: "알림 설정", description: "기한이 있는 일은 알림을 설정하세요", icon: "bell"),
                    TutorialStep(title: "완료 체크", description: "일을 완료하면 체크 표시하세요", icon: "checkmark.circle")
                ]
            }
        }
    }

    struct TutorialStep {
        let title: String
        let description: String
        let icon: String
    }

    // MARK: - Public Methods

    /// 특정 기능의 튜토리얼 표시 여부 확인
    func shouldShowTutorial(_ type: TutorialType) -> Bool {
        let key = "tutorial_\(type.rawValue)_shown"
        return !UserDefaults.standard.bool(forKey: key)
    }

    /// 튜토리얼 표시 완료로 마크
    func markTutorialAsShown(_ type: TutorialType) {
        let key = "tutorial_\(type.rawValue)_shown"
        UserDefaults.standard.set(true, forKey: key)
    }

    /// 튜토리얼 재시작 (모든 튜토리얼 리셋)
    func resetAllTutorials() {
        TutorialType.allCases.forEach { type in
            let key = "tutorial_\(type.rawValue)_shown"
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// 튜토리얼 뷰 컨트롤러 생성
    func createTutorialViewController(for type: TutorialType) -> TutorialViewController {
        let tutorialVC = TutorialViewController()
        tutorialVC.tutorialType = type
        tutorialVC.steps = type.steps
        return tutorialVC
    }

    /// 특정 화면에서 튜토리얼 표시
    func showTutorialIfNeeded(for type: TutorialType, in viewController: UIViewController) {
        guard shouldShowTutorial(type) else { return }

        let tutorialVC = createTutorialViewController(for: type)
        tutorialVC.modalPresentationStyle = .overFullScreen
        viewController.present(tutorialVC, animated: true)
    }
}

/// 🎯 튜토리얼 뷰 컨트롤러
class TutorialViewController: UIViewController {

    var tutorialType: FeatureTutorialManager.TutorialType!
    var steps: [FeatureTutorialManager.TutorialStep] = []
    private var currentStepIndex = 0

    private let overlayView = UIView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let iconImageView = UIImageView()
    private let stepIndicator = UILabel()
    private let nextButton = UIButton(type: .system)
    private let skipButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        showCurrentStep()
    }

    private func setupUI() {
        // 오버레이
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)

        // 컨텐츠 뷰
        contentView.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        contentView.layer.cornerRadius = 20
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOffset = CGSize(width: 0, height: 4)
        contentView.layer.shadowRadius = 8
        contentView.layer.shadowOpacity = 0.3
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)

        // 아이콘
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .systemBlue
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconImageView)

        // 타이틀
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // 설명
        descriptionLabel.font = UIFont.systemFont(ofSize: 16)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(descriptionLabel)

        // 스텝 인디케이터
        stepIndicator.font = UIFont.systemFont(ofSize: 14)
        stepIndicator.textColor = .tertiaryLabel
        stepIndicator.textAlignment = .center
        stepIndicator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stepIndicator)

        // 다음 버튼
        nextButton.setTitle("다음", for: .normal)
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.backgroundColor = .systemBlue
        nextButton.layer.cornerRadius = 25
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nextButton)

        // 건너뛰기 버튼
        skipButton.setTitle("건너뛰기", for: .normal)
        skipButton.setTitleColor(.systemGray, for: .normal)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(skipButton)

        setupConstraints()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            contentView.widthAnchor.constraint(equalToConstant: 320),
            contentView.heightAnchor.constraint(equalToConstant: 400),

            iconImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 30),
            iconImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 60),
            iconImageView.heightAnchor.constraint(equalToConstant: 60),

            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            stepIndicator.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 20),
            stepIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            nextButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            nextButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            nextButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            nextButton.heightAnchor.constraint(equalToConstant: 50),

            skipButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 15),
            skipButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15)
        ])
    }

    private func showCurrentStep() {
        guard currentStepIndex < steps.count else {
            completeTutorial()
            return
        }

        let step = steps[currentStepIndex]

        iconImageView.image = UIImage(systemName: step.icon)
        titleLabel.text = step.title
        descriptionLabel.text = step.description
        stepIndicator.text = "\(currentStepIndex + 1) / \(steps.count)"

        let isLastStep = currentStepIndex == steps.count - 1
        nextButton.setTitle(isLastStep ? "완료" : "다음", for: .normal)
    }

    @objc private func nextTapped() {
        if currentStepIndex < steps.count - 1 {
            currentStepIndex += 1
            showCurrentStep()
        } else {
            completeTutorial()
        }
    }

    @objc private func skipTapped() {
        completeTutorial()
    }

    private func completeTutorial() {
        FeatureTutorialManager.shared.markTutorialAsShown(tutorialType)
        dismiss(animated: true)
    }
}
