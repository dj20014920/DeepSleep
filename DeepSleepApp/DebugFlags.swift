import Foundation

/// 전역 디버그 플래그(런타임 토글 가능). 배포 전 반드시 기본값을 false로 유지.
enum DebugFlags {    
    /// 성능 상세 로깅 (DEBUG 전용). Console에 세부 단계별 타이밍 요약을 출력합니다.
    static var performanceVerboseLogging: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "debug_performance_verbose")
        #else
        return false
        #endif
    }

    /// 프리셋 추천 일일 제한 해제(디버깅용). 기본 false. 배포 전/후 모두 기본값은 false 유지.
    static var unlimitedPresetRecommendation: Bool {
        get {
            let key = "debug_unlimited_preset_recommendation"
            #if DEBUG
            // 기본값은 DEBUG에서도 false. 필요 시 설정에서 수동 토글.
            return UserDefaults.standard.bool(forKey: key)
            #else
            // RELEASE 빌드에서는 항상 비활성화(설정값 무시)
            return false
            #endif
        }
        set { UserDefaults.standard.set(newValue, forKey: "debug_unlimited_preset_recommendation") }
    }
    /// 내부 UsageLimitManager 상세 로그 출력 (기본 비활성). DEBUG에서 UserDefaults 토글 가능.
    static var internalUsageVerbose: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "debug_internal_usage_verbose")
        #else
        return false
        #endif
    }
}
