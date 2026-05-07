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
    let isArchived: Bool

    init(
        trackingNumber: String,
        title: String,
        carrierSlug: String,
        carrierName: String,
        status: PackageStatus,
        lastUpdate: String,
        trackingId: String?,
        checkpoints: [TrackingEvent],
        isArchived: Bool = false
    ) {
        self.trackingNumber = trackingNumber
        self.title = title
        self.carrierSlug = carrierSlug
        self.carrierName = carrierName
        self.status = status
        self.lastUpdate = lastUpdate
        self.trackingId = trackingId
        self.checkpoints = checkpoints
        self.isArchived = isArchived
    }
}
