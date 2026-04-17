import UIKit

final class StatusFilterBar: UIView {
    var onSelectionChanged: ((PackageStatus) -> Void)?

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private var buttons: [UIButton] = []
    private var selectedStatus: PackageStatus = .all

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateSelection(_ status: PackageStatus) {
        selectedStatus = status
        buttons.forEach { button in
            let isSelected = button.accessibilityIdentifier == status.rawValue
            button.setTitleColor(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary, for: .normal)
            button.backgroundColor = isSelected ? AppTheme.secondaryBackground : .clear
        }
    }

    private func configureUI() {
        addSubview(scrollView)
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

        PackageStatus.allCases.forEach { status in
            let button = UIButton(type: .system)
            button.setTitle(status.title, for: .normal)
            button.setTitleColor(AppTheme.textSecondary, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
            button.backgroundColor = .clear
            button.layer.cornerRadius = 14
            button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
            button.accessibilityIdentifier = status.rawValue
            button.addTarget(self, action: #selector(filterTapped(_:)), for: .touchUpInside)
            buttons.append(button)
            stackView.addArrangedSubview(button)
        }

        updateSelection(.all)
    }

    @objc private func filterTapped(_ sender: UIButton) {
        guard let rawValue = sender.accessibilityIdentifier,
              let status = PackageStatus(rawValue: rawValue) else { return }
        updateSelection(status)
        onSelectionChanged?(status)
    }
}
