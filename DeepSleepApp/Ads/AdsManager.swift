// Centralized AdMob integration utilities.
// This file is safe to build without the GoogleMobileAds SDK; all calls are guarded.

import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

final class AdsManager {
    static let shared = AdsManager()
    private init() {}

    // Test IDs from Google documentation
    private let testAppId = "ca-app-pub-3940256099942544~1458002511"
    private let testBannerUnitId = "ca-app-pub-3940256099942544/2934735716"

    // Reads from Info.plist which in turn reads from Secrets.xcconfig
    private var configuredAppId: String? {
        Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String
    }
    private var configuredBannerUnitId: String? {
        Bundle.main.object(forInfoDictionaryKey: "ADMOB_BANNER_UNIT_ID") as? String
    }

    // Enforce test units for DEBUG builds, as per Google policy and your requirement.
    func bannerAdUnitIdForCurrentBuild() -> String {
        #if DEBUG
        return testBannerUnitId
        #else
        return (configuredBannerUnitId?.isEmpty == false ? configuredBannerUnitId! : testBannerUnitId)
        #endif
    }

    // Optional: initialize SDK if available and the app id is present.
    func configureIfPossible() {
        #if canImport(GoogleMobileAds)
        let appId = configuredAppId
        if let appId, !appId.isEmpty {
            // The SDK reads the App ID from Info.plist; start() is sufficient.
            MobileAds.shared.start { _ in }
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
        // Use adaptive anchored size where possible; fallback to standard banner size.
        let adWidth = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
        let adSize = currentOrientationAnchoredAdaptiveBanner(width: adWidth)
        let banner = BannerView(adSize: adSize)
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.adUnitID = AdsManager.shared.bannerAdUnitIdForCurrentBuild()
        banner.rootViewController = viewController
        addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: centerXAnchor),
            banner.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        banner.load(Request())
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

