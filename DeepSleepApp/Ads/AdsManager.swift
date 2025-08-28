// Centralized AdMob integration utilities.
// This file is safe to build without the GoogleMobileAds SDK; all calls are guarded.

import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

final class AdsManager {
    static let shared = AdsManager()
    private init() {}

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

    // Choose banner unit ID strictly from Info.plist (Secrets.xcconfig). No hardcoded test IDs.
    func bannerAdUnitIdForCurrentBuild() -> String {
        if let real = configuredBannerUnitId, !real.isEmpty {
            return real
        }
        return testBannerUnitIdFromConfig ?? ""
    }

    // Optional: initialize SDK if available and the app id is present.
    func configureIfPossible() {
        #if canImport(GoogleMobileAds)
        // Prefer real app id; fallback to test app id from config when missing.
        let appId = configuredAppId ?? testAppIdFromConfig
        if let appId, !appId.isEmpty {
            // The SDK reads the App ID from Info.plist; start() is sufficient.
            MobileAds.shared.start { _ in }
            // Ensure simulator shows test creatives while using real unit IDs (Google policy-safe)
            MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [ "SIMULATOR_ID" ]
            print("✅ [Ads] Google Mobile Ads started with App ID: \(appId)")
        } else {
            print("ℹ️ [Ads] GADApplicationIdentifier missing or empty. Skipping GADMobileAds.start().")
        }
        #else
        print("ℹ️ [Ads] GoogleMobileAds SDK not present. Ad initialization skipped.")
        #endif
    }
}

// A minimal host view that expands to banner height when an ad is loaded.
final class BannerAdContainerView: UIView {
    private var heightConstraint: NSLayoutConstraint!
    private var didRetryWithTestUnit = false
    private var lastAdSize: AdSize?

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
        guard let unitId = (Bundle.main.object(forInfoDictionaryKey: "ADMOB_BANNER_UNIT_ID") as? String), !unitId.isEmpty else {
            print("⚠️ [Ads] ADMOB_BANNER_UNIT_ID is missing in Info.plist. Banner will not load.")
            heightConstraint.constant = 0
            return
        }
        // Use adaptive anchored size where possible; fallback to standard banner size.
        let adWidth = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
        let adSize = currentOrientationAnchoredAdaptiveBanner(width: adWidth)
        self.lastAdSize = adSize
        let banner = BannerView(adSize: adSize)
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.adUnitID = unitId
        banner.rootViewController = viewController
        addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: centerXAnchor),
            banner.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        banner.delegate = self
        let request = Request()
        banner.load(request)
        self.bannerView = banner

        // Update height to the resolved ad height
        heightConstraint.constant = adSize.size.height
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
        print("✅ [Ads] Banner loaded: size=\(bannerView.adSize.size), unitId=\(bannerView.adUnitID ?? "-")")
        // Reset retry flag on success
        didRetryWithTestUnit = false
    }
    
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("⚠️ [Ads] Banner failed to load: \(error.localizedDescription)")
        // If real unit failed and test unit exists, retry once with test unit for development visibility
        if !didRetryWithTestUnit,
           let testId = Bundle.main.object(forInfoDictionaryKey: "ADMOB_TEST_BANNER_UNIT_ID") as? String,
           !testId.isEmpty {
            didRetryWithTestUnit = true
            print("↻ [Ads] Retrying with test unit id: \(testId)")
            bannerView.adUnitID = testId
            bannerView.load(Request())
            return
        }

        // Keep container height minimal when fail definitively
        heightConstraint.constant = 0
        layoutIfNeeded()
    }
}
#endif
