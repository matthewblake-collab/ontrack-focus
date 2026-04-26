import Foundation

struct RSVP: Codable, Identifiable {
    let id: UUID
    let sessionId: UUID
    let userId: UUID
    var status: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case userId = "user_id"
        case status
        case updatedAt = "updated_at"
    }
}
