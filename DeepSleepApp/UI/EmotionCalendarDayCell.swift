import UIKit
import FSCalendar

/// FSCalendar 셀에 감정 이모지와 To-do 존재 표시(그라데이션 테두리)를 함께 표현하는 셀
final class EmotionCalendarDayCell: FSCalendarCell, GradientTickSubscriber {
    enum Palette { case premium, free }
    private let gradientBorderLayer = CAGradientLayer()
    private let borderMaskLayer = CAShapeLayer()
    private let todayCornerLayer = CAShapeLayer()
    private var isAnimating = false
    private var currentPalette: Palette = .premium
    private var isTodayCornerVisible: Bool = false

    // 팔레트는 GradientBadgePalette에서 공유(중복 정의 금지)

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
        // 기본 셀 스타일 유지하면서, 가장 위에 얇은 네모 링(그라데이션)을 추가한다
        if #available(iOS 12.0, *) {
            gradientBorderLayer.type = .conic   // 시각적으로 뚜렷한 링 흐름
            // Conic: startPoint가 중심이어야 올바른 각도 매핑이 됨
            gradientBorderLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
            gradientBorderLayer.endPoint = CGPoint(x: 1.0, y: 0.5) // 시작 각도 기준점
        } else {
            gradientBorderLayer.type = .axial
            gradientBorderLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
            gradientBorderLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        }
        gradientBorderLayer.colors = GradientBadgePalette.proColors().map { $0.cgColor }
        gradientBorderLayer.isHidden = true
        // 은은한 빛 번짐 효과
        gradientBorderLayer.shadowColor = UIColor.systemPurple.cgColor
        gradientBorderLayer.shadowOffset = .zero
        gradientBorderLayer.shadowRadius = 6
        gradientBorderLayer.shadowOpacity = 0.55
        gradientBorderLayer.isOpaque = false
        gradientBorderLayer.zPosition = 999
        if #available(iOS 13.0, *) {
            gradientBorderLayer.cornerCurve = .continuous
        }
        contentView.layer.addSublayer(gradientBorderLayer)

        borderMaskLayer.fillColor = UIColor.clear.cgColor
        borderMaskLayer.strokeColor = UIColor.black.cgColor
        borderMaskLayer.lineWidth = 2
        borderMaskLayer.lineJoin = .round
        borderMaskLayer.lineCap = .round
        gradientBorderLayer.mask = borderMaskLayer

        // 오늘 표시: 우상단 작은 접힌 모서리 형태의 삼각형 레이어
        todayCornerLayer.fillColor = UIColor.systemBlue.withAlphaComponent(0.9).cgColor
        todayCornerLayer.strokeColor = UIColor.clear.cgColor
        todayCornerLayer.isHidden = true
        todayCornerLayer.zPosition = 1000
        contentView.layer.addSublayer(todayCornerLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientBorderLayer.frame = contentView.bounds

        // 날짜 셀의 실제 블록(컨텐츠 뷰) 경계에 딱 맞는 테두리
        // 선이 잘리지 않도록 선 두께의 절반만큼만 인셋
        let base = min(contentView.bounds.width, contentView.bounds.height)
        let lineWidth: CGFloat = max(1.0, base * 0.035)
        borderMaskLayer.lineWidth = lineWidth
        let rect = contentView.bounds.insetBy(dx: lineWidth / 2.0, dy: lineWidth / 2.0)
        // 애플 UI 느낌의 연속 곡률에 가깝게: 셀 크기 기반 동적 라운드(최소 6, 최대 12)
        let corner: CGFloat = max(6.0, min(12.0, base * 0.22))
        let path = UIBezierPath(roundedRect: rect, cornerRadius: corner)
        borderMaskLayer.path = path.cgPath
        gradientBorderLayer.shadowPath = path.cgPath
        gradientBorderLayer.cornerRadius = corner

        // 오늘 모서리 접힘 표시 갱신
        todayCornerLayer.frame = contentView.bounds
        updateTodayCornerPath()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        setTodoRingVisible(false)
        setTodayCornerVisible(false)
    }

    func setTodoRingVisible(_ visible: Bool) {
        shouldShowTodoRing = visible
        gradientBorderLayer.isHidden = !visible
        setNeedsLayout()
        if visible {
            startBadgeMatchedAnimation()
            // 즉시 현재 진행도를 반영하여 첫 프레임부터 배지와 동기화
            gradientTick(progress: GlobalGradientTicker.shared.progress)
        } else {
            stopBadgeMatchedAnimation()
        }
    }

    func setPalette(_ palette: Palette) {
        currentPalette = palette
        let uiColors: [UIColor] = (palette == .premium) ? GradientBadgePalette.proColors() : GradientBadgePalette.freeColors()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        gradientBorderLayer.colors = uiColors.map { $0.cgColor }
        CATransaction.commit()
        if shouldShowTodoRing {
            gradientTick(progress: GlobalGradientTicker.shared.progress)
        }
    }

    // MARK: - Badge-matched gradient flow via global ticker
    private func startBadgeMatchedAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        applyGradientColorsAnimation()
    }

    private func stopBadgeMatchedAnimation() {
        guard isAnimating else { return }
        isAnimating = false
        gradientBorderLayer.removeAnimation(forKey: "colorsFlow")
        gradientBorderLayer.removeAnimation(forKey: "locationsFlow")
    }

    // GradientTickSubscriber (더 이상 전역 틱커를 사용하지 않지만 초기 프레임 지정용으로 남김)
    func gradientTick(progress: CGFloat) {
        setGradientColors(progress: progress)
    }

    private func setGradientColors(progress: CGFloat) {
        let base: [UIColor] = (currentPalette == .premium) ? GradientBadgePalette.proColors() : GradientBadgePalette.freeColors()
        let colors = GradientBadgePalette.interpolatedColors(from: base, progress: progress)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        gradientBorderLayer.colors = colors
        // locations는 균등 분포 고정 (conic에서 각도 기준)
        let n = max(2, colors.count)
        let locs: [NSNumber] = (0..<n).map { NSNumber(value: Double(CGFloat($0) / CGFloat(n - 1))) }
        gradientBorderLayer.locations = locs
        CATransaction.commit()
    }

    private func applyGradientColorsAnimation() {
        let base: [UIColor] = (currentPalette == .premium) ? GradientBadgePalette.proColors() : GradientBadgePalette.freeColors()
        // Keyframe으로 colors 자체를 회전시켜 흐름을 보장 (locations는 균등 고정)
        let steps = 36
        var values: [[CGColor]] = []
        for i in 0..<steps {
            let p = CGFloat(i) / CGFloat(steps)
            values.append(GradientBadgePalette.interpolatedColors(from: base, progress: p))
        }
        let anim = CAKeyframeAnimation(keyPath: "colors")
        anim.values = values
        anim.calculationMode = .linear
        anim.duration = GradientAnimationSpec.badgeCycleDuration
        anim.repeatCount = .infinity
        anim.isRemovedOnCompletion = false
        gradientBorderLayer.add(anim, forKey: "colorsFlow")

        // locations는 균등 분포로 고정 (렌더링 일관성)
        let n = max(2, base.count)
        let locs: [NSNumber] = (0..<n).map { NSNumber(value: Double(CGFloat($0) / CGFloat(n - 1))) }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        gradientBorderLayer.locations = locs
        CATransaction.commit()
    }

    // 오늘 날짜의 모서리 접힘 마크 노출 여부
    func setTodayCornerVisible(_ visible: Bool) {
        isTodayCornerVisible = visible
        todayCornerLayer.isHidden = !visible
        if visible { updateTodayCornerPath() }
    }

    private func updateTodayCornerPath() {
        guard !todayCornerLayer.isHidden else { return }
        let b = contentView.bounds
        let size = max(6, min(12, min(b.width, b.height) * 0.22))
        // 우상단 작은 삼각형
        let path = UIBezierPath()
        let topRight = CGPoint(x: b.maxX, y: b.minY)
        path.move(to: CGPoint(x: topRight.x - size, y: topRight.y))
        path.addLine(to: topRight)
        path.addLine(to: CGPoint(x: topRight.x, y: topRight.y + size))
        path.close()
        todayCornerLayer.path = path.cgPath
    }
}
