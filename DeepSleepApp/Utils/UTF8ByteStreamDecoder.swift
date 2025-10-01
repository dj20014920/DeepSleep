//
//  UTF8ByteStreamDecoder.swift
//  DeepSleep
//
//  Byte-level UTF-8 streaming decoder to safely assemble multi-byte characters
//  across chunk boundaries (e.g., Hangul syllables, emojis).
//

import Foundation

/// UTF-8 바이트 스트리밍 디코더
/// - 목적: 멀티바이트 문자가 스트림 경계에서 잘리지 않도록 바이트 단위로 누적 후
///         완전한 경계에서만 문자열로 디코딩한다.
public final class UTF8ByteStreamDecoder {
    private var incomplete: [UInt8] = []

    public init() {}

    /// 바이트 조각을 처리하고 완전한 UTF-8 조각만 문자열로 반환한다.
    /// - Parameter bytes: 새로 수신한 바이트 조각
    /// - Returns: 디코딩된 문자열 조각 (미완성 부분은 내부에 보류)
    public func processBytes(_ bytes: [UInt8]) -> String {
        guard !bytes.isEmpty else { return "" }
        var merged = incomplete
        merged.append(contentsOf: bytes)

        // 마지막 최대 4바이트 검사하여 경계 지점 계산
        if merged.isEmpty { return "" }
        let searchStart = max(0, merged.count - 4)
        var splitIndex = merged.count
        for i in stride(from: merged.count - 1, through: searchStart, by: -1) {
            let b = merged[i]
            // continuation(10xxxxxx)이 아니면 시작 바이트 후보
            if (b & 0b1100_0000) != 0b1000_0000 {
                let expected: Int
                if (b & 0b1000_0000) == 0 { expected = 1 }
                else if (b & 0b1110_0000) == 0b1100_0000 { expected = 2 }
                else if (b & 0b1111_0000) == 0b1110_0000 { expected = 3 }
                else if (b & 0b1111_1000) == 0b1111_0000 { expected = 4 }
                else { expected = 1 }
                let actual = merged.count - i
                if actual < expected { splitIndex = i }
                break
            }
        }

        if splitIndex == merged.count {
            // 모두 완전 → 전부 디코딩
            incomplete.removeAll(keepingCapacity: true)
            return String(decoding: merged, as: UTF8.self)
        } else if splitIndex > 0 {
            let complete = Array(merged[..<splitIndex])
            let rest = Array(merged[splitIndex...])
            incomplete = rest
            return String(decoding: complete, as: UTF8.self)
        } else {
            // 처음부터 미완성 → 보류만
            incomplete = merged
            return ""
        }
    }

    /// 스트림 종료 시 남은 바이트를 강제 디코딩하여 반환한다.
    public func flush() -> String {
        guard !incomplete.isEmpty else { return "" }
        let s = String(decoding: incomplete, as: UTF8.self)
        incomplete.removeAll()
        return s
    }

    /// 내부 버퍼를 초기화한다.
    public func reset() { incomplete.removeAll() }
}

