import Foundation

struct Comment: Codable, Identifiable {
    let id: UUID
    let sessionId: UUID
    let userId: UUID
    var content: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case userId = "user_id"
        case content
        case createdAt = "created_at"
    }
}
