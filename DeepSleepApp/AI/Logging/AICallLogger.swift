//
//  AICallLogger.swift
//  DeepSleep
//
//  Created by Claude on 2025-07-23.
//  Copyright © 2025 DeepSleep. All rights reserved.
//

import Foundation
import os.log

/// 📊 AI 호출 전용 로깅 시스템
/// 통합 아키텍처의 모든 AI 호출을 추적하고 디버깅을 지원
public final class AICallLogger {
    
    public static let shared = AICallLogger()
    private init() {}
    
    // MARK: - 📝 로깅 설정
    
    private let logger = Logger(subsystem: "com.deepsleep.ai", category: "AICallLogger")
    private let fileManager = FileManager.default
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    private var logFilePath: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("ai_calls.log")
    }
    
    // MARK: - 📊 AI 호출 로깅
    
    /// AI 호출 시작 로그
    /// - Parameters:
    ///   - mode: AI 모드
    ///   - model: AI 모델
    ///   - userInput: 사용자 입력 (민감 정보 마스킹)
    ///   - callId: 호출 고유 ID
    public func logAICallStart(
        mode: AIMode,
        model: AIModel,
        userInput: String,
        callId: String = UUID().uuidString
    ) -> String {
        let maskedInput = maskSensitiveData(userInput)
        let logEntry = AICallLogEntry(
            id: callId,
            timestamp: Date(),
            mode: mode,
            model: model,
            userInput: maskedInput,
            status: .started
        )
        
        writeLog(entry: logEntry)
        
        logger.info("🚀 AI 호출 시작 - Mode: \(mode.displayName), Model: \(model.displayName), ID: \(callId)")
        
        return callId
    }
    
    /// AI 호출 성공 로그
    /// - Parameters:
    ///   - callId: 호출 고유 ID
    ///   - responseLength: 응답 길이
    ///   - processingTime: 처리 시간 (밀리초)
    ///   - tokenUsage: 토큰 사용량 (선택사항)
    public func logAICallSuccess(
        callId: String,
        responseLength: Int,
        processingTime: Int,
        tokenUsage: TokenUsage? = nil
    ) {
        let logEntry = AICallLogEntry(
            id: callId,
            timestamp: Date(),
            status: .success,
            responseLength: responseLength,
            processingTime: processingTime,
            tokenUsage: tokenUsage
        )
        
        writeLog(entry: logEntry)
        
        logger.info("✅ AI 호출 성공 - ID: \(callId), 응답 길이: \(responseLength), 처리 시간: \(processingTime)ms")
    }
    
    /// AI 호출 실패 로그
    /// - Parameters:
    ///   - callId: 호출 고유 ID
    ///   - error: 발생한 에러
    ///   - processingTime: 처리 시간 (밀리초)
    public func logAICallFailure(
        callId: String,
        error: AIServiceError,
        processingTime: Int
    ) {
        let logEntry = AICallLogEntry(
            id: callId,
            timestamp: Date(),
            mode: nil,
            model: nil,
            userInput: nil,
            status: .failed,
            responseLength: nil,
            processingTime: processingTime,
            errorType: String(describing: error),
            errorMessage: error.localizedDescription,
            tokenUsage: nil,
            usageInfo: nil
        )
        
        writeLog(entry: logEntry)
        
        logger.error("❌ AI 호출 실패 - ID: \(callId), 에러: \(error.shortTitle), 처리 시간: \(processingTime)ms")
    }
    
    /// 사용량 제한 초과 로그
    /// - Parameters:
    ///   - mode: AI 모드
    ///   - currentUsage: 현재 사용량
    ///   - dailyLimit: 일일 제한
    public func logUsageLimitExceeded(
        mode: AIMode,
        currentUsage: Int,
        dailyLimit: Int
    ) {
        let logEntry = AICallLogEntry(
            id: UUID().uuidString,
            timestamp: Date(),
            mode: mode,
            status: .usageLimitExceeded,
            usageInfo: UsageInfo(currentUsage: currentUsage, dailyLimit: dailyLimit)
        )
        
        writeLog(entry: logEntry)
        
        logger.warning("🚫 사용량 제한 초과 - Mode: \(mode.displayName), 사용량: \(currentUsage)/\(dailyLimit)")
    }
    
    // MARK: - 📈 통계 및 분석
    
    /// 일별 AI 호출 통계 조회
    /// - Parameter date: 조회할 날짜
    /// - Returns: 일별 통계
    public func getDailyStats(for date: Date) -> DailyAIStats {
        let logs = readLogsForDate(date)
        
        return DailyAIStats(
            date: date,
            totalCalls: logs.count,
            successfulCalls: logs.filter { $0.status == .success }.count,
            failedCalls: logs.filter { $0.status == .failed }.count,
            usageLimitExceeded: logs.filter { $0.status == .usageLimitExceeded }.count,
            averageProcessingTime: calculateAverageProcessingTime(logs),
            modeDistribution: calculateModeDistribution(logs),
            modelDistribution: calculateModelDistribution(logs)
        )
    }
    
    /// 최근 에러 목록 조회
    /// - Parameter limit: 조회할 에러 개수
    /// - Returns: 최근 에러 목록
    public func getRecentErrors(limit: Int = 10) -> [AICallLogEntry] {
        let logs = readRecentLogs(days: 7)
        return logs.filter { $0.status == .failed }
                   .prefix(limit)
                   .map { $0 }
    }
    
    /// 성능 문제 탐지
    /// - Returns: 성능 문제 리포트
    public func detectPerformanceIssues() -> PerformanceReport {
        let logs = readRecentLogs(days: 1)
        
        let slowCalls = logs.filter { ($0.processingTime ?? 0) > 10000 } // 10초 이상
        let highErrorRate = Double(logs.filter { $0.status == .failed }.count) / Double(logs.count) > 0.1
        
        return PerformanceReport(
            slowCallsCount: slowCalls.count,
            highErrorRate: highErrorRate,
            averageProcessingTime: calculateAverageProcessingTime(logs),
            recommendations: generatePerformanceRecommendations(logs)
        )
    }
    
    // MARK: - 🗂️ 로그 파일 관리
    
    private func writeLog(entry: AICallLogEntry) {
        let logLine = formatLogEntry(entry) + "\n"
        
        if let data = logLine.data(using: .utf8) {
            if fileManager.fileExists(atPath: logFilePath.path) {
                // 파일이 존재하면 추가
                if let fileHandle = try? FileHandle(forWritingTo: logFilePath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                // 파일이 없으면 생성
                try? data.write(to: logFilePath)
            }
        }
        
        // 로그 파일 크기 관리 (5MB 초과 시 정리)
        manageLogFileSize()
    }
    
    private func formatLogEntry(_ entry: AICallLogEntry) -> String {
        let timestamp = dateFormatter.string(from: entry.timestamp)
        var components = [timestamp, entry.id, entry.status.rawValue]
        
        if let mode = entry.mode {
            components.append("mode:\(mode.rawValue)")
        }
        
        if let model = entry.model {
            components.append("model:\(model.rawValue)")
        }
        
        if let processingTime = entry.processingTime {
            components.append("time:\(processingTime)ms")
        }
        
        if let errorType = entry.errorType {
            components.append("error:\(errorType)")
        }
        
        return components.joined(separator: " | ")
    }
    
    private func readLogsForDate(_ date: Date) -> [AICallLogEntry] {
        guard let content = try? String(contentsOf: logFilePath) else { return [] }
        
        let dateString = DateFormatter().string(from: date)
        return content.components(separatedBy: .newlines)
                     .filter { $0.contains(dateString) }
                     .compactMap { parseLogLine($0) }
    }
    
    private func readRecentLogs(days: Int) -> [AICallLogEntry] {
        guard let content = try? String(contentsOf: logFilePath) else { return [] }
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        return content.components(separatedBy: .newlines)
                     .compactMap { parseLogLine($0) }
                     .filter { $0.timestamp >= cutoffDate }
                     .sorted { $0.timestamp > $1.timestamp }
    }
    
    private func parseLogLine(_ line: String) -> AICallLogEntry? {
        // 간단한 로그 파싱 로직 (실제로는 더 정교한 파싱 필요)
        let components = line.components(separatedBy: " | ")
        guard components.count >= 3 else { return nil }
        
        let timestamp = dateFormatter.date(from: components[0]) ?? Date()
        let id = components[1]
        let status = AICallStatus(rawValue: components[2]) ?? .unknown
        
        return AICallLogEntry(id: id, timestamp: timestamp, status: status)
    }
    
    private func manageLogFileSize() {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: logFilePath.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            // 5MB 초과 시 오래된 로그 삭제
            if fileSize > 5 * 1024 * 1024 {
                rotateLogFile()
            }
        } catch {
            logger.error("로그 파일 크기 확인 실패: \(error)")
        }
    }
    
    private func rotateLogFile() {
        // 기존 로그를 백업하고 새 로그 파일 시작
        let backupPath = logFilePath.appendingPathExtension("backup")
        try? fileManager.moveItem(at: logFilePath, to: backupPath)
        
        logger.info("로그 파일 로테이션 완료")
    }
    
    // MARK: - 🔒 프라이버시 및 보안
    
    private func maskSensitiveData(_ input: String) -> String {
        var masked = input
        
        // 이메일 패턴 마스킹
        let emailRegex = try! NSRegularExpression(pattern: #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#)
        masked = emailRegex.stringByReplacingMatches(in: masked, options: [], range: NSRange(location: 0, length: masked.count), withTemplate: "***@***.***")
        
        // 전화번호 패턴 마스킹
        let phoneRegex = try! NSRegularExpression(pattern: #"\d{3}-\d{4}-\d{4}"#)
        masked = phoneRegex.stringByReplacingMatches(in: masked, options: [], range: NSRange(location: 0, length: masked.count), withTemplate: "***-****-****")
        
        // 긴 개인 정보성 텍스트는 일부만 표시
        if masked.count > 200 {
            masked = String(masked.prefix(100)) + "...[truncated \(masked.count - 100) chars]"
        }
        
        return masked
    }
    
    // MARK: - 📊 분석 헬퍼 메서드
    
    private func calculateAverageProcessingTime(_ logs: [AICallLogEntry]) -> Double {
        let validTimes = logs.compactMap { $0.processingTime }.filter { $0 > 0 }
        return validTimes.isEmpty ? 0 : Double(validTimes.reduce(0, +)) / Double(validTimes.count)
    }
    
    private func calculateModeDistribution(_ logs: [AICallLogEntry]) -> [AIMode: Int] {
        var distribution: [AIMode: Int] = [:]
        for log in logs {
            if let mode = log.mode {
                distribution[mode, default: 0] += 1
            }
        }
        return distribution
    }
    
    private func calculateModelDistribution(_ logs: [AICallLogEntry]) -> [AIModel: Int] {
        var distribution: [AIModel: Int] = [:]
        for log in logs {
            if let model = log.model {
                distribution[model, default: 0] += 1
            }
        }
        return distribution
    }
    
    private func generatePerformanceRecommendations(_ logs: [AICallLogEntry]) -> [String] {
        var recommendations: [String] = []
        
        let averageTime = calculateAverageProcessingTime(logs)
        if averageTime > 5000 {
            recommendations.append("평균 응답 시간이 5초를 초과합니다. 토큰 수를 줄이거나 더 빠른 모델 사용을 고려하세요.")
        }
        
        let errorRate = Double(logs.filter { $0.status == .failed }.count) / Double(logs.count)
        if errorRate > 0.1 {
            recommendations.append("오류율이 10%를 초과합니다. 네트워크 연결이나 API 키를 확인하세요.")
        }
        
        return recommendations
    }
}

// MARK: - 📊 데이터 구조체들

/// AI 호출 로그 엔트리
public struct AICallLogEntry {
    let id: String
    let timestamp: Date
    
    // 호출 정보
    let mode: AIMode?
    let model: AIModel?
    let userInput: String?
    
    // 상태 정보
    let status: AICallStatus
    
    // 응답 정보
    let responseLength: Int?
    let processingTime: Int?
    
    // 에러 정보
    let errorType: String?
    let errorMessage: String?
    
    // 사용량 정보
    let tokenUsage: TokenUsage?
    let usageInfo: UsageInfo?
    
    init(
        id: String,
        timestamp: Date,
        mode: AIMode? = nil,
        model: AIModel? = nil,
        userInput: String? = nil,
        status: AICallStatus,
        responseLength: Int? = nil,
        processingTime: Int? = nil,
        errorType: String? = nil,
        errorMessage: String? = nil,
        tokenUsage: TokenUsage? = nil,
        usageInfo: UsageInfo? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.mode = mode
        self.model = model
        self.userInput = userInput
        self.status = status
        self.responseLength = responseLength
        self.processingTime = processingTime
        self.errorType = errorType
        self.errorMessage = errorMessage
        self.tokenUsage = tokenUsage
        self.usageInfo = usageInfo
    }
}

/// AI 호출 상태
public enum AICallStatus: String, CaseIterable {
    case started = "STARTED"
    case success = "SUCCESS"
    case failed = "FAILED"
    case usageLimitExceeded = "USAGE_LIMIT_EXCEEDED"
    case unknown = "UNKNOWN"
}

/// 사용량 정보
public struct UsageInfo {
    let currentUsage: Int
    let dailyLimit: Int
}

/// 일별 AI 통계
public struct DailyAIStats {
    let date: Date
    let totalCalls: Int
    let successfulCalls: Int
    let failedCalls: Int
    let usageLimitExceeded: Int
    let averageProcessingTime: Double
    let modeDistribution: [AIMode: Int]
    let modelDistribution: [AIModel: Int]
    
    var successRate: Double {
        return totalCalls > 0 ? Double(successfulCalls) / Double(totalCalls) : 0
    }
}

/// 성능 리포트
public struct PerformanceReport {
    let slowCallsCount: Int
    let highErrorRate: Bool
    let averageProcessingTime: Double
    let recommendations: [String]
}