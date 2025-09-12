import Foundation
import CoreData

// MARK: - Core Data Entities for DeepSleep App

/// 통합 세션 엔티티 - 모든 사용자 활동을 하나의 세션으로 관리
@objc(UnifiedSessionEntity)
public class UnifiedSessionEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var createdAt: Date
    @NSManaged public var lastActivityAt: Date
    @NSManaged public var metadataData: Data? // SessionMetadata를 JSON으로 저장
    
    // 관계 (Relationships)
    @NSManaged public var chatMessages: NSSet?
    @NSManaged public var feedbackData: NSSet?
    @NSManaged public var behaviorEvents: NSSet?
}

// MARK: - UnifiedSessionEntity Core Data Extensions
extension UnifiedSessionEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<UnifiedSessionEntity> {
        return NSFetchRequest<UnifiedSessionEntity>(entityName: "UnifiedSessionEntity")
    }
    
    @objc(addChatMessagesObject:)
    @NSManaged public func addToChatMessages(_ value: StoredChatMessageEntity)
    
    @objc(removeChatMessagesObject:)
    @NSManaged public func removeFromChatMessages(_ value: StoredChatMessageEntity)
    
    @objc(addChatMessages:)
    @NSManaged public func addToChatMessages(_ values: NSSet)
    
    @objc(removeChatMessages:)
    @NSManaged public func removeFromChatMessages(_ values: NSSet)
    
    @objc(addFeedbackDataObject:)
    @NSManaged public func addToFeedbackData(_ value: PresetFeedbackEntity)
    
    @objc(removeFeedbackDataObject:)
    @NSManaged public func removeFromFeedbackData(_ value: PresetFeedbackEntity)
    
    @objc(addFeedbackData:)
    @NSManaged public func addToFeedbackData(_ values: NSSet)
    
    @objc(removeFeedbackData:)
    @NSManaged public func removeFromFeedbackData(_ values: NSSet)
    
    @objc(addBehaviorEventsObject:)
    @NSManaged public func addToBehaviorEvents(_ value: BehaviorEventEntity)
    
    @objc(removeBehaviorEventsObject:)
    @NSManaged public func removeFromBehaviorEvents(_ value: BehaviorEventEntity)
    
    @objc(addBehaviorEvents:)
    @NSManaged public func addToBehaviorEvents(_ values: NSSet)
    
    @objc(removeBehaviorEvents:)
    @NSManaged public func removeFromBehaviorEvents(_ values: NSSet)
}

/// 채팅 메시지 엔티티
@objc(StoredChatMessageEntity)
public class StoredChatMessageEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var role: String
    @NSManaged public var content: String
    
    // 관계
    @NSManaged public var session: UnifiedSessionEntity?
}

extension StoredChatMessageEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<StoredChatMessageEntity> {
        return NSFetchRequest<StoredChatMessageEntity>(entityName: "StoredChatMessageEntity")
    }
}

/// 프리셋 피드백 엔티티
@objc(PresetFeedbackEntity)
public class PresetFeedbackEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var presetName: String
    @NSManaged public var rating: Int16
    @NSManaged public var comment: String?
    
    // 관계
    @NSManaged public var session: UnifiedSessionEntity?
}

extension PresetFeedbackEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PresetFeedbackEntity> {
        return NSFetchRequest<PresetFeedbackEntity>(entityName: "PresetFeedbackEntity")
    }
}

/// 행동 이벤트 엔티티
@objc(BehaviorEventEntity)
public class BehaviorEventEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var eventType: String
    @NSManaged public var details: String?
    
    // 관계
    @NSManaged public var session: UnifiedSessionEntity?
}

extension BehaviorEventEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<BehaviorEventEntity> {
        return NSFetchRequest<BehaviorEventEntity>(entityName: "BehaviorEventEntity")
    }
}
// MARK: - Data Conversion Extensions

extension UnifiedSessionEntity {
    /// Core Data 엔티티를 struct 모델로 변환
    func toStruct() -> UnifiedSession {
        // 메타데이터 디코딩
        var metadata = SessionMetadata()
        if let metadataData = self.metadataData {
            metadata = (try? JSONDecoder().decode(SessionMetadata.self, from: metadataData)) ?? SessionMetadata()
        }
        
        // 채팅 메시지 변환 - 스레드/컨텍스트 안전: 현재 컨텍스트에서 Array로 복사 후 map
        let chatMessages: [StoredChatMessage] = {
            guard let set = self.chatMessages else { return [] }
            let copied = Array(set) as NSArray
            let entities: [StoredChatMessageEntity]
            if let typed = copied as? [StoredChatMessageEntity] {
                entities = typed
            } else {
                entities = copied.compactMap { $0 as? StoredChatMessageEntity }
            }
            // 결정적 정렬: timestamp asc → role(user<assistant<system) → uuid asc
            let roleRank: (String?) -> Int = { role in
                switch (role ?? "user") {
                case "user": return 0
                case "assistant": return 1
                case "system": return 2
                default: return 3
                }
            }
            let sorted = entities.sorted { a, b in
                let ta = a.timestamp
                let tb = b.timestamp
                if ta != tb { return ta < tb }
                let ra = roleRank(a.role)
                let rb = roleRank(b.role)
                if ra != rb { return ra < rb }
                return a.id.uuidString < b.id.uuidString
            }
            return sorted.map { $0.toStruct() }
        }()
        
        // 피드백 데이터 변환 - 동일 패턴 적용
        let feedbackData: [PresetFeedback] = {
            guard let set = self.feedbackData else { return [] }
            let copied = Array(set) as NSArray
            if let typed = copied as? [PresetFeedbackEntity] {
                return typed.map { $0.toStruct() }
            }
            let anyArray = copied.compactMap { $0 as? PresetFeedbackEntity }
            return anyArray.sorted { $0.timestamp < $1.timestamp }.map { $0.toStruct() }
        }()
        
        // 행동 이벤트 변환 - 동일 패턴 적용
        let behaviorEvents: [BehaviorEvent] = {
            guard let set = self.behaviorEvents else { return [] }
            let copied = Array(set) as NSArray
            if let typed = copied as? [BehaviorEventEntity] {
                return typed.map { $0.toStruct() }
            }
            let anyArray = copied.compactMap { $0 as? BehaviorEventEntity }
            return anyArray.sorted { $0.timestamp < $1.timestamp }.map { $0.toStruct() }
        }()
        
        return UnifiedSession(
            id: self.id.uuidString,
            createdAt: self.createdAt,
            lastActivityAt: self.lastActivityAt,
            chatMessages: chatMessages,
            feedbackData: feedbackData,
            behaviorEvents: behaviorEvents,
            metadata: metadata
        )
    }
    
    /// struct 모델로부터 엔티티 속성 업데이트
    func configure(with session: UnifiedSession) {
        self.id = UUID(uuidString: session.id) ?? UUID()
        self.createdAt = session.createdAt
        self.lastActivityAt = session.lastActivityAt
        self.metadataData = try? JSONEncoder().encode(session.metadata)
    }
}

extension StoredChatMessageEntity {
    /// Core Data 엔티티를 struct 모델로 변환
    func toStruct() -> StoredChatMessage {
        return StoredChatMessage(
            id: self.id.uuidString,
            timestamp: self.timestamp,
            role: self.role,
            content: self.content,
            type: .text // 기본값
        )
    }
    
    /// struct 모델로부터 엔티티 속성 업데이트
    func configure(with message: StoredChatMessage) {
        self.id = UUID(uuidString: message.id) ?? UUID()
        self.timestamp = message.timestamp
        self.role = message.role
        self.content = message.content
    }
}

extension PresetFeedbackEntity {
    /// Core Data 엔티티를 struct 모델로 변환
    func toStruct() -> PresetFeedback {
        return PresetFeedback(
            id: self.id,
            timestamp: self.timestamp,
            presetName: self.presetName,
            contextEmotion: "",
            contextTime: 0,
            recommendedVolumes: [],
            recommendedVersions: [],
            finalVolumes: [],
            listeningDuration: 0,
            wasSkipped: false,
            wasSaved: false,
            userSatisfaction: Int(self.rating),
            comment: self.comment
        )
    }
    
    /// struct 모델로부터 엔티티 속성 업데이트
    func configure(with feedback: PresetFeedback) {
        self.id = feedback.id
        self.timestamp = feedback.timestamp
        self.presetName = feedback.presetName ?? ""
        self.rating = Int16(feedback.userSatisfaction)
        self.comment = feedback.comment
    }
}

extension BehaviorEventEntity {
    /// Core Data 엔티티를 struct 모델로 변환
    func toStruct() -> BehaviorEvent {
        return BehaviorEvent(
            id: self.id.uuidString,
            type: BehaviorEventType(rawValue: self.eventType) ?? .presetStart,
            timestamp: self.timestamp,
            data: [:]
        )
    }
    
    /// struct 모델로부터 엔티티 속성 업데이트
    func configure(with event: BehaviorEvent) {
        self.id = UUID(uuidString: event.id) ?? UUID()
        self.timestamp = event.timestamp
        self.eventType = event.type.rawValue
        self.details = event.data.description
    }
}
