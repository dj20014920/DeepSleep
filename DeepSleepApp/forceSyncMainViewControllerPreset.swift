import UIKit

/// MainViewController에 프리셋을 강제로 동기화하고 UI를 업데이트합니다.
/// - Note: 이 함수는 UI 계층 구조를 순회하므로 메인 스레드에서만 호출해야 합니다.
func forceSyncMainViewControllerPreset(volumes: [Float], versions: [Int], name: String) {
    // 1. SoundManager를 통해 실제 사운드 프리셋을 적용합니다.
    SoundManager.shared.applyPresetWithVersions(volumes: volumes, versions: versions)
    
    // 2. NotificationCenter를 통해 프리셋 변경을 앱 전체에 알립니다.
    //    UI 업데이트는 이 알림을 수신하는 각 ViewController가 담당합니다.
    let userInfo = ["presetName": name]
    NotificationCenter.default.post(name: .PresetChanged, object: nil, userInfo: userInfo)
    
    print("✅ [forceSyncMainViewControllerPreset] SoundManager에 프리셋 적용 및 Notification 전송 완료: \(name)")
}

extension Notification.Name {
    /// 사운드 프리셋이 변경되었을 때 발생하는 알림입니다.
    static let PresetChanged = Notification.Name("PresetChangedNotification")
} 
