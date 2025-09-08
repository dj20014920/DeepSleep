import UIKit
import ObjectiveC

/// AdsBannerCoordinator
/// - 목적: 배너 광고의 전역 부착과 인셋(레이아웃) 조정을 중앙에서 일관되게 처리
/// - 특징:
///   1) DRY: 각 화면에서 중복되는 배너/인셋 코드 제거
///   2) KISS: 간단한 API (`attachBanner`)로 배너 장착 및 자동 인셋 조정
///   3) YAGNI: 필요 최소 기능만 제공 (전면 광고/보상형 등은 범위 밖)
///   4) SOLID:
///      - SRP: 본 유틸은 “배너 부착과 인셋 조정”만 담당
///      - OCP: 포지션/정책 확장은 열려있고, 기존 코드 수정 최소화
///      - DIP: GoogleMobileAds SDK 부재 시에도 빌드 가능 (BannerAdContainerView가 보호)
///
/// 사용 가이드:
/// - 일반 화면(미니 다이어리, 오늘의 운세, 설정 등): .bottom 포지션 권장
/// - 대나무숯(채팅창): .topUnderNavBar 포지션 권장 (상단바 [뒤로, 내보내기] 바로 아래)
///
/// 기본 전략:
/// - bottom 포지션:
///   • 배너는 view.bottomAnchor에 붙임 (safeArea가 아님)
///   • viewController.additionalSafeAreaInsets.bottom = 배너 높이 로 자동 조정
///   • 키보드 표시 중에는 배너를 자동으로 숨김(침범 방지)
///
/// - topUnderNavBar 포지션(채팅/스크롤형 화면에 최적화):
///   • 배너는 view.safeAreaLayoutGuide.topAnchor에 붙임
///   • 스크롤 뷰(테이블/컬렉션)가 있을 경우 contentInset.top/scrollIndicatorInsets.top을 배너 높이만큼 조정
///   • 일반 뷰 레이아웃일 경우에는 필요에 따라 상단 여백을 직접 처리하시길 권장
///
/// 주의:
/// - 아래 유틸은 중앙에서만 배너를 관리하도록 설계됨. 각 화면에 기존 배너 로직이 있다면 제거/이관을 권장
/// - 키보드 및 회전 대응 포함
///
/// 의존:
/// - BannerAdContainerView (DeepSleepApp/Ads/AdsManager.swift 내 정의)
///   → SDK가 없으면 높이 0으로 취급되어 안전
///
final class AdsBannerCoordinator {

    static let shared = AdsBannerCoordinator()
    private init() {}

    enum BannerPosition {
        case bottom  // 화면 하단(탭바 위 영역에 안전하게)
        case topUnderNavBar  // 네비게이션바 아래(채팅 전용 권장)
    }

    /// 내부적으로 각 화면(VC)별 부착 상태와 옵저버/인셋 정보를 유지
    private final class AttachedBannerHandle {
        weak var viewController: UIViewController?
        let bannerView: BannerAdContainerView
        let position: BannerPosition

        // 키보드 옵저버
        var kbShowObserver: NSObjectProtocol?
        var kbHideObserver: NSObjectProtocol?

        // 최신 배너 높이
        var lastBannerHeight: CGFloat = 0

        // 스크롤 뷰 기본 인셋(Top 포지션에서만 사용)
        struct WeakScrollInfo {
            weak var scrollView: UIScrollView?
            let baseContentInset: UIEdgeInsets
            let baseIndicatorInset: UIEdgeInsets
        }
        var trackedScrolls: [WeakScrollInfo] = []

        init(
            viewController: UIViewController, bannerView: BannerAdContainerView,
            position: BannerPosition
        ) {
            self.viewController = viewController
            self.bannerView = bannerView
            self.position = position
        }

        deinit {
            // 옵저버 정리
            if let kbShowObserver { NotificationCenter.default.removeObserver(kbShowObserver) }
            if let kbHideObserver { NotificationCenter.default.removeObserver(kbHideObserver) }
        }
    }

    // UIViewController에 연관 객체로 핸들을 붙여 수명 주기와 동기화
    private struct AssocKey {
        static var bannerHandle = "kr.deepsleep.ads.banner.handle"
    }

    private func getHandle(from vc: UIViewController) -> AttachedBannerHandle? {
        return objc_getAssociatedObject(vc, &AssocKey.bannerHandle) as? AttachedBannerHandle
    }

    private func setHandle(_ handle: AttachedBannerHandle?, to vc: UIViewController) {
        objc_setAssociatedObject(
            vc, &AssocKey.bannerHandle, handle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    // MARK: - Public API

    /// 배너를 해당 VC에 부착(중복 방지)하고 자동 인셋 조정 시작
    /// - Parameters:
    ///   - viewController: 타깃 화면
    ///   - position: .bottom(기본) 또는 .topUnderNavBar(채팅)
    ///   - autoLoad: true면 즉시 배너 로드
    func attachBanner(
        to viewController: UIViewController,
        position: BannerPosition = .bottom,
        autoLoad: Bool = true,
        reserveSpace: Bool = true // 하단 배너 시 컨텐츠 여백(세이프박스) 확보 여부
    ) {
        // 이미 같은 포지션으로 붙어 있으면 재사용
        if let existing = getHandle(from: viewController),
            existing.position == position,
            existing.bannerView.superview != nil
        {
            // 갱신만
            existing.viewController = viewController // 최신 VC 보장
            refreshInsets(for: existing, animated: false)
            return
        }

        // 기존 핸들 제거
        detachBanner(from: viewController)

        // 새 배너 생성 및 부착
        let banner = BannerAdContainerView()
        banner.translatesAutoresizingMaskIntoConstraints = false
        viewController.view.addSubview(banner)
        // 어떤 화면에서도 배너가 항상 최상단으로 보이도록 보장
        viewController.view.bringSubviewToFront(banner)
        print("🧩 [AdsAttach] vc=\(type(of: viewController)), pos=\(position)")

        switch position {
        case .bottom:
            if let tbc = viewController.tabBarController {
                let container = tbc.view!
                container.addSubview(banner)
                NSLayoutConstraint.activate([
                    banner.leadingAnchor.constraint(equalTo: container.safeAreaLayoutGuide.leadingAnchor),
                    banner.trailingAnchor.constraint(equalTo: container.safeAreaLayoutGuide.trailingAnchor),
                    // 탭바 바로 위에 배너를 부착
                    banner.bottomAnchor.constraint(equalTo: tbc.tabBar.topAnchor)
                ])
                container.bringSubviewToFront(banner)
            } else {
                if reserveSpace {
                    NSLayoutConstraint.activate([
                        banner.leadingAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.leadingAnchor),
                        banner.trailingAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.trailingAnchor),
                        // 탭바가 없고 세이프박스를 사용하는 경우: 안전영역 하단에 부착
                        banner.bottomAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.bottomAnchor)
                    ])
                } else {
                    NSLayoutConstraint.activate([
                        banner.leadingAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.leadingAnchor),
                        banner.trailingAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.trailingAnchor),
                        // 세이프박스 없이 완전 하단에 부착(홈 인디케이터 영역 포함)
                        banner.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor)
                    ])
                }
                viewController.view.bringSubviewToFront(banner)
            }

        case .topUnderNavBar:
            NSLayoutConstraint.activate([
                banner.leadingAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.leadingAnchor),
                banner.trailingAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.trailingAnchor),
                banner.topAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.topAnchor),
            ])
        }

        let handle = AttachedBannerHandle(
            viewController: viewController, bannerView: banner, position: position)
        setHandle(handle, to: viewController)
        // reserveSpace 플래그를 bannerView에 연관 저장 (간단 전달)
        objc_setAssociatedObject(banner, Unmanaged.passUnretained(self).toOpaque(), reserveSpace, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // 스크롤뷰 추적 (상단/하단 모두에서 필요: 겹침 방지용으로 contentInset 조정)
        handle.trackedScrolls = captureTopLevelScrollViews(of: viewController.view).map {
            .init(
                scrollView: $0, baseContentInset: $0.contentInset,
                baseIndicatorInset: $0.scrollIndicatorInsets)
        }

        // 배너 높이 변경 콜백 설정 → 인셋 즉시 반영
        banner.onHeightChange = { [weak self, weak handle] newHeight in
            guard let self, let handle else { return }
            handle.lastBannerHeight = newHeight
            // 배너를 항상 맨 위로 유지 (덮임 방지)
            handle.viewController?.view.bringSubviewToFront(handle.bannerView)
            print("📐 [AdsLayout] vc=\(type(of: handle.viewController!)), pos=\(handle.position), height=\(newHeight), safe=\(handle.viewController!.view.safeAreaInsets), addSafe=\(handle.viewController!.additionalSafeAreaInsets)")
            self.refreshInsets(for: handle, animated: true)
        }

        // 키보드 충돌 방지: bottom 포지션에서 키보드가 올라오면 배너 숨김
        registerKeyboardObservers(for: handle)

        // 로드
        if autoLoad {
            banner.loadBanner(in: viewController)
        }
    }

    /// 해당 VC에서 배너를 제거하고 인셋 복구
    func detachBanner(from viewController: UIViewController) {
        guard let handle = getHandle(from: viewController) else { return }

        // 옵저버 해제
        if let obs = handle.kbShowObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = handle.kbHideObserver { NotificationCenter.default.removeObserver(obs) }

        // 인셋 원복
        switch handle.position {
        case .bottom:
            viewController.additionalSafeAreaInsets.bottom = 0

        case .topUnderNavBar:
            // 추적했던 스크롤뷰 인셋 복구
            handle.trackedScrolls.forEach { info in
                guard let scroll = info.scrollView else { return }
                scroll.contentInset = info.baseContentInset
                scroll.scrollIndicatorInsets = info.baseIndicatorInset
            }
        }

        // 뷰 제거
        handle.bannerView.removeFromSuperview()
        setHandle(nil, to: viewController)
    }

    /// 수동으로 인셋 갱신이 필요한 경우 호출 (회전/레이아웃 이후 등)
    func refreshLayoutIfNeeded(for viewController: UIViewController) {
        guard let handle = getHandle(from: viewController) else { return }
        refreshInsets(for: handle, animated: false)
    }

    // MARK: - Internals

    private func refreshInsets(for handle: AttachedBannerHandle, animated: Bool) {
        guard let vc = handle.viewController else { return }
        let height = handle.lastBannerHeight
        // 연관 객체로 저장한 reserveSpace를 읽어 하단 여백 처리 여부 결정 (일기쓰기 탭에서만 false로 전달)
        let reserveSpace = (objc_getAssociatedObject(handle.bannerView, Unmanaged.passUnretained(self).toOpaque()) as? Bool) ?? true

        let applyChanges = {
            switch handle.position {
            case .bottom:
                if reserveSpace {
                    // 배너는 탭바 바로 위에 고정, 컨텐츠는 SafeArea를 통해 위로 밀어 올림
                    vc.additionalSafeAreaInsets.bottom = height
                } else {
                    // 일기쓰기 탭 전용: 세이프박스(여백) 없이 배너를 바닥에 붙이고 컨텐츠 여백도 0으로 유지
                    vc.additionalSafeAreaInsets.bottom = 0
                }
                // 하단 스크롤 inset은 더 이상 만지지 않아 이중 여백 방지 (topUnderNavBar만 조정)

            case .topUnderNavBar:
                // 상단 배너 높이만큼 스크롤뷰 컨텐츠 인셋/스크롤 인디케이터 인셋을 증가
                handle.trackedScrolls.forEach { info in
                    guard let scroll = info.scrollView else { return }
                    var contentInset = info.baseContentInset
                    var indicatorInset = info.baseIndicatorInset
                    contentInset.top = info.baseContentInset.top + height
                    indicatorInset.top = info.baseIndicatorInset.top + height
                    scroll.contentInset = contentInset
                    scroll.scrollIndicatorInsets = indicatorInset
                }
            }
            vc.view.setNeedsLayout()
            vc.view.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.2, animations: applyChanges)
        } else {
            applyChanges()
        }
    }

    private func captureTopLevelScrollViews(of root: UIView) -> [UIScrollView] {
        // 뷰 계층에서 표시 가능한 주요 스크롤뷰들을 수집
        var result: [UIScrollView] = []
        func dfs(_ view: UIView) {
            if let sv = view as? UIScrollView {
                result.append(sv)
            }
            for sub in view.subviews {
                dfs(sub)
            }
        }
        dfs(root)
        // 중복 제거
        return Array(Set(result))
    }

    private func registerKeyboardObservers(for handle: AttachedBannerHandle) {
        guard let vc = handle.viewController else { return }

        // bottom 포지션에서만 키보드 충돌 회피(배너 숨김)
        handle.kbShowObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak handle] note in
            guard let handle, let vc = handle.viewController else { return }
            if handle.position == .bottom {
                // 키보드 높이에 맞춰 실제 보이는 영역을 확보: 배너는 유지, 컨텐츠는 키보드+배너 만큼 inset 적용
                if let frameEnd = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    let kbHeight = frameEnd.height
                    vc.additionalSafeAreaInsets.bottom = kbHeight + handle.lastBannerHeight
                    handle.trackedScrolls.forEach { info in
                        guard let scroll = info.scrollView else { return }
                        var contentInset = info.baseContentInset
                        var indicatorInset = info.baseIndicatorInset
                        contentInset.bottom = kbHeight + handle.lastBannerHeight
                        indicatorInset.bottom = kbHeight + handle.lastBannerHeight
                        scroll.contentInset = contentInset
                        scroll.scrollIndicatorInsets = indicatorInset
                    }
                }
            }
        }

        handle.kbHideObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak handle] _ in
            guard let handle, let vc = handle.viewController else { return }
            if handle.position == .bottom {
                // 키보드가 사라지면 원래 배너 높이만큼만 보정
                vc.additionalSafeAreaInsets.bottom = handle.lastBannerHeight
                handle.trackedScrolls.forEach { info in
                    guard let scroll = info.scrollView else { return }
                    var contentInset = info.baseContentInset
                    var indicatorInset = info.baseIndicatorInset
                    contentInset.bottom = handle.lastBannerHeight
                    indicatorInset.bottom = handle.lastBannerHeight
                    scroll.contentInset = contentInset
                    scroll.scrollIndicatorInsets = indicatorInset
                }
            }
        }
    }
}

// MARK: - 편의 API (채팅/일반 화면용)

extension AdsBannerCoordinator {
    /// 일반 화면: 하단 배너 (세이프박스 기본 확보)
    func attachBottomBanner(to vc: UIViewController, autoLoad: Bool = true) {
        attachBanner(to: vc, position: .bottom, autoLoad: autoLoad, reserveSpace: true)
    }

    /// 일반 화면: 하단 배너 (세이프박스 확보 여부 제어)
    func attachBottomBanner(to vc: UIViewController, autoLoad: Bool = true, reserveSpace: Bool) {
        attachBanner(to: vc, position: .bottom, autoLoad: autoLoad, reserveSpace: reserveSpace)
    }

    /// 채팅 화면: 상단(네비게이션 바 아래) 배너
    func attachTopBannerUnderNavBar(to vc: UIViewController, autoLoad: Bool = true) {
        attachBanner(to: vc, position: .topUnderNavBar, autoLoad: autoLoad, reserveSpace: true)
    }
}
