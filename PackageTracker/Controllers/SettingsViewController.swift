import MessageUI
import RevenueCat
import SafariServices
import StoreKit
import UIKit
import UserNotifications

final class SettingsViewController: UIViewController, MFMailComposeViewControllerDelegate {
    private var restoreLoadingOverlay: UIView?
    /// Tracks premium state used when building the Support rows (`Upgrade to Pro`).
    private var layoutPremiumState: Bool?
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let notificationSwitch = UISwitch()
    /// Hidden until the user has been prompted for notification permission at least once.
    private var showNotificationSection = false

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        navigationItem.largeTitleDisplayMode = .always
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        navigationItem.largeTitleDisplayMode = .always
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background
        title = "Settings"
        configureUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        applySettingsNavigationBarAppearance()
        navigationItem.title = "Settings"
        title = "Settings"
        super.viewWillAppear(animated)
        let premiumNow = isPremium()
        if let prev = layoutPremiumState, prev != premiumNow {
            tableView.reloadData()
        }
        layoutPremiumState = premiumNow
        syncNotificationSwitchState()
    }

    private func syncNotificationSwitchState() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                guard let self else { return }
                let wasVisible = self.showNotificationSection
                self.showNotificationSection = settings.authorizationStatus != .notDetermined

                let userPreference = UserDefaults.standard.bool(forKey: DefaultsKey.notificationsEnabled)
                let systemAuthorized = settings.authorizationStatus == .authorized
                self.notificationSwitch.isOn = systemAuthorized && userPreference

                if wasVisible != self.showNotificationSection {
                    self.tableView.reloadData()
                }
            }
        }
    }

    /// Re-apply on every appearance so tab switches keep bar colors aligned with Packages.
    private func applySettingsNavigationBarAppearance() {
        guard let bar = navigationController?.navigationBar else { return }
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = AppTheme.background
        navAppearance.titleTextAttributes = [.foregroundColor: AppTheme.textPrimary]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: AppTheme.textPrimary]
        bar.standardAppearance = navAppearance
        bar.scrollEdgeAppearance = navAppearance
        bar.compactAppearance = navAppearance
        bar.compactScrollEdgeAppearance = navAppearance
        bar.tintColor = AppTheme.accent
        bar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        bar.setNeedsLayout()
    }

    private func configureUI() {
        applySettingsNavigationBarAppearance()

        notificationSwitch.onTintColor = AppTheme.accent
        notificationSwitch.isOn = UserDefaults.standard.bool(forKey: DefaultsKey.notificationsEnabled)
        notificationSwitch.addTarget(self, action: #selector(notificationToggleChanged), for: .valueChanged)

        tableView.backgroundColor = AppTheme.background
        tableView.delegate = self
        tableView.dataSource = self
        tableView.keyboardDismissMode = .onDrag
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: SettingsCell.switchRow.rawValue)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: SettingsCell.actionRow.rawValue)
        tableView.sectionHeaderTopPadding = 18
        view.addSubview(tableView)
        tableView.pinToSuperview()
        tableView.reloadData()
    }

    private enum SettingsSection {
        case general
        case support
    }

    private var visibleSections: [SettingsSection] {
        var sections: [SettingsSection] = []
        if showNotificationSection { sections.append(.general) }
        sections.append(.support)
        return sections
    }

    private enum SettingsCell: String {
        case switchRow = "settings.switch"
        case actionRow = "settings.action"
    }

    /// Row index in Support section maps to these actions (premium hides `upgrade`).
    private func supportEntries() -> [Selector] {
        var entries: [Selector] = []
        if !isPremium() {
            entries.append(#selector(upgradeTapped))
        }
        entries.append(contentsOf: [
            #selector(sendEmailTapped),
            #selector(rateUsTapped),
            #selector(shareAppTapped),
            #selector(restoreTapped),
            #selector(termsTapped),
            #selector(privacyTapped)
        ])
        return entries
    }

    private func title(forSupportRow row: Int) -> String {
        let titles: [String] = [
            "Upgrade to Pro",
            "Send Email",
            "Rate Us",
            "Share App",
            "Restore",
            "Terms",
            "Privacy"
        ]
        let offset = isPremium() ? 1 : 0
        return titles[row + offset]
    }

    private func headerLabel(text: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = AppTheme.textPrimary
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Layout.screenPadding),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Layout.screenPadding),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6)
        ])
        return container
    }

    /// Configures grouped cell appearance to match former card styling.
    private func styleGrouped(cell: UITableViewCell) {
        cell.backgroundColor = AppTheme.secondaryBackground
        cell.textLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        cell.textLabel?.textColor = AppTheme.textPrimary
    }

    @objc private func notificationToggleChanged() {
        HapticFeedback.light.play()
        let isOn = notificationSwitch.isOn

        if isOn {
            UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if settings.authorizationStatus == .denied {
                        self.notificationSwitch.setOn(false, animated: true)
                        self.presentNotificationDeniedAlert()
                        return
                    }

                    NotificationService.shared.requestSystemNotificationPermission(application: UIApplication.shared) { [weak self] granted in
                        if !granted {
                            DispatchQueue.main.async {
                                self?.notificationSwitch.setOn(false, animated: true)
                            }
                        }
                        Task {
                            try? await APIService.shared.upsertInstallation()
                        }
                    }
                }
            }
        } else {
            UserDefaults.standard.set(false, forKey: DefaultsKey.notificationsEnabled)
            Task {
                try? await APIService.shared.upsertInstallation()
            }
        }
    }

    private func presentNotificationDeniedAlert() {
        let alert = UIAlertController(
            title: "Notifications Disabled",
            message: "Please enable notifications in Settings to receive tracking updates.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Actions

    @objc private func upgradeTapped() {
        HapticFeedback.light.play()
        PaywallViewController.presentModally(from: self)
    }

    @objc private func sendEmailTapped() {
        HapticFeedback.light.play()

        let appDisplayName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "Package Tracker"
        let userID = Purchases.shared.appUserID

        let intro = """
        App: \(appDisplayName)
        User ID: \(userID)

        —
        (Write your message below)

        """
        let body = intro + "\n"

        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients([AppLinks.supportEmail])
            mail.setSubject("\(appDisplayName) — Support")
            mail.setMessageBody(body, isHTML: false)
            present(mail, animated: true)
            return
        }

        let subject = "\(appDisplayName) — Support"
        guard var components = URLComponents(string: "mailto:\(AppLinks.supportEmail)") else { return }
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        guard let mailURL = components.url else { return }
        UIApplication.shared.open(mailURL)
    }

    @objc private func rateUsTapped() {
        HapticFeedback.light.play()
        if let url = AppLinks.appStoreWriteReviewURL {
            UIApplication.shared.open(url)
            return
        }
        guard let scene = view.window?.windowScene else { return }
        SKStoreReviewController.requestReview(in: scene)
    }

    @objc private func shareAppTapped() {
        HapticFeedback.light.play()
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Package Tracker"
        var items: [Any] = [appName]
        if let storeURL = AppLinks.appStoreListingURL {
            items.append(storeURL)
        }
        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        present(activity, animated: true)
    }

    @objc private func restoreTapped() {
        HapticFeedback.light.play()

        beginRestoreOverlay()
        IapService.sharedInstance.restorePurchase { [weak self] success, error in
            DispatchQueue.main.async {
                self?.endRestoreOverlay()
                if success {
                    let alert = UIAlertController(
                        title: "Purchases Restored",
                        message: "Your subscription is active again.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alert, animated: true)
                    return
                }
                if let error {
                    let alert = UIAlertController(
                        title: "Restore Failed",
                        message: error.localizedDescription,
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alert, animated: true)
                    return
                }
                let alert = UIAlertController(
                    title: "Nothing to Restore",
                    message: "We could not find an active subscription for this Apple ID.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
            }
        }
    }

    private func beginRestoreOverlay() {
        guard restoreLoadingOverlay == nil else { return }
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        overlay.addSubview(spinner)
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            spinner.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
        ])
        restoreLoadingOverlay = overlay
    }

    private func endRestoreOverlay() {
        restoreLoadingOverlay?.removeFromSuperview()
        restoreLoadingOverlay = nil
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }

    @objc private func termsTapped() {
        HapticFeedback.light.play()
        presentInAppWeb(url: AppLinks.terms)
    }

    @objc private func privacyTapped() {
        HapticFeedback.light.play()
        presentInAppWeb(url: AppLinks.privacy)
    }

    private func presentInAppWeb(url: URL) {
        let safari = SFSafariViewController(url: url)
        safari.preferredControlTintColor = AppTheme.accent
        safari.dismissButtonStyle = .close
        safari.modalPresentationStyle = .pageSheet
        if let sheet = safari.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = Layout.cardCornerRadius
        }
        present(safari, animated: true)
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { visibleSections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch visibleSections[section] {
        case .general:
            return 1
        case .support:
            return supportEntries().count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch visibleSections[indexPath.section] {
        case .general:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsCell.switchRow.rawValue, for: indexPath)
            cell.selectionStyle = .none
            cell.textLabel?.text = "Tracking Notifications"
            notificationSwitch.onTintColor = AppTheme.accent
            cell.accessoryView = notificationSwitch
            styleGrouped(cell: cell)
            return cell
        case .support:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsCell.actionRow.rawValue, for: indexPath)
            cell.selectionStyle = .default
            cell.accessoryView = nil
            cell.accessoryType = .disclosureIndicator
            cell.textLabel?.text = title(forSupportRow: indexPath.row)
            styleGrouped(cell: cell)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { UITableView.automaticDimension }

    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat { 40 }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch visibleSections[section] {
        case .general:
            return headerLabel(text: "General")
        case .support:
            return headerLabel(text: "Support & Legal")
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard visibleSections[indexPath.section] == .support else { return }
        tableView.deselectRow(at: indexPath, animated: true)
        perform(supportEntries()[indexPath.row])
    }
}
