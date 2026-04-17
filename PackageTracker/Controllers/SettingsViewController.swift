import UIKit

final class SettingsViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let notificationSwitch = UISwitch()
    private let archiveSwitch = UISwitch()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background
        title = "Settings"
        configureUI()
    }

    private func configureUI() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = AppTheme.background
        navAppearance.titleTextAttributes = [.foregroundColor: AppTheme.textPrimary]
        navigationController?.navigationBar.standardAppearance = navAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = navAppearance
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        view.addSubview(scrollView)
        scrollView.pinToSuperview()

        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        let headerLabel = UILabel()
        headerLabel.text = "General"
        headerLabel.font = .systemFont(ofSize: 18, weight: .bold)
        headerLabel.textColor = AppTheme.textPrimary

        notificationSwitch.onTintColor = AppTheme.accent
        notificationSwitch.isOn = UserDefaults.standard.bool(forKey: DefaultsKey.notificationsEnabled)
        notificationSwitch.addTarget(self, action: #selector(notificationToggleChanged), for: .valueChanged)

        archiveSwitch.onTintColor = AppTheme.accent
        archiveSwitch.isOn = UserDefaults.standard.bool(forKey: DefaultsKey.archiveDelivered)
        archiveSwitch.addTarget(self, action: #selector(archiveToggleChanged), for: .valueChanged)

        let card = UIStackView(arrangedSubviews: [
            makeRow(title: "Notifications", subtitle: "Push updates for shipment changes", accessory: notificationSwitch),
            makeSeparator(),
            makeRow(title: "Archive Delivered", subtitle: "Hide delivered packages from the main list", accessory: archiveSwitch)
        ])
        card.axis = .vertical
        card.backgroundColor = AppTheme.secondaryBackground
        card.isLayoutMarginsRelativeArrangement = true
        card.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
        card.layer.cornerRadius = Layout.cardCornerRadius
        card.clipsToBounds = true

        let footer = UILabel()
        footer.text = "Firebase + 17TRACK wiring is scaffolded. Add your Cloud Functions URL in Info.plist to switch from local mock mode to live backend mode."
        footer.font = .systemFont(ofSize: 14, weight: .medium)
        footer.textColor = AppTheme.textSecondary
        footer.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [headerLabel, card, footer])
        stack.axis = .vertical
        stack.spacing = 18

        contentView.addSubview(stack)
        stack.anchor(
            top: contentView.safeAreaLayoutGuide.topAnchor,
            leading: contentView.leadingAnchor,
            bottom: contentView.bottomAnchor,
            trailing: contentView.trailingAnchor,
            padding: UIEdgeInsets(top: 20, left: Layout.screenPadding, bottom: 24, right: Layout.screenPadding)
        )
    }

    private func makeRow(title: String, subtitle: String, accessory: UIView) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = AppTheme.textPrimary

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = AppTheme.textSecondary
        subtitleLabel.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 4

        let row = UIStackView(arrangedSubviews: [textStack, accessory])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        return row
    }

    private func makeSeparator() -> UIView {
        let view = UIView()
        view.backgroundColor = AppTheme.separator
        view.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return view
    }

    @objc private func notificationToggleChanged() {
        UserDefaults.standard.set(notificationSwitch.isOn, forKey: DefaultsKey.notificationsEnabled)
        Task {
            try? await APIService.shared.upsertInstallation()
        }
    }

    @objc private func archiveToggleChanged() {
        UserDefaults.standard.set(archiveSwitch.isOn, forKey: DefaultsKey.archiveDelivered)
        NotificationCenter.default.post(name: .packageStoreDidChange, object: nil)
    }
}
