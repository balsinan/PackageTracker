import UIKit

final class StatusFilterBar: UIView {
    var onSelectionChanged: ((PackageStatus) -> Void)?

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private var chips: [StatusFilterChipControl] = []
    private var selectedStatus: PackageStatus = .all
    private var counts: [PackageStatus: Int] = [:]
    private var chipOrder: [PackageStatus] = PackageStatus.filterChips(includeArchived: false)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
        rebuildChips(order: chipOrder, preserveSelection: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateCounts(_ newCounts: [PackageStatus: Int]) {
        counts = newCounts
        applyButtonAppearances()
    }

    func updateSelection(_ status: PackageStatus) {
        selectedStatus = status
        applyButtonAppearances()
    }

    /// Rebuild chips when the filtered statuses change (order must match `PackageStatus.filterChips`).
    func setChipOrder(_ order: [PackageStatus], preserveSelection: Bool) {
        guard order != chipOrder else {
            applyButtonAppearances()
            return
        }
        chipOrder = order
        rebuildChips(order: order, preserveSelection: preserveSelection)
    }

    private func rebuildChips(order: [PackageStatus], preserveSelection: Bool) {
        let previousSelection = selectedStatus
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        chips.removeAll()

        let candidate = preserveSelection ? selectedStatus : .all
        let fallback: PackageStatus = order.contains(candidate) ? candidate : .all

        for status in order {
            let chip = StatusFilterChipControl(packageStatus: status)
            chip.accessibilityIdentifier = status.rawValue
            chip.addTarget(self, action: #selector(filterTapped(_:)), for: .touchUpInside)
            chips.append(chip)
            stackView.addArrangedSubview(chip)
        }

        selectedStatus = fallback
        applyButtonAppearances()
        if previousSelection != selectedStatus {
            onSelectionChanged?(selectedStatus)
        }
    }

    private func applyButtonAppearances() {
        for chip in chips {
            chip.count = counts[chip.packageStatus] ?? 0
            chip.setChipSelected(chip.packageStatus == selectedStatus)
        }
    }

    private func configureUI() {
        addSubview(scrollView)
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.pinToSuperview()

        scrollView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        stackView.axis = .horizontal
        stackView.spacing = 8
    }

    @objc private func filterTapped(_ sender: UIControl) {
        guard let chip = sender as? StatusFilterChipControl else { return }
        if chip.packageStatus == selectedStatus {
            HapticFeedback.soft.play()
            return
        }
        HapticFeedback.selection.play()
        updateSelection(chip.packageStatus)
        onSelectionChanged?(chip.packageStatus)
    }
}

// MARK: - Chip

private final class StatusFilterChipControl: UIControl {
    let packageStatus: PackageStatus

    private let titleLabel = UILabel()
    private let badgeContainer = UIView()
    private let countLabel = UILabel()
    private let row = UIStackView()

    var count: Int = 0 {
        didSet {
            guard oldValue != count else { return }
            updateAppearance()
        }
    }

    private var chipSelected = false

    init(packageStatus: PackageStatus) {
        self.packageStatus = packageStatus
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setChipSelected(_ selected: Bool) {
        guard chipSelected != selected else { return }
        chipSelected = selected
        updateAppearance()
    }

    private func formatCount(_ value: Int) -> String {
        value > 99 ? "99+" : "\(value)"
    }

    private func setup() {
        titleLabel.text = packageStatus.title
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        countLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        countLabel.textAlignment = .center
        countLabel.text = "0"

        badgeContainer.layer.cornerRadius = 9
        badgeContainer.clipsToBounds = true
        badgeContainer.addSubview(countLabel)
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            countLabel.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: 3),
            countLabel.bottomAnchor.constraint(equalTo: badgeContainer.bottomAnchor, constant: -3),
            countLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 7),
            countLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -7)
        ])
        badgeContainer.setContentHuggingPriority(.required, for: .horizontal)
        badgeContainer.setContentCompressionResistancePriority(.required, for: .horizontal)

        row.axis = .horizontal
        row.spacing = 6
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(badgeContainer)

        addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            row.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        layer.cornerRadius = 14
        updateAppearance()
    }

    private func updateAppearance() {
        backgroundColor = chipSelected ? AppTheme.secondaryBackground : .clear

        titleLabel.textColor = chipSelected ? AppTheme.textPrimary : AppTheme.textSecondary

        let showBadge = count > 0
        badgeContainer.isHidden = !showBadge
        guard showBadge else {
            accessibilityLabel = packageStatus.title
            return
        }

        countLabel.text = formatCount(count)

        if chipSelected {
            badgeContainer.backgroundColor = AppTheme.tertiaryBackground
            countLabel.textColor = AppTheme.textPrimary
        } else {
            badgeContainer.backgroundColor = AppTheme.tertiaryBackground.withAlphaComponent(0.55)
            countLabel.textColor = AppTheme.textSecondary
        }

        accessibilityLabel = "\(packageStatus.title), \(count) " + (count == 1 ? "package" : "packages")
    }
}
