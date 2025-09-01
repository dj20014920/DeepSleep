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

class OptimizedTabBarController: UITabBarController, UITabBarControllerDelegate, UIGestureRecognizerDelegate {
    
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
            leftSwipe.delegate = self // 델리게이트 설정
            view.addGestureRecognizer(leftSwipe)
            swipeGestureRecognizers.append(leftSwipe)
            
            // 우측 스와이프 (이전 탭으로)
            let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
            rightSwipe.direction = .right
            rightSwipe.delegate = self // 델리게이트 설정
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

// MARK: - UIGestureRecognizerDelegate
extension OptimizedTabBarController {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // 터치 위치가 테이블뷰나 컬렉션뷰 내부인지 확인
        let touchPoint = touch.location(in: view)
        let hitView = view.hitTest(touchPoint, with: nil)
        
        // UITableView나 그 서브뷰에서 발생한 터치인지 확인
        var currentView = hitView
        while currentView != nil {
            if currentView is UITableView {
                // 테이블뷰 내부에서는 탭 스와이프 제스처 비활성화
                return false
            }
            // UICollectionView 내부의 UITableView도 처리
            if currentView is UICollectionView {
                // 컴렉션뷰 내부에 TodoListCell이 있을 수 있음
                if let collectionView = currentView as? UICollectionView {
                    let cellPoint = touch.location(in: collectionView)
                    if let indexPath = collectionView.indexPathForItem(at: cellPoint),
                       let cell = collectionView.cellForItem(at: indexPath) {
                        // TodoListCell 내부의 UITableView 확인
                        let cellLocalPoint = touch.location(in: cell)
                        
                        // TodoListCell 타입 확인
                        if String(describing: type(of: cell)).contains("TodoListCell") {
                            UnifiedLogger.shared.debug("TodoListCell 내부에서 탭 스와이프 제스처 비활성화", category: .ui)
                            return false
                        }
                        
                        // 재귀적으로 UITableView 찾기
                        func findTableView(in view: UIView) -> UITableView? {
                            if let tableView = view as? UITableView {
                                return tableView
                            }
                            for subview in view.subviews {
                                if let foundTableView = findTableView(in: subview) {
                                    return foundTableView
                                }
                            }
                            return nil
                        }
                        
                        if let tableView = findTableView(in: cell) {
                            let tableFrame = tableView.frame
                            if tableFrame.contains(cellLocalPoint) {
                                UnifiedLogger.shared.debug("테이블뷰 영역에서 탭 스와이프 제스처 비활성화", category: .ui)
                                return false // TodoListCell의 테이블뷰에서는 탭 스와이프 비활성화
                            }
                        }
                    }
                }
            }
            currentView = currentView?.superview
        }
        
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 테이블뷰의 스와이프 액션과 동시에 인식되지 않도록 설정
        return false
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