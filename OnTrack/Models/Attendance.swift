import Foundation

struct Attendance: Codable, Identifiable {
    let id: UUID
    let sessionId: UUID
    let userId: UUID
    var attended: Bool
    let markedBy: UUID?
    let markedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case userId = "user_id"
        case attended
        case markedBy = "marked_by"
        case markedAt = "marked_at"
    }
}
