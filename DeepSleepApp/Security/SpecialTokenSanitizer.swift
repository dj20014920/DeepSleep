//
//  SpecialTokenSanitizer.swift
//  DeepSleep
//
//  Created by AI Security Team on 2025-01-26.
//  Copyright © 2025 DeepSleep. All rights reserved.
//

import Foundation

// MARK: - SpecialTokenSanitizer
/// 🛡️ **특수 토큰 및 이모티콘 보안 처리 중앙화 시스템 (SSOT)**
///
/// **목적:**
/// - 사용자 입력의 특수 토큰 이스케이프 (보안)
/// - AI 출력의 특수 토큰 제거 (사용자 경험)
/// - 스트리밍 토큰 실시간 정화
/// - 이모티콘과 특수 토큰 충돌 방지
///
/// **설계 원칙:**
/// - SSOT: 모든 특수 토큰 관리를 한 곳에서
/// - KISS: 간단하고 명확한 로직
/// - DRY: 중복 없는 단일 처리 경로
/// - 성능: 최소한의 오버헤드, 빠른 실행
///
/// **사용 예시:**
/// ```swift
/// // 사용자 입력 처리
/// let safe = SpecialTokenSanitizer.sanitizeUserInput(userText, modelID: .hyperclovax_seed_text_instruct_0_5b_q4_k_m)
///
/// // AI 출력 처리 (최종)
/// let clean = SpecialTokenSanitizer.cleanAIOutput(aiResponse, modelID: .hyperclovax_seed_text_instruct_0_5b_q4_k_m)
///
/// // 스트리밍 토큰 처리 (실시간)
/// let cleaned = SpecialTokenSanitizer.cleanStreamingToken(delta, modelID: .hyperclovax_seed_text_instruct_0_5b_q4_k_m)
///
/// // Stop sequences 가져오기
/// let stops = SpecialTokenSanitizer.getStopSequences(for: .hyperclovax_seed_text_instruct_0_5b_q4_k_m)
/// ```
public enum SpecialTokenSanitizer {

    // MARK: - Model-Specific Token Definitions (SSOT)

    /// 모델별 특수 토큰 정의 (SSOT)
    internal enum TokenSet {
        case gemma3Style  // Gemma 3 계열
        case hcx05bStyle  // HyperCLOVA X Seed 0.5B 계열
        case hcx15bStyle  // HyperCLOVA X Seed 1.5B 계열

        /// 시스템 레벨 특수 토큰 목록 (모든 토큰 포함)
        var systemTokens: [String] {
            switch self {
            case .gemma3Style:
                return [
                    // Chat template tokens
                    "<start_of_turn>",
                    "<end_of_turn>",
                    "<start_of_turn>user",
                    "<start_of_turn>model",
                    "<start_of_turn>assistant",
                    "<start_of_turn>system",
                    "<start_of_image>",

                    // HCX-style tokens that may leak from mixed-corpa training
                    "<|im_start|>",
                    "<|im_end|>",
                    "<|im_start|>user",
                    "<|im_start|>assistant",
                    "<|im_start|>system",

                    // Special tokens from tokenizer
                    "<bos>",
                    "<eos>",
                    "<pad>",
                    "<unk>",
                    "<mask>",

                    // Common alternatives
                    "</s>",
                    "<|eot_id|>",
                    "<|end_of_text|>",
                ]
            case .hcx05bStyle, .hcx15bStyle:
                return [
                    // Chat template tokens
                    "<|im_start|>",
                    "<|im_end|>",
                    "<|im_start|>user",
                    "<|im_start|>assistant",
                    "<|im_start|>system",

                    // Alternative stop tokens
                    "<|endofturn|>",
                    "<|stop|>",
                    "<|eom|>",
                    "<|eom_id|>",

                    // Common end tokens
                    "<bos>",
                    "<eos>",
                    "</s>",
                    "<|eot_id|>",
                    "<|end_of_text|>",
                ]
            }
        }

        /// 스트리밍 중 즉시 필터링할 토큰 (stop sequences)
        var stopSequences: [String] {
            switch self {
            case .gemma3Style:
                return [
                    // 정상적인 턴 종료
                    "<end_of_turn>",

                    // 새 턴 시작 방지 (모든 역할)
                    "<start_of_turn>user",
                    "<start_of_turn>model",
                    "<start_of_turn>assistant",
                    "<start_of_turn>system",
                    "<start_of_turn>",

                    // 부분적/깨진 토큰들
                    "<start_of_",
                    "<end_of_",

                    // 공통 종료 토큰들
                    "</s>",
                    "<eos>",
                    "<bos>",
                    "<|eot_id|>",
                    "<|end_of_text|>",
                    // HCX-style markers to stop early when they appear in Gemma output
                    "<|im_end|>",
                    "<|im_start|>",
                    // Gemma3 에코 억제: 시스템 지시 핵심 키워드가 응답에 등장하면 즉시 중단
                    // (한국어 일반 대화에서 드물게 쓰이는 키워드 위주로 선정)
                    "핵심 지침:",
                    "요청/응답 같은 표현을 반복하거나 설명하지 마세요",
                    "현재 대화 맥락에 집중하세요",
                    "시스템/템플릿 문구",
                    "### User",
                    "### Recent",
                ]
            case .hcx05bStyle, .hcx15bStyle:
                return [
                    // 정상적인 턴 종료(정확 매칭만)
                    "<|im_end|>",
                    "<|eom|>",
                    "<|eom_id|>",

                    // 새 턴 시작 방지 (정확 매칭만) — 역할 뒤 공백 유무 모두 처리
                    "<|im_start|>user ", "<|im_start|>user",
                    "<|im_start|>assistant ", "<|im_start|>assistant",
                    "<|im_start|>system ", "<|im_start|>system",
                    "<|im_start|>",

                    // 대체 종료 토큰들
                    "<|endofturn|>",
                    "<|stop|>",

                    // 부분적/깨진 토큰들 — 과도 필터링 제거: "|>" 와 "<|im_"는 델타 정상 텍스트를 훼손 가능성이 높아 제외
                    // 필요 시 brokenTokenPatterns에서 정규식으로 후단 정리

                    // 공통 종료 토큰들(정확 매칭)
                    "</s>",
                    "<eos>",
                    "<bos>",
                    "<|eot_id|>",
                    "<|end_of_text|>",
                ]
            }
        }

        /// 부분적/깨진 토큰 패턴 (정규식용)
        var brokenTokenPatterns: [String] {
            switch self {
            case .gemma3Style:
                return [
                    #"<start_of_[^>]*"#,  // <start_of_... 로 시작하는 미완성
                    #"<end_of_[^>]*"#,  // <end_of_... 로 시작하는 미완성
                    #"[^<]*_of_turn>"#,  // ...of_turn> 로 끝나는 미완성
                    #"<bos[^>]*"#,  // <bos... 미완성
                    #"<eos[^>]*"#,  // <eos... 미완성
                    #"<pad[^>]*"#,  // <pad... 미완성
                    #"<unk[^>]*"#,  // <unk... 미완성
                    #"<mask[^>]*"#,  // <mask... 미완성
                ]
            case .hcx05bStyle, .hcx15bStyle:
                return [
                    #"<\|im_start\|>(user|assistant|system)\s"#, // 정확한 역할 프리픽스까지만 제거
                    #"<\|im_end\|>?"#,  // <|im_end| 또는 미완성 <|im_end|
                    #"<\|eom[^>]*"#,   // <|eom... 미완성
                    #"<bos[^>]*"#,  // <bos... 미완성
                    #"<eos[^>]*"#,  // <eos... 미완성
                ]
            }
        }

        /// 스트리밍 중 나타날 수 있는 부분 패턴 (성능 최적화용)
        var partialPatterns: [String] {
            switch self {
            case .gemma3Style:
                return [
                    "<start_of_",
                    "<end_of_",
                    "turn>",
                    "<bos",
                    "<eos",
                    "<pad",
                    "<unk",
                    "<mask",
                ]
            case .hcx05bStyle, .hcx15bStyle:
                return [
                    "<|im_",
                    "<|im",
                    "|>",
                    "<|eom",
                    "<bos",
                    "<eos",
                ]
            }
        }
    }

    /// 모델 ID를 TokenSet으로 매핑
    static func tokenSet(for modelID: OnDeviceModelID) -> TokenSet {
        switch modelID {
        case .amoral_gemma3_1b_v2_q5_k_m:
            return .gemma3Style
        case .hyperclovax_seed_text_instruct_0_5b_q4_k_m, .hyperclovax_seed_text_instruct_0_5b_q8_0:
            return .hcx05bStyle
        case .hyperclovax_seed_text_instruct_1_5b_q4_k_m:
            return .hcx15bStyle
        }
    }

    // MARK: - Public API: Stop Sequences

    /// **Stop Sequences 가져오기**
    ///
    /// - 모델별 스트리밍 중단 시퀀스 반환
    /// - 다른 모듈에서 중복 정의 방지 (SSOT)
    ///
    /// - Parameter modelID: 모델 ID
    /// - Returns: Stop sequences 배열
    public static func getStopSequences(for modelID: OnDeviceModelID) -> [String] {
        // SSOT 내부 함수는 내부 접근으로 충분하며, @inlinable 제거로 제약 해소
        return tokenSet(for: modelID).stopSequences
    }

    // MARK: - User Input Sanitization (입력 보안)

    /// **사용자 입력 보안 처리**
    ///
    /// - 특수 토큰과 유사한 패턴을 이스케이프하여 프롬프트 인젝션 방지
    /// - 일반 이모티콘(><, :), 등)은 보존
    /// - 빠른 실행: 특수 토큰이 없으면 즉시 반환
    ///
    /// - Parameters:
    ///   - input: 사용자 입력 텍스트
    ///   - modelID: 대상 모델 ID
    /// - Returns: 보안 처리된 텍스트
    public static func sanitizeUserInput(_ input: String, modelID: OnDeviceModelID) -> String {
        guard !input.isEmpty else { return input }

        var result = input
        let tokens = tokenSet(for: modelID)

        // 1단계: 시스템 레벨 특수 토큰 이스케이프 (공백 삽입)
        // 예: "<|im_start|>" -> "< |im_start|>"
        for token in tokens.systemTokens {
            if result.contains(token) {
                let escaped = token.replacingOccurrences(of: "<", with: "< ")
                result = result.replacingOccurrences(of: token, with: escaped)
            }
        }

        // 2단계: 일반적인 angle bracket 패턴 보호
        // ><는 이모티콘일 가능성이 높으므로 공백 삽입으로 안전하게 처리
        result = result.replacingOccurrences(of: "><", with: "> <")

        // 3단계: 단독 <| 패턴 이스케이프 (Qwen 계열 시작 마커)
        if tokens == .hcx05bStyle || tokens == .hcx15bStyle {
            result = result.replacingOccurrences(of: "<|", with: "< |")
        }

        // 4단계: LLM 프롬프트 인젝션 방지 — 역할/섹션 레이블 제거 (정확 매칭)
        let sectionLabelPatterns = [
            #"^\s*#{2,3}\s*(System|User|Assistant)\s*$"#,
            #"^\s*(System|User|Assistant)\s*:\s*"#,
            #"^\s*role\s*:\s*(system|assistant|user)\s*$"#,
        ]
        for pat in sectionLabelPatterns {
            if let re = try? NSRegularExpression(pattern: pat, options: [.anchorsMatchLines, .caseInsensitive]) {
                let range = NSRange(location: 0, length: result.utf16.count)
                result = re.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
            }
        }

        // 5단계: 지시 무력화 패턴 완화(정확 문구 위주, 과도한 삭제 방지)
        let directiveBlocks = [
            "ignore previous instructions",
            "ignore all instructions",
            "disregard previous",
            "pretend to be system",
            "act as system",
            "reveal the prompt",
            "show me the system prompt",
            "print the system prompt",
            "prompt injection",
            "jailbreak",
            "개발자 모드",
            "시스템 프롬프트",
        ]
        for phrase in directiveBlocks {
            result = result.replacingOccurrences(of: phrase, with: "[blocked]", options: [.caseInsensitive])
        }

        // 6단계: 과도한 헤더/코드펜스 제거(사용자 입력 내에서는 불필요)
        result = result.replacingOccurrences(of: "```", with: "")
        result = result.replacingOccurrences(of: #"^\s*#+\s*"#, with: "", options: .regularExpression)

        return result
    }

    // MARK: - System Prompt Sanitization (모델별 시스템 프롬프트 정화)

    /// 시스템 프롬프트에 다른 템플릿 마커/레이블(요청:, 답변:) 등이 섞여 있을 때 제거하여 에코를 방지
    /// - Gemma3: HCX 마커(<|im_start|>, <|im_end|>, <|eom|>)만 제거 (시스템 역할 지원하므로 최소 처리)
    /// - HCX: Gemma 마커(<start_of_turn>, <end_of_turn>) 제거
    public static func sanitizeSystemForModel(_ system: String, modelID: OnDeviceModelID) -> String {
        guard !system.isEmpty else { return system }
        var s = system
        switch tokenSet(for: modelID) {
        case .gemma3Style:
            // ✅ 수정: Gemma3는 system 역할을 지원하므로, 타 템플릿 마커만 제거
            let removeList = [
                "<|im_start|>", "<|im_end|>", "<|eom|>",
                // 레이블 제거는 하지 않음 (Gemma3는 시스템 프롬프트 내용 유지 필요)
            ]
            for r in removeList { s = s.replacingOccurrences(of: r, with: "") }
            // ⚠️ Gemma3 에코 방지: 사용자/말투/MBTI/핵심 지시 라인 제거
            // • 사용자의 이름: …
            // • 사용자가 선호하는 대화 스타일: …
            // • 사용자가 선호하는 AI 말투: …
            // • 사용자가 선호하는 AI 친구 성향: …
            // • 당신이 따라야 할 응답 스타일 가이드:
            let patterns = [
                #"^\s*•\s*사용자의 이름:\s*.*$"#,
                #"^\s*•\s*사용자가 선호하는 대화 스타일:\s*.*$"#,
                #"^\s*•\s*사용자가 선호하는 AI 말투:\s*.*$"#,
                #"^\s*•\s*사용자가 선호하는 AI 친구 성향:\s*.*$"#,
                #"^\s*•\s*당신이 따라야 할 응답 스타일 가이드:\s*.*$"#,
                #"^\s*핵심 지침:\s*$"#,
                #"요청/응답 같은 표현을 반복하거나 설명하지 마세요"#,
                #"현재 대화 맥락에 집중하세요"#,
                #"시스템/템플릿 문구"#,
            ]
            let lines = s.components(separatedBy: "\n")
            let filtered = lines.filter { line in
                for p in patterns {
                    if let re = try? NSRegularExpression(pattern: p, options: [.anchorsMatchLines]) {
                        let r = NSRange(location: 0, length: line.utf16.count)
                        if re.firstMatch(in: line, options: [], range: r) != nil { return false }
                    }
                }
                return true
            }
            s = filtered.joined(separator: "\n")
        case .hcx05bStyle, .hcx15bStyle:
            let removeList = [
                "<start_of_turn>", "<end_of_turn>", "<bos>", "<eos>",
            ]
            for r in removeList { s = s.replacingOccurrences(of: r, with: "") }
        }
        // 코드 펜스/주석/마크다운 헤더/HTML 주석 제거 및 레이블 제거
        // 1) 코드 펜스 정리
        s = s.replacingOccurrences(of: "```", with: "")
        // 2) 라인 단위 처리: 주석과 선행 레이블 제거
        let filtered = s.components(separatedBy: "\n").compactMap { ln -> String? in
            let t = ln.trimmingCharacters(in: .whitespaces)
            // 개발자 주석/헤더/HTML 주석 라인 제거
            if t.hasPrefix("///") || t.hasPrefix("//") || t.hasPrefix("# ") || t == "#" { return nil }
            if t.hasPrefix("<!--") && t.hasSuffix("-->") { return nil }
            // 특정 설명성 문구 제거(유출 보고 사례)
            if t.contains("모델별 특화 최적화 지침") { return nil }
            // 레이블 접두 제거
            if t.hasPrefix("요청:") {
                return String(t.dropFirst("요청:".count)).trimmingCharacters(in: .whitespaces)
            }
            if t.hasPrefix("답변:") {
                return String(t.dropFirst("답변:".count)).trimmingCharacters(in: .whitespaces)
            }
            return ln
        }
        s = filtered.joined(separator: "\n")
        // 과도한 공백 정리
        s = s.replacingOccurrences(of: "\r", with: "")
        s = s.replacingOccurrences(of: "\t", with: " ")
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    // MARK: - Streaming Token Cleaning (스트리밍 실시간 정화)

    /// **스트리밍 토큰 실시간 정화 (UTF-8 안전 버전)**
    ///
    /// - 스트리밍 중 생성되는 각 토큰 델타를 즉시 정화
    /// - ✅ UTF-8 멀티바이트 경계 안전 처리 (한글 등 문자 손실 방지)
    /// - ✅ U+FFFD 제거 금지 (미완성 바이트의 복구 기회 보장)
    /// - 부분적 특수 토큰만 제거
    /// - 성능 최적화: 필요한 경우만 처리
    ///
    /// **중요:** 
    /// - 델타 단계에서는 "�" (U+FFFD)를 제거하지 않습니다
    /// - UTF-8 멀티바이트가 스트림 경계에서 잘릴 경우, 다음 델타와 합쳐져야 복구 가능
    /// - 최종 출력(cleanAIOutput)에서만 남은 U+FFFD를 정리합니다
    ///
    /// - Parameters:
    ///   - delta: 스트리밍 토큰 델타
    ///   - modelID: 모델 ID
    /// - Returns: 정화된 토큰
    public static func cleanStreamingToken(_ delta: String, modelID: OnDeviceModelID) -> String {
        guard !delta.isEmpty else { return delta }

        var cleaned = delta

        // ❌ 주의: UTF-8 U+FFFD 제거를 스트리밍 단계에서 하지 않음
        // 이유: 멀티바이트 문자(한글 등)가 경계에서 잘릴 경우, 
        //       임시로 "�"가 나타났다가 다음 델타와 합쳐지면 복구됨
        //       여기서 제거하면 바이트 손실로 "참치 샐러드" → "치 샐러드" 현상 발생
        
        // Fast path: 특수 토큰 패턴이 없으면 즉시 반환
        guard cleaned.contains("<") || cleaned.contains("|>") else {
            return cleaned
        }

        let tokens = tokenSet(for: modelID)

        // 1. Stop sequences 즉시 필터링 (정확 매칭만 제거)
        for token in tokens.stopSequences {
            if cleaned == token {
                cleaned = ""
            } else {
                cleaned = cleaned.replacingOccurrences(of: token, with: "")
            }
        }

        // 2. 부분적 템플릿 토큰 필터링 — Qwen 계열(hcx05b/hcx15b)은 과도 필터 제거(자연어 훼손 방지)
        for pattern in tokens.partialPatterns {
            if tokens == .gemma3Style, cleaned.contains(pattern) {
                cleaned = cleaned.replacingOccurrences(of: pattern, with: "")
            }
        }

        // 3. 연속된 공백 정리 (토큰 제거 후 남은 공백들)
        if cleaned.contains("   ") {  // 3개 이상의 공백이 있을 때만 처리
            cleaned = cleaned.replacingOccurrences(
                of: #"\s{3,}"#,
                with: " ",
                options: .regularExpression
            )
        }

        return cleaned
    }

    // MARK: - AI Output Cleaning (출력 정화)

    /// **AI 출력 정화 (최종)**
    ///
    /// - 누출된 특수 토큰 제거
    /// - 깨진/부분 토큰 제거
    /// - 중복 패턴 제거
    /// - ✅ 남아있는 U+FFFD (�) 안전 처리
    /// - 사용자에게 보여줄 텍스트만 반환
    ///
    /// **중요:**
    /// - 최종 출력 단계에서만 U+FFFD를 처리합니다
    /// - 스트리밍 중에는 제거하지 않아 멀티바이트 문자 복구 기회를 보장합니다
    ///
    /// - Parameters:
    ///   - output: AI가 생성한 텍스트
    ///   - modelID: 모델 ID
    /// - Returns: 정화된 텍스트
    public static func cleanAIOutput(_ output: String, modelID: OnDeviceModelID) -> String {
        guard !output.isEmpty else { return output }

        var result = output
        let tokens = tokenSet(for: modelID)

        // 1단계: 정확한 토큰 매칭 제거
        for token in tokens.systemTokens {
            if result.contains(token) {
                result = result.replacingOccurrences(of: token, with: "")
            }
        }

        // 2단계: 정규식 기반 깨진 토큰 제거
        for pattern in tokens.brokenTokenPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: result.utf16.count)
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: range,
                    withTemplate: ""
                )
            }
        }

        // 3단계: 일반적인 깨진 마커 제거 (모델 무관)
        let universalPatterns = [
            #"<\|[^>|]*$"#,  // 미완성 <|...
            #"^[^<]*\|>"#,  // 미완성 ...|>
            #"<[^>]{0,3}$"#,  // 미완성 < 또는 <x, <xy
        ]

        for pattern in universalPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: result.utf16.count)
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: range,
                    withTemplate: ""
                )
            }
        }

        // 4단계: 남아있는 U+FFFD 안전 처리
        // 스트리밍이 모두 끝난 후에도 남아있는 U+FFFD는 실제 깨진 문자이므로 공백으로 치환
        // (삭제하면 단어가 붙을 수 있으므로 공백 치환이 안전)
        if result.contains("�") || result.contains("\u{FFFD}") {
            // 연속된 U+FFFD는 하나의 공백으로
            result = result.replacingOccurrences(of: "���", with: " ")
            result = result.replacingOccurrences(of: "��", with: " ")
            result = result.replacingOccurrences(of: "�", with: " ")
            result = result.replacingOccurrences(of: "\u{FFFD}", with: " ")
        }

        // 5단계: 유니코드 정규화(NFC) 및 최종 정리
        // - 조합형(NFD) → 완성형(NFC)로 정규화하여 한글/악센트 문자의 일관성 확보
        result = result.precomposedStringWithCanonicalMapping
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // 6단계: 중복 공백 정리
        if result.contains("  ") {  // 2개 이상의 공백이 있을 때만 처리
            result = result.replacingOccurrences(
                of: #"\s{2,}"#,
                with: " ",
                options: .regularExpression
            )
        }

        return result
    }

    // MARK: - Validation & Integrity Check

    /// **토큰 무결성 검증**
    ///
    /// - 텍스트에 위험한 토큰 패턴이 있는지 검사
    /// - 사용자 입력 검증에 사용
    ///
    /// - Parameters:
    ///   - text: 검사할 텍스트
    ///   - modelID: 모델 ID
    /// - Returns: (안전 여부, 발견된 위험 토큰)
    public static func validateTokenSafety(
        _ text: String,
        modelID: OnDeviceModelID
    ) -> (isSafe: Bool, riskyTokens: [String]) {
        guard !text.isEmpty else { return (true, []) }

        // Fast path: 의심 패턴이 없으면 즉시 안전 판정
        guard text.contains("<") || text.contains("|>") else {
            return (true, [])
        }

        let tokens = tokenSet(for: modelID)
        var found: [String] = []

        for token in tokens.systemTokens {
            if text.contains(token) {
                found.append(token)
            }
        }

        return (found.isEmpty, found)
    }

    // MARK: - Emoji-Safe Processing

    /// **이모티콘 보존 처리**
    ///
    /// - 일반적인 이모티콘 패턴을 보호하면서 특수 토큰만 처리
    /// - 화이트리스트 방식
    ///
    /// - Parameter text: 원본 텍스트
    /// - Returns: 이모티콘이 보존된 텍스트
    public static func preserveCommonEmojis(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        var result = text

        // 일반적인 이모티콘 패턴들 (특수 토큰과 충돌하지 않음)
        let safeEmojis: [(original: String, placeholder: String)] = [
            (":)", "[[SMILE]]"),
            (":(", "[[SAD]]"),
            (":D", "[[BIGGRIN]]"),
            ("^^", "[[HAPPY]]"),
            ("T_T", "[[CRY]]"),
            ("^_^", "[[JOY]]"),
            (">_<", "[[SHY]]"),
            ("O_O", "[[SURPRISE]]"),
            ("-_-", "[[MEH]]"),
            ("ㅠㅠ", "[[TEAR]]"),
            ("ㅋㅋ", "[[LOL]]"),
            ("><", "[[FISH]]"),  // 이모티콘 추가
        ]

        // 1단계: 이모티콘을 임시 플레이스홀더로 치환
        for (emoji, placeholder) in safeEmojis {
            if result.contains(emoji) {
                result = result.replacingOccurrences(of: emoji, with: placeholder)
            }
        }

        return result
    }

    /// **이모티콘 복원**
    ///
    /// - preserveCommonEmojis로 치환한 플레이스홀더를 원래대로 복원
    ///
    /// - Parameter text: 플레이스홀더가 포함된 텍스트
    /// - Returns: 이모티콘이 복원된 텍스트
    public static func restoreCommonEmojis(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        var result = text

        let emojiMap: [(placeholder: String, original: String)] = [
            ("[[SMILE]]", ":)"),
            ("[[SAD]]", ":("),
            ("[[BIGGRIN]]", ":D"),
            ("[[HAPPY]]", "^^"),
            ("[[CRY]]", "T_T"),
            ("[[JOY]]", "^_^"),
            ("[[SHY]]", ">_<"),
            ("[[SURPRISE]]", "O_O"),
            ("[[MEH]]", "-_-"),
            ("[[TEAR]]", "ㅠㅠ"),
            ("[[LOL]]", "ㅋㅋ"),
            ("[[FISH]]", "><"),
        ]

        // 플레이스홀더를 원래 이모티콘으로 복원
        for (placeholder, emoji) in emojiMap {
            if result.contains(placeholder) {
                result = result.replacingOccurrences(of: placeholder, with: emoji)
            }
        }

        return result
    }

    // MARK: - Debug & Diagnostics

    /// **디버그: 텍스트 내 특수 토큰 찾기**
    ///
    /// - 개발 및 디버깅 목적
    ///
    /// - Parameters:
    ///   - text: 검사할 텍스트
    ///   - modelID: 모델 ID
    /// - Returns: 발견된 토큰과 위치 정보
    public static func findSpecialTokens(
        in text: String,
        modelID: OnDeviceModelID
    ) -> [(token: String, range: Range<String.Index>)] {
        guard !text.isEmpty else { return [] }

        let tokens = tokenSet(for: modelID)
        var findings: [(String, Range<String.Index>)] = []

        for token in tokens.systemTokens {
            var searchRange = text.startIndex..<text.endIndex

            while let range = text.range(of: token, range: searchRange) {
                findings.append((token, range))
                searchRange = range.upperBound..<text.endIndex
            }
        }

        return findings.sorted { lhs, rhs in lhs.1.lowerBound < rhs.1.lowerBound }
    }
}

// MARK: - Private Extensions

extension SpecialTokenSanitizer.TokenSet: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.gemma3Style, .gemma3Style), (.hcx05bStyle, .hcx05bStyle), (.hcx15bStyle, .hcx15bStyle):
            return true
        default:
            return false
        }
    }
}
