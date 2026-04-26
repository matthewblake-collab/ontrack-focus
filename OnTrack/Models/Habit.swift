import Foundation

struct Habit: Identifiable, Codable {
    let id: UUID
    let createdBy: UUID
    var groupId: UUID?
    var name: String
    var frequency: String
    var daysOfWeek: String?
    var weeklyTarget: Int?
    var monthlyTarget: Int?
    var targetCount: Int?
    var isArchived: Bool
    var isPrivate: Bool
    var visibleToFriends: Bool
    var targetDate: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case createdBy = "created_by"
        case groupId = "group_id"
        case name
        case frequency
        case daysOfWeek = "days_of_week"
        case weeklyTarget = "weekly_target"
        case monthlyTarget = "monthly_target"
        case targetCount = "target_count"
        case isArchived = "is_archived"
        case isPrivate = "is_private"
        case visibleToFriends = "visible_to_friends"
        case targetDate = "target_date"
        case createdAt = "created_at"
    }
}

struct HabitSummary: Codable {
    let id: UUID
    let name: String
    let isPrivate: Bool
    let createdBy: UUID

    enum CodingKeys: String, CodingKey {
        case id, name
        case isPrivate = "is_private"
        case createdBy = "created_by"
    }
}

enum HabitFrequency: String, CaseIterable {
    case daily = "daily"
    case specificDays = "specific_days"
    case weekly = "weekly"
    case monthly = "monthly"

    var label: String {
        switch self {
        case .daily: return "Every day"
        case .specificDays: return "Specific days"
        case .weekly: return "Weekly target"
        case .monthly: return "Monthly target"
        }
    }
}
