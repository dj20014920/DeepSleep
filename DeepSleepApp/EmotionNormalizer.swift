import Foundation

struct EmotionNormalizer {
    // 확장 가능한 한국어 감정 동의어 매핑 테이블
    private static let mapping: [(normalized: String, keywords: [String])] = [
        ("평온", ["평온", "차분", "안정", "편안", "진정", "릴랙스", "휴식", "이완", "잔다", "잠온다"]),
        ("수면", ["수면", "잠", "졸림", "졸려", "눈감김", "코골이", "불면", "잠이 안와"]),
        ("불면", ["불면", "잠이 안", "잠 설침", "깬다", "뒤척"]),
        ("불안", ["불안", "걱정", "초조", "긴장", "공황", "긴급"]),
        ("스트레스", ["스트레스", "과부하", "압박", "피곤", "번아웃", "압도"]),
        ("우울", ["우울", "슬픔", "침울", "무기력", "허무", "의욕없"]),
        ("행복", ["행복", "기쁨", "즐거움", "희열", "기분 좋"]),
        ("활력", ["활력", "에너지", "힘", "상쾌", "산뜻", "기상"]),
        ("집중", ["집중", "몰입", "작업", "공부", "일", "코딩"]),
        ("창의", ["창의", "아이디어", "영감", "브레인스토밍"]),
        ("외로움", ["외로움", "고독", "그리움", "쓸쓸"]),
        ("분노", ["분노", "짜증", "화남", "열받"])
    ]

    static func normalize(_ text: String?) -> String {
        guard let raw = text?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "평온"
        }
        // 매핑 테이블 검색
        for entry in mapping {
            if entry.keywords.contains(where: { raw.contains($0) }) {
                return entry.normalized
            }
        }
        // 직접 매핑 실패 시, 보수적으로 기본값
        return "평온"
    }

    static func detect(in text: String?) -> String? {
        guard let raw = text?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        for entry in mapping {
            if entry.keywords.contains(where: { raw.contains($0) }) {
                return entry.normalized
            }
        }
        return nil
    }

    static func normalizeFromSignals(emotion: String?, recentUserTexts: [String], timeOfDay: String) -> String {
        // 1) 명시적 감정 우선
        let e1 = normalize(emotion)
        if e1 != "평온" || (emotion != nil && !(emotion!.isEmpty)) { return e1 }
        // 2) 최근 사용자 텍스트에서 감정 키워드 탐지
        for t in recentUserTexts.reversed() {
            if let d = detect(in: t) { return d }
        }
        // 3) 시간대 기반 폴백 (비활성화 가능)
        if AppConfig.Recommendation.useTimeOfDay {
            switch timeOfDay {
            case "새벽", "자정", "밤", "깊은밤": return "수면"
            case "아침": return "활력"
            case "오전", "점심": return "집중"
            case "오후": return "안정"
            case "저녁": return "이완"
            default: return "평온"
            }
        }
        return "평온"
    }
}
