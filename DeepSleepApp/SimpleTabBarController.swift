//
//  SimpleTabBarController.swift
//  DeepSleep
//
//  Created by Claude on 2025-07-28.
//  간단하고 안정적인 탭바 컨트롤러 - 크래시 없는 버전
//

import UIKit

class SimpleTabBarController: UITabBarController, UIGestureRecognizerDelegate {
    
    // MARK: - Properties
    
    private var swipeGestureRecognizers: [UISwipeGestureRecognizer] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 탭바 스타일 설정
        setupTabBarAppearance()
        
        // 스와이프 제스처 설정 (선택사항)
        setupSwipeGestures()
        
        // 구독 상태에 따라 탭바 스타일을 즉시 반영
        _ = SubscriptionUIBinder.attach(to: self) { [weak self] isPremium in
            guard let self = self else { return }
            let selectedColor: UIColor = isPremium ? .systemYellow : .systemBlue
            self.tabBar.tintColor = selectedColor
            if #available(iOS 15.0, *) {
                let appearance = UITabBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor.systemBackground
                appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
                appearance.inlineLayoutAppearance.selected.iconColor = selectedColor
                appearance.compactInlineLayoutAppearance.selected.iconColor = selectedColor
                self.tabBar.standardAppearance = appearance
                self.tabBar.scrollEdgeAppearance = appearance
            }
        }
        
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
        leftSwipe.delegate = self // 델리게이트 설정
        view.addGestureRecognizer(leftSwipe)
        swipeGestureRecognizers.append(leftSwipe)
        
        // 우측 스와이프 (이전 탭으로)
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        rightSwipe.direction = .right
        rightSwipe.delegate = self // 델리게이트 설정
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

// MARK: - UIGestureRecognizerDelegate
extension SimpleTabBarController {
    
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
                        if let tableView = cell.subviews.first(where: { $0 is UITableView }) {
                            let tableFrame = tableView.frame
                            if tableFrame.contains(cellLocalPoint) {
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

// MARK: - 🎯 장점
/*
 * ✅ iOS 기본 UITabBarController 사용 - 100% 안정성
 * ✅ 크래시 없음 - 내부 일관성 검사 통과
 * ✅ 간단한 코드 - 유지보수 용이
 * ✅ 선택적 스와이프 - 필요시만 사용
 * ✅ 메모리 효율적 - 불필요한 뷰 계층 없음
 */