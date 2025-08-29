import UIKit

// 파일명만 다르고, 타입명은 기존 PremiumBadgeView 리팩터링과 동일하게 유지
struct GradientBadgePalette {
    static func proColors() -> [UIColor] {
        return [
            UIColor.systemPink,
            blend(UIColor.systemPink, UIColor.systemRed),
            UIColor.systemRed,
            blend(UIColor.systemRed, UIColor.systemOrange),
            UIColor.systemOrange,
            blend(UIColor.systemOrange, UIColor.systemYellow),
            UIColor.systemYellow,
            blend(UIColor.systemYellow, UIColor.systemGreen),
            UIColor.systemGreen,
            blend(UIColor.systemGreen, UIColor.systemTeal),
            UIColor.systemTeal,
            blend(UIColor.systemTeal, UIColor.systemCyan),
            UIColor.systemCyan,
            blend(UIColor.systemCyan, UIColor.systemBlue),
            UIColor.systemBlue,
            blend(UIColor.systemBlue, UIColor.systemIndigo),
            UIColor.systemIndigo,
            blend(UIColor.systemIndigo, UIColor.systemPurple),
            UIColor.systemPurple,
            blend(UIColor.systemPurple, UIColor.systemPink),
            UIColor.systemPink
        ]
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
