import UIKit

final class PackageDetailViewController: UIViewController {

    private var package: Package
    private var events: [TrackingEvent] = []

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let trackingNumberLabel = UILabel()
    private let copyButton = UIButton(type: .system)
    private let statusBadge = PaddedLabel()
    private let stepperView = TrackingStepperView()
    private let carrierIconView = UIImageView()
    private let carrierNameLabel = UILabel()
    private let lastUpdateValueLabel = UILabel()
    private let carrierValueLabel = UILabel()
    private let timelineStack = UIStackView()

    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    init(package: Package) {
        self.package = package
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background
        navigationItem.title = package.displayName
        navigationItem.largeTitleDisplayMode = .never
        configureNavBar()
        buildLayout()
        populateUI()
        events = package.checkpoints
        rebuildTimeline()
        loadLatestStatus()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateScrollContentInsets()
    }

    // MARK: - Navigation Bar

    private func configureNavBar() {
        let moreButton = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: self,
            action: #selector(moreTapped)
        )
        navigationItem.rightBarButtonItem = moreButton
    }

    // MARK: - Layout

    private func buildLayout() {
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .onDrag
        view.addSubview(scrollView)
        scrollView.pinToSuperview()

        contentStack.axis = .vertical
        contentStack.spacing = 0
        scrollView.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        contentStack.addArrangedSubview(buildTrackingCard())
        contentStack.addArrangedSubview(buildStepperSection())
        contentStack.addArrangedSubview(buildCarrierCard())
        contentStack.addArrangedSubview(buildInfoCard())
        contentStack.addArrangedSubview(buildTimelineSection())
        contentStack.addArrangedSubview(buildActionsSection())

        contentStack.setCustomSpacing(16, after: contentStack.arrangedSubviews[0])
        contentStack.setCustomSpacing(16, after: contentStack.arrangedSubviews[1])
        contentStack.setCustomSpacing(12, after: contentStack.arrangedSubviews[2])
        contentStack.setCustomSpacing(16, after: contentStack.arrangedSubviews[3])
        contentStack.setCustomSpacing(20, after: contentStack.arrangedSubviews[4])
    }

    private func updateScrollContentInsets() {
        let safe = view.safeAreaInsets
        let inset = UIEdgeInsets(
            top: safe.top + Layout.detailExtraTopInset,
            left: safe.left,
            bottom: safe.bottom,
            right: safe.right
        )
        scrollView.contentInset = inset
        scrollView.verticalScrollIndicatorInsets = inset
    }

    // MARK: - Tracking Number Card

    private func buildTrackingCard() -> UIView {
        let card = makeCard()

        let header = UILabel()
        header.text = "TRACKING NUMBER"
        header.font = .systemFont(ofSize: 12, weight: .bold)
        header.textColor = AppTheme.textSecondary

        trackingNumberLabel.font = .monospacedSystemFont(ofSize: 18, weight: .semibold)
        trackingNumberLabel.textColor = AppTheme.textPrimary

        copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copyButton.tintColor = AppTheme.textSecondary
        copyButton.addTarget(self, action: #selector(copyTrackingNumber), for: .touchUpInside)

        let numberRow = UIStackView(arrangedSubviews: [trackingNumberLabel, copyButton])
        numberRow.axis = .horizontal
        numberRow.spacing = 8
        numberRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [header, numberRow])
        stack.axis = .vertical
        stack.spacing = 8

        card.addSubview(stack)
        stack.anchor(
            top: card.topAnchor, leading: card.leadingAnchor,
            bottom: card.bottomAnchor, trailing: card.trailingAnchor,
            padding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        )

        return wrapInPadding(card)
    }

    // MARK: - Stepper Section

    private func buildStepperSection() -> UIView {
        let card = makeCard()

        card.addSubview(stepperView)
        stepperView.anchor(
            top: card.topAnchor, leading: card.leadingAnchor,
            bottom: card.bottomAnchor, trailing: card.trailingAnchor,
            padding: UIEdgeInsets(top: 20, left: 8, bottom: 20, right: 8)
        )

        return wrapInPadding(card)
    }

    // MARK: - Carrier Card

    private func buildCarrierCard() -> UIView {
        let card = makeCard()

        carrierIconView.contentMode = .scaleAspectFit
        carrierIconView.clipsToBounds = true
        carrierIconView.layer.cornerRadius = 8
        carrierIconView.backgroundColor = AppTheme.tertiaryBackground
        carrierIconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            carrierIconView.widthAnchor.constraint(equalToConstant: 40),
            carrierIconView.heightAnchor.constraint(equalToConstant: 40)
        ])

        carrierNameLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        carrierNameLabel.textColor = AppTheme.textPrimary

        let textStack = UIStackView(arrangedSubviews: [carrierNameLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [carrierIconView, textStack])
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center

        card.addSubview(row)
        row.anchor(
            top: card.topAnchor, leading: card.leadingAnchor,
            bottom: card.bottomAnchor, trailing: card.trailingAnchor,
            padding: UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        )

        return wrapInPadding(card)
    }

    // MARK: - Info Card (last update, carrier name)

    private func buildInfoCard() -> UIView {
        let card = makeCard()

        let updateRow = makeInfoRow(title: "Last update", valueLabel: lastUpdateValueLabel)
        let carrierRow = makeInfoRow(title: "Carrier", valueLabel: carrierValueLabel)

        let divider = UIView()
        divider.backgroundColor = AppTheme.separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true

        let stack = UIStackView(arrangedSubviews: [updateRow, divider, carrierRow])
        stack.axis = .vertical
        stack.spacing = 12

        card.addSubview(stack)
        stack.anchor(
            top: card.topAnchor, leading: card.leadingAnchor,
            bottom: card.bottomAnchor, trailing: card.trailingAnchor,
            padding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        )

        return wrapInPadding(card)
    }

    private func makeInfoRow(title: String, valueLabel: UILabel) -> UIStackView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = AppTheme.textSecondary

        valueLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        valueLabel.textColor = AppTheme.textPrimary
        valueLabel.textAlignment = .right
        valueLabel.numberOfLines = 2

        let row = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        row.axis = .horizontal
        row.spacing = 8
        return row
    }

    // MARK: - Timeline Section

    private func buildTimelineSection() -> UIView {
        let container = UIView()

        let header = UILabel()
        header.text = "TRACKING HISTORY"
        header.font = .systemFont(ofSize: 12, weight: .bold)
        header.textColor = AppTheme.textSecondary

        timelineStack.axis = .vertical
        timelineStack.spacing = 0

        activityIndicator.color = AppTheme.textSecondary
        activityIndicator.hidesWhenStopped = true
        activityIndicator.startAnimating()

        let vStack = UIStackView(arrangedSubviews: [header, activityIndicator, timelineStack])
        vStack.axis = .vertical
        vStack.spacing = 12

        container.addSubview(vStack)
        vStack.anchor(
            top: container.topAnchor, leading: container.leadingAnchor,
            bottom: container.bottomAnchor, trailing: container.trailingAnchor,
            padding: UIEdgeInsets(top: 0, left: Layout.screenPadding, bottom: 0, right: Layout.screenPadding)
        )

        return container
    }

    // MARK: - Actions Section

    private func buildActionsSection() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0

        stack.addArrangedSubview(makeActionButton(
            title: "Mark as delivered",
            icon: "checkmark.circle",
            color: AppTheme.delivered,
            action: #selector(markDeliveredTapped)
        ))
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(makeActionButton(
            title: "Change carrier",
            icon: "arrow.triangle.2.circlepath",
            color: AppTheme.textPrimary,
            action: #selector(changeCarrierTapped)
        ))
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(makeActionButton(
            title: "Delete package",
            icon: "trash",
            color: AppTheme.exception,
            action: #selector(deletePackageTapped)
        ))

        let wrapper = UIView()
        wrapper.addSubview(stack)
        stack.anchor(
            top: wrapper.topAnchor, leading: wrapper.leadingAnchor,
            bottom: wrapper.bottomAnchor, trailing: wrapper.trailingAnchor,
            padding: UIEdgeInsets(top: 0, left: Layout.screenPadding, bottom: 32, right: Layout.screenPadding)
        )

        return wrapper
    }

    private func makeActionButton(title: String, icon: String, color: UIColor, action: Selector) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.image = UIImage(systemName: icon)
        config.imagePadding = 10
        config.baseForegroundColor = color
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attrs = incoming
            attrs.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            return attrs
        }

        let button = UIButton(configuration: config)
        button.contentHorizontalAlignment = .center
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func makeSeparator() -> UIView {
        let line = UIView()
        line.backgroundColor = AppTheme.separator
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }

    // MARK: - Helpers

    private func makeCard() -> UIView {
        let card = UIView()
        card.backgroundColor = AppTheme.secondaryBackground
        card.layer.cornerRadius = Layout.cardCornerRadius
        return card
    }

    private func wrapInPadding(_ view: UIView) -> UIView {
        let wrapper = UIView()
        wrapper.addSubview(view)
        view.anchor(
            top: wrapper.topAnchor, leading: wrapper.leadingAnchor,
            bottom: wrapper.bottomAnchor, trailing: wrapper.trailingAnchor,
            padding: UIEdgeInsets(top: 0, left: Layout.screenPadding, bottom: 0, right: Layout.screenPadding)
        )
        return wrapper
    }

    // MARK: - Populate

    private func populateUI() {
        navigationItem.title = package.displayName
        trackingNumberLabel.text = package.trackingNumber
        applyStatus(package.status)
        stepperView.setActiveStep(package.status)

        let carrierName = package.carrierName ?? "Unknown Carrier"
        carrierNameLabel.text = carrierName
        carrierValueLabel.text = carrierName

        let placeholder = UIImage(systemName: "shippingbox.fill")?.withTintColor(AppTheme.textSecondary, renderingMode: .alwaysOriginal)
        if let slug = package.carrierSlug {
            let carrier = CarrierDataService.shared.allCarriers.first { "\($0.code)" == slug }
            FaviconLoader.shared.loadFavicon(for: carrier?.url, into: carrierIconView, placeholder: placeholder)
        } else {
            carrierIconView.image = placeholder
        }

        lastUpdateValueLabel.text = package.lastUpdate ?? "Waiting for update"
    }

    private func applyStatus(_ status: PackageStatus) {
        statusBadge.text = status.badgeText
        statusBadge.textColor = status.color
        statusBadge.backgroundColor = status.color.withAlphaComponent(0.15)
    }

    private func rebuildTimeline() {
        timelineStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if events.isEmpty {
            let empty = UILabel()
            empty.text = "No tracking updates yet."
            empty.font = .systemFont(ofSize: 15, weight: .medium)
            empty.textColor = AppTheme.textSecondary
            empty.textAlignment = .center
            timelineStack.addArrangedSubview(empty)
            return
        }

        for (i, event) in events.enumerated() {
            let row = TrackingEventCell()
            row.configure(with: event, isLast: i == events.count - 1)
            timelineStack.addArrangedSubview(row)
        }
    }

    // MARK: - Network

    private func loadLatestStatus() {
        Task { @MainActor in
            defer { activityIndicator.stopAnimating() }

            do {
                let payload = try await APIService.shared.getTrackingStatus(for: package)
                events = payload.checkpoints
                if events.isEmpty {
                    events = package.checkpoints
                }
                applyStatus(payload.status)
                stepperView.setActiveStep(payload.status)
                carrierNameLabel.text = payload.carrierName
                carrierValueLabel.text = payload.carrierName
                lastUpdateValueLabel.text = payload.lastUpdate
                PackageStore.shared.syncWithPayload(id: package.id, payload: payload)
                if let fresh = PackageStore.shared.packages.first(where: { $0.id == package.id }) {
                    package = fresh
                    title = package.displayName
                }
                rebuildTimeline()
            } catch {
                events = package.checkpoints
                rebuildTimeline()
            }
        }
    }

    // MARK: - Actions

    @objc private func copyTrackingNumber() {
        UIPasteboard.general.string = package.trackingNumber
        HapticFeedback.notification(.success).play()

        let original = copyButton.tintColor
        copyButton.tintColor = AppTheme.delivered
        copyButton.setImage(UIImage(systemName: "checkmark"), for: .normal)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.copyButton.tintColor = original
            self?.copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        }
    }

    @objc private func moreTapped() {
        HapticFeedback.light.play()
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Mark as delivered", style: .default) { [weak self] _ in
            self?.markDeliveredTapped()
        })
        alert.addAction(UIAlertAction(title: "Change carrier", style: .default) { [weak self] _ in
            self?.changeCarrierTapped()
        })
        alert.addAction(UIAlertAction(title: "Delete package", style: .destructive) { [weak self] _ in
            self?.deletePackageTapped()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func markDeliveredTapped() {
        let previousStatus = package.status
        let previousLastUpdate = package.lastUpdate
        HapticFeedback.notification(.success).play()
        PackageStore.shared.update(id: package.id, status: .delivered, lastUpdate: "Manually marked as delivered")
        package.status = .delivered
        package.lastUpdate = "Manually marked as delivered"
        applyStatus(.delivered)
        stepperView.setActiveStep(.delivered)
        lastUpdateValueLabel.text = package.lastUpdate

        Task { @MainActor in
            do {
                let payload = try await APIService.shared.markTrackingDelivered(for: package)
                PackageStore.shared.syncWithPayload(id: package.id, payload: payload)
                if let fresh = PackageStore.shared.packages.first(where: { $0.id == package.id }) {
                    package = fresh
                }
                populateUI()
            } catch {
                PackageStore.shared.update(
                    id: package.id,
                    status: previousStatus,
                    lastUpdate: previousLastUpdate ?? previousStatus.summaryText
                )
                package.status = previousStatus
                package.lastUpdate = previousLastUpdate
                populateUI()
                let alert = UIAlertController(
                    title: "Unable to mark delivered",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
    }

    @objc private func changeCarrierTapped() {
        HapticFeedback.light.play()
        let vc = CarrierSelectionViewController(selectedCarrier: nil)
        vc.delegate = self
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }

    @objc private func deletePackageTapped() {
        HapticFeedback.rigid.play()
        let alert = UIAlertController(
            title: "Delete Package",
            message: "Are you sure you want to remove this package from tracking?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self else { return }
            HapticFeedback.notification(.error).play()
            PackageStore.shared.delete(id: self.package.id)
            Task {
                try? await APIService.shared.stopTracking(for: self.package)
            }
            self.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }
}

// MARK: - Carrier Selection Delegate

extension PackageDetailViewController: CarrierSelectionViewControllerDelegate {
    func carrierSelectionViewController(_ controller: CarrierSelectionViewController, didSelect carrier: Carrier) {
        package.carrierSlug = "\(carrier.code)"
        package.carrierName = carrier.name

        carrierNameLabel.text = carrier.name
        carrierValueLabel.text = carrier.name

        let placeholder = UIImage(systemName: "shippingbox.fill")?.withTintColor(AppTheme.textSecondary, renderingMode: .alwaysOriginal)
        FaviconLoader.shared.loadFavicon(for: carrier.url, into: carrierIconView, placeholder: placeholder)

        PackageStore.shared.updateCarrier(id: package.id, carrierCode: carrier.code, carrierName: carrier.name)

        controller.dismiss(animated: true)

        Task { @MainActor in
            activityIndicator.startAnimating()
            defer { activityIndicator.stopAnimating() }

            do {
                let payload = try await APIService.shared.updateTrackingCarrier(for: package, carrier: carrier)
                PackageStore.shared.syncWithPayload(
                    id: package.id,
                    payload: payload,
                    preserveExistingCheckpointsWhenPayloadIsEmpty: false
                )
                if let fresh = PackageStore.shared.packages.first(where: { $0.id == package.id }) {
                    package = fresh
                }
                events = package.checkpoints
                populateUI()
                rebuildTimeline()
            } catch {
                let alert = UIAlertController(
                    title: "Unable to update carrier",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
    }
}

// MARK: - PaddedLabel

private final class PaddedLabel: UILabel {
    var insets = UIEdgeInsets.zero

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + insets.left + insets.right,
            height: size.height + insets.top + insets.bottom
        )
    }
}
