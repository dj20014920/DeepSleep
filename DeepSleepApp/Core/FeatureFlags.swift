import Foundation

public struct FeatureFlags {
    // Build-time defaults; can be overridden by remote config
    public static var IAP_ENABLED: Bool = true
    public static var PAYWALL_ENABLED: Bool = true
    public static var PREMIUM_LIMITS_ENABLED: Bool = true
    public static var MONTHLY_STATS_STRICT_WINDOW: Bool = true
}

