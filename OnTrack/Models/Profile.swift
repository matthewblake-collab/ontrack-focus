import Foundation

struct Profile: Codable, Identifiable {
    let id: UUID
    var displayName: String
    var avatarURL: String?
    var goals: [String]
    let createdAt: Date
    var isFoundationMember: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case goals
        case createdAt = "created_at"
        case isFoundationMember = "is_foundation_member"
    }
}
