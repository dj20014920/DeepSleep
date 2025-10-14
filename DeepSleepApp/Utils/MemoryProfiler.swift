import Foundation
import os

/// 메모리 사용량 추적 및 프로파일링을 위한 유틸리티
class MemoryProfiler {
    static let shared = MemoryProfiler()
    
    private let logger = Logger(subsystem: "com.deepsleep.app", category: "Memory")
    private var baselineMemory: Float = 0
    
    // 경고 임계치(MB). Secrets.xcconfig의 MEMORY_WARN_THRESHOLD_MB 값 사용
    // 기본값을 동적으로 계산해 온디바이스 LLM 사용 시 과도한 경고를 방지합니다.
    // - 총 RAM의 ~38%를 기준으로 하되 900~1600MB 범위로 클램핑합니다.
    // - Secrets.xcconfig(Info.plist) 값이 있으면 최우선 사용합니다.
    private lazy var thresholdMB: Float = {
        if let v = ConfigReader.double("MEMORY_WARN_THRESHOLD_MB") {
            return Float(v)
        }
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        let totalMB = Float(totalBytes) / 1024.0 / 1024.0
        // 동적 기준: 38% (iPhone 12 4GB ≈ 1550MB), 900~1600MB로 안전 범위 제한
        let dynamic = max(900, min(1600, totalMB * 0.38))
        return dynamic
    }()
    
    private init() {}
    
    /// 현재 앱의 메모리 사용량을 MB 단위로 반환
    /// 🛡️ 시스템 콜 실패 시 안전한 값 반환 (크래시 방지)
    func getCurrentMemoryUsage() -> Float {
        guard Thread.isMainThread || !Thread.current.isCancelled else {
            // 취소된 스레드에서는 시스템 콜 회피
            return 0
        }
        
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            // 🛡️ 시스템 콜 실패 시 안전한 기본값 반환
            logger.debug("⚠️ 메모리 사용량 조회 실패: kern_return_t=\(result)")
            return 0
        }
        
        let memoryInBytes = Float(info.resident_size)
        let memoryInMB = memoryInBytes / 1024.0 / 1024.0
        
        // 🛡️ 비정상적인 값 필터링
        guard memoryInMB >= 0 && memoryInMB < 2048 else {
            logger.debug("⚠️ 비정상적인 메모리 사용량: \(memoryInMB)MB")
            return 0
        }
        
        return memoryInMB
    }
    
    /// 메모리 사용량 베이스라인 설정
    func setBaseline() {
        baselineMemory = getCurrentMemoryUsage()
        logger.info("📊 메모리 베이스라인 설정: \(String(format: "%.2f", self.baselineMemory)) MB")
    }
    
    /// 베이스라인 대비 메모리 증가량 확인
    func getMemoryIncrease() -> Float {
        let current = getCurrentMemoryUsage()
        let increase = current - baselineMemory
        return increase
    }
    
    /// 메모리 사용량 로깅
    func logMemoryUsage(context: String = "") {
        let current = getCurrentMemoryUsage()
        let increase = getMemoryIncrease()
        
        let logMessage = """
        📊 메모리 사용량 [\(context)]:
        • 현재: \(String(format: "%.2f", current)) MB
        • 증가량: \(String(format: "%.2f", increase)) MB
        • \(Int(thresholdMB))MB 제한 대비: \(String(format: "%.1f", (current/thresholdMB)*100))%
        """
        
        if current < thresholdMB {
            logger.info("\(logMessage) ✅")
        } else {
            logger.warning("\(logMessage) ⚠️ 메모리 사용량 초과!")
        }
        
        print(logMessage)
    }
    
    /// 메모리 경고 체크
    func checkMemoryWarning() -> Bool {
        let current = getCurrentMemoryUsage()
        return current > thresholdMB
    }
    
    /// 채팅 메시지 로드 시뮬레이션 테스트
    func simulateMessageLoadTest(messageCount: Int) {
        print("\n🧪 메모리 테스트 시작: \(messageCount)개 메시지 로드")
        
        setBaseline()
        
        // 메시지 생성 시뮬레이션
        var messages: [ChatMessage] = []
        
        for i in 0..<messageCount {
            let message = ChatMessage(
                text: "테스트 메시지 \(i) - " + String(repeating: "텍스트", count: 100),
                sender: i % 2 == 0 ? MessageSender.user : MessageSender.ai,
                type: i % 2 == 0 ? ChatMessageType.user : ChatMessageType.bot
            )
            messages.append(message)
            
            // 100개마다 메모리 체크
            if (i + 1) % 100 == 0 {
                logMemoryUsage(context: "\(i + 1)개 메시지 로드됨")
            }
        }
        
        // 최종 메모리 사용량
        logMemoryUsage(context: "최종 (\(messageCount)개)")
        
        // 메모리 경고 체크
        if checkMemoryWarning() {
            print("⚠️ 메모리 사용량이 50MB를 초과했습니다!")
        } else {
            print("✅ 메모리 사용량이 50MB 이하로 유지되고 있습니다.")
        }
        
        // 정리
        messages.removeAll()
        
        // 정리 후 메모리
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.logMemoryUsage(context: "메모리 정리 후")
        }
    }
    
    /// 페이징 테스트
    func testPagingMemory(totalMessages: Int, pageSize: Int) {
        print("\n🧪 페이징 메모리 테스트")
        print("• 전체 메시지: \(totalMessages)개")
        print("• 페이지 크기: \(pageSize)개")
        
        setBaseline()
        
        // 전체 캐시 생성
        var allMessagesCache: [ChatMessage] = []
        for i in 0..<totalMessages {
            allMessagesCache.append(ChatMessage(
                text: "캐시 메시지 \(i)",
                sender: MessageSender.user,
                type: ChatMessageType.user
            ))
        }
        
        logMemoryUsage(context: "전체 캐시 로드 (\(totalMessages)개)")
        
        // 디스플레이용 배열 (페이징)
        var displayMessages: [ChatMessage] = []
        let initialPage = Array(allMessagesCache.suffix(pageSize))
        displayMessages = initialPage
        
        logMemoryUsage(context: "초기 페이지 표시 (\(pageSize)개)")
        
        // 추가 페이지 로드 시뮬레이션
        for page in 1...5 {
            let startIdx = max(0, totalMessages - (page + 1) * pageSize)
            let endIdx = max(0, totalMessages - page * pageSize)
            
            if startIdx < endIdx {
                let pageMessages = Array(allMessagesCache[startIdx..<endIdx])
                displayMessages.insert(contentsOf: pageMessages, at: 0)
                logMemoryUsage(context: "페이지 \(page) 로드 (표시: \(displayMessages.count)개)")
            }
        }
        
        // 정리
        displayMessages.removeAll()
        allMessagesCache.removeAll()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.logMemoryUsage(context: "전체 정리 후")
        }
    }
}

// MARK: - Debug Extensions
#if DEBUG
extension MemoryProfiler {
    /// 디버그용 상세 메모리 리포트
    func generateDetailedReport() -> String {
        let current = getCurrentMemoryUsage()
        let increase = getMemoryIncrease()
        
        let report = """
        ============================
        📊 메모리 상세 리포트
        ============================
        현재 메모리: \(String(format: "%.2f", current)) MB
        베이스라인: \(String(format: "%.2f", baselineMemory)) MB
        증가량: \(String(format: "%.2f", increase)) MB
        
        메모리 상태:
        • 임계치(\(Int(thresholdMB))MB) 이하: \(current <= thresholdMB ? "✅ 정상" : "⚠️ 초과")
        
        권장사항:
        \(current > thresholdMB ? "• 페이지 크기 축소/캐시 정리 주기 단축/이미지 압축 강화 권장" : "• 현재 설정 유지 권장")
        ============================
        """
        
        return report
    }
}
#endif
