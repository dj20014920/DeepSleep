import UIKit

/// 관찰 기반으로 구독 상태 변화에 맞춰 화면 UI를 일관되게 갱신하기 위한 바인더
/// - 목적: 각 화면에 산재한 상태 갱신 코드를 중앙화하고 UX/색감 일관성을 유지
/// - 사용법:
///   1) 화면에서 `SubscriptionUIBinder.attach(to:self) { isPremium in ... }` 호출
///   2) 콜백 안에서 버튼/라벨/배지 등의 상태를 갱신
public final class SubscriptionUIBinder {
    public typealias UpdateHandler = (_ isPremium: Bool) -> Void

    private weak var host: AnyObject?
    private var token: NSObjectProtocol?
    private var handler: UpdateHandler?

    /// 공통 CTA 버튼 타이틀에 가격을 포함하여 설정하는 헬퍼(KISS/DRY)
    public static func setPriceTitle(button: UIButton, title: String, price: String?) {
        if let price = price { button.setTitle("\(title)  \(price)", for: .normal) }
        else { button.setTitle(title, for: .normal) }
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.separator.cgColor
        button.backgroundColor = UIColor.secondarySystemBackground
        button.accessibilityLabel = button.titleLabel?.text
    }

    private init(host: AnyObject, handler: @escaping UpdateHandler) {
        self.host = host
        self.handler = handler
        // 최초 상태 반영
        handler(SubscriptionStatusCenter.shared.isPremium)
        // 구독 상태 변경 옵저버 등록
        token = NotificationCenter.default.addObserver(
            forName: .subscriptionStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.handler?(SubscriptionStatusCenter.shared.isPremium)
        }
    }

    deinit {
        if let t = token { NotificationCenter.default.removeObserver(t) }
    }

    /// 화면(UIViewController 등)에 바인더를 연결합니다.
    @discardableResult
    public static func attach(to host: AnyObject, update: @escaping UpdateHandler) -> SubscriptionUIBinder {
        let binder = SubscriptionUIBinder(host: host, handler: update)
        SubscriptionUIBinderStore.shared.store(binder: binder, for: host)
        return binder
    }
}

/// 바인더 수명 관리를 위한 내부 저장소(호스트 생명주기와 함께 해제)
private final class SubscriptionUIBinderStore {
    static let shared = SubscriptionUIBinderStore()
    private var table = NSMapTable<AnyObject, NSMutableArray>(keyOptions: .weakMemory, valueOptions: .strongMemory)

    private init() {}

    func store(binder: SubscriptionUIBinder, for host: AnyObject) {
        let arr = table.object(forKey: host) ?? NSMutableArray()
        arr.add(binder)
        table.setObject(arr, forKey: host)
    }
}

// MARK: - UI 헬퍼 (색감/애니메이션 일관성)
public struct SubscriptionUIStyleHelper {
    /// 프리미엄 상태에 따른 버튼 스타일 일관 적용
    public static func styleCTAButton(_ button: UIButton, isPremium: Bool) {
        if isPremium {
            button.isEnabled = true
            button.alpha = 1.0
            button.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.15)
            button.setTitleColor(.systemGreen, for: .normal)
            button.layer.cornerRadius = 10
        } else {
            button.isEnabled = true
            button.alpha = 1.0
            button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
            button.setTitleColor(.systemBlue, for: .normal)
            button.layer.cornerRadius = 10
        }
    }

    /// 프리미엄 배지 텍스트/가시성 제어(상위 뷰에서 D-N 배지와 함께 사용)
    public static func setBadge(_ label: UILabel, isPremium: Bool, daysRemaining: Int?) {
        if isPremium {
            label.isHidden = true
            return
        }
        
        // 무료 상태: 배지 표시
        label.isHidden = false
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        label.backgroundColor = UIColor.systemPink
        label.layer.cornerRadius = 14
        label.clipsToBounds = true
        label.textAlignment = .center
        
        // 내부 패딩을 위한 여백 설정
        label.layer.sublayerTransform = CATransform3DMakeTranslation(8, 0, 0)
        
        if let d = daysRemaining, d >= 0 {
            label.text = "  D-\(d) | 7일 무료체험  "
        } else {
            label.text = "  7일 무료체험  "
        }
    }

    /// 상태 전환 시 부드러운 페이드 애니메이션
    public static func crossfade(_ view: UIView, duration: TimeInterval = 0.2) {
        UIView.transition(with: view, duration: duration, options: .transitionCrossDissolve, animations: nil, completion: nil)
    }
}

