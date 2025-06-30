//
//  SceneDelegate.swift
//  DeepSleep
//
//  Created by 추동준 on 4/15/25.
//

import UIKit
import SwiftData

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    // MARK: - AI Services
    var aiOrchestrator: EnhancedUnifiedAIOrchestrator?

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
        
        // 🚀 AI 서비스 스택 초기화
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
        
        // 메인 화면 이동 노티피케이션 관찰
        NotificationCenter.default.addObserver(
            self, 
            selector: #selector(handleGoToMainScreen), 
            name: NSNotification.Name("GoToMainScreen"), 
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
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        
        // 📱 백그라운드 진입 시 채팅 기록 저장
        print("💾 [SceneDelegate] 백그라운드 진입 시 채팅 기록 보존 (ChatManager 자동 관리)")
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
        let mainVC = MainViewController()
        let navController = UINavigationController(rootViewController: mainVC)
        
        window.rootViewController = navController
        window.makeKeyAndVisible()
        
        // 프리셋 목록 화면 열기
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let presetListVC = PresetListViewController()
            
            // 프리셋 선택 시 메인 화면에 적용하는 콜백 설정 (버전 정보 포함)
            presetListVC.onPresetSelected = { [weak mainVC] preset in
                // URL로 가져온 프리셋은 적용만 하고, 로컬에 저장하거나 갱신하지 않음
                mainVC?.applyPreset(
                    volumes: preset.compatibleVolumes,
                    versions: preset.compatibleVersions,
                    name: preset.name,
                    presetId: nil,
                    saveAsNew: false
                )
            }
            
            navController.pushViewController(presetListVC, animated: true)
            
            // URL에서 받은 공유 코드 자동 입력
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                presetListVC.handleIncomingShareCode(shareCode)
            }
        }
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
    
    // MARK: - 메인 화면 전환
    func showMainInterface() {
        print("🚀🚀🚀 [SceneDelegate] showMainInterface() 호출됨 - 메인 인터페이스 전환 시작")
        
        // TabBarController 생성
        let tabBarController = UITabBarController()

        // 1. 메인 사운드 화면 (MainViewController)
        let mainVC = MainViewController()
        mainVC.aiOrchestrator = self.aiOrchestrator
        
        let mainNav = UINavigationController(rootViewController: mainVC)
        mainNav.navigationBar.prefersLargeTitles = true
        mainNav.tabBarItem = UITabBarItem(title: "사운드", image: UIImage(systemName: "speaker.wave.2.fill"), tag: 0)

        // 2. 일기 목록 화면 (EmotionDiaryViewController)
        let diaryVC = EmotionDiaryViewController()
        let diaryNav = UINavigationController(rootViewController: diaryVC)
        diaryNav.navigationBar.prefersLargeTitles = true
        diaryNav.tabBarItem = UITabBarItem(title: "일기목록", image: UIImage(systemName: "book.fill"), tag: 1)
        
        // 3. 오늘의 운세 화면 (TodaysFortuneViewController)
        let fortuneVC = TodaysFortuneViewController()
        let fortuneNav = UINavigationController(rootViewController: fortuneVC)
        fortuneNav.navigationBar.prefersLargeTitles = true
        fortuneNav.tabBarItem = UITabBarItem(title: "오늘의 운세", image: UIImage(systemName: "sparkles"), tag: 2)
        
        // TabBarController에 뷰 컨트롤러들 설정
        tabBarController.viewControllers = [mainNav, diaryNav, fortuneNav]
        tabBarController.selectedIndex = 0 // 기본으로 첫 번째 탭 선택

        // 현재 윈도우의 루트 뷰 컨트롤러를 탭바 컨트롤러로 교체
                self.window?.rootViewController = tabBarController
        self.window?.makeKeyAndVisible()
        
        print("✅ [SceneDelegate] 메인 인터페이스(TabBarController)로 전환 완료")
    }

    // MARK: - AI 서비스 초기화
    
    private func setupAIServices() {
        // AppDelegate에 생성된 공유 ModelContainer에서 ModelContext를 가져옴
        let modelContext = AppDelegate.sharedModelContainer.mainContext
        
        // 1. PersonaMemoryManager 초기화
        let personaMemoryManager = PersonaMemoryManager(modelContext: modelContext)
        
        // 2. EnhancedUnifiedAIOrchestrator 초기화 (PersonaMemoryManager 주입)
        let orchestrator = EnhancedUnifiedAIOrchestrator(memoryManager: personaMemoryManager)
        
        // 3. SceneDelegate의 프로퍼티에 할당
        self.aiOrchestrator = orchestrator
        
        print("✅ [SceneDelegate] AI 서비스 스택 초기화 완료")
    }
}

