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

        // 하단 배너 포지션에서 사용하는 제약(세이프영역 하단 오프셋 반영)
        var bottomConstraint: NSLayoutConstraint?

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
        // Objective-C 연관 객체 키는 "주소가 안정적인 전역 변수의 포인터"를 쓰는 것이 정석
        // (문자열 값의 주소나 객체 포인터 사용은 OS/ABI 변화에 취약할 수 있음)
        static var bannerHandleKey: UInt8 = 0
        static var reserveSpaceKey: UInt8 = 0
    }

    private func getHandle(from vc: UIViewController) -> AttachedBannerHandle? {
        return objc_getAssociatedObject(vc, &AssocKey.bannerHandleKey) as? AttachedBannerHandle
    }

    private func setHandle(_ handle: AttachedBannerHandle?, to vc: UIViewController) {
        objc_setAssociatedObject(
            vc, &AssocKey.bannerHandleKey, handle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
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
        print("🧩 [AdsAttach] vc=\(type(of: viewController)), pos=\(position)")

        // 하단 배너 제약 보관용 (키보드/회전/세이프에어리어 변경 시 재계산)
        var bottomConstraintRef: NSLayoutConstraint?

        switch position {
        case .bottom:
            // KISS: 배너는 VC.view에 직접 추가하고, 배너의 "하단"을 view.bottom에 붙이되
            //       오프셋을 "시스템 safeArea 하단"만큼 음수로 준다.
            //       이렇게 하면 추가 인셋(bottom)을 얼마를 주든 배너 위치는 흔들리지 않는다.
            viewController.view.addSubview(banner)
            NSLayoutConstraint.activate([
                banner.leadingAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.leadingAnchor),
                banner.trailingAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.trailingAnchor)
            ])
            // 동적으로 계산되는 시스템 하단 세이프(추가 인셋 제외)를 반영하기 위해 제약 상수만 갱신 가능하도록 저장
            let bottom = banner.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor)
            bottom.isActive = true
            bottomConstraintRef = bottom
            // 최초 한 번 현재 시스템 세이프 하단만큼 올림
            let systemBottom = max(0, viewController.view.safeAreaInsets.bottom - viewController.additionalSafeAreaInsets.bottom)
            bottom.constant = -systemBottom
            viewController.view.bringSubviewToFront(banner)

        case .topUnderNavBar:
            viewController.view.addSubview(banner)
            NSLayoutConstraint.activate([
                banner.leadingAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.leadingAnchor),
                banner.trailingAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.trailingAnchor),
                banner.topAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.topAnchor),
            ])
            // 최상단 고정 시에도 공통 조상 보장 후 맨 앞으로 올림
            viewController.view.bringSubviewToFront(banner)
        }

        let handle = AttachedBannerHandle(
            viewController: viewController, bannerView: banner, position: position)
        handle.bottomConstraint = bottomConstraintRef
        setHandle(handle, to: viewController)
        // reserveSpace 플래그를 bannerView에 연관 저장 (간단 전달)
        objc_setAssociatedObject(banner, &AssocKey.reserveSpaceKey, reserveSpace, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // 스크롤뷰 추적 (상단/하단 모두에서 필요: 겹침 방지용으로 contentInset 조정)
        handle.trackedScrolls = captureTopLevelScrollViews(of: viewController.view).map {
            .init(
                scrollView: $0, baseContentInset: $0.contentInset,
                baseIndicatorInset: $0.scrollIndicatorInsets)
        }

        // 배너 높이 변경 콜백 설정 → 인셋 즉시 반영
        banner.onHeightChange = { [weak self, weak handle] newHeight in
            guard let self, let handle, let vc = handle.viewController else { return }
            handle.lastBannerHeight = newHeight
            // z-order 보정 및 하단 제약 상수 재계산(시스템 세이프 하단만 반영)
            vc.view.bringSubviewToFront(handle.bannerView)
            if let bottom = handle.bottomConstraint {
                let reserveSpace = (objc_getAssociatedObject(handle.bannerView, &AssocKey.reserveSpaceKey) as? Bool) ?? true
                let systemBottom = max(0, vc.view.safeAreaInsets.bottom - vc.additionalSafeAreaInsets.bottom)
                bottom.constant = -systemBottom
                // 콘텐츠 여백은 배너 높이를 추가 인셋으로만 반영
                vc.additionalSafeAreaInsets.bottom = reserveSpace ? newHeight : 0
            }
            print("📐 [AdsLayout] vc=\(type(of: vc)), pos=\(handle.position), height=\(newHeight), safe=\(vc.view.safeAreaInsets), addSafe=\(vc.additionalSafeAreaInsets)")
            self.refreshInsets(for: handle, animated: true)
        }

        // 키보드 충돌 방지: bottom 포지션에서 키보드가 올라오면 배너 숨김
        registerKeyboardObservers(for: handle)

        // 로드: 레이아웃을 한 번 강제 적용하여 배너 컨테이너 폭이 0이 아니게 만든 후 로드
        if autoLoad {
            viewController.view.layoutIfNeeded()
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
        let reserveSpace = (objc_getAssociatedObject(handle.bannerView, &AssocKey.reserveSpaceKey) as? Bool) ?? true

        let applyChanges = {
            switch handle.position {
            case .bottom:
                // 시스템 하단 세이프(탭바/홈인디케이터)만큼만 배너를 올리고, 콘텐츠 여백은 추가 인셋으로만 반영
                if let bottom = handle.bottomConstraint {
                    let systemBottom = max(0, vc.view.safeAreaInsets.bottom - vc.additionalSafeAreaInsets.bottom)
                    bottom.constant = -systemBottom
                }
                vc.additionalSafeAreaInsets.bottom = reserveSpace ? height : 0
                // 하단 스크롤 inset은 더 이상 만지지 않음(이중 여백 방지)

            case .topUnderNavBar:
                // A 옵션: 배너는 safeAreaLayoutGuide.top 에 고정 + 추가 top inset 제거 → 배너를 Safe Area 내부에 자연스럽게 포함
                // 기존 구현(추가 inset = 배너 높이)으로 발생하던 이중 여백 제거.
                // 필요시(특정 화면) 개별 tableView/scrollView contentInset.top 조정으로 후속 세밀 제어 가능.
                vc.additionalSafeAreaInsets.top = 0
                // 스크롤 inset(top)은 조정하지 않음(이중 여백 방지)
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

    /// 현재 VC에 배너가 부착되어 있는지 여부
    func isBannerAttached(to vc: UIViewController) -> Bool {
        return getHandle(from: vc) != nil
    }

    /// 사운드 등 일반 화면에서 하단 배너가 존재하도록 보장
    /// - 이미 다른 포지션 배너가 붙어 있으면 분리 후 하단으로 재부착
    /// - 없으면 새로 부착
    /// - 하단 배너가 있으면 레이아웃만 새로 고침
    func ensureBottomBannerAttached(to vc: UIViewController, autoLoad: Bool = true) {
        // 같은 탭 내에 남아 있을지 모르는 상단 배너를 선제적으로 제거해 이중 노출 방지
        detachTopBannersInSameTabBarController(of: vc)
        if let handle = getHandle(from: vc) {
            switch handle.position {
            case .bottom:
                refreshLayoutIfNeeded(for: vc)
            case .topUnderNavBar:
                detachBanner(from: vc)
                attachBottomBanner(to: vc, autoLoad: autoLoad)
            }
        } else {
            attachBottomBanner(to: vc, autoLoad: autoLoad)
        }
    }

    /// 같은 탭바 컨트롤러 소속 VC들 중 상단 배너가 붙어 있는 경우 분리
    private func detachTopBannersInSameTabBarController(of vc: UIViewController) {
        guard let tbc = vc.tabBarController else { return }
        let roots = tbc.viewControllers ?? []
        for root in roots {
            if let h = getHandle(from: root), h.position == .topUnderNavBar { detachBanner(from: root) }
            if let nav = root as? UINavigationController {
                for inner in nav.viewControllers {
                    if let h = getHandle(from: inner), h.position == .topUnderNavBar {
                        detachBanner(from: inner)
                    }
                }
            }
        }
    }



    /// 채팅 전용 단일 상단 배너 정책: 다른 탭/스택의 잔존 배너 제거 후 상단 배너 1개만 유지
    /// - 사용처: ChatViewController(대나무숲), EmotionAnalysisChatViewController 등 Top-only 화면
    /// - 구현 철학: KISS/DRY (중복 제거), YAGNI (불필요한 상태 저장 회피)
    /// - 동작:
    ///   1. 동일 탭바 컨트롤러 내 다른 VC 및 그 내비 스택 자식에서 배너 분리(detach)
    ///   2. 대상 VC에 topUnderNavBar 배너 1개 부착
    func attachExclusiveTopBannerUnderNavBar(to vc: UIViewController, autoLoad: Bool = true) {
        if let tbc = vc.tabBarController {
            let vcs = tbc.viewControllers ?? []
            for root in vcs {
                if root !== vc { detachBanner(from: root) }
                if let nav = root as? UINavigationController {
                    for inner in nav.viewControllers where inner !== vc {
                        detachBanner(from: inner)
                    }
                }
            }
        }
        attachBanner(to: vc, position: .topUnderNavBar, autoLoad: autoLoad, reserveSpace: true)
    }



}
