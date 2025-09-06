import UIKit

/// 간단한 전역 로딩 오버레이 (고양이 GIF 포함)
final class LoadingOverlay: UIView {
    static let tagValue = 0xD5EE110 // unique

    private let dimView = UIView()
    private let container = UIView()
    private let catView = GifCatView()
    private let messageLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        // 반투명 딤(화이트 아님)
        backgroundColor = .clear
        isUserInteractionEnabled = true // 터치 차단
        translatesAutoresizingMaskIntoConstraints = false
        tag = LoadingOverlay.tagValue

        dimView.translatesAutoresizingMaskIntoConstraints = false
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        addSubview(dimView)

        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .systemBackground
        container.layer.cornerRadius = 14
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.15
        container.layer.shadowOffset = CGSize(width: 0, height: 2)
        container.layer.shadowRadius = 8
        addSubview(container)

        catView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(catView)

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        messageLabel.textColor = .label
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 2
        messageLabel.text = "조언 생성 중…\n잠시만 기다려 주세요"
        container.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor),

            container.centerXAnchor.constraint(equalTo: centerXAnchor),
            container.centerYAnchor.constraint(equalTo: centerYAnchor),
            // 더 작은 카드 크기
            container.widthAnchor.constraint(equalToConstant: 150),
            container.heightAnchor.constraint(equalToConstant: 150),

            catView.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            catView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            catView.widthAnchor.constraint(equalToConstant: 56),
            catView.heightAnchor.constraint(equalToConstant: 56),

            messageLabel.topAnchor.constraint(equalTo: catView.bottomAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            messageLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            messageLabel.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -12)
        ])
    }

    static func show(in viewController: UIViewController) {
        DispatchQueue.main.async {
            guard viewController.view.viewWithTag(LoadingOverlay.tagValue) == nil else { return }
            let overlay = LoadingOverlay(frame: .zero)
            viewController.view.addSubview(overlay)
            NSLayoutConstraint.activate([
                overlay.topAnchor.constraint(equalTo: viewController.view.topAnchor),
                overlay.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
                overlay.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor)
            ])
            overlay.alpha = 0
            UIView.animate(withDuration: 0.15) { overlay.alpha = 1 }
        }
    }

    static func hide(from viewController: UIViewController?) {
        DispatchQueue.main.async {
            guard let container = viewController?.view ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else { return }
            if let overlay = container.viewWithTag(LoadingOverlay.tagValue) {
                UIView.animate(withDuration: 0.15, animations: { overlay.alpha = 0 }) { _ in overlay.removeFromSuperview() }
            }
        }
    }
}
