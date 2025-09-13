import UIKit

/// Centralized alternate app icon switching based on appearance.
/// Configure alternate icons (e.g., "AppIconLight", "AppIconDark") in the asset catalog/Info.plist.
enum AppIconManager {
    /// Always enforce the white app icon regardless of appearance.
    static func enforceWhiteIcon() {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let desiredName = desiredWhiteIconName()
        let currentName = UIApplication.shared.alternateIconName
        if currentName == desiredName { return }

        DispatchQueue.main.async {
            UIApplication.shared.setAlternateIconName(desiredName) { error in
                #if DEBUG
                if let error = error {
                    print("❌ [AppIconManager] Failed to set white icon (\(desiredName ?? "primary")): \(error)")
                } else {
                    print("✅ [AppIconManager] White icon applied: \(desiredName ?? "primary")")
                }
                #endif
            }
        }
    }

    /// Backward-compat function; now just enforces white icon.
    static func updateForTraitCollection(_ traitCollection: UITraitCollection?) {
        enforceWhiteIcon()
    }

    /// Determine the alternate icon name that looks white.
    /// Preference order: names containing "white" → "AppIconWhite" → names containing "light" → "AppIconLight" → nil(primary)
    private static func desiredWhiteIconName() -> String? {
        let names = availableAlternateIconNames()
        let lower = names.map { $0.lowercased() }

        if let idx = lower.firstIndex(where: { $0.contains("white") }) { return names[idx] }
        if names.contains("AppIconWhite") { return "AppIconWhite" }
        if let idx = lower.firstIndex(where: { $0.contains("light") }) { return names[idx] }
        if names.contains("AppIconLight") { return "AppIconLight" }
        return nil
    }

    private static func availableAlternateIconNames() -> [String] {
        guard let iconsDict = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let alternates = iconsDict["CFBundleAlternateIcons"] as? [String: Any] else {
            return []
        }
        return Array(alternates.keys)
    }
}
