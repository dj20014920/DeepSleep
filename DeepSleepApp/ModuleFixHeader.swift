//
//  ModuleFixHeader.swift  
//  DeepSleep
//
//  Module 타입 참조 문제 해결을 위한 헤더 파일
//  Created by Claude (DeepSleep AI Project) on 2025-07-25
//

import Foundation

// MARK: - 🔗 Module Type References Fix
// 이 파일은 Swift 컴파일러가 모든 타입을 올바르게 인식하도록 돕는 참조 헤더입니다.

// PERF-WARNING: 이 파일은 컴파일 시간을 약간 증가시킬 수 있음
// 확인 방법: Xcode Build Timeline에서 컴파일 시간 측정

/*
 💡 Swift Module System 해결 방식:
 
 1. 같은 모듈 내 타입들은 자동으로 import되어야 하지만,
    Xcode 프로젝트 설정이나 파일 순서 문제로 인식 실패할 수 있음
    
 2. 이 파일에서 모든 핵심 타입들을 한 번에 참조함으로써
    Swift 컴파일러가 타입 해결 순서를 최적화할 수 있도록 도움
    
 3. 각 소스 파일에서 개별적으로 타입을 찾는 대신,
    이미 해결된 타입 정보를 재사용할 수 있음
*/

// MARK: - AI Service Types (from AIServiceTypes.swift)
typealias _SecurityValidationResult = SecurityValidationResult
typealias _ConversationType = ConversationType
typealias _AIModel = AIModel
typealias _AIMode = AIMode
typealias _AIServiceError = AIServiceError
typealias _MessageSender = MessageSender

// MARK: - Chat Models (from SharedModels.swift)
typealias _ChatMessage = ChatMessage
typealias _ChatMessageType = ChatMessageType

// MARK: - User Settings (from UserSettingsModel.swift)
typealias _UserSettingsModel = UserSettingsModel

// MARK: - AI Service Classes (확실한 참조를 위해)
// UnifiedAIServiceImpl은 AI/Services/UnifiedAIServiceImpl.swift에 정의됨
// AICallLogger는 AI/Logging/AICallLogger.swift에 정의됨
// UsageLimitManager는 AI/UsageLimitManager.swift에 정의됨

// MARK: - Module Validation
// 이 extension들은 타입이 올바르게 로드되었는지 컴파일 타임에 검증합니다.
private extension SecurityValidationResult {
    static func _moduleTest() { print("SecurityValidationResult loaded") }
}

private extension ConversationType {
    static func _moduleTest() { print("ConversationType loaded") }
}

private extension ChatMessage {
    static func _moduleTest() { print("ChatMessage loaded") }
}

private extension UserSettingsModel {
    static func _moduleTest() { print("UserSettingsModel loaded") }
}

// 컴파일 타임 검증: 이 함수가 컴파일되면 모든 타입이 올바르게 인식됨
private func _verifyAllTypesLoaded() {
    let _: SecurityValidationResult? = nil
    let _: ConversationType? = nil
    let _: ChatMessage? = nil
    let _: ChatMessageType? = nil
    let _: MessageSender? = nil
    let _: UserSettingsModel? = nil
    let _: AIModel? = nil
    let _: AIMode? = nil
    let _: AIServiceError? = nil
}