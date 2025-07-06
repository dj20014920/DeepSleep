//
//  ComprehensiveRecommendationEngine.swift
//  DeepSleep
//
//  Created by AI on 2025/07/04.
//

import Foundation
import Core

/// 사용자의 감정, 시간, 상황을 종합적으로 분석하여 최적의 추천을 제공하는 엔진
public final class ComprehensiveRecommendationEngine {
    
    // MARK: - Properties
    
    public static let shared = ComprehensiveRecommendationEngine()
    private let llmRouter = LLMRouter.shared
    private let memoryManager = LongTermMemoryManager.shared
    private let soundManager = SoundManager.shared
    
    // 추천 알고리즘의 가중치
    private struct Weights {
        static let emotionWeight: Double = 0.35
        static let timeWeight: Double = 0.25
        static let historyWeight: Double = 0.20
        static let contextWeight: Double = 0.20
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 종합적인 사운드 추천
    public func recommendSound(
        emotion: String,
        timeContext: TimeContext,
        userContext: RecommendationUserContext
    ) async throws -> SoundRecommendation {
        
        // 1. 사용자 프로필 분석
        let userProfile = await analyzeUserProfile(userContext: userContext)
        
        // 2. 시간대별 선호도 분석
        let timePreference = analyzeTimePreference(timeContext: timeContext)
        
        // 3. 감정 상태 기반 추천
        let emotionBasedSounds = await recommendByEmotion(emotion: emotion)
        
        // 4. 과거 이력 기반 추천
        let historyBasedSounds = await recommendByHistory(userProfile: userProfile)
        
        // 5. 종합 점수 계산
        let recommendations = calculateComprehensiveScore(
            emotionBased: emotionBasedSounds,
            historyBased: historyBasedSounds,
            timePreference: timePreference,
            userProfile: userProfile
        )
        
        // 6. AI 기반 최종 추천
        return try await generateFinalRecommendation(
            candidates: recommendations,
            emotion: emotion,
            context: userContext
        )
    }
    
    /// 감정 기반 맞춤형 조언 생성
    public func generateEmotionAdvice(
        emotion: String,
        intensity: Double,
        context: String? = nil
    ) async throws -> EmotionAdvice {
        
        // 과거 유사 감정 상황 검색
        let similarEmotions = try await memoryManager.searchRelevantMemories(
            query: "\(emotion) 감정",
            limit: 3
        )
        
        // 프롬프트 생성
        var prompt = """
        사용자의 현재 감정: \(emotion) (강도: \(Int(intensity * 100))%)
        
        """
        
        if !similarEmotions.isEmpty {
            prompt += """
            과거 유사한 감정 경험:
            \(similarEmotions.map { "- \($0.date.formatted()): \($0.summary)" }.joined(separator: "\n"))
            
            """
        }
        
        if let context = context {
            prompt += "추가 상황: \(context)\n\n"
        }
        
        prompt += """
        위 정보를 바탕으로 사용자에게 도움이 되는 감정 조절 조언을 200자 이내로 제공해주세요.
        구체적이고 실행 가능한 방법을 포함해주세요.
        """
        
        let response = try await llmRouter.send(
            task: .analyzeEmotion(text: prompt)
        )
        
        return EmotionAdvice(
            content: response.content,
            emotion: emotion,
            intensity: intensity,
            timestamp: Date()
        )
    }
    
    /// 수면 패턴 분석 및 개선 제안
    public func analyzeSleepPattern(
        sleepData: [SleepData],
        currentEmotion: String? = nil
    ) async throws -> SleepAnalysis {
        
        // 평균 수면 시간 계산
        let avgSleepDuration = sleepData.map { $0.duration }.reduce(0, +) / Double(sleepData.count)
        
        // 수면 품질 점수 계산
        let qualityScore = calculateSleepQualityScore(sleepData: sleepData)
        
        // 패턴 분석
        let patterns = analyzeSleepPatterns(sleepData: sleepData)
        
        // AI 기반 개인화된 조언 생성
        let advice = try await generateSleepAdvice(
            avgDuration: avgSleepDuration,
            qualityScore: qualityScore,
            patterns: patterns,
            emotion: currentEmotion
        )
        
        return SleepAnalysis(
            averageDuration: avgSleepDuration,
            qualityScore: qualityScore,
            patterns: patterns,
            advice: advice,
            recommendedSounds: await recommendSleepSounds(patterns: patterns)
        )
    }
    
    // MARK: - Private Methods
    
    private func analyzeUserProfile(userContext: RecommendationUserContext) async -> UserProfileVector {
        // 사용자 프로필 분석 로직
        let feedbackHistory = await loadUserFeedbackHistory()
        return UserProfileVector(feedbackData: feedbackHistory)
    }
    
    private func analyzeTimePreference(timeContext: TimeContext) -> TimePreference {
        let hour = Calendar.current.component(.hour, from: timeContext.currentTime)
        
        let category: TimeCategory
        switch hour {
        case 5..<9:
            category = .earlyMorning
        case 9..<12:
            category = .morning
        case 12..<14:
            category = .noon
        case 14..<18:
            category = .afternoon
        case 18..<22:
            category = .evening
        default:
            category = .night
        }
        
        return TimePreference(
            category: category,
            preferredSoundTypes: getPreferredSoundTypes(for: category)
        )
    }
    
    private func recommendByEmotion(emotion: String) async -> [SoundCandidate] {
        // 감정별 추천 사운드 매핑
        let emotionSoundMap: [String: [String]] = [
            "행복": ["cheerful_melody", "upbeat_nature", "light_piano"],
            "슬픔": ["gentle_rain", "soft_strings", "calm_waves"],
            "불안": ["deep_breathing", "white_noise", "forest_ambience"],
            "분노": ["ocean_waves", "meditation_bell", "slow_classical"],
            "평온": ["nature_mix", "ambient_space", "soft_rain"]
        ]
        
        let soundIds = emotionSoundMap[emotion] ?? ["white_noise", "nature_mix"]
        
        return soundIds.map { soundId in
            SoundCandidate(
                id: soundId,
                score: 0.8,
                reason: "\(emotion) 감정에 적합한 사운드"
            )
        }
    }
    
    private func recommendByHistory(userProfile: UserProfileVector) async -> [SoundCandidate] {
        // 사용자 이력 기반 추천
        let categories = SoundPresetCatalog.categoryNames
        var candidates: [SoundCandidate] = []
        
        for (index, preference) in userProfile.soundPreferences.enumerated() where preference > 0.6 {
            if index < categories.count {
                candidates.append(SoundCandidate(
                    id: categories[index],
                    score: Double(preference),
                    reason: "자주 사용하고 만족도가 높았던 사운드"
                ))
            }
        }
        
        return Array(candidates.prefix(5))
    }
    
    private func calculateComprehensiveScore(
        emotionBased: [SoundCandidate],
        historyBased: [SoundCandidate],
        timePreference: TimePreference,
        userProfile: UserProfileVector
    ) -> [SoundCandidate] {
        
        var scoreMap: [String: Double] = [:]
        var reasonMap: [String: [String]] = [:]
        
        // 감정 기반 점수
        for candidate in emotionBased {
            scoreMap[candidate.id, default: 0] += candidate.score * Weights.emotionWeight
            reasonMap[candidate.id, default: []].append(candidate.reason)
        }
        
        // 이력 기반 점수
        for candidate in historyBased {
            scoreMap[candidate.id, default: 0] += candidate.score * Weights.historyWeight
            reasonMap[candidate.id, default: []].append(candidate.reason)
        }
        
        // 시간대 기반 점수 추가
        for soundType in timePreference.preferredSoundTypes {
            scoreMap[soundType, default: 0] += Weights.timeWeight
            reasonMap[soundType, default: []].append("현재 시간대에 적합")
        }
        
        // 최종 후보 생성
        return scoreMap.map { (soundId, score) in
            SoundCandidate(
                id: soundId,
                score: min(score, 1.0),
                reason: reasonMap[soundId]?.joined(separator: ", ") ?? ""
            )
        }.sorted { $0.score > $1.score }
    }
    
    private func generateFinalRecommendation(
        candidates: [SoundCandidate],
        emotion: String,
        context: RecommendationUserContext
    ) async throws -> SoundRecommendation {
        
        // 상위 3개 후보 선택
        let topCandidates = Array(candidates.prefix(3))
        
        // AI를 통한 최종 추천 생성
        let prompt = """
        사용자 감정: \(emotion)
        현재 시간: \(context.currentTime.formatted())
        배터리 레벨: \(Int(context.batteryLevel * 100))%
        
        추천 사운드 후보:
        \(topCandidates.map { "- \($0.id): \($0.reason) (점수: \(String(format: "%.2f", $0.score)))" }.joined(separator: "\n"))
        
        위 정보를 바탕으로 가장 적합한 사운드 1개를 선택하고, 선택 이유를 50자 이내로 설명해주세요.
        """
        
        let response = try await llmRouter.send(
            task: .recommendSound(emotion: emotion, situation: prompt)
        )
        
        // 응답 파싱 (간단한 구현)
        let selectedSound = topCandidates.first ?? SoundCandidate(id: "default_sound", score: 0.5, reason: "기본 추천")
        
        return SoundRecommendation(
            soundId: selectedSound.id,
            confidence: selectedSound.score,
            reason: response.content,
            alternatives: Array(topCandidates.dropFirst())
        )
    }
    
    // MARK: - Helper Methods
    
    private func loadUserFeedbackHistory() async -> [PresetFeedback] {
        // 실제 구현시 Core Data나 UserDefaults에서 로드
        return []
    }
    
    private func analyzePreferences(from feedback: [PresetFeedback]) -> [String: Double] {
        var preferences: [String: Double] = [:]
        
        for item in feedback {
            guard let soundId = item.presetName else { continue }
            let score = Double(item.satisfactionScore)  // 0.0-1.0 범위
            preferences[soundId, default: 0] += score
        }
        
        // 정규화
        let total = preferences.values.reduce(0, +)
        if total > 0 {
            for (key, value) in preferences {
                preferences[key] = value / total
            }
        }
        
        return preferences
    }
    
    private func calculateAverageSatisfaction(_ feedback: [PresetFeedback]) -> Double {
        guard !feedback.isEmpty else { return 0.5 }
        let total = feedback.map { Double($0.satisfactionScore) }.reduce(0, +)
        return total / Double(feedback.count)
    }
    
    private func analyzeEmotionTendencies(_ feedback: [PresetFeedback]) -> [String: Double] {
        var emotionCounts: [String: Int] = [:]
        
        for item in feedback {
            if let emotion = item.contextEmotion {
                emotionCounts[emotion, default: 0] += 1
            }
        }
        
        let total = Double(emotionCounts.values.reduce(0, +))
        var tendencies: [String: Double] = [:]
        
        for (emotion, count) in emotionCounts {
            tendencies[emotion] = Double(count) / total
        }
        
        return tendencies
    }
    
    private func getPreferredSoundTypes(for category: TimeCategory) -> [String] {
        switch category {
        case .earlyMorning:
            return ["birds_chirping", "gentle_alarm", "morning_meditation"]
        case .morning:
            return ["upbeat_nature", "light_piano", "energizing_sounds"]
        case .noon:
            return ["focus_sounds", "white_noise", "productive_ambience"]
        case .afternoon:
            return ["calm_instrumental", "nature_mix", "concentration_sounds"]
        case .evening:
            return ["relaxing_music", "sunset_sounds", "wind_chimes"]
        case .night:
            return ["sleep_sounds", "ocean_waves", "deep_meditation"]
        }
    }
    
    private func calculateSleepQualityScore(sleepData: [SleepData]) -> Double {
        guard !sleepData.isEmpty else { return 0 }
        
        var totalScore = 0.0
        
        for data in sleepData {
            var score = 0.0
            
            // 수면 시간 점수 (7-9시간이 최적)
            if data.duration >= 7 && data.duration <= 9 {
                score += 0.4
            } else if data.duration >= 6 && data.duration <= 10 {
                score += 0.2
            }
            
            // 수면 효율성 점수
            score += min(data.efficiency * 0.3, 0.3)
            
            // 깊은 수면 비율 점수
            score += min(data.deepSleepRatio * 0.3, 0.3)
            
            totalScore += score
        }
        
        return totalScore / Double(sleepData.count)
    }
    
    private func analyzeSleepPatterns(sleepData: [SleepData]) -> [SleepPattern] {
        var patterns: [SleepPattern] = []
        
        // 평균 취침 시간 계산
        let avgBedtime = sleepData.map { $0.bedtime }.reduce(0, +) / Double(sleepData.count)
        
        // 일관성 분석
        let bedtimeVariance = sleepData.map { pow($0.bedtime - avgBedtime, 2) }.reduce(0, +) / Double(sleepData.count)
        let consistency = 1.0 - min(sqrt(bedtimeVariance) / 2.0, 1.0)
        
        patterns.append(SleepPattern(
            type: .consistency,
            value: consistency,
            description: consistency > 0.7 ? "일정한 수면 패턴" : "불규칙한 수면 패턴"
        ))
        
        // 수면 시간 추세
        if sleepData.count >= 7 {
            let recentAvg = sleepData.suffix(3).map { $0.duration }.reduce(0, +) / 3.0
            let overallAvg = sleepData.map { $0.duration }.reduce(0, +) / Double(sleepData.count)
            
            if recentAvg > overallAvg + 0.5 {
                patterns.append(SleepPattern(
                    type: .trend,
                    value: 1.0,
                    description: "수면 시간 증가 추세"
                ))
            } else if recentAvg < overallAvg - 0.5 {
                patterns.append(SleepPattern(
                    type: .trend,
                    value: -1.0,
                    description: "수면 시간 감소 추세"
                ))
            }
        }
        
        return patterns
    }
    
    private func generateSleepAdvice(
        avgDuration: Double,
        qualityScore: Double,
        patterns: [SleepPattern],
        emotion: String?
    ) async throws -> String {
        
        var prompt = """
        사용자 수면 분석:
        - 평균 수면 시간: \(String(format: "%.1f", avgDuration))시간
        - 수면 품질 점수: \(Int(qualityScore * 100))점
        
        패턴:
        \(patterns.map { "- \($0.description)" }.joined(separator: "\n"))
        
        """
        
        if let emotion = emotion {
            prompt += "\n현재 감정 상태: \(emotion)\n"
        }
        
        prompt += """
        
        위 정보를 바탕으로 수면 개선을 위한 구체적인 조언을 150자 이내로 제공해주세요.
        실천 가능한 방법을 포함해주세요.
        """
        
        let response = try await llmRouter.send(
            task: .generalChat(message: prompt, history: [])
        )
        
        return response.content
    }
    
    private func recommendSleepSounds(patterns: [SleepPattern]) async -> [String] {
        var recommendations: [String] = []
        
        // 패턴에 따른 추천
        for pattern in patterns {
            switch pattern.type {
            case .consistency:
                if pattern.value < 0.5 {
                    recommendations.append("sleep_meditation")
                    recommendations.append("delta_waves")
                }
            case .trend:
                if pattern.value < 0 {
                    recommendations.append("deep_sleep_inducer")
                    recommendations.append("rain_thunder")
                }
            default:
                break
            }
        }
        
        // 기본 추천 추가
        if recommendations.isEmpty {
            recommendations = ["ocean_waves", "white_noise", "nature_night"]
        }
        
        return Array(Set(recommendations)).prefix(3).map { $0 }
    }
}

// MARK: - Supporting Types

public struct SoundRecommendation {
    public let soundId: String
    public let confidence: Double
    public let reason: String
    public let alternatives: [SoundCandidate]
}

public struct SoundCandidate {
    public let id: String
    public let score: Double
    public let reason: String
}

public struct EmotionAdvice {
    public let content: String
    public let emotion: String
    public let intensity: Double
    public let timestamp: Date
}

public struct SleepAnalysis {
    public let averageDuration: Double
    public let qualityScore: Double
    public let patterns: [SleepPattern]
    public let advice: String
    public let recommendedSounds: [String]
}

public struct SleepData {
    public let date: Date
    public let bedtime: Double // 24시간 형식 (예: 22.5 = 오후 10:30)
    public let duration: Double // 시간
    public let efficiency: Double // 0-1
    public let deepSleepRatio: Double // 0-1
}

public struct SleepPattern {
    public let type: PatternType
    public let value: Double
    public let description: String
    
    public enum PatternType {
        case consistency
        case trend
        case quality
        case timing
    }
}

// UserProfile is defined in Models.swift

public struct TimeContext {
    public let currentTime: Date
    public let dayOfWeek: Int
    public let isHoliday: Bool
}

public struct TimePreference {
    public let category: TimeCategory
    public let preferredSoundTypes: [String]
}

public enum TimeCategory {
    case earlyMorning
    case morning
    case noon
    case afternoon
    case evening
    case night
}

public struct RecommendationUserContext {
    public let currentTime: Date
    public let batteryLevel: Float
    public let headphonesConnected: Bool
    public let locationContext: String?
}
