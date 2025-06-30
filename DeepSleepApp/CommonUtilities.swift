import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// 🔧 공통 유틸리티 클래스 - 중복 함수들을 통합하여 일관성 보장
class CommonUtilities {
    
    // MARK: - Singleton
    static let shared = CommonUtilities()
    private init() {}
    
    // MARK: - 🕐 시간대 관련 통합 함수
    
    /// 통합된 시간대 판단 함수 (모든 중복 함수들을 대체)
    func getCurrentTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        return getTimeOfDay(from: hour)
    }
    
    /// 시간(Int)을 받아 시간대 문자열로 변환
    func getTimeOfDay(from hour: Int) -> String {
        switch hour {
        case 4..<6: return "새벽"
        case 6..<10: return "아침"
        case 10..<12: return "오전"
        case 12..<14: return "점심"
        case 14..<18: return "오후"
        case 18..<21: return "저녁"
        case 21..<24, 0..<4: return "밤"
        default: return "알 수 없음"
        }
    }
    
    /// 현재 사용 시간대 (사용자 친화적)
    func getCurrentTimeOfUse() -> String {
        let timeOfDay = getCurrentTimeOfDay()
        return "\(timeOfDay) 시간"
    }
    
    // MARK: - 🎵 사운드 설명 생성 통합 함수
    
    /// 통합된 사운드 설명 생성 함수
    func generateSoundDescription(
        volumes: [Float], 
        emotion: String, 
        timeOfDay: String? = nil,
        includeVolumes: Bool = false,
        style: DescriptionStyle = .detailed
    ) -> String {
        
        let currentTimeOfDay = timeOfDay ?? getCurrentTimeOfDay()
        let activeSounds = getActiveSounds(from: volumes)
        
        switch style {
        case .simple:
            return generateSimpleDescription(activeSounds: activeSounds, emotion: emotion)
        case .detailed:
            return generateDetailedDescription(
                activeSounds: activeSounds, 
                emotion: emotion, 
                timeOfDay: currentTimeOfDay,
                includeVolumes: includeVolumes
            )
        case .poetic:
            return generatePoeticDescription(
                activeSounds: activeSounds, 
                emotion: emotion, 
                timeOfDay: currentTimeOfDay
            )
        }
    }
    
    enum DescriptionStyle {
        case simple      // 간단한 설명
        case detailed    // 상세한 설명 (기본)
        case poetic      // 시적인 설명
    }
    
    private func getActiveSounds(from volumes: [Float]) -> [(index: Int, name: String, volume: Float)] {
        let soundNames = SoundManager.shared.standardSoundNames
        return volumes.enumerated().compactMap { index, volume in
            guard volume > 0.05, index < soundNames.count else { return nil }
            return (index: index, name: soundNames[index], volume: volume)
        }
    }
    
    private func generateSimpleDescription(activeSounds: [(index: Int, name: String, volume: Float)], emotion: String) -> String {
        if activeSounds.isEmpty {
            return "조용한 상태입니다."
        }
        
        let soundList = activeSounds.map { $0.name }.joined(separator: ", ")
        return "\(emotion) 상태를 위한 \(soundList) 조합"
    }
    
    private func generateDetailedDescription(
        activeSounds: [(index: Int, name: String, volume: Float)], 
        emotion: String, 
        timeOfDay: String,
        includeVolumes: Bool
    ) -> String {
        
        if activeSounds.isEmpty {
            return "\(timeOfDay)의 고요한 순간을 위한 완전한 정적 상태입니다."
        }
        
        var description = "\(timeOfDay)의 \(emotion) 감정을 위해 선별된 사운드 조합:\n\n"
        
        // 볼륨별로 그룹화
        let highVolume = activeSounds.filter { $0.volume > 0.6 }
        let mediumVolume = activeSounds.filter { $0.volume > 0.3 && $0.volume <= 0.6 }
        let lowVolume = activeSounds.filter { $0.volume <= 0.3 }
        
        if !highVolume.isEmpty {
            let names = highVolume.map { includeVolumes ? "\($0.name) (\(Int($0.volume * 100))%)" : $0.name }
            description += "🔊 주요 사운드: \(names.joined(separator: ", "))\n"
        }
        
        if !mediumVolume.isEmpty {
            let names = mediumVolume.map { includeVolumes ? "\($0.name) (\(Int($0.volume * 100))%)" : $0.name }
            description += "🎵 보조 사운드: \(names.joined(separator: ", "))\n"
        }
        
        if !lowVolume.isEmpty {
            let names = lowVolume.map { includeVolumes ? "\($0.name) (\(Int($0.volume * 100))%)" : $0.name }
            description += "🌫️ 배경 사운드: \(names.joined(separator: ", "))\n"
        }
        
        return description.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func generatePoeticDescription(
        activeSounds: [(index: Int, name: String, volume: Float)], 
        emotion: String, 
        timeOfDay: String
    ) -> String {
        
        if activeSounds.isEmpty {
            return poeticEmptyDescription(emotion: emotion, timeOfDay: timeOfDay)
        }
        
        let metaphors = generateSoundMetaphors(activeSounds: activeSounds)
        let emotionAdjective = getEmotionAdjective(emotion: emotion)
        let timePoetry = getTimePoetry(timeOfDay: timeOfDay)
        
        return "\(timePoetry)에 \(emotionAdjective) 마음을 위해 \(metaphors)가 어우러진 특별한 순간을 선사합니다."
    }
    
    private func poeticEmptyDescription(emotion: String, timeOfDay: String) -> String {
        let timePoetry = getTimePoetry(timeOfDay: timeOfDay)
        let emotionAdjective = getEmotionAdjective(emotion: emotion)
        return "\(timePoetry)의 고요한 침묵 속에서 \(emotionAdjective) 마음이 스스로를 찾아가는 순수한 명상의 시간입니다."
    }
    
    private func generateSoundMetaphors(activeSounds: [(index: Int, name: String, volume: Float)]) -> String {
        let metaphorMap: [String: String] = [
            "🐱 고양이": "부드러운 위로",
            "🌪 바람": "자유로운 숨결",
            "🌧 비": "정화의 리듬",
            "🌊 파도": "끝없는 평온",
            "🔥 불타는소리": "따뜻한 열정",
            "🐋 고래": "깊은 명상",
            "🌙 밤": "신비로운 정적",
            "⛈️ 천둥": "웅장한 울림",
            "🌲 숲": "자연의 속삭임",
            "🌬️ 냉각팬": "현대적 안정감"
        ]
        
        let metaphors = activeSounds.compactMap { sound in
            metaphorMap[sound.name] ?? sound.name.replacingOccurrences(of: "🎵 ", with: "")
        }
        
        return metaphors.joined(separator: "과 ")
    }
    
    private func getEmotionAdjective(emotion: String) -> String {
        let emotionMap: [String: String] = [
            "평온": "고요한",
            "스트레스": "지친",
            "불안": "흔들리는",
            "우울": "침울한",
            "기쁨": "밝은",
            "집중": "명료한",
            "수면": "졸린",
            "이완": "느긋한",
            "피로": "무거운",
            "외로움": "그리운"
        ]
        
        return emotionMap[emotion] ?? "특별한"
    }
    
    private func getTimePoetry(timeOfDay: String) -> String {
        let timeMap: [String: String] = [
            "새벽": "희미한 여명",
            "아침": "상쾌한 시작",
            "오전": "활기찬 오전",
            "점심": "따스한 정오",
            "오후": "여유로운 오후",
            "저녁": "황금빛 노을",
            "밤": "깊어가는 밤"
        ]
        
        return timeMap[timeOfDay] ?? "특별한 시간"
    }
    
    // MARK: - 🔄 볼륨 변환 통합 함수
    
    /// 사운드 배열을 볼륨 배열로 변환 (통합)
    func convertSoundsToVolumes(sounds: [(soundId: String, version: String, volume: Float)]) -> [Float] {
        let soundManager = SoundManager.shared
        var volumes = Array(repeating: Float(0.0), count: soundManager.standardSoundNames.count)
        
        for sound in sounds {
            if let index = soundManager.getSoundIndex(for: sound.soundId) {
                volumes[index] = sound.volume
            }
        }
        
        return volumes
    }
    
    /// 사운드 배열을 버전 배열로 변환 (통합)
    func convertSoundsToVersions(sounds: [(soundId: String, version: String, volume: Float)]) -> [Int] {
        let soundManager = SoundManager.shared
        var versions = Array(repeating: 1, count: soundManager.standardSoundNames.count)
        
        for sound in sounds {
            if let index = soundManager.getSoundIndex(for: sound.soundId) {
                versions[index] = Int(sound.version.replacingOccurrences(of: ".", with: "")) ?? 1
            }
        }
        
        return versions
    }
    
    /// 볼륨 배열을 사운드 배열로 역변환
    func convertVolumesToSounds(volumes: [Float], versions: [Int]? = nil) -> [(soundId: String, version: String, volume: Float)] {
        let soundManager = SoundManager.shared
        let soundNames = soundManager.standardSoundNames
        let defaultVersions = versions ?? Array(repeating: 1, count: volumes.count)
        
        return volumes.enumerated().compactMap { index, volume in
            guard volume > 0.05, index < soundNames.count else { return nil }
            
            let soundId = extractSoundId(from: soundNames[index])
            let version = index < defaultVersions.count ? "\(defaultVersions[index]).0" : "1.0"
            
            return (soundId: soundId, version: version, volume: volume)
        }
    }
    
    private func extractSoundId(from displayName: String) -> String {
        // 이모지와 공백 제거하여 사운드 ID 추출
        let cleanName = displayName.replacingOccurrences(of: "🎵 ", with: "")
                                  .replacingOccurrences(of: " ", with: "_")
                                  .lowercased()
        
        // 특수 문자 매핑
        let specialMappings: [String: String] = [
            "고양이": "cat",
            "바람": "wind",
            "비": "rain",
            "파도": "wave",
            "불타는소리": "fire",
            "고래": "whale",
            "밤": "night",
            "천둥": "thunder",
            "숲": "forest",
            "냉각팬": "cooling_fan"
        ]
        
        return specialMappings[cleanName] ?? cleanName
    }
    
    // MARK: - 🎯 감정 분석 통합 함수
    
    /// 텍스트에서 감정 키워드 추출 (통합)
    func extractEmotionKeywords(from text: String) -> [String] {
        let emotionKeywords: [String: [String]] = [
            "스트레스": ["스트레스", "힘들", "지침", "피곤", "압박", "부담", "과로"],
            "불안": ["불안", "걱정", "초조", "긴장", "두려", "무서", "떨림"],
            "우울": ["우울", "슬픔", "처짐", "무기력", "절망", "암울", "침울"],
            "피로": ["피로", "지침", "무력", "탈진", "고갈", "녹초", "기진"],
            "집중": ["집중", "몰입", "공부", "작업", "업무", "사고", "정신"],
            "평온": ["평온", "안정", "차분", "고요", "평화", "조용", "편안"],
            "기쁨": ["기쁨", "행복", "즐거", "신나", "좋아", "활기", "에너지"],
            "외로움": ["외로", "혼자", "고독", "쓸쓸", "그리", "애정", "사랑"]
        ]
        
        let lowercasedText = text.lowercased()
        var detectedEmotions: [String] = []
        
        for (emotion, keywords) in emotionKeywords {
            for keyword in keywords {
                if lowercasedText.contains(keyword) {
                    detectedEmotions.append(emotion)
                    break
                }
            }
        }
        
        return Array(Set(detectedEmotions)) // 중복 제거
    }
    
    /// 가장 강한 감정 키워드 반환
    func getPrimaryEmotion(from text: String) -> String {
        let emotions = extractEmotionKeywords(from: text)
        
        // 우선순위 기반 선택 (더 구체적인 감정을 우선)
        let priorityOrder = ["우울", "불안", "스트레스", "피로", "외로움", "집중", "평온", "기쁨"]
        
        for emotion in priorityOrder {
            if emotions.contains(emotion) {
                return emotion
            }
        }
        
        return emotions.first ?? "평온"
    }
    
    // MARK: - 📊 통계 및 분석 유틸리티
    
    /// 배열의 평균값 계산
    func average<T: FloatingPoint>(_ values: [T]) -> T {
        guard !values.isEmpty else { return T.zero }
        return values.reduce(T.zero, +) / T(values.count)
    }
    
    /// 표준편차 계산
    func standardDeviation(_ values: [Float]) -> Float {
        guard values.count > 1 else { return 0.0 }
        
        let mean = average(values)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        let variance = average(squaredDifferences)
        
        return sqrt(variance)
    }
    
    /// 값을 범위 내로 제한
    func clamp<T: Comparable>(_ value: T, min: T, max: T) -> T {
        return Swift.min(Swift.max(value, min), max)
    }
    
    /// 선형 보간
    func lerp(from: Float, to: Float, factor: Float) -> Float {
        return from + (to - from) * clamp(factor, min: 0.0, max: 1.0)
    }
    
    // MARK: - 🎨 UI 유틸리티
    
    /// 감정에 따른 색상 반환
    func getEmotionColor(emotion: String) -> UIColor {
        let colorMap: [String: UIColor] = [
            "평온": .systemBlue,
            "스트레스": .systemRed,
            "불안": .systemOrange,
            "우울": .systemIndigo,
            "기쁨": .systemYellow,
            "집중": .systemGreen,
            "수면": .systemPurple,
            "이완": .systemTeal,
            "피로": .systemGray,
            "외로움": .systemPink
        ]
        
        return colorMap[emotion] ?? .systemBlue
    }
    
    /// 강도에 따른 투명도 반환
    func getIntensityAlpha(intensity: Float) -> CGFloat {
        return CGFloat(clamp(intensity * 0.8 + 0.2, min: 0.2, max: 1.0))
    }
    
    // MARK: - 🔧 성능 최적화 유틸리티
    
    /// 무거운 작업을 백그라운드에서 실행
    func performHeavyTask<T>(_ task: @escaping () throws -> T, completion: @escaping (Result<T, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try task()
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 디바운스 실행 (연속 호출 방지)
    private var debounceTimers: [String: Timer] = [:]
    
    func debounce(identifier: String, delay: TimeInterval, action: @escaping () -> Void) {
        debounceTimers[identifier]?.invalidate()
        debounceTimers[identifier] = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            action()
            self.debounceTimers.removeValue(forKey: identifier)
        }
    }
    
    /// 메모리 사용량 체크
    func getMemoryUsage() -> (used: Double, total: Double) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            return (used: usedMB, total: Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0)
        }
        
        return (used: 0, total: 0)
    }
    
    /// 🔋 배터리 레벨 확인 (0.0 ~ 1.0)
    static func getCurrentBatteryLevel() -> Float {
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryLevel
        #else
        return 1.0 // 시뮬레이터나 다른 플랫폼에서는 항상 100%로 가정
        #endif
    }
}

// MARK: - Cache Constants
public struct CacheConst {
    public static let keepDays = 30
    public static let recentDaysRaw = 7
}

// MARK: - StoredChatMessage for Compatibility
public struct StoredChatMessage {
    public let id: UUID
    public let text: String
    public let type: MessageType
    public let timestamp: Date
    public let metadata: [String: Any]?
    
    public enum MessageType {
        case user
        case bot
    }
    
    public init(id: UUID = UUID(), text: String, type: MessageType, timestamp: Date = Date(), metadata: [String: Any]? = nil) {
        self.id = id
        self.text = text
        self.type = type
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - Note: Color extensions moved to UIColorExtensions.swift
// Removed duplicate Color extension to avoid circular references 