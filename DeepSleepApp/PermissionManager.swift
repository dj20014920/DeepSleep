//
//  PermissionManager.swift
//  DeepSleep
//
//  Created on 2025-09-01.
//

import Foundation
import UIKit
import UserNotifications
import EventKit

/// 🔐 권한 타입 정의
enum PermissionType: String, CaseIterable {
    case notification = "notification"
    case calendar = "calendar"
    case backgroundAudio = "backgroundAudio"
    
    var displayName: String {
        switch self {
        case .notification:
            return "알림"
        case .calendar:
            return "캘린더"
        
        case .backgroundAudio:
            return "백그라운드 오디오"
        }
    }
    
    var description: String {
        switch self {
        case .notification:
            return "할 일 미리 알림, 타이머 알림을 위해 필요합니다"
        case .calendar:
            return "할 일을 iPhone 캘린더 앱과 동기화하여 일정 관리를 도와드립니다. iOS 설정에서 바로 변경 가능합니다."
        
        case .backgroundAudio:
            return "수면 사운드를 백그라운드에서 재생하기 위해 필요합니다. 자동으로 설정됩니다."
        }
    }
    
    var icon: String {
        switch self {
        case .notification:
            return "🔔"
        case .calendar:
            return "📅"
        
        case .backgroundAudio:
            return "🎵"
        }
    }
}

/// 🔐 권한 상태 정의
enum PermissionStatus {
    case notDetermined
    case denied
    case authorized
    case restricted
    case provisional // 알림 전용
    
    var displayName: String {
        switch self {
        case .notDetermined:
            return "확인 안됨"
        case .denied:
            return "거부됨"
        case .authorized:
            return "허용됨"
        case .restricted:
            return "제한됨"
        case .provisional:
            return "임시 허용"
        }
    }
    
    var isEnabled: Bool {
        switch self {
        case .authorized, .provisional:
            return true
        default:
            return false
        }
    }
    
    var color: UIColor {
        switch self {
        case .authorized, .provisional:
            return UIColor.systemGreen
        case .denied:
            return UIColor.systemRed
        case .restricted:
            return UIColor.systemOrange
        case .notDetermined:
            return UIColor.systemBlue
        }
    }
}

/// 🔐 권한 통합 관리자
/// 모든 앱 권한을 중앙에서 관리하는 싱글톤 클래스
class PermissionManager {
    
    // MARK: - Singleton
    static let shared = PermissionManager()
    private init() {}
    
    // MARK: - Properties
    // 건강 권한 지원 제거됨
    private let eventStore = EKEventStore()
    
    // MARK: - Public Methods
    
    /// 릫든 권한 상태를 확인
    func getAllPermissionStatuses(completion: @escaping ([PermissionType: PermissionStatus]) -> Void) {
        print("🔍 [PermissionManager] 모든 권한 상태 확인 시작")
        var statuses: [PermissionType: PermissionStatus] = [:]
        let group = DispatchGroup()
        
        for permissionType in PermissionType.allCases {
            group.enter()
            print("ℹ️ [PermissionManager] \(permissionType.displayName) 권한 상태 확인 중...")
            getPermissionStatus(for: permissionType) { status in
                print("✅ [PermissionManager] \(permissionType.displayName): \(status.displayName)")
                statuses[permissionType] = status
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            print("🎉 [PermissionManager] 모든 권한 상태 확인 완료")
            completion(statuses)
        }
    }
    
    /// 특정 권한 상태 확인
    func getPermissionStatus(for type: PermissionType, completion: @escaping (PermissionStatus) -> Void) {
        switch type {
        case .notification:
            getNotificationPermissionStatus(completion: completion)
        case .calendar:
            getCalendarPermissionStatus(completion: completion)
        
        case .backgroundAudio:
            getBackgroundAudioPermissionStatus(completion: completion)
        }
    }
    
    /// 권한 요청
    func requestPermission(for type: PermissionType, completion: @escaping (Bool) -> Void) {
        switch type {
        case .notification:
            requestNotificationPermission(completion: completion)
        case .calendar:
            requestCalendarPermission(completion: completion)
        
        case .backgroundAudio:
            // 백그라운드 오디오는 Info.plist 설정으로 자동 처리
            completion(true)
        }
    }
    
    /// iOS 설정 앱으로 이동
    func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl, completionHandler: nil)
        }
    }
    
    /// 특정 권한 섹션으로 이동 (iOS 설정)
    func openSpecificPermissionSettings(for type: PermissionType) {
        // iOS에서는 특정 권한 페이지로 직접 이동이 제한되어 있으므로
        // 앱의 설정 페이지로 이동하여 사용자가 직접 권한을 관리하도록 함
        openAppSettings()
    }
}

// MARK: - Private Methods - Notification
private extension PermissionManager {
    
    func getNotificationPermissionStatus(completion: @escaping (PermissionStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    completion(.notDetermined)
                case .denied:
                    completion(.denied)
                case .authorized:
                    completion(.authorized)
                case .provisional:
                    completion(.provisional)
                case .ephemeral:
                    completion(.provisional)
                @unknown default:
                    completion(.notDetermined)
                }
            }
        }
    }
    
    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
}

// MARK: - Private Methods - Calendar
private extension PermissionManager {
    
    func getCalendarPermissionStatus(completion: @escaping (PermissionStatus) -> Void) {
        let status = EKEventStore.authorizationStatus(for: .event)
        
        DispatchQueue.main.async {
            switch status {
            case .notDetermined:
                completion(.notDetermined)
            case .denied:
                completion(.denied)
            case .authorized, .fullAccess:
                completion(.authorized)
            case .restricted:
                completion(.restricted)
            case .writeOnly:
                completion(.authorized) // 쓰기 권한도 허용으로 간주
            @unknown default:
                completion(.notDetermined)
            }
        }
    }
    
    func requestCalendarPermission(completion: @escaping (Bool) -> Void) {
        print("📅 [PermissionManager] 캘린더 권한 요청 시작")
        
        if #available(iOS 17.0, *) {
            print("ℹ️ [PermissionManager] iOS 17+ requestFullAccessToEvents 사용")
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("🔴 [PermissionManager] 캘린더 권한 오류: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        print("✅ [PermissionManager] 캘린더 권한 결과: \(granted ? "허용" : "거부")")
                        completion(granted)
                    }
                }
            }
        } else {
            print("ℹ️ [PermissionManager] iOS 16 이하 requestAccess 사용")
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("🔴 [PermissionManager] 캘린더 권한 오류: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        print("✅ [PermissionManager] 캘린더 권한 결과: \(granted ? "허용" : "거부")")
                        completion(granted)
                    }
                }
            }
        }
    }
}

// MARK: - Health-related permissions removed
// 본 앱은 건강(헬스) 권한을 사용하지 않습니다.

// MARK: - Private Methods - Background Audio
private extension PermissionManager {
    
    func getBackgroundAudioPermissionStatus(completion: @escaping (PermissionStatus) -> Void) {
        // 백그라운드 오디오는 Info.plist 설정이므로 항상 허용된 것으로 간주
        // 실제로는 UIBackgroundModes에 audio가 포함되어 있는지 확인
        let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        let hasAudioMode = backgroundModes?.contains("audio") ?? false
        
        DispatchQueue.main.async {
            completion(hasAudioMode ? .authorized : .denied)
        }
    }
}