import UIKit

enum HapticFeedback {
    /// Tab changes, filter chips, list picks.
    case selection
    /// Physical tap intensity.
    case impact(UIImpactFeedbackGenerator.FeedbackStyle)
    case notification(UINotificationFeedbackGenerator.FeedbackType)

    static let light = HapticFeedback.impact(.light)
    static let medium = HapticFeedback.impact(.medium)
    static let heavy = HapticFeedback.impact(.heavy)
    static let soft = HapticFeedback.impact(.soft)
    static let rigid = HapticFeedback.impact(.rigid)

    func play() {
        switch self {
        case .selection:
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        case .impact(let style):
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred()
        case .notification(let type):
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(type)
        }
    }
}
