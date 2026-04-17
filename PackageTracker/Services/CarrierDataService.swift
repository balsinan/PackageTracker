import Foundation

final class CarrierDataService {
    static let shared = CarrierDataService()

    let allCarriers: [Carrier]

    private init() {
        guard let url = Bundle.main.url(forResource: "carriers", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let carriers = try? JSONDecoder().decode([Carrier].self, from: data) else {
            allCarriers = []
            return
        }
        allCarriers = carriers
    }

    func search(_ query: String) -> [Carrier] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return allCarriers }
        return allCarriers.filter { $0.name.lowercased().contains(trimmed) }
    }
}
