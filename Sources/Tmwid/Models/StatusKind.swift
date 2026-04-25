import Foundation

enum StatusKind: String, Codable, CaseIterable, Hashable {
    case working
    case done
    case ask
}
