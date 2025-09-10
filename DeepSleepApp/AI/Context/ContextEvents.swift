import Foundation

public enum InvalidationReason: String, Codable {
    case personaChanged  // 페르소나(닉네임/특성/톤 등) 변경
    case languageChanged  // 언어/로케일 변경
    case toneChanged  // 말투/친구 톤 변경
    case modeChanged  // 대화/AI 모드 전환
    case coreMemoryUpdated  // 핵심 기억(메모리) 업데이트
    case modelSelectionChanged  // 모델(LMM) 변경
    case manual  // 수동 무효화(사용자/관리자 트리거)
    case expired  // TTL 만료 (이전 expiredOrPersonaChanged 분리)
    @available(*, deprecated, message: "이전 통합 사유. 이제 .expired / .personaChanged / modelSelectionChanged / modeChanged / toneChanged 세분화 사용.")
    case expiredOrPersonaChanged  // 레거시: 새 코드에서는 사용 금지 (검색/로그 잔재 정리 예정)
    case none  // (주로 Hit 로깅에 사용)
}

public enum CacheEvent: String, Codable {
    case hit
    case miss
}

public struct CacheLogEntry: Codable {
    public let timestamp: Date
    public let event: CacheEvent
    public let reason: InvalidationReason
    public let ageSeconds: Int?
    public let caller: String?

    public init(event: CacheEvent, reason: InvalidationReason, age: TimeInterval?, caller: String?)
    {
        self.timestamp = Date()
        self.event = event
        self.reason = reason
        self.ageSeconds = age != nil ? Int(age!) : nil
        self.caller = caller
    }
}
