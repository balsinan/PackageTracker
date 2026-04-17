import UIKit

final class PackageCell: UITableViewCell {
    static let reuseIdentifier = "PackageCell"

    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let carrierLabel = UILabel()
    private let messageLabel = UILabel()
    private let dateLabel = UILabel()
    private let badgeLabel = PaddingLabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with package: Package) {
        titleLabel.text = package.title ?? package.trackingNumber
        carrierLabel.text = package.carrierName ?? "Unknown carrier"
        messageLabel.text = package.lastUpdate ?? package.status.summaryText

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        dateLabel.text = formatter.localizedString(for: package.createdAt, relativeTo: Date())

        badgeLabel.text = package.status.badgeText
        badgeLabel.backgroundColor = package.status.color.withAlphaComponent(0.15)
        badgeLabel.textColor = package.status.color
    }

    private func configureUI() {
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(cardView)
        cardView.anchor(
            top: contentView.topAnchor,
            leading: contentView.leadingAnchor,
            bottom: contentView.bottomAnchor,
            trailing: contentView.trailingAnchor,
            padding: UIEdgeInsets(top: 6, left: Layout.screenPadding, bottom: 6, right: Layout.screenPadding)
        )

        cardView.backgroundColor = AppTheme.secondaryBackground
        cardView.layer.cornerRadius = Layout.cardCornerRadius

        let topRow = UIStackView(arrangedSubviews: [titleLabel, badgeLabel])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 12

        let stack = UIStackView(arrangedSubviews: [topRow, carrierLabel, messageLabel, dateLabel])
        stack.axis = .vertical
        stack.spacing = 8

        cardView.addSubview(stack)
        stack.anchor(
            top: cardView.topAnchor,
            leading: cardView.leadingAnchor,
            bottom: cardView.bottomAnchor,
            trailing: cardView.trailingAnchor,
            padding: UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        )

        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = AppTheme.textPrimary

        carrierLabel.font = .systemFont(ofSize: 15, weight: .medium)
        carrierLabel.textColor = AppTheme.textSecondary

        messageLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        messageLabel.textColor = AppTheme.textPrimary
        messageLabel.numberOfLines = 2

        dateLabel.font = .systemFont(ofSize: 15, weight: .regular)
        dateLabel.textColor = AppTheme.textSecondary

        badgeLabel.font = .systemFont(ofSize: 13, weight: .bold)
        badgeLabel.layer.cornerRadius = 14
        badgeLabel.clipsToBounds = true
    }
}

private final class PaddingLabel: UILabel {
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + 20, height: size.height + 12)
    }
}
