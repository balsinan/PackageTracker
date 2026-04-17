import UIKit

enum AppTheme {
    static let background = UIColor(red: 18 / 255, green: 19 / 255, blue: 23 / 255, alpha: 1)
    static let secondaryBackground = UIColor(red: 33 / 255, green: 36 / 255, blue: 41 / 255, alpha: 1)
    static let tertiaryBackground = UIColor(red: 44 / 255, green: 47 / 255, blue: 52 / 255, alpha: 1)
    static let accent = UIColor(red: 1, green: 98 / 255, blue: 53 / 255, alpha: 1)
    static let textPrimary = UIColor.white
    static let textSecondary = UIColor(white: 0.72, alpha: 1)
    static let separator = UIColor(white: 1, alpha: 0.08)
    static let pending = UIColor(red: 242 / 255, green: 180 / 255, blue: 64 / 255, alpha: 1)
    static let inTransit = UIColor(red: 88 / 255, green: 166 / 255, blue: 255 / 255, alpha: 1)
    static let delivered = UIColor(red: 76 / 255, green: 175 / 255, blue: 80 / 255, alpha: 1)
    static let exception = UIColor(red: 235 / 255, green: 87 / 255, blue: 87 / 255, alpha: 1)
}

enum Layout {
    static let screenPadding: CGFloat = 20
    static let cardCornerRadius: CGFloat = 22
    static let controlCornerRadius: CGFloat = 16
    static let buttonHeight: CGFloat = 56
}

enum DefaultsKey {
    static let archiveDelivered = "archiveDelivered"
    static let notificationsEnabled = "notificationsEnabled"
    static let fcmToken = "fcmToken"
    static let installationID = "installationID"
}

enum AppConfig {
    static var functionsBaseURL: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "FUNCTIONS_BASE_URL") as? String,
              !value.isEmpty else {
            return nil
        }

        return URL(string: value)
    }
}

extension Notification.Name {
    static let packageStoreDidChange = Notification.Name("packageStoreDidChange")
}
