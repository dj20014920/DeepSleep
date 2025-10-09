//
//  AIResponseHelpers.swift
//  DeepSleep
//
//  Created by AI Security Team on 2025-01-26.
//  Copyright © 2025 DeepSleep. All rights reserved.
//

import Foundation

/// 🔧 **AI 응답 처리 헬퍼 유틸리티**
///
/// **목적:**
/// - AIModel 타입을 OnDeviceModelID로 변환
/// - 모델별 특수 토큰 처리를 위한 매핑 제공
/// - DRY: 모델 판별 로직 중앙화
///
/// **설계 원칙:**
/// - SSOT: 모델 타입 매핑의 단일 출처
/// - KISS: 간단하고 명확한 변환 로직
/// - 빠른 실행: 최소한의 연산
public enum AIResponseHelpers {

    // MARK: - Model Type Detection

    /// AIModel을 OnDeviceModelID로 변환
    ///
    /// - Parameter model: AI 모델 타입
    /// - Returns: 온디바이스 모델 ID (온디바이스 모델인 경우), nil (API 모델인 경우)
    public static func onDeviceModelID(from model: AIModel) -> OnDeviceModelID? {
        switch model {
        case .onDevice:
            // 현재 활성화된 온디바이스 모델 ID를 가져옴
            // 기본값: hcx05b_q4_k_m (가장 많이 사용되는 모델)
            return getActiveOnDeviceModelID()
        default:
            // 클라우드 모델은 더 이상 사용하지 않음
            return nil
        }
    }

    /// 현재 활성화된 온디바이스 모델 ID 가져오기
    ///
    /// - Returns: 현재 사용 중인 모델 ID, 없으면 기본 모델
    private static func getActiveOnDeviceModelID() -> OnDeviceModelID {
        // UserDefaults에서 선택된 모델 확인
        if let savedModelName = UserDefaults.standard.string(forKey: "selectedOnDeviceModel") {
            // 저장된 모델명을 OnDeviceModelID로 변환
            switch savedModelName {
            case "amoral_gemma3_1b_v2_q5_k_m", "amoral-gemma3-1B-v2-Q5_K_M.gguf":
                return .amoral_gemma3_1b_v2_q5_k_m
            case "hyperclovax-seed-text-instruct-0.5b-q4_k_m.gguf":
                return .hyperclovax_seed_text_instruct_0_5b_q4_k_m
            case "hyperclovax-seed-text-instruct-0.5b-q8_0.gguf":
                return .hyperclovax_seed_text_instruct_0_5b_q8_0
            case "hyperclovax-seed-text-instruct-1.5b-q4_k_m.gguf":
                return .hyperclovax_seed_text_instruct_1_5b_q4_k_m
            default:
                break
            }
        }

        // 기본값: HyperCLOVA X 0.5B Q4_K_M (가장 일반적)
        return .hyperclovax_seed_text_instruct_0_5b_q4_k_m
    }

    // MARK: - Model Capability Detection

    /// 모델이 온디바이스인지 확인
    ///
    /// - Parameter model: AI 모델 타입
    /// - Returns: 온디바이스 여부
    public static func isOnDeviceModel(_ model: AIModel) -> Bool {
        switch model {
        case .onDevice:
            return true
        default:
            return false
        }
    }

    /// 모델이 API 기반인지 확인
    ///
    /// - Parameter model: AI 모델 타입
    /// - Returns: API 기반 여부
    public static func isAPIModel(_ model: AIModel) -> Bool {
        return !isOnDeviceModel(model)
    }

    // MARK: - Sanitization Support

    /// 응답 정화 시 사용할 모델 ID 결정
    ///
    /// - Parameter model: AI 모델 타입
    /// - Returns: 정화에 사용할 OnDeviceModelID (API 모델은 기본값 반환)
    ///
    /// - Note: API 모델도 기본 온디바이스 모델 ID를 반환하여 일관된 특수 토큰 제거
    public static func modelIDForSanitization(_ model: AIModel) -> OnDeviceModelID {
        return onDeviceModelID(from: model) ?? .hyperclovax_seed_text_instruct_0_5b_q4_k_m
    }

    // MARK: - Display Helpers

    /// 모델의 사용자 친화적 표시명
    ///
    /// - Parameter model: AI 모델 타입
    /// - Returns: 표시용 이름
    public static func displayName(for model: AIModel) -> String {
        switch model {
        case .onDevice:
            let modelID = getActiveOnDeviceModelID()
            return ModelCatalog.record(for: modelID).displayName
        default:
            // 클라우드 모델은 전면 비활성화: 사용자 표기는 온디바이스로 통일
            return "On‑Device"
        }
    }

    /// 온디바이스 모델 ID의 표시명
    ///
    /// - Parameter modelID: 온디바이스 모델 ID
    /// - Returns: 표시용 이름
    public static func displayName(for modelID: OnDeviceModelID) -> String {
        return ModelCatalog.record(for: modelID).displayName
    }
}

// MARK: - AIModel Extension

extension AIModel {
    /// 온디바이스 모델 여부
    public var isOnDevice: Bool {
        return AIResponseHelpers.isOnDeviceModel(self)
    }

    /// API 모델 여부
    public var isAPI: Bool {
        return AIResponseHelpers.isAPIModel(self)
    }

    // 정화용 모델 ID 확장은 제거하여 DRY 및 의존성 축소

    /// 온디바이스 모델 ID (있는 경우)
    public var onDeviceID: OnDeviceModelID? {
        return AIResponseHelpers.onDeviceModelID(from: self)
    }
}
