//
//  LLMService.swift
//  DeepSleep
//
//  Created by AI on 2025/06/28.
//

import Foundation

/// 모든 LLM 서비스가 준수해야 하는 프로토콜입니다.
/// 이 프로토콜은 다양한 AI 모델(Claude, Gemini, On-Device 등)을
/// 일관된 방식으로 호출하고 관리할 수 있도록 추상화 계층을 제공합니다.
public protocol LLMService {
    /// 주어진 프롬프트에 대한 응답을 비동기적으로 생성합니다.
    ///
    /// - Parameters:
    ///   - prompt: AI 모델에 전달할 텍스트 프롬프트.
    /// - Returns: AI 모델이 생성한 응답 문자열.
    /// - Throws: API 통신 오류, 데이터 파싱 오류 등 서비스별로 발생할 수 있는 에러.
    func generateResponse(prompt: String) async throws -> String
} 