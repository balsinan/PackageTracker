import RevenueCat
import SafariServices
import UIKit

/// Full-screen paywall. Completion targets depend on `presentationStyle` (session gate vs in-app modal).
final class PaywallViewController: UIViewController {

    enum PresentationStyle {
        /// Window root after splash/onboarding; close or purchase → replace root with main tabs.
        case sessionGate
        /// Presented from inside the app; close or purchase → dismiss.
        case modal
    }

    var presentationStyle: PresentationStyle = .sessionGate

    /// Invoked once after the modal paywall finishes dismissing (close, purchase success, or restore success).
    var onModalDismiss: (() -> Void)?

    /// Presents a dismissible paywall over the current UI (e.g. Settings).
    static func presentModally(from presenter: UIViewController, onDismiss: (() -> Void)? = nil) {
        let paywall = PaywallViewController()
        paywall.presentationStyle = .modal
        paywall.onModalDismiss = onDismiss
        paywall.modalPresentationStyle = .fullScreen
        presenter.present(paywall, animated: true)
    }

    private enum Metrics {
        /// Close and info: exact control size (pt).
        static let topBarButtonSide: CGFloat = 29
        static let closeTop: CGFloat = 20
        static let topBarHorizontalInset: CGFloat = 32

        static let titleTopBelowClose: CGFloat = 9
        static let titleLeading: CGFloat = 45
        static let featuresTopBelowTitle: CGFloat = 16
        static let featureIconSize: CGFloat = 12
        static let featureRowLeading: CGFloat = 43
        static let featureRowSpacing: CGFloat = 6
        static let featureIconToLabelSpacing: CGFloat = 8
        static let featuresToWorldSpacing: CGFloat = 12
        static let worldToFooterSpacing: CGFloat = 12

        static let rowHeight: CGFloat = 70
        static let weeklyToYearlySpacing: CGFloat = 13
        static let yearlyToContinueSpacing: CGFloat = 11
        static let horizontalInset: CGFloat = 22
        static let bottomInset: CGFloat = 24
        static let cornerRadius: CGFloat = 31.7

        static let kingTop: CGFloat = 20
        static let kingLeading: CGFloat = 22
        static let kingWidth: CGFloat = 28
        static let kingHeight: CGFloat = 18

        static let badgeWidth: CGFloat = 114
        static let badgeHeight: CGFloat = 20

        static let continueNextIconLeading: CGFloat = 23
        static let continueNextIconWidth: CGFloat = 20
        static let continueNextIconHeight: CGFloat = 23

        /// Matches onboarding inactive dot / review text (`#102B4E`).
        static let selectedForeground = UIColor(red: 16 / 255, green: 43 / 255, blue: 78 / 255, alpha: 1)
    }

    private enum SelectedProduct {
        case weekly
        case yearly
    }

    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "paywall_bg"))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    /// Matches `paywall_close` fallback so the SF Symbol aligns with info in size and weight.
    private static func topBarSymbolConfiguration() -> UIImage.SymbolConfiguration {
        UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
    }

    /// Outline `info.circle`; same metrics as close fallback so both fit the shared square touch target.
    private static func infoBarSymbolConfiguration() -> UIImage.SymbolConfiguration {
        UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
    }

    private static func applyTopBarButtonImageScaling(_ button: UIButton) {
        button.contentHorizontalAlignment = .fill
        button.contentVerticalAlignment = .fill
        button.imageView?.contentMode = .scaleAspectFit
    }

    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        if let image = UIImage(named: "paywall_close") {
            button.setImage(image.withRenderingMode(.alwaysOriginal), for: .normal)
        } else {
            let fallback = UIImage(systemName: "xmark", withConfiguration: Self.topBarSymbolConfiguration())?
                .withTintColor(.white, renderingMode: .alwaysOriginal)
            button.setImage(fallback, for: .normal)
        }
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        button.accessibilityLabel = NSLocalizedString("Close", comment: "Paywall dismiss")
        Self.applyTopBarButtonImageScaling(button)
        return button
    }()

    private lazy var infoButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        let symbolConfig = Self.infoBarSymbolConfiguration()
        let symbol = UIImage(systemName: "info.circle", withConfiguration: symbolConfig)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        button.setImage(symbol, for: .normal)
        Self.applyTopBarButtonImageScaling(button)
        button.menu = paywallInfoMenu()
        button.showsMenuAsPrimaryAction = true
        button.addAction(UIAction { _ in HapticFeedback.light.play() }, for: .menuActionTriggered)
        button.accessibilityLabel = NSLocalizedString("Legal & restore", comment: "Paywall info menu accessibility")
        return button
    }()

    /// Full-screen blocker while RevenueCat completes restore (matches Settings behaviour).
    private var restoreLoadingOverlay: UIView?

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        let titleText = NSLocalizedString(
            "Unlock\nPackage Tracker",
            comment: "Paywall marketing title; two lines"
        )
        let font = Typography.poppins(.semiBold, size: 34)
        let color = Metrics.selectedForeground
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: color,
        ]
        label.attributedText = NSAttributedString(string: titleText, attributes: attributes)
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private let featuresColumn: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        return view
    }()

    private let worldImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "paywall_world"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = false
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return imageView
    }()

    private let paywallFooter: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()

    private let weeklyRow = PlanRow(kind: .weekly)
    private let yearlyRow = PlanRow(kind: .yearly)

    private let continueShadowContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()

    private let continuePill: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.layer.cornerRadius = Metrics.cornerRadius
        view.clipsToBounds = true
        return view
    }()

    private let continueBackgroundImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "next_bg"))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = false
        return imageView
    }()

    private let nextIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.isUserInteractionEnabled = false
        return imageView
    }()

    private let continueTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = Typography.poppins(.semiBold, size: 22)
        label.textAlignment = .center
        label.isUserInteractionEnabled = false
        label.text = NSLocalizedString("Continue", comment: "Paywall purchase CTA")
        return label
    }()

    private var selectedProduct: SelectedProduct = .yearly {
        didSet { syncSelectionToServiceAndUI() }
    }

    private var isPurchasing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(backgroundImageView)
        view.addSubview(closeButton)
        view.addSubview(infoButton)
        view.addSubview(titleLabel)
        view.addSubview(featuresColumn)
        view.addSubview(worldImageView)
        view.addSubview(paywallFooter)
        paywallFooter.addSubview(weeklyRow)
        paywallFooter.addSubview(yearlyRow)
        paywallFooter.addSubview(continueShadowContainer)
        continueShadowContainer.addSubview(continuePill)
        continuePill.addSubview(continueBackgroundImageView)
        continuePill.addSubview(nextIconImageView)
        continuePill.addSubview(continueTitleLabel)

        installFeatureRows()

        configureNextIcon()
        wireRows()
        installFooterConstraints()
        syncSelectionToServiceAndUI()

        let continueTap = UITapGestureRecognizer(target: self, action: #selector(continueTapped))
        continuePill.addGestureRecognizer(continueTap)
        continuePill.isAccessibilityElement = true
        continuePill.accessibilityTraits = .button
        continuePill.accessibilityLabel = continueTitleLabel.text

        ensureTopBarButtonImageScaling()

        fetchProducts()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        closeButton.imageView?.contentMode = .scaleAspectFit
        infoButton.imageView?.contentMode = .scaleAspectFit
    }

    private func ensureTopBarButtonImageScaling() {
        Self.applyTopBarButtonImageScaling(closeButton)
        Self.applyTopBarButtonImageScaling(infoButton)
    }

    private func installFooterConstraints() {
        weeklyRow.translatesAutoresizingMaskIntoConstraints = false
        yearlyRow.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Metrics.closeTop),
            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Metrics.topBarHorizontalInset),
            closeButton.widthAnchor.constraint(equalToConstant: Metrics.topBarButtonSide),
            closeButton.heightAnchor.constraint(equalToConstant: Metrics.topBarButtonSide),

            infoButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Metrics.closeTop),
            infoButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -Metrics.topBarHorizontalInset),
            infoButton.widthAnchor.constraint(equalTo: closeButton.widthAnchor),
            infoButton.heightAnchor.constraint(equalTo: closeButton.heightAnchor),

            titleLabel.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: Metrics.titleTopBelowClose),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metrics.titleLeading),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: infoButton.leadingAnchor, constant: -12),

            featuresColumn.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Metrics.featuresTopBelowTitle),
            featuresColumn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metrics.featureRowLeading),
            featuresColumn.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -Metrics.horizontalInset),

            worldImageView.topAnchor.constraint(equalTo: featuresColumn.bottomAnchor, constant: Metrics.featuresToWorldSpacing),
            worldImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            worldImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            worldImageView.bottomAnchor.constraint(equalTo: paywallFooter.topAnchor, constant: -Metrics.worldToFooterSpacing),

            paywallFooter.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metrics.horizontalInset),
            paywallFooter.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Metrics.horizontalInset),
            paywallFooter.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Metrics.bottomInset),

            weeklyRow.topAnchor.constraint(equalTo: paywallFooter.topAnchor),
            weeklyRow.leadingAnchor.constraint(equalTo: paywallFooter.leadingAnchor),
            weeklyRow.trailingAnchor.constraint(equalTo: paywallFooter.trailingAnchor),
            weeklyRow.heightAnchor.constraint(equalToConstant: Metrics.rowHeight),

            yearlyRow.topAnchor.constraint(equalTo: weeklyRow.bottomAnchor, constant: Metrics.weeklyToYearlySpacing),
            yearlyRow.leadingAnchor.constraint(equalTo: paywallFooter.leadingAnchor),
            yearlyRow.trailingAnchor.constraint(equalTo: paywallFooter.trailingAnchor),
            yearlyRow.heightAnchor.constraint(equalToConstant: Metrics.rowHeight),

            continueShadowContainer.topAnchor.constraint(equalTo: yearlyRow.bottomAnchor, constant: Metrics.yearlyToContinueSpacing),
            continueShadowContainer.leadingAnchor.constraint(equalTo: paywallFooter.leadingAnchor),
            continueShadowContainer.trailingAnchor.constraint(equalTo: paywallFooter.trailingAnchor),
            continueShadowContainer.bottomAnchor.constraint(equalTo: paywallFooter.bottomAnchor),
            continueShadowContainer.heightAnchor.constraint(equalToConstant: Metrics.rowHeight),

            continuePill.topAnchor.constraint(equalTo: continueShadowContainer.topAnchor),
            continuePill.leadingAnchor.constraint(equalTo: continueShadowContainer.leadingAnchor),
            continuePill.trailingAnchor.constraint(equalTo: continueShadowContainer.trailingAnchor),
            continuePill.bottomAnchor.constraint(equalTo: continueShadowContainer.bottomAnchor),

            continueBackgroundImageView.topAnchor.constraint(equalTo: continuePill.topAnchor),
            continueBackgroundImageView.leadingAnchor.constraint(equalTo: continuePill.leadingAnchor),
            continueBackgroundImageView.trailingAnchor.constraint(equalTo: continuePill.trailingAnchor),
            continueBackgroundImageView.bottomAnchor.constraint(equalTo: continuePill.bottomAnchor),

            nextIconImageView.leadingAnchor.constraint(equalTo: continuePill.leadingAnchor, constant: Metrics.continueNextIconLeading),
            nextIconImageView.centerYAnchor.constraint(equalTo: continuePill.centerYAnchor),
            nextIconImageView.widthAnchor.constraint(equalToConstant: Metrics.continueNextIconWidth),
            nextIconImageView.heightAnchor.constraint(equalToConstant: Metrics.continueNextIconHeight),

            continueTitleLabel.centerXAnchor.constraint(equalTo: continuePill.centerXAnchor),
            continueTitleLabel.centerYAnchor.constraint(equalTo: continuePill.centerYAnchor),
            continueTitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: nextIconImageView.trailingAnchor, constant: 12),
        ])
    }

    private func installFeatureRows() {
        let lines = [
            NSLocalizedString("No Ads", comment: "Paywall feature"),
            NSLocalizedString("Track Unlimited Packages", comment: "Paywall feature"),
            NSLocalizedString("Get Real-Time Notifications", comment: "Paywall feature"),
            NSLocalizedString("Supports 3000+ Carriers", comment: "Paywall feature"),
        ]
        var previousRow: UIView?
        for text in lines {
            let row = makeFeatureRow(text: text)
            featuresColumn.addSubview(row)
            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: featuresColumn.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: featuresColumn.trailingAnchor),
            ])
            if let prev = previousRow {
                row.topAnchor.constraint(equalTo: prev.bottomAnchor, constant: Metrics.featureRowSpacing).isActive = true
            } else {
                row.topAnchor.constraint(equalTo: featuresColumn.topAnchor).isActive = true
            }
            previousRow = row
        }
        if let last = previousRow {
            last.bottomAnchor.constraint(equalTo: featuresColumn.bottomAnchor).isActive = true
        }
    }

    private func configureNextIcon() {
        if let custom = UIImage(named: "next_icon") {
            nextIconImageView.image = custom
        } else {
            let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
            let fallback = UIImage(systemName: "arrow.right", withConfiguration: configuration)?
                .withTintColor(.white, renderingMode: .alwaysOriginal)
            nextIconImageView.image = fallback
        }
    }

    private func wireRows() {
        weeklyRow.onTap = { [weak self] in
            self?.selectedProduct = .weekly
        }
        yearlyRow.onTap = { [weak self] in
            self?.selectedProduct = .yearly
        }
    }

    private func syncSelectionToServiceAndUI() {
        let iap = IapService.sharedInstance
        switch selectedProduct {
        case .weekly:
            iap.selectedRCProduct = iap.weeklyProduct
        case .yearly:
            iap.selectedRCProduct = iap.yearlyProduct
        }
        weeklyRow.applySelectionState(isSelected: selectedProduct == .weekly)
        yearlyRow.applySelectionState(isSelected: selectedProduct == .yearly)
    }

    private func fetchProducts() {
        IapService.sharedInstance.getProducts { [weak self] success, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                let iap = IapService.sharedInstance
                self.weeklyRow.applyProductData(iap.weeklyProduct)
                self.yearlyRow.applyProductData(iap.yearlyProduct)
                self.syncSelectionToServiceAndUI()
                if !success {
                    // Keep UI usable; purchase will fail until offerings load — avoids blocking dismiss via close.
                }
            }
        }
    }

    @objc private func closeTapped() {
        HapticFeedback.light.play()
        finishPaywallInteraction()
    }

    private func finishPaywallInteraction() {
        switch presentationStyle {
        case .sessionGate:
            transitionWindowRootToMainTabs()
        case .modal:
            let handler = onModalDismiss
            onModalDismiss = nil
            dismiss(animated: true) {
                handler?()
            }
        }
    }

    private func transitionWindowRootToMainTabs() {
        guard let window = view.window else { return }
        UIView.transition(with: window, duration: 0.28, options: .transitionCrossDissolve) {
            window.rootViewController = MainTabBarController()
        }
    }

    private func paywallInfoMenu() -> UIMenu {
        UIMenu(children: [
            UIAction(title: NSLocalizedString("Terms", comment: "Paywall legal")) { [weak self] _ in
                HapticFeedback.selection.play()
                self?.presentInAppWeb(url: AppLinks.terms)
            },
            UIAction(title: NSLocalizedString("Privacy", comment: "Paywall legal")) { [weak self] _ in
                HapticFeedback.selection.play()
                self?.presentInAppWeb(url: AppLinks.privacy)
            },
            UIAction(title: NSLocalizedString("Restore", comment: "Paywall restore purchases")) { [weak self] _ in
                self?.paywallRestoreTapped()
            },
        ])
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

    private func paywallRestoreTapped() {
        HapticFeedback.light.play()
        beginPaywallRestoreOverlay()
        IapService.sharedInstance.restorePurchase { [weak self] success, error in
            DispatchQueue.main.async {
                self?.endPaywallRestoreOverlay()
                guard let self else { return }
                if success {
                    let alert = UIAlertController(
                        title: NSLocalizedString("Purchases Restored", comment: "Restore success title"),
                        message: NSLocalizedString("Your subscription is active again.", comment: "Restore success message"),
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { [weak self] _ in
                        self?.finishPaywallInteraction()
                    })
                    self.present(alert, animated: true)
                    return
                }
                if let error {
                    let alert = UIAlertController(
                        title: NSLocalizedString("Restore Failed", comment: "Restore error title"),
                        message: error.localizedDescription,
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
                    self.present(alert, animated: true)
                    return
                }
                let alert = UIAlertController(
                    title: NSLocalizedString("Nothing to Restore", comment: "Restore empty title"),
                    message: NSLocalizedString(
                        "We could not find an active subscription for this Apple ID.",
                        comment: "Restore empty message"
                    ),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    private func beginPaywallRestoreOverlay() {
        guard restoreLoadingOverlay == nil else { return }
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.25)
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
            spinner.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
        ])
        restoreLoadingOverlay = overlay
    }

    private func endPaywallRestoreOverlay() {
        restoreLoadingOverlay?.removeFromSuperview()
        restoreLoadingOverlay = nil
    }

    @objc private func continueTapped() {
        guard !isPurchasing else { return }
        guard IapService.sharedInstance.selectedRCProduct != nil else { return }
        isPurchasing = true
        HapticFeedback.medium.play()
        IapService.sharedInstance.startPurchase { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isPurchasing = false
                if success {
                    self.finishPaywallInteraction()
                } else if let error {
                    let alert = UIAlertController(
                        title: nil,
                        message: error.localizedDescription,
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    private func makeFeatureRow(text: String) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(named: "paywall_option_icon"))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.contentMode = .scaleAspectFit

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = Typography.poppins(.semiBold, size: 12)
        label.textColor = UIColor.white
        label.numberOfLines = 0
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)

        row.addSubview(icon)
        row.addSubview(label)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            icon.topAnchor.constraint(equalTo: label.topAnchor),
            icon.widthAnchor.constraint(equalToConstant: Metrics.featureIconSize),
            icon.heightAnchor.constraint(equalToConstant: Metrics.featureIconSize),

            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: Metrics.featureIconToLabelSpacing),
            label.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            label.topAnchor.constraint(equalTo: row.topAnchor),
            label.bottomAnchor.constraint(equalTo: row.bottomAnchor),
        ])
        row.setContentHuggingPriority(.required, for: .vertical)
        row.setContentCompressionResistancePriority(.required, for: .vertical)
        return row
    }
}

// MARK: - Plan row

private extension PaywallViewController {
    final class PlanRow: UIView {
        enum Kind {
            case weekly
            case yearly
        }

        private let kind: Kind

        private let rowBackgroundImageView: UIImageView = {
            let imageView = UIImageView(image: UIImage(named: "paywall_selected_image"))
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = Metrics.cornerRadius
            imageView.isUserInteractionEnabled = false
            return imageView
        }()

        private let kingImageView = UIImageView()
        private let titleLabel = UILabel()
        private let subtitleLabel = UILabel()
        private let priceLabel = UILabel()
        private let periodLabel = UILabel()

        private let textStack: UIStackView = {
            let stack = UIStackView()
            stack.axis = .vertical
            stack.alignment = .leading
            stack.spacing = 2
            stack.translatesAutoresizingMaskIntoConstraints = false
            return stack
        }()

        private let priceStack: UIStackView = {
            let stack = UIStackView()
            stack.axis = .vertical
            stack.alignment = .trailing
            stack.spacing = 0
            stack.translatesAutoresizingMaskIntoConstraints = false
            return stack
        }()

        private let badgeBackground = UIView()
        private let badgeLabel = UILabel()

        /// Mirrors `applySelectionState` so repeated taps on the active row don’t buzz.
        private var showsSelectedAppearance = false

        var onTap: (() -> Void)?

        init(kind: Kind) {
            self.kind = kind
            super.init(frame: .zero)
            translatesAutoresizingMaskIntoConstraints = false
            layer.cornerRadius = Metrics.cornerRadius
            clipsToBounds = kind == .weekly

            kingImageView.translatesAutoresizingMaskIntoConstraints = false
            kingImageView.contentMode = .scaleAspectFit

            addSubview(rowBackgroundImageView)
            titleLabel.font = Typography.poppins(.medium, size: 20)
            subtitleLabel.font = Typography.poppins(.medium, size: 10)
            priceLabel.font = Typography.poppins(.semiBold, size: 18)
            periodLabel.font = Typography.poppins(.medium, size: 10)

            addSubview(kingImageView)
            addSubview(textStack)
            addSubview(priceStack)
            textStack.addArrangedSubview(titleLabel)
            textStack.addArrangedSubview(subtitleLabel)
            priceStack.addArrangedSubview(priceLabel)
            priceStack.addArrangedSubview(periodLabel)

            switch kind {
            case .weekly:
                titleLabel.text = NSLocalizedString("Weekly", comment: "Paywall plan title")
            case .yearly:
                titleLabel.text = NSLocalizedString("Yearly", comment: "Paywall plan title")
                badgeBackground.translatesAutoresizingMaskIntoConstraints = false
                badgeBackground.backgroundColor = Metrics.selectedForeground
                badgeBackground.layer.cornerRadius = Metrics.badgeHeight / 2
                badgeBackground.clipsToBounds = true
                badgeLabel.translatesAutoresizingMaskIntoConstraints = false
                badgeLabel.text = NSLocalizedString("Most Popular", comment: "Paywall yearly badge")
                badgeLabel.font = Typography.poppins(.semiBold, size: 11)
                badgeLabel.textColor = .white
                badgeLabel.textAlignment = .center
                badgeBackground.addSubview(badgeLabel)
                addSubview(badgeBackground)

                NSLayoutConstraint.activate([
                    badgeBackground.widthAnchor.constraint(equalToConstant: Metrics.badgeWidth),
                    badgeBackground.heightAnchor.constraint(equalToConstant: Metrics.badgeHeight),
                    badgeBackground.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
                    badgeBackground.bottomAnchor.constraint(equalTo: topAnchor, constant: 10),
                    badgeLabel.centerXAnchor.constraint(equalTo: badgeBackground.centerXAnchor),
                    badgeLabel.centerYAnchor.constraint(equalTo: badgeBackground.centerYAnchor),
                ])
            }

            NSLayoutConstraint.activate([
                rowBackgroundImageView.topAnchor.constraint(equalTo: topAnchor),
                rowBackgroundImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
                rowBackgroundImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
                rowBackgroundImageView.bottomAnchor.constraint(equalTo: bottomAnchor),

                kingImageView.topAnchor.constraint(equalTo: topAnchor, constant: Metrics.kingTop),
                kingImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metrics.kingLeading),
                kingImageView.widthAnchor.constraint(equalToConstant: Metrics.kingWidth),
                kingImageView.heightAnchor.constraint(equalToConstant: Metrics.kingHeight),

                textStack.leadingAnchor.constraint(equalTo: kingImageView.trailingAnchor, constant: 10),
                textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
                textStack.trailingAnchor.constraint(lessThanOrEqualTo: priceStack.leadingAnchor, constant: -8),

                priceStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                priceStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            addGestureRecognizer(tap)
            isUserInteractionEnabled = true
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func applyProductData(_ product: StoreProduct?) {
            switch kind {
            case .weekly:
                if let product {
                    subtitleLabel.text = String(
                        format: NSLocalizedString("Just %@ per week", comment: "Paywall weekly description"),
                        product.localizedPriceString
                    )
                    priceLabel.text = product.localizedPriceString
                    periodLabel.text = NSLocalizedString("per week", comment: "Paywall period")
                } else {
                    subtitleLabel.text = "—"
                    priceLabel.text = "—"
                    periodLabel.text = NSLocalizedString("per week", comment: "Paywall period")
                }
            case .yearly:
                if let product {
                    subtitleLabel.text = String(
                        format: NSLocalizedString("Just %@ per year", comment: "Paywall yearly description"),
                        product.localizedPriceString
                    )
                    priceLabel.text = product.localizedPriceString
                    periodLabel.text = NSLocalizedString("per year", comment: "Paywall period")
                } else {
                    subtitleLabel.text = "—"
                    priceLabel.text = "—"
                    periodLabel.text = NSLocalizedString("per year", comment: "Paywall period")
                }
            }
        }

        func applySelectionState(isSelected: Bool) {
            showsSelectedAppearance = isSelected
            if isSelected {
                backgroundColor = .white
                rowBackgroundImageView.isHidden = true
                let c = Metrics.selectedForeground
                titleLabel.textColor = c
                subtitleLabel.textColor = c
                priceLabel.textColor = c
                periodLabel.textColor = c
                kingImageView.image = UIImage(named: "selected_king")
            } else {
                backgroundColor = .clear
                rowBackgroundImageView.isHidden = false
                titleLabel.textColor = .white
                subtitleLabel.textColor = .white
                priceLabel.textColor = .white
                periodLabel.textColor = .white
                kingImageView.image = UIImage(named: "unselected_king")
            }
        }

        @objc private func handleTap() {
            if !showsSelectedAppearance {
                HapticFeedback.selection.play()
            } else {
                HapticFeedback.soft.play()
            }
            onTap?()
        }
    }
}
