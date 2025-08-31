import Foundation

/// 공용 프록시 인증 설정(SSOT)
/// - Origin 등 네트워크 레벨 상수는 여기에서만 관리합니다.
public enum ProxyAuthConfig {
    /// CORS/서버 정책과 일치해야 하는 Origin 헤더 값
    public static let origin = "https://emozleep.app"
}
