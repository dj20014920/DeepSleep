import UIKit
import AVFoundation

/// 시스템 상태 감지 및 모니터링 매니저
class SystemDetectionManager {
    static let shared = SystemDetectionManager()
    
    private init() {
        setupNotificationObservers()
    }
    
    // MARK: - Notification Observers
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioRouteChanged),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelChanged),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateChanged),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
        
        // 배터리 모니터링 활성화
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        DebugManager.shared.logSystem("SystemDetectionManager initialized")
    }
    
    // MARK: - Audio Detection
    
    /// 헤드폰 연결 상태 확인
    func isHeadphonesConnected() -> Bool {
        let route = AVAudioSession.sharedInstance().currentRoute
        
        for description in route.outputs {
            let portType = description.portType
            
            // 유선 헤드폰
            if portType == .headphones {
                DebugManager.shared.logSystem("Wired headphones detected")
                return true
            }
            
            // 블루투스 헤드폰/이어폰
            if portType == .bluetoothA2DP || 
               portType == .bluetoothLE ||
               portType == .bluetoothA2DP {
                DebugManager.shared.logSystem("Bluetooth audio device detected: \(portType.rawValue)")
                return true
            }
            
            // AirPods 등 기타 블루투스 오디오
            if description.portName.lowercased().contains("airpods") ||
               description.portName.lowercased().contains("beats") ||
               description.portName.lowercased().contains("headphones") {
                DebugManager.shared.logSystem("Bluetooth headphones detected by name: \(description.portName)")
                return true
            }
        }
        
        DebugManager.shared.logSystem("No headphones detected")
        return false
    }
    
    /// 현재 오디오 출력 장치 정보 가져오기
    func getCurrentAudioOutputInfo() -> AudioOutputInfo {
        let route = AVAudioSession.sharedInstance().currentRoute
        let outputs = route.outputs
        
        if outputs.isEmpty {
            return AudioOutputInfo(type: .unknown, name: "Unknown", isHeadphones: false)
        }
        
        let primaryOutput = outputs.first!
        let portType = primaryOutput.portType
        let portName = primaryOutput.portName
        
        var outputType: AudioOutputType = .unknown
        var isHeadphones = false
        
        switch portType {
        case .builtInSpeaker:
            outputType = .speaker
        case .builtInReceiver:
            outputType = .receiver
        case .headphones:
            outputType = .wiredHeadphones
            isHeadphones = true
        case .bluetoothA2DP, .bluetoothLE:
            outputType = .bluetoothHeadphones
            isHeadphones = true
        case .airPlay:
            outputType = .airPlay
        case .carAudio:
            outputType = .carAudio
        default:
            outputType = .other
        }
        
        let info = AudioOutputInfo(type: outputType, name: portName, isHeadphones: isHeadphones)
        DebugManager.shared.logSystem("Current audio output: \(info)")
        return info
    }
    
    // MARK: - Battery Detection
    
    /// 현재 배터리 레벨 (0.0 - 1.0)
    func getBatteryLevel() -> Float {
        let level = UIDevice.current.batteryLevel
        DebugManager.shared.logSystem("Battery level: \(Int(level * 100))%")
        return level
    }
    
    /// 배터리 상태 확인
    func getBatteryState() -> UIDevice.BatteryState {
        let state = UIDevice.current.batteryState
        DebugManager.shared.logSystem("Battery state: \(state)")
        return state
    }
    
    /// 저전력 모드 여부 확인
    func isLowPowerModeEnabled() -> Bool {
        let isEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        DebugManager.shared.logSystem("Low power mode: \(isEnabled ? "enabled" : "disabled")")
        return isEnabled
    }
    
    /// 배터리 상태 종합 정보
    func getBatteryInfo() -> BatteryInfo {
        return BatteryInfo(
            level: getBatteryLevel(),
            state: getBatteryState(),
            isLowPowerMode: isLowPowerModeEnabled()
        )
    }
    
    // MARK: - Device Detection
    
    /// 현재 기기 모델 확인
    func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String.init(validatingUTF8: ptr)
            }
        }
        return modelCode ?? "Unknown"
    }
    
    /// 화면 크기 정보
    func getScreenInfo() -> ScreenInfo {
        let screen = UIScreen.main
        let bounds = screen.bounds
        let scale = screen.scale
        
        return ScreenInfo(
            size: bounds.size,
            scale: scale,
            nativeBounds: screen.nativeBounds
        )
    }
    
    /// 다크 모드 여부 확인
    func isDarkModeEnabled() -> Bool {
        let isDark = UITraitCollection.current.userInterfaceStyle == .dark
        DebugManager.shared.logSystem("Dark mode: \(isDark ? "enabled" : "disabled")")
        return isDark
    }
    
    // MARK: - Network Detection
    
    /// 네트워크 연결 상태 (간단한 체크)
    func isNetworkAvailable() -> Bool {
        // 실제 네트워크 체크는 별도 라이브러리나 더 복잡한 로직이 필요
        // 여기서는 간단한 체크만 수행
        return true // 임시로 항상 true 반환
    }
    
    // MARK: - Notification Handlers
    
    @objc private func audioRouteChanged(notification: Notification) {
        DebugManager.shared.logSystem("Audio route changed")
        
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .newDeviceAvailable:
            DebugManager.shared.logSystem("New audio device available")
        case .oldDeviceUnavailable:
            DebugManager.shared.logSystem("Audio device disconnected")
        case .categoryChange:
            DebugManager.shared.logSystem("Audio category changed")
        default:
            DebugManager.shared.logSystem("Audio route change reason: \(reason.rawValue)")
        }
        
        // 헤드폰 상태 변경 알림 발송
        NotificationCenter.default.post(
            name: .headphonesConnectionChanged,
            object: nil,
            userInfo: ["isConnected": isHeadphonesConnected()]
        )
    }
    
    @objc private func batteryLevelChanged(notification: Notification) {
        let level = getBatteryLevel()
        DebugManager.shared.logSystem("Battery level changed: \(Int(level * 100))%")
        
        NotificationCenter.default.post(
            name: .batteryLevelChanged,
            object: nil,
            userInfo: ["level": level]
        )
    }
    
    @objc private func batteryStateChanged(notification: Notification) {
        let state = getBatteryState()
        DebugManager.shared.logSystem("Battery state changed: \(state)")
        
        NotificationCenter.default.post(
            name: .batteryStateChanged,
            object: nil,
            userInfo: ["state": state]
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Supporting Types

struct AudioOutputInfo: CustomStringConvertible {
    let type: AudioOutputType
    let name: String
    let isHeadphones: Bool
    
    var description: String {
        return "\(type.rawValue) (\(name)) - Headphones: \(isHeadphones)"
    }
}

enum AudioOutputType: String {
    case speaker = "Speaker"
    case receiver = "Receiver"
    case wiredHeadphones = "Wired Headphones"
    case bluetoothHeadphones = "Bluetooth Headphones"
    case airPlay = "AirPlay"
    case carAudio = "Car Audio"
    case other = "Other"
    case unknown = "Unknown"
}

struct BatteryInfo {
    let level: Float
    let state: UIDevice.BatteryState
    let isLowPowerMode: Bool
    
    var levelPercentage: Int {
        return Int(level * 100)
    }
    
    var isCharging: Bool {
        return state == .charging
    }
}

struct ScreenInfo {
    let size: CGSize
    let scale: CGFloat
    let nativeBounds: CGRect
    
    var pixelSize: CGSize {
        return CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let headphonesConnectionChanged = Notification.Name("headphonesConnectionChanged")
    static let batteryLevelChanged = Notification.Name("batteryLevelChanged")
    static let batteryStateChanged = Notification.Name("batteryStateChanged")
}

// MARK: - Global Functions (for backward compatibility)
/// 전역 함수로 헤드폰 연결 상태 확인
func isHeadphonesConnected() -> Bool {
    return SystemDetectionManager.shared.isHeadphonesConnected()
} 