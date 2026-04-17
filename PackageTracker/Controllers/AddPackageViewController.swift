import UIKit

final class AddPackageViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let trackingField = UITextField()
    private let titleField = UITextField()
    private let carrierButton = UIButton(type: .system)
    private let carrierHintLabel = UILabel()
    private let addButton = UIButton(type: .system)

    private var selectedCarrier: Carrier? {
        didSet { updateCarrierButton() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        updateAddButtonState()
    }

    private func configureUI() {
        title = "Add Package"
        view.backgroundColor = AppTheme.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(closeTapped)
        )

        view.addSubview(scrollView)
        scrollView.pinToSuperview()
        scrollView.keyboardDismissMode = .onDrag
        scrollView.addSubview(contentView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        let trackingLabel = sectionLabel("Tracking Number")
        configureTextField(trackingField, placeholder: "Enter or paste tracking number")
        trackingField.autocapitalizationType = .allCharacters
        trackingField.addTarget(self, action: #selector(textDidChange), for: .editingChanged)

        let nameLabel = sectionLabel("Package Name (optional)")
        configureTextField(titleField, placeholder: "e.g. New headphones")

        let carrierLabel = sectionLabel("Carrier")

        var carrierConfig = UIButton.Configuration.filled()
        carrierConfig.baseBackgroundColor = AppTheme.secondaryBackground
        carrierConfig.baseForegroundColor = AppTheme.textSecondary
        carrierConfig.cornerStyle = .medium
        carrierConfig.contentInsets = NSDirectionalEdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
        carrierConfig.title = "Select carrier"
        carrierConfig.image = UIImage(systemName: "chevron.down")
        carrierConfig.imagePlacement = .trailing
        carrierConfig.imagePadding = 8
        carrierConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        carrierConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attrs = incoming
            attrs.font = UIFont.systemFont(ofSize: 17, weight: .medium)
            return attrs
        }
        carrierButton.configuration = carrierConfig
        carrierButton.contentHorizontalAlignment = .leading
        carrierButton.addTarget(self, action: #selector(carrierTapped), for: .touchUpInside)

        carrierHintLabel.text = "Select the carrier for accurate tracking results."
        carrierHintLabel.font = .systemFont(ofSize: 13, weight: .medium)
        carrierHintLabel.textColor = AppTheme.textSecondary
        carrierHintLabel.numberOfLines = 0

        addButton.setTitle("Add Package", for: .normal)
        addButton.backgroundColor = AppTheme.accent
        addButton.setTitleColor(.white, for: .normal)
        addButton.layer.cornerRadius = Layout.controlCornerRadius
        addButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)

        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true

        let stack = UIStackView(arrangedSubviews: [
            trackingLabel,
            fieldContainer(for: trackingField),
            nameLabel,
            fieldContainer(for: titleField),
            spacer,
            carrierLabel,
            carrierButton,
            carrierHintLabel,
            addButton
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(6, after: trackingLabel)
        stack.setCustomSpacing(6, after: nameLabel)
        stack.setCustomSpacing(6, after: carrierLabel)
        stack.setCustomSpacing(6, after: carrierHintLabel)
        stack.setCustomSpacing(24, after: carrierHintLabel)

        contentView.addSubview(stack)
        stack.anchor(
            top: contentView.safeAreaLayoutGuide.topAnchor,
            leading: contentView.leadingAnchor,
            bottom: contentView.bottomAnchor,
            trailing: contentView.trailingAnchor,
            padding: UIEdgeInsets(top: 24, left: Layout.screenPadding, bottom: 24, right: Layout.screenPadding)
        )

        addButton.heightAnchor.constraint(equalToConstant: Layout.buttonHeight).isActive = true
        carrierButton.heightAnchor.constraint(equalToConstant: 56).isActive = true
    }

    private func sectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = AppTheme.textSecondary
        return label
    }

    private func configureTextField(_ field: UITextField, placeholder: String) {
        field.placeholder = placeholder
        field.textColor = AppTheme.textPrimary
        field.tintColor = AppTheme.accent
        field.font = .systemFont(ofSize: 17, weight: .medium)
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: AppTheme.textSecondary.withAlphaComponent(0.6)]
        )
    }

    private func fieldContainer(for textField: UITextField) -> UIView {
        let container = UIView()
        container.backgroundColor = AppTheme.secondaryBackground
        container.layer.cornerRadius = Layout.controlCornerRadius

        container.addSubview(textField)
        textField.anchor(
            top: container.topAnchor,
            leading: container.leadingAnchor,
            bottom: container.bottomAnchor,
            trailing: container.trailingAnchor,
            padding: UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        )

        return container
    }

    private func updateCarrierButton() {
        var config = carrierButton.configuration ?? UIButton.Configuration.filled()
        if let carrier = selectedCarrier {
            config.title = carrier.name
            config.baseForegroundColor = AppTheme.textPrimary
            carrierHintLabel.text = "\(carrier.name) selected."
        } else {
            config.title = "Select carrier"
            config.baseForegroundColor = AppTheme.textSecondary
            carrierHintLabel.text = "Select the carrier for accurate tracking results."
        }
        carrierButton.configuration = config
        updateAddButtonState()
    }

    private func updateAddButtonState() {
        let hasNumber = !(trackingField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let isEnabled = hasNumber
        addButton.isEnabled = isEnabled
        addButton.alpha = isEnabled ? 1 : 0.4
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func textDidChange() {
        updateAddButtonState()
    }

    @objc private func carrierTapped() {
        view.endEditing(true)
        let vc = CarrierSelectionViewController(selectedCarrier: selectedCarrier)
        vc.delegate = self
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func addTapped() {
        guard let trackingNumber = trackingField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trackingNumber.isEmpty else { return }

        addButton.isEnabled = false
        addButton.alpha = 0.5

        Task { @MainActor in
            defer {
                addButton.isEnabled = true
                addButton.alpha = 1
            }

            do {
                let payload = try await APIService.shared.registerTracking(
                    number: trackingNumber,
                    title: titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                    carrier: selectedCarrier
                )
                PackageStore.shared.upsert(from: payload)
                dismiss(animated: true)
            } catch {
                let alert = UIAlertController(
                    title: "Unable to add package",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
    }
}

extension AddPackageViewController: CarrierSelectionViewControllerDelegate {
    func carrierSelectionViewController(_ controller: CarrierSelectionViewController, didSelect carrier: Carrier) {
        selectedCarrier = carrier
    }
}
