import UIKit
import UserNotifications
import FirebaseMessaging

final class NotificationService: NSObject {
    static let shared = NotificationService()

    private override init() {}

    /// Short explainer alert with one action; tapping it presents the system notification permission prompt.
    func presentFirstPackageNotificationEducation(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Notifications",
            message: "Get alerts when your package status changes.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self] _ in
            self?.requestSystemNotificationPermission(application: UIApplication.shared) { _ in
                Task {
                    try? await APIService.shared.upsertInstallation()
                }
            }
        })
        viewController.present(alert, animated: true)
    }

    /// Requests iOS notification permission and registers for remote notifications when granted.
    func requestSystemNotificationPermission(application: UIApplication, completion: ((Bool) -> Void)? = nil) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            UserDefaults.standard.set(granted, forKey: DefaultsKey.notificationsEnabled)

            guard granted else {
                DispatchQueue.main.async {
                    completion?(false)
                }
                return
            }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
                completion?(true)
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
