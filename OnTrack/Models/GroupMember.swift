import Foundation

struct GroupMember: Codable, Identifiable {
    let id: UUID
    let groupId: UUID
    let userId: UUID
    var role: String
    let joinedAt: Date
    var sessionStreak: Int
    var bestStreak: Int

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
        case sessionStreak = "session_streak"
        case bestStreak = "best_streak"
    }
}
