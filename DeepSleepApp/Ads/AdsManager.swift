// Centralized AdMob integration utilities.
// This file is safe to build without the GoogleMobileAds SDK; all calls are guarded.

import Foundation
import ObjectiveC

#if canImport(UIKit)
    import UIKit
#else
    // UIKit 미포함 타겟(예: 서버 사이드/테스트 CLI) 빌드 호환용 최소 스텁
    import Foundation
    public typealias CGFloat = Double
    public class UIView { public init() {} }
    public class UIViewController { public init() {} }
    public class NSLayoutConstraint { public init() {} }
    public struct CGRect { public static let zero = CGRect() }
    public struct _LayoutAnchor {
        public func constraint(equalToConstant: CGFloat) -> NSLayoutConstraint {
            NSLayoutConstraint()
        }
    }
    extension UIView {
        public var translatesAutoresizingMaskIntoConstraints: Bool {
            get { false }
            set {}
        }
        public var backgroundColor: Any? {
            get { nil }
            set {}
        }
        public var heightAnchor: _LayoutAnchor { _LayoutAnchor() }
        public func addSubview(_ v: UIView) {}
        public func layoutIfNeeded() {}
    }
#endif

#if canImport(GoogleMobileAds)
    import GoogleMobileAds
#endif

final class AdsManager {
    static let shared = AdsManager()
    private init() {}
    // Thread-safe 단일 초기화 보장을 위한 전용 직렬 큐 & 플래그
    private let startSyncQueue = DispatchQueue(label: "ads.manager.start.queue")
    private var didStartSDK = false

    // Reads from Info.plist which in turn reads from Secrets.xcconfig
    private var configuredAppId: String? {
        Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String
    }
    private var configuredBannerUnitId: String? {
        Bundle.main.object(forInfoDictionaryKey: "ADMOB_BANNER_UNIT_ID") as? String
    }
    private var testAppIdFromConfig: String? {
        Bundle.main.object(forInfoDictionaryKey: "ADMOB_TEST_APP_ID") as? String
    }
    private var testBannerUnitIdFromConfig: String? {
        Bundle.main.object(forInfoDictionaryKey: "ADMOB_TEST_BANNER_UNIT_ID") as? String
    }

    // ---- 안전성 보장용 유틸 ----
    private func isPlaceholder(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.hasPrefix("$(") && t.hasSuffix(")")
    }
    private func looksLikeAdMobAppId(_ s: String) -> Bool {
        // 예: ca-app-pub-3940256099942544~1458002511
        return s.hasPrefix("ca-app-pub-") && s.contains("~")
    }
    private func looksLikeAdUnitId(_ s: String) -> Bool {
        // 예: ca-app-pub-3940256099942544/2934735716
        return s.hasPrefix("ca-app-pub-") && s.contains("/")
    }

    private var resolvedAppId: String? {
        if let real = configuredAppId, !real.isEmpty, !isPlaceholder(real), looksLikeAdMobAppId(real) {
            return real
        }
        if let test = testAppIdFromConfig, !test.isEmpty, !isPlaceholder(test), looksLikeAdMobAppId(test) {
            return test
        }
        return nil
    }

    private func resolveBannerUnitId() -> String? {
        if isTestModeEnabled {
            if let t = testBannerUnitIdFromConfig, !t.isEmpty, !isPlaceholder(t), looksLikeAdUnitId(t) {
                return t
            }
            // 테스트 모드인데 테스트 유닛이 없으면 로드하지 않음
            return nil
        }
        if let real = configuredBannerUnitId, !real.isEmpty, !isPlaceholder(real), looksLikeAdUnitId(real) {
            return real
        }
        if let t = testBannerUnitIdFromConfig, !t.isEmpty, !isPlaceholder(t), looksLikeAdUnitId(t) {
            return t
        }
        return nil
    }

    var hasValidAppConfiguration: Bool {
        return resolvedAppId != nil && resolveBannerUnitId() != nil
    }

    // Choose banner unit ID from Info.plist (Secrets.xcconfig). Force test when TEST_MODE enabled.
    private var isTestModeEnabled: Bool {
        if let boolVal = Bundle.main.object(forInfoDictionaryKey: "TEST_MODE") as? Bool {
            return boolVal
        }
        if let strVal = Bundle.main.object(forInfoDictionaryKey: "TEST_MODE") as? String {
            return ["1", "true", "yes", "on"].contains(strVal.lowercased())
        }
        return false
    }

    func bannerAdUnitIdForCurrentBuild() -> String {
        return resolveBannerUnitId() ?? ""
    }

    // Optional: initialize SDK if available and the app id is present.
    func configureIfPossible() {
        #if canImport(GoogleMobileAds)
            // 1. 중복 start 방지 (Thread-safe)
            var shouldReturn = false
            startSyncQueue.sync {
                if didStartSDK {
                    shouldReturn = true
                } else {
                    didStartSDK = true
                }
            }
            if shouldReturn {
                // 이미 초기화 시도 완료 (성공/실패). 재호출 방지.
                return
            }

            // 2. App ID 결정 (실제 → 테스트 순) 및 유효성 검증
            guard let appId = resolvedAppId else {
                print("ℹ️ [Ads] GADApplicationIdentifier missing/invalid. Skipping GADMobileAds.start().")
                // 구성 누락으로 start 수행 안 됨 → 이후 재시도 가능하도록 플래그 되돌림
                startSyncQueue.async { [weak self] in
                    self?.didStartSDK = false
                }
                return
            }

            // 3. SDK start
            MobileAds.shared.start { _ in }
            // 4. 테스트 디바이스 설정
            var ids = ["SIMULATOR_ID"]
            if isTestModeEnabled { ids.append("00000000-0000-0000-0000-000000000000") }
            MobileAds.shared.requestConfiguration.testDeviceIdentifiers = ids
            print("✅ [Ads] Google Mobile Ads started with App ID: \(appId)")
        #else
            print("ℹ️ [Ads] GoogleMobileAds SDK not present. Ad initialization skipped.")
        #endif
    }
}

// A minimal host view that expands to banner height when an ad is loaded.
#if canImport(UIKit)
    final class BannerAdContainerView: UIView {
        // 외부에서 배너 높이 변화를 감지하여 추가 안전영역 조정 등에 활용
        var onHeightChange: ((CGFloat) -> Void)?

        private var heightConstraint: NSLayoutConstraint!
        private var didRetryWithTestUnit = false
        private var lastAdSize: AdSize?
        private var deferredLoadScheduled = false

        #if canImport(GoogleMobileAds)
            private var bannerView: BannerView?
        #endif

        override init(frame: CGRect) {
            super.init(frame: frame)
            translatesAutoresizingMaskIntoConstraints = false
            backgroundColor = .clear
            heightConstraint = heightAnchor.constraint(equalToConstant: 0)
            heightConstraint.isActive = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func loadBanner(in viewController: UIViewController) {
            // Initialize SDK if possible (no-op when SDK absent)
            AdsManager.shared.configureIfPossible()

            #if canImport(GoogleMobileAds)
                // 레이아웃 미완성 시(폭 0)에는 1 프레임 뒤로 미루어 정확한 적응형 크기를 계산
                let width = bounds.width
                if width <= 1, !deferredLoadScheduled {
                    deferredLoadScheduled = true
                    DispatchQueue.main.async { [weak self, weak viewController] in
                        guard let self, let vc = viewController else { return }
                        self.deferredLoadScheduled = false
                        self.loadBanner(in: vc)
                    }
                    return
                }

                let unitId: String = AdsManager.shared.bannerAdUnitIdForCurrentBuild()
                if unitId.isEmpty {
                    print(
                        "⚠️ [Ads] Banner unit id missing (both real and test). Banner will not load."
                    )
                    heightConstraint.constant = 0
                    return
                }
                // Use adaptive anchored size where possible; fallback to standard banner size.
                let adWidth = max(width, UIScreen.main.bounds.width * 0.9)  // 폭 0 방지 + 너무 좁은 폭 방지
                let adSize = currentOrientationAnchoredAdaptiveBanner(width: adWidth)
                self.lastAdSize = adSize
                let banner = BannerView(adSize: adSize)
                banner.translatesAutoresizingMaskIntoConstraints = false
                banner.adUnitID = unitId
                banner.rootViewController = viewController
                addSubview(banner)
                NSLayoutConstraint.activate([
                    banner.centerXAnchor.constraint(equalTo: centerXAnchor),
                    banner.bottomAnchor.constraint(equalTo: bottomAnchor),
                ])
                banner.delegate = self
                let request = Request()
                banner.load(request)
                self.bannerView = banner

                // Update height to the resolved ad height
                let newHeight = adSize.size.height
                if heightConstraint.constant != newHeight {
                    heightConstraint.constant = newHeight
                    onHeightChange?(newHeight)
                }
                layoutIfNeeded()
            #else
                // SDK not available: keep height at 0 so it doesn't occupy space.
                heightConstraint.constant = 0
            #endif
        }
    }

    #if canImport(GoogleMobileAds)
        extension BannerAdContainerView: BannerViewDelegate {
            func bannerViewDidReceiveAd(_ bannerView: BannerView) {
                print(
                    "✅ [Ads] Banner loaded: size=\(bannerView.adSize.size), unitId=\(bannerView.adUnitID ?? "-")"
                )
                // Reset retry flag on success
                didRetryWithTestUnit = false
            }

            func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
                print("⚠️ [Ads] Banner failed to load: \(error.localizedDescription)")
                // In test mode, always retry with configured test unit id
                if !didRetryWithTestUnit {
                    let testId =
                        (Bundle.main.object(forInfoDictionaryKey: "ADMOB_TEST_BANNER_UNIT_ID")
                            as? String) ?? ""
                    if !testId.isEmpty {
                        didRetryWithTestUnit = true
                        print("↻ [Ads] Retrying with test unit id: \(testId)")
                        bannerView.adUnitID = testId
                        bannerView.load(Request())
                        return
                    }
                }

                // Keep container height minimal when fail definitively
                if heightConstraint.constant != 0 {
                    heightConstraint.constant = 0
                    onHeightChange?(0)
                }
                layoutIfNeeded()
            }
        }
    #endif
#endif  // end canImport(UIKit) wrapping BannerAdContainerView
