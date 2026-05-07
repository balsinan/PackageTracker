import UIKit

enum AppTheme {
    static let background = UIColor(red: 247 / 255, green: 248 / 255, blue: 250 / 255, alpha: 1)
    static let secondaryBackground = UIColor.white
    static let tertiaryBackground = UIColor(red: 236 / 255, green: 239 / 255, blue: 243 / 255, alpha: 1)
    static let accent = UIColor(red: 1, green: 98 / 255, blue: 53 / 255, alpha: 1)
    static let textPrimary = UIColor(red: 22 / 255, green: 24 / 255, blue: 29 / 255, alpha: 1)
    static let textSecondary = UIColor(red: 104 / 255, green: 112 / 255, blue: 124 / 255, alpha: 1)
    static let separator = UIColor(red: 218 / 255, green: 224 / 255, blue: 232 / 255, alpha: 1)
    static let pending = UIColor(red: 194 / 255, green: 128 / 255, blue: 20 / 255, alpha: 1)
    static let inTransit = UIColor(red: 37 / 255, green: 99 / 255, blue: 235 / 255, alpha: 1)
    static let delivered = UIColor(red: 34 / 255, green: 139 / 255, blue: 84 / 255, alpha: 1)
    static let exception = UIColor(red: 220 / 255, green: 38 / 255, blue: 38 / 255, alpha: 1)
}

enum Layout {
    static let screenPadding: CGFloat = 20
    /// Extra breathing room below the nav bar on package detail.
    static let detailExtraTopInset: CGFloat = 45
    static let cardCornerRadius: CGFloat = 22
    static let controlCornerRadius: CGFloat = 16
    static let buttonHeight: CGFloat = 56
}

enum DefaultsKey {
    static let notificationsEnabled = "notificationsEnabled"
    static let fcmToken = "fcmToken"
    static let installationID = "installationID"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    /// Free users may complete one package registration after closing the paywall; then only paywall is shown.
    static let hasConsumedComplimentaryPackageAdd = "hasConsumedComplimentaryPackageAdd"
}

enum AppLinks {
    static let terms = URL(string: "https://blackcellaiapps.com/terms")!
    static let privacy = URL(string: "https://blackcellaiapps.com/privacy")!
    /// In-app support compose / mailto recipient.
    static let supportEmail = "info@blackcellaiapps.com"

    /// Numeric App Store ID is read from `APP_STORE_ID` in Info.plist (defaults to the live app if missing).
    static var appStoreListingURL: URL? {
        let id = (Bundle.main.object(forInfoDictionaryKey: "APP_STORE_ID") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "6762486028"
        guard !id.isEmpty, let url = URL(string: "https://apps.apple.com/app/id\(id)") else { return nil }
        return url
    }

    static var appStoreWriteReviewURL: URL? {
        guard let base = appStoreListingURL else { return nil }
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "action", value: "write-review")]
        return components?.url
    }
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
