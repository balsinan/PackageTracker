import Foundation

struct Carrier: Hashable, Codable {
    let code: Int
    let name: String
    let url: String?
}
