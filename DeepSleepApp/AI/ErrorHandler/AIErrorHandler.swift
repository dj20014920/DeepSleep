//
//  AIErrorHandler.swift
//  DeepSleep
//
//  Created by Claude on 2025-07-23.
//  Copyright © 2025 DeepSleep. All rights reserved.
//

import UIKit
import Foundation

/// 🚨 AI 에러 처리 전용 헬퍼 클래스
/// 통합 아키텍처의 일관된 에러 처리를 담당
public final class AIErrorHandler {
    
    public static let shared = AIErrorHandler()
    private init() {}
    
    // MARK: - 🎨 사용자 친화적인 에러 알림
    
    /// 표준화된 AI 에러 알림 표시
    /// - Parameters:
    ///   - error: AI 서비스 에러
    ///   - in: 표시할 ViewController
    ///   - retryHandler: 재시도 핸들러 (선택사항)
    public func showError(
        _ error: AIServiceError,
        in viewController: UIViewController,
        retryHandler: (() -> Void)? = nil
    ) {
        let alert = UIAlertController(
            title: error.shortTitle,
            message: formatErrorMessage(error),
            preferredStyle: .alert
        )
        
        // requiresOnDeviceSetup → "친구 선택" 바로가기 제공
        if case .requiresOnDeviceSetup = error {
            alert.addAction(UIAlertAction(title: "친구 선택", style: .default) { _ in
                // 현재 VC가 이미 선택 화면이면 무시
                if viewController is AIModelSelectionViewController { return }
                let selector = AIModelSelectionViewController()
                if let nav = viewController.navigationController {
                    nav.pushViewController(selector, animated: true)
                } else {
                    let nav = UINavigationController(rootViewController: selector)
                    nav.modalPresentationStyle = .automatic
                    viewController.present(nav, animated: true)
                }
            })
        }
        
        // 확인 버튼 (항상 존재)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        
        // 재시도 버튼 (핸들러가 있는 경우)
        if let retryHandler = retryHandler {
            alert.addAction(UIAlertAction(title: "다시 시도", style: .default) { _ in
                retryHandler()
            })
        }
        
        // 설정 이동 버튼 (설정 관련 에러의 경우)
        if case .unauthorized = error {
            alert.addAction(UIAlertAction(title: "설정 열기", style: .default) { _ in
                self.openSettings()
            })
        }
        
        DispatchQueue.main.async {
            viewController.present(alert, animated: true)
        }
        
        // 에러 로깅
        logError(error)
    }
    
    /// 간단한 토스트 메시지로 에러 표시 (덜 중요한 에러용)
    /// - Parameters:
    ///   - error: AI 서비스 에러
    ///   - in: 표시할 ViewController
    public func showToast(
        _ error: AIServiceError,
        in viewController: UIViewController
    ) {
        let message = error.shortTitle
        
        DispatchQueue.main.async {
            // UIViewController+Toast 확장이 있다면 사용
            if viewController.responds(to: Selector(("showToast:message:"))) {
                viewController.perform(Selector(("showToast:message:")), with: message)
            } else {
                // 기본 알림으로 fallback
                self.showError(error, in: viewController)
            }
        }
        
        // 에러 로깅
        logError(error)
    }
    
    // MARK: - 🔧 에러 메시지 포매팅
    
    private func formatErrorMessage(_ error: AIServiceError) -> String {
        var message = error.localizedDescription
        
        if let suggestion = error.recoverySuggestion {
            message += "\n\n💡 해결 방법:\n\(suggestion)"
        }
        
        return message
    }
    
    // MARK: - 📊 에러 로깅
    
    private func logError(_ error: AIServiceError) {
        let errorInfo = [
            "error_type": String(describing: error),
            "error_description": error.localizedDescription ?? "Unknown",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        print("🚨 [AIErrorHandler] AI 에러 발생: \(errorInfo)")
        
        // TODO: 실제 로깅 시스템 (Firebase Crashlytics, 자체 로깅 서버 등)과 연동
        // AnalyticsManager.shared.logError(error: error, context: errorInfo)
    }
    
    // MARK: - 🔄 자동 복구 시도
    
    /// 특정 에러에 대해 자동 복구를 시도
    /// - Parameters:
    ///   - error: AI 서비스 에러
    ///   - retryAction: 재시도할 액션
    /// - Returns: 자동 복구가 시도되었는지 여부
    public func attemptAutoRecovery(
        for error: AIServiceError,
        retryAction: @escaping () async throws -> Void
    ) -> Bool {
        switch error {
        case .rateLimitExceeded:
            // 1분 후 자동 재시도
            Task {
                try await Task.sleep(nanoseconds: 60_000_000_000) // 60초
                try await retryAction()
            }
            return true
            
        case .timeoutError:
            // 즉시 재시도
            Task {
                try await retryAction()
            }
            return true
            
        case .networkError:
            // 네트워크 상태 확인 후 재시도
            if isNetworkAvailable() {
                Task {
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2초 대기
                    try await retryAction()
                }
                return true
            }
            return false
            
        default:
            return false
        }
    }
    
    // MARK: - 🔧 유틸리티 메서드
    
    private func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func isNetworkAvailable() -> Bool {
        // 간단한 네트워크 체크 (실제로는 Reachability 라이브러리 사용 권장)
        return true // 임시 구현
    }
}

// MARK: - 🎨 UIViewController 확장

extension UIViewController {
    
    /// AI 에러를 표준화된 방식으로 표시하는 편의 메서드
    /// - Parameters:
    ///   - error: AI 서비스 에러
    ///   - retryHandler: 재시도 핸들러 (선택사항)
    public func showAIError(
        _ error: AIServiceError,
        retryHandler: (() -> Void)? = nil
    ) {
        AIErrorHandler.shared.showError(error, in: self, retryHandler: retryHandler)
    }
    
    /// AI 에러를 토스트로 표시하는 편의 메서드
    /// - Parameter error: AI 서비스 에러
    public func showAIErrorToast(_ error: AIServiceError) {
        AIErrorHandler.shared.showToast(error, in: self)
    }
}

// MARK: - 🚨 에러 복구 전략

/// 에러 복구 전략 정의
public enum ErrorRecoveryStrategy {
    case showAlert
    case showToast
    case autoRetry(delay: TimeInterval)
    case fallbackToOffline
    case showRetryButton
}

extension AIServiceError {
    
    /// 각 에러 타입별 권장 복구 전략
    public var recommendedRecoveryStrategy: ErrorRecoveryStrategy {
        switch self {
        case .usageLimitExceeded, .quotaExceeded:
            return .showAlert
        case .rateLimitExceeded:
            return .autoRetry(delay: 60)
        case .timeoutError:
            return .autoRetry(delay: 2)
        case .networkError:
            return .showRetryButton
        case .configurationError, .unauthorized:
            return .showAlert
        default:
            return .showRetryButton
        }
    }
}