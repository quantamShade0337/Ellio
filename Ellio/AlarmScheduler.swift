import Foundation
import UserNotifications

enum AlarmScheduler {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func sync(_ alarms: [AlarmItem]) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: alarms.map(\.id))

        alarms.filter(\.isEnabled).forEach { alarm in
            guard let date = parsedTime(alarm.time) else { return }

            var components = DateComponents()
            components.hour = Calendar.current.component(.hour, from: date)
            components.minute = Calendar.current.component(.minute, from: date)

            let content = UNMutableNotificationContent()
            content.title = alarm.label
            content.body = "Time to wake up with Ellio."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: alarm.id,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )

            center.add(request)
        }
    }

    private static func parsedTime(_ time: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: time)
    }
}
