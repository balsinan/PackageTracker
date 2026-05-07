import Foundation

struct Package: Identifiable, Hashable {
    let id: UUID
    var trackingNumber: String
    var title: String?
    var carrierSlug: String?
    var carrierName: String?
    var statusRaw: String
    var lastUpdate: String?
    var createdAt: Date
    var trackingId: String?
    /// User/archive bucket; independent of carrier `status`.
    var isArchived: Bool
    /// Last known timeline from the backend (mirrors Firestore `checkpoints` when synced).
    var checkpoints: [TrackingEvent]

    var status: PackageStatus {
        get { PackageStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    /// Shown in list and detail (custom name, or tracking number if unnamed).
    var displayName: String {
        title ?? trackingNumber
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
        trackingId: String? = nil,
        isArchived: Bool = false,
        checkpoints: [TrackingEvent] = []
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
        self.isArchived = isArchived
        self.checkpoints = checkpoints
    }
}

extension Package: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case trackingNumber
        case title
        case carrierSlug
        case carrierName
        case statusRaw
        case lastUpdate
        case createdAt
        case trackingId
        case isArchived
        case checkpoints
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        trackingNumber = try c.decode(String.self, forKey: .trackingNumber)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        carrierSlug = try c.decodeIfPresent(String.self, forKey: .carrierSlug)
        carrierName = try c.decodeIfPresent(String.self, forKey: .carrierName)
        statusRaw = try c.decode(String.self, forKey: .statusRaw)
        lastUpdate = try c.decodeIfPresent(String.self, forKey: .lastUpdate)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        trackingId = try c.decodeIfPresent(String.self, forKey: .trackingId)
        isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        checkpoints = try c.decodeIfPresent([TrackingEvent].self, forKey: .checkpoints) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(trackingNumber, forKey: .trackingNumber)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(carrierSlug, forKey: .carrierSlug)
        try c.encodeIfPresent(carrierName, forKey: .carrierName)
        try c.encode(statusRaw, forKey: .statusRaw)
        try c.encodeIfPresent(lastUpdate, forKey: .lastUpdate)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(trackingId, forKey: .trackingId)
        try c.encode(isArchived, forKey: .isArchived)
        try c.encode(checkpoints, forKey: .checkpoints)
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
            trackingId: payload.trackingId,
            isArchived: payload.isArchived,
            checkpoints: payload.checkpoints
        )
    }
}
