import Foundation

struct HabitLog: Identifiable, Codable {
    let id: UUID
    let habitId: UUID
    let userId: UUID
    var loggedDate: String
    var count: Int
    let createdAt: Date
    let habit: HabitSummary?

    enum CodingKeys: String, CodingKey {
        case id
        case habitId = "habit_id"
        case userId = "user_id"
        case loggedDate = "logged_date"
        case count
        case createdAt = "created_at"
        case habit
    }
}

struct NewHabitLog: Encodable {
    let habitId: UUID
    let userId: UUID
    let loggedDate: String
    let count: Int

    enum CodingKeys: String, CodingKey {
        case habitId = "habit_id"
        case userId = "user_id"
        case loggedDate = "logged_date"
        case count
    }
}
