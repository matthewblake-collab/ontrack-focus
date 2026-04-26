import Foundation

struct HealthWorkoutImport: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let workoutType: String
    let durationMinutes: Int
    let calories: Int?
    let workoutDate: String  // "yyyy-MM-dd"
    let source: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case workoutType = "workout_type"
        case durationMinutes = "duration_minutes"
        case calories
        case workoutDate = "workout_date"
        case source
        case createdAt = "created_at"
    }
}
