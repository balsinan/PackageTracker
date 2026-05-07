import UIKit

enum EmptyStateMode {
    case noPackages
    case noSearchResults
    case noArchivedPackages
}

final class EmptyStateView: UIView {
    private let imageView = UIImageView(image: UIImage(systemName: "shippingbox"))
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    private(set) var mode: EmptyStateMode = .noPackages

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureUI() {
        let stackView = UIStackView(arrangedSubviews: [imageView, titleLabel, subtitleLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 16

        imageView.tintColor = AppTheme.accent
        imageView.contentMode = .scaleAspectFit
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 82, weight: .regular)

        titleLabel.text = "Add your first package"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = AppTheme.textPrimary

        subtitleLabel.text = "Track every shipment in one place and get status changes as they happen."
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        subtitleLabel.textColor = AppTheme.textSecondary
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center

        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32)
        ])
    }

    func setMode(_ mode: EmptyStateMode) {
        guard self.mode != mode else { return }
        self.mode = mode
        switch mode {
        case .noPackages:
            imageView.image = UIImage(systemName: "shippingbox")
            titleLabel.text = "Add your first package"
            subtitleLabel.text = "Track every shipment in one place and get status changes as they happen."
        case .noSearchResults:
            imageView.image = UIImage(systemName: "magnifyingglass")
            titleLabel.text = "No matches"
            subtitleLabel.text = "Try a different name, carrier, or tracking number."
        case .noArchivedPackages:
            imageView.image = UIImage(systemName: "archivebox")
            titleLabel.text = "Nothing archived yet"
            subtitleLabel.text = "Delivered packages can move here automatically, or swipe a row to archive."
        }
    }
}
