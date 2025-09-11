import Foundation

/// 앱 번들에서 버전(마케팅 버전)과 빌드 번호를 읽어오는 유틸리티
/// - CFBundleShortVersionString → v[version]
/// - CFBundleVersion            → b[build]
/// - 최종 포맷: "v[version] b[build]"
///
/// Info.plist에서 $(MARKETING_VERSION), $(CURRENT_PROJECT_VERSION) 같은
/// 미치환 플레이스홀더가 남아있는 경우를 대비하여 안전하게 처리합니다.
public enum AppVersionInfo {

    /// CFBundleShortVersionString (마케팅 버전, 예: "1.2.3")
    /// - Parameter bundle: 기본 .main
    /// - Returns: 유효한 값이 없으면 "0.0.0"
    public static func marketingVersion(in bundle: Bundle = .main) -> String {
        if let s = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            isValidInfoPlistValue(s)
        {
            return s
        }
        if let n = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? NSNumber {
            return n.stringValue
        }
        return "0.0.0"
    }

    /// CFBundleVersion (빌드 번호, 예: "42")
    /// - Parameter bundle: 기본 .main
    /// - Returns: 유효한 값이 없으면 "0"
    public static func buildNumber(in bundle: Bundle = .main) -> String {
        if let s = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            isValidInfoPlistValue(s)
        {
            return s
        }
        if let n = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? NSNumber {
            return n.stringValue
        }
        return "0"
    }

    /// 최종 표시용 문자열
    /// - Format: "v[version] b[build]"
    /// - Parameter bundle: 기본 .main
    public static func formatted(in bundle: Bundle = .main) -> String {
        let v = marketingVersion(in: bundle)
        let b = buildNumber(in: bundle)
        return "v\(v) b\(b)"
    }

    /// DEBUG 빌드에서만 "(debug)" 꼬리를 다는 보조 함수
    public static func debugDescription(in bundle: Bundle = .main) -> String {
        #if DEBUG
            return formatted(in: bundle) + " (debug)"
        #else
            return formatted(in: bundle)
        #endif
    }

    // MARK: - Helpers

    /// Info.plist에서 읽은 문자열이 유효한지 판단
    /// - 비어있지 않고, "$(…)" 형태의 미치환 플레이스홀더가 아님
    private static func isValidInfoPlistValue(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // xcconfig 미치환 방지: "$(KEY)" 형태이면 무시
        if trimmed.hasPrefix("$(") && trimmed.hasSuffix(")") { return false }
        return true
    }
}
