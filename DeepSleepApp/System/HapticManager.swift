import UIKit
import CoreHaptics

/// 앱 전체에서 사용할 수 있는 햅틱 피드백 시스템
class HapticManager {
    static let shared = HapticManager()
    
    private var hapticEngine: CHHapticEngine?
    private var isHapticAvailable: Bool = false
    
    private init() {
        setupHapticEngine()
    }
    
    // MARK: - Setup
    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            UnifiedLogger.shared.info("Haptic feedback not supported on this device", category: .system)
            return
        }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            isHapticAvailable = true
            
            hapticEngine?.stoppedHandler = { [weak self] reason in
                UnifiedLogger.shared.info("Haptic engine stopped: \(reason)", category: .system)
                self?.restartHapticEngine()
            }
            
            hapticEngine?.resetHandler = { [weak self] in
                UnifiedLogger.shared.info("Haptic engine reset", category: .system)
                self?.restartHapticEngine()
            }
            
            UnifiedLogger.shared.info("Haptic engine initialized successfully", category: .system)
        } catch {
            UnifiedLogger.shared.error("Failed to initialize haptic engine: \(error)", category: .system)
            isHapticAvailable = false
        }
    }
    
    private func restartHapticEngine() {
        do {
            try hapticEngine?.start()
            UnifiedLogger.shared.info("Haptic engine restarted", category: .system)
        } catch {
            UnifiedLogger.shared.error("Failed to restart haptic engine: \(error)", category: .system)
        }
    }
    
    // MARK: - Simple Haptic Feedback
    
    /// 가벼운 햅틱 피드백 (버튼 탭 등)
    func lightImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        UnifiedLogger.shared.debug("Light haptic feedback triggered", category: .system)
    }
    
    /// 중간 햅틱 피드백 (선택, 토글 등)
    func mediumImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        UnifiedLogger.shared.debug("Medium haptic feedback triggered", category: .system)
    }
    
    /// 강한 햅틱 피드백 (중요한 액션)
    func heavyImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        UnifiedLogger.shared.debug("Heavy haptic feedback triggered", category: .system)
    }
    
    /// 성공 햅틱 피드백
    func success() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
        UnifiedLogger.shared.debug("Success haptic feedback triggered", category: .system)
    }
    
    /// 경고 햅틱 피드백
    func warning() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
        UnifiedLogger.shared.debug("Warning haptic feedback triggered", category: .system)
    }
    
    /// 에러 햅틱 피드백
    func error() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
        UnifiedLogger.shared.debug("Error haptic feedback triggered", category: .system)
    }
    
    /// 선택 햅틱 피드백
    func selection() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
        UnifiedLogger.shared.debug("Selection haptic feedback triggered", category: .system)
    }
    
    // MARK: - Advanced Haptic Patterns
    
    /// 커스텀 햅틱 패턴 재생
    func playCustomPattern(_ pattern: HapticPattern) {
        guard isHapticAvailable, let engine = hapticEngine else {
            // 햅틱이 지원되지 않는 경우 기본 피드백으로 대체
            mediumImpact()
            return
        }
        
        do {
            let hapticPattern = try createCHHapticPattern(from: pattern)
            let player = try engine.makePlayer(with: hapticPattern)
            try player.start(atTime: 0)
            
            UnifiedLogger.shared.debug("Custom haptic pattern played: \(pattern.name)", category: .system)
        } catch {
            UnifiedLogger.shared.error("Failed to play custom haptic pattern: \(error)", category: .system)
            // 실패 시 기본 피드백으로 대체
            mediumImpact()
        }
    }
    
    /// 감정에 따른 햅틱 피드백
    func playEmotionFeedback(for emotion: String) {
        switch emotion.lowercased() {
        case "행복", "기쁨":
            playCustomPattern(.joy)
        case "슬픔", "우울":
            playCustomPattern(.sadness)
        case "불안", "걱정":
            playCustomPattern(.anxiety)
        case "평온", "차분":
            playCustomPattern(.calm)
        case "스트레스":
            playCustomPattern(.stress)
        default:
            mediumImpact()
        }
    }
    
    /// 프리셋 적용 시 햅틱 피드백
    func playPresetAppliedFeedback() {
        playCustomPattern(.presetApplied)
    }
    
    /// 타이머 시작/종료 햅틱 피드백
    func playTimerFeedback(isStart: Bool) {
        if isStart {
            playCustomPattern(.timerStart)
        } else {
            playCustomPattern(.timerEnd)
        }
    }
    
    // MARK: - Pattern Creation
    private func createCHHapticPattern(from pattern: HapticPattern) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        
        for element in pattern.elements {
            let hapticEvent = CHHapticEvent(
                eventType: element.type == .impact ? .hapticTransient : .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: element.intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: element.sharpness)
                ],
                relativeTime: element.time,
                duration: element.duration
            )
            events.append(hapticEvent)
        }
        
        return try CHHapticPattern(events: events, parameters: [])
    }
}

// MARK: - HapticPattern
struct HapticPattern {
    let name: String
    let elements: [HapticElement]
    
    struct HapticElement {
        let type: HapticType
        let intensity: Float
        let sharpness: Float
        let time: TimeInterval
        let duration: TimeInterval
        
        enum HapticType {
            case impact
            case continuous
        }
    }
    
    // MARK: - Predefined Patterns
    static let joy = HapticPattern(
        name: "Joy",
        elements: [
            HapticElement(type: .impact, intensity: 0.7, sharpness: 0.8, time: 0.0, duration: 0.1),
            HapticElement(type: .impact, intensity: 0.5, sharpness: 0.6, time: 0.15, duration: 0.1),
            HapticElement(type: .impact, intensity: 0.8, sharpness: 0.9, time: 0.3, duration: 0.1)
        ]
    )
    
    static let sadness = HapticPattern(
        name: "Sadness",
        elements: [
            HapticElement(type: .continuous, intensity: 0.3, sharpness: 0.2, time: 0.0, duration: 0.8)
        ]
    )
    
    static let anxiety = HapticPattern(
        name: "Anxiety",
        elements: [
            HapticElement(type: .impact, intensity: 0.6, sharpness: 0.9, time: 0.0, duration: 0.05),
            HapticElement(type: .impact, intensity: 0.4, sharpness: 0.7, time: 0.1, duration: 0.05),
            HapticElement(type: .impact, intensity: 0.7, sharpness: 0.8, time: 0.2, duration: 0.05),
            HapticElement(type: .impact, intensity: 0.3, sharpness: 0.6, time: 0.35, duration: 0.05)
        ]
    )
    
    static let calm = HapticPattern(
        name: "Calm",
        elements: [
            HapticElement(type: .continuous, intensity: 0.2, sharpness: 0.1, time: 0.0, duration: 1.0)
        ]
    )
    
    static let stress = HapticPattern(
        name: "Stress",
        elements: [
            HapticElement(type: .impact, intensity: 0.9, sharpness: 1.0, time: 0.0, duration: 0.1),
            HapticElement(type: .impact, intensity: 0.8, sharpness: 0.9, time: 0.15, duration: 0.1)
        ]
    )
    
    static let presetApplied = HapticPattern(
        name: "PresetApplied",
        elements: [
            HapticElement(type: .impact, intensity: 0.6, sharpness: 0.7, time: 0.0, duration: 0.1),
            HapticElement(type: .continuous, intensity: 0.3, sharpness: 0.4, time: 0.15, duration: 0.3)
        ]
    )
    
    static let timerStart = HapticPattern(
        name: "TimerStart",
        elements: [
            HapticElement(type: .impact, intensity: 0.7, sharpness: 0.8, time: 0.0, duration: 0.1),
            HapticElement(type: .impact, intensity: 0.5, sharpness: 0.6, time: 0.2, duration: 0.1),
            HapticElement(type: .impact, intensity: 0.8, sharpness: 0.9, time: 0.4, duration: 0.1)
        ]
    )
    
    static let timerEnd = HapticPattern(
        name: "TimerEnd",
        elements: [
            HapticElement(type: .impact, intensity: 0.8, sharpness: 0.9, time: 0.0, duration: 0.1),
            HapticElement(type: .continuous, intensity: 0.4, sharpness: 0.5, time: 0.15, duration: 0.5)
        ]
    )
}

// MARK: - Global Functions (for backward compatibility)
/// CHHapticPattern 타입 별칭 (CompilerFixStubs.swift 호환성)
typealias CHHapticPattern = CoreHaptics.CHHapticPattern

// MARK: - UIViewController Extension
extension UIViewController {
    /// 뷰 컨트롤러에서 간편하게 햅틱 피드백 사용
    func triggerHapticFeedback(_ type: HapticFeedbackType) {
        switch type {
        case .light:
            HapticManager.shared.lightImpact()
        case .medium:
            HapticManager.shared.mediumImpact()
        case .heavy:
            HapticManager.shared.heavyImpact()
        case .success:
            HapticManager.shared.success()
        case .warning:
            HapticManager.shared.warning()
        case .error:
            HapticManager.shared.error()
        case .selection:
            HapticManager.shared.selection()
        }
    }
}

enum HapticFeedbackType {
    case light, medium, heavy
    case success, warning, error
    case selection
} 