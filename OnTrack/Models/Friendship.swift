import Foundation

// MARK: - Friendship

struct Friendship: Codable, Identifiable {
    let id: String
    let requesterId: String
    let receiverId: String
    let status: String
    let createdAt: String
    let requester: FriendProfile?
    let receiver: FriendProfile?

    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case receiverId = "receiver_id"
        case status
        case createdAt = "created_at"
        case requester
        case receiver
    }

    var friendProfile: FriendProfile? {
        // Returns the other person's profile
        return nil // resolved in view using currentUserId
    }
}

struct NewFriendship: Codable {
    let requesterId: String
    let receiverId: String

    enum CodingKeys: String, CodingKey {
        case requesterId = "requester_id"
        case receiverId = "receiver_id"
    }
}

// MARK: - FriendProfile (lightweight profile for joins)

struct FriendProfile: Codable, Identifiable {
    let id: String
    let displayName: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
    }
}

// MARK: - FriendCode

struct FriendCode: Codable, Identifiable {
    let id: String
    let userId: String
    let code: String
    let createdAt: String
    let profile: Profile?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case code
        case createdAt = "created_at"
        case profile
    }
}

struct NewFriendCode: Codable {
    let userId: String
    let code: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case code
    }
}

// MARK: - HabitMember

struct HabitMember: Codable, Identifiable {
    let id: String
    let habitId: String
    let userId: String
    let invitedBy: String
    let status: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case habitId = "habit_id"
        case userId = "user_id"
        case invitedBy = "invited_by"
        case status
        case createdAt = "created_at"
    }
}

struct NewHabitMember: Codable {
    let habitId: String
    let userId: String
    let invitedBy: String

    enum CodingKeys: String, CodingKey {
        case habitId = "habit_id"
        case userId = "user_id"
        case invitedBy = "invited_by"
    }
}

// MARK: - Milestone

struct Milestone: Identifiable {
    let id = UUID()
    let userId: String
    let habitId: String
    let habitName: String?
    let isPrivate: Bool
    let streakCount: Int
    let achievedAt: String

    var displayName: String {
        isPrivate ? "a habit" : (habitName ?? "a habit")
    }
}
