import UIKit

final class CarrierCell: UITableViewCell {
    static let reuseIdentifier = "CarrierCell"

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 8
        iv.backgroundColor = AppTheme.tertiaryBackground
        return iv
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textColor = AppTheme.textPrimary
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.image = nil
        nameLabel.text = nil
        accessoryType = .none
    }

    func configure(with carrier: Carrier, selected: Bool) {
        nameLabel.text = carrier.name
        accessoryType = selected ? .checkmark : .none

        let placeholder = UIImage(systemName: "shippingbox.fill")?.withTintColor(AppTheme.textSecondary, renderingMode: .alwaysOriginal)
        FaviconLoader.shared.loadFavicon(for: carrier.url, into: iconView, placeholder: placeholder)
    }

    private func configureUI() {
        backgroundColor = AppTheme.secondaryBackground
        tintColor = AppTheme.accent
        selectionStyle = .none

        let row = UIStackView(arrangedSubviews: [iconView, nameLabel])
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center

        contentView.addSubview(row)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 36),
            iconView.heightAnchor.constraint(equalToConstant: 36)
        ])

        row.anchor(
            top: contentView.topAnchor,
            leading: contentView.leadingAnchor,
            bottom: contentView.bottomAnchor,
            trailing: contentView.trailingAnchor,
            padding: UIEdgeInsets(top: 10, left: Layout.screenPadding, bottom: 10, right: Layout.screenPadding)
        )
    }
}
