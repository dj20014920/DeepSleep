import AVFoundation
import BackgroundTasks
import CoreData
import SwiftData
import UIKit
import UserNotifications

// 타입 접근성 문제로 인해 임시 주석 처리

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    override init() {
        super.init()
        // 시작 시 AFM 세션 풀/캐시 메트릭 로거 초기화
        CacheMetricsLogger.shared.startPeriodicAFMStatsLogging()
        CacheMetricsLogger.shared.logAppleFMSessionPoolStatsOnce()
    }

    /// Fallback window for non-scene UI
    var window: UIWindow?

    static var shared: AppDelegate {
        guard let delegate = UIApplication.shared.delegate as? AppDelegate else {
            fatalError("AppDelegate is not of expected type")
        }
        return delegate
    }

    @available(iOS 17.0, *)
    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserPersona.self,
            ConversationTurn.self,
            FeedbackLog.self,
            UserContext.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // iOS 13 이상부터 SceneDelegate로 UI 진입점을 분리했어도
    // 여기는 앱 전체 초기화 코드(오디오 세션, 백그라운드 재생 등)를 넣습니다.
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // 🔍 원격 로깅 시작
        let currentVersion =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        UnifiedLogger.shared.info("앱 시작됨 - \(currentVersion)", category: .appLifecycle)
        UnifiedLogger.shared.logMemoryUsage("앱 시작 시")

        // 🧹 앱 버전 변경 감지 시 시스템 프롬프트 캐시 무효화 (8/18 정책)
        let lastSeenKey = "app_version_last_seen"
        let lastSeenVersion = UserDefaults.standard.string(forKey: lastSeenKey)
        if lastSeenVersion == nil || lastSeenVersion != currentVersion {
            // 버전 변경 캐시 무효화: 단순화 정책으로 .manual 사용
            AIContextManager.shared.clearCache(
                reason: .manual, caller: "AppDelegate.appVersionChange")
            UserDefaults.standard.set(currentVersion, forKey: lastSeenKey)
            UnifiedLogger.shared.info("앱 버전 변경 감지 → 캐시 무효화 수행", category: .appLifecycle)
        }

        // 🔐 API 키 보안 검증 실행
        EnvironmentConfig.shared.performSecurityCheck()

        // 초기 메트릭 요약 로그 출력
        let summary = ContextMetrics.shared.oneLineSummary()
        UnifiedLogger.shared.info("\(summary)", category: .appLifecycle)

        // 🚀 성능 관리 시스템 초기화 (최우선 - 다른 시스템들이 성능 관리자에 의존할 수 있음)
        PerformanceSystemBootstrap.shared.initializePerformanceSystem()

        // 💎 구독 시스템 초기화 및 MemoryManager 티어 설정
        initializeSubscriptionSystem()

        // 💯 완전 토큰 소모 제로 API 체크
        performZeroTokenAPICheck()

        // SoundManager 초기화 (내부에서 오디오 세션 설정)
        _ = SoundManager.shared  // SoundManager.shared를 호출하여 초기화 유도
        UnifiedLogger.shared.info("SoundManager 초기화 완료", category: .appLifecycle)

        // 제어 센터(remote control) 이벤트 받기 시작 (오디오 세션 설정 이후에 호출되도록)
        application.beginReceivingRemoteControlEvents()

        // 알림 센터 delegate 설정
        UNUserNotificationCenter.current().delegate = self

        // 알림 권한 요청
        requestNotificationAuthorization()

        // 앱 시작 시 모든 알림 재스케줄링
        TodoManager.shared.rescheduleAllNotifications()
        // 운세 알림도 스케줄링
        CentralNotificationScheduler.shared.scheduleFortuneNotification()

        // ⏱️ 시간 지정된 할 일 자동 완료 모니터 시작
        TodoAutoCompleter.shared.start()

        // AdMob SDK 초기화(가능한 경우). 실제 배너 로드는 뷰컨트롤러에서 처리.
        AdsManager.shared.configureIfPossible()

        // MARK: - Fallback UI Setup
        // SceneDelegate가 iOS 13+에서 메인 UI를 처리하므로 여기서는 설정하지 않음
        // 필요시에만 fallback window 생성
        if #available(iOS 13.0, *) {
            // SceneDelegate가 처리하므로 여기서는 window 설정하지 않음
            print("📱 iOS 13+ SceneDelegate 모드 - UI 설정 스킵")
        } else {
            // iOS 12 이하에서만 fallback UI 설정
            let fallbackWindow = UIWindow(frame: UIScreen.main.bounds)
            fallbackWindow.rootViewController = LaunchViewController()
            fallbackWindow.makeKeyAndVisible()
            self.window = fallbackWindow
            print("📱 iOS 12 이하 - Fallback UI 설정")
        }

        // 프록시 인증 메모리 캐시 워밍(앱 시작 시 1회)
        Task.detached {
            [
                useProxy = EnvironmentConfig.shared.useProxy,
                base = EnvironmentConfig.shared.proxyBaseURL
            ] in
            guard useProxy, let url = URL(string: base),
                let uid = UIDevice.current.identifierForVendor?.uuidString
            else { return }
            do {
                _ = try await ProxyAuthClient.loadSecretOrEnroll(uid: uid, proxyBase: url)
                print("✅ [AppLaunch] Proxy secret warmed in memory")
            } catch {
                print("⚠️ [AppLaunch] Proxy secret warm-up failed: \(error)")
            }
        }

        // BGTask 등록 (iOS13+)
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: "com.deepsleep.feedback.learning", using: nil
            ) { task in
                self.handleFeedbackLearningTask(task: task as! BGAppRefreshTask)
            }
        }

        // 초기 앱 실행 시 항상 흰색 아이콘 강제 적용
        AppIconManager.enforceWhiteIcon()

        // 앱 실행 직후 전달된 알림과 배지 초기화
        CentralNotificationScheduler.shared.clearDeliveredNotificationsAndResetBadge()

        // On-device model remote endpoints injection (HTTP downloader)
        // NOTE: Prefer presignEndpoint if available; otherwise use CDN fallback.
        // //mltodo Replace with real endpoints from remote config.
        // Cloudflare Worker presign + CDN 베이스를 앱 런치 시 주입
        if let presign = URL(string: "https://emozleep-presign.vinny4920-081.workers.dev/presign"),
            let cdn = URL(string: "https://cdn.emozleep.space/models")
        {
            OnDeviceAdapter.shared.reconfigureRemote(
                presignEndpoint: presign,
                cdnBaseURL: cdn,
                backgroundSessionID: "com.deepsleep.models.bg",
                cancelOngoing: false
            )
            // 카탈로그 외 모델 파일 정리(한 번 실행)
            _ = OnDeviceAdapter.shared.purgeObsoleteInstalledFiles()
        }

        // ✅ 앱 실행 시 1회 온디바이스 선호 모델 프리로드(있다면)
        Task {
            let settings = SettingsManager.shared
            guard settings.selectedLLM == .onDevice else { return }
            let id = settings.preferredOnDeviceModelID ?? ModelCatalog.defaultModelID
            do {
                try await OnDeviceAdapter.shared.activate(id: id)
                print("🚚 모델 프리로드 완료 id=\(id.rawValue)")
            } catch {
                print("⚠️ 모델 프리로드 실패: \(error.localizedDescription)")
            }
        }

        return true
    }

    // BG URLSession 이벤트 핸드오버(온디바이스 다운로드)
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        // RemoteAssetClient가 사용하는 백그라운드 세션 식별자와 일치하도록 재구성
        OnDeviceAdapter.shared.reconfigureRemote(
            presignEndpoint: URL(
                string: "https://emozleep-presign.vinny4920-081.workers.dev/presign"
            ),
            cdnBaseURL: URL(string: "https://cdn.emozleep.space/models"),
            backgroundSessionID: identifier,
            cancelOngoing: false
        )
        // 제한: RemoteAssetClient가 urlSessionDidFinishEvents의 외부 핸드오프를 노출하지 않으므로,
        // 여기서는 즉시 completionHandler를 호출합니다(시스템이 작업 지속 처리).
        completionHandler()
    }

    // MARK: - Subscription System

    /// 구독 시스템 초기화 및 MemoryManager 티어 설정
    private func initializeSubscriptionSystem() {
        // 실제 StoreKit2 기반 초기화: 제품 로드 및 권리 상태 새로고침
        Task {
            await StoreKitSubscriptionManager.shared.loadProducts()
            await StoreKitSubscriptionManager.shared.refreshEntitlements()
        }

        // 구독 상태 변경 브로드캐스트 수신 → 메모리 티어 및 로깅 반영
        NotificationCenter.default.addObserver(
            forName: .subscriptionStatusChanged,
            object: nil,
            queue: .main
        ) { _ in
            let isPremium = SubscriptionStatusCenter.shared.isPremium
            let tier: MemoryTier = isPremium ? .premium : .free
            MemoryManager.shared.setTier(tier)
            let tierText = isPremium ? "Premium" : "Free"
            UnifiedLogger.shared.info("💎 구독 상태 변경됨: \(tierText)", category: .appLifecycle)

            // ✅ 즐겨찾기 날짜 상한 적용 (프리미엄/트라이얼: 10, 무료: 3)
            let cap = isPremium ? 10 : 3
            let removed = SettingsManager.shared.enforceFavoriteCap(cap: cap)
            if removed > 0 {
                if !isPremium {
                    ToastManager.shared.showWarning(
                        message: "무료 플랜으로 전환되어 즐겨찾기 최대 3개만 유지됩니다. \(removed)개가 해제되었습니다.")
                } else {
                    ToastManager.shared.showToast(
                        message: "즐겨찾기 제한(\(cap)개)에 맞춰 \(removed)개가 정리되었습니다.")
                }
            }
        }
    }

    // MARK: - Notification Authorization & Handling
    func requestNotificationAuthorization() {
        CentralNotificationScheduler.shared.requestAuthorizationIfNeeded()
    }

    // 앱이 foreground에 있을 때 알림을 수신하면 호출됨
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) ->
            Void
    ) {
        // 앱이 실행 중일 때도 알림을 표시하도록 설정 (alert, sound, badge 모두 사용)
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    // 사용자가 알림을 탭했을 때 호출됨
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("🔔 알림 탭: \(userInfo)")

        // 운세 알림인지 확인
        if response.notification.request.identifier == "DeepSleep.fortune" {
            // 운세 탭으로 이동하도록 알림
            NotificationCenter.default.post(
                name: NSNotification.Name("GoToFortuneTab"), object: nil)
        }
        // TODO: 알림을 통해 특정 Todo 항목으로 이동하는 등의 액션 처리

        completionHandler()
    }

    // MARK: UISceneSession Lifecycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }

    func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {
        // 필요 시 릴리즈 로직
    }

    // MARK: - App Lifecycle Methods

    /// 앱이 비활성화되기 직전 (홈 버튼, 전화 수신 등)
    func applicationWillResignActive(_ application: UIApplication) {
        UnifiedLogger.shared.info("앱 비활성화 - 데이터 저장 시작", category: .appLifecycle)

        // 🎯 SessionManager 디스크 동기화 (메모리 → 디스크)
        SessionManager.shared.flush()
        UnifiedLogger.shared.info("SessionManager 데이터 플러시 완료", category: .appLifecycle)

        // 메트릭 요약 추가 로그
        let metricsLine = ContextMetrics.shared.oneLineSummary()
        let modelModeLine = ContextMetrics.shared.modelModeSummary()
        UnifiedLogger.shared.info("\(metricsLine)", category: .appLifecycle)
        UnifiedLogger.shared.info("\(modelModeLine)", category: .appLifecycle)

        // Core Data 저장
        saveContext()
    }

    /// 앱이 백그라운드로 진입
    func applicationDidEnterBackground(_ application: UIApplication) {
        // BGTask 스케줄
        if #available(iOS 13.0, *) {
            scheduleFeedbackLearningBGTask()
        }
        UnifiedLogger.shared.info("앱 백그라운드 진입 - 추가 저장 처리", category: .appLifecycle)

        // 🎯 한번 더 SessionManager 플러시 (안전성 강화)
        SessionManager.shared.flush()

        // MessageStore는 메모리 기반이므로 별도 플러시 불필요
        UnifiedLogger.shared.info("SessionManager 백그라운드 플러시 완료", category: .appLifecycle)
    }

    // MARK: - BGTask (Feedback Learning)
    @available(iOS 13.0, *)
    private func scheduleFeedbackLearningBGTask() {
        let request = BGAppRefreshTaskRequest(identifier: "com.deepsleep.feedback.learning")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)  // 15분 후 earliest
        do {
            try BGTaskScheduler.shared.submit(request)
            UnifiedLogger.shared.info("BGTask 스케줄 제출 완료", category: .appLifecycle)
        } catch {
            UnifiedLogger.shared.warning("BGTask 스케줄 제출 실패: \(error)", category: .appLifecycle)
        }
    }

    @available(iOS 13.0, *)
    private func handleFeedbackLearningTask(task: BGAppRefreshTask) {
        UnifiedLogger.shared.info("BGTask 실행 - 피드백 학습", category: .appLifecycle)
        scheduleFeedbackLearningBGTask()  // 다음 실행도 예약
        task.expirationHandler = {
            UnifiedLogger.shared.warning("BGTask 만료", category: .appLifecycle)
        }
        Task {
            if #available(iOS 17.0, *) {
                await FeedbackIntegrationManager.shared.performIncrementalLearning()
            }
            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - App Termination
    func applicationWillTerminate(_ application: UIApplication) {
        UnifiedLogger.shared.info("앱 종료 시작 - 리소스 정리", category: .appLifecycle)

        // 🎯 최종 SessionManager 플러시
        SessionManager.shared.flush()

        // Core Data 저장
        saveContext()

        // 성능 관리 시스템 정리
        PerformanceSystemBootstrap.shared.shutdownPerformanceSystem()

        UnifiedLogger.shared.info("앱 종료 완료", category: .appLifecycle)
    }

    // MARK: - 🚨 Phase 3: Core Data 에러 처리 개선

    /// Core Data 초기화 에러 사용자 알림
    private func showCoreDataError(_ error: NSError) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first,
            let rootViewController = window.rootViewController
        else {
            print("❌ [AppDelegate] 루트 뷰컨트롤러를 찾을 수 없음")
            return
        }

        let alert = UIAlertController(
            title: "데이터 저장소 초기화 오류",
            message:
                "앱의 데이터 저장소를 초기화하는 중 문제가 발생했습니다. 임시 저장소를 사용하여 계속 진행합니다.\n\n오류: \(error.localizedDescription)",
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(title: "계속 사용", style: .default) { _ in
                print("✅ [AppDelegate] 사용자가 임시 저장소 사용에 동의")
            })

        alert.addAction(
            UIAlertAction(title: "앱 재시작", style: .destructive) { _ in
                print("🔄 [AppDelegate] 사용자가 앱 재시작 선택")
                exit(0)  // 사용자가 명시적으로 선택한 경우에만 종료
            })

        rootViewController.present(alert, animated: true)
    }

    /// Core Data 저장 에러 사용자 알림
    private func showCoreDataSaveError(_ error: NSError) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first,
            let rootViewController = window.rootViewController
        else {
            return
        }

        let alert = UIAlertController(
            title: "데이터 저장 오류",
            message:
                "데이터를 저장하는 중 문제가 발생했습니다. 변경사항이 손실될 수 있습니다.\n\n오류: \(error.localizedDescription)",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "확인", style: .default))

        rootViewController.present(alert, animated: true)
    }

    /// 메모리 전용 저장소 설정 (폴백)
    private func setupInMemoryStore(container: NSPersistentContainer) {
        print("🔄 [AppDelegate] 메모리 전용 저장소로 폴백")

        // 기존 저장소 제거
        container.persistentStoreCoordinator.persistentStores.forEach { store in
            try? container.persistentStoreCoordinator.remove(store)
        }

        // 메모리 전용 저장소 추가
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false

        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { (storeDescription, error) in
            if let error = error {
                print("❌ [AppDelegate] 메모리 저장소 설정도 실패: \(error)")
                // 이 경우에는 정말 심각한 문제이므로 로깅만 하고 계속 진행
                UnifiedLogger.shared.error(
                    "메모리 저장소 설정 실패: \(error.localizedDescription)", category: .coreData)
            } else {
                print("✅ [AppDelegate] 메모리 전용 저장소 설정 완료")
                UnifiedLogger.shared.info("메모리 전용 저장소로 폴백 완료", category: .coreData)
            }
        }
    }

    /// Core Data 에러 로깅 (분석용)
    private func logCoreDataError(_ error: NSError) {
        let errorInfo: [String: Any] = [
            "error_code": error.code,
            "error_domain": error.domain,
            "error_description": error.localizedDescription,
            "user_info": error.userInfo.description,
            "timestamp": Date().timeIntervalSince1970,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
                ?? "unknown",
        ]

        // 원격 로깅 (실제 구현 시 원격 서버로 전송)
        UnifiedLogger.shared.error("Core Data 에러 상세 정보: \(errorInfo)", category: .coreData)

        // 로컬 로그 파일에도 저장 (디버깅용)
        if let documentsPath = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first {
            let logFile = documentsPath.appendingPathComponent("coredata_errors.log")
            let logEntry = "\(Date()): \(errorInfo)\n"

            if let data = logEntry.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: logFile.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    try? data.write(to: logFile)
                }
            }
        }
    }

    // MARK: - Core Data stack

    // SSOT: CoreDataStack.shared 를 단일 소스로 사용하여 다중 컨테이너 혼용으로 인한 크래시를 방지
    var persistentContainer: NSPersistentContainer {
        return CoreDataStack.shared.persistentContainer
    }

    // MARK: - Core Data Saving support

    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                // 🚨 Phase 3: fatalError 제거 - 우아한 에러 처리
                UnifiedLogger.shared.error(
                    "❌ Core Data 저장 실패: \(nserror.localizedDescription)", category: .coreData)

                // 1. 사용자에게 알림
                DispatchQueue.main.async {
                    self.showCoreDataSaveError(nserror)
                }

                // 2. 컨텍스트 롤백 시도
                context.rollback()

                // 3. 분석을 위한 에러 로깅
                self.logCoreDataError(nserror)
            }
        }
    }

    // MARK: - Audio Session 설정

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // 백그라운드 재생 허용, 다른 앱과 믹스 가능
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try session.setActive(true)
        } catch {
            print("🔴 AVAudioSession setup failed:", error)
        }
    }

    // MARK: - API 초기화 및 연결 테스트

    /// 완전 토큰 소모 제로 API 상태 확인
    private func performZeroTokenAPICheck() {
        // 프록시 모드에서는 API 키 검증을 생략(키 불필요), 네트워크 상태만 기본적으로 신뢰
        if EnvironmentConfig.shared.useProxy {
            print("🔌 [Proxy] 프록시 모드 활성화 → API 키 체크 생략")
            if EnvironmentConfig.shared.proxyBaseURL.isEmpty {
                print("⚠️ [Proxy] PROXY_BASE_URL이 비어 있습니다. Secrets.xcconfig/Info.plist를 확인하세요.")
            }
            print("📱 [메인 UI] 앱 메인 화면으로 진행...")
            return
        }

        // API 상태 확인 (토큰 소모 없음)
        // 1단계: 즉시 빠른 체크 (로컬 Info.plist 기반)
        let hasValidKeys: Bool = {
            return
                ((ConfigReader.string("GEMINI_API_KEY")?.isEmpty == false)
                || (ConfigReader.string("OPEN_AI_4oMINI_API_KEY")?.isEmpty == false)
                || (ConfigReader.string("CLAUDE_API_KEY")?.isEmpty == false)
                || (ConfigReader.string("NAVER_CLOUD_API_KEY")?.isEmpty == false)
                || (ConfigReader.string("OPENROUTER_API_KEY")?.isEmpty == false))
        }()
        let recommendedAPI: String? = hasValidKeys ? "gemini" : nil

        if hasValidKeys {
            print("✅ [즉시 결과] API 사용 준비 완료!")
            if let recommended = recommendedAPI { print("🏆 [권장 API] \(recommended)") }
            Task {
                await ZeroTokenAPIChecker.shared.performZeroTokenCheck()
                print("🎉 [최종 완료] 모든 상태 확인 완료 (토큰 소모 0개)")
            }
        } else {
            print("⚠️ [즉시 결과] API 키 설정이 필요합니다")
            showAPISetupGuidance()
        }

        print("📱 [메인 UI] 앱 메인 화면으로 진행...")
    }

    /// API 설정 안내 표시
    private func showAPISetupGuidance() {
        print("\n" + "📘" + " API 설정 가이드:")
        print("   1. Secrets.xcconfig 파일을 확인하세요")
        print("   2. API 키가 올바른 형식인지 확인하세요")
        print("   3. 네트워크 연결을 확인하세요")
        print("   4. API 키 잔액을 확인하세요")
        print("")

        // 사용자에게 설정 안내 알림 (선택적)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.scheduleAPISetupNotification()
        }
    }

    /// API 설정 안내 알림 스케줄링
    private func scheduleAPISetupNotification() {
        let content = UNMutableNotificationContent()
        content.title = "리플릿(Leaflet) API 설정 필요"
        content.body = "AI 기능을 사용하기 위해 API 키 설정이 필요합니다."
        content.sound = UNNotificationSound.default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "api-setup-guidance",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ API 설정 알림 스케줄 실패: \(error.localizedDescription)")
            }
        }
    }
}
