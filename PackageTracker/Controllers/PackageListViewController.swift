import UIKit

final class PackageListViewController: UIViewController {
    private let filterBar = StatusFilterBar()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyStateView = EmptyStateView()
    private let addButton = UIButton(type: .system)
    private let refreshControl = UIRefreshControl()

    private var allPackages: [Package] = []
    private var selectedStatus: PackageStatus = .all

    private var filteredPackages: [Package] {
        let packagesToDisplay: [Package]
        if UserDefaults.standard.bool(forKey: DefaultsKey.archiveDelivered) {
            packagesToDisplay = allPackages.filter { $0.status != .delivered }
        } else {
            packagesToDisplay = allPackages
        }

        guard selectedStatus != .all else { return packagesToDisplay }
        return packagesToDisplay.filter { $0.status == selectedStatus }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        configureObservers()
        reloadPackages()
        syncFromBackend()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadPackages()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureUI() {
        title = "My Packages"
        view.backgroundColor = AppTheme.background

        let plusItem = UIBarButtonItem(image: UIImage(systemName: "plus"), style: .plain, target: self, action: #selector(addPackageTapped))
        navigationItem.rightBarButtonItem = plusItem

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = AppTheme.background
        navAppearance.titleTextAttributes = [.foregroundColor: AppTheme.textPrimary]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: AppTheme.textPrimary]
        navigationController?.navigationBar.standardAppearance = navAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = navAppearance
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

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

        view.addSubview(filterBar)
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
        tableView.anchor(top: filterBar.bottomAnchor, leading: view.leadingAnchor, bottom: view.bottomAnchor, trailing: view.trailingAnchor, padding: UIEdgeInsets(top: 16, left: 0, bottom: 0, right: 0))
        emptyStateView.anchor(top: filterBar.bottomAnchor, leading: view.leadingAnchor, bottom: view.bottomAnchor, trailing: view.trailingAnchor)
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
        tableView.reloadData()
        emptyStateView.isHidden = !filteredPackages.isEmpty
        tableView.isHidden = filteredPackages.isEmpty
    }

    @objc private func addPackageTapped() {
        let controller = AddPackageViewController()
        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.modalPresentationStyle = .pageSheet
        present(navigationController, animated: true)
    }

    @objc private func refreshPulled() {
        Task { @MainActor in
            defer { refreshControl.endRefreshing() }

            for package in allPackages {
                do {
                    let payload = try await APIService.shared.getTrackingStatus(for: package)
                    PackageStore.shared.update(id: package.id, status: payload.status, lastUpdate: payload.lastUpdate)
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

extension PackageListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredPackages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: PackageCell.reuseIdentifier, for: indexPath) as? PackageCell else {
            return UITableViewCell()
        }

        cell.configure(with: filteredPackages[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let controller = PackageDetailViewController(package: filteredPackages[indexPath.row])
        navigationController?.pushViewController(controller, animated: true)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        let package = filteredPackages[indexPath.row]
        PackageStore.shared.delete(id: package.id)
        Task {
            try? await APIService.shared.stopTracking(for: package)
        }
    }
}
