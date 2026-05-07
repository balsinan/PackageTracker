import Foundation

enum APIServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)
    case carrierRequired

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The backend URL is invalid."
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .serverError(let message):
            return message
        case .carrierRequired:
            return "Carrier could not be detected automatically. Please select a carrier and try again."
        }
    }
}

final class APIService {
    static let shared = APIService()

    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {}

    private struct PackageBody: Decodable {
        let trackingNumber: String
        let title: String
        let carrierSlug: String
        let carrierName: String
        let status: String
        let lastUpdate: String
        let trackingId: String?
        let checkpoints: [CheckpointBody]?
        let isArchived: Bool?
    }

    private struct CheckpointBody: Decodable {
        let id: String?
        let status: String?
        let subStatus: String?
        let message: String?
        let location: String?
        let time: String?
    }

    private struct PackageListResponse: Decodable {
        let packages: [PackageBody]
    }

    private func shipmentStatus(from raw: String) -> PackageStatus {
        let decoded = PackageStatus(rawValue: raw) ?? .pending
        return decoded == .archived ? .pending : decoded
    }

    private func statusFromCheckpointTag(_ tag: String) -> PackageStatus? {
        let words = tag.replacingOccurrences(
            of: "([a-z])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        ).replacingOccurrences(of: "_", with: " ").lowercased()

        if words.contains("delivered") { return .delivered }
        if words.contains("out for delivery") { return .outForDelivery }
        if words.contains("failed") || words.contains("attempt fail") { return .failedAttempt }
        if words.contains("exception") || words.contains("returned") || words.contains("undeliverable") { return .exception }
        if words.contains("expired") { return .expired }
        if words.contains("transit") || words.contains("pickup") || words.contains("arrival") || words.contains("departure") { return .inTransit }
        return nil
    }

    private func makePayload(from package: PackageBody) -> TrackedPackagePayload {
        var resolvedStatus = shipmentStatus(from: package.status)

        if resolvedStatus == .pending, let latestCheckpoint = package.checkpoints?.first,
           let tag = latestCheckpoint.status, !tag.isEmpty,
           let inferred = statusFromCheckpointTag(tag) {
            resolvedStatus = inferred
        }

        return TrackedPackagePayload(
            trackingNumber: package.trackingNumber,
            title: package.title,
            carrierSlug: package.carrierSlug,
            carrierName: package.carrierName,
            status: resolvedStatus,
            lastUpdate: package.lastUpdate,
            trackingId: package.trackingId,
            checkpoints: (package.checkpoints ?? []).map {
                TrackingEvent(
                    id: $0.id ?? UUID().uuidString,
                    title: ($0.status?.isEmpty == false ? $0.status! : "Tracking Update"),
                    detail: ($0.message?.isEmpty == false ? $0.message! : package.lastUpdate),
                    location: $0.location ?? "",
                    timestampText: $0.time ?? "Recent"
                )
            },
            isArchived: package.isArchived ?? false
        )
    }

    func upsertInstallation() async throws {
        guard AppConfig.functionsBaseURL != nil else { return }

        struct RequestBody: Encodable {
            let installationId: String
            let fcmToken: String?
            let notificationsEnabled: Bool
            let platform: String
        }

        _ = try await performRequest(
            path: "upsertInstallation",
            method: "POST",
            body: RequestBody(
                installationId: NotificationService.shared.installationID(),
                fcmToken: NotificationService.shared.currentToken(),
                notificationsEnabled: UserDefaults.standard.bool(forKey: DefaultsKey.notificationsEnabled),
                platform: "ios"
            )
        ) as EmptyResponse
    }

    func listInstallationTrackings() async throws -> [TrackedPackagePayload] {
        guard AppConfig.functionsBaseURL != nil else { return [] }

        let installationID = NotificationService.shared.installationID().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let response: PackageListResponse = try await performRequest(
            path: "listInstallationTrackings?installationId=\(installationID)",
            method: "GET",
            body: Optional<String>.none
        )

        return response.packages.map(makePayload(from:))
    }

    func registerTracking(number: String, title: String, carrier: Carrier?) async throws -> TrackedPackagePayload {
        if AppConfig.functionsBaseURL == nil {
            return mockPayload(number: number, title: title, carrier: carrier)
        }

        struct RequestBody: Encodable {
            let trackingNumber: String
            let title: String
            let carrierCode: Int?
            let installationId: String
        }

        let body = RequestBody(
            trackingNumber: number,
            title: title,
            carrierCode: carrier?.code,
            installationId: NotificationService.shared.installationID()
        )

        let response: PackageBody = try await performRequest(
            path: "registerTracking",
            method: "POST",
            body: body
        )

        return makePayload(from: response)
    }

    func getTrackingStatus(for package: Package) async throws -> TrackedPackagePayload {
        if AppConfig.functionsBaseURL == nil {
            return TrackedPackagePayload(
                trackingNumber: package.trackingNumber,
                title: package.title ?? "Package",
                carrierSlug: package.carrierSlug ?? "unknown",
                carrierName: package.carrierName ?? "Unknown Carrier",
                status: package.status,
                lastUpdate: package.lastUpdate ?? package.status.summaryText,
                trackingId: package.trackingId,
                checkpoints: [
                    TrackingEvent(
                        id: package.id.uuidString,
                        title: package.status.badgeText,
                        detail: package.lastUpdate ?? package.status.summaryText,
                        location: package.carrierName ?? "",
                        timestampText: "Recent"
                    )
                ],
                isArchived: package.isArchived
            )
        }

        let encodedNumber = package.trackingNumber.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let installationID = NotificationService.shared.installationID().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let path = "getTrackingStatus?trackingNumber=\(encodedNumber)&installationId=\(installationID)"
        let response: PackageBody = try await performRequest(path: path, method: "GET", body: Optional<String>.none)

        return makePayload(from: response)
    }

    func stopTracking(for package: Package) async throws {
        guard AppConfig.functionsBaseURL != nil else { return }

        struct RequestBody: Encodable {
            let trackingNumber: String
            let installationId: String
        }

        _ = try await performRequest(
            path: "stopTracking",
            method: "POST",
            body: RequestBody(
                trackingNumber: package.trackingNumber,
                installationId: NotificationService.shared.installationID()
            )
        ) as EmptyResponse
    }

    func setTrackingArchived(trackingNumber: String, isArchived: Bool) async throws {
        guard AppConfig.functionsBaseURL != nil else { return }

        struct RequestBody: Encodable {
            let trackingNumber: String
            let installationId: String
            let isArchived: Bool
        }

        _ = try await performRequest(
            path: "setTrackingArchived",
            method: "POST",
            body: RequestBody(
                trackingNumber: trackingNumber,
                installationId: NotificationService.shared.installationID(),
                isArchived: isArchived
            )
        ) as EmptyResponse
    }

    func markTrackingDelivered(for package: Package) async throws -> TrackedPackagePayload {
        if AppConfig.functionsBaseURL == nil {
            return TrackedPackagePayload(
                trackingNumber: package.trackingNumber,
                title: package.title ?? package.trackingNumber,
                carrierSlug: package.carrierSlug ?? "unknown",
                carrierName: package.carrierName ?? "Unknown Carrier",
                status: .delivered,
                lastUpdate: "Manually marked as delivered",
                trackingId: package.trackingId,
                checkpoints: package.checkpoints,
                isArchived: package.isArchived
            )
        }

        struct RequestBody: Encodable {
            let trackingNumber: String
            let installationId: String
        }

        let response: PackageBody = try await performRequest(
            path: "markTrackingDelivered",
            method: "POST",
            body: RequestBody(
                trackingNumber: package.trackingNumber,
                installationId: NotificationService.shared.installationID()
            )
        )

        return makePayload(from: response)
    }

    func updateTrackingCarrier(for package: Package, carrier: Carrier) async throws -> TrackedPackagePayload {
        if AppConfig.functionsBaseURL == nil {
            return TrackedPackagePayload(
                trackingNumber: package.trackingNumber,
                title: package.title ?? package.trackingNumber,
                carrierSlug: "\(carrier.code)",
                carrierName: carrier.name,
                status: package.status,
                lastUpdate: package.lastUpdate ?? package.status.summaryText,
                trackingId: package.trackingId,
                checkpoints: package.checkpoints,
                isArchived: package.isArchived
            )
        }

        struct RequestBody: Encodable {
            let trackingNumber: String
            let installationId: String
            let carrierCode: Int
            let carrierName: String
        }

        let response: PackageBody = try await performRequest(
            path: "updateTrackingCarrier",
            method: "POST",
            body: RequestBody(
                trackingNumber: package.trackingNumber,
                installationId: NotificationService.shared.installationID(),
                carrierCode: carrier.code,
                carrierName: carrier.name
            )
        )

        return makePayload(from: response)
    }

    private func performRequest<Response: Decodable, Body: Encodable>(path: String,
                                                                      method: String,
                                                                      body: Body?) async throws -> Response {
        guard let baseURL = AppConfig.functionsBaseURL else {
            throw APIServiceError.invalidURL
        }

        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let code = json["code"] as? String, code == "CARRIER_REQUIRED" {
                throw APIServiceError.carrierRequired
            }
            let message = String(data: data, encoding: .utf8) ?? "Unknown server error."
            throw APIServiceError.serverError(message)
        }

        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }

        return try decoder.decode(Response.self, from: data)
    }

    private func mockPayload(number: String, title: String, carrier: Carrier?) -> TrackedPackagePayload {
        let carrierName = carrier?.name ?? "Unknown Carrier"
        return TrackedPackagePayload(
            trackingNumber: number,
            title: title.isEmpty ? "New Package" : title,
            carrierSlug: "unknown",
            carrierName: carrierName,
            status: .pending,
            lastUpdate: "Connected to local mock flow until Firebase Functions URL is configured.",
            trackingId: UUID().uuidString,
            checkpoints: [
                TrackingEvent(
                    id: UUID().uuidString,
                    title: "Pending",
                    detail: "Tracking is waiting for live backend data.",
                    location: carrierName,
                    timestampText: "Recent"
                )
            ]
        )
    }
}

private struct EmptyResponse: Decodable {
}
