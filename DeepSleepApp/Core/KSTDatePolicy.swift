import Foundation

public enum KSTDatePolicy {
    /// 대한민국 표준시(KST) 기준으로 월요일 00:00인지 판단
    public static func isKSTMonday00(now: Date = Date()) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let comps = cal.dateComponents([.weekday, .hour, .minute], from: now)
        return comps.weekday == 2 && comps.hour == 0 && comps.minute == 0 // Monday==2 in Gregorian
    }
}

