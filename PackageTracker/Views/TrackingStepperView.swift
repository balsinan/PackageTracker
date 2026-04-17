import UIKit

final class TrackingStepperView: UIView {

    private let steps: [(icon: String, label: String)] = [
        ("doc.text.fill", "Info\nReceived"),
        ("shippingbox.fill", "In\nTransit"),
        ("house.fill", "Out for\nDelivery"),
        ("checkmark.circle.fill", "Delivered")
    ]

    private var stepCircles: [UIView] = []
    private var connectors: [UIView] = []
    private var iconViews: [UIImageView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setActiveStep(_ status: PackageStatus) {
        let activeIndex: Int
        switch status {
        case .pending:
            activeIndex = 0
        case .inTransit:
            activeIndex = 1
        case .outForDelivery:
            activeIndex = 2
        case .delivered:
            activeIndex = 3
        default:
            activeIndex = 0
        }

        for (i, circle) in stepCircles.enumerated() {
            let isActive = i <= activeIndex
            circle.backgroundColor = isActive ? AppTheme.accent : AppTheme.tertiaryBackground
            iconViews[i].tintColor = isActive ? .white : AppTheme.textSecondary
        }

        for (i, connector) in connectors.enumerated() {
            connector.backgroundColor = (i < activeIndex) ? AppTheme.accent : AppTheme.tertiaryBackground
        }
    }

    private func buildUI() {
        let container = UIStackView()
        container.axis = .horizontal
        container.alignment = .top
        container.distribution = .equalSpacing

        for (i, step) in steps.enumerated() {
            let column = UIStackView()
            column.axis = .vertical
            column.alignment = .center
            column.spacing = 8

            let circle = UIView()
            circle.backgroundColor = AppTheme.tertiaryBackground
            circle.layer.cornerRadius = 24
            circle.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                circle.widthAnchor.constraint(equalToConstant: 48),
                circle.heightAnchor.constraint(equalToConstant: 48)
            ])

            let icon = UIImageView(image: UIImage(systemName: step.icon))
            icon.tintColor = AppTheme.textSecondary
            icon.contentMode = .scaleAspectFit
            icon.translatesAutoresizingMaskIntoConstraints = false
            circle.addSubview(icon)
            NSLayoutConstraint.activate([
                icon.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 22),
                icon.heightAnchor.constraint(equalToConstant: 22)
            ])

            let label = UILabel()
            label.text = step.label
            label.font = .systemFont(ofSize: 11, weight: .semibold)
            label.textColor = AppTheme.textSecondary
            label.textAlignment = .center
            label.numberOfLines = 2

            column.addArrangedSubview(circle)
            column.addArrangedSubview(label)

            stepCircles.append(circle)
            iconViews.append(icon)

            if i > 0 {
                let connector = UIView()
                connector.backgroundColor = AppTheme.tertiaryBackground
                connector.translatesAutoresizingMaskIntoConstraints = false
                addSubview(connector)
                connectors.append(connector)
            }

            container.addArrangedSubview(column)
        }

        addSubview(container)
        container.anchor(
            top: topAnchor,
            leading: leadingAnchor,
            bottom: bottomAnchor,
            trailing: trailingAnchor,
            padding: UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for (i, connector) in connectors.enumerated() {
            let from = stepCircles[i]
            let to = stepCircles[i + 1]
            let fromFrame = convert(from.bounds, from: from)
            let toFrame = convert(to.bounds, from: to)
            let connectorHeight: CGFloat = 3

            connector.frame = CGRect(
                x: fromFrame.maxX + 4,
                y: fromFrame.midY - (connectorHeight / 2),
                width: max(0, toFrame.minX - fromFrame.maxX - 8),
                height: connectorHeight
            )
            connector.layer.cornerRadius = connectorHeight / 2
        }
    }
}
