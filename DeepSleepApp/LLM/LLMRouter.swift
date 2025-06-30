//
//  LLMRouter.swift
//  DeepSleep
//
//  Created by AI on 2025/06/28.
//

import Foundation
import OSLog

/// `LLMRouter`는 모든 AI 관련 요청을 처리하는 중앙 컨트롤 타워입니다.
/// `AITask`를 입력받아, 사용자의 모델 선택, OS 버전, 기타 시스템 상태를 종합적으로 고려하여
/// 최적의 `LLMService`로 요청을 라우팅합니다.
public final class LLMRouter {
    
    public static let shared = LLMRouter()
    
    private let logger = Logger(subsystem: "com.deepsleep.app", category: "LLMRouter")
    private let settingsManager = SettingsManager.shared
    
    // `LLMServiceFactory`를 통해 서비스 인스턴스를 동적으로 가져옵니다.
    private let serviceFactory: LLMServiceFactory
    
    private init(serviceFactory: LLMServiceFactory = .shared) {
        self.serviceFactory = serviceFactory
    }
    
    /// 주어진 `AITask`를 조건에 맞는 최적의 LLM 서비스로 전달하여 응답을 생성합니다.
    ///
    /// - Parameter task: AI에게 요청할 작업 명세서 (`AITask`).
    /// - Returns: LLM의 응답을 담은 `LLMResponseEntity`.
    public func send(task: AITask) async throws -> String {
        let service = try selectService(for: task)
        let serviceName = String(describing: type(of: service))
        
        logger.info("Routing task '\(String(describing: task))' to \(serviceName)")
        
        do {
            // TODO: - LLMService의 generateResponse가 AITask를 직접 받도록 수정 필요
            // 우선은 기존 인터페이스에 맞추어 userPrompt를 전달합니다.
            let response = try await service.generateResponse(prompt: task.userPrompt)
            
            logger.info("Successfully received response from \(serviceName)")
            return response
        } catch {
            logger.error("LLM service '\(serviceName)' failed: \(error.localizedDescription).")
            // TODO: - 실패 시 예비 서비스(fallback)로 재시도하는 로직 구현
            throw error
        }
    }
    
    /// `AITask`에 가장 적합한 `LLMService`를 선택합니다.
    private func selectService(for task: AITask) throws -> LLMService {
        // TODO: - 온디바이스 모델 정책 확정 필요 (예: 특정 Task는 무조건 온디바이스)
        // 예를 들어, 간단한 텍스트 분류나 요약 등은 온디바이스가 적합할 수 있습니다.
        
        // 1순위: iOS 18 이상이며, 온디바이스 모델이 사용 가능한 경우 (향후 구현)
        if #available(iOS 18.0, *), settingsManager.useOnDeviceModelIfNeeded {
             logger.info("Attempting to use On-Device model for iOS 18+.")
             // return try serviceFactory.createService(for: .onDevice)
        }
        
        // 2순위: 사용자가 설정에서 선택한 모델
        let selectedModelType = settingsManager.selectedLLM
        logger.info("User-selected model is '\(String(describing: selectedModelType))'. Routing to corresponding service.")
        return try serviceFactory.createService(for: selectedModelType)
    }
} 