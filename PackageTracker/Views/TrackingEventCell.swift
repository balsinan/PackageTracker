import UIKit

final class TrackingEventCell: UITableViewCell {
    static let reuseIdentifier = "TrackingEventCell"

    private let dotView = UIView()
    private let verticalLine = UIView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let locationLabel = UILabel()
    private let dateLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with event: TrackingEvent, isLast: Bool) {
        titleLabel.text = event.title
        detailLabel.text = event.detail
        locationLabel.text = event.location
        locationLabel.isHidden = event.location.isEmpty
        dateLabel.text = event.timestampText

        verticalLine.isHidden = isLast
    }

    private func configureUI() {
        backgroundColor = .clear
        selectionStyle = .none

        dotView.backgroundColor = AppTheme.accent
        dotView.layer.cornerRadius = 6

        verticalLine.backgroundColor = AppTheme.separator

        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = AppTheme.textPrimary

        detailLabel.font = .systemFont(ofSize: 15, weight: .medium)
        detailLabel.textColor = AppTheme.textPrimary
        detailLabel.numberOfLines = 0

        locationLabel.font = .systemFont(ofSize: 14, weight: .medium)
        locationLabel.textColor = AppTheme.textSecondary

        dateLabel.font = .systemFont(ofSize: 13, weight: .regular)
        dateLabel.textColor = AppTheme.textSecondary

        let textStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel, locationLabel, dateLabel])
        textStack.axis = .vertical
        textStack.spacing = 4

        contentView.addSubview(dotView)
        contentView.addSubview(verticalLine)
        contentView.addSubview(textStack)

        dotView.anchor(top: contentView.topAnchor, leading: contentView.leadingAnchor,
                       padding: UIEdgeInsets(top: 22, left: Layout.screenPadding + 4, bottom: 0, right: 0),
                       size: CGSize(width: 12, height: 12))
        verticalLine.anchor(top: dotView.bottomAnchor, leading: dotView.leadingAnchor, bottom: contentView.bottomAnchor,
                            padding: UIEdgeInsets(top: 6, left: 5, bottom: 0, right: 0),
                            size: CGSize(width: 2, height: .zero))
        textStack.anchor(
            top: contentView.topAnchor,
            leading: dotView.trailingAnchor,
            bottom: contentView.bottomAnchor,
            trailing: contentView.trailingAnchor,
            padding: UIEdgeInsets(top: 16, left: 18, bottom: 16, right: Layout.screenPadding)
        )
    }
}
