import Foundation

struct TrackingEvent: Hashable, Codable {
    let id: String
    let title: String
    let detail: String
    let location: String
    let timestampText: String
}
