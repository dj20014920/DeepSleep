import Foundation
import UIKit
import AVFoundation
import Accelerate
import SoundAnalysis

/// 🎼 사운드 조화 분석 전담 클래스
/// 음향학적, 감정적, 심리적 조화를 종합 분석하여 최적의 사운드 조합을 제안
@available(iOS 17.0, *)
class SoundHarmonyAnalyzer {
    
    // MARK: - Singleton
    static let shared = SoundHarmonyAnalyzer()
    private init() {}
    
    // MARK: - Properties
    private let audioEngine = AVAudioEngine()
    private var analyzers: [String: AudioAnalyzer] = [:]
    
    // MARK: - Data Structures for Analysis Results
    
    /// 사운드의 핵심 음향 특성을 나타냅니다.
    struct SoundFeatures {
        let pitch: [CGFloat]
        let volume: [CGFloat]
        let complexity: CGFloat
    }
    
    /// 두 사운드 간의 조화 분석 결과를 담습니다.
    struct HarmonyAnalysisResult {
        let harmonicity: CGFloat
        let dissonance: CGFloat
        let rhythmSync: CGFloat
        let combinedScore: CGFloat
    }
    
    /// 여러 사운드 파일 간의 종합적인 조화도 점수입니다.
    struct OverallHarmonyScore {
        let average: CGFloat
        let max: CGFloat
        let min: CGFloat
        let deviation: CGFloat
    }
    
    // MARK: - Data Models
    
    /// 🎯 종합 조화 분석 결과
    struct HarmonyAnalysis {
        let overallScore: Float          // 전체 조화 점수 (0-100)
        let frequencyMasking: Float      // 주파수 마스킹 점수
        let rhythmConflict: Float        // 리듬 충돌 점수
        let emotionalHarmony: Float      // 감정적 조화 점수
        let dynamicRange: Float          // 다이나믹 레인지 점수
        let lengthMatching: Float        // 길이 일치 점수
        let temporalFitness: Float       // 시간적 적합성 점수
        
        let conflicts: [HarmonyConflict]
        let suggestions: [ImprovementSuggestion]
        let confidence: Float            // 분석 신뢰도
    }
    
    /// ⚠️ 조화 충돌 정보
    struct HarmonyConflict {
        let type: ConflictType
        let severity: Float             // 심각도 (0.0 ~ 1.0)
        let affectedSounds: [String]    // 영향받는 음원들
        let description: String         // 문제 설명
        let recommendation: String      // 해결 방법
    }
    
    enum ConflictType: String, CaseIterable {
        case frequencyMasking = "주파수 마스킹"
        case rhythmConflict = "리듬 충돌"
        case emotionalDissonance = "감정적 부조화"
        case dynamicImbalance = "다이나믹 불균형"
        case lengthMismatch = "길이 불일치"
        case temporalInappropriateness = "시간적 부적합"
        
        var emoji: String {
            switch self {
            case .frequencyMasking: return "🎵"
            case .rhythmConflict: return "🥁"
            case .emotionalDissonance: return "😰"
            case .dynamicImbalance: return "📊"
            case .lengthMismatch: return "⏱️"
            case .temporalInappropriateness: return "🕐"
            }
        }
    }
    
    /// 🎭 로컬 감정 프로필 (주관적 특성)
    private struct LocalEmotionalProfile {
        let calmness: Float
        let energy: Float
        let positivity: Float
        let focus: Float
    }
    
    // MARK: - 개별 조화 지표 계산 메서드
    
    /// 🎵 주파수 마스킹 점수 계산
    func calculateFrequencyMaskingScore(
        _ combination: [(soundId: String, version: String, volume: Float)]
    ) async -> Float {
        
        print("🎵 [HarmonyAnalyzer] 주파수 마스킹 분석 시작...")
        
        // 각 음원의 주파수 스펙트럼 분석
        var spectrumOverlaps: [(String, String, Float)] = []
        
        for i in 0..<combination.count {
            for j in (i+1)..<combination.count {
                let sound1 = combination[i]
                let sound2 = combination[j]
                
                let overlap = await calculateSpectralOverlap(sound1, sound2)
                spectrumOverlaps.append((sound1.soundId, sound2.soundId, overlap))
            }
        }
        
        // 주파수 마스킹 심각도 계산
        let totalOverlap = spectrumOverlaps.reduce(0) { $0 + $1.2 }
        let normalizedOverlap = totalOverlap / Float(spectrumOverlaps.count)
        
        // 점수 계산 (겹침이 적을수록 높은 점수)
        let score = max(0, 100 - (normalizedOverlap * 100))
        
        print("📊 [HarmonyAnalyzer] 주파수 마스킹 점수: \(score)")
        return score
    }
    
    /// 🥁 리듬 충돌 점수 계산
    func calculateRhythmConflictScore(
        _ combination: [(soundId: String, version: String, volume: Float)]
    ) async -> Float {
        
        print("🥁 [HarmonyAnalyzer] 리듬 충돌 분석 시작...")
        
        // 각 음원의 리듬 패턴 분석
        var rhythmPatterns: [String: [Float]] = [:]
        
        for sound in combination {
            rhythmPatterns[sound.soundId] = await extractRhythmPattern(sound)
        }
        
        // 리듬 패턴 간 충돌 계산
        var conflictScores: [Float] = []
        
        let rhythmKeys = Array(rhythmPatterns.keys)
        for i in 0..<rhythmKeys.count {
            for j in (i+1)..<rhythmKeys.count {
                if let pattern1 = rhythmPatterns[rhythmKeys[i]],
                   let pattern2 = rhythmPatterns[rhythmKeys[j]] {
                    let conflict = calculateRhythmConflict(pattern1, pattern2)
                    conflictScores.append(conflict)
                }
            }
        }
        
        let avgConflict = conflictScores.isEmpty ? 0 : conflictScores.reduce(0, +) / Float(conflictScores.count)
        let score = max(0, 100 - (avgConflict * 100))
        
        print("📊 [HarmonyAnalyzer] 리듬 충돌 점수: \(score)")
        return score
    }
    
    /// 😊 감정적 조화 점수 계산
    func calculateEmotionalHarmonyScore(
        _ combination: [(soundId: String, version: String, volume: Float)]
    ) async -> Float {
        
        print("😊 [HarmonyAnalyzer] 감정적 조화 분석 시작...")
        
        // 각 음원의 감정적 특성 분석
        var emotionalProfiles: [String: LocalEmotionalProfile] = [:]
        
        for sound in combination {
            emotionalProfiles[sound.soundId] = await analyzeEmotionalProfile(sound)
        }
        
        // 감정적 일관성 계산
        let profiles = Array(emotionalProfiles.values)
        guard profiles.count > 1 else { return 85.0 }
        
        let baseProfile = profiles[0]
        var harmonyScores: [Float] = []
        
        for i in 1..<profiles.count {
            let harmony = calculateEmotionalHarmony(baseProfile, profiles[i])
            harmonyScores.append(harmony)
        }
        
        let avgHarmony = harmonyScores.reduce(0, +) / Float(harmonyScores.count)
        let score = avgHarmony * 100
        
        print("📊 [HarmonyAnalyzer] 감정적 조화 점수: \(score)")
        return score
    }
    
    /// 📊 다이나믹 레인지 점수 계산
    func calculateDynamicRangeScore(
        _ combination: [(soundId: String, version: String, volume: Float)]
    ) async -> Float {
        
        print("📊 [HarmonyAnalyzer] 다이나믹 레인지 분석 시작...")
        
        // 각 음원의 볼륨 레벨 및 다이나믹 레인지 분석
        var volumeLevels: [Float] = []
        var dynamicRanges: [Float] = []
        
        for sound in combination {
            let level = sound.volume
            let dynamicRange = await calculateDynamicRange(sound)
            
            volumeLevels.append(level)
            dynamicRanges.append(dynamicRange)
        }
        
        // 볼륨 밸런스 계산
        let volumeVariance = calculateVariance(volumeLevels)
        let balanceScore = max(0, 1.0 - volumeVariance)
        
        // 다이나믹 레인지 호환성 계산
        let rangeVariance = calculateVariance(dynamicRanges)
        let rangeScore = max(0, 1.0 - rangeVariance)
        
        let score = (balanceScore + rangeScore) / 2.0 * 100
        
        print("📊 [HarmonyAnalyzer] 다이나믹 레인지 점수: \(score)")
        return score
    }
    
    /// ⏱️ 길이 일치 점수 계산
    func calculateLengthMatchingScore(
        _ combination: [(soundId: String, version: String, volume: Float)]
    ) async -> Float {
        
        print("⏱️ [HarmonyAnalyzer] 길이 일치 분석 시작...")
        
        // 각 음원의 길이 정보 가져오기
        var durations: [Float] = []
        
        for sound in combination {
            let duration = await getSoundDuration(sound)
            durations.append(duration)
        }
        
        guard durations.count > 1 else { return 90.0 }
        
        // 길이 차이 계산
        let maxDuration = durations.max() ?? 0
        let minDuration = durations.min() ?? 0
        
        let lengthVariance = maxDuration > 0 ? (maxDuration - minDuration) / maxDuration : 0
        let score = max(0, (1.0 - lengthVariance) * 100)
        
        print("📊 [HarmonyAnalyzer] 길이 일치 점수: \(score)")
        return score
    }
    
    /// 🕐 시간적 적합성 점수 계산
    func calculateTemporalFitnessScore(
        _ combination: [(soundId: String, version: String, volume: Float)]
    ) async -> Float {
        
        print("🕐 [HarmonyAnalyzer] 시간적 적합성 분석 시작...")
        
        let currentHour = Calendar.current.component(.hour, from: Date())
        
        // 각 음원의 시간대별 적합성 점수
        var fitnessScores: [Float] = []
        
        for sound in combination {
            let fitness = calculateTimeOfDayFitness(sound.soundId, hour: currentHour)
            fitnessScores.append(fitness)
        }
        
        let avgFitness = fitnessScores.reduce(0, +) / Float(fitnessScores.count)
        let score = avgFitness * 100
        
        print("📊 [HarmonyAnalyzer] 시간적 적합성 점수: \(score)")
        return score
    }
    
    // MARK: - 종합 조화 분석
    
    /// 🎯 전체 조화도 분석
    func analyzeHarmony(
        for combination: [(soundId: String, version: String, volume: Float)]
    ) async -> HarmonyAnalysis {
        
        print("🎯 [HarmonyAnalyzer] 종합 조화도 분석 시작...")
        
        // 각 차원별 점수 계산
        async let frequencyScore = calculateFrequencyMaskingScore(combination)
        async let rhythmScore = calculateRhythmConflictScore(combination)
        async let emotionalScore = calculateEmotionalHarmonyScore(combination)
        async let dynamicScore = calculateDynamicRangeScore(combination)
        async let lengthScore = calculateLengthMatchingScore(combination)
        async let temporalScore = calculateTemporalFitnessScore(combination)
        
        let scores = await [
            frequencyScore, rhythmScore, emotionalScore,
            dynamicScore, lengthScore, temporalScore
        ]
        
        // 개인화된 가중치 적용
        let weights = await getPersonalizedWeights()
        let weightedSum = zip(scores, weights.toArray()).map { $0 * $1 }.reduce(0, +)
        let overallScore = min(max(weightedSum, 0), 100)
        
        // 충돌 및 제안 생성
        let conflicts = await identifyConflicts(combination, scores: scores)
        let suggestions = await generateSuggestions(combination, conflicts: conflicts)
        
        let analysis = HarmonyAnalysis(
            overallScore: overallScore,
            frequencyMasking: await frequencyScore,
            rhythmConflict: await rhythmScore,
            emotionalHarmony: await emotionalScore,
            dynamicRange: await dynamicScore,
            lengthMatching: await lengthScore,
            temporalFitness: await temporalScore,
            conflicts: conflicts,
            suggestions: suggestions,
            confidence: calculateConfidence(scores)
        )
        
        print("✅ [HarmonyAnalyzer] 종합 분석 완료 - 전체 점수: \(overallScore)")
        return analysis
    }
    
    // MARK: - Helper Methods
    
    private func calculateSpectralOverlap(
        _ sound1: (soundId: String, version: String, volume: Float),
        _ sound2: (soundId: String, version: String, volume: Float)
    ) async -> Float {
        
        // 음원별 주파수 특성 (실제로는 FFT 분석 결과)
        let frequencyProfiles: [String: [Float]] = [
            "wave": [0.8, 0.3, 0.1, 0.05, 0.02],      // 저주파 위주
            "bird": [0.1, 0.2, 0.6, 0.8, 0.4],       // 중고주파 위주
            "rain": [0.6, 0.7, 0.5, 0.3, 0.2],       // 중간 주파수
            "fire": [0.4, 0.5, 0.3, 0.2, 0.1],       // 넓은 분포
            "thunder": [0.9, 0.6, 0.2, 0.1, 0.05],   // 저주파 집중
            "forest": [0.3, 0.4, 0.5, 0.6, 0.3],     // 고른 분포
            "space": [0.2, 0.3, 0.4, 0.5, 0.6],      // 고주파 위주
            "night": [0.5, 0.4, 0.3, 0.2, 0.1]       // 중저주파
        ]
        
        let profile1 = frequencyProfiles[sound1.soundId] ?? [0.2, 0.2, 0.2, 0.2, 0.2]
        let profile2 = frequencyProfiles[sound2.soundId] ?? [0.2, 0.2, 0.2, 0.2, 0.2]
        
        // 스펙트럼 겹침 계산 (코사인 유사도)
        let dotProduct = zip(profile1, profile2).map { $0 * $1 }.reduce(0, +)
        let magnitude1 = sqrt(profile1.map { $0 * $0 }.reduce(0, +))
        let magnitude2 = sqrt(profile2.map { $0 * $0 }.reduce(0, +))
        
        let similarity = dotProduct / (magnitude1 * magnitude2)
        
        // 볼륨 가중치 적용
        let volumeWeight = (sound1.volume + sound2.volume) / 2.0
        return similarity * volumeWeight
    }
    
    private func extractRhythmPattern(
        _ sound: (soundId: String, version: String, volume: Float)
    ) async -> [Float] {
        
        // 음원별 리듬 패턴 (실제로는 오디오 분석 결과)
        let rhythmPatterns: [String: [Float]] = [
            "wave": [0.8, 0.9, 0.8, 0.7, 0.8, 0.9, 0.8, 0.7],      // 규칙적인 파도
            "bird": [0.2, 0.8, 0.1, 0.6, 0.3, 0.9, 0.2, 0.5],      // 불규칙한 새소리
            "rain": [0.7, 0.6, 0.8, 0.7, 0.6, 0.8, 0.7, 0.6],      // 일정한 비
            "fire": [0.5, 0.3, 0.6, 0.4, 0.7, 0.2, 0.5, 0.3],      // 불규칙한 불꽃
            "thunder": [0.1, 0.1, 0.9, 0.1, 0.1, 0.1, 0.8, 0.1],   // 간헐적 천둥
            "forest": [0.4, 0.5, 0.3, 0.6, 0.4, 0.5, 0.3, 0.6],    // 자연스러운 패턴
            "space": [0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3],     // 일정한 우주음
            "night": [0.6, 0.5, 0.6, 0.5, 0.6, 0.5, 0.6, 0.5]      // 잔잔한 밤
        ]
        
        return rhythmPatterns[sound.soundId] ?? [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5]
    }
    
    private func calculateRhythmConflict(_ pattern1: [Float], _ pattern2: [Float]) -> Float {
        guard pattern1.count == pattern2.count else { return 0.5 }
        
        // 패턴 간 상관관계 계산
        let correlation = zip(pattern1, pattern2).map { abs($0 - $1) }.reduce(0, +) / Float(pattern1.count)
        
        // 충돌 정도 반환 (차이가 클수록 높은 충돌)
        return min(correlation, 1.0)
    }
    
    private func analyzeEmotionalProfile(
        _ sound: (soundId: String, version: String, volume: Float)
    ) async -> LocalEmotionalProfile {
        
        let emotionalProfiles: [String: LocalEmotionalProfile] = [
            "wave": LocalEmotionalProfile(calmness: 0.9, energy: 0.3, positivity: 0.7, focus: 0.8),
            "bird": LocalEmotionalProfile(calmness: 0.6, energy: 0.7, positivity: 0.9, focus: 0.5),
            "rain": LocalEmotionalProfile(calmness: 0.8, energy: 0.2, positivity: 0.6, focus: 0.9),
            "fire": LocalEmotionalProfile(calmness: 0.7, energy: 0.6, positivity: 0.8, focus: 0.6),
            "thunder": LocalEmotionalProfile(calmness: 0.3, energy: 0.9, positivity: 0.4, focus: 0.3),
            "forest": LocalEmotionalProfile(calmness: 0.8, energy: 0.4, positivity: 0.8, focus: 0.7),
            "space": LocalEmotionalProfile(calmness: 0.9, energy: 0.1, positivity: 0.5, focus: 0.9),
            "night": LocalEmotionalProfile(calmness: 0.9, energy: 0.1, positivity: 0.6, focus: 0.8)
        ]
        
        return emotionalProfiles[sound.soundId] ?? LocalEmotionalProfile(calmness: 0.5, energy: 0.5, positivity: 0.5, focus: 0.5)
    }
    
    private func calculateEmotionalHarmony(_ profile1: LocalEmotionalProfile, _ profile2: LocalEmotionalProfile) -> Float {
        // 감정적 특성 간 유사도 계산
        let calmnessHarmony = 1.0 - abs(profile1.calmness - profile2.calmness)
        let energyHarmony = 1.0 - abs(profile1.energy - profile2.energy)
        let positivityHarmony = 1.0 - abs(profile1.positivity - profile2.positivity)
        let focusHarmony = 1.0 - abs(profile1.focus - profile2.focus)
        
        return (calmnessHarmony + energyHarmony + positivityHarmony + focusHarmony) / 4.0
    }
    
    private func calculateDynamicRange(
        _ sound: (soundId: String, version: String, volume: Float)
    ) async -> Float {
        
        // 음원별 다이나믹 레인지 (실제로는 오디오 분석 결과)
        let dynamicRanges: [String: Float] = [
            "wave": 0.6,      // 중간 다이나믹 레인지
            "bird": 0.8,      // 높은 다이나믹 레인지
            "rain": 0.4,      // 낮은 다이나믹 레인지
            "fire": 0.7,      // 높은 다이나믹 레인지
            "thunder": 0.9,   // 매우 높은 다이나믹 레인지
            "forest": 0.5,    // 중간 다이나믹 레인지
            "space": 0.2,     // 낮은 다이나믹 레인지
            "night": 0.3      // 낮은 다이나믹 레인지
        ]
        
        return dynamicRanges[sound.soundId] ?? 0.5
    }
    
    private func getSoundDuration(
        _ sound: (soundId: String, version: String, volume: Float)
    ) async -> Float {
        
        // 음원별 지속 시간 (초)
        let durations: [String: Float] = [
            "wave": 300.0,    // 5분
            "bird": 180.0,    // 3분
            "rain": 600.0,    // 10분
            "fire": 240.0,    // 4분
            "thunder": 120.0, // 2분
            "forest": 480.0,  // 8분
            "space": 900.0,   // 15분
            "night": 720.0    // 12분
        ]
        
        return durations[sound.soundId] ?? 300.0
    }
    
    private func calculateTimeOfDayFitness(_ soundId: String, hour: Int) -> Float {
        // 시간대별 음원 적합성 매트릭스
        let fitnessMatrix: [String: [Float]] = [
            "wave": [0.3, 0.3, 0.3, 0.3, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.9, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3],
            "bird": [0.2, 0.2, 0.2, 0.2, 0.3, 0.8, 0.9, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2],
            "rain": [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5],
            "fire": [0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.6, 0.8, 0.9, 0.8, 0.6, 0.5, 0.4, 0.4],
            "thunder": [0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.4, 0.5, 0.6, 0.5, 0.4, 0.3, 0.3, 0.3],
            "forest": [0.6, 0.6, 0.6, 0.6, 0.6, 0.7, 0.8, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.3, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.8, 0.7, 0.6, 0.6],
            "space": [0.8, 0.8, 0.8, 0.8, 0.8, 0.6, 0.4, 0.3, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.3, 0.4, 0.6, 0.7, 0.8, 0.8, 0.8],
            "night": [0.9, 0.9, 0.9, 0.9, 0.9, 0.7, 0.5, 0.3, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.3, 0.5, 0.7, 0.8, 0.9, 0.9, 0.9]
        ]
        
        return fitnessMatrix[soundId]?[hour] ?? 0.5
    }
    
    private func calculateVariance(_ values: [Float]) -> Float {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0, +) / Float(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0, +) / Float(values.count)
        
        return sqrt(variance) // 표준편차 반환
    }
    
    private func getPersonalizedWeights() async -> HarmonyWeights {
        if #available(iOS 18.0, *) {
            return await PersonalizedHarmonyLearner.shared.harmonyWeights
        } else {
            return HarmonyWeights.default
        }
    }
    
    private func identifyConflicts(
        _ combination: [(soundId: String, version: String, volume: Float)],
        scores: [Float]
    ) async -> [HarmonyConflict] {
        
        var conflicts: [HarmonyConflict] = []
        
        // 각 점수가 임계값 이하인 경우 충돌로 판단
        let thresholds: [Float] = [60, 65, 70, 75, 70, 65] // 각 차원별 임계값
        let conflictTypes = ConflictType.allCases
        
        for (index, score) in scores.enumerated() {
            if score < thresholds[index] {
                let severity = (thresholds[index] - score) / thresholds[index]
                let conflict = HarmonyConflict(
                    type: conflictTypes[index],
                    severity: severity,
                    affectedSounds: combination.map { $0.soundId },
                    description: generateConflictDescription(conflictTypes[index], severity),
                    recommendation: generateConflictRecommendation(conflictTypes[index])
                )
                conflicts.append(conflict)
            }
        }
        
        return conflicts
    }
    
    private func generateSuggestions(
        _ combination: [(soundId: String, version: String, volume: Float)],
        conflicts: [HarmonyConflict]
    ) async -> [ImprovementSuggestion] {
        
        var suggestions: [ImprovementSuggestion] = []
        
        for conflict in conflicts {
            let suggestion = ImprovementSuggestion(
                id: UUID().uuidString,
                title: "\(conflict.type.emoji) \(conflict.type.rawValue) 개선",
                description: conflict.recommendation,
                improvementScore: Int(conflict.severity * 10),
                confidence: Double(1.0 - conflict.severity),
                type: determineSuggestionType(conflict.type)
            )
            suggestions.append(suggestion)
        }
        
        return suggestions
    }
    
    private func calculateConfidence(_ scores: [Float]) -> Float {
        // 점수들의 일관성을 기반으로 신뢰도 계산
        let mean = scores.reduce(0, +) / Float(scores.count)
        let variance = scores.map { pow($0 - mean, 2) }.reduce(0, +) / Float(scores.count)
        let consistency = max(0, 1.0 - sqrt(variance) / 100.0)
        
        return consistency
    }
    
    private func generateConflictDescription(_ type: ConflictType, _ severity: Float) -> String {
        switch type {
        case .frequencyMasking:
            return severity > 0.7 ? "심각한 주파수 겹침 발생" : "일부 주파수 대역에서 마스킹 현상"
        case .rhythmConflict:
            return severity > 0.7 ? "리듬 패턴이 서로 충돌" : "리듬 패턴 간 약간의 불일치"
        case .emotionalDissonance:
            return severity > 0.7 ? "감정적으로 상반된 음원들" : "감정적 조화에 약간의 문제"
        case .dynamicImbalance:
            return severity > 0.7 ? "볼륨 레벨 불균형 심각" : "볼륨 밸런스 조정 필요"
        case .lengthMismatch:
            return severity > 0.7 ? "음원 길이 차이가 매우 큼" : "음원 길이 약간 불일치"
        case .temporalInappropriateness:
            return severity > 0.7 ? "현재 시간대에 부적합" : "시간대 적합성 다소 부족"
        }
    }
    
    private func generateConflictRecommendation(_ type: ConflictType) -> String {
        switch type {
        case .frequencyMasking:
            return "다른 주파수 대역의 음원으로 교체하거나 볼륨 조정"
        case .rhythmConflict:
            return "비슷한 리듬 패턴의 음원으로 교체"
        case .emotionalDissonance:
            return "감정적으로 일치하는 음원들로 조합 변경"
        case .dynamicImbalance:
            return "볼륨 레벨을 균등하게 조정"
        case .lengthMismatch:
            return "비슷한 길이의 음원들로 조합 구성"
        case .temporalInappropriateness:
            return "현재 시간대에 적합한 음원으로 교체"
        }
    }
    
    private func determineSuggestionType(_ conflictType: ConflictType) -> SuggestionType {
        switch conflictType {
        case .frequencyMasking, .emotionalDissonance, .temporalInappropriateness:
            return .replacement
        case .dynamicImbalance:
            return .volumeAdjustment
        case .rhythmConflict, .lengthMismatch:
            return .combination
        }
    }

    // MARK: - 비공개 헬퍼
    private func updateUIWithAnalysis(_ analysis: (harmonicity: CGFloat, dissonance: CGFloat, rhythmSync: CGFloat, combinedScore: CGFloat)) {
        // UI 업데이트 로직 (예시)
        print("조화도: \(analysis.harmonicity), 불협화음: \(analysis.dissonance), 리듬 동기화: \(analysis.rhythmSync)")
    }

    private func calculateHarmony(file1: URL, file2: URL) -> HarmonyAnalysisResult? {
        // 두 사운드 파일 간의 조화 분석
        guard let features1 = extractFeatures(from: file1),
              let features2 = extractFeatures(from: file2) else {
            return nil
        }
        
        return analyzeHarmony(features1: features1, features2: features2)
    }
    
    private func findIncompatibleSounds(from files: [URL], threshold: CGFloat = 0.3) -> [URL] {
        var harmonyScores: [URL: CGFloat] = [:]

        for (index, file1) in files.enumerated() {
            for file2 in files.dropFirst(index + 1) {
                if let score = calculateHarmony(file1: file1, file2: file2)?.combinedScore {
                    harmonyScores[file1, default: 0] += score
                    harmonyScores[file2, default: 0] += score
                }
            }
        }

        var incompatibleFiles: [URL] = []
        for (file, score) in harmonyScores where score / CGFloat(files.count - 1) < threshold {
            incompatibleFiles.append(file)
        }
        
        return incompatibleFiles
    }
}

/// 🔍 개별 오디오 분석기
class AudioAnalyzer {
    func analyzeSpectrum(_ audioData: Data) -> [Float] {
        // FFT 기반 스펙트럼 분석
        return []
    }
    
    func extractRhythm(_ audioData: Data) -> [Float] {
        // 리듬 패턴 추출
        return []
    }
    
    func calculateDynamicRange(_ audioData: Data) -> Float {
        // 다이나믹 레인지 계산
        return 0.0
    }
}

// MARK: - 확장 유틸리티
@available(iOS 17.0, *)
extension SoundHarmonyAnalyzer {
    
    /// 조화도 점수를 기반으로 한 간단한 평가
    func getHarmonyRating(score: Float) -> (rating: String, color: UIColor, emoji: String) {
        switch score {
        case 0.9...1.0:
            return ("완벽한 조화", .systemGreen, "🎵")
        case 0.8..<0.9:
            return ("매우 좋음", .systemGreen, "✨")
        case 0.7..<0.8:
            return ("좋음", .systemBlue, "👍")
        case 0.6..<0.7:
            return ("보통", .systemYellow, "⚖️")
        case 0.5..<0.6:
            return ("개선 필요", .systemOrange, "⚠️")
        default:
            return ("조정 필요", .systemRed, "🔧")
        }
    }
    
    /// 빠른 충돌 체크 (성능 최적화용)
    func quickConflictCheck(soundIds: [String]) -> Bool {
        // SoundPresetCatalog의 avoidWith 리스트를 기반으로 간단 충돌 체크
        for i in 0..<soundIds.count {
            for j in (i+1)..<soundIds.count {
                let sound1 = soundIds[i]
                let sound2 = soundIds[j]
                if let details = SoundPresetCatalog.soundDetails[sound1],
                   let avoidList = details["avoidWith"] as? [String],
                   avoidList.contains(sound2) {
                    return true // 충돌 발견
                }
            }
        }
        return false
    }
}

// MARK: - Feature Extraction
@available(iOS 17.0, *)
extension SoundHarmonyAnalyzer {
    
    /// 사운드 파일에서 핵심 음향 특성을 추출합니다.
    private func extractFeatures(from fileURL: URL) -> SoundFeatures? {
        // ... 기존 로직 ...
        // todo: 실제 특성 추출 로직 구현 필요
        return SoundFeatures(pitch: [0.1, 0.2], volume: [0.8, 0.7], complexity: 0.5)
    }
}

// MARK: - Harmony Analysis
@available(iOS 17.0, *)
extension SoundHarmonyAnalyzer {

    /// 두 사운드 특성 세트 간의 조화를 분석합니다.
    private func analyzeHarmony(features1: SoundFeatures, features2: SoundFeatures) -> HarmonyAnalysisResult {
        // ... 기존 로직 ...
        // todo: 실제 조화 분석 로직 구현 필요
        return HarmonyAnalysisResult(harmonicity: 0.9, dissonance: 0.1, rhythmSync: 0.8, combinedScore: 0.85)
    }

    /// 주어진 사운드 파일 목록의 전반적인 조화도를 계산합니다.
    public func calculateOverallHarmony(for files: [URL]) -> OverallHarmonyScore {
        guard files.count > 1 else {
            return OverallHarmonyScore(average: 1.0, max: 1.0, min: 1.0, deviation: 0.0)
        }
        
        let allScores = [1.0, 0.9, 0.8] // todo: 실제 점수 계산 로직
        let sum = allScores.reduce(0, +)
        let average = sum / CGFloat(allScores.count)
        
        return OverallHarmonyScore(
            average: average,
            max: allScores.max() ?? 0,
            min: allScores.min() ?? 0,
            deviation: 0.1 // todo: 실제 표준 편차 계산
        )
    }
}
