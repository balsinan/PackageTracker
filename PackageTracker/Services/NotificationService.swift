import UIKit
import UserNotifications
import FirebaseMessaging

final class NotificationService: NSObject {
    static let shared = NotificationService()

    private override init() {}

    func configure(application: UIApplication) {
        requestAuthorization(application: application)
    }

    private func requestAuthorization(application: UIApplication) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            UserDefaults.standard.set(granted, forKey: DefaultsKey.notificationsEnabled)

            guard granted else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }

    func updateFCMToken(_ token: String?) {
        UserDefaults.standard.set(token, forKey: DefaultsKey.fcmToken)
    }

    func currentToken() -> String? {
        UserDefaults.standard.string(forKey: DefaultsKey.fcmToken)
    }

    func installationID() -> String {
        if let existing = UserDefaults.standard.string(forKey: DefaultsKey.installationID),
           !existing.isEmpty {
            return existing
        }

        let newValue = UUID().uuidString
        UserDefaults.standard.set(newValue, forKey: DefaultsKey.installationID)
        return newValue
    }
}
