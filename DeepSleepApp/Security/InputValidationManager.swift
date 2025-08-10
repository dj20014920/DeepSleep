import Foundation
import UIKit

/// 2025년 OWASP 보안 기준을 준수하는 입력 검증 및 살균 시스템
/// SQL Injection, XSS, Command Injection 방지를 위한 종합 방어 시스템
class InputValidationManager {
    
    // MARK: - 싱글톤 패턴
    static let shared = InputValidationManager()
    private init() {}
    
    // MARK: - 검증 규칙 정의
    enum ValidationRule {
        case nickname           // 닉네임: 한글, 영문, 숫자만 허용 (2-20자)
        case age               // 나이: 1-120 숫자만
        case email             // 이메일: RFC 5322 준수
        case apiKey            // API 키: 영문, 숫자, 특정 기호만
        case searchQuery       // 검색어: XSS 방지 필터링 (최대 200자)
        case aiResponse        // AI 응답: XSS 방지, 긴 텍스트 허용 (최대 5000자)
        case filename          // 파일명: Path Traversal 방지
        case jsonData          // JSON 데이터: 구조 검증
        case sql              // SQL 쿼리: Injection 방지
        case custom(String)   // 커스텀 정규식
    }
    
    // MARK: - 검증 결과
    struct ValidationResult {
        let isValid: Bool
        let sanitizedValue: String?
        let errorMessage: String?
        let securityIssues: [SecurityIssue]
        
        struct SecurityIssue {
            let type: SecurityIssueType
            let description: String
            let severity: Severity
            
            enum SecurityIssueType {
                case sqlInjection
                case xssAttempt
                case pathTraversal
                case maliciousScript
                case invalidCharacters
                case lengthExceeded
            }
            
            enum Severity {
                case low, medium, high, critical
            }
        }
    }
    
    // MARK: - 정규식 패턴 (2025년 보안 권장사항)
    private struct ValidationPatterns {
        // 한글, 영문, 숫자만 허용 (닉네임용)
        static let nickname = "^[가-힣a-zA-Z0-9\\s]{2,20}$"
        
        // 나이: 1-120 범위
        static let age = "^(?:[1-9]|[1-9][0-9]|1[01][0-9]|120)$"
        
        // 이메일: RFC 5322 준수
        static let email = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
        
        // API 키: 영문, 숫자, 하이픈, 언더스코어만
        static let apiKey = "^[a-zA-Z0-9\\-_]{10,100}$"
        
        // 안전한 파일명: 알파벳, 숫자, 점, 하이픈만
        static let safeFilename = "^[a-zA-Z0-9\\-_.]{1,50}$"
        
        // XSS 위험 패턴 감지
        static let xssPatterns = [
            "<script[^>]*>.*?</script>",
            "javascript:",
            "vbscript:",
            "onload=",
            "onerror=",
            "onclick=",
            "onmouseover=",
            "<iframe",
            "<object",
            "<embed"
        ]
        
        // SQL Injection 위험 패턴 감지
        static let sqlInjectionPatterns = [
            "(?i)(union|select|insert|update|delete|drop|create|alter|exec|execute)",
            "'\\s*(or|and)\\s*'",
            "\\b(or|and)\\s+\\d+\\s*=\\s*\\d+",
            "--",
            "/\\*.*?\\*/",
            ";\\s*(drop|delete|insert|update)"
        ]
        
        // Path Traversal 패턴
        static let pathTraversalPatterns = [
            "\\.\\./",
            "\\.\\.\\\\",
            "%2e%2e%2f",
            "%2e%2e%5c"
        ]
    }
    
    // MARK: - 메인 검증 메서드
    func validate(_ input: String, against rule: ValidationRule) -> ValidationResult {
        guard !input.isEmpty else {
            return ValidationResult(
                isValid: false,
                sanitizedValue: nil,
                errorMessage: "입력값이 비어있습니다",
                securityIssues: []
            )
        }
        
        // 1단계: 보안 위협 검사
        let securityIssues = detectSecurityThreats(in: input)
        
        // 2단계: 길이 검증
        let lengthValidation = validateLength(input, for: rule)
        
        // 3단계: 패턴 검증
        let patternValidation = validatePattern(input, for: rule)
        
        // 4단계: 데이터 살균
        let sanitizedValue = sanitizeInput(input, for: rule)
        
        // 결과 종합
        let allIssues = securityIssues + (lengthValidation.securityIssues) + (patternValidation.securityIssues)
        let isValid = allIssues.isEmpty && patternValidation.isValid && lengthValidation.isValid
        
        var errorMessage: String?
        if !isValid {
            if let highRiskIssue = allIssues.first(where: { $0.severity == .critical || $0.severity == .high }) {
                errorMessage = "보안 위험: \(highRiskIssue.description)"
            } else {
                errorMessage = patternValidation.errorMessage ?? lengthValidation.errorMessage
            }
        }
        
        return ValidationResult(
            isValid: isValid,
            sanitizedValue: sanitizedValue,
            errorMessage: errorMessage,
            securityIssues: allIssues
        )
    }
    
    // MARK: - 보안 위협 탐지
    private func detectSecurityThreats(in input: String) -> [ValidationResult.SecurityIssue] {
        var issues: [ValidationResult.SecurityIssue] = []
        
        // XSS 패턴 검사
        for pattern in ValidationPatterns.xssPatterns {
            if input.range(of: pattern, options: .regularExpression) != nil {
                issues.append(ValidationResult.SecurityIssue(
                    type: .xssAttempt,
                    description: "XSS 공격 패턴이 감지되었습니다",
                    severity: .critical
                ))
                break
            }
        }
        
        // SQL Injection 패턴 검사
        for pattern in ValidationPatterns.sqlInjectionPatterns {
            if input.range(of: pattern, options: .regularExpression) != nil {
                issues.append(ValidationResult.SecurityIssue(
                    type: .sqlInjection,
                    description: "SQL Injection 공격 패턴이 감지되었습니다",
                    severity: .critical
                ))
                break
            }
        }
        
        // Path Traversal 패턴 검사
        for pattern in ValidationPatterns.pathTraversalPatterns {
            if input.range(of: pattern, options: .regularExpression) != nil {
                issues.append(ValidationResult.SecurityIssue(
                    type: .pathTraversal,
                    description: "Path Traversal 공격 패턴이 감지되었습니다",
                    severity: .high
                ))
                break
            }
        }
        
        return issues
    }
    
    // MARK: - 패턴 검증
    private func validatePattern(_ input: String, for rule: ValidationRule) -> ValidationResult {
        let pattern: String
        var errorMessage: String?
        
        switch rule {
        case .nickname:
            pattern = ValidationPatterns.nickname
            errorMessage = "닉네임은 한글, 영문, 숫자만 사용 가능하며 2-20자여야 합니다"
            
        case .age:
            pattern = ValidationPatterns.age
            errorMessage = "나이는 1-120 사이의 숫자여야 합니다"
            
        case .email:
            pattern = ValidationPatterns.email
            errorMessage = "올바른 이메일 형식이 아닙니다"
            
        case .apiKey:
            pattern = ValidationPatterns.apiKey
            errorMessage = "API 키 형식이 올바르지 않습니다"
            
        case .filename:
            pattern = ValidationPatterns.safeFilename
            errorMessage = "파일명에 허용되지 않는 문자가 포함되어 있습니다"
            
        case .searchQuery:
            // 검색어는 XSS 방지에만 집중
            return ValidationResult(isValid: true, sanitizedValue: input, errorMessage: nil, securityIssues: [])
            
        case .aiResponse:
            // AI 응답은 자연어이므로 패턴 검증 없이 보안 위협 탐지에만 의존
            return ValidationResult(isValid: true, sanitizedValue: input, errorMessage: nil, securityIssues: [])
            
        case .jsonData:
            return validateJSON(input)
            
        case .sql:
            return ValidationResult(isValid: false, sanitizedValue: nil, 
                                  errorMessage: "직접 SQL 입력은 보안상 허용되지 않습니다", 
                                  securityIssues: [])
            
        case .custom(let customPattern):
            pattern = customPattern
            errorMessage = "입력 형식이 올바르지 않습니다"
        }
        
        let isValid = input.range(of: pattern, options: .regularExpression) != nil
        
        return ValidationResult(
            isValid: isValid,
            sanitizedValue: isValid ? input : nil,
            errorMessage: isValid ? nil : errorMessage,
            securityIssues: []
        )
    }
    
    // MARK: - 길이 검증
    private func validateLength(_ input: String, for rule: ValidationRule) -> ValidationResult {
        let maxLength: Int
        
        switch rule {
        case .nickname: maxLength = 20
        case .age: maxLength = 3
        case .email: maxLength = 100
        case .apiKey: maxLength = 100
        case .searchQuery: maxLength = 200
        case .aiResponse: maxLength = 5000  // AI 응답은 긴 텍스트 허용
        case .filename: maxLength = 50
        case .jsonData: maxLength = 10000
        case .sql: maxLength = 0  // SQL 직접 입력 금지
        case .custom: maxLength = 1000
        }
        
        let isValid = input.count <= maxLength
        let securityIssues: [ValidationResult.SecurityIssue] = isValid ? [] : [
            ValidationResult.SecurityIssue(
                type: .lengthExceeded,
                description: "입력 길이가 제한을 초과했습니다 (최대 \(maxLength)자)",
                severity: .medium
            )
        ]
        
        return ValidationResult(
            isValid: isValid,
            sanitizedValue: isValid ? input : nil,
            errorMessage: isValid ? nil : "입력 길이가 제한을 초과했습니다",
            securityIssues: securityIssues
        )
    }
    
    // MARK: - JSON 검증
    private func validateJSON(_ input: String) -> ValidationResult {
        do {
            guard let data = input.data(using: .utf8) else {
                return ValidationResult(isValid: false, sanitizedValue: nil, 
                                      errorMessage: "유효하지 않은 JSON 형식입니다", securityIssues: [])
            }
            
            let _ = try JSONSerialization.jsonObject(with: data, options: [])
            return ValidationResult(isValid: true, sanitizedValue: input, errorMessage: nil, securityIssues: [])
            
        } catch {
            return ValidationResult(isValid: false, sanitizedValue: nil, 
                                  errorMessage: "JSON 파싱 오류: \(error.localizedDescription)", securityIssues: [])
        }
    }
    
    // MARK: - 데이터 살균 (Sanitization)
    private func sanitizeInput(_ input: String, for rule: ValidationRule) -> String {
        var sanitized = input
        
        switch rule {
        case .searchQuery:
            // HTML 엔티티 인코딩
            sanitized = sanitized
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "'", with: "&#x27;")
                .replacingOccurrences(of: "&", with: "&amp;")
            
        case .filename:
            // 파일명 안전화
            sanitized = sanitized
                .replacingOccurrences(of: "..", with: "")
                .replacingOccurrences(of: "/", with: "")
                .replacingOccurrences(of: "\\", with: "")
            
        case .nickname:
            // 닉네임 트림 및 다중 공백 제거
            sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
            sanitized = sanitized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            
        default:
            // 기본 안전화: 제어 문자 제거
            sanitized = sanitized.filter { !$0.isNewline && $0.isLetter || $0.isNumber || $0.isWhitespace || $0.isPunctuation }
        }
        
        return sanitized
    }
    
    // MARK: - UI 통합을 위한 편의 메서드
    func validateTextField(_ textField: UITextField, rule: ValidationRule, showAlert: Bool = true) -> Bool {
        guard let text = textField.text else { return false }
        
        let result = validate(text, against: rule)
        
        // UI 피드백
        if result.isValid {
            textField.layer.borderColor = UIColor.systemGreen.cgColor
            textField.layer.borderWidth = 1.0
        } else {
            textField.layer.borderColor = UIColor.systemRed.cgColor
            textField.layer.borderWidth = 1.0
            
            if showAlert, let errorMessage = result.errorMessage {
                // 에러 메시지 표시 (실제 구현시 UIAlertController 사용)
                print("❌ 입력 검증 실패: \(errorMessage)")
            }
        }
        
        return result.isValid
    }
    
    // MARK: - 보안 로깅
    func logSecurityIncident(_ result: ValidationResult, input: String, context: String) {
        guard !result.securityIssues.isEmpty else { return }
        
        let criticalIssues = result.securityIssues.filter { $0.severity == .critical }
        
        if !criticalIssues.isEmpty {
            // 심각한 보안 위협은 즉시 로깅
            let sanitizedInput = String(input.prefix(50)) + "..." // 입력값 일부만 로깅
            print("🚨 CRITICAL SECURITY THREAT: \(context)")
            print("   Issues: \(criticalIssues.map { $0.description }.joined(separator: ", "))")
            print("   Input (truncated): \(sanitizedInput)")
            
            // 실제 구현시 원격 보안 로깅 시스템으로 전송
            // TODO: UnifiedLogger 사용 (현재는 콘솔 로깅으로 대체)
            print("🔐 SECURITY INCIDENT: \(context)")
            print("   Issues: \(criticalIssues)")
            print("   Timestamp: \(Date())")
        }
    }
}

// MARK: - 확장: 특정 데이터 타입별 검증
extension InputValidationManager {
    
    /// 사용자 기본 정보 일괄 검증
    func validateUserBasicInfo(nickname: String, age: String) -> (Bool, [String]) {
        var errors: [String] = []
        
        let nicknameResult = validate(nickname, against: .nickname)
        let ageResult = validate(age, against: .age)
        
        if !nicknameResult.isValid {
            errors.append(nicknameResult.errorMessage ?? "닉네임이 유효하지 않습니다")
        }
        
        if !ageResult.isValid {
            errors.append(ageResult.errorMessage ?? "나이가 유효하지 않습니다")
        }
        
        // 보안 이슈 로깅
        logSecurityIncident(nicknameResult, input: nickname, context: "UserBasicInfo.nickname")
        logSecurityIncident(ageResult, input: age, context: "UserBasicInfo.age")
        
        return (errors.isEmpty, errors)
    }
    
    /// API 키 검증 (여러 개)
    func validateAPIKeys(_ keys: [String: String]) -> (Bool, [String: String]) {
        var errors: [String: String] = [:]
        
        for (service, key) in keys {
            let result = validate(key, against: .apiKey)
            if !result.isValid {
                errors[service] = result.errorMessage ?? "유효하지 않은 API 키입니다"
            }
            
            logSecurityIncident(result, input: key, context: "APIKey.\(service)")
        }
        
        return (errors.isEmpty, errors)
    }
}

// RemoteLogger는 별도 파일 (RemoteLogger.swift)에 정의됨