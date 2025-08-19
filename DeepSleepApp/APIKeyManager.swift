//
//  APIKeyManager.swift
//  DeepSleep
//
//  Created by System on 2025-01-20.
//  Copyright © 2025 DeepSleep. All rights reserved.
//

import Foundation

/// 🔐 **API 키 관리자**
/// Secrets.xcconfig에서 API 키를 안전하게 로드하고 검증하는 시스템
class APIKeyManager {
    static let shared = APIKeyManager()
    
    private init() {}
    
    // MARK: - 🔑 API 키 로딩
    
    /// Claude API 키 로드
    var claudeAPIKey: String? {
        return loadAPIKey(for: "CLAUDE_API_KEY")
    }
    
    /// OpenAI API 키 로드
    var openAIAPIKey: String? {
        return loadAPIKey(for: "OPEN_AI_4oMINI_API_KEY")
    }
    
    /// Gemini API 키 로드
    var geminiAPIKey: String? {
        return loadAPIKey(for: "GEMINI_API_KEY")
    }
    
    // MARK: - 🛠️ Private Methods
    
    /// Secrets.xcconfig에서 API 키 로드
    private func loadAPIKey(for key: String) -> String? {
        guard let apiKey = ConfigReader.string(key) else {
            print("⚠️ [APIKeyManager] \(key) 키를 찾을 수 없습니다.")
            return nil
        }
        
        // 템플릿 키인지 확인
        if isTemplateKey(apiKey) {
            print("⚠️ [APIKeyManager] \(key)가 템플릿 상태입니다. 실제 키로 교체해주세요.")
            return nil
        }
        
        // 키 형식 검증
        if !isValidAPIKey(apiKey, for: key) {
            print("⚠️ [APIKeyManager] \(key)의 형식이 올바르지 않습니다.")
            return nil
        }
        
        print("✅ [APIKeyManager] \(key) 로드 성공")
        return apiKey
    }
    
    /// 템플릿 키인지 확인
    private func isTemplateKey(_ key: String) -> Bool {
        let templatePatterns = [
            "YOUR_CLAUDE_API_KEY_HERE",
            "YOUR_OPENAI_API_KEY_HERE",
            "YOUR_GEMINI_API_KEY_HERE",
            "sk-ant-api03-YOUR_CLAUDE_API_KEY_HERE",
            "sk-proj-YOUR_OPENAI_API_KEY_HERE"
        ]
        
        return templatePatterns.contains { key.contains($0) }
    }
    
    /// API 키 형식 검증
    private func isValidAPIKey(_ key: String, for keyType: String) -> Bool {
        switch keyType {
        case "CLAUDE_API_KEY":
            return key.hasPrefix("sk-ant-") && key.count > 20
        case "OPEN_AI_4oMINI_API_KEY":
            return key.hasPrefix("sk-") && key.count > 20
        case "GEMINI_API_KEY":
            return key.count > 20 // Gemini 키는 다양한 형식
        default:
            return key.count > 10 // 기본 최소 길이
        }
    }
    
    // MARK: - 🔍 상태 확인
    
    /// 모든 API 키 상태 확인
    func checkAllAPIKeys() -> APIKeyStatus {
        let claude = claudeAPIKey != nil
        let openai = openAIAPIKey != nil
        let gemini = geminiAPIKey != nil
        
        return APIKeyStatus(
            claude: claude,
            openai: openai,
            gemini: gemini,
            hasAnyKey: claude || openai || gemini
        )
    }
    
    /// API 키 상태 로그 출력
    func logAPIKeyStatus() {
        let status = checkAllAPIKeys()
        
        print("🔐 [APIKeyManager] API 키 상태:")
        print("   🤖 Claude: \(status.claude ? "✅ 사용 가능" : "❌ 없음")")
        print("   🧠 OpenAI: \(status.openai ? "✅ 사용 가능" : "❌ 없음")")
        print("   💎 Gemini: \(status.gemini ? "✅ 사용 가능" : "❌ 없음")")
        print("   📊 전체 상태: \(status.hasAnyKey ? "✅ 사용 가능" : "❌ 설정 필요")")
        
        if !status.hasAnyKey {
            print("")
            print("⚠️ [APIKeyManager] 경고: 사용 가능한 API 키가 없습니다.")
            print("   Secrets.xcconfig 파일에서 실제 API 키로 교체해주세요.")
        }
    }
    
    // MARK: - 🎯 사용 권장 API 선택
    
    /// 사용 가능한 API 중 권장 순서로 반환
    func getPreferredAPI() -> (type: APIType, key: String)? {
        // 우선순위: Claude > OpenAI > Gemini
        if let claudeKey = claudeAPIKey {
            return (.claude, claudeKey)
        }
        
        if let openaiKey = openAIAPIKey {
            return (.openai, openaiKey)
        }
        
        if let geminiKey = geminiAPIKey {
            return (.gemini, geminiKey)
        }
        
        return nil
    }
}

// MARK: - 📊 데이터 모델

/// API 키 상태 정보
struct APIKeyStatus {
    let claude: Bool
    let openai: Bool
    let gemini: Bool
    let hasAnyKey: Bool
}

/// API 타입 정의
enum APIType: String, CaseIterable {
    case claude = "Claude"
    case openai = "OpenAI"
    case gemini = "Gemini"
    
    var displayName: String {
        return rawValue
    }
}

// MARK: - 🎯 사용 예시

/*
사용 예시:

// 1. API 키 상태 확인
APIKeyManager.shared.logAPIKeyStatus()

// 2. 특정 API 키 사용
if let claudeKey = APIKeyManager.shared.claudeAPIKey {
    // Claude API 호출
}

// 3. 권장 API 사용
if let (apiType, apiKey) = APIKeyManager.shared.getPreferredAPI() {
    print("사용할 API: \(apiType.displayName)")
    // API 호출
}

// 4. 전체 상태 확인
let status = APIKeyManager.shared.checkAllAPIKeys()
if !status.hasAnyKey {
    // API 키 설정 안내
}
*/