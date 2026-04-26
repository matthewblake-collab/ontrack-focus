import Foundation

struct PersonalBest: Identifiable, Codable {
    let id: UUID
    var userId: UUID
    var category: String
    var eventName: String
    var value: Double
    var valueUnit: String
    var reps: Int?
    var isVerified: Bool
    var proofUrl: String?
    var isPublic: Bool
    var loggedAt: String
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, category, reps
        case userId = "user_id"
        case eventName = "event_name"
        case value
        case valueUnit = "value_unit"
        case isVerified = "is_verified"
        case proofUrl = "proof_url"
        case isPublic = "is_public"
        case loggedAt = "logged_at"
        case createdAt = "created_at"
    }
}
