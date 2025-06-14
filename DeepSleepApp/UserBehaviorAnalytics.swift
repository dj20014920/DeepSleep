import Foundation
import UIKit
import AVFoundation

/// 🧠 사용자 행동 자동 분석 시스템 (Netflix/Spotify/Google 수준)
/// 명시적 피드백 없이 사용자 패턴을 자동으로 학습하고 분석
class UserBehaviorAnalytics {
    static let shared = UserBehaviorAnalytics()
    
    // Private session tracking
    private var currentSessionStartTime: Date?
    private var currentSessionData: (String, [Float], [Int], String)?
    
    private init() {}
    
    // MARK: - 🎯 Core Analytics Engine
    
    /// 사용자 세션 자동 기록 (백그라운드에서 실행)
    func recordSession(
        presetName: String,
        volumes: [Float],
        versions: [Int],
        emotion: String,
        startTime: Date,
        endTime: Date? = nil,
        completionRate: Float = 0.0,
        interactionEvents: [InteractionEvent] = []
    ) {
        let session = UserSession(
            id: UUID(),
            presetName: presetName,
            volumes: volumes,
            versions: versions,
            emotion: emotion,
            startTime: startTime,
            endTime: endTime ?? Date(),
            duration: endTime?.timeIntervalSince(startTime) ?? Date().timeIntervalSince(startTime),
            completionRate: completionRate,
            interactionEvents: interactionEvents,
            contextData: captureCurrentContext()
        )
        
        // 세션 저장
        saveSession(session)
        
        // 실시간 패턴 분석 트리거
        analyzeRealtimePatterns()
    }
    
    /// 🔍 실시간 패턴 분석 (Google Analytics 스타일)
    private func analyzeRealtimePatterns() {
        DispatchQueue.global(qos: .utility).async {
            // 1. 최근 100개 세션 분석
            let recentSessions = self.loadRecentSessions(limit: 100)
            
            // 2. 감정별 선호도 패턴 분석
            let emotionPatterns = self.analyzeEmotionPatterns(sessions: recentSessions)
            
            // 3. 시간대별 사용 패턴 분석
            let timePatterns = self.analyzeTimePatterns(sessions: recentSessions)
            
            // 4. 음원 조합 선호도 분석
            let soundPatterns = self.analyzeSoundPreferences(sessions: recentSessions)
            
            // 5. 완료율 기반 만족도 추정
            let satisfactionMetrics = self.analyzeSatisfactionMetrics(sessions: recentSessions)
            
            // 6. 결과를 종합하여 사용자 프로필 업데이트
            let comprehensiveProfile = UserBehaviorProfile(
                emotionPatterns: emotionPatterns,
                timePatterns: timePatterns,
                soundPatterns: soundPatterns,
                satisfactionMetrics: satisfactionMetrics,
                lastUpdated: Date()
            )
            
            self.updateUserProfile(comprehensiveProfile)
        }
    }
    
    // MARK: - 📊 Advanced Pattern Analysis
    
    /// 감정별 선호 패턴 분석 (Spotify Discovery 스타일)
    private func analyzeEmotionPatterns(sessions: [UserSession]) -> [String: EmotionPreferencePattern] {
        var patterns: [String: EmotionPreferencePattern] = [:]
        
        let emotionGroups = Dictionary(grouping: sessions) { $0.emotion }
        
        for (emotion, emotionSessions) in emotionGroups {
            // 완료율이 높은 프리셋들 분석
            let highSatisfactionSessions = emotionSessions.filter { $0.completionRate > 0.7 }
            
            // 음원별 사용 빈도 계산
            var soundFrequency: [String: Int] = [:]
            var versionPreferences: [Int: Int] = [:]
            var averageDuration: TimeInterval = 0
            
            for session in highSatisfactionSessions {
                // 주요 음원 (볼륨 0.3 이상) 추출
                for (index, volume) in session.volumes.enumerated() {
                    if volume > 0.3 && index < SoundPresetCatalog.categoryNames.count {
                        let soundName = SoundPresetCatalog.categoryNames[index]
                        soundFrequency[soundName, default: 0] += 1
                        
                        // 버전 선호도 기록
                        if index < session.versions.count {
                            versionPreferences[session.versions[index], default: 0] += 1
                        }
                    }
                }
                averageDuration += session.duration
            }
            
            averageDuration = highSatisfactionSessions.isEmpty ? 0 : averageDuration / Double(highSatisfactionSessions.count)
            
            // 선호 음원 상위 5개 추출
            let preferredSounds = soundFrequency.sorted { $0.value > $1.value }
                .prefix(5)
                .map { $0.key }
            
            patterns[emotion] = EmotionPreferencePattern(
                emotion: emotion,
                preferredSounds: Array(preferredSounds),
                versionPreferences: versionPreferences,
                averageSessionDuration: averageDuration,
                satisfactionRate: Double(highSatisfactionSessions.count) / Double(emotionSessions.count),
                totalSessions: emotionSessions.count
            )
        }
        
        return patterns
    }
    
    /// 시간대별 사용 패턴 분석 (Google Analytics 스타일)
    private func analyzeTimePatterns(sessions: [UserSession]) -> [Int: TimeUsagePattern] {
        var patterns: [Int: TimeUsagePattern] = [:]
        
        let hourGroups = Dictionary(grouping: sessions) { session in
            Calendar.current.component(.hour, from: session.startTime)
        }
        
        for (hour, hourSessions) in hourGroups {
            let emotionDistribution = Dictionary(grouping: hourSessions) { $0.emotion }
                .mapValues { Double($0.count) / Double(hourSessions.count) }
            
            let averageDuration = hourSessions.reduce(0) { $0 + $1.duration } / Double(hourSessions.count)
            let averageCompletionRate = hourSessions.reduce(0) { $0 + $1.completionRate } / Float(hourSessions.count)
            
            patterns[hour] = TimeUsagePattern(
                hour: hour,
                emotionDistribution: emotionDistribution,
                averageDuration: averageDuration,
                averageCompletionRate: averageCompletionRate,
                totalSessions: hourSessions.count
            )
        }
        
        return patterns
    }
    
    /// 음원 조합 선호도 분석 (Amazon Recommendation 스타일)
    private func analyzeSoundPreferences(sessions: [UserSession]) -> SoundPreferenceAnalysis {
        var soundCombinations: [String: Int] = [:]
        var individualSoundUsage: [String: SoundUsageMetric] = [:]
        
        for session in sessions {
            // 주요 음원들 (볼륨 0.2 이상) 추출
            var activeSounds: [String] = []
            
            for (index, volume) in session.volumes.enumerated() {
                if volume > 0.2 && index < SoundPresetCatalog.categoryNames.count {
                    let soundName = SoundPresetCatalog.categoryNames[index]
                    activeSounds.append(soundName)
                    
                    // 개별 음원 사용 통계 업데이트
                    var metric = individualSoundUsage[soundName] ?? SoundUsageMetric(
                        soundName: soundName,
                        totalUsage: 0,
                        averageVolume: 0,
                        averageCompletionRate: 0,
                        emotionAssociations: [:]
                    )
                    
                    metric.totalUsage += 1
                    metric.averageVolume = (metric.averageVolume * Float(metric.totalUsage - 1) + volume) / Float(metric.totalUsage)
                    metric.averageCompletionRate = (metric.averageCompletionRate * Float(metric.totalUsage - 1) + session.completionRate) / Float(metric.totalUsage)
                    metric.emotionAssociations[session.emotion, default: 0] += 1
                    
                    individualSoundUsage[soundName] = metric
                }
            }
            
            // 음원 조합 패턴 기록 (2-3개 조합)
            if activeSounds.count >= 2 {
                let sortedCombination = activeSounds.sorted().joined(separator: "+")
                soundCombinations[sortedCombination, default: 0] += 1
            }
        }
        
        return SoundPreferenceAnalysis(
            popularCombinations: soundCombinations.sorted { $0.value > $1.value }.prefix(10).map { PopularCombination(name: $0.key, count: $0.value) },
            individualSoundMetrics: individualSoundUsage,
            totalAnalyzedSessions: sessions.count
        )
    }
    
    /// 만족도 메트릭 분석 (Netflix 스타일)
    private func analyzeSatisfactionMetrics(sessions: [UserSession]) -> SatisfactionAnalysis {
        let completionRates = sessions.map { $0.completionRate }
        let durations = sessions.map { $0.duration }
        
        // 완료율 분포 계산
        let highSatisfaction = sessions.filter { $0.completionRate > 0.8 }.count
        let mediumSatisfaction = sessions.filter { $0.completionRate > 0.4 && $0.completionRate <= 0.8 }.count
        let lowSatisfaction = sessions.filter { $0.completionRate <= 0.4 }.count
        
        // 최적 세션 길이 분석
        let highSatisfactionSessions = sessions.filter { $0.completionRate > 0.7 }
        let optimalDuration = highSatisfactionSessions.isEmpty ? 0 : 
            highSatisfactionSessions.reduce(0) { $0 + $1.duration } / Double(highSatisfactionSessions.count)
        
        return SatisfactionAnalysis(
            averageCompletionRate: completionRates.reduce(0, +) / Float(completionRates.count),
            satisfactionDistribution: SatisfactionDistribution(
                high: Double(highSatisfaction) / Double(sessions.count),
                medium: Double(mediumSatisfaction) / Double(sessions.count),
                low: Double(lowSatisfaction) / Double(sessions.count)
            ),
            optimalSessionDuration: optimalDuration,
            averageSessionDuration: durations.reduce(0, +) / Double(durations.count),
            totalAnalyzedSessions: sessions.count
        )
    }
    
    // MARK: - 🎯 Context Capture
    
    /// 현재 컨텍스트 자동 캡처 (Google-level context awareness)
    private func captureCurrentContext() -> ContextData {
        let calendar = Calendar.current
        let now = Date()
        
        return ContextData(
            timeOfDay: calendar.component(.hour, from: now),
            dayOfWeek: calendar.component(.weekday, from: now),
            isWeekend: [1, 7].contains(calendar.component(.weekday, from: now)),
            season: getCurrentSeason(),
            deviceBatteryLevel: UIDevice.current.batteryLevel,
            deviceOrientation: UIDevice.current.orientation.rawValue,
            systemVolume: AVAudioSession.sharedInstance().outputVolume,
            estimatedAmbientNoise: estimateAmbientNoise(),
            recentEmotions: getRecentEmotions(hours: 6),
            appUsageStreak: calculateUsageStreak()
        )
    }
    
    private func getCurrentSeason() -> String {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3...5: return "봄"
        case 6...8: return "여름"
        case 9...11: return "가을"
        default: return "겨울"
        }
    }
    
    private func estimateAmbientNoise() -> Float {
        // 시간대 기반 추정 (실제 마이크 사용은 권한 문제로 제외)
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6...9, 17...22: return 0.7 // 출퇴근 시간
        case 10...16: return 0.5 // 일반 시간
        case 23...24, 0...5: return 0.2 // 야간
        default: return 0.4
        }
    }
    
    private func getRecentEmotions(hours: Int) -> [String] {
        // 최근 N시간 내 감정 데이터 가져오기
        let cutoffTime = Date().addingTimeInterval(-Double(hours * 3600))
        return loadRecentSessions(limit: 50)
            .filter { $0.startTime >= cutoffTime }
            .map { $0.emotion }
    }
    
    private func calculateUsageStreak() -> Int {
        // 연속 사용 일수 계산
        let sessions = loadRecentSessions(limit: 100)
        let calendar = Calendar.current
        
        var streak = 0
        var currentDate = Date()
        
        for _ in 0..<30 { // 최대 30일까지 확인
            let dayStart = calendar.startOfDay(for: currentDate)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            let dayHasSessions = sessions.contains { session in
                session.startTime >= dayStart && session.startTime < dayEnd
            }
            
            if dayHasSessions {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else {
                break
            }
        }
        
        return streak
    }
    
    // MARK: - 💾 Data Management
    
    private func saveSession(_ session: UserSession) {
        var sessions = loadAllSessions()
        sessions.append(session)
        
        // 최근 1000개 세션만 유지 (메모리 관리)
        if sessions.count > 1000 {
            sessions = Array(sessions.suffix(1000))
        }
        
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(sessions) {
            UserDefaults.standard.set(data, forKey: "userSessions")
        }
    }
    
    private func loadRecentSessions(limit: Int) -> [UserSession] {
        return Array(loadAllSessions().suffix(limit))
    }
    
    private func loadAllSessions() -> [UserSession] {
        guard let data = UserDefaults.standard.data(forKey: "userSessions"),
              let sessions = try? JSONDecoder().decode([UserSession].self, from: data) else {
            return []
        }
        return sessions
    }
    
    private func updateUserProfile(_ profile: UserBehaviorProfile) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(profile) {
            UserDefaults.standard.set(data, forKey: "userBehaviorProfile")
        }
        
        // 실시간 추천 엔진에 프로필 업데이트 알림
        NotificationCenter.default.post(
            name: .userBehaviorProfileUpdated,
            object: profile
        )
    }
    
    /// 현재 사용자 프로필 가져오기
    func getCurrentUserProfile() -> UserBehaviorProfile? {
        guard let data = UserDefaults.standard.data(forKey: "userBehaviorProfile"),
              let profile = try? JSONDecoder().decode(UserBehaviorProfile.self, from: data) else {
            return nil
        }
        return profile
    }
}

// MARK: - 📊 Data Models for Advanced Analytics

struct UserSession: Codable {
    let id: UUID
    let presetName: String
    let volumes: [Float]
    let versions: [Int]
    let emotion: String
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let completionRate: Float
    let interactionEvents: [InteractionEvent]
    let contextData: ContextData
}

struct InteractionEvent: Codable {
    let type: InteractionType
    let timestamp: Date
    let value: Float?
    let metadata: [String: String]
    
    enum InteractionType: String, Codable {
        case volumeAdjustment = "volume_adjustment"
        case presetChange = "preset_change"
        case pause = "pause"
        case resume = "resume"
        case skip = "skip"
        case favorite = "favorite"
    }
}

struct ContextData: Codable {
    let timeOfDay: Int
    let dayOfWeek: Int
    let isWeekend: Bool
    let season: String
    let deviceBatteryLevel: Float
    let deviceOrientation: Int
    let systemVolume: Float
    let estimatedAmbientNoise: Float
    let recentEmotions: [String]
    let appUsageStreak: Int
}

struct UserBehaviorProfile: Codable {
    let emotionPatterns: [String: EmotionPreferencePattern]
    let timePatterns: [Int: TimeUsagePattern]
    let soundPatterns: SoundPreferenceAnalysis
    let satisfactionMetrics: SatisfactionAnalysis
    let lastUpdated: Date
}

struct EmotionPreferencePattern: Codable {
    let emotion: String
    let preferredSounds: [String]
    let versionPreferences: [Int: Int]
    let averageSessionDuration: TimeInterval
    let satisfactionRate: Double
    let totalSessions: Int
}

struct TimeUsagePattern: Codable {
    let hour: Int
    let emotionDistribution: [String: Double]
    let averageDuration: TimeInterval
    let averageCompletionRate: Float
    let totalSessions: Int
}

struct SoundPreferenceAnalysis: Codable {
    let popularCombinations: [PopularCombination]
    let individualSoundMetrics: [String: SoundUsageMetric]
    let totalAnalyzedSessions: Int
}

struct PopularCombination: Codable {
    let name: String
    let count: Int
}

struct SoundUsageMetric: Codable {
    let soundName: String
    var totalUsage: Int
    var averageVolume: Float
    var averageCompletionRate: Float
    var emotionAssociations: [String: Int]
}

struct SatisfactionAnalysis: Codable {
    let averageCompletionRate: Float
    let satisfactionDistribution: SatisfactionDistribution
    let optimalSessionDuration: TimeInterval
    let averageSessionDuration: TimeInterval
    let totalAnalyzedSessions: Int
}

struct SatisfactionDistribution: Codable {
    let high: Double // >80% 완료율
    let medium: Double // 40-80% 완료율
    let low: Double // <40% 완료율
}

// MARK: - 🔔 Notifications

extension Notification.Name {
    static let userBehaviorProfileUpdated = Notification.Name("userBehaviorProfileUpdated")
}

// MARK: - 🎯 Public API for Integration

extension UserBehaviorAnalytics {
    
    /// 간편한 세션 시작 기록
    func startSession(presetName: String, volumes: [Float], versions: [Int], emotion: String) {
        currentSessionStartTime = Date()
        currentSessionData = (presetName, volumes, versions, emotion)
    }
    
    /// 간편한 세션 종료 기록
    func endSession(completionRate: Float = 1.0, interactionEvents: [InteractionEvent] = []) {
        guard let startTime = currentSessionStartTime,
              let (presetName, volumes, versions, emotion) = currentSessionData else { return }
        
        recordSession(
            presetName: presetName,
            volumes: volumes,
            versions: versions,
            emotion: emotion,
            startTime: startTime,
            endTime: Date(),
            completionRate: completionRate,
            interactionEvents: interactionEvents
        )
        
        currentSessionStartTime = nil
        currentSessionData = nil
    }
    
    /// Get analytics summary for debugging
    func getAnalyticsSummary() -> String {
        let profile = getCurrentUserProfile()
        let recentSessions = loadRecentSessions(limit: 50)
        
        return """
        📊 User Behavior Analytics Summary
        
        📈 Recent Sessions: \(recentSessions.count)
        🎭 Emotions Tracked: \(profile?.emotionPatterns.keys.count ?? 0)
        ⏰ Time Patterns: \(profile?.timePatterns.keys.count ?? 0)
        🎵 Sound Combinations: \(profile?.soundPatterns.popularCombinations.count ?? 0)
        📊 Avg Completion Rate: \(String(format: "%.1f%%", (profile?.satisfactionMetrics.averageCompletionRate ?? 0) * 100))
        🔥 Usage Streak: \(getRecentEmotions(hours: 24).count > 0 ? "Active" : "Inactive")
        """
    }
    

}