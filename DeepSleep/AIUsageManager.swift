import Foundation

class AIUsageManager {
    static let shared = AIUsageManager()

    private let userDefaults = UserDefaults.standard
    
    // 기존: 개별 할 일 조언에 대한 일일 총 한도 관리
    private let lastIndividualAdviceDateKey = "lastAIAdviceDateKey" // 키 이름 명확화
    private let dailyIndividualAdviceCountKey = "dailyAIAdviceCountKey" // 키 이름 명확화
    private let dailyIndividualAdviceLimit = 2 // 기존 제한 값 유지

    // 신규: 전체 할 일 목록 조언에 대한 일일 한도 관리
    private let lastOverallAdviceDateKey = "lastOverallAIAdviceDateKey"
    private let dailyOverallAdviceCountKey = "dailyOverallAIAdviceCountKey"
    private let dailyOverallAdviceLimit = 2 // 사용자 요청에 따른 제한 값

    private var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private init() {
        resetIndividualCountIfNeeded() // 함수 이름 명확화
        resetOverallCountIfNeeded()    // 새 기능 초기화 호출
    }

    private func todaysDateString() -> String {
        return dateFormatter.string(from: Date())
    }

    // MARK: - 개별 할 일 조언 일일 한도 관리
    
    /// (개별 조언) 날짜가 변경되었으면 일일 조언 횟수를 초기화합니다.
    func resetIndividualCountIfNeeded() { // 함수 이름 명확화
        let todayString = todaysDateString()
        guard let lastDateString = userDefaults.string(forKey: lastIndividualAdviceDateKey) else {
            userDefaults.set(todayString, forKey: lastIndividualAdviceDateKey)
            userDefaults.set(0, forKey: dailyIndividualAdviceCountKey)
            return
        }

        if lastDateString != todayString {
            userDefaults.set(0, forKey: dailyIndividualAdviceCountKey)
            userDefaults.set(todayString, forKey: lastIndividualAdviceDateKey)
            print("✨ (개별) AI 조언 횟수가 초기화되었습니다. (날짜 변경)")
        }
    }

    /// (개별 조언) 오늘 남은 AI 조언 횟수를 반환합니다.
    func getRemainingDailyIndividualAdviceCount() -> Int { // 함수 이름 명확화
        resetIndividualCountIfNeeded()
        let usedCount = userDefaults.integer(forKey: dailyIndividualAdviceCountKey)
        return max(0, dailyIndividualAdviceLimit - usedCount)
    }

    /// (개별 조언) AI 조언을 성공적으로 사용했음을 기록합니다.
    @discardableResult
    func recordIndividualAdviceUsed() -> Bool { // 함수 이름 명확화
        resetIndividualCountIfNeeded()
        let currentCount = userDefaults.integer(forKey: dailyIndividualAdviceCountKey)
        
        if currentCount < dailyIndividualAdviceLimit {
            userDefaults.set(currentCount + 1, forKey: dailyIndividualAdviceCountKey)
            print("💡 (개별) AI 조언 사용 기록됨. 오늘 사용한 횟수: \(currentCount + 1)/\(dailyIndividualAdviceLimit)")
            return true
        } else {
            print("⚠️ (개별) AI 조언 횟수 초과. 더 이상 사용할 수 없습니다.")
            return false
        }
    }
    
    /// (개별 조언 테스트용) 일일 조언 횟수를 강제로 초기화합니다.
    func forceResetDailyIndividualCount() { // 함수 이름 명확화
        userDefaults.set(0, forKey: dailyIndividualAdviceCountKey)
        userDefaults.set(todaysDateString(), forKey: lastIndividualAdviceDateKey)
        print("⚠️ 관리자에 의해 (개별) AI 조언 횟수가 강제 초기화되었습니다.")
    }
    
    // MARK: - 전체 할 일 목록 조언 일일 한도 관리 (신규)
    
    /// (전체 목록 조언) 날짜가 변경되었으면 일일 조언 횟수를 초기화합니다.
    func resetOverallCountIfNeeded() {
        let todayString = todaysDateString()
        guard let lastDateString = userDefaults.string(forKey: lastOverallAdviceDateKey) else {
            userDefaults.set(todayString, forKey: lastOverallAdviceDateKey)
            userDefaults.set(0, forKey: dailyOverallAdviceCountKey)
            return
        }

        if lastDateString != todayString {
            userDefaults.set(0, forKey: dailyOverallAdviceCountKey)
            userDefaults.set(todayString, forKey: lastOverallAdviceDateKey)
            print("✨ (전체 목록) AI 조언 횟수가 초기화되었습니다. (날짜 변경)")
        }
    }

    /// (전체 목록 조언) 오늘 남은 AI 조언 횟수를 반환합니다.
    func getRemainingDailyOverallAdviceCount() -> Int {
        resetOverallCountIfNeeded()
        let usedCount = userDefaults.integer(forKey: dailyOverallAdviceCountKey)
        return max(0, dailyOverallAdviceLimit - usedCount)
    }

    /// (전체 목록 조언) AI 조언을 성공적으로 사용했음을 기록합니다.
    @discardableResult
    func recordOverallAdviceUsed() -> Bool {
        resetOverallCountIfNeeded()
        let currentCount = userDefaults.integer(forKey: dailyOverallAdviceCountKey)
        
        if currentCount < dailyOverallAdviceLimit {
            userDefaults.set(currentCount + 1, forKey: dailyOverallAdviceCountKey)
            print("💡 (전체 목록) AI 조언 사용 기록됨. 오늘 사용한 횟수: \(currentCount + 1)/\(dailyOverallAdviceLimit)")
            return true
        } else {
            print("⚠️ (전체 목록) AI 조언 횟수 초과. 더 이상 사용할 수 없습니다.")
            return false
        }
    }
    
    /// (전체 목록 조언 테스트용) 일일 조언 횟수를 강제로 초기화합니다.
    func forceResetDailyOverallCount() {
        userDefaults.set(0, forKey: dailyOverallAdviceCountKey)
        userDefaults.set(todaysDateString(), forKey: lastOverallAdviceDateKey)
        print("⚠️ 관리자에 의해 (전체 목록) AI 조언 횟수가 강제 초기화되었습니다.")
    }
} 