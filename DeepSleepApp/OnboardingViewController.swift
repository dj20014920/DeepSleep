//
//  OnboardingViewController.swift
//  EmoZleep
//
//  Created on 2025-01-20.
//

import UIKit

/// 🎯 종합 온보딩 화면
class OnboardingViewController: UIViewController {

    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let pageControl = UIPageControl()
    private let nextButton = UIButton(type: .system)
    private let skipButton = UIButton(type: .system)

    private var currentPage = 0
    private let totalPages = OnboardingManager.OnboardingStep.allCases.count

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupPages()
        updateUI()
    }

    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground

        // ScrollView 설정
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        view.addSubview(scrollView)

        // ContentView 설정
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        // Page Control
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.numberOfPages = totalPages
        pageControl.currentPage = 0
        pageControl.pageIndicatorTintColor = .systemGray3
        pageControl.currentPageIndicatorTintColor = .systemBlue
        view.addSubview(pageControl)

        // Skip Button
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.setTitle("건너뛰기", for: .normal)
        skipButton.setTitleColor(.systemGray, for: .normal)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        view.addSubview(skipButton)

        // Next Button
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.setTitle("다음", for: .normal)
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.backgroundColor = .systemBlue
        nextButton.layer.cornerRadius = 25
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        view.addSubview(nextButton)

        setupConstraints()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -20),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, multiplier: CGFloat(totalPages)),

            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -20),

            skipButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            skipButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            nextButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nextButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            nextButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            nextButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func setupPages() {
        let steps = OnboardingManager.OnboardingStep.allCases

        for (index, step) in steps.enumerated() {
            let pageView = createPageView(for: step)
            contentView.addSubview(pageView)

            NSLayoutConstraint.activate([
                pageView.topAnchor.constraint(equalTo: contentView.topAnchor),
                pageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                pageView.widthAnchor.constraint(equalTo: view.widthAnchor),
                pageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: CGFloat(index) * view.frame.width)
            ])
        }
    }

    private func createPageView(for step: OnboardingManager.OnboardingStep) -> UIView {
        let pageView = UIView()
        pageView.translatesAutoresizingMaskIntoConstraints = false

        // 아이콘 이미지뷰
        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.image = getIconForStep(step)
        pageView.addSubview(iconImageView)

        // 타이틀 레이블
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = step.title
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        pageView.addSubview(titleLabel)

        // 설명 레이블
        let descriptionLabel = UILabel()
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.text = step.description
        descriptionLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        pageView.addSubview(descriptionLabel)

        // 추가 컨텐츠 (특정 단계용)
        let additionalContent = createAdditionalContent(for: step)
        if let additionalView = additionalContent {
            pageView.addSubview(additionalView)
        }

        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: pageView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: pageView.centerYAnchor, constant: -80),
            iconImageView.widthAnchor.constraint(equalToConstant: 120),
            iconImageView.heightAnchor.constraint(equalToConstant: 120),

            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: pageView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -20),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            descriptionLabel.leadingAnchor.constraint(equalTo: pageView.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -20)
        ])

        // 추가 컨텐츠 제약조건
        if let additionalView = additionalContent {
            NSLayoutConstraint.activate([
                additionalView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 30),
                additionalView.leadingAnchor.constraint(equalTo: pageView.leadingAnchor, constant: 20),
                additionalView.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -20),
                additionalView.bottomAnchor.constraint(lessThanOrEqualTo: pageView.bottomAnchor, constant: -20)
            ])
        }

        return pageView
    }

    private func getIconForStep(_ step: OnboardingManager.OnboardingStep) -> UIImage? {
        switch step {
        case .welcome:
            return UIImage(systemName: "moon.stars.fill")
        case .appIntroduction:
            return UIImage(systemName: "sparkles")
        case .aiPersonaSetup:
            return UIImage(systemName: "person.fill")
        case .mainFeatures:
            return UIImage(systemName: "star.fill")
        case .soundExperience:
            return UIImage(systemName: "speaker.wave.2.fill")
        case .emotionDiary:
            return UIImage(systemName: "book.fill")
        case .subscriptionIntro:
            return UIImage(systemName: "crown.fill")
        case .completion:
            return UIImage(systemName: "checkmark.circle.fill")
        }
    }

    private func createAdditionalContent(for step: OnboardingManager.OnboardingStep) -> UIView? {
        switch step {
        case .aiPersonaSetup:
            return createPersonaPreview()
        case .mainFeatures:
            return createFeaturesList()
        case .subscriptionIntro:
            return createSubscriptionPreview()
        default:
            return nil
        }
    }

    private func createPersonaPreview() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // 미리보기(비활성) 버튼 + 설명 캡션
        let previewButton = UIButton(type: .system)
        previewButton.translatesAutoresizingMaskIntoConstraints = false
        previewButton.setTitle("대나무숲 친구 선택하기", for: .normal)
        previewButton.setTitleColor(.white, for: .normal)
        previewButton.backgroundColor = .systemBlue
        previewButton.layer.cornerRadius = 8
        previewButton.isEnabled = false
        previewButton.isUserInteractionEnabled = false
        previewButton.alpha = 0.5

        let previewCaption = UILabel()
        previewCaption.translatesAutoresizingMaskIntoConstraints = false
        previewCaption.text = "설정 창에 있는 대나무숲 친구 설정을 누르면 친구를 고를 수 있어요"
        previewCaption.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        previewCaption.textColor = .secondaryLabel
        previewCaption.textAlignment = .center
        previewCaption.numberOfLines = 0

        let previewStack = UIStackView(arrangedSubviews: [previewButton, previewCaption])
        previewStack.axis = .vertical
        previewStack.alignment = .center
        previewStack.spacing = 8
        previewStack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(previewStack)

        NSLayoutConstraint.activate([
            // 미리보기 버튼 크기
            previewButton.widthAnchor.constraint(equalToConstant: 200),
            previewButton.heightAnchor.constraint(equalToConstant: 44),

            // 미리보기 스택 배치
            previewStack.topAnchor.constraint(equalTo: container.topAnchor),
            previewStack.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            // 실제 동작 버튼 배치
            personaButton.topAnchor.constraint(equalTo: previewStack.bottomAnchor, constant: 20),
            personaButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            personaButton.widthAnchor.constraint(equalToConstant: 200),
            personaButton.heightAnchor.constraint(equalToConstant: 44),
            personaButton.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func createFeaturesList() -> UIView {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.alignment = .leading

        let features = [
            "• 감정 분석 및 대나무숲 친구 대화",
            "• 개인 맞춤 수면 사운드",
            "• 감정 일기 및 캘린더",
            "• 할 일 관리 및 리마인더"
        ]

        for feature in features {
            let label = UILabel()
            label.text = feature
            label.font = UIFont.systemFont(ofSize: 14)
            label.textColor = .label
            stackView.addArrangedSubview(label)
        }

        return stackView
    }

    private func createSubscriptionPreview() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let freeLabel = UILabel()
        freeLabel.translatesAutoresizingMaskIntoConstraints = false
        freeLabel.text = BrandingCopy.subscriptionFreeLabel
        freeLabel.font = UIFont.systemFont(ofSize: 14)
        freeLabel.textColor = .secondaryLabel

        let proLabel = UILabel()
        proLabel.translatesAutoresizingMaskIntoConstraints = false
        proLabel.text = BrandingCopy.subscriptionProLabel
        proLabel.font = UIFont.systemFont(ofSize: 14)
        proLabel.textColor = .systemBlue
        proLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)

        container.addSubview(freeLabel)
        container.addSubview(proLabel)

        NSLayoutConstraint.activate([
            freeLabel.topAnchor.constraint(equalTo: container.topAnchor),
            freeLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            freeLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            proLabel.topAnchor.constraint(equalTo: freeLabel.bottomAnchor, constant: 8),
            proLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            proLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        return container
    }

    // MARK: - Actions
    @objc private func skipTapped() {
        OnboardingManager.shared.completeOnboarding()
        dismiss(animated: true)
    }

    @objc private func nextTapped() {
        if currentPage < totalPages - 1 {
            currentPage += 1
            scrollToPage(currentPage)
            updateUI()
        } else {
            OnboardingManager.shared.completeOnboarding()
            dismiss(animated: true) {
                // 온보딩 완료 후 메인 인터페이스로 전환 (단일 진입점)
                if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                    sceneDelegate.showOptimizedMainInterface()
                } else {
                    // SceneDelegate 접근이 어려운 환경에서는 표준 노티를 통해 메인 전환을 요청
                    NotificationCenter.default.post(name: NSNotification.Name("GoToMainScreen"), object: nil)
                }
            }
        }
    }

    @objc private func personaSetupTapped() {
        // 대나무숲 친구 페르소나 설정 화면으로 이동
        let personaVC = AIModelSelectionViewController()
        navigationController?.pushViewController(personaVC, animated: true)
    }

    private func scrollToPage(_ page: Int) {
        let offset = CGPoint(x: CGFloat(page) * view.frame.width, y: 0)
        scrollView.setContentOffset(offset, animated: true)
    }

    private func updateUI() {
        pageControl.currentPage = currentPage

        let isLastPage = currentPage == totalPages - 1
        nextButton.setTitle(isLastPage ? "시작하기" : "다음", for: .normal)

        // 마지막 페이지에서는 스킵 버튼 숨김
        skipButton.isHidden = isLastPage
    }
}

// MARK: - UIScrollViewDelegate
extension OnboardingViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let pageIndex = round(scrollView.contentOffset.x / view.frame.width)
        currentPage = Int(pageIndex)
        pageControl.currentPage = currentPage
        updateUI()
    }
}
