import Foundation

struct TrackedPackagePayload {
    let trackingNumber: String
    let title: String
    let carrierSlug: String
    let carrierName: String
    let status: PackageStatus
    let lastUpdate: String
    let trackingId: String?
    let checkpoints: [TrackingEvent]
}
