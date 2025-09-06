import Foundation
import UserNotifications

// MARK: - UserSettings Model
public struct UserSettings: Codable {
    var dailyEmotionLimit: Int = 5
    var enableAIRecommendations: Bool = true
    var preferredLLMService: String = "claude"
    var maxTokensPerRequest: Int = 1000
    var temperatureSetting: Float = 0.7
    var dailyPresetLimit: Int = 10
    var enableNotifications: Bool = true
    var selectedTheme: String = "auto"
    var soundQuality: String = "high"
    var autoSave: Bool = true

    public init() {}
}

// MARK: - Emotion Diary Notifications
public extension Notification.Name {
    static let emotionDiaryUpdated = Notification.Name("EmotionDiaryUpdatedNotification")
    static let diaryAnalysisUpdated = Notification.Name("DiaryAnalysisUpdatedNotification")
}

// MARK: - UsageStats 타입 정의 (임시)
public struct UsageStats: Codable {
    let date: String
    var appOpenCount: Int = 0
    var totalUsageTime: TimeInterval = 0
    var presetUsageCount: Int = 0
    var emotionAnalysisCount: Int = 0
    var aiInteractionCount: Int = 0
    var chatCount: Int = 0
    var presetRecommendationCount: Int = 0
    var timerUsageCount: Int = 0
    var soundPlaybackTime: TimeInterval = 0
    var favoritePresets: [String] = []
    var peakUsageHour: Int?
    var deviceInfo: [String: String]?
    var monthlyStatisticsCount: Int = 0  // 월간 통계 사용 횟수

    init(date: String) {
        self.date = date
    }

    mutating func incrementAppOpenCount() {
        appOpenCount += 1
    }

    mutating func addUsageTime(_ time: TimeInterval) {
        totalUsageTime += time
    }

    mutating func incrementPresetUsage() {
        presetUsageCount += 1
    }

    mutating func incrementEmotionAnalysis() {
        emotionAnalysisCount += 1
    }

    mutating func incrementAIInteraction() {
        aiInteractionCount += 1
    }

    mutating func addSoundPlaybackTime(_ time: TimeInterval) {
        soundPlaybackTime += time
    }

    mutating func incrementChatUsage() {
        chatCount += 1
    }
}

// MARK: - Notifications
public extension Notification.Name {
    static let aiModelChanged = Notification.Name("aiModelChanged")
    static let notificationSettingsChanged = Notification.Name("notificationSettingsChanged")
}

public class SettingsManager {
    public static let shared = SettingsManager()
    private let userDefaults = UserDefaults.standard

    // MARK: - Keys
    private struct Keys {
        static let userSettings = "userSettings"
        static let usageStats = "usageStats"
        static let emotionDiary = "emotionDiary"
        static let soundPresets = "soundPresets"
        static let lastOpenDate = "lastOpenDate"
        static let onboardingCompleted = "onboardingCompleted"
        static let selectedSoundVersions = "selectedSoundVersions"
        static let selectedLLM = "selectedLLM"
        // Notification preferences
        static let notificationsMasterEnabled = "notificationsMasterEnabled"
        static let notificationsTimerEnabled = "notificationsTimerEnabled"
        static let notificationsTodoEnabled = "notificationsTodoEnabled"
        static let notificationsTodoOneHourBeforeEnabled = "notificationsTodoOneHourBeforeEnabled"
        // Time and retention controls
        static let serverTimeOffsetSeconds = "serverTimeOffsetSeconds"
        static let protectedWeekdays = "protectedWeekdays"
        static let protectedDaysWindow = "protectedDaysWindow"
        static let favoriteDates = "favoriteDates" // yyyy-MM-dd 문자열 세트
        // Chat override
        static let activeChatSessionOverrideId = "activeChatSessionOverrideId"
    }

    private init() {
        setupDefaultSettings()
    }

    // MARK: - AI Model Selection

    /// 사용 가능한 모든 AI 모델의 목록입니다.
    /// 향후 OS 버전에 따라 동적으로 온디바이스 모델을 포함하거나 제외할 수 있습니다.
    var availableAIModels: [AIModelType] {
        // 모든 모델 사용 가능
        return AIModelType.allCases
    }

    /// 사용자가 선택한 AI 모델을 가져오거나 설정합니다.
    /// 기본값은 Claude 입니다.
    var selectedLLM: AIModelType {
        get {
            // 이전 버전 호환성: LLMServiceType 값을 AIModelType으로 변환
            if let rawValue = userDefaults.string(forKey: Keys.selectedLLM) {
                // 0) 사전 정규화/마이그레이션: 레거시 문자열을 표준 모델로 매핑(gemini-pro 등)
                if let normalized = normalizeStoredModelString(rawValue) {
                    // 필요 시 자체 치유: 정규화된 값으로 저장값 업데이트
                    if normalized.rawValue != rawValue {
                        userDefaults.set(normalized.rawValue, forKey: Keys.selectedLLM)
                    }
                    return normalized
                }
                // 1) 직접 매핑 실패 시, 기본값으로 자체 치유
                userDefaults.set(AIModelType.gemini.rawValue, forKey: Keys.selectedLLM)
                return .gemini
            }
            return .gemini // 기본 모델
        }
        set {
            // 새로운 모델의 rawValue를 UserDefaults에 저장
            userDefaults.set(newValue.rawValue, forKey: Keys.selectedLLM)
            // 모델별 지침은 런타임 합성이므로 시스템 프롬프트 캐시는 모델 변경으로 무효화하지 않습니다.
        }
    }

    // MARK: - Stored model normalization (migration/self-heal)
    /// 레거시/비표준 저장 문자열을 표준 AIModelType으로 정규화합니다.
    /// 예: "gemini-pro" → .gemini
    private func normalizeStoredModelString(_ raw: String) -> AIModelType? {
        // 우선 정확/공식 매핑 시도
        if let model = AIModelType(rawValue: raw) { return model }
        // LLMServiceType 호환성 체크 (AIServiceTypes.swift에서 가져옴)
        if let model = AIModelType(fromLegacyString: raw) { return model }
        // 레거시 값 처리
        let lower = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lower == "gemini-pro" || lower.hasPrefix("gemini-pro") || lower.hasPrefix("gemini") {
            return .gemini
        }
        if lower == "gpt-4o-mini" || lower.hasPrefix("gpt-4o") || lower == "gpt-4-mini" {
            return .gpt4
        }
        if lower.contains("claude") { return .claude35 }
        if lower.contains("hyperclova") || lower.contains("naver") { return .naver }
        return nil
    }

    /// 모델 변경을 단일 진입점에서 원자적으로 처리 (저장 → 컨텍스트 무효화 → 알림)
    func updateSelectedModelAtomically(_ model: AIModelType) {
        let previous = selectedLLM
        guard previous != model else { return }
        selectedLLM = model
        // 컨텍스트 시스템 프롬프트 캐시 무효화 및 서버 헤더 전파 보장
        AIContextManager.shared.clearCache(reason: .modelSelectionChanged, caller: "SettingsManager.updateSelectedModelAtomically")
        NotificationCenter.default.post(name: .aiModelChanged, object: nil, userInfo: ["from": previous.rawValue, "to": model.rawValue])
    }

    /// (iOS 18+) 온디바이스 AI 모델을 우선적으로 사용할지 여부를 결정합니다.
    /// 이 설정은 `selectedLLM` 보다 우선 순위를 가질 수 있습니다.
    var useOnDeviceModelIfNeeded: Bool {
        get {
            return userDefaults.bool(forKey: "useOnDeviceModel")
        }
        set {
            userDefaults.set(newValue, forKey: "useOnDeviceModel")
        }
    }

    // MARK: - Notification Preferences
    var notificationsMasterEnabled: Bool {
        get {
            if userDefaults.object(forKey: Keys.notificationsMasterEnabled) == nil {
                return true
            }
            return userDefaults.bool(forKey: Keys.notificationsMasterEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.notificationsMasterEnabled)
            NotificationCenter.default.post(name: .notificationSettingsChanged, object: nil, userInfo: ["key": "master", "value": newValue])
        }
    }

    var notificationsTimerEnabled: Bool {
        get {
            if userDefaults.object(forKey: Keys.notificationsTimerEnabled) == nil {
                return true
            }
            return userDefaults.bool(forKey: Keys.notificationsTimerEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.notificationsTimerEnabled)
            NotificationCenter.default.post(name: .notificationSettingsChanged, object: nil, userInfo: ["key": "timer", "value": newValue])
        }
    }

    var notificationsTodoEnabled: Bool {
        get {
            if userDefaults.object(forKey: Keys.notificationsTodoEnabled) == nil {
                return true
            }
            return userDefaults.bool(forKey: Keys.notificationsTodoEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.notificationsTodoEnabled)
            NotificationCenter.default.post(name: .notificationSettingsChanged, object: nil, userInfo: ["key": "todo", "value": newValue])
        }
    }

    /// 할 일 1시간 전 알림 사용 여부
    var notificationsTodoOneHourBeforeEnabled: Bool {
        get {
            if userDefaults.object(forKey: Keys.notificationsTodoOneHourBeforeEnabled) == nil {
                return true
            }
            return userDefaults.bool(forKey: Keys.notificationsTodoOneHourBeforeEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.notificationsTodoOneHourBeforeEnabled)
            NotificationCenter.default.post(name: .notificationSettingsChanged, object: nil, userInfo: ["key": "todo1h", "value": newValue])
        }
    }

    // MARK: - Time Source (Server time merge)
    /// 서버 시간이 제공될 경우 오프셋을 계산하여 현재 시간을 보정합니다.
    func setServerTime(nowServer: Date, nowDevice: Date = Date()) {
        let offset = nowServer.timeIntervalSince(nowDevice)
        userDefaults.set(offset, forKey: Keys.serverTimeOffsetSeconds)
    }

    /// 보정된 현재 시간(서버 오프셋 반영)
    func currentDate() -> Date {
        let offset = userDefaults.double(forKey: Keys.serverTimeOffsetSeconds)
        return Date().addingTimeInterval(offset)
    }

    // MARK: - Protected Weekdays (Retention exceptions)
    /// 보호 요일(요일 번호: 1=일요일 ... 7=토요일). 해당 요일의 세션은 압축/삭제에서 제외됩니다.
    var protectedWeekdays: Set<Int> {
        get {
            let arr = userDefaults.array(forKey: Keys.protectedWeekdays) as? [Int] ?? []
            return Set(arr)
        }
        set {
            let arr = Array(newValue).sorted()
            userDefaults.set(arr, forKey: Keys.protectedWeekdays)
        }
    }

    // MARK: - Protection Window (recent days)
    /// 최근 N일 보호 기간. 이 기간 내 생성된 세션은 압축/삭제 대상에서 제외됩니다.
    var protectedDaysWindow: Int {
        get {
            let value = userDefaults.integer(forKey: Keys.protectedDaysWindow)
            return value == 0 ? 7 : value // 기본값 7일
        }
        set {
            let clamped = max(0, min(newValue, 365))
            userDefaults.set(clamped, forKey: Keys.protectedDaysWindow)
        }
    }

    // MARK: - Favorite Dates (삭제 방지)
    /// 특정 "날짜(yyyy-MM-dd)"를 즐겨찾기로 지정하여 30일 이후에도 삭제되지 않도록 합니다.
    var favoriteDates: Set<String> {
        get {
            let arr = userDefaults.array(forKey: Keys.favoriteDates) as? [String] ?? []
            return Set(arr)
        }
        set {
            userDefaults.set(Array(newValue).sorted(), forKey: Keys.favoriteDates)
        }
    }

    // MARK: - Chat 세션 덮어쓰기(Override)
    /// 특정 세션 ID를 현재 채팅의 기준 세션으로 강제하는 오버라이드 ID입니다.
    /// 설정되면 ChatViewController는 해당 세션의 히스토리를 로드하고, 이후 메시지 저장도 동일 세션으로 진행합니다.
    var activeChatSessionOverrideId: String? {
        get { userDefaults.string(forKey: Keys.activeChatSessionOverrideId) }
        set {
            if let value = newValue {
                userDefaults.set(value, forKey: Keys.activeChatSessionOverrideId)
            } else {
                userDefaults.removeObject(forKey: Keys.activeChatSessionOverrideId)
            }
        }
    }

    /// 날짜를 yyyy-MM-dd 키로 변환
    func dateKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    /// 해당 날짜가 즐겨찾기(삭제 방지)인지 여부
    func isFavorite(date: Date) -> Bool {
        favoriteDates.contains(dateKey(for: date))
    }

    /// 현재 플랜의 상한(cap)에 맞춰 즐겨찾기 날짜 수를 강제합니다.
    /// - Returns: 제거된 즐겨찾기 날짜 수
    @discardableResult
    func enforceFavoriteCap(cap: Int) -> Int {
        var current = favoriteDates
        guard current.count > cap else { return 0 }

        // yyyy-MM-dd → Date 파싱
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")

        // 날짜 기준 오래된 순으로 정렬 후 최신 cap만 유지
        let sorted = current.compactMap { key -> (String, Date)? in
            if let d = f.date(from: key) { return (key, d) }
            return nil
        }.sorted { $0.1 < $1.1 }

        let toKeep = Set(sorted.suffix(cap).map { $0.0 })
        let removed = current.subtracting(toKeep)

        favoriteDates = toKeep
        return removed.count
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

        if let existingIndex = entries.firstIndex(where: { $0.id == entry.id }) {
            // 업서트: 동일 ID가 있으면 교체
            entries[existingIndex] = entry
        } else {
            entries.append(entry)
        }

        // 최대 200개 항목만 유지
        if entries.count > 200 {
            entries = Array(entries.suffix(200))
        }

        if let encoded = try? JSONEncoder().encode(entries) {
            userDefaults.set(encoded, forKey: Keys.emotionDiary)
        }

        // 브로드캐스트: 감정 일기 업데이트 (즉시 동기화)
        NotificationCenter.default.post(name: .emotionDiaryUpdated, object: nil, userInfo: ["entry": entry])
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

    // MARK: - Emotion Diary - 삭제/초기화
    func resetAllDiaryEntries() {
        userDefaults.removeObject(forKey: Keys.emotionDiary)
        print("🗑️ 모든 감정 일기 데이터가 UserDefaults에서 삭제되었습니다.")
        // 분석 로그도 함께 초기화
        clearAllDiaryAnalyses()
        NotificationCenter.default.post(name: .emotionDiaryUpdated, object: nil, userInfo: ["cleared": true])
    }

    /// 단일 일기 삭제 (ID 기준)
    func deleteEmotionDiary(id: UUID) {
        var entries = loadEmotionDiary()
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        let removed = entries.remove(at: idx)
        if let encoded = try? JSONEncoder().encode(entries) {
            userDefaults.set(encoded, forKey: Keys.emotionDiary)
        }
        // 해당 날짜의 분석 로그도 함께 제거 (동기화)
        clearDiaryAnalyses(for: removed.date)
        NotificationCenter.default.post(name: .emotionDiaryUpdated, object: nil, userInfo: ["deletedId": id.uuidString, "date": removed.date])
    }

    // MARK: - Sound Presets
    func saveSoundPreset(_ preset: SoundPreset) {
        var presets = loadSoundPresets()

        // ✅ 새로 저장되는 프리셋의 lastUsed를 현재 시간으로 설정
        var updatedPreset = preset
        if preset.lastUsed == nil {
            updatedPreset = SoundPreset(
                id: preset.id,
                name: preset.name,
                volumes: preset.volumes,
                emotion: preset.emotion,
                isAIGenerated: preset.isAIGenerated,
                description: preset.description,
                scientificBasis: preset.scientificBasis,
                createdDate: preset.createdDate,
                selectedVersions: preset.selectedVersions,
                presetVersion: preset.presetVersion,
                lastUsed: Date() // ✅ 현재 시간으로 설정
            )
        }

        // ID가 같으면 덮어쓰기 (이름 대신 ID 사용)
        if let index = presets.firstIndex(where: { $0.id == updatedPreset.id }) {
            presets[index] = updatedPreset
        } else {
            presets.append(updatedPreset)
        }

        if let encoded = try? JSONEncoder().encode(presets) {
            userDefaults.set(encoded, forKey: Keys.soundPresets)
        }
    }

    func loadSoundPresets() -> [SoundPreset] {
        guard let data = userDefaults.data(forKey: Keys.soundPresets),
              let presets = try? JSONDecoder().decode([SoundPreset].self, from: data) else {
            return []
        }

        // ✅ 수정: lastUsed 기준으로 정렬 (nil인 경우 createdDate 사용)
        return presets.sorted { preset1, preset2 in
            let date1 = preset1.lastUsed ?? preset1.createdDate
            let date2 = preset2.lastUsed ?? preset2.createdDate
            return date1 > date2
        }
    }

    // 편의 메서드: 프리셋 ID로 조회
    func getSoundPreset(id: UUID) -> SoundPreset? {
        return loadSoundPresets().first { $0.id == id }
    }

    // 편의 메서드: 문자열 ID(또는 이름)로 조회
    func getSoundPresetByStringId(_ idString: String) -> SoundPreset? {
        if let uuid = UUID(uuidString: idString) {
            return getSoundPreset(id: uuid)
        }
        let presets = loadSoundPresets()
        if let match = presets.first(where: { $0.id.uuidString == idString }) {
            return match
        }
        // Fallback: 일부 호출부에서 이름을 전달할 수 있음
        return presets.first(where: { $0.name == idString })
    }

    // ✅ 프리셋의 날짜만 업데이트하여 '최근 사용'으로 만드는 함수
    func updatePresetTimestamp(id: UUID) {
        var presets = loadSoundPresets()

        guard let index = presets.firstIndex(where: { $0.id == id }) else {
            print("⚠️ [updatePresetTimestamp] ID에 해당하는 프리셋을 찾지 못함: \(id)")
            return
        }

        // ✅ lastUsed를 현재 시간으로 변경 (createdDate가 아닌)
        let updatedPreset = SoundPreset(
            id: presets[index].id,
            name: presets[index].name,
            volumes: presets[index].volumes,
            emotion: presets[index].emotion,
            isAIGenerated: presets[index].isAIGenerated,
            description: presets[index].description,
            scientificBasis: presets[index].scientificBasis,
            createdDate: presets[index].createdDate, // 원본 생성 날짜 유지
            selectedVersions: presets[index].selectedVersions,
            presetVersion: presets[index].presetVersion,
            lastUsed: Date() // ✅ 현재 시간으로 업데이트
        )

        presets[index] = updatedPreset

        // 전체 배열을 다시 저장
        if let encoded = try? JSONEncoder().encode(presets) {
            userDefaults.set(encoded, forKey: Keys.soundPresets)
            print("🔄 [updatePresetTimestamp] 프리셋 lastUsed 시간 갱신 완료: \(presets[index].name)")
        }
    }

    func deleteSoundPreset(id: UUID) {
        var presets = loadSoundPresets()
        presets.removeAll { $0.id == id }

        if let encoded = try? JSONEncoder().encode(presets) {
            userDefaults.set(encoded, forKey: Keys.soundPresets)
        }
    }

    /// 프리셋 배열 전체를 교체합니다. (마이그레이션 전용)
    func replaceAllPresets(with newPresets: [SoundPreset]) {
        if let encoded = try? JSONEncoder().encode(newPresets) {
            userDefaults.set(encoded, forKey: Keys.soundPresets)
        }
    }

    // MARK: - Usage Limits
    func canUseChatToday() -> Bool {
        let todayStats = getTodayStats()
        return todayStats.chatCount < settings.dailyEmotionLimit
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
            stats.totalUsageTime += duration
        }
    }

    // MARK: - Storage Management
    /// 📊 앱 전체 저장소 사용량 정보
    func getStorageInfo() -> String {
        let diaryCount = loadEmotionDiary().count
        let presetCount = loadSoundPresets().count
        let statsCount = getAllStats().count

        let feedbackStats: String
        if #available(iOS 17.0, *) {
            feedbackStats = "피드백 통계 (iOS 17+)"
        } else {
            feedbackStats = "호환되지 않음 (iOS 17+ 필요)"
        }

        return """
        📊 저장된 데이터 현황

        🎵 프리셋: \(presetCount)개
        📔 감정 일기: \(diaryCount)개
        📈 사용 통계: \(statsCount)일
        💬 피드백: \(feedbackStats)

        🕐 마지막 정리: \(getLastCleanupDate())
        """
    }

    private func getLastCleanupDate() -> String {
        if let date = userDefaults.object(forKey: "lastCleanupDate") as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return "없음"
    }

    /// 🧹 수동 데이터 정리 (사용자 요청 시)
    func performStorageCleanup() async {
        let beforeInfo = getStorageInfo()
        print("🧹 저장소 정리 시작:\n\(beforeInfo)")

        // FeedbackManager는 SessionManager로 통합됨
        // SessionManager에서 필요한 정리 작업 수행
        print("✅ SessionManager 기반 시스템으로 전환 완료")

        userDefaults.set(Date(), forKey: "lastCleanupDate")

        let afterInfo = getStorageInfo()
        print("✅ 저장소 정리 완료:\n\(afterInfo)")
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
        let _ = calendar.date(byAdding: .day, value: -days, to: Date())!

        var totalTime: TimeInterval = 0
        var validDays = 0

        for i in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                let dateString = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
                if let stats = allStats[dateString], stats.totalUsageTime > 0 {
                    totalTime += stats.totalUsageTime
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
        // 기본 내보내기는 개인정보 최소화를 적용한 안전 버전으로 처리합니다.
        return exportUserDataSanitized()
    }

    /// PII 최소화를 적용한 안전한 내보내기
    func exportUserDataSanitized() -> [String: Any] {
        let diaries = loadEmotionDiary().map { diary in
            return [
                "id": diary.id.uuidString,
                "date": diary.date,
                "selectedEmotion": diary.selectedEmotion,
                // 사용자 입력/응답은 마스킹 처리
                "userMessage": sanitizePII(in: diary.userMessage),
                "aiResponse": sanitizePII(in: diary.aiResponse)
            ] as [String: Any]
        }
        let presets = loadSoundPresets().map { preset in
            return [
                "id": preset.id.uuidString,
                "name": sanitizePII(in: preset.name),
                "volumes": preset.volumes,
                "emotion": preset.emotion as Any,
                "createdDate": preset.createdDate
            ] as [String: Any]
        }
        return [
            "settings": settings,
            "emotionDiary": diaries,
            "soundPresets": presets,
            "usageStats": getAllStats(),
            "exportDate": Date()
        ]
    }

    // 간단한 PII 마스킹 (이메일/전화/카드번호)
    private func sanitizePII(in text: String) -> String {
        var result = text
        // 이메일
        result = result.replacingOccurrences(of: "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", with: "[REDACTED_EMAIL]", options: .regularExpression)
        // 한국 전화번호
        result = result.replacingOccurrences(of: "01[0-9]-?\\d{4}-?\\d{4}", with: "[REDACTED_PHONE]", options: .regularExpression)
        // 카드번호
        result = result.replacingOccurrences(of: "\\b\\d{4}[-\\s]?\\d{4}[-\\s]?\\d{4}[-\\s]?\\d{4}\\b", with: "[REDACTED_CARD]", options: .regularExpression)
        return result
    }

    /// 공개 API: 내보내기/공유 등의 텍스트에 대해 PII 마스킹 적용
    public func maskPIIForExport(_ text: String) -> String {
        return sanitizePII(in: text)
    }

    func canWriteDiaryToday() -> Bool {
        let today = getTodayDateString()
        let lastDiaryDate = UserDefaults.standard.string(forKey: "lastDiaryDate")
        return lastDiaryDate != today
    }

    func recordDiaryWritten() {
        let today = getTodayDateString()
        UserDefaults.standard.set(today, forKey: "lastDiaryDate")
    }

    private func getTodayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    func getTodayDiaryCount() -> Int {
        let diaries = loadEmotionDiary()
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        return diaries.filter { diary in
            diary.date >= today && diary.date < tomorrow
        }.count
    }

    // MARK: - Diary Analysis Store (오늘의 일기 대화 기록)

    struct DiaryAnalysisRecord: Codable {
        let id: UUID
        let date: Date
        let text: String
    }

    private func diaryAnalysisKey(for date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return "DiaryAnalysis." + f.string(from: date)
    }

    /// 오늘(또는 특정 날짜)의 분석 결과를 저장 (최신순 정렬은 조회 시 처리)
    func appendDiaryAnalysis(_ text: String, for date: Date = Date()) {
        let key = diaryAnalysisKey(for: date)
        var list = loadDiaryAnalysesAll(for: date)
        list.append(DiaryAnalysisRecord(id: UUID(), date: Date(), text: text))
        if let encoded = try? JSONEncoder().encode(list) { userDefaults.set(encoded, forKey: key) }
        NotificationCenter.default.post(name: .diaryAnalysisUpdated, object: nil, userInfo: ["date": date])
    }

    /// 특정 날짜의 모든 분석 결과 로드 (최신순)
    private func loadDiaryAnalysesAll(for date: Date) -> [DiaryAnalysisRecord] {
        let key = diaryAnalysisKey(for: date)
        guard let data = userDefaults.data(forKey: key), let list = try? JSONDecoder().decode([DiaryAnalysisRecord].self, from: data) else { return [] }
        return list.sorted { $0.date > $1.date }
    }

    /// 페이지네이션 로드
    func loadDiaryAnalyses(for date: Date, offset: Int, limit: Int) -> ([DiaryAnalysisRecord], Bool) {
        let all = loadDiaryAnalysesAll(for: date)
        let start = min(offset, all.count)
        let end = min(offset + limit, all.count)
        let page = Array(all[start..<end])
        let hasMore = end < all.count
        return (page, hasMore)
    }

    /// 특정 날짜의 분석 로그 삭제
    func clearDiaryAnalyses(for date: Date) {
        let key = diaryAnalysisKey(for: date)
        userDefaults.removeObject(forKey: key)
        NotificationCenter.default.post(name: .diaryAnalysisUpdated, object: nil, userInfo: ["date": date, "cleared": true])
    }

    /// 전체 분석 로그 삭제
    func clearAllDiaryAnalyses() {
        // 최근 60일 정도만 키 스캔 (YAGNI: 전체 키 열람 대신 최근 일수만 처리)
        let cal = Calendar.current
        for i in 0..<60 {
            if let d = cal.date(byAdding: .day, value: -i, to: Date()) {
                userDefaults.removeObject(forKey: diaryAnalysisKey(for: d))
            }
        }
        NotificationCenter.default.post(name: .diaryAnalysisUpdated, object: nil, userInfo: ["clearedAll": true])
    }

    // MARK: - Category Sound Versions

    /// 특정 카테고리의 선택된 사운드 버전을 업데이트합니다.
    /// - Parameters:
    ///   - categoryIndex: 업데이트할 사운드 카테고리 인덱스
    ///   - versionIndex: 선택된 버전 인덱스 (0부터 시작)
    func updateSelectedVersion(for categoryIndex: Int, to versionIndex: Int) {
        var versions = userDefaults.dictionary(forKey: Keys.selectedSoundVersions) as? [String: Int] ?? [:]
        versions["\(categoryIndex)"] = versionIndex
        userDefaults.set(versions, forKey: Keys.selectedSoundVersions)
    }

    /// 특정 카테고리의 선택된 사운드 버전을 가져옵니다.
    /// - Parameter categoryIndex: 조회할 사운드 카테고리 인덱스
    /// - Returns: 선택된 버전 인덱스. 저장된 값이 없으면 기본값 0을 반환합니다.
    func getSelectedVersion(for categoryIndex: Int) -> Int {
        let versions = userDefaults.dictionary(forKey: Keys.selectedSoundVersions) as? [String: Int] ?? [:]
        return versions["\(categoryIndex)"] ?? 0 // 기본값 0 반환
    }

    // MARK: - Monthly Statistics Usage Limits (DEPRECATED - use UsageLimitManager instead)
    func canUsePatternAnalysisToday() -> Bool {
        let todayStats = getTodayStats()
        return todayStats.monthlyStatisticsCount < 1  // ✅ 하루 1번으로 변경
    }

    func incrementPatternAnalysisUsage() {
        updateTodayStats { stats in
            stats.monthlyStatisticsCount += 1
        }
    }

    // MARK: - Sound Presets V2 (버전 관리 포함)

    // SoundPreset에 있는 init을 사용하여 객체 생성하도록 변경
    private func mutablePreset(from preset: SoundPreset, createdDate: Date? = nil, selectedVersions: [Int]? = nil) -> SoundPreset {
        return SoundPreset(
            id: preset.id,
            name: preset.name,
            volumes: preset.volumes,
            emotion: preset.emotion,
            isAIGenerated: preset.isAIGenerated,
            description: preset.description,
            scientificBasis: preset.scientificBasis,
            createdDate: createdDate ?? preset.createdDate,
            selectedVersions: selectedVersions ?? preset.selectedVersions,
            presetVersion: preset.presetVersion
        )
    }

    // MARK: - 🛡️ 프리셋 이름 중복 체크 및 충돌 방지

    /// 프리셋 이름 중복 체크
    func isPresetNameExists(_ name: String, excludingId: UUID? = nil) -> Bool {
        let presets = loadSoundPresets()
        return presets.contains { preset in
            preset.name.lowercased() == name.lowercased() && preset.id != excludingId
        }
    }

    /// 중복되지 않는 프리셋 이름 생성
    func generateUniquePresetName(baseName: String) -> String {
        var uniqueName = baseName
        var counter = 1

        while isPresetNameExists(uniqueName) {
            uniqueName = "\(baseName) (\(counter))"
            counter += 1
        }

        return uniqueName
    }

    /// 안전한 프리셋 저장 (중복 이름 체크 포함)
    func saveSoundPresetSafely(_ preset: SoundPreset, allowOverwrite: Bool = false) -> (success: Bool, finalName: String, wasRenamed: Bool) {
        let existingPresets = loadSoundPresets()

        // 동일 ID를 가진 기존 프리셋이 있는지 확인 (업데이트인지 체크)
        let isUpdate = existingPresets.contains { $0.id == preset.id }

        if isUpdate {
            // 업데이트의 경우 기존 로직 사용
            var presets = existingPresets
            if let index = presets.firstIndex(where: { $0.id == preset.id }) {
                presets[index] = preset
                if let encoded = try? JSONEncoder().encode(presets) {
                    userDefaults.set(encoded, forKey: Keys.soundPresets)
                    return (true, preset.name, false)
                }
            }
            return (false, preset.name, false)
        }

        // 새로운 프리셋 저장 시 중복 이름 체크
        if isPresetNameExists(preset.name) && !allowOverwrite {
            // 중복 이름이 있고 덮어쓰기를 허용하지 않는 경우 고유 이름 생성
            let uniqueName = generateUniquePresetName(baseName: preset.name)
            let renamedPreset = SoundPreset(
                id: preset.id,
                name: uniqueName,
                volumes: preset.volumes,
                emotion: preset.emotion,
                isAIGenerated: preset.isAIGenerated,
                description: preset.description,
                scientificBasis: preset.scientificBasis,
                createdDate: preset.createdDate,
                selectedVersions: preset.selectedVersions,
                presetVersion: preset.presetVersion,
                lastUsed: Date() // ✅ 수정: 현재 시간으로 설정
            )

            // 기존 saveSoundPreset 사용
            saveSoundPreset(renamedPreset)
            return (true, uniqueName, true)
        } else {
            // 중복이 없거나 덮어쓰기를 허용하는 경우
            if allowOverwrite && isPresetNameExists(preset.name) {
                // 동일 이름의 기존 프리셋 삭제
                var presets = existingPresets
                presets.removeAll { $0.name.lowercased() == preset.name.lowercased() }
                presets.append(preset)

                if let encoded = try? JSONEncoder().encode(presets) {
                    userDefaults.set(encoded, forKey: Keys.soundPresets)
                    print("🔄 [SettingsManager] 프리셋 덮어쓰기: \(preset.name)")
                }
            } else {
                // 기존 saveSoundPreset 사용
                saveSoundPreset(preset)
            }
            return (true, preset.name, false)
        }
    }
}
