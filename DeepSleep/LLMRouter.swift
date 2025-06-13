import Foundation
import os

/// LLM 라우팅 및 분기 관리 (Foundation ↔ Claude 3.5)
public final class LLMRouter {
    /// LLM 종류
    public enum ModelType {
        case foundation
        case claude
    }
    /// 라우팅 결과
    public struct RoutingResult {
        public let model: ModelType
        public let reason: String
    }
    /// iOS 버전, 프롬프트, 출력 특성에 따라 라우팅 결정
    /// - Parameters:
    ///   - prompt: 입력 프롬프트
    ///   - outputHint: 예상 출력(길이, 코드블록 등)
    /// - Returns: RoutingResult (모델, 사유)
    public static func route(prompt: String, outputHint: String? = nil) -> RoutingResult {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        // iOS 26 이상: Foundation 우선
        if osVersion >= 26 {
            // 출력 길이 1000자 초과 또는 코드블록 포함 시 Claude fallback
            if let hint = outputHint, (hint.count > 1000 || hint.contains("```")) {
                return RoutingResult(model: .claude, reason: "output > 1000자 or 코드블록 포함")
            }
            return RoutingResult(model: .foundation, reason: "iOS 26 이상, Foundation 우선")
        } else {
            return RoutingResult(model: .claude, reason: "iOS 26 미만, Claude fallback")
        }
    }
} 