import Foundation

@MainActor
final class PackageStore {
    static let shared = PackageStore()

    private(set) var packages: [Package] = []

    private let fileURL: URL
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private init() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.fileURL = directory.appendingPathComponent("packages.json")
        load()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            packages = []
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            packages = try decoder.decode([Package].self, from: data)
        } catch {
            print("PackageStore load failed: \(error.localizedDescription)")
            packages = []
        }
    }

    @discardableResult
    func upsert(from payload: TrackedPackagePayload) -> Package {
        if let index = packages.firstIndex(where: { $0.trackingNumber == payload.trackingNumber }) {
            var updated = packages[index]
            updated.title = payload.title.isEmpty ? updated.title : payload.title
            updated.carrierSlug = payload.carrierSlug
            updated.carrierName = payload.carrierName
            updated.status = payload.status
            updated.lastUpdate = payload.lastUpdate
            updated.trackingId = payload.trackingId
            packages[index] = updated
            persist()
            return updated
        }

        let new = Package(from: payload)
        packages.insert(new, at: 0)
        persist()
        return new
    }

    func replace(with payloads: [TrackedPackagePayload]) {
        var updated: [Package] = []
        for payload in payloads {
            if let existing = packages.first(where: { $0.trackingNumber == payload.trackingNumber }) {
                updated.append(Package(from: payload, existingID: existing.id, createdAt: existing.createdAt))
            } else {
                updated.append(Package(from: payload))
            }
        }
        packages = updated.sorted(by: { $0.createdAt > $1.createdAt })
        persist()
    }

    func update(id: UUID, status: PackageStatus, lastUpdate: String) {
        guard let index = packages.firstIndex(where: { $0.id == id }) else { return }
        packages[index].status = status
        packages[index].lastUpdate = lastUpdate
        persist()
    }

    func updateCarrier(id: UUID, carrierCode: Int, carrierName: String) {
        guard let index = packages.firstIndex(where: { $0.id == id }) else { return }
        packages[index].carrierSlug = "\(carrierCode)"
        packages[index].carrierName = carrierName
        persist()
    }

    func delete(id: UUID) {
        packages.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        do {
            let data = try encoder.encode(packages)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("PackageStore save failed: \(error.localizedDescription)")
        }
        NotificationCenter.default.post(name: .packageStoreDidChange, object: nil)
    }
}
