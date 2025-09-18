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
        case mainFeatures
        case bamboofriend
        case getStarted

        var title: String {
            switch self {
            case .welcome: return "반가워요! 😊"
            case .mainFeatures: return "이런 것들을 할 수 있어요"
            case .bamboofriend: return "특별한 친구를 소개할게요"
            case .getStarted: return "이제 시작해볼까요?"
            }
        }

        var description: String {
            switch self {
            case .welcome:
                return "여기서는 대나무숲 친구와 함께\n마음을 나누고 일상을 기록할 수 있어요"
            case .mainFeatures:
                return "🎵 편안한 수면 사운드\n📓 감정 일기 쓰기\n✨ 매일 새로운 운세\n⚙️ 나만의 설정\n\n모든 게 여러분을 위해 준비되어 있어요"
            case .bamboofriend:
                return "대나무숲 친구는 여러분의 마음을 이해하고\n따뜻한 조언을 해주는 특별한 친구예요\n\n#Todays_Mood 버튼을 눌러서\n언제든 대화를 나눠보세요!\n\n📱 Free 티어는 '온디바이스 모델'로만 대화해요.\n(설정 > 대나무숲 친구 설정에서 모델을 선택/설치할 수 있어요)\n\n✨ 설정 탭의 '친구 말투 설정'에서\n친구의 MBTI를 바꿀 수 있어요"
            case .getStarted:
                return "준비가 모두 끝났어요! 🎉\n이제 대나무숲 친구와 함께\n따뜻하고 평온한 하루를 만들어가요"
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
        // 기본 대나무숲 친구 모델 설정 (Free 티어 가이드에 따라 온디바이스로 기본 설정)
        SettingsManager.shared.selectedLLM = .onDevice

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
