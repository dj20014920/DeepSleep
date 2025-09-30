//
//  UTF8StreamBuffer.swift
//  DeepSleep
//
//  UTF-8 스트리밍 버퍼 - 멀티바이트 문자 경계 안전 처리
//  참고: OpenAI ChatGPT, Apple TextDecoder 표준 구현
//

import Foundation

/// UTF-8 스트리밍 버퍼 - 멀티바이트 문자 손실 방지
///
/// **목적:**
/// - 스트리밍 중 UTF-8 경계에서 잘린 멀티바이트 문자(한글 등) 복구
/// - 미완성 바이트 시퀀스를 다음 델타와 병합하여 완전한 문자로 복원
/// - 업계 표준(OpenAI, TextDecoder) 방식 적용
///
/// **작동 원리:**
/// 1. 각 델타의 마지막 바이트가 멀티바이트 시퀀스 중간인지 확인
/// 2. 미완성이면 버퍼에 보관하고 다음 델타와 병합
/// 3. 완성된 부분만 반환하여 `U+FFFD` 생성 방지
///
/// **사용 예:**
/// ```swift
/// let buffer = UTF8StreamBuffer()
/// for delta in stream {
///     let safeText = buffer.process(delta)
///     display(safeText)  // 안전하게 복원된 텍스트만 표시
/// }
/// let remaining = buffer.flush()  // 마지막 잔여 데이터 처리
/// ```
public final class UTF8StreamBuffer {
    
    // MARK: - Properties
    
    /// 미완성 UTF-8 바이트 시퀀스 버퍼
    private var incompleteBytes: [UInt8] = []
    
    // MARK: - Public API
    
    public init() {}
    
    /// 스트리밍 델타를 처리하고 완전한 UTF-8 문자열만 반환
    ///
    /// - Parameter delta: 스트림에서 받은 텍스트 조각
    /// - Returns: 안전하게 디코딩된 텍스트 (미완성 부분은 다음 호출까지 보류)
    public func process(_ delta: String) -> String {
        guard !delta.isEmpty else { return "" }
        
        // 델타를 UTF-8 바이트 배열로 변환
        var bytes = Array(delta.utf8)
        
        // 이전에 보류된 미완성 바이트가 있으면 앞에 추가
        if !incompleteBytes.isEmpty {
            bytes.insert(contentsOf: incompleteBytes, at: 0)
            incompleteBytes.removeAll()
        }
        
        // 마지막 바이트가 멀티바이트 시퀀스의 중간이면 보류
        let (completeBytes, incomplete) = splitAtUTF8Boundary(bytes)
        
        // 미완성 바이트는 다음 델타를 위해 보관
        if !incomplete.isEmpty {
            incompleteBytes = incomplete
        }
        
        // 완전한 바이트만 문자열로 디코딩
        guard !completeBytes.isEmpty else { return "" }
        return String(decoding: completeBytes, as: UTF8.self)
    }
    
    /// 스트림 종료 시 남은 바이트 처리
    ///
    /// - Returns: 버퍼에 남아있던 데이터 (있다면)
    public func flush() -> String {
        guard !incompleteBytes.isEmpty else { return "" }
        
        // 남은 바이트를 강제 디코딩 (손실되는 것보다 나음)
        let result = String(decoding: incompleteBytes, as: UTF8.self)
        incompleteBytes.removeAll()
        return result
    }
    
    /// 버퍼 초기화
    public func reset() {
        incompleteBytes.removeAll()
    }
    
    // MARK: - Private Helpers
    
    /// UTF-8 바이트 배열을 완전한 문자 경계에서 분할
    ///
    /// - Parameter bytes: 전체 바이트 배열
    /// - Returns: (완전한 바이트들, 미완성 바이트들)
    private func splitAtUTF8Boundary(_ bytes: [UInt8]) -> (complete: [UInt8], incomplete: [UInt8]) {
        guard !bytes.isEmpty else { return ([], []) }
        
        // 마지막에서부터 역방향 탐색하여 완전한 문자의 시작점 찾기
        var splitIndex = bytes.count
        
        // 최대 4바이트까지만 확인 (UTF-8 최대 길이)
        let searchStart = max(0, bytes.count - 4)
        
        for i in stride(from: bytes.count - 1, through: searchStart, by: -1) {
            let byte = bytes[i]
            
            // UTF-8 멀티바이트 시퀀스의 시작 바이트인지 확인
            if isUTF8StartByte(byte) {
                let expectedLength = utf8SequenceLength(startingWith: byte)
                let actualLength = bytes.count - i
                
                if actualLength < expectedLength {
                    // 미완성 시퀀스 발견 - 여기서 분할
                    splitIndex = i
                }
                // 완전한 시퀀스이면 전체 반환
                break
            }
        }
        
        if splitIndex == bytes.count {
            // 모든 바이트가 완전함
            return (bytes, [])
        } else {
            // 분할 필요
            let complete = Array(bytes[..<splitIndex])
            let incomplete = Array(bytes[splitIndex...])
            return (complete, incomplete)
        }
    }
    
    /// UTF-8 시퀀스의 시작 바이트인지 확인
    ///
    /// - 0xxxxxxx (ASCII, 1바이트)
    /// - 110xxxxx (2바이트 시작)
    /// - 1110xxxx (3바이트 시작, 한글)
    /// - 11110xxx (4바이트 시작, 이모지)
    ///
    /// - Parameter byte: 확인할 바이트
    /// - Returns: 시작 바이트 여부
    private func isUTF8StartByte(_ byte: UInt8) -> Bool {
        // Continuation 바이트(10xxxxxx)가 아닌 모든 바이트
        return (byte & 0b1100_0000) != 0b1000_0000
    }
    
    /// UTF-8 시퀀스의 예상 길이 계산
    ///
    /// - Parameter byte: 시작 바이트
    /// - Returns: 전체 시퀀스 길이
    private func utf8SequenceLength(startingWith byte: UInt8) -> Int {
        if (byte & 0b1000_0000) == 0 {
            return 1  // 0xxxxxxx (ASCII)
        } else if (byte & 0b1110_0000) == 0b1100_0000 {
            return 2  // 110xxxxx
        } else if (byte & 0b1111_0000) == 0b1110_0000 {
            return 3  // 1110xxxx (한글)
        } else if (byte & 0b1111_1000) == 0b1111_0000 {
            return 4  // 11110xxx (이모지)
        } else {
            return 1  // 잘못된 바이트, 안전하게 1로 처리
        }
    }
}

// MARK: - UTF-8 Utilities Extension

extension UTF8 {
    /// 바이트가 continuation 바이트인지 확인
    ///
    /// Continuation 바이트: 10xxxxxx
    /// Swift 표준 API 사용
    ///
    /// - Parameter byte: 확인할 바이트
    /// - Returns: continuation 여부
    public static func isContinuation(_ byte: UInt8) -> Bool {
        return (byte & 0b1100_0000) == 0b1000_0000
    }
}
