//  SettingsViewController.swift
//  EmoZleep
//
//  Created on 2025-01-20.

import UIKit
import SwiftUI

/// 🛠️ 사용자 설정 화면
/// AI 모델 선택, 개인정보, 앱 설정 등을 관리하는 메인 설정 화면
class SettingsViewController: UIViewController {
    // 구독 상태는 SubscriptionUIBinder로 바인딩하여 DRY 유지

    // MARK: - UI Components

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()

    // 섹션들
    private var aiModelSection: SettingsSectionView!
    private var userInfoSection: SettingsSectionView!
    private var appSettingsSection: SettingsSectionView!
    private var aboutSection: SettingsSectionView!

    // MARK: - Properties

    private var selectedAIModel: AIModelType = .claude35
    private var userInfo: UserSettingsModel = UserSettingsModel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        loadCurrentSettings()
        // 구독 상태 바인딩(전역 통일 패턴)
        _ = SubscriptionUIBinder.attach(to: self) { [weak self] _ in
            self?.updateSubscriptionBadge()
        }
        updateSubscriptionBadge()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Settings 화면은 별도의 튜토리얼을 표시하지 않습니다(KISS/YAGNI).
    }

    // MARK: - Setup Methods

    private func setupUI() {
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground

        // ScrollView 설정
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        // ContentView 설정
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        // StackView 설정
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.alignment = .fill
        contentView.addSubview(stackView)

        // 섹션들 생성
        createSections()

        // 제약조건 설정
        setupConstraints()
    }

    private func setupNavigationBar() {
        title = "설정"
        navigationController?.navigationBar.prefersLargeTitles = true

        // 메인 설정 화면은 저장 버튼을 두지 않습니다(각 세부 화면에서 즉시 저장).
        navigationItem.rightBarButtonItem = nil
    }

    private func createSections() {
        // AI 모델 선택 섹션
        aiModelSection = SettingsSectionView(
            title: "🌳 대나무숲 친구 설정",
            subtitle: "대화에 사용할 친구를 선택하세요"
        )
        aiModelSection.delegate = self
        stackView.addArrangedSubview(aiModelSection)

        // 👤 사용자 정보 섹션
        userInfoSection = SettingsSectionView(
            title: "👤 사용자 정보",
            subtitle: "친구가 알고 있다면 좋은 정보"
        )
        userInfoSection.delegate = self
        stackView.addArrangedSubview(userInfoSection)

        // ⚙️ 앱 설정 섹션
        appSettingsSection = SettingsSectionView(
            title: "⚙️ 앱 설정",
            subtitle: "알림, 테마, 저장소 관리 등"
        )
        appSettingsSection.delegate = self
        stackView.addArrangedSubview(appSettingsSection)

        // ℹ️ 정보 섹션
        aboutSection = SettingsSectionView(
            title: "ℹ️ 앱 정보",
            subtitle: "버전, 개발자 정보, 피드백"
        )
        aboutSection.delegate = self
        stackView.addArrangedSubview(aboutSection)

        // 각 섹션에 항목들 추가
        setupSectionItems()
    }

    private func setupSectionItems() {
        // AI 모델 선택 항목들
        aiModelSection.addItem(SettingsItem(
            title: "대나무숲 친구",
            subtitle: selectedAIModel.displayName,
            type: .navigation,
            action: { [weak self] in
                self?.showAIModelSelection()
            }
        ))
        // 친구 말투 설정
        aiModelSection.addItem(SettingsItem(
            title: "친구 성격 설정",
            type: .navigation,
            action: { [weak self] in
                self?.showFriendToneSettings()
            }
        ))

        // 사용자 정보 항목들
        userInfoSection.addItem(SettingsItem(
            title: "기본 정보",
            subtitle: "이름, 나이, 성격 등",
            type: .navigation,
            action: { [weak self] in
                self?.showUserBasicInfo()
            }
        ))


        userInfoSection.addItem(SettingsItem(
            title: "사용 패턴 분석",
            subtitle: "대나무숲 친구가 분석한 나의 음악/프리셋 선호도",
            type: .navigation,
            action: { [weak self] in
                self?.showUsageAnalytics()
            }
        ))

        // 앱 설정 항목들
        appSettingsSection.addItem(SettingsItem(
            title: "🔐 권한 설정",
            subtitle: "알림, 캘린더, 건강 데이터 등 앱 권한 관리",
            type: .navigation,
            action: { [weak self] in
                self?.showPermissionSettings()
            }
        ))

        appSettingsSection.addItem(SettingsItem(
            title: "알림 설정",
            subtitle: "푸시 알림, 수면 리마인더",
            type: .navigation,
            action: { [weak self] in
                self?.showNotificationSettings()
            }
        ))

        appSettingsSection.addItem(SettingsItem(
            title: "저장소 관리",
            subtitle: "대화 데이터, 캐시 정리",
            type: .navigation,
            action: { [weak self] in
                self?.showStorageManagement()
            }
        ))

        // 앱 정보 항목들
        aboutSection.addItem(SettingsItem(
            title: "버전 정보",
            subtitle: "EmoZleep v1.0.0",
            type: .info,
            action: nil
        ))

        aboutSection.addItem(SettingsItem(
            title: "개발자 피드백",
            subtitle: "의견이나 문제점을 알려주세요",
            type: .navigation,
            action: { [weak self] in
                self?.showFeedback()
            }
        ))

        aboutSection.addItem(SettingsItem(
            title: "📚 정책 모음집",
            subtitle: "개인정보/이용약관/구독 관리/면책 고지",
            type: .navigation,
            action: { [weak self] in
                self?.showPolicyHub()
            }
        ))

        aboutSection.addItem(SettingsItem(
            title: "🎯 앱 다시보기",
            subtitle: "온보딩 및 튜토리얼 재시작",
            type: .navigation,
            action: { [weak self] in
                self?.showOnboardingRestart()
            }
        ))
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // ContentView
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // StackView
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }

    // MARK: - Data Methods

    private func loadCurrentSettings() {
        // SettingsManager에서 현재 설정 불러오기 - 통일된 방식 사용
        selectedAIModel = SettingsManager.shared.selectedLLM

        // 사용자 정보 불러오기
        userInfo = UserSettingsModel.loadFromUserDefaults()

        // UI 업데이트
        updateAIModelDisplay()
    }

    private func updateAIModelDisplay() {
        // AI 모델 섹션의 첫 번째 항목 업데이트
        aiModelSection.updateItem(at: 0, subtitle: selectedAIModel.displayName)
    }

    private func updateSubscriptionBadge() {
        // 요청사항: 상단 타이틀은 항상 "설정"으로 고정하고, 프로모션/상태 문구는 표시하지 않는다.
        self.title = "설정"
        // 상태 배지는 섹션 내부에서 필요 시 별도 라벨로 처리(YAGNI). 네비게이션 타이틀에는 반영하지 않음.
    }

    // MARK: - Action Methods

    // 메인 화면에서는 저장/확인 다이얼로그를 표시하지 않습니다.
}

// MARK: - Navigation Methods

extension SettingsViewController {

    private func showAIModelSelection() {
        // ✅ 대나무숲 친구 선택 화면을 별도 뷰컨트롤러로 표시
        let modelSelectionVC = AIModelSelectionViewController()
        modelSelectionVC.currentSelectedModel = selectedAIModel
        modelSelectionVC.onModelSelected = { [weak self] selectedModel in
            self?.selectedAIModel = selectedModel
            SettingsManager.shared.updateSelectedModelAtomically(selectedModel)
            self?.updateAIModelDisplay()
        }

        let navController = UINavigationController(rootViewController: modelSelectionVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    private func showFriendToneSettings() {
        let vc = FriendToneSettingsViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }
    private func showUserBasicInfo() {
        let basicInfoVC = UserBasicInfoViewController()
        basicInfoVC.userInfo = userInfo
        basicInfoVC.onInfoUpdated = { [weak self] updatedInfo in
            self?.userInfo = updatedInfo
            // 페르소나/기본 정보 변경 시 캐시 무효화
            AIContextManager.shared.clearCache(reason: .personaChanged, caller: "SettingsVC.userInfo")
        }
        navigationController?.pushViewController(basicInfoVC, animated: true)
    }

    private func showUsageAnalytics() {
        let analyticsVC = UsageAnalyticsViewController()
        navigationController?.pushViewController(analyticsVC, animated: true)
    }

    private func showPermissionSettings() {
        let permissionVC = PermissionSettingsViewController()
        navigationController?.pushViewController(permissionVC, animated: true)
    }

    private func showNotificationSettings() {
        let notificationVC = NotificationSettingsViewController()
        navigationController?.pushViewController(notificationVC, animated: true)
    }

    private func showStorageManagement() {
        let storageVC = StorageManagementViewController()
        navigationController?.pushViewController(storageVC, animated: true)
    }

    private func showThemeSettings() {
        let themeVC = ThemeSettingsViewController()
        navigationController?.pushViewController(themeVC, animated: true)
    }

    private func showFeedback() {
        let feedbackVC = FeedbackViewController()
        navigationController?.pushViewController(feedbackVC, animated: true)
    }

    private func showPolicyHub() {
        let hubVC = PolicyHubViewController()
        navigationController?.pushViewController(hubVC, animated: true)
    }

    private func showOnboardingRestart() {
        let alert = UIAlertController(
            title: "🎯 EmoZleep 둘러보기",
            message: "앱의 주요 기능들을 다시 한 번 살펴보시겠습니까?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "다시보기", style: .default) { [weak self] _ in
            // 온보딩 재시작
            OnboardingManager.shared.restartOnboarding()

            // 현재 화면을 닫고 온보딩 시작
            self?.dismiss(animated: true) {
                if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                    sceneDelegate.showOnboardingFirst()
                }
            }
        })

        alert.addAction(UIAlertAction(title: "취소", style: .cancel))

        present(alert, animated: true)
    }
}

// MARK: - SettingsSectionDelegate

extension SettingsViewController: SettingsSectionDelegate {
    func sectionDidUpdate(_ section: SettingsSectionView) {
        // 섹션 업데이트 처리
    }
}
