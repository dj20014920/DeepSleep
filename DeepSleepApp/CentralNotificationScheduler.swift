import Foundation
import UserNotifications
import UIKit

/// Centralized notification scheduler responsible for:
/// - Permission handling (request + settings redirection)
/// - De-duplicated scheduling for Timer and Todo notifications
/// - Safe cancellation without affecting unrelated notifications
final class CentralNotificationScheduler {
    static let shared = CentralNotificationScheduler()
    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Authorization
    func requestAuthorizationIfNeeded(presenting: UIViewController? = nil) {
        center.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            switch settings.authorizationStatus {
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if !granted, let presenter = presenting {
                        DispatchQueue.main.async {
                            self.presentPermissionAlert(from: presenter)
                        }
                    }
                }
            case .denied:
                if let presenter = presenting {
                    DispatchQueue.main.async {
                        self.presentPermissionAlert(from: presenter)
                    }
                }
            case .authorized, .provisional, .ephemeral:
                break
            @unknown default:
                break
            }
        }
    }

    private func presentPermissionAlert(from presenter: UIViewController) {
        let alert = UIAlertController(
            title: "알림 권한 필요",
            message: "타이머 종료나 할 일 미리 알림을 받으려면 알림 권한이 필요합니다.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "설정으로 이동", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        alert.addAction(UIAlertAction(title: "나중에", style: .cancel))
        presenter.present(alert, animated: true)
    }

    // MARK: - Timer Notification
    func scheduleTimerNotification(endDate: Date) {
        // Respect user preferences
        if !(SettingsManager.shared.notificationsMasterEnabled && SettingsManager.shared.notificationsTimerEnabled) {
            print("🔕 타이머 알림 비활성화 상태 - 스케줄링 생략")
            return
        }
        let identifier = NotificationIdentifier.timer
        // Upsert: remove existing with same ID before scheduling
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "EmoZleep 타이머 완료"
        content.body = "설정하신 시간이 되었습니다. 사운드가 꺼집니다."
        content.sound = .default
        content.badge = 1

        let interval = max(1, endDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("알림 스케줄링 실패: \(error)")
            } else {
                print("알림 스케줄링 성공: \(endDate)")
            }
        }
    }

    func cancelTimerNotification() {
        center.removePendingNotificationRequests(withIdentifiers: [NotificationIdentifier.timer])
    }

    // MARK: - Todo Notification
    func scheduleTodoNotification(for todo: TodoItem) {
        // Respect user preferences
        if !(SettingsManager.shared.notificationsMasterEnabled && SettingsManager.shared.notificationsTodoEnabled) {
            print("🔕 할 일 알림 비활성화 상태 - 스케줄링 생략 ('\(todo.title)')")
            return
        }
        // 1시간 전 알림 토글 확인
        if !SettingsManager.shared.notificationsTodoOneHourBeforeEnabled {
            print("🔕 1시간 전 알림 비활성화 - 스케줄링 생략 ('\(todo.title)')")
            return
        }
        // If completed, ensure it's canceled
        if todo.isCompleted {
            cancelTodoNotification(id: todo.id)
            return
        }

        let calendar = Calendar.current
        guard let oneHourBefore = calendar.date(byAdding: .hour, value: -1, to: todo.dueDate) else { return }
        if oneHourBefore <= Date() {
            print("🔔 알림 스케줄링 건너뜀: 알림 시간(\(oneHourBefore))이 이미 지남 (할 일: \(todo.title))")
            return
        }

        // Upsert
        let identifier = todo.id.uuidString
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "할 일 미리 알림 ⏰"
        if let endDate = todo.endDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            let endDateString = dateFormatter.string(from: endDate)
            content.body = "'\(todo.title)' 시작 1시간 전입니다! (~\(endDateString))"
        } else {
            content.body = "'\(todo.title)' 마감 1시간 전입니다!"
        }
        content.sound = .default
        content.userInfo = ["todoID": identifier]

        let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: oneHourBefore)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("🔔 알림 스케줄링 오류 (\(todo.title)): \(error.localizedDescription)")
            } else {
                print("🔔 알림 스케줄링 성공: \(todo.title) (ID: \(identifier)) at \(oneHourBefore)")
            }
        }
    }

    func cancelTodoNotification(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        print("🔔 예정된 알림 제거: \(id.uuidString)")
    }

    func rescheduleTodos(_ todos: [TodoItem]) {
        for todo in todos {
            scheduleTodoNotification(for: todo)
        }
        print("🔔 모든 알림 재스케줄링 완료")
    }
}

// MARK: - Identifiers
private enum NotificationIdentifier {
    static let timer = "DeepSleep.timer"
}

