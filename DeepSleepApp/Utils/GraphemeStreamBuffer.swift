//
//  GraphemeStreamBuffer.swift
//  DeepSleep
//
//  목적: 스트리밍 텍스트 델타에서 결합 문자/이모지 ZWJ/VARIATION/지역표시자(국기) 등
//       그래펨(사용자 인지 문자) 경계가 델타 끝에서 끊기지 않도록 완전한 경계까지만 방출.
//

import Foundation

public final class GraphemeStreamBuffer {
    private var pendingScalars: [Unicode.Scalar] = []

    public init() {}

    /// 델타 텍스트를 받아 그래펨 경계에서만 안전하게 방출한다.
    /// - Parameter text: 새로 수신한 텍스트 조각 (유효한 UTF-8 가정)
    /// - Returns: 완전한 그래펨으로만 구성된 텍스트. 미완성 조각은 내부에 보류.
    public func process(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        var scalars = pendingScalars
        scalars.append(contentsOf: text.unicodeScalars)

        if scalars.isEmpty { return "" }

        let holdCount = trailingUnsafeCount(in: scalars)
        let safeCount = scalars.count - holdCount
        if safeCount <= 0 {
            // 전부 보류
            pendingScalars = scalars
            return ""
        }
        let safe = scalars[..<safeCount]
        let rest = scalars[safeCount...]
        pendingScalars = Array(rest)
        return String(String.UnicodeScalarView(safe))
    }

    /// 스트림 종료 시 보류 중인 스칼라를 모두 방출한다.
    public func flush() -> String {
        guard !pendingScalars.isEmpty else { return "" }
        let s = String(String.UnicodeScalarView(pendingScalars))
        pendingScalars.removeAll()
        return s
    }

    public func reset() { pendingScalars.removeAll() }

    // MARK: - Heuristics

    /// 델타 끝에서 보류해야 할 스칼라 개수 계산
    /// 결합표(CMn), ZWJ/VS, 피부톤, 지역표시자(국기) 홀수개 등은 보류
    private func trailingUnsafeCount(in scalars: [Unicode.Scalar]) -> Int {
        var count = 0
        var i = scalars.count - 1
        if i < 0 { return 0 }

        // 1) 지역 표시자(국기) U+1F1E6..U+1F1FF → 짝수 쌍 단위로 유효
        var trailingRI = 0
        while i - trailingRI >= 0, isRegionalIndicator(scalars[i - trailingRI]) {
            trailingRI += 1
        }
        if trailingRI % 2 == 1 {
            // 마지막 RI 1개는 홀수 → 보류
            count = max(count, 1)
        }

        // 2) 결합표/ZWJ/Variation Selector/피부톤 수정자 등은 끝에 오면 보류
        var trailingCombining = 0
        while i - trailingCombining >= 0, isUnsafeStandaloneTail(scalars[i - trailingCombining]) {
            trailingCombining += 1
        }
        count = max(count, trailingCombining)

        return count
    }

    private func isRegionalIndicator(_ s: Unicode.Scalar) -> Bool {
        return (0x1F1E6...0x1F1FF).contains(s.value)
    }

    private func isVariationSelector(_ s: Unicode.Scalar) -> Bool {
        return (0xFE00...0xFE0F).contains(s.value) || (0xE0100...0xE01EF).contains(s.value)
    }

    private func isZeroWidthJoiner(_ s: Unicode.Scalar) -> Bool {
        return s.value == 0x200D || s.value == 0x200C
    }

    private func isSkinToneModifier(_ s: Unicode.Scalar) -> Bool {
        return (0x1F3FB...0x1F3FF).contains(s.value)
    }

    private func isCombiningMark(_ s: Unicode.Scalar) -> Bool {
        // canonicalCombiningClass != .notReordered (0) → 결합표
        return s.properties.canonicalCombiningClass != .notReordered
    }

    private func isUnsafeStandaloneTail(_ s: Unicode.Scalar) -> Bool {
        return isCombiningMark(s) || isVariationSelector(s) || isZeroWidthJoiner(s) || isSkinToneModifier(s)
    }
}

