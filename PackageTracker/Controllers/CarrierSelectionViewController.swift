import UIKit

protocol CarrierSelectionViewControllerDelegate: AnyObject {
    func carrierSelectionViewController(_ controller: CarrierSelectionViewController, didSelect carrier: Carrier)
}

final class CarrierSelectionViewController: UIViewController {
    weak var delegate: CarrierSelectionViewControllerDelegate?

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let searchController = UISearchController(searchResultsController: nil)
    private let selectedCarrier: Carrier?

    private var filteredCarriers: [Carrier] = []

    init(selectedCarrier: Carrier?) {
        self.selectedCarrier = selectedCarrier
        self.filteredCarriers = CarrierDataService.shared.allCarriers
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background
        title = "Select Carrier"
        configureTableView()
        configureSearch()
    }

    private func configureTableView() {
        tableView.backgroundColor = AppTheme.background
        tableView.separatorColor = AppTheme.separator
        tableView.register(CarrierCell.self, forCellReuseIdentifier: CarrierCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self

        view.addSubview(tableView)
        tableView.pinToSuperview()
    }

    private func configureSearch() {
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search carrier"
        searchController.searchResultsUpdater = self
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
    }
}

extension CarrierSelectionViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredCarriers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: CarrierCell.reuseIdentifier, for: indexPath) as? CarrierCell else {
            return UITableViewCell()
        }

        let carrier = filteredCarriers[indexPath.row]
        let isSelected = carrier.code == selectedCarrier?.code
        cell.configure(with: carrier, selected: isSelected)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let carrier = filteredCarriers[indexPath.row]
        delegate?.carrierSelectionViewController(self, didSelect: carrier)
        navigationController?.popViewController(animated: true)
    }
}

extension CarrierSelectionViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text ?? ""
        filteredCarriers = CarrierDataService.shared.search(query)
        tableView.reloadData()
    }
}
