import Foundation

/// Formats raw API checkpoint times (usually ISO8601 UTC) for on-screen display.
enum TrackingTimestampFormatter {

    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    /// Example: `2026/04/18 05:00` in the user's local time zone.
    static func displayString(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Recent"
        }
        if trimmed.caseInsensitiveCompare("Recent") == .orderedSame {
            return "Recent"
        }
        guard let date = parseInstant(trimmed) else {
            return trimmed
        }
        let out = DateFormatter()
        out.locale = .autoupdatingCurrent
        out.timeZone = .current
        out.dateFormat = "yyyy/MM/dd HH:mm"
        return out.string(from: date)
    }

    private static func parseInstant(_ s: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) {
            return d
        }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) {
            return d
        }

        let f = DateFormatter()
        f.locale = posixLocale
        let patternsWithZone: [(String, TimeZone?)] = [
            ("yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX", nil),
            ("yyyy-MM-dd'T'HH:mm:ssXXXXX", nil),
            ("yyyy-MM-dd'T'HH:mm:ss'Z'", TimeZone(secondsFromGMT: 0)),
            ("yyyy-MM-dd'T'HH:mm:ssZ", TimeZone(secondsFromGMT: 0)),
            ("yyyy-MM-dd HH:mm:ss", TimeZone(secondsFromGMT: 0))
        ]
        for (pattern, tz) in patternsWithZone {
            f.timeZone = tz ?? TimeZone(secondsFromGMT: 0)
            f.dateFormat = pattern
            if let d = f.date(from: s) {
                return d
            }
        }
        return nil
    }
}

extension TrackingEvent {
    var displayTimestamp: String {
        TrackingTimestampFormatter.displayString(from: timestampText)
    }
}
