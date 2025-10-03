import UIKit

// MARK: - 🚀 채팅 화면 통합 관리 라우터
enum ChatRouter {
    // 단일 채팅 VC 보장을 위한 약한 참조 (전역 싱글턴 아님: 생명주기 존중)
    private static weak var currentChatVC: ChatViewController? = nil
    static func registerCurrentChatVC(_ vc: ChatViewController) { currentChatVC = vc }
    static func unregisterCurrentChatVC(_ vc: ChatViewController) { if currentChatVC === vc { currentChatVC = nil } }

    /// 채팅 라우팅 컨텍스트 타입 (ChatMode enum과 구분하기 위해 다른 이름 사용)
    enum RoutingContext {
        case general
        case diaryAnalysis(diary: EmotionDiary)
        case emotionAnalysis(emotion: String)
        case monthlyPattern(data: String)
        case feedbackAnalysis
        case customContext(title: String, initialMessage: String)
    }

    /// 통합된 채팅 화면 생성 (컨텍스트 지원)
    static func chatViewController(context: RoutingContext = .general) -> ChatViewController {
        let vc = ChatViewController()
        // SessionManager는 싱글톤으로 자동 관리됨

        // 컨텍스트에 따른 초기 설정 (ChatMode enum 사용)
        switch context {
        case .general:
            vc.chatContext = .generalConversation

        case .diaryAnalysis(let diary):
            vc.chatContext = .emotionDiaryAnalysis
            // DRY: 분석 트리거의 단일 SSoT는 ChatViewController.requestDiaryAnalysisWithTracking
            //     → diaryContext를 설정하여 ChatViewController의 setupInitialMessages 경로를 사용하도록 통일
            vc.diaryContext = DiaryContext(from: diary)
            // 호환성: 기존 초기 데이터 필드도 유지(표시 메시지 등에서 사용될 수 있음)
            vc.initialDiaryData = diary
            // ⚠️ Resume/Override로 기존 세션으로 덮어쓰는 문제 방지: 에페메랄 세션으로 지정
            //    - viewDidLoad의 재개/오버라이드 로직을 우회하여 '새 창 깜빡임' 및 세션 덮어쓰기 차단
            vc.isEphemeralSession = true
        // 명시적 모드 플래그는 불필요 (diaryContext가 있으면 setupInitialMessages에서 즉시 분석 시작)

        case .emotionAnalysis(let emotion):
            vc.chatContext = .emotionAnalysis
            vc.initialEmotion = emotion

        case .monthlyPattern(let data):
            vc.chatContext = .monthlyPatternAnalysis
            vc.initialPatternData = data

        case .feedbackAnalysis:
            vc.chatContext = .feedbackAnalysis

        case .customContext(let title, let initialMessage):
            // 커스텀 컨텍스트의 경우 title에 따라 적절한 ChatMode enum 매핑
            vc.chatContext = ChatMode.from(title)
            vc.initialSystemMessage = initialMessage
        }

        return vc
    }

    /// 기존 호환성을 위한 메서드
    static func chatViewController() -> ChatViewController {
        return chatViewController(context: .general)
    }

    /// 채팅 화면 모달 프레젠테이션 설정
    static func configurePresentationStyle(_ vc: ChatViewController) {
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .coverVertical
    }

    /// 단일 ChatViewController를 항상 재사용하며 대나무숲(일반 채팅)으로 이동
    /// - 동작:
    ///   1) 최상위 UITabBarController 탐색
    ///   2) 모든 탭의 UINavigationController에서 기존 ChatViewController 탐색
    ///   3) 발견 시 해당 탭으로 전환하고 popToViewController 처리
    ///   4) 없으면 0번 탭의 내비게이션에 ChatViewController를 push(루트 교체 금지)
    ///   5) 현재 표시 중 모달이 있으면 정리(dismiss) 후 진행
    static func navigateToGeneralChat(from sourceVC: UIViewController? = nil, animated: Bool = true, completion: ((ChatViewController) -> Void)? = nil)
    {
        DispatchQueue.main.async {
            // 1) 루트 탭바 탐색
            guard
                let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let window = windowScene.windows.first(where: { $0.isKeyWindow }),
                let tabBar = window.rootViewController as? UITabBarController
            else {
                // 폴백: 모달을 닫고 재시도
                if let presenter = sourceVC, presenter.presentingViewController != nil {
                    presenter.dismiss(animated: true) {
                        navigateToGeneralChat(from: nil, animated: animated)
                    }
                }
                return
            }

            // 2) 모든 탭에서 기존 ChatViewController 탐색
            var targetNav: UINavigationController?
            var targetIndex: Int?
            var existingChatVC: ChatViewController?
            if let roots = tabBar.viewControllers {
                for (idx, root) in roots.enumerated() {
                    if let nav = root as? UINavigationController,
                        let found = nav.viewControllers.first(where: { $0 is ChatViewController })
                            as? ChatViewController
                    {
                        targetNav = nav
                        targetIndex = idx
                        existingChatVC = found
                        break
                    }
                }
            }

            // 3) 목적 내비게이션 선택: 기존이 있으면 그 탭, 없으면 0번 탭
            if targetNav == nil {
                targetNav = tabBar.viewControllers?.first as? UINavigationController
                targetIndex = 0
                // 0번 탭이 네비게이션이 아니라면 보정
                if targetNav == nil {
                    let chat = chatViewController(context: .general)
                    let nav = UINavigationController(rootViewController: chat)
                    var vcs = tabBar.viewControllers ?? []
                    if vcs.isEmpty { vcs = [nav] } else { vcs[0] = nav }
                    tabBar.viewControllers = vcs
                    targetNav = nav
                    targetIndex = 0
                    existingChatVC = chat
                }
            }

            guard let nav = targetNav, let navIndex = targetIndex else { return }

            // 4) 해당 탭으로 전환
            tabBar.selectedIndex = navIndex

            // 5) 현재 표시 중인 모달 정리
            if let presenter = sourceVC, presenter.presentingViewController != nil {
                presenter.dismiss(animated: true)
            } else if let presented = tabBar.presentedViewController {
                presented.dismiss(animated: true)
            }

            // 6) 기존 ChatVC 재사용 또는 새로 push
            if let chatVC = existingChatVC {
                nav.popToViewController(chatVC, animated: false)
                completion?(chatVC)
            } else {
                let vc = chatViewController(context: .general)
                nav.pushViewController(vc, animated: false)
                completion?(vc)
            }
        }
    }

    /// 편의 메서드: Navigation Push
    static func pushChatViewController(from sourceVC: UIViewController, animated: Bool = true) {
        navigateToGeneralChat(from: sourceVC, animated: animated)
    }

    /// 편의 메서드: Modal Present
    static func presentChatViewController(from sourceVC: UIViewController, animated: Bool = true) {
        navigateToGeneralChat(from: sourceVC, animated: animated)
    }

    /// 기존 채팅창으로 일기 분석을 시작하는 내비게이션 유틸
    /// - 목적: 새 ChatViewController를 만들지 않고, 메인 탭의 기존 채팅창에서 바로 분석을 시작
    /// - 동작:
    ///   1) 루트 UITabBarController 탐색 → 첫 번째 탭(대나무숲)으로 전환
    ///   2) 해당 탭의 UINavigationController에서 ChatViewController 확보(없으면 생성)
    ///   3) 현재 표시 중인 모달을 정리(dismiss)한 뒤 기존 채팅창에서 분석 시작
    /// - 폴백: 루트 탐색 실패 시 기존 방식(새 창 생성)으로 안전하게 처리
    static func startDiaryAnalysisInExistingChat(
        from sourceVC: UIViewController?, diary: EmotionDiary
    ) {
        // 단일 경로: 먼저 ‘단일 ChatVC’로 이동을 보장 → 도착 후 분석 컨텍스트 주입 + 1회 트리거
        navigateToGeneralChat(from: sourceVC, animated: false) { chatVC in
            // 모달/탭 전환 등의 애니메이션 완료 후 안전 트리거
            let injectAndStart = { [weak chatVC] in
                guard let vc = chatVC else { return }
                // 공개 API로 즉시 일기 표시 + 분석 시작 (중복 방지 내장)
                if vc.isViewLoaded, vc.view.window != nil {
                    vc.presentDiaryAndStartAnalysis(DiaryContext(from: diary))
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        vc.presentDiaryAndStartAnalysis(DiaryContext(from: diary))
                    }
                }
            }

            // 네비 전환 직후 한 프레임 대기 후 주입/시작
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: injectAndStart)
        }
        return

            // 1) 루트 탭바 탐색
            guard
                let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let window = windowScene.windows.first(where: { $0.isKeyWindow }),
                let tabBar = window.rootViewController as? UITabBarController
            else {
                // 폴백: 새 창 생성 금지. 모달을 우선 정리하고 재시도한다.
                if let presenter = sourceVC, presenter.presentingViewController != nil {
                    presenter.dismiss(animated: true) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            startDiaryAnalysisInExistingChat(from: nil, diary: diary)
                        }
                    }
                } else {
                    // 최후의 수단: 키 윈도우 루트에서 탭바를 재탐색 후 재시도 (없으면 안전 중단)
                    if UIApplication.shared.connectedScenes
                        .compactMap({ $0 as? UIWindowScene })
                        .flatMap({ $0.windows })
                        .first(where: { $0.isKeyWindow })?.rootViewController as? UITabBarController
                        != nil
                    {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            startDiaryAnalysisInExistingChat(from: nil, diary: diary)
                        }
                    } else {
                        // 로그만 남기고 중단 (새 창 생성은 금지)
                        #if DEBUG
                            print("[ChatRouter] 폴백 실패: 탭바를 찾지 못해 분석 시작을 중단합니다.")
                        #endif
                    }
                }
                return
            }

            // 2) 모든 탭의 네비게이션에서 기존 ChatViewController 탐색
            var targetNav: UINavigationController?
            var targetIndex: Int?
            var existingChatVC: ChatViewController?
            if let roots = tabBar.viewControllers {
                for (idx, root) in roots.enumerated() {
                    if let nav = root as? UINavigationController,
                        let found = nav.viewControllers.first(where: { $0 is ChatViewController })
                            as? ChatViewController
                    {
                        targetNav = nav
                        targetIndex = idx
                        existingChatVC = found
                        break
                    }
                }
            }

            // 3) 목적 네비게이션 선택: 기존이 있으면 그 탭, 없으면 0번 탭의 네비게이션
            if targetNav == nil {
                targetNav = tabBar.viewControllers?.first as? UINavigationController
                targetIndex = 0
            }
            guard let nav = targetNav, let navIndex = targetIndex else {
                // 탭 루트가 네비게이션이 아닌 경우 보정
                let vc = chatViewController(context: .general)
                let fallbackNav = UINavigationController(rootViewController: vc)
                var vcs = tabBar.viewControllers ?? []
                if vcs.isEmpty {
                    vcs = [fallbackNav]
                } else {
                    vcs[0] = fallbackNav
                }
                tabBar.viewControllers = vcs
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    startDiaryAnalysisInExistingChat(from: sourceVC, diary: diary)
                }
                return
            }

            // 4) 해당 탭으로 전환 (기존 ChatVC가 있는 탭을 우선)
            tabBar.selectedIndex = navIndex

            // 5) 기존 ChatViewController 확보(없으면 생성)
            var chatVC = existingChatVC ?? ChatRouter.currentChatVC
            var createdNew = false
            if chatVC == nil {
                // 신규 VC 생성: 컨텍스트/데이터를 미리 주입하고 push로 스택에 추가 (루트 교체 금지)
                let vc = chatViewController(context: .general)
                vc.chatContext = .emotionDiaryAnalysis
                vc.isEphemeralSession = true  // 재개/오버라이드 및 페이징 방지
                vc.diaryContext = DiaryContext(from: diary)
                vc.initialDiaryData = diary
                nav.pushViewController(vc, animated: false)
                chatVC = vc
                ChatRouter.currentChatVC = vc
                createdNew = true
            } else {
                // 루트로 정리하여 일관된 상태 보장
                if let existing = chatVC, nav.viewControllers.contains(existing) {
                    nav.popToViewController(existing, animated: false)
                } else if let existing = chatVC {
                    nav.pushViewController(existing, animated: false)
                }
                ChatRouter.currentChatVC = chatVC
            }

            guard let target = chatVC else { return }

            // 5) 현재 표시 중인 모달 정리 (일기 작성/수정 화면 등)
            var didDismiss = false
            if let presenter = sourceVC, presenter.presentingViewController != nil {
                didDismiss = true
                presenter.dismiss(animated: true)
            } else if let presented = tabBar.presentedViewController {
                didDismiss = true
                presented.dismiss(animated: true)
            }

            // 6) 일기 분석 컨텍스트 주입
            target.chatContext = .emotionDiaryAnalysis
            target.diaryContext = DiaryContext(from: diary)
            target.initialDiaryData = diary
            target.initialUserText = nil  // 외부 트리거 경로 차단

            let startIfVisible: () -> Void = { [weak target] in
                guard let vc = target else { return }
                if vc.isViewLoaded, vc.view.window != nil, let ctx = vc.diaryContext {
                    // 화면에 붙은 상태에서만 직접 트리거 → 중복 없음
                    vc.didStartDiaryAnalysis = true
                    vc.requestDiaryAnalysisWithTracking(diary: ctx)
                }
            }

            // 화면 부착 상태에 따라 분기 처리
            if target.isViewLoaded, target.view.window != nil {
                // 기존 VC면 직접 트리거, 신규 VC면 setupInitialMessages가 처리하므로 생략
                if !createdNew { startIfVisible() }
            } else {
                // 탭 전환/모달 dismiss 애니메이션 완료를 기다린 뒤 한 번만 시도
                let delay: TimeInterval = didDismiss ? 0.18 : 0.08
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    if !createdNew { startIfVisible() }
                }
            }
        }
    }

// MARK: - 🚀 ChatViewController 디버그 헬퍼
extension ChatRouter {
    static func debugInfo() -> String {
        let hasCache = false  // 캐시 제거로 인해 항상 false
        let messageCount = SessionManager.shared.getRecentChatMessages(
            limit: AppConfig.Pagination.recentMessagesLimit
        ).count

        return """
            🔍 [ChatRouter 디버그 정보]
            • 캐시된 VC: \(hasCache ? "있음" : "없음")
            • 메시지 수: \(messageCount)개
            • SessionManager: \(SessionManager.shared)
            """
    }
}
