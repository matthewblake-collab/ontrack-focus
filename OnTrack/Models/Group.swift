import Foundation

struct AppGroup: Codable, Identifiable {
    let id: UUID
    var name: String
    var description: String?
    let inviteCode: String
    let createdBy: UUID
    let createdAt: Date
    var coverImageURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case inviteCode = "invite_code"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case coverImageURL = "cover_image_url"
    }
}

// MARK: - Group Invite

struct GroupInvite: Codable, Identifiable {
    let id: UUID
    let groupId: UUID
    let inviteeId: String
    let invitedBy: String
    let status: String
    let createdAt: Date
    let groups: GroupNameJoin?

    struct GroupNameJoin: Codable {
        let name: String
    }

    var groupName: String { groups?.name ?? "Unknown Group" }

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case inviteeId = "invitee_id"
        case invitedBy = "invited_by"
        case status
        case createdAt = "created_at"
        case groups
    }
}

struct NewGroupInvite: Codable {
    let groupId: UUID
    let inviteeId: String
    let invitedBy: String

    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case inviteeId = "invitee_id"
        case invitedBy = "invited_by"
    }
}
