//
//  SceneDelegate.swift
//  EmoZleep
//
//  Created by 추동준 on 4/15/25.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    // MARK: - 🚨 Phase 3: AI Services 정리 완료
    // EnhancedUnifiedAIOrchestrator 제거 - UnifiedAIServiceImpl로 충분함

    func scene(_ scene: UIScene,
                   willConnectTo session: UISceneSession,
                   options connectionOptions: UIScene.ConnectionOptions) {
        #if DEBUG
        print("🟢 [SceneDelegate] scene(_:willConnectTo:) 호출됨, scene=\(scene), session=\(session)")
        #endif
        guard let windowScene = (scene as? UIWindowScene) else {
            #if DEBUG
            print("⚠️ [SceneDelegate] scene is not UIWindowScene, cannot create window")
            #endif
            return
        }
        #if DEBUG
        print("🟢 [SceneDelegate] 성공적으로 UIWindowScene 확인, window 생성 시작")
        #endif
        
        // 🚀 Phase 3: AI 서비스 스택 초기화 (간소화)
        setupAIServices()
        
        let window = UIWindow(windowScene: windowScene)

        // LaunchViewController만 루트로 설정
        window.rootViewController = LaunchViewController()
        self.window = window
        window.makeKeyAndVisible()
        #if DEBUG
        print("🟢 [SceneDelegate] LaunchViewController set as rootViewController and window made keyVisible")
        #endif
        
        // 만약 presented view controller가 있다면 dismiss
        if let presentedVC = window.rootViewController as? UITabBarController {
            presentedVC.selectedIndex = 0
            presentedVC.dismiss(animated: true)
            print("✅ 모달 뷰 dismiss 완료")
        }
        
        // 운세 알림을 통해 앱이 시작된 경우 처리
        if connectionOptions.notificationResponse?.notification.request.identifier == "DeepSleep.fortune" {
            print("🔔 운세 알림을 통해 앱 시작됨")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.handleGoToFortuneTab()
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        print("🟢 [SceneDelegate] Scene이 활성화됨")

        // SoundManager에게 Scene 활성화 알림
        SoundManager.shared.handleSceneStateChange(isActive: true)

        // 재생 상태 복원 (필요시)
        SoundManager.shared.restorePlaybackStateIfNeeded()

        // 홈 화면 아이콘은 항상 흰색으로 유지
        AppIconManager.enforceWhiteIcon()
        
        // 메인 화면 이동 노티피케이션 관찰
        NotificationCenter.default.addObserver(
            self, 
            selector: #selector(handleGoToMainScreen), 
            name: NSNotification.Name("GoToMainScreen"), 
            object: nil
        )
        
        // 운세 탭 이동 노티피케이션 관찰
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGoToFortuneTab),
            name: NSNotification.Name("GoToFortuneTab"),
            object: nil
        )
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        print("🔴 [SceneDelegate] Scene이 비활성화됨")
        
        // SoundManager에게 Scene 비활성화 알림
        SoundManager.shared.handleSceneStateChange(isActive: false)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Keep chat requests running smoothly in background
        print("💾 [SceneDelegate] 백그라운드 진입 - ChatRequestCenter 유지 및 복구 대비")
    }
    
    // MARK: - 노티피케이션 처리
    
    @objc private func handleGoToMainScreen() {
        print("📢 SceneDelegate에서 메인 화면 이동 노티피케이션 수신")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let window = self.window else { 
                print("❌ window 없음")
                return 
            }
            
            // 현재 루트 뷰컨트롤러가 탭바 컨트롤러인지 확인
            if let tabBarController = window.rootViewController as? UITabBarController {
                // 첫 번째 탭 (메인 화면)으로 이동
                tabBarController.selectedIndex = 0
                print("✅ 탭바 첫 번째 탭으로 이동 완료")
                
                // 만약 presented view controller가 있다면 dismiss
                if let presentedVC = tabBarController.presentedViewController {
                    presentedVC.dismiss(animated: true)
                    print("✅ 모달 뷰 dismiss 완료")
                }
            } else {
                // 탭바 컨트롤러가 아니라면 메인 인터페이스로 전환
                print("🔄 탭바 컨트롤러가 아니므로 메인 인터페이스로 전환")
                self.showMainInterface()
            }
        }
    }
    
    // 운세 탭으로 이동하는 함수
    @objc private func handleGoToFortuneTab() {
        print("📢 SceneDelegate에서 운세 탭 이동 노티피케이션 수신")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let window = self.window else {
                print("❌ window 없음")
                return
            }
            
            // 현재 루트 뷰컨트롤러가 탭바 컨트롤러인지 확인
            if let tabBarController = window.rootViewController as? UITabBarController {
                // 세 번째 탭 (오늘의 운세)으로 이동
                tabBarController.selectedIndex = 2
                print("✅ 탭바 세 번째 탭(오늘의 운세)으로 이동 완료")
                
                // 만약 presented view controller가 있다면 dismiss
                if let presentedVC = tabBarController.presentedViewController {
                    presentedVC.dismiss(animated: true)
                    print("✅ 모달 뷰 dismiss 완료")
                }
            } else {
                // 탭바 컨트롤러가 아니라면 메인 인터페이스로 전환 후 운세 탭으로 이동
                print("🔄 탭바 컨트롤러가 아니므로 메인 인터페이스로 전환 후 운세 탭으로 이동")
                self.showMainInterface()
                
                // 전환 후 운세 탭으로 이동
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let tabBarController = window.rootViewController as? UITabBarController {
                        tabBarController.selectedIndex = 2
                        print("✅ 탭바 세 번째 탭(오늘의 운세)으로 이동 완료")
                    }
                }
            }
        }
    }
    
    // MARK: - URL 스키마 처리
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        
        print("📱 URL 스키마 수신: \(url)")
        
        // emozleep:// 스키마 처리
        if url.scheme == "emozleep" && url.host == "preset" {
            handlePresetURL(url)
        }
    }
    
    private func handlePresetURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let dataItem = queryItems.first(where: { $0.name == "data" }),
              let shareCode = dataItem.value else {
            showURLError(message: "올바르지 않은 프리셋 링크입니다.")
            return
        }
        
        // PresetListViewController의 가져오기 기능 사용
        importPresetFromURL(shareCode: "emozleep://preset?data=\(shareCode)")
    }
    
    private func importPresetFromURL(shareCode: String) {
        guard let windowScene = window?.windowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }
        
        // 프리셋 가져오기 처리
        // 임시로 여기서 직접 처리하고, 나중에 PresetListViewController로 이동
        let alert = UIAlertController(
            title: "🎵 프리셋 링크 감지",
            message: "공유받은 프리셋을 가져오시겠습니까?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "가져오기", style: .default) { _ in
            // 프리셋 목록 화면으로 이동하여 처리
            self.navigateToPresetImport(shareCode: shareCode)
        })
        
        rootVC.present(alert, animated: true)
    }
    
    private func navigateToPresetImport(shareCode: String) {
        // 메인 뷰컨트롤러로 이동한 후 프리셋 목록 화면 열기
        guard let windowScene = window?.windowScene,
              let window = windowScene.windows.first else { return }
        
        // LaunchViewController에서 메인 화면으로 전환
        let mainVC = ViewController()
        let navController = UINavigationController(rootViewController: mainVC)
        
        window.rootViewController = navController
        window.makeKeyAndVisible()
        
        // 프리셋 목록 화면 열기
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            let presetListVC = PresetListViewController()
            
            // 프리셋 선택 시 메인 화면에 적용하는 콜백 설정 (버전 정보 포함)
            presetListVC.onPresetSelected = { [weak mainVC] preset in
                // URL로 가져온 프리셋은 적용만 하고, 로컬에 저장하거나 갱신하지 않음
                mainVC?.applyPreset(
                    volumes: preset.compatibleVolumes,
                    versions: preset.selectedVersions,
                    name: preset.name,
                    presetId: preset.id,
                    saveAsNew: false
                )
            }
            
            navController.pushViewController(presetListVC, animated: true)
            
            // URL에서 받은 공유 코드 자동 입력
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                presetListVC.handleIncomingShareCode(shareCode)
            })
        })
    }
    
    private func showURLError(message: String) {
        guard let windowScene = window?.windowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }
        
        let alert = UIAlertController(
            title: "프리셋 가져오기 오류",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        rootVC.present(alert, animated: true)
    }
    
    // MARK: - 메인 화면 전환 (최적화된 버전)
    func showMainInterface() {
        print("🚀🚀🚀 [SceneDelegate] 최적화된 메인 인터페이스 전환 시작")
        
        // 🎯 새로운 최적화된 탭바 컨트롤러 사용
        showOptimizedMainInterface()
    }
    
    /// 🚀 최적화된 메인 인터페이스 (안정적인 기본 탭바 시스템)
    func showOptimizedMainInterface() {
        print("🚀 [SceneDelegate] OptimizedTabBarController 적용")

        // 온보딩 체크 및 시작
        if !OnboardingManager.shared.isOnboardingCompleted {
            print("🎯 [SceneDelegate] 온보딩 미완료 - 온보딩 시작")
            showOnboardingFirst()
            return
        }

        // 최적화된 탭바 컨트롤러 생성
        let optimizedTabController = OptimizedTabBarController()
        
        // 1. 메인 사운드 화면 (ViewController)
        // 메인 사운드 화면 생성
        let mainVC = ViewController()
        let mainNav = UINavigationController(rootViewController: mainVC)
        mainNav.navigationBar.prefersLargeTitles = true
        mainNav.tabBarItem = UITabBarItem(title: "사운드", image: UIImage(systemName: "speaker.wave.2.fill"), tag: 0)
        print("✅ [SceneDelegate] 사운드 탭 생성 완료")
        
        // 2. 일기 목록 화면 (EmotionDiaryViewController)
        // 일기 목록 화면 생성
        let diaryVC = EmotionDiaryViewController()
        let diaryNav = UINavigationController(rootViewController: diaryVC)
        diaryNav.navigationBar.prefersLargeTitles = true
        diaryNav.tabBarItem = UITabBarItem(title: "미니 다이어리", image: UIImage(systemName: "book.fill"), tag: 1)
        print("✅ [SceneDelegate] 미니 다이어리 탭 생성 완료")
        
        // 3. 오늘의 운세 화면 (TodaysFortuneViewController)
        // 오늘의 운세 화면 생성
        let fortuneVC = TodaysFortuneViewController()
        let fortuneNav = UINavigationController(rootViewController: fortuneVC)
        fortuneNav.navigationBar.prefersLargeTitles = true
        fortuneNav.tabBarItem = UITabBarItem(title: "오늘의 운세", image: UIImage(systemName: "sparkles"), tag: 2)
        print("✅ [SceneDelegate] 오늘의 운세 탭 생성 완료")
        
        // 4. 설정 화면 (SettingsViewController)
        // 설정 화면 생성
        let settingsVC = SettingsViewController()
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        settingsNav.navigationBar.prefersLargeTitles = true
        settingsNav.tabBarItem = UITabBarItem(title: "설정", image: UIImage(systemName: "gearshape.fill"), tag: 3)
        print("✅ [SceneDelegate] 설정 탭 생성 완료")
        
        // 탭바 컨트롤러에 설정하기 전 배열 확인
        let allTabs = [mainNav, diaryNav, fortuneNav, settingsNav]
        print("🔍 [SceneDelegate] 생성된 탭 개수: \(allTabs.count)")
        for (index, tab) in allTabs.enumerated() {
            print("   탭 \(index): \(tab.tabBarItem?.title ?? "제목 없음")")
        }
        
        // 최적화된 탭바 컨트롤러에 뷰 컨트롤러들 설정
        optimizedTabController.viewControllers = allTabs
        optimizedTabController.selectedIndex = 0 // 기본으로 첫 번째 탭 선택
        
        // 현재 윈도우의 루트 뷰 컨트롤러를 최적화된 탭바 컨트롤러로 교체
        self.window?.rootViewController = optimizedTabController
        self.window?.makeKeyAndVisible()
        
        print("✅ [SceneDelegate] 안정적인 메인 인터페이스 전환 완료")
        print("🎯 [안정성] iOS 기본 탭바 + 간단한 스와이프 제스처 적용됨")
    }

    // MARK: - 🧹 레거시 코드 정리 완료
    // 복잡한 스와이프 시스템은 SimpleTabBarController로 대체됨
    
    // MARK: - 🚨 Phase 3: AI 서비스 초기화 (간소화 완료)
    
    private func setupAIServices() {
        print("🚀 [SceneDelegate] AI 서비스 초기화 시작")

        // SessionManager 초기화는 메인 전환 이후 백그라운드로 지연하여 UI 전환을 방해하지 않음
        DispatchQueue.global(qos: .background).async {
            _ = SessionManager.shared
            print("✅ [SceneDelegate] SessionManager 초기화 완료")
        }

        // iOS 17+ 전용 기능 (선택): 초기 화면 전환을 우선하기 위해 약간 지연 실행
        if #available(iOS 17.0, *) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if NSClassFromString("PersonaMemoryManager") != nil {
                    _ = PersonaMemoryManager()
                    print("✅ [SceneDelegate] PersonaMemoryManager 초기화 완료 (iOS 17+)")
                }
            }
        }

        print("🎉 [SceneDelegate] AI 서비스 초기화 예약 완료")
    }
    
    // MARK: - 🧹 레거시 스와이프 코드 모두 제거됨
    // OptimizedTabBarController가 모든 스와이프 기능을 대체
    
}

// MARK: - 🎯 온보딩 관리

extension SceneDelegate {
    /// 🎯 온보딩 우선 표시
    func showOnboardingFirst() {
        print("🎯 [SceneDelegate] 리플릿(Leaflet) 온보딩 화면 표시")

        let onboardingVC = OnboardingViewController()
        onboardingVC.modalPresentationStyle = .fullScreen

        // 현재 window의 rootViewController가 있다면 그 위에 표시
        if let window = self.window,
           let rootVC = window.rootViewController {
            rootVC.present(onboardingVC, animated: true)
        } else {
            // window가 아직 설정되지 않은 경우
            let tempVC = UIViewController()
            tempVC.view.backgroundColor = .black
            self.window?.rootViewController = tempVC
            tempVC.present(onboardingVC, animated: true)
        }
    }
}

/*
 * 🧹 레거시 코드 정리 완료
 * 
 * 제거된 항목들:
 * - 복잡한 스와이프 제스처 처리 (500+ 라인)
 * - 뷰 계층 조작 시스템
 * - 메모리 누수 위험 코드
 * - 성능 저하 요소들
 * 
 * ✅ SimpleTabBarController로 모든 기능이 안정적으로 대체됨:
 * - UIPageViewController 기반 안정적 전환
 * - 메모리 최적화 뷰 미리 로딩
 * - 네이티브 스와이프 애니메이션
 * - 햅틱 피드백 최적화
 */
