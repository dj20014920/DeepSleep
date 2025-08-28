import UIKit
import FSCalendar

/// FSCalendar 셀에 감정 이모지와 To-do 존재 표시(그라데이션 테두리)를 함께 표현하는 셀
final class EmotionCalendarDayCell: FSCalendarCell {
    enum Palette { case premium, free }
    private let gradientBorderLayer = CAGradientLayer()
    private let borderMaskLayer = CAShapeLayer()

    // 팔레트 프리셋
    private let premiumColors: [CGColor] = [
        UIColor.systemPink.cgColor,
        UIColor.systemRed.cgColor,
        UIColor.systemOrange.cgColor,
        UIColor.systemYellow.cgColor,
        UIColor.systemGreen.cgColor,
        UIColor.systemTeal.cgColor,
        UIColor.systemCyan.cgColor,
        UIColor.systemBlue.cgColor,
        UIColor.systemIndigo.cgColor,
        UIColor.systemPurple.cgColor,
        UIColor.systemPink.cgColor
    ]

    private let freeColors: [CGColor] = [
        UIColor(white: 0.30, alpha: 1.0).cgColor,
        UIColor(white: 0.40, alpha: 1.0).cgColor,
        UIColor(white: 0.50, alpha: 1.0).cgColor,
        UIColor(white: 0.60, alpha: 1.0).cgColor,
        UIColor(white: 0.70, alpha: 1.0).cgColor,
        UIColor(white: 0.60, alpha: 1.0).cgColor,
        UIColor(white: 0.50, alpha: 1.0).cgColor,
        UIColor(white: 0.40, alpha: 1.0).cgColor
    ]

    // 테두리 표시 여부
    private var shouldShowTodoRing: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init!(coder aDecoder: NSCoder!) {
        super.init(coder: aDecoder)
        setup()
    }

    private func setup() {
        // 기본 셀 스타일 유지하면서, 가장 위에 얇은 링을 추가한다
        gradientBorderLayer.type = .axial
        gradientBorderLayer.colors = premiumColors
        gradientBorderLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientBorderLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientBorderLayer.isHidden = true
        layer.addSublayer(gradientBorderLayer)

        borderMaskLayer.fillColor = UIColor.clear.cgColor
        borderMaskLayer.strokeColor = UIColor.black.cgColor
        borderMaskLayer.lineWidth = 2
        gradientBorderLayer.mask = borderMaskLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientBorderLayer.frame = bounds

        // 날짜 셀의 네모난 칸에 맞춘 라운디드 사각형 테두리
        // 약간 안쪽으로 인셋하여 겹침을 줄임
        let inset: CGFloat = 3.0
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let corner: CGFloat = max(6, min(rect.width, rect.height) * 0.16)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: corner)
        borderMaskLayer.path = path.cgPath
        borderMaskLayer.lineWidth = 2.0
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        setTodoRingVisible(false)
    }

    func setTodoRingVisible(_ visible: Bool) {
        shouldShowTodoRing = visible
        gradientBorderLayer.isHidden = !visible
        setNeedsLayout()
    }

    func setPalette(_ palette: Palette) {
        switch palette {
        case .premium:
            gradientBorderLayer.colors = premiumColors
        case .free:
            gradientBorderLayer.colors = freeColors
        }
    }
}
