import Foundation
import UIKit

// MARK: - 감정 관련 모델 (기존 유지)
struct Emotion {
    let emoji: String
    let name: String
    let description: String
    let category: EmotionCategory
    
    enum EmotionCategory: String, CaseIterable {
        case happy = "기쁨"
        case sad = "슬픔"
        case anxious = "불안"
        case tired = "피곤"
        case angry = "화남"
        case neutral = "평온"
    }
    
    static let predefinedEmotions: [Emotion] = [
        Emotion(emoji: "😊", name: "기쁨", description: "행복하고 즐거운", category: .happy),
        Emotion(emoji: "😄", name: "신남", description: "에너지 넘치는", category: .happy),
        Emotion(emoji: "🥰", name: "사랑", description: "따뜻하고 포근한", category: .happy),
        
        Emotion(emoji: "😢", name: "슬픔", description: "눈물이 나는", category: .sad),
        Emotion(emoji: "😞", name: "우울", description: "마음이 무거운", category: .sad),
        Emotion(emoji: "😔", name: "실망", description: "기대가 무너진", category: .sad),
        
        Emotion(emoji: "😰", name: "불안", description: "마음이 조급한", category: .anxious),
        Emotion(emoji: "😱", name: "공포", description: "두렵고 무서운", category: .anxious),
        Emotion(emoji: "😨", name: "걱정", description: "앞이 막막한", category: .anxious),
        
        Emotion(emoji: "😴", name: "졸림", description: "잠이 오는", category: .tired),
        Emotion(emoji: "😪", name: "피곤", description: "몸과 마음이 지친", category: .tired),
        
        Emotion(emoji: "😡", name: "화남", description: "분노가 치미는", category: .angry),
        Emotion(emoji: "😤", name: "짜증", description: "신경이 날카로운", category: .angry),
        
        Emotion(emoji: "😐", name: "무덤덤", description: "특별한 감정 없는", category: .neutral),
        Emotion(emoji: "🙂", name: "평온", description: "마음이 고요한", category: .neutral)
    ]
}

// MARK: - ✅ 원래 구조 복원된 감정 일기 모델 (기존 유지)
struct EmotionDiary: Codable, Identifiable {
    let id: UUID
    let date: Date
    let selectedEmotion: String
    let userMessage: String    // ✅ 원래대로 userMessage 사용
    let aiResponse: String     // ✅ 원래대로 aiResponse 사용
    
    // ✅ 원래 초기화 방식 복원
    init(id: UUID = UUID(), selectedEmotion: String, userMessage: String, aiResponse: String, date: Date = Date()) {
        self.id = id
        self.selectedEmotion = selectedEmotion
        self.userMessage = userMessage
        self.aiResponse = aiResponse
        self.date = date
    }
    
    // ✅ 편의 초기화 (기존 코드 호환성)
    init(selectedEmotion: String, userMessage: String, aiResponse: String) {
        self.init(selectedEmotion: selectedEmotion, userMessage: userMessage, aiResponse: aiResponse, date: Date())
    }
}

// MARK: - ✅ 확장된 사운드 프리셋 모델 (버전 정보 포함)
struct SoundPreset: Codable {
    let id: UUID
    let name: String
    let volumes: [Float]
    let emotion: String?
    let isAIGenerated: Bool
    let description: String?
    let createdDate: Date
    
    // ✅ 새로 추가: 버전 정보 (11개 카테고리)
    let selectedVersions: [Int]?  // 각 카테고리별 선택된 버전 인덱스
    let presetVersion: String     // 프리셋 버전 ("v1.0" = 12개, "v2.0" = 11개)
    
    // MARK: - 기존 호환성 초기화 (12개 → 11개 변환 없이 저장)
    init(name: String, volumes: [Float], emotion: String? = nil, isAIGenerated: Bool = false, description: String? = nil) {
        self.id = UUID()
        self.name = name
        self.volumes = volumes
        self.emotion = emotion
        self.isAIGenerated = isAIGenerated
        self.description = description
        self.createdDate = Date()
        
        // 기존 버전 호환성
        if volumes.count == 12 {
            self.presetVersion = "v1.0"  // 기존 12개 프리셋
            self.selectedVersions = nil  // 버전 정보 없음
        } else {
            self.presetVersion = "v2.0"  // 새로운 11개 프리셋
            self.selectedVersions = SoundPresetCatalog.defaultVersions  // 기본 버전
        }
    }
    
    // MARK: - 새로운 초기화 (버전 정보 포함)
    init(name: String, volumes: [Float], selectedVersions: [Int], emotion: String? = nil, isAIGenerated: Bool = false, description: String? = nil) {
        self.id = UUID()
        self.name = name
        self.volumes = volumes
        self.selectedVersions = selectedVersions
        self.emotion = emotion
        self.isAIGenerated = isAIGenerated
        self.description = description
        self.createdDate = Date()
        self.presetVersion = "v2.0"  // 항상 새 버전
    }
    
    // MARK: - 버전 호환성 메서드
    
    /// 11개 카테고리용 볼륨 배열 반환
    var compatibleVolumes: [Float] {
        if presetVersion == "v1.0" && volumes.count == 12 {
            // 기존 12개를 11개로 변환
            return volumes.count == 13 ? volumes : Array(repeating: 0.0, count: 13)
        } else {
            // 이미 11개이거나 새 버전
            return volumes
        }
    }
    
    /// 현재 선택된 버전들 반환 (없으면 기본값)
    var compatibleVersions: [Int] {
        return selectedVersions ?? SoundPresetCatalog.defaultVersions
    }
    
    /// 프리셋이 새로운 11개 카테고리 형식인지 확인
    var isNewFormat: Bool {
        return presetVersion == "v2.0"
    }
    
    /// 레거시 형식에서 새 형식으로 업그레이드
    func upgraded() -> SoundPreset {
        if isNewFormat {
            return self  // 이미 새 형식
        }
        
        return SoundPreset(
            name: name,
            volumes: compatibleVolumes,
            selectedVersions: SoundPresetCatalog.defaultVersions,
            emotion: emotion,
            isAIGenerated: isAIGenerated,
            description: description
        )
    }
}

// MARK: - ✅ 프리셋 버전 관리
struct PresetManager {
    static let shared = PresetManager()
    
    private init() {}
    
    /// 기존 프리셋들을 새 형식으로 마이그레이션 (통합 및 강화)
    func migrateLegacyPresetsIfNeeded() {
        let userDefaults = UserDefaults.standard
        let migrationKey = "presetMigrationV3Completed" // 키 변경으로 재실행 보장

        guard !userDefaults.bool(forKey: migrationKey) else {
            print("✅ 통합 프리셋 마이그레이션 이미 완료됨")
            return
        }

        let existingPresets = SettingsManager.shared.loadSoundPresets()
        var migratedCount = 0
        // needsSave 변수는 미래 확장을 위해 예약됨
        // var needsSave = false

        let updatedPresets = existingPresets.map { preset -> SoundPreset in
            var mutablePreset = preset
            var presetWasModified = false

            // 조건 1: isNewFormat이 false인 경우 (12개 볼륨 -> 11개로 변환 필요)
            if !mutablePreset.isNewFormat {
                mutablePreset = mutablePreset.upgraded()
                presetWasModified = true
            }

            // 조건 2: selectedVersions가 nil인 경우 (버전 정보 추가 필요)
            if mutablePreset.selectedVersions == nil {
                // SoundPreset의 init에서 이미 기본값을 할당하므로, 여기서는 nil 체크만으로 충분
                // 하지만 명시적으로 다시 할당하여 안정성 강화
                var newVolumes = mutablePreset.volumes
                if newVolumes.count != SoundPresetCatalog.categoryCount {
                    newVolumes = Array(repeating: 0.0, count: SoundPresetCatalog.categoryCount)
                }
                
                mutablePreset = SoundPreset(
                    name: mutablePreset.name,
                    volumes: newVolumes,
                    selectedVersions: SoundPresetCatalog.defaultVersions,
                    emotion: mutablePreset.emotion,
                    isAIGenerated: mutablePreset.isAIGenerated,
                    description: mutablePreset.description
                )
                presetWasModified = true
            }

            if presetWasModified {
                migratedCount += 1
            }
            return mutablePreset
        }
        
        // 변경된 경우에만 전체 프리셋을 다시 저장
        if migratedCount > 0 {
            SettingsManager.shared.replaceAllPresets(with: updatedPresets)
            print("✅ 통합 프리셋 마이그레이션 완료: \(migratedCount)개 업그레이드")
        }

        userDefaults.set(true, forKey: migrationKey)
    }
    
    /// 새로운 버전 정보를 포함한 프리셋 저장
    func savePresetWithVersions(name: String, volumes: [Float], versions: [Int], emotion: String? = nil, isAIGenerated: Bool = false) {
        let preset = SoundPreset(
            name: name,
            volumes: volumes,
            selectedVersions: versions,
            emotion: emotion,
            isAIGenerated: isAIGenerated,
            description: isAIGenerated ? "AI 추천 프리셋" : "사용자 저장 프리셋"
        )
        
        SettingsManager.shared.saveSoundPreset(preset)
        print("✅ 새 형식 프리셋 저장: \(name)")
    }
}

// MARK: - 일기 컨텍스트 모델 (기존 유지)
struct DiaryContext {
    let emotion: String
    let content: String
    let date: Date
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter.string(from: date)
    }
    
    var contextPrompt: String {
        return """
        사용자가 작성한 감정 일기:
        
        날짜: \(formattedDate)
        감정: \(emotion)
        
        일기 내용:
        \(content)
        
        위 일기를 읽고 사용자의 감정에 깊이 공감해주시고, 
        따뜻하고 위로가 되는 대화를 해주세요.
        마음의 안정을 위한 조언도 함께 해주시면 좋겠습니다.
        """
    }
    
    // ✅ EmotionDiary에서 DiaryContext 생성하는 편의 메소드 (원래 구조로)
    init(from diary: EmotionDiary) {
        self.emotion = diary.selectedEmotion
        self.content = diary.userMessage  // ✅ userMessage 사용
        self.date = diary.date
    }
}

// MARK: - 사용자 설정 모델 (기존 유지)
struct UserSettings: Codable {
    var dailyChatLimit: Int = 50
    var dailyPresetLimit: Int = 5
    var enableNotifications: Bool = true
    var autoSavePresets: Bool = true
    var preferredFadeOutDuration: TimeInterval = 30.0
    var enableHapticFeedback: Bool = true
    var preferredTheme: Theme = .system
    
    enum Theme: String, CaseIterable, Codable {
        case light = "라이트"
        case dark = "다크"
        case system = "시스템"
    }
}

// MARK: - 사용 통계 모델 (기존 유지)
struct UsageStats: Codable {
    let date: String
    var chatCount: Int = 0
    var presetRecommendationCount: Int = 0
    var patternAnalysisCount: Int = 0
    var diaryAnalysisCount: Int = 0
    var timerUsageCount: Int = 0
    var totalSessionTime: TimeInterval = 0
    var mostUsedEmotion: String?
    var effectivePresets: [String] = []
    
    init(date: String) {
        self.date = date
    }
}

// MARK: - AI 응답 모델 (확장됨)
struct AIResponse {
    let message: String
    let preset: SoundPreset?
    let confidence: Float
    let processingTime: TimeInterval
    let intent: AIIntent
    
    enum AIIntent: String {
        case chat = "일반 대화"
        case diary = "감정 일기"
        case presetRecommendation = "프리셋 추천"
        case comfort = "위로"
        case advice = "조언"
        case diaryAnalysis = "일기 분석"
        case patternAnalysis = "패턴 분석"
    }
}

// MARK: - ✅ 확장된 추천 응답 모델 (기존과 충돌 방지)
struct EnhancedRecommendationResponse {
    let volumes: [Float]
    let presetName: String
    let selectedVersions: [Int]?  // 버전 정보 추가
    let confidence: Float
    
    init(volumes: [Float], presetName: String, selectedVersions: [Int]? = nil, confidence: Float = 1.0) {
        self.volumes = volumes
        self.presetName = presetName
        self.selectedVersions = selectedVersions ?? SoundPresetCatalog.defaultVersions
        self.confidence = confidence
    }
    
    // 기존 RecommendationResponse와 호환성을 위한 변환
    func toLegacyFormat() -> (volumes: [Float], presetName: String) {
        return (volumes: volumes, presetName: presetName)
    }
}

// MARK: - 알림 모델 (기존 유지)
struct DeepSleepNotification: Codable {
    let id: UUID
    let title: String
    let body: String
    let scheduledDate: Date
    let type: NotificationType
    let isRepeating: Bool
    
    enum NotificationType: String, Codable {
        case timerComplete = "타이머 완료"
        case dailyCheckIn = "일일 체크인"
        case recommendationReady = "추천 준비 완료"
        case moodReminder = "기분 체크 알림"
    }
    
    init(title: String, body: String, scheduledDate: Date, type: NotificationType, isRepeating: Bool = false) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.scheduledDate = scheduledDate
        self.type = type
        self.isRepeating = isRepeating
    }
}

// MARK: - ✅ 감정 패턴 분석 모델 (기존 유지)
struct EmotionPattern: Codable {
    let startDate: Date
    let endDate: Date
    let emotionFrequency: [String: Int]
    let totalEntries: Int
    let mostFrequentEmotion: String
    let averageEntriesPerDay: Double
    let emotionTrend: EmotionTrend
    
    enum EmotionTrend: String, Codable {
        case improving = "개선"
        case stable = "안정"
        case declining = "하락"
        case mixed = "혼재"
    }
    
    var analysisText: String {
        let period = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return """
        📊 \(period)일간 감정 패턴 분석
        
        • 총 기록: \(totalEntries)개
        • 가장 많은 감정: \(mostFrequentEmotion)
        • 평균 일일 기록: \(String(format: "%.1f", averageEntriesPerDay))개
        • 전체적 경향: \(emotionTrend.rawValue)
        
        감정별 빈도:
        \(emotionFrequency.map { "\($0.key): \($0.value)회" }.joined(separator: "\n"))
        """
    }
}

// MARK: - ✅ 차트 데이터 모델 (향후 차트 구현용)
struct ChartDataPoint: Codable {
    let date: Date
    let emotion: String
    let value: Double // 감정 점수 또는 빈도
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

struct EmotionChartData: Codable {
    let title: String
    let dataPoints: [ChartDataPoint]
    let chartType: ChartType
    
    enum ChartType: String, Codable {
        case line = "라인"
        case bar = "막대"
        case pie = "원형"
    }
}

// MARK: - ✅ 인사이트 카드 모델
struct InsightCard {
    let id = UUID()
    let title: String
    let content: String
    let color: UIColor
    let icon: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(title: String, content: String, color: UIColor, icon: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.content = content
        self.color = color
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
    }
}

// MARK: - ✅ 데이터 내보내기/가져오기 모델
struct ExportData: Codable {
    let exportDate: Date
    let diaries: [EmotionDiary]
    let presets: [SoundPreset]
    let settings: UserSettings
    let stats: [String: UsageStats]
    let appVersion: String
    
    init(diaries: [EmotionDiary], presets: [SoundPreset], settings: UserSettings, stats: [String: UsageStats]) {
        self.exportDate = Date()
        self.diaries = diaries
        self.presets = presets
        self.settings = settings
        self.stats = stats
        self.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

// MARK: - ✅ 확장 메소드들
extension EmotionDiary {
    
    /// 일기의 감정 카테고리 반환
    var emotionCategory: Emotion.EmotionCategory {
        let emotion = Emotion.predefinedEmotions.first { $0.emoji == selectedEmotion }
        return emotion?.category ?? .neutral
    }
    
    /// 일기 길이에 따른 상세도 레벨
    var detailLevel: DetailLevel {
        switch userMessage.count {  // ✅ userMessage 사용
        case 0..<50:
            return .brief
        case 50..<200:
            return .moderate
        default:
            return .detailed
        }
    }
    
    enum DetailLevel: String {
        case brief = "간단"
        case moderate = "보통"
        case detailed = "상세"
    }
}

extension Array where Element == EmotionDiary {
    
    /// 날짜 범위별 일기 필터링
    func entries(in dateRange: ClosedRange<Date>) -> [EmotionDiary] {
        return self.filter { dateRange.contains($0.date) }
    }
    
    /// 특정 감정의 일기만 필터링
    func entries(with emotion: String) -> [EmotionDiary] {
        return self.filter { $0.selectedEmotion == emotion }
    }
    
    /// 감정 패턴 분석 생성
    func generatePattern(for period: Int = 30) -> EmotionPattern {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -period, to: endDate) ?? endDate
        
        let filteredEntries = self.entries(in: startDate...endDate)
        let emotionFrequency = Dictionary(grouping: filteredEntries, by: { $0.selectedEmotion })
            .mapValues { $0.count }
        
        let mostFrequent = emotionFrequency.max { $0.value < $1.value }?.key ?? "😊"
        let averagePerDay = Double(filteredEntries.count) / Double(period)
        
        return EmotionPattern(
            startDate: startDate,
            endDate: endDate,
            emotionFrequency: emotionFrequency,
            totalEntries: filteredEntries.count,
            mostFrequentEmotion: mostFrequent,
            averageEntriesPerDay: averagePerDay,
            emotionTrend: calculateTrend(for: filteredEntries)
        )
    }
    
    /// 감정 트렌드 계산
    private func calculateTrend(for entries: [EmotionDiary]) -> EmotionPattern.EmotionTrend {
        guard entries.count >= 7 else { return .stable }
        
        let sortedEntries = entries.sorted { $0.date < $1.date }
        let midPoint = sortedEntries.count / 2
        
        let firstHalf = Array(sortedEntries.prefix(midPoint))
        let secondHalf = Array(sortedEntries.suffix(midPoint))
        
        let firstPositiveRatio = calculatePositiveEmotionRatio(firstHalf)
        let secondPositiveRatio = calculatePositiveEmotionRatio(secondHalf)
        
        let difference = secondPositiveRatio - firstPositiveRatio
        
        switch difference {
        case 0.1...:
            return .improving
        case ..<(-0.1):
            return .declining
        case -0.1...0.1:
            return .stable
        default:
            return .mixed
        }
    }
    
    /// 긍정적 감정 비율 계산
    private func calculatePositiveEmotionRatio(_ entries: [EmotionDiary]) -> Double {
        guard !entries.isEmpty else { return 0 }
        
        let positiveEmotions = ["😊", "😄", "🥰", "😐", "🙂"]
        let positiveCount = entries.filter { positiveEmotions.contains($0.selectedEmotion) }.count
        
        return Double(positiveCount) / Double(entries.count)
    }
}

// MARK: - ✅ SoundPreset 확장
extension SoundPreset {
    
    /// 프리셋의 주요 사운드 카테고리들 (볼륨이 높은 순)
    var dominantCategories: [(emoji: String, name: String, volume: Float)] {
        let volumes = compatibleVolumes
        let categoryCount = min(volumes.count, SoundPresetCatalog.categoryCount)
        
        var results: [(emoji: String, name: String, volume: Float)] = []
        
        for i in 0..<categoryCount {
            if volumes[i] > 0 {
                results.append((
                    emoji: SoundPresetCatalog.categoryEmojis[i],
                    name: SoundPresetCatalog.categoryNames[i],
                    volume: volumes[i]
                ))
            }
        }
        
        return results.sorted { $0.volume > $1.volume }
    }
    
    /// 프리셋 요약 텍스트
    var summaryText: String {
        let dominant = dominantCategories.prefix(3)
        if dominant.isEmpty {
            return "🔇 무음"
        }
        
        let descriptions = dominant.map { "\($0.emoji)\($0.name)" }
        return descriptions.joined(separator: " + ")
    }
    
    /// 프리셋의 전체 볼륨 레벨
    var totalVolumeLevel: VolumeLevel {
        let totalVolume = compatibleVolumes.reduce(0, +)
        switch totalVolume {
        case 0:
            return .silent
        case 1..<100:
            return .low
        case 100..<300:
            return .medium
        case 300..<600:
            return .high
        default:
            return .veryHigh
        }
    }
    
    enum VolumeLevel: String {
        case silent = "무음"
        case low = "낮음"
        case medium = "보통"
        case high = "높음"
        case veryHigh = "매우 높음"
    }
}

// MARK: - ✅ SettingsManager 확장을 위한 프로토콜
protocol EmotionDiaryManaging {
    func saveEmotionDiary(_ entry: EmotionDiary)
    func loadEmotionDiary() -> [EmotionDiary]
    func deleteEmotionDiary(id: UUID)
    func updateEmotionDiary(_ updatedDiary: EmotionDiary)
    func clearAllEmotionDiaries()
}

// MARK: - ✅ 유틸리티 확장
extension Date {
    
    /// 오늘인지 확인
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// 이번 주인지 확인
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    /// 상대적 시간 표현
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

extension String {
    
    /// 감정 이모지인지 확인
    var isEmotionEmoji: Bool {
        let emotionEmojis = ["😊", "😢", "😡", "😰", "😴", "🥰", "😞", "😤", "😱", "😪", "😐", "🙂"]
        return emotionEmojis.contains(self)
    }
    
    /// 텍스트 감정 점수 (간단한 키워드 기반)
    var emotionScore: Double {
        let positiveKeywords = ["좋", "행복", "기쁨", "즐거", "편안", "만족", "완벽", "최고"]
        let negativeKeywords = ["나쁘", "슬프", "우울", "힘들", "불안", "화나", "짜증", "최악"]
        
        let text = self.lowercased()
        var score = 0.0
        
        for keyword in positiveKeywords {
            if text.contains(keyword) { score += 1.0 }
        }
        
        for keyword in negativeKeywords {
            if text.contains(keyword) { score -= 1.0 }
        }
        
        return score
    }
}

// MARK: - ✅ 색상 확장 (감정별 색상)
extension UIColor {
    
    static func emotionColor(for emotion: String) -> UIColor {
        switch emotion {
        case "😊", "😄", "🥰":
            return .systemYellow.withAlphaComponent(0.3)
        case "😢", "😞", "😔":
            return .systemBlue.withAlphaComponent(0.3)
        case "😡", "😤":
            return .systemRed.withAlphaComponent(0.3)
        case "😰", "😱", "😨":
            return .systemOrange.withAlphaComponent(0.3)
        case "😴", "😪":
            return .systemPurple.withAlphaComponent(0.3)
        default:
            return .systemGray.withAlphaComponent(0.3)
        }
    }
    
    /// 다크 모드 호환 색상
    static var adaptiveBackground: UIColor {
        if #available(iOS 13.0, *) {
            return UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? .systemGray6 : .systemBackground
            }
        } else {
            return .white
        }
    }
    
    static var adaptiveText: UIColor {
        if #available(iOS 13.0, *) {
            return .label
        } else {
            return .black
        }
    }
}

// MARK: - ✅ 디버그 및 로깅 확장
extension EmotionDiary {
    
    #if DEBUG
    /// 디버그용 일기 생성
    static func mockDiary(emotion: String = "😊", userMessage: String = "테스트 일기입니다.", aiResponse: String = "테스트 AI 응답입니다.", daysAgo: Int = 0) -> EmotionDiary {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return EmotionDiary(selectedEmotion: emotion, userMessage: userMessage, aiResponse: aiResponse, date: date)
    }
    
    /// 디버그용 여러 일기 생성
    static func mockDiaries(count: Int = 10) -> [EmotionDiary] {
        let emotions = ["😊", "😢", "😡", "😰", "😴", "🥰", "😞", "😤", "😱", "😪"]
        let userMessages = [
            "오늘은 정말 좋은 하루였어요!",
            "조금 우울한 기분이에요.",
            "화가 나는 일이 있었어요.",
            "불안한 마음이 들어요.",
            "너무 피곤해요.",
            "사랑스러운 순간이었어요.",
            "실망스러운 하루였어요.",
            "짜증이 많이 났어요.",
            "무서운 일이 있었어요.",
            "잠이 너무 와요."
        ]
        let aiResponses = [
            "좋은 하루를 보내셨군요! 이런 긍정적인 에너지를 계속 유지하세요.",
            "우울한 기분이 드는 것은 자연스러운 일이에요. 천천히 회복해나가세요.",
            "화나는 일이 있으셨군요. 깊게 숨을 쉬고 마음을 진정시켜보세요.",
            "불안함을 느끼고 계시는군요. 명상이나 가벼운 운동이 도움이 될 수 있어요.",
            "피곤하신 것 같네요. 충분한 휴식을 취하시길 바래요.",
            "사랑스러운 순간을 경험하셨군요! 이런 따뜻한 감정을 간직하세요.",
            "실망스러운 하루였군요. 내일은 더 나은 하루가 될 거예요.",
            "짜증이 나셨군요. 잠시 휴식을 취하고 마음을 가라앉혀보세요.",
            "무서운 경험을 하셨군요. 안전한 곳에 계시니 괜찮을 거예요.",
            "잠이 오는군요. 충분한 수면은 건강에 중요해요."
        ]
        
        return (0..<count).map { index in
            mockDiary(
                emotion: emotions[index % emotions.count],
                userMessage: userMessages[index % userMessages.count],
                aiResponse: aiResponses[index % aiResponses.count],
                daysAgo: index
            )
        }
    }
    #endif
}

// MARK: - ✅ 에러 타입 정의
enum DeepSleepError: LocalizedError {
    case diaryNotFound
    case invalidData
    case saveFailure
    case loadFailure
    case networkError
    case permissionDenied
    case presetVersionMismatch
    case soundFileNotFound
    
    var errorDescription: String? {
        switch self {
        case .diaryNotFound:
            return "일기를 찾을 수 없습니다."
        case .invalidData:
            return "잘못된 데이터입니다."
        case .saveFailure:
            return "저장에 실패했습니다."
        case .loadFailure:
            return "불러오기에 실패했습니다."
        case .networkError:
            return "네트워크 오류가 발생했습니다."
        case .permissionDenied:
            return "권한이 거부되었습니다."
        case .presetVersionMismatch:
            return "프리셋 버전이 호환되지 않습니다."
        case .soundFileNotFound:
            return "사운드 파일을 찾을 수 없습니다."
        }
    }
}

// MARK: - ✅ 상수 정의
struct DeepSleepConstants {
    struct UI {
        static let cornerRadius: CGFloat = 12
        static let padding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let buttonHeight: CGFloat = 50
        static let cellHeight: CGFloat = 140
    }
    
    struct Animation {
        static let duration: TimeInterval = 0.3
        static let springDamping: CGFloat = 0.8
        static let springVelocity: CGFloat = 0.5
    }
    
    struct Limits {
        static let maxDiaryLength = 1000
        static let maxDiaryCount = 500
        static let recentDiaryCount = 10
        static let analysisDefaultPeriod = 30
    }
    
    struct Sound {
        static let categoryCount = 13  // 그룹화된 13개 슬라이더
        static let previewDuration: TimeInterval = 3.0
        static let defaultFadeOutDuration: TimeInterval = 30.0
        static let maxVolume: Float = 100.0
        static let minVolume: Float = 0.0
    }
}
