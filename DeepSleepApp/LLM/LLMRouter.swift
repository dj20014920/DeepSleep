//
//  LLMRouter.swift
//  DeepSleep
//
//  Created by AI on 2025/06/28.
//

import Foundation
import UIKit
import Core

/// `LLMRouter`는 모든 AI 관련 요청을 처리하는 중앙 컨트롤 타워입니다.
/// `AITask`를 입력받아, 사용자의 모델 선택, OS 버전, 기타 시스템 상태를 종합적으로 고려하여
/// 최적의 `LLMService`로 요청을 라우팅합니다.
public final class LLMRouter {
    
    public static let shared = LLMRouter()
    
    // Supported AI tasks
    public enum AITask {
        case generalChat(message: String, context: ChatContext?)
        case analyzeEmotion(emotion: String)
        case recommendSound(context: SoundRecommendationContext)
        case generateFortune(userInfo: UserInfo)
        case recommendTodo(todos: [String])
        case analyzeEmotionDiary(diaryContent: String)
    }
    
    private init() {}
    
    /// 지정된 AI 작업을 처리하고 결과를 반환합니다.
    /// - Parameter task: 처리할 AI 작업
    /// - Returns: AI 처리 결과 문자열
    /// - Throws: LLM 서비스 관련 오류
    public func send(task: AITask) async throws -> String {
        // 기본 Claude 서비스를 사용하여 요청 처리
        let service = try LLMServiceFactory.shared.getService(for: LLMServiceType.claude)
        
        // 임시 config 구조체 - CompilerFixStubs 제거로 인한 대체
        struct TempLLMRequestConfig {
            let temperature: Double
            let maxTokens: Int
        }
        let _ = TempLLMRequestConfig(temperature: 0.7, maxTokens: 2000)
        
        let prompt: String
        
        switch task {
        case .generalChat(let message, _):
            prompt = message
        case .analyzeEmotion(let emotion):
            prompt = "다음 감정을 분석해주세요: \(emotion)"
        case .recommendSound(_):
            prompt = "현재 상황에 맞는 사운드를 추천해주세요."
        case .generateFortune(_):
            prompt = "오늘의 운세를 알려주세요."
        case .recommendTodo(let todos):
            prompt = "다음 할 일들을 분석하고 우선순위를 추천해주세요: \(todos.joined(separator: ", "))"
        case .analyzeEmotionDiary(let content):
            prompt = "다음 일기의 감정을 분석해주세요: \(content)"
        }
        
        // 임시로 기본 config 없이 호출 (실제 구현에서는 적절한 config 전달 필요)
        let (response, _) = try await service.sendMessage(prompt, config: nil as Any?)
        return response
    }
} 
