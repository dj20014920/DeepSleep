import Foundation
import CoreData

/// Core Data 스택 관리자 - 프로그래매틱 모델 생성 방식
public class CoreDataStack {
    public static let shared = CoreDataStack()
    
    private init() {}
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        // 프로그래매틱하게 모델 생성
        let managedObjectModel = createManagedObjectModel()
        let container = NSPersistentContainer(name: "DeepSleep", managedObjectModel: managedObjectModel)
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("❌ [CoreDataStack] Core Data 초기화 실패: \(error), \(error.userInfo)")
                // 프로덕션에서는 더 우아한 에러 처리 필요
            }
        }
        
        // 자동 병합 정책 설정
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Core Data Saving Support
    
    func saveContext() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                print("✅ [CoreDataStack] 컨텍스트 저장 성공")
            } catch {
                print("❌ [CoreDataStack] 컨텍스트 저장 실패: \(error)")
                // 프로덕션에서는 더 정교한 에러 처리 필요
            }
        }
    }
    
    /// 에러를 전파하는 저장 메서드 (프로덕션 안정성)
    func saveContextWithError() throws {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                print("✅ [CoreDataStack] 컨텍스트 저장 성공")
            } catch {
                print("❌ [CoreDataStack] 컨텍스트 저장 실패: \(error)")
                throw SessionManagerError.saveFailure(underlying: error)
            }
        }
    }
    
    // MARK: - Background Context
    
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }
    
    // MARK: - Programmatic Model Creation
    
    private func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // 엔티티들 생성
        let unifiedSessionEntity = createUnifiedSessionEntity()
        let chatMessageEntity = createChatMessageEntity()
        let feedbackEntity = createFeedbackEntity()
        let behaviorEventEntity = createBehaviorEventEntity()
        
        // 관계 설정
        setupRelationships(
            unifiedSession: unifiedSessionEntity,
            chatMessage: chatMessageEntity,
            feedback: feedbackEntity,
            behaviorEvent: behaviorEventEntity
        )
        
        // 모델에 엔티티 추가
        model.entities = [
            unifiedSessionEntity,
            chatMessageEntity,
            feedbackEntity,
            behaviorEventEntity
        ]
        
        return model
    }
    
    private func createUnifiedSessionEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "UnifiedSessionEntity"
        entity.managedObjectClassName = "UnifiedSessionEntity"
        
        // 속성들 정의
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .UUIDAttributeType
        idAttribute.isOptional = false
        
        let createdAtAttribute = NSAttributeDescription()
        createdAtAttribute.name = "createdAt"
        createdAtAttribute.attributeType = .dateAttributeType
        createdAtAttribute.isOptional = false
        createdAtAttribute.isIndexed = true
        
        let lastActivityAtAttribute = NSAttributeDescription()
        lastActivityAtAttribute.name = "lastActivityAt"
        lastActivityAtAttribute.attributeType = .dateAttributeType
        lastActivityAtAttribute.isOptional = false
        
        let metadataAttribute = NSAttributeDescription()
        metadataAttribute.name = "metadataData"
        metadataAttribute.attributeType = .binaryDataAttributeType
        metadataAttribute.isOptional = true
        
        entity.properties = [
            idAttribute,
            createdAtAttribute,
            lastActivityAtAttribute,
            metadataAttribute
        ]
        
        return entity
    }
    
    private func createChatMessageEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "StoredChatMessageEntity"
        entity.managedObjectClassName = "StoredChatMessageEntity"
        
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .UUIDAttributeType
        idAttribute.isOptional = false
        
        let timestampAttribute = NSAttributeDescription()
        timestampAttribute.name = "timestamp"
        timestampAttribute.attributeType = .dateAttributeType
        timestampAttribute.isOptional = false
        timestampAttribute.isIndexed = true
        
        let roleAttribute = NSAttributeDescription()
        roleAttribute.name = "role"
        roleAttribute.attributeType = .stringAttributeType
        roleAttribute.isOptional = false
        
        let contentAttribute = NSAttributeDescription()
        contentAttribute.name = "content"
        contentAttribute.attributeType = .stringAttributeType
        contentAttribute.isOptional = false
        
        entity.properties = [
            idAttribute,
            timestampAttribute,
            roleAttribute,
            contentAttribute
        ]
        
        return entity
    }
    
    private func createFeedbackEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "PresetFeedbackEntity"
        entity.managedObjectClassName = "PresetFeedbackEntity"
        
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .UUIDAttributeType
        idAttribute.isOptional = false
        
        let timestampAttribute = NSAttributeDescription()
        timestampAttribute.name = "timestamp"
        timestampAttribute.attributeType = .dateAttributeType
        timestampAttribute.isOptional = false
        
        let presetNameAttribute = NSAttributeDescription()
        presetNameAttribute.name = "presetName"
        presetNameAttribute.attributeType = .stringAttributeType
        presetNameAttribute.isOptional = false
        
        let ratingAttribute = NSAttributeDescription()
        ratingAttribute.name = "rating"
        ratingAttribute.attributeType = .integer16AttributeType
        ratingAttribute.isOptional = false
        
        let commentAttribute = NSAttributeDescription()
        commentAttribute.name = "comment"
        commentAttribute.attributeType = .stringAttributeType
        commentAttribute.isOptional = true
        
        entity.properties = [
            idAttribute,
            timestampAttribute,
            presetNameAttribute,
            ratingAttribute,
            commentAttribute
        ]
        
        return entity
    }
    
    private func createBehaviorEventEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "BehaviorEventEntity"
        entity.managedObjectClassName = "BehaviorEventEntity"
        
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .UUIDAttributeType
        idAttribute.isOptional = false
        
        let timestampAttribute = NSAttributeDescription()
        timestampAttribute.name = "timestamp"
        timestampAttribute.attributeType = .dateAttributeType
        timestampAttribute.isOptional = false
        
        let eventTypeAttribute = NSAttributeDescription()
        eventTypeAttribute.name = "eventType"
        eventTypeAttribute.attributeType = .stringAttributeType
        eventTypeAttribute.isOptional = false
        
        let detailsAttribute = NSAttributeDescription()
        detailsAttribute.name = "details"
        detailsAttribute.attributeType = .stringAttributeType
        detailsAttribute.isOptional = true
        
        entity.properties = [
            idAttribute,
            timestampAttribute,
            eventTypeAttribute,
            detailsAttribute
        ]
        
        return entity
    }
    
    private func setupRelationships(
        unifiedSession: NSEntityDescription,
        chatMessage: NSEntityDescription,
        feedback: NSEntityDescription,
        behaviorEvent: NSEntityDescription
    ) {
        // UnifiedSession -> ChatMessages (One-to-Many)
        let sessionToChatMessages = NSRelationshipDescription()
        sessionToChatMessages.name = "chatMessages"
        sessionToChatMessages.destinationEntity = chatMessage
        sessionToChatMessages.deleteRule = .cascadeDeleteRule
        sessionToChatMessages.isOptional = true
        
        let chatMessageToSession = NSRelationshipDescription()
        chatMessageToSession.name = "session"
        chatMessageToSession.destinationEntity = unifiedSession
        chatMessageToSession.deleteRule = .nullifyDeleteRule
        chatMessageToSession.isOptional = true
        chatMessageToSession.maxCount = 1
        
        sessionToChatMessages.inverseRelationship = chatMessageToSession
        chatMessageToSession.inverseRelationship = sessionToChatMessages
        
        // UnifiedSession -> Feedback (One-to-Many)
        let sessionToFeedback = NSRelationshipDescription()
        sessionToFeedback.name = "feedbackData"
        sessionToFeedback.destinationEntity = feedback
        sessionToFeedback.deleteRule = .cascadeDeleteRule
        sessionToFeedback.isOptional = true
        
        let feedbackToSession = NSRelationshipDescription()
        feedbackToSession.name = "session"
        feedbackToSession.destinationEntity = unifiedSession
        feedbackToSession.deleteRule = .nullifyDeleteRule
        feedbackToSession.isOptional = true
        feedbackToSession.maxCount = 1
        
        sessionToFeedback.inverseRelationship = feedbackToSession
        feedbackToSession.inverseRelationship = sessionToFeedback
        
        // UnifiedSession -> BehaviorEvents (One-to-Many)
        let sessionToBehaviorEvents = NSRelationshipDescription()
        sessionToBehaviorEvents.name = "behaviorEvents"
        sessionToBehaviorEvents.destinationEntity = behaviorEvent
        sessionToBehaviorEvents.deleteRule = .cascadeDeleteRule
        sessionToBehaviorEvents.isOptional = true
        
        let behaviorEventToSession = NSRelationshipDescription()
        behaviorEventToSession.name = "session"
        behaviorEventToSession.destinationEntity = unifiedSession
        behaviorEventToSession.deleteRule = .nullifyDeleteRule
        behaviorEventToSession.isOptional = true
        behaviorEventToSession.maxCount = 1
        
        sessionToBehaviorEvents.inverseRelationship = behaviorEventToSession
        behaviorEventToSession.inverseRelationship = sessionToBehaviorEvents
        
        // 엔티티에 관계 추가
        unifiedSession.properties.append(contentsOf: [
            sessionToChatMessages,
            sessionToFeedback,
            sessionToBehaviorEvents
        ])
        
        chatMessage.properties.append(chatMessageToSession)
        feedback.properties.append(feedbackToSession)
        behaviorEvent.properties.append(behaviorEventToSession)
    }
}