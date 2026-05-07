import UIKit

enum PackageStatus: String, CaseIterable {
    case all
    case pending
    case inTransit
    case outForDelivery
    case delivered
    case failedAttempt
    case exception
    case expired
    /// List filter only — not a carrier tracking state.
    case archived

    /// Chips shown in the packages filter bar (optionally includes the Archived status chip).
    static func filterChips(includeArchived: Bool) -> [PackageStatus] {
        let core: [PackageStatus] = [.all, .pending, .inTransit, .outForDelivery, .delivered, .failedAttempt, .exception, .expired]
        return includeArchived ? core + [.archived] : core
    }

    var title: String {
        switch self {
        case .all: return "ALL"
        case .pending: return "PENDING"
        case .inTransit: return "IN TRANSIT"
        case .outForDelivery: return "OUT FOR DELIVERY"
        case .delivered: return "DELIVERED"
        case .failedAttempt: return "FAILED"
        case .exception: return "EXCEPTION"
        case .expired: return "EXPIRED"
        case .archived: return "ARCHIVED"
        }
    }

    var badgeText: String {
        switch self {
        case .outForDelivery:
            return "Out for delivery"
        case .archived:
            return "Archived"
        default:
            return title.capitalized
        }
    }

    var color: UIColor {
        switch self {
        case .all:
            return AppTheme.textSecondary
        case .pending:
            return AppTheme.pending
        case .inTransit, .outForDelivery:
            return AppTheme.inTransit
        case .delivered:
            return AppTheme.delivered
        case .failedAttempt, .exception, .expired:
            return AppTheme.exception
        case .archived:
            return AppTheme.textSecondary
        }
    }

    var summaryText: String {
        switch self {
        case .all:
            return "All packages"
        case .pending:
            return "Waiting for the first scan"
        case .inTransit:
            return "Package is moving through the network"
        case .outForDelivery:
            return "Courier is delivering today"
        case .delivered:
            return "Package was delivered"
        case .failedAttempt:
            return "Delivery attempt failed"
        case .exception:
            return "Unexpected shipment exception"
        case .expired:
            return "Tracking expired"
        case .archived:
            return "Archived packages"
        }
    }
}
