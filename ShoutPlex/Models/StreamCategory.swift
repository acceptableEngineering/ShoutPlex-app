import Foundation

struct StreamCategory: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    /// Ordered list of stream IDs belonging to this category.
    var streamIDs: [UUID] = []
}
