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
import HealthKit

/// 🔐 권한 타입 정의
enum PermissionType: String, CaseIterable {
    case notification = "notification"
    case calendar = "calendar"
    case health = "health"
    case backgroundAudio = "backgroundAudio"
    
    var displayName: String {
        switch self {
        case .notification:
            return "알림"
        case .calendar:
            return "캘린더"
        case .health:
            return "건강 데이터"
        case .backgroundAudio:
            return "백그라운드 오디오"
        }
    }
    
    var description: String {
        switch self {
        case .notification:
            return "할 일 미리 알림, 타이머 알림을 위해 필요합니다"
        case .calendar:
            return "할 일을 시스템 캘린더에 동기화하기 위해 필요합니다"
        case .health:
            return "수면 데이터와 마음챙김 분석을 위해 필요합니다"
        case .backgroundAudio:
            return "수면 사운드를 백그라운드에서 재생하기 위해 필요합니다"
        }
    }
    
    var icon: String {
        switch self {
        case .notification:
            return "🔔"
        case .calendar:
            return "📅"
        case .health:
            return "❤️"
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
    private let healthStore = HKHealthStore()
    private let eventStore = EKEventStore()
    
    // MARK: - Public Methods
    
    /// 모든 권한 상태를 확인
    func getAllPermissionStatuses(completion: @escaping ([PermissionType: PermissionStatus]) -> Void) {
        var statuses: [PermissionType: PermissionStatus] = [:]
        let group = DispatchGroup()
        
        for permissionType in PermissionType.allCases {
            group.enter()
            getPermissionStatus(for: permissionType) { status in
                statuses[permissionType] = status
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
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
        case .health:
            getHealthPermissionStatus(completion: completion)
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
        case .health:
            requestHealthPermission(completion: completion)
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
        let urlString: String
        
        switch type {
        case .notification:
            urlString = UIApplication.openSettingsURLString
        case .calendar:
            urlString = "App-prefs:Privacy&path=CALENDARS"
        case .health:
            urlString = "x-apple-health://sources/\(Bundle.main.bundleIdentifier ?? "")"
        case .backgroundAudio:
            urlString = UIApplication.openSettingsURLString
        }
        
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // 특정 설정으로 이동할 수 없는 경우 일반 설정으로 이동
            openAppSettings()
        }
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
        eventStore.requestFullAccessToEvents { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🔴 Calendar permission error: \(error.localizedDescription)")
                    completion(false)
                } else {
                    completion(granted)
                }
            }
        }
    }
}

// MARK: - Private Methods - Health
private extension PermissionManager {
    
    func getHealthPermissionStatus(completion: @escaping (PermissionStatus) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(.restricted)
            return
        }
        
        // 건강 앱에서는 개별 데이터 타입별로 권한을 확인해야 함
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession)!
        
        let sleepStatus = healthStore.authorizationStatus(for: sleepType)
        let mindfulStatus = healthStore.authorizationStatus(for: mindfulType)
        
        DispatchQueue.main.async {
            // 둘 중 하나라도 허용되면 authorized로 처리
            if sleepStatus == .sharingAuthorized || mindfulStatus == .sharingAuthorized {
                completion(.authorized)
            } else if sleepStatus == .sharingDenied && mindfulStatus == .sharingDenied {
                completion(.denied)
            } else {
                completion(.notDetermined)
            }
        }
    }
    
    func requestHealthPermission(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }
        
        let readTypes: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.categoryType(forIdentifier: .mindfulSession)!
        ]
        
        let writeTypes: Set<HKSampleType> = [
            HKObjectType.categoryType(forIdentifier: .mindfulSession)!
        ]
        
        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🔴 Health permission error: \(error.localizedDescription)")
                    completion(false)
                } else {
                    completion(granted)
                }
            }
        }
    }
}

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