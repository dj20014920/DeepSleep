//
//  OnboardingManager.swift
//  DeepSleep
//
//  Created on 2025-01-20.
//

import UIKit

/// 🎯 앱 전체 온보딩을 관리하는 중앙 매니저
class OnboardingManager {
    static let shared = OnboardingManager()

    // MARK: - Onboarding States
    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case appIntroduction
        case aiPersonaSetup
        case mainFeatures
        case soundExperience
        case emotionDiary
        case subscriptionIntro
        case completion

        var title: String {
            switch self {
            case .welcome: return "EmoZleep에 오신 것을 환영합니다"
            case .appIntroduction: return "앱 소개"
            case .aiPersonaSetup: return "대나무숲 친구 설정"
            case .mainFeatures: return "주요 기능 안내"
            case .soundExperience: return "사운드 체험"
            case .emotionDiary: return "감정 일기"
            case .subscriptionIntro: return "프리미엄 기능"
            case .completion: return "설정 완료"
            }
        }

        var description: String {
            switch self {
            case .welcome:
                return "대나무숲 친구와 함께하는 감정 기록과 일상 앱입니다"
            case .appIntroduction:
                return "EmoZleep은 당신의 감정을 이해하고 편안한 환경을 제공합니다"
            case .aiPersonaSetup:
                return "나만의 대나무숲 친구를 설정하여 더 개인적인 대화를 나눠보세요"
            case .mainFeatures:
                return "감정 분석, 수면 사운드 추천, 일기 작성 분석, 할 일 조언 등 다양한 기능을 만나보세요"
            case .soundExperience:
                return "현재 감정에 맞는 사운드를 대나무숲 친구가 추천해드립니다"
            case .emotionDiary:
                return "감정을 기록하고 대나무숲 친구와 함께 분석하며 마음의 안정을 찾으세요"
            case .subscriptionIntro:
                return "프리미엄 기능을 통해 더 많은 대나무숲 친구와 고급 기능을 이용해보세요"
            case .completion:
                return "이제 EmoZleep을 시작해보세요!"
            }
        }
    }

    // MARK: - Properties
    private let userDefaults = UserDefaults.standard
    private var currentStep: OnboardingStep = .welcome

    // MARK: - Public Methods

    /// 온보딩이 완료되었는지 확인
    var isOnboardingCompleted: Bool {
        get { userDefaults.bool(forKey: "onboardingCompleted") }
        set { userDefaults.set(newValue, forKey: "onboardingCompleted") }
    }

    /// 현재 온보딩 단계
    var currentOnboardingStep: OnboardingStep {
        get {
            let rawValue = userDefaults.integer(forKey: "currentOnboardingStep")
            return OnboardingStep(rawValue: rawValue) ?? .welcome
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: "currentOnboardingStep")
            currentStep = newValue
        }
    }

    /// 온보딩 시작
    func startOnboarding(from viewController: UIViewController) {
        guard !isOnboardingCompleted else { return }

        let onboardingVC = OnboardingViewController()
        onboardingVC.modalPresentationStyle = .fullScreen
        viewController.present(onboardingVC, animated: true)
    }

    /// 다음 단계로 진행
    func moveToNextStep() {
        guard let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) else {
            completeOnboarding()
            return
        }
        currentOnboardingStep = nextStep
    }

    /// 이전 단계로 돌아가기
    func moveToPreviousStep() {
        guard let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) else {
            return
        }
        currentOnboardingStep = previousStep
    }

    /// 온보딩 완료 처리
    func completeOnboarding() {
        isOnboardingCompleted = true
        currentOnboardingStep = .welcome

        // 첫 사용자를 위한 추가 설정
        setupFirstTimeUser()

        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
    }

    /// 온보딩 재시작 (설정에서)
    func restartOnboarding() {
        isOnboardingCompleted = false
        currentOnboardingStep = .welcome
    }

    // MARK: - Private Methods

    private func setupFirstTimeUser() {
        // 기본 대나무숲 친구 모델 설정 (초기값: Gemini)
        SettingsManager.shared.selectedLLM = .gemini

        // 기본 알림 설정
        SettingsManager.shared.notificationsMasterEnabled = true
        SettingsManager.shared.notificationsTimerEnabled = true

        // 웰컴 메시지 표시 플래그 초기화
        UserDefaults.standard.set(false, forKey: "HasShownChatOnboarding")
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
    static let onboardingStepChanged = Notification.Name("onboardingStepChanged")
}
