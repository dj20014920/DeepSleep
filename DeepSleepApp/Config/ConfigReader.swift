//  ConfigReader.swift
//  DeepSleep
//
//  중앙집중형 구성 로딩 유틸리티
//  - Secrets.xcconfig → Info.plist → Bundle.main.object(forInfoDictionaryKey:)
//  - 타입 세이프 변환 + 안전한 로깅(민감값 미노출)
//  - 목적: DRY/KISS, 보안, 유지보수성 향상

import Foundation

public enum ConfigReader {
    // 내부 로깅: 실제 값은 절대 노출하지 않음
    private static func logMissing(_ key: String, type: String) {
        print("⚠️ [ConfigReader] Missing or invalid value for key=\(key), expected=\(type)")
    }

    // 원시 객체 조회 (String 또는 원시 타입)
    private static func raw(_ key: String) -> Any? {
        let value = Bundle.main.object(forInfoDictionaryKey: key)
        // xcconfig 미치환("$(KEY)") 또는 빈 문자열 방지
        if let s = value as? String, (s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || s.hasPrefix("$(")) {
            return nil
        }
        return value
    }

    // MARK: - Typed Getters
    public static func string(_ key: String, default defaultValue: String? = nil) -> String? {
        if let value = raw(key) as? String { return value }
        if let value = raw(key) as? NSString { return value as String }
        if let def = defaultValue { return def }
        logMissing(key, type: "String")
        return nil
    }

    public static func int(_ key: String, default defaultValue: Int? = nil) -> Int? {
        if let value = raw(key) as? Int { return value }
        if let s = raw(key) as? String, let v = Int(s) { return v }
        if let n = raw(key) as? NSNumber { return n.intValue }
        if let def = defaultValue { return def }
        logMissing(key, type: "Int")
        return nil
    }

    public static func double(_ key: String, default defaultValue: Double? = nil) -> Double? {
        if let value = raw(key) as? Double { return value }
        if let s = raw(key) as? String, let v = Double(s) { return v }
        if let n = raw(key) as? NSNumber { return n.doubleValue }
        if let def = defaultValue { return def }
        logMissing(key, type: "Double")
        return nil
    }

    public static func bool(_ key: String, default defaultValue: Bool? = nil) -> Bool? {
        if let value = raw(key) as? Bool { return value }
        if let s = raw(key) as? String {
            let lower = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["yes","true","1"].contains(lower) { return true }
            if ["no","false","0"].contains(lower) { return false }
        }
        if let n = raw(key) as? NSNumber { return n.boolValue }
        if let def = defaultValue { return def }
        logMissing(key, type: "Bool")
        return nil
    }
}
