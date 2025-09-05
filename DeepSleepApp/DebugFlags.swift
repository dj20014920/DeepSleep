import Foundation

/// 전역 디버그 플래그(런타임 토글 가능). 배포 전 반드시 기본값을 false로 유지.
enum DebugFlags {
    /// 프리셋 추천 일일 제한 해제(디버깅용). 기본 false.
    static var unlimitedPresetRecommendation: Bool {
        get {
            let key = "debug_unlimited_preset_recommendation"
            #if DEBUG
            // 기본값: 디버그 빌드에서는 true (명시적으로 끌 수 있음)
            if UserDefaults.standard.object(forKey: key) == nil { return true }
            #endif
            return UserDefaults.standard.bool(forKey: key)
        }
        set { UserDefaults.standard.set(newValue, forKey: "debug_unlimited_preset_recommendation") }
    }
}
