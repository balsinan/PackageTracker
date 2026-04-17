import Foundation

struct Package: Identifiable, Codable, Hashable {
    let id: UUID
    var trackingNumber: String
    var title: String?
    var carrierSlug: String?
    var carrierName: String?
    var statusRaw: String
    var lastUpdate: String?
    var createdAt: Date
    var trackingId: String?

    var status: PackageStatus {
        get { PackageStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        trackingNumber: String,
        title: String? = nil,
        carrierSlug: String? = nil,
        carrierName: String? = nil,
        status: PackageStatus = .pending,
        lastUpdate: String? = nil,
        createdAt: Date = Date(),
        trackingId: String? = nil
    ) {
        self.id = id
        self.trackingNumber = trackingNumber
        self.title = title
        self.carrierSlug = carrierSlug
        self.carrierName = carrierName
        self.statusRaw = status.rawValue
        self.lastUpdate = lastUpdate
        self.createdAt = createdAt
        self.trackingId = trackingId
    }
}

extension Package {
    init(from payload: TrackedPackagePayload, existingID: UUID? = nil, createdAt: Date? = nil) {
        self.init(
            id: existingID ?? UUID(),
            trackingNumber: payload.trackingNumber,
            title: payload.title.isEmpty ? nil : payload.title,
            carrierSlug: payload.carrierSlug,
            carrierName: payload.carrierName,
            status: payload.status,
            lastUpdate: payload.lastUpdate,
            createdAt: createdAt ?? Date(),
            trackingId: payload.trackingId
        )
    }
}
