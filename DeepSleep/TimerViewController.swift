import UIKit
import UserNotifications

class TimerViewController: UIViewController {
    
    // MARK: –– UI 컴포넌트
    
    /// 모드 선택: “분 뒤” / “시각”
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
    
    /// 타이머 시작/재시작 버튼
    private let startButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("시작", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    // MARK: –– 내부 상태
    
    private var timer: Timer?
    private var endDate: Date?
    
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
        view.backgroundColor = .systemBackground
        title = "타이머"
        
        setupUI()
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        
        // 알림 권한 요청
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // UserDefaults에 남아있는 endDate가 있으면 복원
        if endDate == nil {
            let ts = UserDefaults.standard.double(forKey: "DeepSleep.timerEndDate")
            if ts > 0 {
                endDate = Date(timeIntervalSince1970: ts)
            }
        }
        restartTimerIfNeeded()
    }
    
    // MARK: –– UI 세팅
    
    private func setupUI() {
        [modeControl, picker, timeLabel, startButton].forEach { view.addSubview($0) }
        
        NSLayoutConstraint.activate([
            modeControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            modeControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            picker.topAnchor.constraint(equalTo: modeControl.bottomAnchor, constant: 20),
            picker.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            timeLabel.topAnchor.constraint(equalTo: picker.bottomAnchor, constant: 40),
            timeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            startButton.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 20),
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }
    
    // MARK: –– 모드 전환
    
    @objc private func modeChanged() {
        if modeControl.selectedSegmentIndex == 0 {
            picker.datePickerMode = .countDownTimer
        } else {
            picker.datePickerMode = .time
        }
    }
    
    // MARK: –– 시작 버튼
    
    @objc private func startTapped() {
        // 1) endDate 계산
        if modeControl.selectedSegmentIndex == 0 {
            // “분 뒤” 모드
            let interval = picker.countDownDuration
            endDate = Date().addingTimeInterval(interval)
        } else {
            // “시각” 모드
            let comps = Calendar.current.dateComponents([.hour, .minute], from: picker.date)
            endDate = Calendar.current.nextDate(
                after: Date(),
                matching: comps,
                matchingPolicy: .nextTime
            )
        }
        guard let end = endDate else { return }
        // 알림 스케줄링
        scheduleNotification(at: end)
        // ③ 로컬 타이머 시작
        startLocalTimer()
        let fadeDuration: TimeInterval = 30.0
          let delay = max(0, end.timeIntervalSinceNow)
          DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            SoundManager.shared.fadeOutAll(duration: fadeDuration)
          }
    }
    
    // MARK: –– 내부 타이머
    
    private func startLocalTimer() {
        timer?.invalidate()
        updateTimeLabel()
        timer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in self?.updateTimeLabel() }
    }
    
    private func restartTimerIfNeeded() {
        guard let end = endDate, end > Date() else { return }
        startLocalTimer()
    }
    
    private func updateTimeLabel() {
        guard let end = endDate else { return }
        let remaining = max(0, end.timeIntervalSinceNow)
        let str = remaining >= 3600
            ? fullFormatter.string(from: remaining)!
            : minuteFormatter.string(from: remaining)!
        timeLabel.text = str
        
        if remaining <= 0 {
               timer?.invalidate()
               timeLabel.text = "00:00"
               // UserDefaults 정리
               UserDefaults.standard.removeObject(forKey: "DeepSleep.timerEndDate")
            SoundManager.shared.fadeOutAll(duration: 30.0)

           }
    }
    
    // MARK: –– 로컬 알림
    
    private func scheduleNotification(at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "DeepSleep 타이머 종료"
        content.body  = "설정하신 타이머 시간이 도착했습니다."
        content.sound = .default
        
        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: interval, repeats: false
        )
        let req = UNNotificationRequest(
            identifier: "DeepSleep.timer",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(req)
    }
}
