import Foundation

public enum InvalidationReason: String, Codable {
    case personaChanged
    case languageChanged
    case toneChanged
    case modeChanged
    case coreMemoryUpdated
    case modelSelectionChanged
    case appVersionUpdated
    case manual
    case expiredOrPersonaChanged
    case none
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

    public init(event: CacheEvent, reason: InvalidationReason, age: TimeInterval?, caller: String?) {
        self.timestamp = Date()
        self.event = event
        self.reason = reason
        self.ageSeconds = age != nil ? Int(age!) : nil
        self.caller = caller
    }
}
