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
}

