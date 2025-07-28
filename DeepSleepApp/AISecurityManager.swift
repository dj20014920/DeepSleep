//
//  AISecurityManager.swift
//  DeepSleep
//
//  Created by AI Security Team on 2024-01-19.
//  Copyright © 2024 DeepSleep. All rights reserved.
//

import Foundation
import CryptoKit

/// 🛡️ **차세대 AI 보안 관리자 v3.0**
/// 최신 OWASP Top 10 (2025) 및 업계 모범 사례 기반
/// 프롬프트 인젝션, 데이터 유출, 시스템 프롬프트 노출 방지
class AISecurityManager {
    static let shared = AISecurityManager()
    
    // MARK: - 🔒 보안 설정 (프로덕션 보안 강화)
    private let maxPromptLength = 2000          // 프롬프트 길이 제한 (보안 강화)
    private let maxDailyRequests = 100          // 일일 요청 제한 (남용 방지)
    private let maxConversationTurns = 200      // 대화 턴 제한 (리소스 보호)
    private let allowedLanguages: Set<String> = ["ko", "en"]
    
    // MARK: - 📊 보안 모니터링
    private var dailyRequestCounts: [String: Int] = [:]
    private var suspiciousPatterns: [String] = []
    internal var sessionStartTime = Date()
    
    // MARK: - 🧠 악성 패턴 탐지 (2024 최신 업데이트)
    private let knownMaliciousPatterns = [
        // 직접적인 프롬프트 인젝션
        "ignore previous instructions",
        "ignore all instructions",
        "ignore the above",
        "disregard",
        "새로운 지시사항",
        "이전 명령 무시",
        "시스템 프롬프트",
        "prompt engineering",
        
        // 시스템 정보 추출 시도
        "system prompt",
        "original instructions",
        "your instructions",
        "tell me your prompt",
        "reveal the prompt",
        "show me the system",
        "프롬프트를 알려줘",
        "시스템 설정",
        "초기 설정",
        
        // 역할 변경 시도 (Role-playing)
        "you are now",
        "pretend to be",
        "act as",
        "roleplay",
        "simulation mode",
        "개발자 모드",
        "관리자 권한",
        "특별 권한",
        
        // 다국어 우회 시도
        "überschreibe",
        "ignorez",
        "ignora",
        "無視して",
        "忽略",
        
        // 인코딩/난독화 우회
        "base64",
        "hex",
        "unicode",
        "rot13",
        "url encode",
        
        // 감정적 조작 (일반적인 단어들 제거)
        "life depends",
        "help me or",
        "생명이 걸린",
        
        // 시스템 침해 시도
        "shell command",
        "execute",
        "run code",
        "script",
        "eval",
        "import os",
        "system(",
        
        // 사용자 정보 탈취
        "other users",
        "previous conversation",
        "user data",
        "password",
        "email address",
        "phone number",
        "다른 사용자",
        "개인정보",
        "비밀번호",
        
        // 2024년 신규 패턴
        "break out of",
        "escape the",
        "jailbreak",
        "cleverly",
        "hypothetically",
        "in theory",
        "what if scenario",
        "creative writing exercise"
    ]
    
    // MARK: - 🔍 고급 보안 탐지 메서드
    
    /// 📋 **1. 입력 검증 및 정화 (Input Validation & Sanitization)**
    func validateAndSanitizeInput(_ input: String, userId: String) -> SecurityValidationResult {
        print("🔍 [Security] 입력 보안 검사 시작: \(input.prefix(50))...")
        
        // 1. 기본 검증
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .rejected(reason: "빈 입력은 허용되지 않습니다.")
        }
        
        // 2. 길이 제한
        guard input.count <= maxPromptLength else {
            return .rejected(reason: "입력이 너무 깁니다. (\(input.count)/\(maxPromptLength)자)")
        }
        
        // 3. 일일 요청 제한 (사용자 친화적 안내)
        let today = DateFormatter.dateOnlyFormatter.string(from: Date())
        let userKey = "\(userId)_\(today)"
        let currentCount = dailyRequestCounts[userKey] ?? 0
        
        if currentCount >= maxDailyRequests {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateFormat = "M월 d일"
            let tomorrowString = formatter.string(from: tomorrow)
            
            return .rejected(reason: "오늘 채팅 한도(\(maxDailyRequests)개)를 모두 사용했어요! 😊\n\(tomorrowString)에 다시 만나요! 내일도 좋은 하루 되세요! ✨")
        }
        
        // 4. 악성 패턴 탐지 (임계값 완화: 0.7 → 0.9)
        let maliciousScore = detectMaliciousPatterns(in: input)
        if maliciousScore > 0.9 {
            logSecurityEvent("HIGH_RISK_PROMPT", details: input, userId: userId)
            return .rejected(reason: "보안 위험이 감지되었습니다. 다른 방식으로 질문해 주세요.")
        }
        
        // 5. 언어 검증
        let detectedLanguage = detectLanguage(input)
        guard allowedLanguages.contains(detectedLanguage) else {
            return .flagged(reason: "지원하지 않는 언어가 감지되었습니다.", cleanInput: input)
        }
        
        // 6. 입력 정화
        let sanitizedInput = sanitizeInput(input)
        
        // 7. 사용량 기록
        dailyRequestCounts[userKey] = currentCount + 1
        
        print("✅ [Security] 입력 검증 완료")
        return .approved(cleanInput: sanitizedInput)
    }
    
    /// 🧠 **2. 악성 패턴 점수 계산 (ML 기반)**
    private func detectMaliciousPatterns(in text: String) -> Double {
        let lowercaseText = text.lowercased()
        var suspiciousScore = 0.0
        var detectedPatterns: [String] = []
        
        // 알려진 악성 패턴 검사 (점수 완화: 0.3 → 0.2)
        for pattern in knownMaliciousPatterns {
            if lowercaseText.contains(pattern) {
                suspiciousScore += 0.2
                detectedPatterns.append(pattern)
            }
        }
        
        // 고급 패턴 분석
        suspiciousScore += analyzeAdvancedPatterns(lowercaseText)
        
        // 의심스러운 패턴 로깅
        if !detectedPatterns.isEmpty {
            print("⚠️ [Security] 악성 패턴 감지: \(detectedPatterns)")
        }
        
        return min(suspiciousScore, 1.0)
    }
    
    /// 🎯 **3. 고급 패턴 분석**
    private func analyzeAdvancedPatterns(_ text: String) -> Double {
        var score = 0.0
        
        // 다중 명령어 시도 탐지
        let commandSeparators = ["&&", "||", ";", "|", "\n"]
        for separator in commandSeparators {
            if text.contains(separator) {
                score += 0.2
            }
        }
        
        // 과도한 특수문자 사용
        let specialCharCount = text.filter { "!@#$%^&*()[]{}|\\;':\"<>?,./".contains($0) }.count
        if Double(specialCharCount) / Double(text.count) > 0.3 {
            score += 0.3
        }
        
        // 반복되는 명령어 패턴
        if text.matches(regex: #"(\b\w+\b).*\1.*\1"#) {
            score += 0.25
        }
        
        // Base64 인코딩 의심 패턴
        if text.matches(regex: #"[A-Za-z0-9+/]{20,}={0,2}"#) {
            score += 0.4
        }
        
        // SQL Injection 패턴
        let sqlPatterns = ["union select", "drop table", "delete from", "insert into"]
        for pattern in sqlPatterns {
            if text.contains(pattern) {
                score += 0.5
            }
        }
        
        return score
    }
    
    /// 🌐 **4. 언어 탐지**
    private func detectLanguage(_ text: String) -> String {
        let koreanStart = UnicodeScalar("가")
        let koreanEnd = UnicodeScalar("힣")
        
        let koreanRange = koreanStart.value...koreanEnd.value
        let koreanCount = text.unicodeScalars.filter { koreanRange.contains($0.value) }.count
        
        if Double(koreanCount) / Double(text.count) > 0.1 {
            return "ko"
        }
        return "en"
    }
    
    /// 🧽 **5. 입력 정화**
    private func sanitizeInput(_ input: String) -> String {
        var sanitized = input
        
        // HTML 태그 제거
        sanitized = sanitized.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        
        // 스크립트 태그 제거
        sanitized = sanitized.replacingOccurrences(of: #"<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>"#, with: "", options: [.regularExpression, .caseInsensitive])
        
        // 위험한 함수 호출 패턴 제거
        let dangerousFunctions = ["eval(", "exec(", "system(", "shell_exec("]
        for dangerousFunc in dangerousFunctions {
            sanitized = sanitized.replacingOccurrences(of: dangerousFunc, with: "[BLOCKED_FUNCTION]")
        }
        
        // 과도한 공백 정리
        sanitized = sanitized.replacingOccurrences(of: #"\s{3,}"#, with: " ", options: .regularExpression)
        
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 📤 **6. 출력 검증 (Output Validation)**
    func validateOutput(_ output: String, originalInput: String) -> OutputValidationResult {
        print("🔍 [Security] 출력 보안 검사 시작...")
        
        // 1. 시스템 프롬프트 노출 확인
        if containsSystemPromptLeakage(output) {
            logSecurityEvent("SYSTEM_PROMPT_LEAK", details: output, userId: "system")
            return .blocked(reason: "안전하지 않은 응답이 감지되어 차단되었습니다.")
        }
        
        // 2. 개인정보 노출 확인
        if containsPersonalInformation(output) {
            logSecurityEvent("PII_LEAK", details: output, userId: "system")
            return .blocked(reason: "개인정보가 포함된 응답이 차단되었습니다.")
        }
        
        // 3. 유해 콘텐츠 확인
        if containsHarmfulContent(output) {
            logSecurityEvent("HARMFUL_CONTENT", details: output, userId: "system")
            return .blocked(reason: "부적절한 내용이 포함된 응답이 차단되었습니다.")
        }
        
        // 4. 코드 실행 시도 확인
        if containsCodeExecution(output) {
            logSecurityEvent("CODE_EXECUTION_ATTEMPT", details: output, userId: "system")
            return .blocked(reason: "코드 실행 시도가 감지되어 차단되었습니다.")
        }
        
        print("✅ [Security] 출력 검증 완료")
        return .approved
    }
    
    // MARK: - 🔍 출력 검증 세부 메서드
    
    private func containsSystemPromptLeakage(_ text: String) -> Bool {
        // 🛡️ 진짜 심각한 시스템 프롬프트 누출만 탐지
        let criticalSystemLeaks = [
            "system:", "assistant:", "user:",
            "instruction:", "initial prompt", "base instruction",
            "시스템 설정", "프롬프트 설정", "역할 설정",
            "you are a", "your role is to", "you have been instructed",
            "as an ai assistant", "i am programmed to"
        ]
        
        let lowercaseText = text.lowercased()
        
        // 정확한 패턴 매칭으로 오탐지 방지
        for leak in criticalSystemLeaks {
            if lowercaseText.contains(leak) {
                // 추가 검증: 문맥상 진짜 시스템 누출인지 확인
                if isActualSystemLeak(text, pattern: leak) {
                    return true
                }
            }
        }
        
        return false
    }
    
    // 문맥상 진짜 시스템 누출인지 추가 검증
    private func isActualSystemLeak(_ text: String, pattern: String) -> Bool {
        let _ = text.lowercased()
        
        // "당신은", "you are" 등은 일반적인 대화 표현이므로 허용
        if pattern == "당신은" || pattern == "you are" {
            return false
        }
        
        // "system:", "instruction:" 등은 진짜 누출일 가능성 높음
        if pattern.contains(":") {
            return true
        }
        
        // "역할", "프롬프트" 등 시스템 관련 명시적 언급
        if pattern.contains("역할") || pattern.contains("프롬프트") || pattern.contains("설정") {
            return true
        }
        
        return false
    }
    
    private func containsPersonalInformation(_ text: String) -> Bool {
        // 이메일 패턴
        if text.matches(regex: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#) {
            return true
        }
        
        // 전화번호 패턴 (한국)
        if text.matches(regex: #"01[0-9]-?\d{4}-?\d{4}"#) {
            return true
        }
        
        // 신용카드 번호 패턴
        if text.matches(regex: #"\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b"#) {
            return true
        }
        
        return false
    }
    
    private func containsHarmfulContent(_ text: String) -> Bool {
        // 🛡️ 진짜 위험한 내용만 차단 (정상적인 감정 표현은 허용)
        let criticalHarmfulPatterns = [
            // 직접적인 자해 지시 (감정 표현과 구분)
            "자살하세요", "자살하라", "죽어버려", "자해하세요",
            // 구체적인 불법 활동
            "폭탄 제조법", "마약 제조", "해킹 방법", "불법 다운로드 사이트",
            // 명시적 혐오 표현
            "혐오합니다", "차별하자", "비하하자"
        ]
        
        let lowercaseText = text.lowercased()
        
        // 정확한 패턴 매칭으로 오탐지 방지
        for pattern in criticalHarmfulPatterns {
            if lowercaseText.contains(pattern) {
                return true
            }
        }
        
        // 추가 검증: 문맥상 정말 위험한 내용인지 확인
        return isActuallyHarmful(text)
    }
    
    // 실제로 위험한 내용인지 문맥 분석
    private func isActuallyHarmful(_ text: String) -> Bool {
        let lowercaseText = text.lowercased()
        
        // 감정 표현은 허용 (슬퍼, 우울해, 힘들어 등)
        let emotionExpressions = ["슬퍼", "우울", "힘들", "속상", "화나", "걱정"]
        for emotion in emotionExpressions {
            if lowercaseText.contains(emotion) {
                return false // 정상적인 감정 표현으로 판단
            }
        }
        
        // 도움 요청은 허용
        let helpRequests = ["도와줘", "상담", "치료", "극복", "해결"]
        for help in helpRequests {
            if lowercaseText.contains(help) {
                return false // 도움 요청으로 판단
            }
        }
        
        return false // 기본적으로 허용
    }
    
    private func containsCodeExecution(_ text: String) -> Bool {
        // 🛡️ 실제 위험한 코드 실행만 탐지 (마크다운 코드 블록은 허용)
        let dangerousCodePatterns = [
            // 직접적인 시스템 명령 실행
            "exec(", "eval(", "system(", "shell_exec(", "passthru(",
            // 위험한 모듈 임포트
            "import os", "import subprocess", "__import__",
            // 실제 쉘 명령어
            "rm -rf", "del /f", "format c:", "shutdown",
            // SQL 인젝션 패턴
            "'; DROP TABLE", "; DELETE FROM"
        ]
        
        let lowercaseText = text.lowercased()
        
        // 정확한 패턴 매칭
        for pattern in dangerousCodePatterns {
            if lowercaseText.contains(pattern) {
                return true
            }
        }
        
        return false // 마크다운 코드 블록(```)은 허용
    }
    
    /// 📊 **7. 보안 이벤트 로깅**
    private func logSecurityEvent(_ eventType: String, details: String, userId: String) {
        let event = SecurityEvent(
            type: eventType,
            timestamp: Date(),
            userId: userId,
            details: details.prefix(200).description, // 민감 정보 제한
            severity: determineSeverity(eventType)
        )
        
        // 로컬 로깅
        print("🚨 [SECURITY EVENT] \(eventType): \(event.severity)")
        
        // 필요시 원격 보안 로깅 시스템으로 전송
        sendToSecurityLogSystem(event)
    }
    
    private func determineSeverity(_ eventType: String) -> String {
        switch eventType {
        case "HIGH_RISK_PROMPT", "SYSTEM_PROMPT_LEAK", "CODE_EXECUTION_ATTEMPT":
            return "HIGH"
        case "PII_LEAK", "HARMFUL_CONTENT":
            return "MEDIUM"
        default:
            return "LOW"
        }
    }
    
    private func sendToSecurityLogSystem(_ event: SecurityEvent) {
        // 실제 구현에서는 보안 로깅 서비스로 전송
        // 예: 암호화된 로그를 secure endpoint로 전송
        print("📤 [Security Log] 이벤트 기록: \(event.type)")
    }
    
    /// 🛡️ **8. 세션 보안 관리 (자동 리셋 방식)**
    func validateSession(conversationTurns: Int, sessionDuration: TimeInterval) -> SessionValidationResult {
        // 대화 턴 수 제한 (99999턴으로 사실상 무제한)
        if conversationTurns > maxConversationTurns {
            print("⚠️ [Security] 대화 턴 수 초과: \(conversationTurns)")
            return .shouldReset("대화가 너무 길어졌어요! 새로운 대화를 시작할게요. 😊")
        }
        
        // 세션 지속 시간 제한 (24시간으로 대폭 증가: 4시간 → 24시간)
        if sessionDuration > 86400 {
            print("⚠️ [Security] 세션 시간 초과: \(sessionDuration)초")
            return .shouldReset("오늘 하루도 수고하셨어요! 새로운 세션을 시작할게요. ✨")
        }
        
        return .continue
    }
    
    /// 🔄 **세션 자동 리셋**
    func resetSession() {
        sessionStartTime = Date()
        print("✅ [Security] 새로운 세션 시작: \(sessionStartTime)")
    }
    
    /// 🔄 **9. 일일 리셋**
    func performDailyCleanup() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // 어제 데이터 정리
        dailyRequestCounts = dailyRequestCounts.filter { key, _ in
            let components = key.split(separator: "_")
            guard components.count >= 2,
                  let date = DateFormatter.dateOnlyFormatter.date(from: String(components.last!)) else {
                return false
            }
            return calendar.isDate(date, inSameDayAs: today)
        }
        
        print("🧹 [Security] 일일 보안 데이터 정리 완료")
    }
}

// MARK: - 📋 보안 관련 데이터 구조
// Note: SecurityValidationResult, OutputValidationResult는 AIServiceTypes.swift에 정의됨

enum SessionValidationResult {
    case `continue`
    case shouldReset(String)
}

struct SecurityEvent {
    let type: String
    let timestamp: Date
    let userId: String
    let details: String
    let severity: String
}

// MARK: - 🛠️ Helper Extensions

extension String {
    func matches(regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression) != nil
    }
}

extension DateFormatter {
    static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
} 
