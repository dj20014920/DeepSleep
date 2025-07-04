import UIKit
import AVFoundation
import UserNotifications
import SwiftData
import CoreData
import Core

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

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
            UserContext.self
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
        RemoteLogger.shared.info("앱 시작됨 - \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")", category: "AppLifecycle")
        RemoteLogger.shared.logMemoryUsage(context: "앱 시작 시")
        
        // 🔐 API 키 보안 검증 실행
        EnvironmentConfig.shared.performSecurityCheck()
        
        // SoundManager 초기화 (내부에서 오디오 세션 설정)
        _ = SoundManager.shared // SoundManager.shared를 호출하여 초기화 유도
        RemoteLogger.shared.info("SoundManager 초기화 완료", category: "AppLifecycle")
        
        // 제어 센터(remote control) 이벤트 받기 시작 (오디오 세션 설정 이후에 호출되도록)
        application.beginReceivingRemoteControlEvents()
        
        // 알림 센터 delegate 설정
        UNUserNotificationCenter.current().delegate = self
        
        // 알림 권한 요청
        requestNotificationAuthorization()
        
        // 앱 시작 시 모든 알림 재스케줄링
        TodoManager.shared.rescheduleAllNotifications()
        
        // MARK: - Fallback UI Setup
        // If SceneDelegate is not invoked, ensure LaunchViewController appears
        let fallbackWindow = UIWindow(frame: UIScreen.main.bounds)
        fallbackWindow.rootViewController = LaunchViewController()
        fallbackWindow.makeKeyAndVisible()
        self.window = fallbackWindow
        
        return true
    }

    // MARK: - Notification Authorization & Handling
    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("🔔 알림 권한 허용됨")
            } else if let error = error {
                print("🔔 알림 권한 요청 오류: \(error.localizedDescription)")
            } else {
                print("🔔 알림 권한 거부됨")
            }
        }
    }
    
    // 앱이 foreground에 있을 때 알림을 수신하면 호출됨
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 앱이 실행 중일 때도 알림을 표시하도록 설정 (alert, sound, badge 모두 사용)
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    // 사용자가 알림을 탭했을 때 호출됨
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        // TODO: 알림을 통해 특정 Todo 항목으로 이동하는 등의 액션 처리
        print("🔔 알림 탭: \(userInfo)")
        
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

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DeepSleep")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
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
}
