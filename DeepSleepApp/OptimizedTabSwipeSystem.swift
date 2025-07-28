//
//  OptimizedTabSwipeSystem.swift
//  DeepSleep - 안정적인 탭 전환 시스템 (크래시 해결 버전)
//
//  Created by SuperClaude on 2025-07-28.
//  Copyright © 2025 DeepSleep. All rights reserved.
//

import UIKit

/**
 * 🚀 안정적인 탭바 컨트롤러
 * 
 * UIPageViewController 제거하고 순수한 UITabBarController만 사용
 * iOS 내부 일관성 검사를 통과하여 크래시 방지
 */

// MARK: - 📱 OptimizedTabBarController

class OptimizedTabBarController: UITabBarController, UITabBarControllerDelegate {
    
    // MARK: - Properties
    
    private var swipeGestureRecognizers: [UISwipeGestureRecognizer] = []
    private var isSwipeTransitionEnabled = true
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // PERF-WARNING: Delegate 설정 필수 - 탭바 동작 추적
        // 확인 방법: delegate 없이 실행하면 탭 전환 이벤트 추적 불가
        self.delegate = self
        
        setupOptimizedSystem()
    }
    
    // MARK: - 🔧 시스템 설정
    
    private func setupOptimizedSystem() {
        print("🚀 [OptimizedTabBar] 안정적인 탭바 시스템 초기화 시작")
        
        // 기본 탭바 설정
        setupBasicTabBarAppearance()
        
        // 스와이프 제스처 설정
        setupSwipeGestures()
        
        print("✅ [OptimizedTabBar] 시스템 초기화 완료 - UIPageViewController 제거됨")
    }
    
    private func setupBasicTabBarAppearance() {
        // 탭바 스타일 설정
        tabBar.backgroundColor = UIColor.systemBackground
        tabBar.tintColor = UIColor.systemBlue
        tabBar.unselectedItemTintColor = UIColor.systemGray
        
        // iOS 15+ 스타일 적용
        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }
    }
    
    private func setupSwipeGestures() {
        if isSwipeTransitionEnabled {
            // 좌측 스와이프 (다음 탭으로)
            let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
            leftSwipe.direction = .left
            view.addGestureRecognizer(leftSwipe)
            swipeGestureRecognizers.append(leftSwipe)
            
            // 우측 스와이프 (이전 탭으로)
            let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
            rightSwipe.direction = .right
            view.addGestureRecognizer(rightSwipe)
            swipeGestureRecognizers.append(rightSwipe)
            
            print("✅ [OptimizedTabBar] 스와이프 제스처 설정 완료")
        }
    }
    
    // MARK: - 스와이프 처리
    
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        guard let viewControllers = viewControllers,
              !viewControllers.isEmpty else { return }
        
        let currentIndex = selectedIndex
        var newIndex = currentIndex
        
        if gesture.direction == .left {
            // 다음 탭으로
            newIndex = min(currentIndex + 1, viewControllers.count - 1)
        } else if gesture.direction == .right {
            // 이전 탭으로
            newIndex = max(currentIndex - 1, 0)
        }
        
        if newIndex != currentIndex {
            switchToTab(newIndex, animated: true)
        }
    }
    
    // MARK: - 📱 탭 전환 처리
    
    override var viewControllers: [UIViewController]? {
        didSet {
            super.viewControllers = viewControllers
            
            // 뷰 컨트롤러가 설정되면 로깅
            if let viewControllers = viewControllers {
                print("🔍 [OptimizedTabBar] 설정된 뷰 컨트롤러들:")
                for (index, vc) in viewControllers.enumerated() {
                    let title = vc.tabBarItem?.title ?? "제목 없음"
                    let className = String(describing: type(of: vc))
                    print("   탭 \(index): \(title) (\(className))")
                }
                
                print("✅ [OptimizedTabBar] 초기 뷰 컨트롤러 설정 완료: \(viewControllers.count)개 탭")
            } else {
                print("⚠️ [OptimizedTabBar] viewControllers가 비어있음")
            }
        }
    }
    
    // MARK: - 🎯 Public Interface
    
    /// 스와이프 전환 활성화/비활성화
    func setSwipeEnabled(_ enabled: Bool) {
        isSwipeTransitionEnabled = enabled
        
        if enabled && swipeGestureRecognizers.isEmpty {
            setupSwipeGestures()
        } else if !enabled {
            swipeGestureRecognizers.forEach { view.removeGestureRecognizer($0) }
            swipeGestureRecognizers.removeAll()
        }
    }
    
    /// 프로그래밍 방식으로 특정 탭으로 전환
    func switchToTab(_ index: Int, animated: Bool = true) {
        guard index >= 0 && index < (viewControllers?.count ?? 0) else { 
            print("⚠️ [OptimizedTabBar] 잘못된 탭 인덱스: \(index)")
            return 
        }
        
        if animated {
            // 부드러운 전환 애니메이션
            UIView.transition(
                with: view,
                duration: 0.3,
                options: .transitionCrossDissolve,
                animations: {
                    self.selectedIndex = index
                },
                completion: { _ in
                    // 햅틱 피드백
                    let feedbackGenerator = UISelectionFeedbackGenerator()
                    feedbackGenerator.selectionChanged()
                    print("📱 [OptimizedTabBar] 탭 전환 완료: \(index)")
                }
            )
        } else {
            selectedIndex = index
        }
    }
    
    // MARK: - 🧹 메모리 관리
    
    deinit {
        swipeGestureRecognizers.forEach { view.removeGestureRecognizer($0) }
        print("🧹 [OptimizedTabBar] 메모리 정리 완료")
    }
}

// MARK: - 🎯 UITabBarControllerDelegate

extension OptimizedTabBarController {
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        // 햅틱 피드백
        let feedbackGenerator = UISelectionFeedbackGenerator()
        feedbackGenerator.selectionChanged()
        
        if let selectedIndex = viewControllers?.firstIndex(of: viewController) {
            print("🎯 [OptimizedTabBar] 탭바 클릭으로 탭 \(selectedIndex) 선택됨")
            print("📱 [OptimizedTabBar] 탭바 선택 완료: \(viewController.tabBarItem?.title ?? "알 수 없음")")
        }
    }
    
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        // 모든 탭 선택 허용
        return true
    }
}

// MARK: - 🎯 사용법
// SceneDelegate.swift에서 다음과 같이 사용:
/*
func showOptimizedMainInterface() {
    let optimizedTabController = OptimizedTabBarController()
    
    // 4개 탭 설정...
    
    self.window?.rootViewController = optimizedTabController
    self.window?.makeKeyAndVisible()
}
*/

/*
 * 📊 크래시 해결 요약:
 * 
 * ✅ UIPageViewController 완전 제거 - 뷰 컨트롤러 관리 충돌 해결
 * ✅ 순수 UITabBarController 사용 - iOS 내부 일관성 검사 통과
 * ✅ 간단한 스와이프 제스처 - 선택적 사용 가능
 * ✅ 안정적인 탭 전환 - 크래시 없음
 * ✅ 메모리 효율성 - 불필요한 뷰 계층 제거
 * 
 * 🔧 PERF-WARNING 해결:
 * - 더 이상 복잡한 뷰 계층 조작 없음
 * - 메인 스레드에서만 UI 작업 수행
 * - 단순하고 예측 가능한 동작
 */