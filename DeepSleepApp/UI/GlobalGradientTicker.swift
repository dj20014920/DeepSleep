import UIKit

/// 여러 뷰(배지/캘린더 등)에서 동일한 진행도(progress)를 공유하도록 하는 전역 그라데이션 틱커
/// - DRY: 비슷한 애니메이션 로직이 산재하지 않도록 단일 진입점
final class GlobalGradientTicker {
    static let shared = GlobalGradientTicker()

    private var displayLink: CADisplayLink?
    private(set) var progress: CGFloat = 0
    private var subscribers = NSHashTable<AnyObject>.weakObjects()

    private init() {}

    func addSubscriber(_ object: GradientTickSubscriber) {
        subscribers.add(object)
        startIfNeeded()
    }

    func removeSubscriber(_ object: GradientTickSubscriber) {
        subscribers.remove(object)
        if subscribers.allObjects.isEmpty { stop() }
    }

    @objc private func tick() {
        progress += GradientAnimationSpec.badgeIncrementPerFrame
        if progress > 1.0 { progress -= 1.0 }
        for obj in subscribers.allObjects {
            (obj as? GradientTickSubscriber)?.gradientTick(progress: progress)
        }
    }

    private func startIfNeeded() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stop() {
        displayLink?.invalidate()
        displayLink = nil
        progress = 0
    }
}

protocol GradientTickSubscriber: AnyObject {
    func gradientTick(progress: CGFloat)
}

