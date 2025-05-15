import UIKit
import AVFoundation

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    // iOS 13 이상부터 SceneDelegate로 UI 진입점을 분리했어도
    // 여기는 앱 전체 초기화 코드(오디오 세션, 백그라운드 재생 등)를 넣습니다.
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        configureAudioSession()
        // 제어 센터(remote control) 이벤트 받기 시작
        application.beginReceivingRemoteControlEvents()
        return true
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
