import UIKit

final class PackageListViewController: UIViewController {
    private let filterBar = StatusFilterBar()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyStateView = EmptyStateView()
    private let addButton = UIButton(type: .system)
    private let refreshControl = UIRefreshControl()
    private let searchBar = UISearchBar()
    private let dismissKeyboardTap = UITapGestureRecognizer()
    private var searchBarHeightConstraint: NSLayoutConstraint!
    private var isSearchBarPresented = false

    private var allPackages: [Package] = []
    private var selectedStatus: PackageStatus = .all
    private var searchQuery: String = ""

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        navigationItem.largeTitleDisplayMode = .always
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        navigationItem.largeTitleDisplayMode = .always
    }

    private var statusFilteredPackages: [Package] {
        let base = allPackages
        guard selectedStatus != .all else { return base }
        return base.filter { $0.status == selectedStatus }
    }

    private var displayedPackages: [Package] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return statusFilteredPackages }
        let needle = trimmed.lowercased()
        return statusFilteredPackages.filter { packageMatchesSearch($0, needle: needle) }
    }

    private func packageMatchesSearch(_ package: Package, needle: String) -> Bool {
        if package.trackingNumber.lowercased().contains(needle) {
            return true
        }
        if let title = package.title, !title.isEmpty, title.lowercased().contains(needle) {
            return true
        }
        if let name = package.carrierName, !name.isEmpty, name.lowercased().contains(needle) {
            return true
        }
        if let slug = package.carrierSlug, !slug.isEmpty, slug.lowercased().contains(needle) {
            return true
        }
        return false
    }

    private func makeStatusFilterCounts() -> [PackageStatus: Int] {
        let base = allPackages
        var map: [PackageStatus: Int] = [:]
        map[.all] = base.count
        for status in PackageStatus.allCases where status != .all && status != .archived {
            map[status] = base.filter { $0.status == status }.count
        }
        return map
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        configureObservers()
        reloadPackages()
        syncFromBackend()
    }

    override func viewWillAppear(_ animated: Bool) {
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        super.viewWillAppear(animated)
        reloadPackages()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureUI() {
        title = "My Packages"
        view.backgroundColor = AppTheme.background

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = AppTheme.background
        navAppearance.titleTextAttributes = [.foregroundColor: AppTheme.textPrimary]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: AppTheme.textPrimary]
        navigationController?.navigationBar.standardAppearance = navAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = navAppearance
        navigationController?.navigationBar.compactAppearance = navAppearance
        navigationController?.navigationBar.compactScrollEdgeAppearance = navAppearance
        navigationController?.navigationBar.tintColor = AppTheme.accent
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        let searchButton = UIBarButtonItem(
            image: UIImage(systemName: "magnifyingglass"),
            style: .plain,
            target: self,
            action: #selector(searchTapped)
        )
        searchButton.accessibilityLabel = "Search packages"
        navigationItem.rightBarButtonItem = searchButton

        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.keyboardAppearance = .light
        searchBar.delegate = self
        searchBar.backgroundImage = UIImage()
        searchBar.searchTextField.backgroundColor = AppTheme.secondaryBackground
        searchBar.searchTextField.textColor = AppTheme.textPrimary
        searchBar.searchTextField.font = .systemFont(ofSize: 16, weight: .regular)
        let placeholderText = "Name, carrier, or tracking number"
        searchBar.searchTextField.attributedPlaceholder = NSAttributedString(
            string: placeholderText,
            attributes: [
                .foregroundColor: AppTheme.textSecondary,
                .font: UIFont.systemFont(ofSize: 13, weight: .medium)
            ]
        )
        searchBar.tintColor = AppTheme.accent
        searchBar.isHidden = true
        searchBar.alpha = 0

        filterBar.onSelectionChanged = { [weak self] status in
            self?.selectedStatus = status
            self?.updateUI()
        }

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.register(PackageCell.self, forCellReuseIdentifier: PackageCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)

        addButton.backgroundColor = AppTheme.accent
        addButton.tintColor = .white
        addButton.layer.cornerRadius = 30
        addButton.setImage(UIImage(systemName: "plus"), for: .normal)
        addButton.addTarget(self, action: #selector(addPackageTapped), for: .touchUpInside)

        dismissKeyboardTap.addTarget(self, action: #selector(backgroundTappedToDismissKeyboard))
        dismissKeyboardTap.cancelsTouchesInView = false
        dismissKeyboardTap.delegate = self
        view.addGestureRecognizer(dismissKeyboardTap)

        view.addSubview(filterBar)
        view.addSubview(searchBar)
        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        view.addSubview(addButton)

        let safeArea = view.safeAreaLayoutGuide
        filterBar.anchor(
            top: safeArea.topAnchor,
            leading: view.leadingAnchor,
            trailing: view.trailingAnchor,
            padding: UIEdgeInsets(top: 12, left: Layout.screenPadding, bottom: 0, right: Layout.screenPadding),
            size: CGSize(width: .zero, height: 36)
        )

        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBarHeightConstraint = searchBar.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: filterBar.bottomAnchor, constant: 6),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Layout.screenPadding - 4),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -(Layout.screenPadding - 4)),
            searchBarHeightConstraint
        ])

        tableView.anchor(top: searchBar.bottomAnchor, leading: view.leadingAnchor, bottom: view.bottomAnchor, trailing: view.trailingAnchor, padding: UIEdgeInsets(top: 16, left: 0, bottom: 0, right: 0))
        emptyStateView.anchor(top: searchBar.bottomAnchor, leading: view.leadingAnchor, bottom: view.bottomAnchor, trailing: view.trailingAnchor, padding: UIEdgeInsets(top: 16, left: 0, bottom: 0, right: 0))
        addButton.anchor(bottom: safeArea.bottomAnchor, trailing: view.trailingAnchor, padding: UIEdgeInsets(top: 0, left: 0, bottom: 20, right: Layout.screenPadding), size: CGSize(width: 60, height: 60))
    }

    private func configureObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(reloadPackages), name: .packageStoreDidChange, object: nil)
    }

    @objc private func reloadPackages() {
        allPackages = PackageStore.shared.packages
        updateUI()
    }

    private func updateUI() {
        filterBar.setChipOrder(PackageStatus.filterChips(includeArchived: false), preserveSelection: true)
        filterBar.updateCounts(makeStatusFilterCounts())
        filterBar.updateSelection(selectedStatus)
        tableView.reloadData()
        let empty = displayedPackages.isEmpty
        emptyStateView.isHidden = !empty
        tableView.isHidden = empty
        if empty {
            let hasScope = !statusFilteredPackages.isEmpty
            let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if hasScope && !trimmed.isEmpty {
                emptyStateView.setMode(.noSearchResults)
            } else {
                emptyStateView.setMode(.noPackages)
            }
        }
    }

    @objc private func backgroundTappedToDismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func searchTapped() {
        HapticFeedback.light.play()
        if isSearchBarPresented {
            dismissSearch(animated: true)
        } else {
            presentSearch(animated: true)
        }
    }

    private func presentSearch(animated: Bool) {
        guard !isSearchBarPresented else { return }
        isSearchBarPresented = true
        searchBar.isHidden = false
        searchBarHeightConstraint.constant = 56
        let animations = {
            self.searchBar.alpha = 1
            self.view.layoutIfNeeded()
        }
        if animated {
            UIView.animate(
                withDuration: 0.38,
                delay: 0,
                usingSpringWithDamping: 0.86,
                initialSpringVelocity: 0.45,
                options: [.curveEaseInOut, .allowUserInteraction]
            ) {
                animations()
            } completion: { [weak self] _ in
                self?.searchBar.becomeFirstResponder()
            }
        } else {
            animations()
            searchBar.becomeFirstResponder()
        }
    }

    private func dismissSearch(animated: Bool) {
        guard isSearchBarPresented else { return }
        isSearchBarPresented = false
        searchBar.resignFirstResponder()
        searchBar.setShowsCancelButton(false, animated: animated)
        searchBar.text = ""
        searchQuery = ""
        updateUI()
        searchBarHeightConstraint.constant = 0
        let animations = {
            self.searchBar.alpha = 0
            self.view.layoutIfNeeded()
        }
        let finishCollapse = { [weak self] in
            self?.searchBar.isHidden = true
        }
        if animated {
            UIView.animate(
                withDuration: 0.32,
                delay: 0,
                usingSpringWithDamping: 0.9,
                initialSpringVelocity: 0.35,
                options: [.curveEaseInOut, .allowUserInteraction]
            ) {
                animations()
            } completion: { _ in
                finishCollapse()
            }
        } else {
            animations()
            finishCollapse()
        }
    }

    @objc private func addPackageTapped() {
        HapticFeedback.medium.play()
        let controller = AddPackageViewController()
        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.modalPresentationStyle = .pageSheet
        present(navigationController, animated: true)
    }

    @objc private func refreshPulled() {
        Task { @MainActor in
            defer {
                refreshControl.endRefreshing()
                HapticFeedback.soft.play()
            }

            for package in allPackages {
                do {
                    let payload = try await APIService.shared.getTrackingStatus(for: package)
                    PackageStore.shared.syncWithPayload(id: package.id, payload: payload)
                } catch {
                    print("Refresh failed: \(error.localizedDescription)")
                }
            }

            syncFromBackend()
        }
    }

    private func syncFromBackend() {
        Task { @MainActor in
            do {
                let payloads = try await APIService.shared.listInstallationTrackings()
                if !payloads.isEmpty {
                    PackageStore.shared.replace(with: payloads)
                }
            } catch {
                print("Initial sync failed: \(error.localizedDescription)")
            }
        }
    }
}

extension PackageListViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === dismissKeyboardTap else { return true }
        let point = touch.location(in: view)
        let searchFrame = searchBar.convert(searchBar.bounds, to: view)
        if searchFrame.contains(point) {
            return false
        }
        return true
    }
}

extension PackageListViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchQuery = searchText
        updateUI()
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        HapticFeedback.light.play()
        dismissSearch(animated: true)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        HapticFeedback.light.play()
        searchBar.resignFirstResponder()
    }
}

extension PackageListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        displayedPackages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: PackageCell.reuseIdentifier, for: indexPath) as? PackageCell else {
            return UITableViewCell()
        }

        cell.configure(with: displayedPackages[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        HapticFeedback.light.play()
        let controller = PackageDetailViewController(package: displayedPackages[indexPath.row])
        navigationController?.pushViewController(controller, animated: true)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let package = displayedPackages[indexPath.row]

        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            HapticFeedback.notification(.warning).play()
            PackageStore.shared.delete(id: package.id)
            Task {
                try? await APIService.shared.stopTracking(for: package)
            }
            completion(true)
        }
        deleteAction.image = UIImage(systemName: "trash")
        let config = UISwipeActionsConfiguration(actions: [deleteAction])
        config.performsFirstActionWithFullSwipe = false
        return config
    }

}
