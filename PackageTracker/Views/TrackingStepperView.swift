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

    private lazy var columnsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .top
        stack.distribution = .equalSpacing
        stack.spacing = 0
        stack.isLayoutMarginsRelativeArrangement = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

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
            let segmentDone = activeIndex > i
            connector.backgroundColor = segmentDone ? AppTheme.accent : AppTheme.tertiaryBackground
            connector.alpha = segmentDone ? 1 : 0.45
        }
    }

    private func buildUI() {
        for (_, step) in steps.enumerated() {
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

            columnsStack.addArrangedSubview(column)
        }

        addSubview(columnsStack)
        columnsStack.anchor(
            top: topAnchor,
            leading: leadingAnchor,
            bottom: bottomAnchor,
            trailing: trailingAnchor,
            padding: UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        )

        for i in 0..<3 {
            let connector = UIView()
            connector.translatesAutoresizingMaskIntoConstraints = false
            connector.layer.cornerRadius = 1.5
            connector.backgroundColor = AppTheme.tertiaryBackground
            connector.alpha = 0.45
            addSubview(connector)
            connectors.append(connector)

            let left = stepCircles[i]
            let right = stepCircles[i + 1]

            NSLayoutConstraint.activate([
                connector.centerYAnchor.constraint(equalTo: left.centerYAnchor),
                connector.leadingAnchor.constraint(equalTo: left.trailingAnchor, constant: 6),
                connector.trailingAnchor.constraint(equalTo: right.leadingAnchor, constant: -6),
                connector.heightAnchor.constraint(equalToConstant: 3)
            ])
        }

        // Connectors are added after `columnsStack`, so they paint on top of the stack. They sit only
        // in the horizontal gap between adjacent circles (see constraints), so they don’t cover icons.
    }
}
