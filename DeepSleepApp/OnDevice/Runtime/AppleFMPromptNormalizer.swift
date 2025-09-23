import Foundation

//  AppleFMPromptNormalizer.swift
//  DeepSleep
//
//  목적
//  - Apple FM 캐시 키(sys + user)에 들어갈 user 텍스트를 표준화(정규화)하여
//    의미가 동일한 인사 변형(예: “안녕”/“안녕하세요!”/“하이!!”/“hello” 등)을
//    동일 키로 캐싱하도록 지원합니다.
//  - KISS/DRY: 단일 장소에서만 정규화 규칙을 관리합니다.
//  - YAGNI: 과도한 의도 추론/LLM 전처리는 하지 않습니다. 인사 전용 + 경량 정규화에 집중합니다.
//
//  사용처(권장)
//  - AppleFMCache 조회/저장 전에 user 텍스트를 normalizeUserForCache(_:)로 변환해 키를 생성하세요.
//  - UnifiedAIServiceImpl.sendMessageStream / sendMessageInternal 의 AFM 경로에서
//    AppleFMCache.get/put 호출 직전에 적용하는 것을 권장합니다.
//
//  캐시 히트 기대 효과
//  - 같은 페르소나/톤/모드에서 사용자가 인사만 여러 번 한 경우,
//    서로 다른 표기(안녕/안녕하세요/하이/hello/굿모닝)라도 "__GREETING__"로
//    표준화되어 캐시 히트가 발생합니다.
//
//  정책
//  - “인사만”으로 판단되는 짧은 문장(후술 ‘greeting-only’ 패턴)인 경우 → "__GREETING__" 반환
//  - 그 외(문장에 내용이 있거나 길이가 길고 의미가 다변화되는 경우) → 경량 정규화(공백/대소문/중복부호)만 수행
//  - 한국어/영어 인사 대표 패턴을 포함하며, 필요 시 규칙 배열에만 추가해 확장
//
//  주의
//  - 과도한 일반화는 캐시 오탐을 키웁니다. 인사 외 문장 치환은 하지 않습니다.
//  - 본 모듈은 “키 표준화” 전용이며, 실제 AFM 호출 전 텍스트를 변경하지 않습니다.
//

public enum AppleFMPromptNormalizer {
    // 캐시 토큰 (변경 시, 기존 캐시 무효화됨)
    public static let GREETING_TOKEN = "__GREETING__"

    // MARK: - Public API

    /// Apple FM 캐시 키 작성을 위해 user 텍스트를 정규화합니다.
    /// - 인사만 있는 경우: "__GREETING__"
    /// - 그 외: 경량 정규화(공백/대소문/중복부호 정리)
    public static func normalizeUserForCache(_ user: String) -> String {
        let trimmed = user.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }  // 빈 문자열은 그대로 반환

        // 빠른 길이/토큰 휴리스틱 + 정규식으로 “인사만” 여부 판정
        if isGreetingOnly(trimmed) {
            return GREETING_TOKEN
        }

        // 일반 문장: 보수적 정규화(공백/대소문/중복부호)
        return conservativeNormalize(trimmed)
    }

    /// (선택) sys와 user를 함께 표준화할 때 사용
    /// - sys는 공백 정리 수준만 수행(의미 보존이 최우선)
    public static func normalizeForCache(sys: String?, user: String) -> (sys: String?, user: String)
    {
        let sysNorm = sys.map { collapseSpaces($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        let userNorm = normalizeUserForCache(user)
        return (sys: (sysNorm?.isEmpty == true ? nil : sysNorm), user: userNorm)
    }

    /// 현재 입력이 “인사만”인지 여부를 반환 (디버깅/테스트용)
    public static func isGreetingOnly(_ text: String) -> Bool {
        // 1) 경량 정규화(대소문/공백/부호)
        let lowered = foldCase(text)
        let cleaned = removeSurroundingPunctuation(lowered)
        let collapsed = collapseSpaces(cleaned)

        // 2) 짧은 길이 & 짧은 토큰 수 휴리스틱 (과도한 오탐 방지)
        //    - 인사말은 일반적으로 매우 짧고 토큰 수도 작음
        let maxCharsForGreeting = 24
        let maxTokensForGreeting = 5
        if collapsed.count > maxCharsForGreeting { return false }
        let tokens = collapsed.split(whereSeparator: \.isWhitespace)
        if tokens.count > maxTokensForGreeting { return false }

        // 3) 정규식 판정(“인사만”에 해당하는 토큰/구 모두로 구성되었는가)
        //    - 예: "안녕", "안녕하세요", "하이!", "hello!!", "굿모닝", "좋은 아침", "오랜만이야", "ㅎㅇ"
        //    - 부호/이모지 등은 제거되어 있음
        return greetingOnlyRegex.matches(
            in: collapsed, range: NSRange(location: 0, length: collapsed.utf16.count)
        ).count > 0
    }

    // MARK: - Internal: Simple Normalization

    /// 일반 문장을 위한 보수적 정규화
    /// - 공백 접기, 대소문 폴딩, 연속 부호 단일화, 앞뒤 부호 제거
    private static func conservativeNormalize(_ s: String) -> String {
        var out = foldCase(s)
        out = collapseSpaces(out)
        out = dedupePunctuation(out)
        out = removeSurroundingPunctuation(out)
        return out
    }

    /// 대소문 폴딩(로케일 영향 최소화를 위해 기본 lowercased 사용)
    private static func foldCase(_ s: String) -> String {
        return s.lowercased()
    }

    /// 공백 접기: 연속 공백(스페이스/탭/개행)을 단일 스페이스로
    private static func collapseSpaces(_ s: String) -> String {
        // 빠른 경로: 공백이 없다면 바로 반환
        if s.rangeOfCharacter(from: .whitespacesAndNewlines) == nil { return s }
        var out = s
        // 모든 공백/개행 → space
        out = out.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        // 앞/뒤 공백 제거
        out = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return out
    }

    /// 연속 부호(???, !!!, ~~ 등)를 단일 문자로 축약
    private static func dedupePunctuation(_ s: String) -> String {
        var out = s
        let patterns = [
            "[?]{2,}": "?",  // ??? → ?
            "[!]{2,}": "!",  // !!! → !
            "[.]{3,}": "...",  // ..... → ...
            "…{2,}": "…",  // …… → …
            "[~]{2,}": "~",  // ~~~~ → ~
        ]
        for (p, r) in patterns {
            out = out.replacingOccurrences(of: p, with: r, options: .regularExpression)
        }
        return out
    }

    /// 앞뒤의 불필요한 부호/이모지/괄호 등을 제거 (문장 내부는 보존)
    private static func removeSurroundingPunctuation(_ s: String) -> String {
        // 양끝의 비-문자/숫자/한글/공백을 제거
        // (내부 의미 보존 위해 중앙은 건드리지 않음)
        // 유니코드 문자 범위를 넓게 포함하도록 정규식 구성
        let pattern = #"^[^\p{L}\p{N}\p{Han}\s]+|[^\p{L}\p{N}\p{Han}\s]+$"#
        var out = s
        // 좌우에서 여러 번 제거될 수 있으므로 반복
        while out.range(of: pattern, options: .regularExpression) != nil {
            out = out.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == out { break }
            out = trimmed
        }
        return out
    }

    // MARK: - Greeting-only Regex

    /// 인사 전용(문장 전체가 인사/간단한 인사 변형으로만 구성)일 때 true
    /// - 한국어/영어 대표 인사 + 시간대 인사 포함
    /// - 토큰/길이 휴리스틱과 함께 사용
    private static let greetingOnlyRegex: NSRegularExpression = {
        // 구성 요소:
        // - koCore: 안녕|안녕하세요|안녕하십니까|하이|ㅎㅇ|헬로(우)
        // - koAlt: 반가워|반갑습니다|오랜만(이야/이에요/입니다)
        // - koTime: 좋은 (아침|오전|오후|저녁|밤)
        // - enCore: hello|hi|hey|yo|sup
        // - enTime: good (morning|afternoon|evening)
        // - optional polite suffixes, and optional trailing punctuation
        //
        // 전체가 (인사 구 + (선택 부호))로만 이루어진 경우를 허용:
        // ^(?: (greet) (space/부호)* )+$
        let koCore = #"안녕(?:하세요|하십니까)?|하이|ㅎㅇ|헬로(?:우)?"#
        let koAlt = #"반갑(?:습니다|습니디|워|습니다)|오랜만(?:이야|이에요|입니다)?"#
        let koTime = #"좋은\s*(?:아침|오전|오후|저녁|밤)"#
        let enCore = #"hello|hi|hey|yo|sup"#
        let enTime = #"good\s*(?:morning|afternoon|evening)"#

        // 허용되는 “구” 하나
        let unit = #"(?:\s*(?:\(.*\))?\s*(?:__g__|__t__|__k__)\s*(?:[!?.~…]*)\s*)"#

        // 실제 패턴을 구성하기 전에 한국어/영어/시간대 인사들을
        // 플레이스홀더로 치환해 조합(읽기 쉬움)
        var pattern = #"^(?:"#
        // koCore | koAlt | koTime | enCore | enTime
        pattern += "(?:\(koCore)|\(koAlt)|\(koTime)|\(enCore)|\(enTime))"
        // 사이에 간단 부호/공백 허용 후 반복
        pattern += #"(?:\s*[!?.~…]*\s*)*$"#

        // 위의 가독성용 문자열 그대로 사용 (플레이스홀더 기법은 단순화)
        // 정규식 옵션: 대소문자 무시
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()
}

// MARK: - 간단 테스트(주석 참고)
//
// let cases = [
//   "안녕", "안녕하세요!!", "하이~", "ㅎㅇ", "헬로우!", "HELLO!!", "Hey!",
//   "좋은 아침", "Good morning!!", "오랜만이야", "반가워",
//   "안녕 오늘 어땠어?", "hello how are you", "안녕하세요, 오늘 일정 알려줘"
// ]
// for s in cases {
//   print(String(format: "%-20s -> %@", (s as NSString).utf8String!, AppleFMPromptNormalizer.normalizeUserForCache(s)))
// }
//
// 기대:
// - 인사만: "__GREETING__"
// - 내용 포함: 보수적 정규화 결과(원문 보존성 유지)
