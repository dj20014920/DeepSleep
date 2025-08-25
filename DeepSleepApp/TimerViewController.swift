import UIKit
import UserNotifications
import AVFoundation

class TimerViewController: UIViewController {
    
    // MARK: –– UI 컴포넌트
    
    /// 모드 선택: "타이머" / "예약"
    private let modeControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["타이머", "예약"])
        sc.selectedSegmentIndex = 0
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()
    
    /// 분 뒤 모드일 때는 countdown, 시각 모드일 땐 time
    private let picker: UIDatePicker = {
        let dp = UIDatePicker()
        dp.datePickerMode = .countDownTimer
        dp.minuteInterval = 1
        dp.translatesAutoresizingMaskIntoConstraints = false
        return dp
    }()
    
    /// 남은 시간 표시
    private let timeLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .monospacedDigitSystemFont(ofSize: 32, weight: .medium)
        lbl.textAlignment = .center
        lbl.text = "00:00"

        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    /// 상태 표시 라벨
    private let statusLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 16, weight: .medium)
        lbl.textAlignment = .center
        lbl.text = ""
        lbl.textColor = UIDesignSystem.Colors.primaryText
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    /// 타이머 시작/정지 버튼
    private let startButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("시작", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        btn.backgroundColor = .systemBlue
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 8
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    /// 타이머 취소 버튼
    private let cancelButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("취소", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        btn.setTitleColor(.systemRed, for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.isHidden = true
        return btn
    }()
    
    // MARK: –– 내부 상태
    
    private var timer: Timer?
    private var endDate: Date?
    private var isTimerRunning = false
    private var fadeOutTimer: Timer?
    
    // 포맷터 (분:초 / 시:분:초)
    private let minuteFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.minute, .second]
        f.unitsStyle = .positional
        f.zeroFormattingBehavior = .pad
        return f
    }()
    
    private let fullFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute, .second]
        f.unitsStyle = .positional
        f.zeroFormattingBehavior = .pad
        return f
    }()
    
    // MARK: –– Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        title = "타이머"
        
        setupUI()
        setupTargets()
        setupAudioSession()
        CentralNotificationScheduler.shared.requestAuthorizationIfNeeded(presenting: self)
        
        // 앱 생명주기 관찰
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        restoreTimerState()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
        fadeOutTimer?.invalidate()
    }
    
    // MARK: –– Setup Methods
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("오디오 세션 설정 실패: \(error)")
        }
    }
    
    
    private func setupTargets() {
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
    }
    
    private func setupUI() {
        [modeControl, picker, timeLabel, statusLabel, startButton, cancelButton].forEach {
            view.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            modeControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            modeControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeControl.widthAnchor.constraint(equalToConstant: 200),
            
            picker.topAnchor.constraint(equalTo: modeControl.bottomAnchor, constant: 30),
            picker.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            timeLabel.topAnchor.constraint(equalTo: picker.bottomAnchor, constant: 50),
            timeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 10),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            startButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 30),
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startButton.widthAnchor.constraint(equalToConstant: 120),
            startButton.heightAnchor.constraint(equalToConstant: 44),
            
            cancelButton.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: 15),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }
    
    // MARK: –– 모드 전환
    
    @objc private func modeChanged() {
        if modeControl.selectedSegmentIndex == 0 {
            picker.datePickerMode = .countDownTimer
            picker.countDownDuration = 600 // 10분 기본값
        } else {
            picker.datePickerMode = .time
            // 1시간 후로 기본 설정
            let oneHourLater = Date().addingTimeInterval(3600)
            picker.date = oneHourLater
        }
        
        if isTimerRunning {
            cancelTimer()
        }
    }
    
    // MARK: –– 타이머 컨트롤
    
    @objc private func startButtonTapped() {
        if isTimerRunning {
            // 실행 중인 타이머 정지
            pauseTimer()
        } else {
            // 새 타이머 시작
            startTimer()
        }
    }
    
    @objc private func cancelButtonTapped() {
        cancelTimer()
    }
    
    private func startTimer() {
        // endDate 계산
        if modeControl.selectedSegmentIndex == 0 {
            // "타이머" 모드
            let interval = picker.countDownDuration
            guard interval > 0 else {
                showAlert(title: "시간 설정", message: "타이머 시간을 설정해주세요.")
                return
            }
            endDate = Date().addingTimeInterval(interval)
        } else {
            // "예약" 모드
            let targetTime = picker.date
            let now = Date()
            
            // 같은 날인지 확인
            let calendar = Calendar.current
            var targetDate = targetTime
            
            if targetTime <= now {
                // 다음 날로 설정
                targetDate = calendar.date(byAdding: .day, value: 1, to: targetTime)!
            }
            
            endDate = targetDate
        }
        
        guard let end = endDate else { return }
        
        // UI 업데이트
        isTimerRunning = true
        updateUI()
        
        // 로컬 알림 스케줄링
        scheduleNotification(at: end)
        
        // 페이드아웃 스케줄링
        scheduleFadeOut(at: end)
        
        // UI 타이머 시작
        startLocalTimer()
        
        // 상태 저장
        saveTimerState()
        
        print("타이머 시작: \(end)")
    }
    
    private func pauseTimer() {
        timer?.invalidate()
        fadeOutTimer?.invalidate()
        cancelNotification()
        
        isTimerRunning = false
        updateUI()
        clearTimerState()
        
        statusLabel.text = "일시정지됨"
    }
    
    private func cancelTimer() {
        timer?.invalidate()
        fadeOutTimer?.invalidate()
        cancelNotification()
        
        isTimerRunning = false
        endDate = nil
        timeLabel.text = "00:00"
        statusLabel.text = ""
        
        updateUI()
        clearTimerState()
    }
    
    private func completeTimer() {
        timer?.invalidate()
        fadeOutTimer?.invalidate()
        
        isTimerRunning = false
        endDate = nil
        timeLabel.text = "00:00"
        statusLabel.text = "완료! 🎵 사운드가 페이드아웃됩니다"
        
        updateUI()
        clearTimerState()
        
        // 완료 햅틱 피드백
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // 5초 후 상태 메시지 지우기
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if !self.isTimerRunning {
                self.statusLabel.text = ""
            }
        }
    }
    
    // MARK: –– UI 업데이트
    
    private func updateUI() {
        if isTimerRunning {
            startButton.setTitle("일시정지", for: .normal)
            startButton.backgroundColor = .systemOrange
            cancelButton.isHidden = false
            picker.isUserInteractionEnabled = false
            modeControl.isUserInteractionEnabled = false
        } else {
            startButton.setTitle("시작", for: .normal)
            startButton.backgroundColor = .systemBlue
            cancelButton.isHidden = true
            picker.isUserInteractionEnabled = true
            modeControl.isUserInteractionEnabled = true
        }
    }
    
    // MARK: –– 로컬 타이머
    
    private func startLocalTimer() {
        timer?.invalidate()
        updateTimeLabel()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimeLabel()
        }
        
        // 백그라운드에서도 실행되도록 RunLoop 설정
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func updateTimeLabel() {
        guard let end = endDate else { return }
        
        let remaining = max(0, end.timeIntervalSinceNow)
        let str = remaining >= 3600
            ? fullFormatter.string(from: remaining)!
            : minuteFormatter.string(from: remaining)!
        
        timeLabel.text = str
        
        // 남은 시간에 따른 상태 업데이트
        if remaining <= 0 {
            completeTimer()
        } else if remaining <= 60 {
            statusLabel.text = "🔔 1분 남았습니다"
        } else if remaining <= 300 {
            statusLabel.text = "⏰ 5분 남았습니다"
        } else {
            let minutes = Int(remaining / 60)
            statusLabel.text = "⏱ \(minutes)분 남음"
        }
    }
    
    // MARK: –– 페이드아웃 처리
    
    private func scheduleFadeOut(at endDate: Date) {
        let fadeDuration: TimeInterval = 30.0 // 30초 페이드아웃
        let fadeStartTime = endDate.addingTimeInterval(-fadeDuration)
        let delay = max(0, fadeStartTime.timeIntervalSinceNow)
        
        fadeOutTimer?.invalidate()
        fadeOutTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.startFadeOut(duration: fadeDuration)
        }
        
        print("페이드아웃 예약: \(fadeStartTime) (현재로부터 \(delay)초 후)")
    }
    
    private func startFadeOut(duration: TimeInterval) {
        print("페이드아웃 시작: \(duration)초 동안")
        
        // ✅ 실제 페이드아웃 호출 (SoundManager의 fadeOutAll 메서드 사용)
        SoundManager.shared.fadeOutAll(duration: duration)
        
        statusLabel.text = "🎵 사운드가 서서히 작아집니다..."
        
        // 페이드아웃 완료 후 상태 업데이트
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.statusLabel.text = "🔇 페이드아웃 완료"
        }
    }
    
    // MARK: –– 알림 처리
    
    private func scheduleNotification(at date: Date) {
        CentralNotificationScheduler.shared.scheduleTimerNotification(endDate: date)
        
        // iPhone 기본 알람 추가 제안 (예약 모드일 때만)
        if modeControl.selectedSegmentIndex == 1 {
            showAlarmIntegrationOption(for: date)
        }
    }
    
    /// iPhone 기본 알람 연동 제안
    private func showAlarmIntegrationOption(for endDate: Date) {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ko_KR")
        
        let timeString = formatter.string(from: endDate)
        
        let alert = UIAlertController(
            title: "알람 연동",
            message: "\(timeString)에 iPhone 기본 알람도 설정하시겠습니까?\n\n더 확실한 기상을 위해 알람을 추가로 설정할 수 있습니다.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "알람 추가", style: .default) { _ in
            self.addToAppleAlarm(endDate)
        })
        
        alert.addAction(UIAlertAction(title: "건너뛰기", style: .cancel))
        
        present(alert, animated: true)
    }
    
    /// iPhone 기본 알람 앱에 알람 추가
    private func addToAppleAlarm(_ date: Date) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        
        guard let hour = components.hour, let minute = components.minute else {
            showAlarmError()
            return
        }
        
        // 알람 앱 URL 스킴 사용
        let alarmURL = "clock-alarm:create?hour=\(hour)&minute=\(minute)"
        
        if let url = URL(string: alarmURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url) { success in
                DispatchQueue.main.async {
                    if success {
                        self.showAlarmSuccess()
                    } else {
                        self.showAlarmFallback(hour: hour, minute: minute)
                    }
                }
            }
        } else {
            showAlarmFallback(hour: hour, minute: minute)
        }
    }
    
    /// 알람 설정 성공 메시지
    private func showAlarmSuccess() {
        let alert = UIAlertController(
            title: "알람 설정 완료",
            message: "iPhone 기본 알람이 추가되었습니다. ⏰",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    /// 알람 설정 대안 방법 제시
    private func showAlarmFallback(hour: Int, minute: Int) {
        let timeString = String(format: "%02d:%02d", hour, minute)
        
        let alert = UIAlertController(
            title: "수동 알람 설정",
            message: "시계 앱을 열어서 \(timeString)에 알람을 설정해주세요.\n\n1. 시계 앱 열기\n2. 알람 탭 선택\n3. + 버튼으로 새 알람 추가\n4. \(timeString) 시간 설정",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "시계 앱 열기", style: .default) { _ in
            if let url = URL(string: "clock-alarm:"), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "나중에", style: .cancel))
        
        present(alert, animated: true)
    }
    
    /// 알람 연동 오류 메시지
    private func showAlarmError() {
        let alert = UIAlertController(
            title: "알람 설정 실패",
            message: "시간 설정에 오류가 발생했습니다. 수동으로 알람을 설정해주세요.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    private func cancelNotification() {
        CentralNotificationScheduler.shared.cancelTimerNotification()
    }
    
    // MARK: –– 상태 저장/복원
    
    private func saveTimerState() {
        guard let endDate = endDate else { return }
        UserDefaults.standard.set(endDate.timeIntervalSince1970, forKey: "DeepSleep.timerEndDate")
        UserDefaults.standard.set(isTimerRunning, forKey: "DeepSleep.timerRunning")
    }
    
    private func clearTimerState() {
        UserDefaults.standard.removeObject(forKey: "DeepSleep.timerEndDate")
        UserDefaults.standard.removeObject(forKey: "DeepSleep.timerRunning")
    }
    
    private func restoreTimerState() {
        let timestamp = UserDefaults.standard.double(forKey: "DeepSleep.timerEndDate")
        let wasRunning = UserDefaults.standard.bool(forKey: "DeepSleep.timerRunning")
        
        guard timestamp > 0, wasRunning else { return }
        
        let savedEndDate = Date(timeIntervalSince1970: timestamp)
        
        if savedEndDate > Date() {
            // 아직 시간이 남음 - 타이머 재시작
            endDate = savedEndDate
            isTimerRunning = true
            updateUI()
            startLocalTimer()
            scheduleFadeOut(at: savedEndDate)
            print("타이머 복원: \(savedEndDate)")
        } else {
            // 시간이 지남 - 완료 처리
            clearTimerState()
            print("타이머 만료됨 (앱이 백그라운드에 있는 동안)")
        }
    }
    
    // MARK: –– 앱 생명주기
    
    @objc private func appWillEnterBackground() {
        // 백그라운드 진입 시 상태 저장
        if isTimerRunning {
            saveTimerState()
        }
    }
    
    @objc private func appDidBecomeActive() {
        // 포그라운드 복귀 시 상태 복원
        restoreTimerState()
    }
    
    // MARK: –– 유틸리티
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}
