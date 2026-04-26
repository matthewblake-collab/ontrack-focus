import Foundation

struct AvailabilityWindow: Codable, Identifiable {
    let id: UUID
    let sessionId: UUID
    let userId: UUID
    var startsAt: Date
    var endsAt: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case userId = "user_id"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case createdAt = "created_at"
    }
}
