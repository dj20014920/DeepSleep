import Foundation
import UIKit

/// AI 기능 유형을 정의하여 중앙에서 관리
enum AIFeatureType: String {
    case chat = "Chat"
    case presetRecommendation = "PresetRecommendation"
    case diaryAnalysis = "DiaryAnalysis"
    case patternAnalysis = "PatternAnalysis"
    case individualTodoAdvice = "IndividualTodoAdvice"
    case overallTodoAdvice = "OverallTodoAdvice"
}

class AIUsageManager {
    static let shared = AIUsageManager()

    private let userDefaults = UserDefaults.standard
    
    // 각 기능별 일일 제한 횟수 설정
    private let dailyLimits: [AIFeatureType: Int] = [
        .chat: 50,
        .presetRecommendation: 5,
        .diaryAnalysis: 5,
        .patternAnalysis: 1,
        .individualTodoAdvice: 2,
        .overallTodoAdvice: 2
    ]

    private var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private init() {
        // 앱 시작 시 모든 기능의 사용 횟수 초기화 검사
        AIFeatureType.allCases.forEach { resetCountIfNeeded(for: $0) }
    }

    private func todaysDateString() -> String {
        return dateFormatter.string(from: Date())
    }
    
    // MARK: - 중앙 관리 로직

    /// 특정 기능의 사용 횟수를 초기화합니다.
    private func resetCountIfNeeded(for feature: AIFeatureType) {
        let lastDateKey = "last_\(feature.rawValue)_date"
        let countKey = "daily_\(feature.rawValue)_count"
        let todayString = todaysDateString()
        
        guard let lastDateString = userDefaults.string(forKey: lastDateKey) else {
            userDefaults.set(todayString, forKey: lastDateKey)
            userDefaults.set(0, forKey: countKey)
            return
        }

        if lastDateString != todayString {
            userDefaults.set(0, forKey: countKey)
            userDefaults.set(todayString, forKey: lastDateKey)
            print("✨ AI 기능 [\(feature.rawValue)] 사용 횟수가 초기화되었습니다.")
        }
    }

    /// 특정 기능을 오늘 더 사용할 수 있는지 확인합니다.
    func canUse(feature: AIFeatureType) -> Bool {
        // 🚀 개발자 무제한 모드 (특정 디바이스 ID 체크)
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? ""
        
        // 🔍 디바이스 정보 로깅 (필요시 활성화)
        // print("📱 [디바이스 확인] Current Device ID: \(deviceID)")
        // print("📱 [디바이스 확인] Device Name: \(UIDevice.current.name)")
        // print("📱 [디바이스 확인] Device Model: \(UIDevice.current.model)")
        
        let testDeviceIDs = [
            "5A84073B-5CD7-4227-B424-0BFF552EF47F", // 개발자 디바이스
            "00008140-000A15401442801C", // 테스트 디바이스 
            "D27A7DCF-0BBA-5CEF-B989-998764F4732B", // 개발자 macOS
            "2AB9C823-CB6B-4F76-B5DA-EF8ABAB262BD" // CDJ iPhone 무제한 모드
        ]
        
        if testDeviceIDs.contains(deviceID) {
            print("🚀 [개발자 모드] 무제한 AI 사용 허용: \(deviceID)")
            return true
        }
        
        resetCountIfNeeded(for: feature)
        let countKey = "daily_\(feature.rawValue)_count"
        let usedCount = userDefaults.integer(forKey: countKey)
        let limit = dailyLimits[feature] ?? 0
        return usedCount < limit
    }

    /// 특정 기능의 남은 사용 횟수를 반환합니다.
    func getRemainingCount(for feature: AIFeatureType) -> Int {
        resetCountIfNeeded(for: feature)
        let countKey = "daily_\(feature.rawValue)_count"
        let usedCount = userDefaults.integer(forKey: countKey)
        let limit = dailyLimits[feature] ?? 0
        return max(0, limit - usedCount)
    }

    /// 특정 기능의 사용을 기록합니다.
    @discardableResult
    func recordUsage(for feature: AIFeatureType) -> Bool {
        resetCountIfNeeded(for: feature)
        let countKey = "daily_\(feature.rawValue)_count"
        let currentCount = userDefaults.integer(forKey: countKey)
        let limit = dailyLimits[feature] ?? 0
        
        if currentCount < limit {
            userDefaults.set(currentCount + 1, forKey: countKey)
            print("💡 AI 기능 [\(feature.rawValue)] 사용 기록됨. 오늘 사용: \(currentCount + 1)/\(limit)")
            return true
        } else {
            print("⚠️ AI 기능 [\(feature.rawValue)] 사용 횟수 초과.")
            return false
        }
    }
    
    /// (테스트용) 특정 기능의 사용 횟수를 강제로 초기화합니다.
    func forceResetCount(for feature: AIFeatureType) {
        let countKey = "daily_\(feature.rawValue)_count"
        let lastDateKey = "last_\(feature.rawValue)_date"
        userDefaults.set(0, forKey: countKey)
        userDefaults.set(todaysDateString(), forKey: lastDateKey)
        print("⚠️ 관리자에 의해 AI 기능 [\(feature.rawValue)] 사용 횟수가 강제 초기화되었습니다.")
    }
}

// CaseIterable 추가
extension AIFeatureType: CaseIterable {} 

