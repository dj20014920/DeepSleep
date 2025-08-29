import UIKit

/// 배지/캘린더 그라데이션 애니메이션 공통 스펙 (DRY)
struct GradientAnimationSpec {
    /// 배지에서 사용하는 프레임당 진행 증가량 (PremiumBadgeView와 동일)
    static let badgeIncrementPerFrame: CGFloat = 0.0075
    /// 목표 FPS (디스플레이 기본 60fps 기준)
    static let targetFPS: CGFloat = 60.0
    /// 한 사이클(0→1) 완주 시간(초)
    static var badgeCycleDuration: CFTimeInterval {
        let perSec = badgeIncrementPerFrame * targetFPS
        guard perSec > 0 else { return 2.2 }
        return CFTimeInterval(1.0 / perSec)
    }
}

