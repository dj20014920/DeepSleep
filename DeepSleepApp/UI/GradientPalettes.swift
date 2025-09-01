import UIKit

// 파일명만 다르고, 타입명은 기존 PremiumBadgeView 리팩터링과 동일하게 유지
struct GradientBadgePalette {
    /// 앱 론칭 화면(LaunchViewController)의 색감을 사용한 부드러운 그라데이션 팔레트
    /// - DRY: 구독 배지와 캘린더/할 일의 프리미엄 링이 동일 팔레트를 사용하도록 단일 진입점으로 통합
    static func proColors() -> [UIColor] {
        // LaunchViewController의 배경 그라데이션과 동일한 색상군(알파 포함)
        // Pink(0.6) → Purple(0.5) → Blue(0.4) → Teal(0.3)
        let base: [UIColor] = [
            UIColor.systemPink.withAlphaComponent(0.60),
            UIColor.systemPurple.withAlphaComponent(0.50),
            UIColor.systemBlue.withAlphaComponent(0.40),
            UIColor.systemTeal.withAlphaComponent(0.30)
        ]
        
        // 부드러운 전환을 위해 각 세그먼트별로 다중 스텝 보간(세그먼트 당 6스텝)
        let stepsPerSegment = 6
        var result: [UIColor] = []
        for i in 0..<base.count {
            let c1 = base[i]
            let c2 = base[(i + 1) % base.count]
            for s in 0..<stepsPerSegment { // 0...5
                let t = CGFloat(s) / CGFloat(stepsPerSegment)
                result.append(interpolate(from: c1, to: c2, fraction: t))
            }
        }
        return result
    }

    static func freeColors() -> [UIColor] {
        return [
            UIColor(white: 0.3, alpha: 1.0),
            UIColor(white: 0.35, alpha: 1.0),
            UIColor(white: 0.4, alpha: 1.0),
            UIColor(white: 0.45, alpha: 1.0),
            UIColor(white: 0.5, alpha: 1.0),
            UIColor(white: 0.55, alpha: 1.0),
            UIColor(white: 0.6, alpha: 1.0),
            UIColor(white: 0.65, alpha: 1.0),
            UIColor(white: 0.7, alpha: 1.0),
            UIColor(white: 0.65, alpha: 1.0),
            UIColor(white: 0.6, alpha: 1.0),
            UIColor(white: 0.55, alpha: 1.0),
            UIColor(white: 0.5, alpha: 1.0),
            UIColor(white: 0.45, alpha: 1.0),
            UIColor(white: 0.4, alpha: 1.0),
            UIColor(white: 0.35, alpha: 1.0),
            UIColor(white: 0.3, alpha: 1.0)
        ]
    }

    private static func blend(_ c1: UIColor, _ c2: UIColor) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: (r1 + r2) / 2,
            green: (g1 + g2) / 2,
            blue: (b1 + b2) / 2,
            alpha: (a1 + a2) / 2
        )
    }

    // 공유: 배지와 캘린더가 동일한 방식/속도로 색을 순환하도록 보간된 색 배열을 생성
    static func interpolatedColors(from base: [UIColor], progress: CGFloat) -> [CGColor] {
        guard !base.isEmpty else { return [] }
        let count = base.count
        var colors: [CGColor] = []
        for i in 0..<count {
            let pos = (CGFloat(i) / CGFloat(max(1, count - 1))) + progress
            let idx = Int(floor(pos * CGFloat(count))) % count
            let next = (idx + 1) % count
            let frac = (pos * CGFloat(count)).truncatingRemainder(dividingBy: 1)
            colors.append(interpolate(from: base[idx], to: base[next], fraction: frac).cgColor)
        }
        return colors
    }

    private static func interpolate(from: UIColor, to: UIColor, fraction: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        from.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        to.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 + (r2 - r1) * fraction,
            green: g1 + (g2 - g1) * fraction,
            blue: b1 + (b2 - b1) * fraction,
            alpha: a1 + (a2 - a1) * fraction
        )
    }
}
