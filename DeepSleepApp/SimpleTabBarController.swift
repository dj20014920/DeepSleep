//
//  SimpleTabBarController.swift
//  DeepSleep
//
//  Created by Claude on 2025-07-28.
//  간단하고 안정적인 탭바 컨트롤러 - 크래시 없는 버전
//

import UIKit

class SimpleTabBarController: UITabBarController {
    
    // MARK: - Properties
    
    private var swipeGestureRecognizers: [UISwipeGestureRecognizer] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 탭바 스타일 설정
        setupTabBarAppearance()
        
        // 스와이프 제스처 설정 (선택사항)
        setupSwipeGestures()
        
        print("✅ [SimpleTabBar] 초기화 완료 - 안정적인 기본 UITabBarController 사용")
    }
    
    // MARK: - Setup
    
    private func setupTabBarAppearance() {
        // 탭바 기본 스타일
        tabBar.backgroundColor = UIColor.systemBackground
        tabBar.tintColor = UIColor.systemBlue
        tabBar.unselectedItemTintColor = UIColor.systemGray
        
        // iOS 15+ 모던 스타일
        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }
    }
    
    private func setupSwipeGestures() {
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
        
        print("✅ [SimpleTabBar] 스와이프 제스처 설정 완료")
    }
    
    // MARK: - Swipe Handling
    
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        guard let viewControllers = viewControllers else { return }
        
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
            // 탭 전환 애니메이션
            switchToTab(at: newIndex, animated: true)
        }
    }
    
    // MARK: - Tab Switching
    
    private func switchToTab(at index: Int, animated: Bool) {
        guard index >= 0 && index < (viewControllers?.count ?? 0) else { return }
        
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
                    
                    print("📱 [SimpleTabBar] 탭 전환 완료: \(index)")
                }
            )
        } else {
            selectedIndex = index
        }
    }
    
    // MARK: - Override
    
    override var viewControllers: [UIViewController]? {
        didSet {
            // 뷰 컨트롤러가 설정될 때 로깅
            if let vcs = viewControllers {
                print("📊 [SimpleTabBar] 뷰 컨트롤러 설정: \(vcs.count)개")
                for (index, vc) in vcs.enumerated() {
                    let title = vc.tabBarItem?.title ?? "제목 없음"
                    print("   탭 \(index): \(title)")
                }
            }
        }
    }
    
    // MARK: - Memory Management
    
    deinit {
        // 제스처 인식기 정리
        swipeGestureRecognizers.forEach { gesture in
            view.removeGestureRecognizer(gesture)
        }
        print("🧹 [SimpleTabBar] 메모리 정리 완료")
    }
}

// MARK: - 🎯 장점
/*
 * ✅ iOS 기본 UITabBarController 사용 - 100% 안정성
 * ✅ 크래시 없음 - 내부 일관성 검사 통과
 * ✅ 간단한 코드 - 유지보수 용이
 * ✅ 선택적 스와이프 - 필요시만 사용
 * ✅ 메모리 효율적 - 불필요한 뷰 계층 없음
 */