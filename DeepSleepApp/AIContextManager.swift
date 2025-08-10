//
//  AIContextManager.swift
//  DeepSleep
//
//  Created by System on 2025-01-20.
//  Copyright © 2025 DeepSleep. All rights reserved.
//

import Foundation

// MARK: - 필수 타입 참조 (같은 모듈 내 파일들)
// AIServiceTypes.swift에서 ConversationType 참조
// UserSettingsModel.swift에서 UserSettingsModel 참조
// SharedModels.swift에서 공통 타입들 참조

/// 🤖 **AI 컨텍스트 관리자**
/// 토큰 효율적인 시스템 프롬프트 및 사용자 정보 관리
public class AIContextManager {
    public static let shared = AIContextManager()
    
    private init() {}
    
    // MARK: - 📝 컨텍스트 캐싱
    
    /// 세션별 컨텍스트 캐시 (토큰 절약)
    private var sessionContext: [String: String] = [:]
    
    /// 마지막 컨텍스트 업데이트 시간
    private var lastContextUpdate: Date = Date()
    
    /// 컨텍스트 유효 시간 (3시간) - 토큰 절약을 위한 확장
    private let contextValidityDuration: TimeInterval = 3 * 60 * 60
    
    // MARK: - 🎭 역할 정의
    
    /// 압축된 역할 정의 (토큰 최적화)
    private var compactRoleDefinition: String {
        return """
        당신은 DeepSleep 앱의 '대나무숲 친구'입니다.
        - 역할: 수면과 휴식을 돕는 AI 친구
        - 말투: 친근하고 따뜻한 친구 같은 톤
        - 목표: 사용자의 숙면과 정서적 안정 지원
        """
    }
    
    /// 상세 역할 정의 (필요시에만 사용)
    private var detailedRoleDefinition: String {
        return """
        당신은 DeepSleep 앱의 '대나무숲 친구'입니다.
        
        🎭 **역할 정의**:
        - 이름: 대나무숲 친구 (사용자가 부르는 호칭)
        - 정체성: 수면과 휴식을 전문으로 하는 AI 친구
        - 성격: 따뜻하고 공감적이며 지혜로운 친구
        - 목표: 사용자의 숙면, 정서적 안정, 일상의 평온 지원
        
        🗣️ **대화 스타일**:
        - 친구처럼 편안하고 자연스러운 말투 사용
        - "~해요", "~네요" 등 정중하지만 친근한 존댓말
        - 공감과 격려를 중심으로 한 대화
        - 수면과 휴식에 관련된 조언과 팁 제공
        
        🎵 **앱 기능 이해**:
        - 사용자는 수면 사운드, 프리셋, 감정 일기 등을 사용
        - 대나무숲(채팅)에서 일상 고민과 수면 관련 상담
        - AI 분석을 통한 개인화된 추천과 조언 제공
        """
    }
    
    // MARK: - 👤 사용자 정보 관리
    
    /// 사용자 기본 정보를 압축된 형태로 생성
    func generateUserContext() -> String {
        // UserSettingsModel에서 사용자 정보 로드
        let userSettings = UserSettingsModel.loadFromUserDefaults()
        
        var context = "사용자 정보: "
        
        // 기본 정보 (간결하게) - 실제 프로퍼티 이름 사용
        if let age = userSettings.age, age > 0 {
            context += "\(age)세, "
        }
        
        // 수면 패턴 (핵심만) - 실제 프로퍼티 이름 확인 후 수정 필요
        // if !userSettings.sleepTime.isEmpty && !userSettings.wakeTime.isEmpty {
        //     context += "수면 \(userSettings.sleepTime)-\(userSettings.wakeTime), "
        // }
        
        // 음악 취향 (최대 2개만)
        if !userSettings.musicPreferences.isEmpty {
            let preferences = userSettings.musicPreferences.prefix(2).map { $0.rawValue }.joined(separator: ", ")
            context += "선호음악 \(preferences), "
        }
        
        // 기본 사용자 정보
        context += "DeepSleep 사용자"
        
        return context.trimmingCharacters(in: CharacterSet(charactersIn: ", "))
    }
    
    // MARK: - 🎯 컨텍스트 생성 전략
    
    /// 대화 유형별 최적화된 시스템 프롬프트 생성
    func generateSystemPrompt(for conversationType: ConversationType, isFirstMessage: Bool = false) -> String {
        var prompt = ""
        
        // 1. 역할 정의 (첫 메시지이거나 새 세션일 때만)
        if isFirstMessage || shouldRefreshContext() {
            prompt += compactRoleDefinition + "\n\n"
            
            // 2. 사용자 정보 (압축된 형태)
            let userContext = generateUserContext()
            if !userContext.isEmpty {
                prompt += userContext + "\n\n"
            }
            
            // 캐시 업데이트
            cacheContext(prompt, for: conversationType)
        } else {
            // 캐시된 컨텍스트 사용
            prompt = getCachedContext(for: conversationType) ?? compactRoleDefinition + "\n\n"
        }
        
        // 3. 대화 유형별 특화 지침 (항상 포함, 짧게)
        prompt += getConversationSpecificGuideline(for: conversationType)
        
        return prompt
    }
    
    /// 대화 유형별 특화 지침 (토큰 최적화)
    private func getConversationSpecificGuideline(for type: ConversationType) -> String {
        switch type {
        case .general:
            return "일상 대화로 편안하게 응답하세요."
        case .emotional:
            return "감정을 공감하고 위로의 말을 전하세요."
        case .task:
            return "생산성과 할 일 관리에 집중한 조언을 제공하세요."
        case .analysis:
            return "데이터를 분석하여 인사이트와 개선점을 제안하세요."
        }
    }
    
    // MARK: - 💾 캐싱 관리
    
    /// 컨텍스트 캐싱
    private func cacheContext(_ context: String, for type: ConversationType) {
        sessionContext[type.rawValue] = context
        lastContextUpdate = Date()
    }
    
    /// 캐시된 컨텍스트 조회
    private func getCachedContext(for type: ConversationType) -> String? {
        return sessionContext[type.rawValue]
    }
    
    /// 컨텍스트 새로고침 필요 여부
    private func shouldRefreshContext() -> Bool {
        return Date().timeIntervalSince(lastContextUpdate) > contextValidityDuration
    }
    
    /// 캐시 초기화 (사용자 정보 변경 시)
    func clearCache() {
        sessionContext.removeAll()
        lastContextUpdate = Date()
    }
    
    // MARK: - 📊 토큰 사용량 최적화
    
    /// 토큰 사용량 추정
    func estimateTokenUsage(for prompt: String) -> Int {
        // 대략적인 토큰 계산 (한글 1글자 ≈ 1.5토큰)
        return Int(Double(prompt.count) * 1.5)
    }
    
    /// 토큰 절약 모드 시스템 프롬프트 (긴급시)
    func generateMinimalPrompt() -> String {
        return "DeepSleep 대나무숲 친구. 수면 도움 AI. 친근한 톤."
    }
}

// MARK: - 📝 대화 유형 정의
// ConversationType은 AIServiceTypes.swift에 정의됨

// MARK: - 🎯 사용 예시 및 가이드

/*
사용 예시:

// 1. 일반 대화 시작
let systemPrompt = AIContextManager.shared.generateSystemPrompt(
    for: .general, 
    isFirstMessage: true
)

// 2. 연속 대화 (캐시 활용)
let followUpPrompt = AIContextManager.shared.generateSystemPrompt(
    for: .general, 
    isFirstMessage: false
)

// 3. 사용자 정보 변경 후 캐시 초기화
AIContextManager.shared.clearCache()

// 4. 토큰 절약 모드
let minimalPrompt = AIContextManager.shared.generateMinimalPrompt()

토큰 절약 전략:
1. 첫 메시지에만 전체 컨텍스트 포함
2. 연속 대화는 캐시된 컨텍스트 재사용
3. 30분 후 자동 갱신
4. 대화 유형별 특화된 짧은 지침
5. 사용자 정보는 핵심만 압축하여 포함
*/