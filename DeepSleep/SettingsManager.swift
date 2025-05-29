import Foundation
import UserNotifications

class SettingsManager {
    static let shared = SettingsManager()
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Keys
    private struct Keys {
        static let userSettings = "userSettings"
        static let usageStats = "usageStats"
        static let emotionDiary = "emotionDiary"
        static let soundPresets = "soundPresets"
        static let lastOpenDate = "lastOpenDate"
        static let onboardingCompleted = "onboardingCompleted"
    }
    
    private init() {
        setupDefaultSettings()
    }
    
    // MARK: - User Settings
    var settings: UserSettings {
        get {
            guard let data = userDefaults.data(forKey: Keys.userSettings),
                  let settings = try? JSONDecoder().decode(UserSettings.self, from: data) else {
                return UserSettings()
            }
            return settings
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                userDefaults.set(encoded, forKey: Keys.userSettings)
            }
        }
    }
    
    // MARK: - Usage Statistics
    func getTodayStats() -> UsageStats {
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        let allStats = getAllStats()
        return allStats[today] ?? UsageStats(date: today)
    }
    
    func updateTodayStats(_ update: (inout UsageStats) -> Void) {
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        var allStats = getAllStats()
        var todayStats = allStats[today] ?? UsageStats(date: today)
        
        update(&todayStats)
        
        allStats[today] = todayStats
        saveAllStats(allStats)
    }
    
    private func getAllStats() -> [String: UsageStats] {
        guard let data = userDefaults.data(forKey: Keys.usageStats),
              let stats = try? JSONDecoder().decode([String: UsageStats].self, from: data) else {
            return [:]
        }
        return stats
    }
    
    private func saveAllStats(_ stats: [String: UsageStats]) {
        // 최근 30일 데이터만 유지
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!
        let cutoffString = DateFormatter.localizedString(from: thirtyDaysAgo, dateStyle: .short, timeStyle: .none)
        
        let filteredStats = stats.filter { $0.key >= cutoffString }
        
        if let encoded = try? JSONEncoder().encode(filteredStats) {
            userDefaults.set(encoded, forKey: Keys.usageStats)
        }
    }
    
    // MARK: - Emotion Diary
    func saveEmotionDiary(_ entry: EmotionDiary) {
        var entries = loadEmotionDiary()
        entries.append(entry)
        
        // 최대 200개 항목만 유지
        if entries.count > 200 {
            entries = Array(entries.suffix(200))
        }
        
        if let encoded = try? JSONEncoder().encode(entries) {
            userDefaults.set(encoded, forKey: Keys.emotionDiary)
        }
    }
    
    func loadEmotionDiary() -> [EmotionDiary] {
        guard let data = userDefaults.data(forKey: Keys.emotionDiary),
              let entries = try? JSONDecoder().decode([EmotionDiary].self, from: data) else {
            return []
        }
        return entries.sorted { $0.date > $1.date }
    }
    
    func getRecentEmotionTrend(days: Int = 7) -> [String: Int] {
        let entries = loadEmotionDiary()
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date())!
        
        let recentEntries = entries.filter { $0.date >= startDate }
        var emotionCount: [String: Int] = [:]
        
        for entry in recentEntries {
            emotionCount[entry.selectedEmotion] = (emotionCount[entry.selectedEmotion] ?? 0) + 1
        }
        
        return emotionCount
    }
    
    // MARK: - Sound Presets
    func saveSoundPreset(_ preset: SoundPreset) {
        var presets = loadSoundPresets()
        
        // 같은 이름이 있으면 덮어쓰기
        presets.removeAll { $0.name == preset.name }
        presets.append(preset)
        
        if let encoded = try? JSONEncoder().encode(presets) {
            userDefaults.set(encoded, forKey: Keys.soundPresets)
        }
    }
    
    func loadSoundPresets() -> [SoundPreset] {
        guard let data = userDefaults.data(forKey: Keys.soundPresets),
              let presets = try? JSONDecoder().decode([SoundPreset].self, from: data) else {
            return []
        }
        return presets.sorted { $0.createdDate > $1.createdDate }
    }
    
    func deleteSoundPreset(id: UUID) {
        var presets = loadSoundPresets()
        presets.removeAll { $0.id == id }
        
        if let encoded = try? JSONEncoder().encode(presets) {
            userDefaults.set(encoded, forKey: Keys.soundPresets)
        }
    }
    
    // MARK: - Usage Limits
    func canUseChatToday() -> Bool {
        let todayStats = getTodayStats()
        return todayStats.chatCount < settings.dailyChatLimit
    }
    
    func canUsePresetRecommendationToday() -> Bool {
        let todayStats = getTodayStats()
        return todayStats.presetRecommendationCount < settings.dailyPresetLimit
    }
    
    func incrementChatUsage() {
        updateTodayStats { stats in
            stats.chatCount += 1
        }
    }
    
    func incrementPresetRecommendationUsage() {
        updateTodayStats { stats in
            stats.presetRecommendationCount += 1
        }
    }
    
    func incrementTimerUsage() {
        updateTodayStats { stats in
            stats.timerUsageCount += 1
        }
    }
    
    func addSessionTime(_ duration: TimeInterval) {
        updateTodayStats { stats in
            stats.totalSessionTime += duration
        }
    }
    
    // MARK: - Onboarding & First Launch
    var isOnboardingCompleted: Bool {
        get { userDefaults.bool(forKey: Keys.onboardingCompleted) }
        set { userDefaults.set(newValue, forKey: Keys.onboardingCompleted) }
    }
    
    var isFirstLaunchToday: Bool {
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        let lastOpen = userDefaults.string(forKey: Keys.lastOpenDate)
        
        if lastOpen != today {
            userDefaults.set(today, forKey: Keys.lastOpenDate)
            return true
        }
        return false
    }
    
    // MARK: - Analytics & Insights
    func getMostUsedEmotion(period: Int = 30) -> String? {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -period, to: Date())!
        let entries = loadEmotionDiary().filter { $0.date >= startDate }
        
        var emotionCount: [String: Int] = [:]
        for entry in entries {
            emotionCount[entry.selectedEmotion] = (emotionCount[entry.selectedEmotion] ?? 0) + 1
        }
        
        return emotionCount.max { $0.value < $1.value }?.key
    }
    
    func getAverageSessionTime(days: Int = 7) -> TimeInterval {
        let allStats = getAllStats()
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date())!
        
        var totalTime: TimeInterval = 0
        var validDays = 0
        
        for i in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                let dateString = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
                if let stats = allStats[dateString], stats.totalSessionTime > 0 {
                    totalTime += stats.totalSessionTime
                    validDays += 1
                }
            }
        }
        
        return validDays > 0 ? totalTime / Double(validDays) : 0
    }
    
    // MARK: - Private Methods
    private func setupDefaultSettings() {
        if userDefaults.object(forKey: Keys.userSettings) == nil {
            let defaultSettings = UserSettings()
            settings = defaultSettings
        }
    }
    
    // MARK: - Reset & Export
    func resetAllData() {
        let keys = [Keys.userSettings, Keys.usageStats, Keys.emotionDiary, Keys.soundPresets]
        for key in keys {
            userDefaults.removeObject(forKey: key)
        }
        setupDefaultSettings()
    }
    
    func exportUserData() -> [String: Any] {
        return [
            "settings": settings,
            "emotionDiary": loadEmotionDiary(),
            "soundPresets": loadSoundPresets(),
            "usageStats": getAllStats(),
            "exportDate": Date()
        ]
    }
    func canWriteDiaryToday() -> Bool {
            let today = getTodayDateString()
            let lastDiaryDate = UserDefaults.standard.string(forKey: "lastDiaryDate")
            return lastDiaryDate != today
        }
        
        /// 일기 작성 완료 기록
        func recordDiaryWritten() {
            let today = getTodayDateString()
            UserDefaults.standard.set(today, forKey: "lastDiaryDate")
        }
        
        /// 오늘 날짜 문자열 반환
        private func getTodayDateString() -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: Date())
        }
        
        /// 오늘 일기 개수 확인 (기존 일기들 중에서)
        func getTodayDiaryCount() -> Int {
            let diaries = loadEmotionDiary()
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
            
            return diaries.filter { diary in
                diary.date >= today && diary.date < tomorrow
            }.count
        }
}

