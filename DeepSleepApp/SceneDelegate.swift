//
//  SceneDelegate.swift
//  DeepSleep
//
//  Created by 추동준 on 4/15/25.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    // MARK: - AI Services
    // var aiOrchestrator: EnhancedUnifiedAIOrchestrator? // TODO: Implement this type or remove

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
        // setupAIServices() // TODO: Uncomment when EnhancedUnifiedAIOrchestrator is implemented
        
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
        
        // 🔧 메모리 최적화: 실시간 전환 요소들 정리
        cleanupTransition()
        isAnimating = false
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
    
    // MARK: - 메인 화면 전환
    func showMainInterface() {
        print("🚀🚀🚀 [SceneDelegate] showMainInterface() 호출됨 - 메인 인터페이스 전환 시작")
        
        // TabBarController 생성
        let tabBarController = UITabBarController()

        // 1. 메인 사운드 화면 (ViewController)
        let mainVC = ViewController()
        // aiOrchestrator는 읽기 전용이므로 직접 할당 제거
        // mainVC.aiOrchestrator = self.aiOrchestrator
        
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
        
        // 4. 설정 화면 (SettingsViewController)
        let settingsVC = SettingsViewController()
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        settingsNav.navigationBar.prefersLargeTitles = true
        settingsNav.tabBarItem = UITabBarItem(title: "설정", image: UIImage(systemName: "gearshape.fill"), tag: 3)
        
        // TabBarController에 뷰 컨트롤러들 설정
        tabBarController.viewControllers = [mainNav, diaryNav, fortuneNav, settingsNav]
        tabBarController.selectedIndex = 0 // 기본으로 첫 번째 탭 선택
        
        // 🚀 모든 탭의 뷰를 미리 로딩 (스와이프 성능 향상)
        preloadAllTabViews(tabBarController: tabBarController)
        
        // 스와이프 제스처로 탭 전환 설정
        setupTabBarSwipeGestures(for: tabBarController)

        // 현재 윈도우의 루트 뷰 컨트롤러를 탭바 컨트롤러로 교체
        self.window?.rootViewController = tabBarController
        self.window?.makeKeyAndVisible()
        
        print("✅ [SceneDelegate] 메인 인터페이스(TabBarController)로 전환 완료")
    }

    // MARK: - 탭 뷰 미리 로딩
    
    /// 모든 탭의 뷰를 미리 로딩하여 스와이프 성능 향상
    private func preloadAllTabViews(tabBarController: UITabBarController) {
        print("🚀 [PreLoading] 모든 탭의 뷰 미리 로딩 시작...")
        
        guard let viewControllers = tabBarController.viewControllers else {
            print("❌ [PreLoading] 뷰컨트롤러 배열이 없음")
            return
        }
        
        let startTime = Date()
        
        for (index, viewController) in viewControllers.enumerated() {
            let tabStartTime = Date()
            
            // NavigationController인 경우 내부의 실제 뷰컨트롤러에 접근
            let actualViewController: UIViewController
            if let navController = viewController as? UINavigationController,
               let rootViewController = navController.viewControllers.first {
                actualViewController = rootViewController
            } else {
                actualViewController = viewController
            }
            
            // 뷰를 강제로 로딩 (이때 viewDidLoad가 자동으로 호출됨)
            _ = actualViewController.view
            actualViewController.loadViewIfNeeded()
            
            let tabLoadTime = Date().timeIntervalSince(tabStartTime)
            let tabName = viewController.tabBarItem?.title ?? "알 수 없음"
            
            print("✅ [PreLoading] 탭 \(index) (\(tabName)) 로딩 완료 - \(Int(tabLoadTime * 1000))ms")
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        print("🎉 [PreLoading] 모든 탭 로딩 완료 - 총 소요시간: \(Int(totalTime * 1000))ms")
        
        // 🔧 PERF-WARNING: 모든 탭을 미리 로딩하므로 메모리 사용량 증가
        // 확인 방법: Instruments > Allocations에서 메모리 사용량 모니터링
        print("📊 [PreLoading] 메모리 사용량이 증가할 수 있지만, 스와이프 성능은 크게 향상됨")
    }
    
    // MARK: - AI 서비스 초기화
    
    private func setupAIServices() {
        // iOS availability 체크 추가
        if #available(iOS 17.0, *) {
            // ✅ ChatManager 기반 외부 AI 메모리 시스템 - 파라미터 없는 초기화
            let _ = PersonaMemoryManager()
            
            // 2. EnhancedUnifiedAIOrchestrator 초기화 (파라미터 없는 버전 사용)
            // TODO: Implement EnhancedUnifiedAIOrchestrator
            // let orchestrator = EnhancedUnifiedAIOrchestrator()
            
            // 3. SceneDelegate의 프로퍼티에 할당
            // self.aiOrchestrator = orchestrator
            
            print("✅ [SceneDelegate] AI 서비스 스택 초기화 완료 (iOS 17+)")
        } else {
            // iOS 17 미만에서는 기본 AI 서비스만 사용
            // TODO: Implement EnhancedUnifiedAIOrchestrator
            // let orchestrator = EnhancedUnifiedAIOrchestrator()
            // self.aiOrchestrator = orchestrator
            
            print("✅ [SceneDelegate] 기본 AI 서비스 초기화 완료 (iOS 16 호환)")
        }
    }
    
    // MARK: - TabBar Swipe Gestures
    
    private func setupTabBarSwipeGestures(for tabBarController: UITabBarController) {
        // Pan 제스처로 부드러운 전환 (메인 제스처)
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleTabPan(_:)))
        panGesture.delegate = self
        panGesture.maximumNumberOfTouches = 1 // 단일 터치만 허용
        panGesture.minimumNumberOfTouches = 1
        tabBarController.view.addGestureRecognizer(panGesture)
        
        // 빠른 스와이프 제스처 (백업용)
        let leftSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleTabSwipe(_:)))
        leftSwipeGesture.direction = .left
        leftSwipeGesture.delegate = self
        leftSwipeGesture.require(toFail: panGesture) // Pan 제스처가 실패할 때만 실행
        tabBarController.view.addGestureRecognizer(leftSwipeGesture)
        
        let rightSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleTabSwipe(_:)))
        rightSwipeGesture.direction = .right
        rightSwipeGesture.delegate = self
        rightSwipeGesture.require(toFail: panGesture) // Pan 제스처가 실패할 때만 실행
        tabBarController.view.addGestureRecognizer(rightSwipeGesture)
        
        print("✅ 탭바 스와이프 제스처 설정 완료 (Pan 우선순위)")
    }
    
    @objc private func handleTabSwipe(_ gesture: UISwipeGestureRecognizer) {
        guard let tabBarController = window?.rootViewController as? UITabBarController else { return }
        
        let currentIndex = tabBarController.selectedIndex
        let totalTabs = tabBarController.viewControllers?.count ?? 0
        
        var newIndex: Int
        
        switch gesture.direction {
        case .left:
            // 왼쪽 스와이프 - 다음 탭으로
            newIndex = (currentIndex + 1) % totalTabs
        case .right:
            // 오른쪽 스와이프 - 이전 탭으로
            newIndex = (currentIndex - 1 + totalTabs) % totalTabs
        default:
            return
        }
        
        // 햅틱 피드백
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // 카메라 뷰포트 시스템으로 통일된 전환
        isAnimating = true
        let screenWidth = tabBarController.view.bounds.width
        
        // 즉석에서 카메라 뷰포트 설정
        setupRealTimeTransition(tabBarController: tabBarController, translation: CGPoint.zero)
        
        // 스와이프 방향에 따른 목표 위치 계산
        let targetTranslation: CGPoint
        if gesture.direction == .left {
            targetTranslation = CGPoint(x: -screenWidth, y: 0) // 왼쪽으로 스와이프하면 다음 탭으로
        } else {
            targetTranslation = CGPoint(x: screenWidth, y: 0) // 오른쪽으로 스와이프하면 이전 탭으로
        }
        
        // 즉시 전환 완료
        finishRealTimeTransition(
            tabBarController: tabBarController, 
            to: newIndex, 
            translation: targetTranslation, 
            screenWidth: screenWidth
        )
    }
    
    @objc private func handleTabPan(_ gesture: UIPanGestureRecognizer) {
        guard let tabBarController = window?.rootViewController as? UITabBarController else { return }
        
        let translation = gesture.translation(in: tabBarController.view)
        let velocity = gesture.velocity(in: tabBarController.view)
        let totalTabs = tabBarController.viewControllers?.count ?? 0
        let screenWidth = tabBarController.view.bounds.width
        let currentIndex = tabBarController.selectedIndex
        
        switch gesture.state {
        case .began:
            // 실시간 전환을 위한 준비
            isAnimating = true
            setupRealTimeTransition(tabBarController: tabBarController, translation: translation)
            
            // 시작 햅틱 피드백
            let selectionFeedback = UISelectionFeedbackGenerator()
            selectionFeedback.selectionChanged()
            
        case .changed:
            // 실시간으로 페이지 전환 효과 업데이트
            updateRealTimeTransition(tabBarController: tabBarController, translation: translation, screenWidth: screenWidth)
            
            // 진행 상황에 따른 햅틱 피드백
            let progress = abs(translation.x) / screenWidth
            if progress > 0.3 && !hasGivenProgressFeedback {
                let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                impactFeedback.impactOccurred()
                hasGivenProgressFeedback = true
            }
            
        case .ended, .cancelled:
            hasGivenProgressFeedback = false
            
            // 전환 결정 로직 (더 부드러운 임계값)
            let progress = abs(translation.x) / screenWidth
            let velocityFactor = abs(velocity.x) / 1000.0
            let shouldTransition = progress > 0.15 || velocityFactor > 0.5  // 더 민감하게
            
            if shouldTransition && totalTabs > 1 {
                let newIndex: Int
                if translation.x < 0 { // 왼쪽 스와이프 - 다음 탭
                    newIndex = (currentIndex + 1) % totalTabs
                } else { // 오른쪽 스와이프 - 이전 탭
                    newIndex = (currentIndex - 1 + totalTabs) % totalTabs
                }
                
                // 전환 완료 애니메이션
                finishRealTimeTransition(tabBarController: tabBarController, to: newIndex, translation: translation, screenWidth: screenWidth)
                
                // 성공 햅틱 피드백
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
            } else {
                // 원래 상태로 복원 애니메이션
                cancelRealTimeTransition(tabBarController: tabBarController, translation: translation, screenWidth: screenWidth)
                
                // 취소 햅틱 피드백
                let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                impactFeedback.impactOccurred()
            }
            
        default:
            break
        }
    }
    
    // 진행 상황 햅틱 피드백 플래그
    private var hasGivenProgressFeedback = false
    
    
    // 애니메이션 중복 실행 방지 플래그
    private var isAnimating = false
    
    // 카메라 뷰포트 스타일 전환을 위한 변수들
    private var continuousScrollContainer: UIView?
    private var tabViewControllers: [UIViewController] = []
    private var viewportContainer: UIView?
    private var initialIndex: Int = 0
    private var currentOffset: CGFloat = 0
    
    // 레거시 스냅샷 시스템 변수들 (하위 호환성)
    private var currentSnapshot: UIView?
    private var nextSnapshot: UIView?
    private var previousSnapshot: UIView?
    private var transitionContainer: UIView?
    
    // MARK: - 카메라 뷰포트 스타일 연속 스크롤 전환
    
    /// 클래식 슬라이드 전환 준비 (현재 페이지 + 다음 페이지만 사용)
    private func setupRealTimeTransition(tabBarController: UITabBarController, translation: CGPoint) {
        let currentIndex = tabBarController.selectedIndex
        let totalTabs = tabBarController.viewControllers?.count ?? 0
        let containerView = tabBarController.view!
        let screenWidth = containerView.bounds.width
        let screenHeight = containerView.bounds.height
        let tabBarHeight = tabBarController.tabBar.frame.height
        
        initialIndex = currentIndex
        
        // 기존 전환 요소들 정리
        cleanupTransition()
        
        // 전환 컨테이너 생성 (탭바 위쪽 전체 영역)
        let transitionContainer = UIView(frame: CGRect(
            x: 0, 
            y: 0, 
            width: screenWidth, 
            height: screenHeight - tabBarHeight
        ))
        transitionContainer.clipsToBounds = true
        transitionContainer.backgroundColor = UIColor.systemBackground
        self.transitionContainer = transitionContainer
        
        // 탭바 위에 전환 컨테이너 삽입
        containerView.insertSubview(transitionContainer, belowSubview: tabBarController.tabBar)
        
        tabViewControllers = tabBarController.viewControllers ?? []
        
        // 스와이프 방향에 따라 현재 페이지와 다음/이전 페이지 결정
        let nextIndex: Int
        let isSwipingLeft = translation.x < 0
        
        if isSwipingLeft {
            // 왼쪽 스와이프 -> 다음 탭으로
            nextIndex = (currentIndex + 1) % totalTabs
        } else {
            // 오른쪽 스와이프 -> 이전 탭으로
            nextIndex = (currentIndex - 1 + totalTabs) % totalTabs
        }
        
        // 현재 페이지 뷰 설정
        if let currentViewController = tabViewControllers[safe: currentIndex],
           let currentView = currentViewController.view {
            
            // 기존 부모에서 제거
            if currentView.superview != nil {
                currentView.removeFromSuperview()
            }
            
            // 전환 컨테이너에 현재 페이지 추가 (초기 위치: 중앙)
            currentView.frame = CGRect(x: 0, y: 0, width: screenWidth, height: transitionContainer.bounds.height)
            transitionContainer.addSubview(currentView)
            self.currentSnapshot = currentView // 참조 저장
            
            print("📱 현재 페이지(\(currentIndex)) 설정 완료")
        }
        
        // 다음 페이지 뷰 설정
        if let nextViewController = tabViewControllers[safe: nextIndex],
           let nextView = nextViewController.view {
            
            // 기존 부모에서 제거
            if nextView.superview != nil {
                nextView.removeFromSuperview()
            }
            
            // 전환 컨테이너에 다음 페이지 추가
            let initialX = isSwipingLeft ? screenWidth : -screenWidth // 화면 밖에서 시작
            nextView.frame = CGRect(x: initialX, y: 0, width: screenWidth, height: transitionContainer.bounds.height)
            transitionContainer.addSubview(nextView)
            
            if isSwipingLeft {
                self.nextSnapshot = nextView
            } else {
                self.previousSnapshot = nextView
            }
            
            // 🚀 뷰는 이미 미리 로딩되어 있으므로 즉시 사용 가능
            print("📱 다음 페이지(\(nextIndex)) 설정 완료 - 초기 위치: \(initialX) (미리 로딩됨)")
        }
        
        print("✅ 클래식 슬라이드 전환 준비 완료")
        print("   📐 전환 컨테이너: \(transitionContainer.frame)")
        print("   🔄 \(currentIndex) -> \(nextIndex) (스와이프 \(isSwipingLeft ? "왼쪽" : "오른쪽"))")
    }
    
    /// 클래식 슬라이드 실시간 업데이트 (현재 페이지와 다음 페이지가 점진적으로 전환)
    private func updateRealTimeTransition(tabBarController: UITabBarController, translation: CGPoint, screenWidth: CGFloat) {
        guard let currentView = currentSnapshot,
              let transitionContainer = transitionContainer else { return }
        
        // 🔧 PERF-WARNING: 실시간 업데이트로 인한 CPU 부하 주의
        // 확인 방법: Instruments > Core Animation에서 프레임 드롭 모니터링
        
        let progress = abs(translation.x) / screenWidth
        let clampedProgress = min(progress, 1.0) // 최대 100%로 제한
        
        // 스와이프 방향 결정
        let isSwipingLeft = translation.x < 0
        
        // 현재 페이지 위치 업데이트 (스와이프 방향으로 이동)
        let currentX = translation.x
        currentView.frame.origin.x = currentX
        
        // 다음 페이지 위치 업데이트
        if isSwipingLeft && nextSnapshot != nil {
            // 왼쪽 스와이프: 다음 페이지가 오른쪽에서 들어옴
            let nextX = screenWidth + translation.x // 오른쪽에서 시작해서 점진적으로 중앙으로
            nextSnapshot?.frame.origin.x = nextX
            
            print("📱 왼쪽 스와이프 - 현재: \(currentX), 다음: \(nextX), 진행도: \(Int(clampedProgress * 100))%")
            
        } else if !isSwipingLeft && previousSnapshot != nil {
            // 오른쪽 스와이프: 이전 페이지가 왼쪽에서 들어옴
            let prevX = -screenWidth + translation.x // 왼쪽에서 시작해서 점진적으로 중앙으로
            previousSnapshot?.frame.origin.x = prevX
            
            print("📱 오른쪽 스와이프 - 현재: \(currentX), 이전: \(prevX), 진행도: \(Int(clampedProgress * 100))%")
        }
        
        // 부드러운 전환을 위한 미묘한 시각 효과 (선택적)
        if clampedProgress > 0.1 {
            // 스와이프 진행도에 따른 미묘한 그림자 효과
            transitionContainer.layer.shadowOpacity = Float(clampedProgress * 0.15)
            transitionContainer.layer.shadowOffset = CGSize(width: isSwipingLeft ? -2 : 2, height: 0)
            transitionContainer.layer.shadowRadius = 8
        } else {
            transitionContainer.layer.shadowOpacity = 0
        }
    }
    
    /// 클래식 슬라이드 전환 완료 애니메이션
    private func finishRealTimeTransition(tabBarController: UITabBarController, to newIndex: Int, translation: CGPoint, screenWidth: CGFloat) {
        guard let currentView = currentSnapshot,
              let transitionContainer = transitionContainer else {
            isAnimating = false
            return
        }
        
        let isSwipingLeft = translation.x < 0
        let targetView = isSwipingLeft ? nextSnapshot : previousSnapshot
        
        // 전환 완료 애니메이션
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.8,
            options: [.curveEaseOut, .allowUserInteraction]
        ) {
            // 현재 페이지를 화면 밖으로 슬라이드
            if isSwipingLeft {
                currentView.frame.origin.x = -screenWidth // 왼쪽으로 완전히 나감
                targetView?.frame.origin.x = 0 // 다음 페이지가 중앙으로
            } else {
                currentView.frame.origin.x = screenWidth // 오른쪽으로 완전히 나감  
                targetView?.frame.origin.x = 0 // 이전 페이지가 중앙으로
            }
            
            // 그림자 효과 제거
            transitionContainer.layer.shadowOpacity = 0
            
        } completion: { _ in
            // 실제 탭 전환
            tabBarController.selectedIndex = newIndex
            
            // 뷰 상태 정리 및 원래 구조로 복원
            self.restoreOriginalTabStructure(tabBarController: tabBarController)
            
            print("✅ 클래식 슬라이드 전환 완료: \(self.initialIndex) → \(newIndex)")
        }
    }
    
    /// 클래식 슬라이드 전환 취소 애니메이션 (원래 상태로 복원)
    private func cancelRealTimeTransition(tabBarController: UITabBarController, translation: CGPoint, screenWidth: CGFloat) {
        guard let currentView = currentSnapshot,
              let transitionContainer = transitionContainer else {
            isAnimating = false
            return
        }
        
        let isSwipingLeft = translation.x < 0
        let targetView = isSwipingLeft ? nextSnapshot : previousSnapshot
        
        // 원래 위치로 부드럽게 복원
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.75,
            initialSpringVelocity: 0.5,
            options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            // 현재 페이지를 중앙으로 복원
            currentView.frame.origin.x = 0
            
            // 다음/이전 페이지를 화면 밖으로 되돌림
            if isSwipingLeft {
                targetView?.frame.origin.x = screenWidth // 다음 페이지를 오른쪽 밖으로
            } else {
                targetView?.frame.origin.x = -screenWidth // 이전 페이지를 왼쪽 밖으로
            }
            
            // 그림자 효과 제거
            transitionContainer.layer.shadowOpacity = 0
            
        } completion: { _ in
            // 뷰 상태 정리 및 원래 구조로 복원
            self.restoreOriginalTabStructure(tabBarController: tabBarController)
            
            print("↩️ 클래식 슬라이드 전환 취소됨")
        }
    }
    
    /// 원래 탭 구조로 복원 (클래식 슬라이드에서 정상 탭바 구조로)
    private func restoreOriginalTabStructure(tabBarController: UITabBarController) {
        // 🔧 PERF-WARNING: 뷰 계층 복원 시 메모리 누수 방지
        // 확인 방법: Instruments > Leaks에서 뷰 컨트롤러 참조 확인
        
        let selectedIndex = tabBarController.selectedIndex
        let containerView = tabBarController.view!
        let tabBarHeight = tabBarController.tabBar.frame.height
        
        // 모든 전환 뷰들을 전환 컨테이너에서 제거
        if let currentView = currentSnapshot {
            currentView.removeFromSuperview()
        }
        if let nextView = nextSnapshot {
            nextView.removeFromSuperview()
        }
        if let prevView = previousSnapshot {
            prevView.removeFromSuperview()
        }
        
        // 선택된 탭의 뷰만 정상 위치로 복원
        if let selectedViewController = tabViewControllers[safe: selectedIndex],
           let selectedView = selectedViewController.view {
            
            // 탭바를 제외한 전체 영역으로 프레임 설정
            selectedView.frame = CGRect(
                x: 0,
                y: 0,
                width: containerView.bounds.width,
                height: containerView.bounds.height - tabBarHeight
            )
            
            // 탭바 컨트롤러의 뷰 계층에 다시 추가
            containerView.insertSubview(selectedView, belowSubview: tabBarController.tabBar)
            
            // 🚀 뷰는 이미 미리 로딩되어 있으므로 생명주기 호출 최소화
            print("🔄 탭 \(selectedIndex) 뷰 복원 완료: \(selectedView.frame) (미리 로딩됨)")
        }
        
        // 🚀 모든 탭이 미리 로딩되어 있으므로 생명주기 관리 최소화
        
        // 전환 시스템 정리
        cleanupTransition()
        
        // 애니메이션 상태 초기화
        isAnimating = false
        
        print("🔄 원래 탭 구조로 복원 완료 - 현재 탭: \(selectedIndex)")
    }
    
    /// 카메라 뷰포트 전환 요소들 정리
    private func cleanupCameraTransition() {
        // 카메라 뷰포트 요소들 제거
        continuousScrollContainer?.removeFromSuperview()
        viewportContainer?.removeFromSuperview()
        
        // 변수 초기화
        continuousScrollContainer = nil
        viewportContainer = nil
        tabViewControllers = []
        currentOffset = 0
        initialIndex = 0
    }
    
    /// 클래식 슬라이드 전환 요소들 정리
    private func cleanupTransition() {
        // 전환 뷰들 제거
        currentSnapshot?.removeFromSuperview()
        nextSnapshot?.removeFromSuperview()
        previousSnapshot?.removeFromSuperview()
        transitionContainer?.removeFromSuperview()
        
        // 변수 초기화
        currentSnapshot = nil
        nextSnapshot = nil
        previousSnapshot = nil
        transitionContainer = nil
        tabViewControllers = []
        initialIndex = 0
        
        // 카메라 뷰포트 시스템도 정리 (하위 호환성)
        cleanupCameraTransition()
    }
}

// MARK: - UIGestureRecognizerDelegate
extension SceneDelegate: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 애니메이션 중일 때는 모든 제스처 비활성화
        if isAnimating { return false }
        
        // 스크롤뷰나 다른 상호작용 요소와의 충돌 방지
        if let view = otherGestureRecognizer.view {
            // UIScrollView나 UITableView, UICollectionView와는 동시 실행 금지
            if view is UIScrollView || 
               String(describing: type(of: view)).contains("ScrollView") ||
               String(describing: type(of: view)).contains("TableView") ||
               String(describing: type(of: view)).contains("CollectionView") {
                return false
            }
        }
        
        return false
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 애니메이션 중일 때는 새로운 제스처 비활성화
        if isAnimating { return false }
        
        // Pan 제스처의 경우 더 정교한 방향 감지
        if let panGesture = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = panGesture.velocity(in: panGesture.view)
            let translation = panGesture.translation(in: panGesture.view)
            
            // 수평 방향이 더 강하고, 최소 속도 조건을 만족할 때만 허용
            let isHorizontalSwipe = abs(velocity.x) > abs(velocity.y) * 1.5
            let hasMinimumVelocity = abs(velocity.x) > 100
            let hasMinimumTranslation = abs(translation.x) > 10
            
            return isHorizontalSwipe && (hasMinimumVelocity || hasMinimumTranslation)
        }
        
        // 스와이프 제스처는 항상 허용
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // 애니메이션 중일 때는 터치 무시
        if isAnimating { return false }
        
        // 탭바 자체를 터치한 경우에는 제스처 비활성화 (탭바 버튼 클릭 허용)
        if let view = touch.view, 
           String(describing: type(of: view)).contains("TabBar") ||
           view.superview is UITabBar {
            return false
        }
        
        return true
    }
}

// MARK: - Array Safe Access Extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
