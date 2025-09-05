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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // 입장 애니메이션
        animateEntrance()
    }

    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground

        // 배경에 미세한 그라데이션 추가
        let backgroundGradient = CAGradientLayer()
        backgroundGradient.colors = [
            UIColor.systemBackground.cgColor,
            UIColor.systemGray6.withAlphaComponent(0.3).cgColor
        ]
        backgroundGradient.locations = [0.0, 1.0]
        backgroundGradient.frame = view.bounds
        view.layer.insertSublayer(backgroundGradient, at: 0)

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
        pageControl.pageIndicatorTintColor = .systemGray4
        pageControl.currentPageIndicatorTintColor = .systemBlue
        pageControl.preferredIndicatorImage = UIImage(systemName: "circle.fill")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 8))
        if #available(iOS 14.0, *) {
            pageControl.backgroundStyle = .minimal
        }
        view.addSubview(pageControl)

        // Skip Button
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.setTitle("건너뛰기", for: .normal)
        skipButton.setTitleColor(.systemGray2, for: .normal)
        skipButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        view.addSubview(skipButton)

        // Next Button
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.setTitle("다음", for: .normal)
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)

        // 파란색 배경으로 통일
        nextButton.backgroundColor = UIColor.systemBlue
        nextButton.layer.cornerRadius = 25
        nextButton.layer.shadowColor = UIColor.systemBlue.cgColor
        nextButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        nextButton.layer.shadowRadius = 12
        nextButton.layer.shadowOpacity = 0.3

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

        // 페이지별 미세한 배경 효과
        let pageBackgroundView = UIView()
        pageBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        pageBackgroundView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.6)
        pageBackgroundView.layer.cornerRadius = 20
        pageView.addSubview(pageBackgroundView)

        // 아이콘 이미지뷰
        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.image = getIconForStep(step)
        iconImageView.tintColor = .systemBlue

        // 아이콘에 미세한 그림자 효과
        iconImageView.layer.shadowColor = UIColor.systemBlue.cgColor
        iconImageView.layer.shadowOffset = CGSize(width: 0, height: 2)
        iconImageView.layer.shadowRadius = 6
        iconImageView.layer.shadowOpacity = 0.2

        pageView.addSubview(iconImageView)

        // 타이틀 레이블
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = step.title
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
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
        descriptionLabel.lineBreakMode = .byWordWrapping

        // 줄간격 설정으로 가독성 향상 및 #Todays_Mood 파란색 그라데이션
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.alignment = .center

        let attributedText = NSMutableAttributedString(
            string: step.description,
            attributes: [
                .paragraphStyle: paragraphStyle,
                .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )

        // #Todays_Mood 부분에 예쁜 파란색 그라데이션 효과 적용
        if step == .bamboofriend {
            let todaysMoodRange = (step.description as NSString).range(of: "#Todays_Mood")
            if todaysMoodRange.location != NSNotFound {
                // 더 밝고 생생한 파란색과 그림자 효과
                attributedText.addAttributes([
                    .foregroundColor: UIColor.systemBlue,
                    .font: UIFont.systemFont(ofSize: 17, weight: .black),
                    .strokeColor: UIColor.systemBlue.withAlphaComponent(0.3),
                    .strokeWidth: -2.0,
                    .shadow: NSShadow()
                ], range: todaysMoodRange)

                // 그림자 효과 설정
                let shadow = NSShadow()
                shadow.shadowColor = UIColor.systemBlue.withAlphaComponent(0.4)
                shadow.shadowOffset = CGSize(width: 0, height: 1)
                shadow.shadowBlurRadius = 2
                attributedText.addAttribute(.shadow, value: shadow, range: todaysMoodRange)
            }
        }

        descriptionLabel.attributedText = attributedText

        pageView.addSubview(descriptionLabel)

        // 추가 컨텐츠 (특정 단계용)
        let additionalContent = createAdditionalContent(for: step)
        if let additionalView = additionalContent {
            pageView.addSubview(additionalView)
        }

        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: pageView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: pageView.centerYAnchor, constant: -120),
            iconImageView.widthAnchor.constraint(equalToConstant: 100),
            iconImageView.heightAnchor.constraint(equalToConstant: 100),

            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: pageView.leadingAnchor, constant: 30),
            titleLabel.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -30),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: pageView.leadingAnchor, constant: 30),
            descriptionLabel.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -30)
        ])

        // 추가 컨텐츠 제약조건
        if let additionalView = additionalContent {
            NSLayoutConstraint.activate([
                additionalView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 24),
                additionalView.leadingAnchor.constraint(equalTo: pageView.leadingAnchor, constant: 20),
                additionalView.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -20),
                additionalView.bottomAnchor.constraint(lessThanOrEqualTo: pageView.bottomAnchor, constant: -40)
            ])
        }

        return pageView
    }

    private func getIconForStep(_ step: OnboardingManager.OnboardingStep) -> UIImage? {
        switch step {
        case .welcome:
            return UIImage(systemName: "moon.stars.fill")
        case .mainFeatures:
            return UIImage(systemName: "square.grid.2x2.fill")
        case .bamboofriend:
            return UIImage(systemName: "message.circle.fill")
        case .getStarted:
            return UIImage(systemName: "checkmark.circle.fill")
        }
    }

    private func createAdditionalContent(for step: OnboardingManager.OnboardingStep) -> UIView? {
        switch step {
        case .mainFeatures:
            return createFeaturesPreview()
        case .bamboofriend:
            return nil  // 버블카드 제거하고 텍스트만 표시
        default:
            return nil
        }
    }

    private func createFeaturesPreview() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // 기능 미리보기 그리드 - 더 매력적인 디자인
        let features = [
            ("speaker.wave.2.fill", "수면 사운드", "편안한 잠자리를 위한\n다양한 사운드", UIColor.systemBlue),
            ("book.fill", "미니 다이어리", "감정 기록과\n친구의 분석", UIColor.systemGreen),
            ("sparkles", "오늘의 운세", "하루를 시작하는\n특별한 메시지", UIColor.systemOrange),
            ("gearshape.fill", "설정", "나만의 맞춤\n환경 설정", UIColor.systemPurple)
        ]

        let gridStackView = UIStackView()
        gridStackView.translatesAutoresizingMaskIntoConstraints = false
        gridStackView.axis = .vertical
        gridStackView.spacing = 16
        gridStackView.alignment = .fill
        gridStackView.distribution = .fillEqually

        // 2x2 그리드로 배치
        for i in stride(from: 0, to: features.count, by: 2) {
            let rowStackView = UIStackView()
            rowStackView.axis = .horizontal
            rowStackView.spacing = 20
            rowStackView.alignment = .top
            rowStackView.distribution = .fillEqually

            for j in i..<min(i+2, features.count) {
                let feature = features[j]
                let featureView = createFeatureItem(icon: feature.0, title: feature.1, description: feature.2, color: feature.3)
                rowStackView.addArrangedSubview(featureView)
            }

            gridStackView.addArrangedSubview(rowStackView)
        }

        container.addSubview(gridStackView)

        NSLayoutConstraint.activate([
            gridStackView.topAnchor.constraint(equalTo: container.topAnchor),
            gridStackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gridStackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            gridStackView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func createFeatureItem(icon: String, title: String, description: String, color: UIColor) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // 원형 배경 뷰 추가
        let iconBackgroundView = UIView()
        iconBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        iconBackgroundView.backgroundColor = color.withAlphaComponent(0.1)
        iconBackgroundView.layer.cornerRadius = 22

        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.image = UIImage(systemName: icon)
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = color

        // 아이콘에 미세한 그림자 효과
        iconImageView.layer.shadowColor = color.cgColor
        iconImageView.layer.shadowOffset = CGSize(width: 0, height: 1)
        iconImageView.layer.shadowRadius = 3
        iconImageView.layer.shadowOpacity = 0.3

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = color
        titleLabel.textAlignment = .center

        let descLabel = UILabel()
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.text = description
        descLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        descLabel.textColor = .secondaryLabel
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0

        container.addSubview(iconBackgroundView)
        iconBackgroundView.addSubview(iconImageView)
        container.addSubview(titleLabel)
        container.addSubview(descLabel)

        NSLayoutConstraint.activate([
            iconBackgroundView.topAnchor.constraint(equalTo: container.topAnchor),
            iconBackgroundView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconBackgroundView.widthAnchor.constraint(equalToConstant: 44),
            iconBackgroundView.heightAnchor.constraint(equalToConstant: 44),

            iconImageView.centerXAnchor.constraint(equalTo: iconBackgroundView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconBackgroundView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.topAnchor.constraint(equalTo: iconBackgroundView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            descLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            descLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func createBambooFriendPreview() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // 대나무숲 친구 미리보기 카드
        let cardView = UIView()
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = UIColor.systemGray6
        cardView.layer.cornerRadius = 16
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowRadius = 8
        cardView.layer.shadowOpacity = 0.1

        let chatBubbleView = UIView()
        chatBubbleView.translatesAutoresizingMaskIntoConstraints = false
        chatBubbleView.backgroundColor = .systemBlue
        chatBubbleView.layer.cornerRadius = 12

        let messageLabel = UILabel()
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = "안녕하세요! 😊\n저는 여러분의 대나무숲 친구예요\n오늘은 어떤 하루를 보내셨나요?\n\n💡 설정 탭에서 친구 말투 설정을 통해\n제 MBTI 성격을 바꿀 수 있어요!"
        messageLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        messageLabel.textColor = .white
        messageLabel.textAlignment = .left
        messageLabel.numberOfLines = 0

        // 줄간격 설정
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3
        let attributedText = NSAttributedString(
            string: messageLabel.text ?? "",
            attributes: [
                .paragraphStyle: paragraphStyle,
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: UIColor.white
            ]
        )
        messageLabel.attributedText = attributedText

        let actionButton = UIButton(type: .system)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.setTitle("💬 #Todays_Mood", for: .normal)
        actionButton.setTitleColor(.white, for: .normal)

        // 그라데이션 배경 설정
        let buttonGradient = CAGradientLayer()
        buttonGradient.colors = [UIColor.systemGreen.cgColor, UIColor.systemTeal.cgColor]
        buttonGradient.startPoint = CGPoint(x: 0, y: 0)
        buttonGradient.endPoint = CGPoint(x: 1, y: 0)
        buttonGradient.cornerRadius = 20
        actionButton.layer.insertSublayer(buttonGradient, at: 0)

        actionButton.layer.cornerRadius = 20
        actionButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        actionButton.isEnabled = false
        actionButton.alpha = 0.9

        // 버튼 그림자 효과
        actionButton.layer.shadowColor = UIColor.systemGreen.cgColor
        actionButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        actionButton.layer.shadowRadius = 6
        actionButton.layer.shadowOpacity = 0.3

        cardView.addSubview(chatBubbleView)
        chatBubbleView.addSubview(messageLabel)
        cardView.addSubview(actionButton)
        container.addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: container.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            cardView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15),
            cardView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            chatBubbleView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            chatBubbleView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            chatBubbleView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            messageLabel.topAnchor.constraint(equalTo: chatBubbleView.topAnchor, constant: 16),
            messageLabel.leadingAnchor.constraint(equalTo: chatBubbleView.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: chatBubbleView.trailingAnchor, constant: -16),
            messageLabel.bottomAnchor.constraint(equalTo: chatBubbleView.bottomAnchor, constant: -16),

            actionButton.topAnchor.constraint(equalTo: chatBubbleView.bottomAnchor, constant: 16),
            actionButton.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: 160),
            actionButton.heightAnchor.constraint(equalToConstant: 44),
            actionButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20)
        ])

        // 버튼 그라데이션 레이어 크기 설정
        DispatchQueue.main.async {
            if let buttonGradient = actionButton.layer.sublayers?.first as? CAGradientLayer {
                buttonGradient.frame = actionButton.bounds
            }
        }

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

        // 부드러운 스크롤 애니메이션
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3, options: .curveEaseInOut) {
            self.scrollView.setContentOffset(offset, animated: false)
        }
    }

    private func updateUI() {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.1, options: .curveEaseInOut) {
            self.pageControl.currentPage = self.currentPage
        }

        let isLastPage = currentPage == totalPages - 1
        let buttonTitle = isLastPage ? "시작하기 🚀" : "다음"

        // 버튼 텍스트 애니메이션
        UIView.transition(with: nextButton, duration: 0.3, options: .transitionCrossDissolve) {
            self.nextButton.setTitle(buttonTitle, for: .normal)
        }

        // 마지막 페이지에서는 스킵 버튼 부드럽게 숨김
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseInOut) {
            self.skipButton.alpha = isLastPage ? 0 : 1
            self.skipButton.transform = isLastPage ? CGAffineTransform(scaleX: 0.8, y: 0.8) : .identity
        } completion: { _ in
            self.skipButton.isHidden = isLastPage
        }

        // 버튼 스케일 애니메이션
        UIView.animate(withDuration: 0.4, delay: 0.1, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.3, options: .curveEaseInOut) {
            self.nextButton.transform = isLastPage ? CGAffineTransform(scaleX: 1.05, y: 1.05) : .identity
        }

        // 파란색 버튼은 별도 레이어 업데이트 불필요

        // 페이지별 색상 테마 변경
        updatePageTheme()
    }

    // MARK: - Animations
    private func animateEntrance() {
        // 초기 상태 설정
        nextButton.alpha = 0
        nextButton.transform = CGAffineTransform(translationX: 0, y: 50)
        skipButton.alpha = 0
        skipButton.transform = CGAffineTransform(translationX: 0, y: -30)
        pageControl.alpha = 0
        pageControl.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)

        // 순차적 입장 애니메이션
        UIView.animate(withDuration: 0.6, delay: 0.3, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseOut) {
            self.skipButton.alpha = 1
            self.skipButton.transform = .identity
        }

        UIView.animate(withDuration: 0.6, delay: 0.4, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseOut) {
            self.pageControl.alpha = 1
            self.pageControl.transform = .identity
        }

        UIView.animate(withDuration: 0.7, delay: 0.5, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.3, options: .curveEaseOut) {
            self.nextButton.alpha = 1
            self.nextButton.transform = .identity
        }

        // 첫 번째 페이지 콘텐츠 애니메이션
        animatePageContent(at: 0)
    }

    private func animatePageContent(at pageIndex: Int) {
        guard pageIndex < contentView.subviews.count else { return }

        let pageView = contentView.subviews[pageIndex]

        // 페이지 콘텐츠 애니메이션
        pageView.subviews.forEach { subview in
            if subview is UIImageView {
                subview.alpha = 0
                subview.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)

                UIView.animate(withDuration: 0.8, delay: 0.1, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.4, options: .curveEaseOut) {
                    subview.alpha = 1
                    subview.transform = .identity
                }
            } else if subview is UILabel {
                subview.alpha = 0
                subview.transform = CGAffineTransform(translationX: 0, y: 20)

                UIView.animate(withDuration: 0.6, delay: 0.2, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseOut) {
                    subview.alpha = 1
                    subview.transform = .identity
                }
            }
        }
    }

    private func updatePageTheme() {
        // 모든 페이지에서 파란색으로 통일
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseInOut) {
            self.pageControl.currentPageIndicatorTintColor = UIColor.systemBlue
            // 버튼은 이미 파란색으로 설정되어 있으므로 별도 변경 불필요
        }
    }
}

// MARK: - UIScrollViewDelegate
extension OnboardingViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let pageIndex = round(scrollView.contentOffset.x / view.frame.width)
        let newPage = Int(pageIndex)

        if newPage != currentPage {
            currentPage = newPage

            // 페이지 변경시 햅틱 피드백
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()

            // 부드러운 UI 업데이트
            DispatchQueue.main.async {
                self.updateUI()
            }
        }

        // 스크롤 진행률에 따른 시각적 효과
        let progress = scrollView.contentOffset.x / scrollView.contentSize.width
        pageControl.alpha = 0.6 + (0.4 * (1.0 - abs(progress - 0.5) * 2))
    }
}
