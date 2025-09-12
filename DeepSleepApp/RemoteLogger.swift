import Foundation
import UIKit
import Network
import os.log

/// 🔍 배포된 앱의 로그를 원격으로 수집하는 매니저
class RemoteLogger {
    static let shared = RemoteLogger()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "리플릿(Leaflet)", category: "RemoteLogger")
    private var logBuffer: [LogEntry] = []
    private let maxBufferSize = 100
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "RemoteLogger")
    
    struct LogEntry: Codable {
        let timestamp: Date
        let level: LogLevel
        let message: String
        let category: String
        let userID: String?
        let appVersion: String
        let device: String
        
        enum LogLevel: String, Codable {
            case debug = "DEBUG"
            case info = "INFO"
            case warning = "WARNING"
            case error = "ERROR"
            case critical = "CRITICAL"
        }
    }
    
    private init() {
        // 네트워크 모니터링 비활성화 - nw_connection 오류 방지
        // startNetworkMonitoring() // 주석 처리
        setupPeriodicLogSend()
    }
    
    // MARK: - 로그 기록 메서드들
    
    /// 디버그 로그
    func debug(_ message: String, category: String = "General") {
        log(message, level: .debug, category: category)
    }
    
    /// 정보 로그
    func info(_ message: String, category: String = "General") {
        log(message, level: .info, category: category)
    }
    
    /// 경고 로그
    func warning(_ message: String, category: String = "General") {
        log(message, level: .warning, category: category)
    }
    
    /// 에러 로그
    func error(_ message: String, category: String = "General") {
        log(message, level: .error, category: category)
    }
    
    /// 크리티컬 로그
    func critical(_ message: String, category: String = "General") {
        log(message, level: .critical, category: category)
    }
    
    // MARK: - 특별한 이벤트 로깅
    
    /// AI 요청 로그
    func logAIRequest(prompt: String, response: String?, error: Error?) {
        if let error = error {
            self.error("AI 요청 실패: \(error.localizedDescription)", category: "AI")
        } else {
            self.info("AI 요청 성공 - Prompt: \(prompt.prefix(100))...", category: "AI")
        }
    }
    
    /// 프리셋 적용 로그
    func logPresetApplied(name: String, volumes: [Float]) {
        self.info("프리셋 적용됨: \(name) - 볼륨: \(volumes.prefix(5))", category: "Preset")
    }
    
    /// 사용자 행동 로그
    func logUserAction(action: String, details: [String: Any] = [:]) {
        let detailsString = details.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        self.info("사용자 액션: \(action) - \(detailsString)", category: "UserAction")
    }
    
    /// 앱 상태 변화 로그
    func logAppStateChange(from: String, to: String) {
        self.info("앱 상태 변화: \(from) → \(to)", category: "AppState")
    }
    
    /// 보안 사고 로그 (InputValidationManager와의 호환성)
    func logSecurityIncident(issues: [Any], context: String, timestamp: Date) {
        let issueDescriptions = issues.map { String(describing: $0) }.joined(separator: ", ")
        self.critical("보안 사고 감지: \(context) - 이슈: \(issueDescriptions)", category: "Security")
    }
    
    // MARK: - 내부 구현
    
    private func log(_ message: String, level: LogEntry.LogLevel, category: String) {
        // Xcode 콘솔에도 출력
        switch level {
        case .debug:
            logger.debug("[\(category)] \(message)")
        case .info:
            logger.info("[\(category)] \(message)")
        case .warning:
            logger.warning("[\(category)] \(message)")
        case .error:
            logger.error("[\(category)] \(message)")
        case .critical:
            logger.critical("[\(category)] \(message)")
        }
        
        // 원격 전송을 위해 버퍼에 저장
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            category: category,
            userID: getUserID(),
            appVersion: getAppVersion(),
            device: getDeviceInfo()
        )
        
        queue.async {
            self.logBuffer.append(entry)
            
            // 버퍼 크기 제한
            if self.logBuffer.count > self.maxBufferSize {
                self.logBuffer.removeFirst(self.logBuffer.count - self.maxBufferSize)
            }
            
            // 중요한 로그는 즉시 전송
            if level == .error || level == .critical {
                self.sendLogsImmediately()
            }
        }
    }
    
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                self?.sendPendingLogs()
            }
        }
        monitor.start(queue: queue)
    }
    
    private func setupPeriodicLogSend() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.sendPendingLogs()
        }
    }
    
    private func sendPendingLogs() {
        queue.async {
            guard !self.logBuffer.isEmpty else { return }
            self.sendLogsToServer(self.logBuffer)
        }
    }
    
    private func sendLogsImmediately() {
        queue.async {
            self.sendLogsToServer(self.logBuffer)
        }
    }
    
    private func sendLogsToServer(_ logs: [LogEntry]) {
        // 🚫 원격 로그 전송 완전 비활성화 - 네트워크 연결 시도 없음
        // 로컬 로그만 사용하여 nw_connection 오류 방지
        
        #if DEBUG
        print("📝 [RemoteLogger] \(logs.count)개 로그가 로컬에 저장됨 (원격 전송 완전 비활성화)")
        #endif
        
        // 로컬에서 버퍼 정리
        queue.async {
            self.logBuffer.removeAll()
        }
        
        // 네트워크 연결 시도 코드 완전 제거 - 모든 로그는 로컬에서만 처리
        // 향후 실제 서버 연결이 필요할 때만 별도 구현
    }
    
    // MARK: - 유틸리티 메서드들
    
    private func getUserID() -> String? {
        // 사용자 식별자 (익명화된)
        return UIDevice.current.identifierForVendor?.uuidString
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private func getDeviceInfo() -> String {
        let device = UIDevice.current
        return "\(device.model) (\(device.systemName) \(device.systemVersion))"
    }
}

// MARK: - 편의 확장

extension RemoteLogger {
    /// 성능 측정을 위한 시간 로깅
    func logPerformance<T>(operation: String, block: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            self.info("성능: \(operation) - \(String(format: "%.3f", timeElapsed))초", category: "Performance")
        }
        return try block()
    }
    
    /// 메모리 사용량 로깅
    func logMemoryUsage(context: String) {
        let memoryUsage = getMemoryUsage()
        self.info("메모리 사용량: \(context) - \(memoryUsage)MB", category: "Memory")
    }
    
    private func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size) / 1024 / 1024
        }
        return 0
    }
} 
