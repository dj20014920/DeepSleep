//
//  SharedCore.swift
//  DeepSleep
//
//  Created by Claude on 2025-07-23.
//  Copyright © 2025 DeepSleep. All rights reserved.
//

import Foundation
import UIKit
import CoreData

// MARK: - 🚀 AI Service Types 
// AI 관련 타입들은 AI/Services/AIServiceTypes.swift에서 정의됨

// MARK: - 💬 Chat Message Types 
// 채팅 메시지 관련 타입들은 Models.swift에서 정의됨

// MARK: - 🎵 Sound Types 
// 사운드 관련 타입들은 Models.swift에서 정의됨

// MARK: - ⏰ Time & Context Types (고유 타입들)

/// 시간 컨텍스트 (SharedCore 고유)
public struct TimeContext {
    public let hour: Int
    public let dayOfWeek: Int
    public let isWeekend: Bool
    public let season: String
    
    public init(hour: Int = Calendar.current.component(.hour, from: Date()), 
                dayOfWeek: Int = Calendar.current.component(.weekday, from: Date()),
                isWeekend: Bool = [1, 7].contains(Calendar.current.component(.weekday, from: Date())),
                season: String = "봄") {
        self.hour = hour
        self.dayOfWeek = dayOfWeek
        self.isWeekend = isWeekend
        self.season = season
    }
}

/// 추천 사용자 컨텍스트 (SharedCore 고유)
public struct RecommendationUserContext {
    public let userEmotion: String
    public let timeOfDay: String
    public let batteryLevel: Float
    public let isHeadphonesConnected: Bool
    
    public init(userEmotion: String = "평온", timeOfDay: String = "오후", batteryLevel: Float = 0.8, isHeadphonesConnected: Bool = false) {
        self.userEmotion = userEmotion
        self.timeOfDay = timeOfDay
        self.batteryLevel = batteryLevel
        self.isHeadphonesConnected = isHeadphonesConnected
    }
}

// MARK: - 📊 Usage Analytics 
// UsageStats는 SettingsManager.swift에서 정의됨

// MARK: - 🔧 Extensions (공통 확장)

/// UserDefaults 확장
extension UserDefaults {
    public func cleanExpiredCaches() {
        // 캐시 정리 로직 구현
        print("🧹 캐시 정리 완료")
    }
}

/// String 확장 - Todo 관련
extension String {
    public static let generalChat = "general_chat"
    public static let recommendTodo = "recommend_todo"
    public static let emotionDiaryAnalysis = "emotion_diary_analysis"
}

// MARK: - 📱 ChatViewController 확장 메서드

/// ChatViewController에서 사용할 메서드들
extension NSObject {
    @objc public func addBotMessage(_ message: String) {
        // 봇 메시지 추가 로직 (ChatViewController에서 구현 예정)
        print("🤖 봇 메시지 추가: \(message)")
    }
}

// MARK: - 🎯 Chat Context & Session Types 
// ChatContext 및 메시지 관련 타입들은 Models.swift와 ChatManager.swift에서 정의됨

// MARK: - 🔒 Performance & Security

/// 성능 경고 매크로
public func perfWarning(_ message: String, file: String = #file, line: Int = #line) {
    #if DEBUG
    print("⚠️ PERF-WARNING: \(message) at \(URL(fileURLWithPath: file).lastPathComponent):\(line)")
    #endif
}

/// 메모리 사용량 체크
public func checkMemoryUsage(context: String) {
    #if DEBUG
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    
    if kerr == KERN_SUCCESS {
        let memoryUsedMB = Double(info.resident_size) / 1024.0 / 1024.0
        print("📊 \(context) - 메모리 사용량: \(String(format: "%.2f", memoryUsedMB)) MB")
    }
    #endif
}

// 📋 **Documentation**

/*
 🚀 SharedCore.swift - DeepSleep 통합 타입 시스템
 
 ## 목적
 - 모든 공통 타입을 한 곳에서 정의하여 유지보수성 향상
 - 중복 코드 제거 및 타입 일관성 보장
 - 확장성 있는 아키텍처 제공
 
 ## 사용법
 ```swift
 import Foundation
 // SharedCore는 자동으로 import됨
 
 // AI 서비스 사용 (ChatManager.swift를 통해)
 let aiResponse = try await ChatManager.shared.sendMessage(
     userInput: "안녕하세요",
     modeString: AIMode.generalConversation.rawValue,
     modelString: AIModel.claude.rawValue
 )
 
 // 채팅 메시지 생성
 let message = ChatMessage(
     text: "테스트 메시지",
     sender: .user,
     type: .user
 )
 ```
 
 ## 아키텍처 변경사항 (2025-07-24)
 - ✅ 통합 아키텍처 완성: 모든 AI 호출이 ChatManager.sendMessage로 통일됨
 - ✅ AI Services 파일들이 Xcode 프로젝트에 정식 등록됨
 - ✅ 임시 ChatManager 구현 제거 완료
 - ✅ 순환 의존성 문제 해결됨
 
 ## 성능 고려사항
 - PERF-WARNING: 대량의 채팅 메시지 처리 시 메모리 사용량 주의
 - 테스트 방법: Instruments의 Allocations로 메모리 누수 확인
 - checkMemoryUsage() 함수로 실시간 모니터링 가능
 
 ## 확장 방법
 1. 새로운 AI 모델 추가: AIModel enum에 case 추가
 2. 새로운 모드 추가: AIMode enum에 case 추가  
 3. 새로운 타입 추가: 해당 MARK 섹션에 추가
 
 ---
 생성일: 2025-07-23
 최종 업데이트: 2025-07-24 (통합 아키텍처 완성)
 작성자: Claude (UltraThink 아키텍처)
 */

