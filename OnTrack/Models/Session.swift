import Foundation

struct AppSession: Codable, Identifiable {
    let id: UUID
    let groupId: UUID?
    var title: String
    var description: String?
    var location: String?
    var proposedAt: Date?
    var status: String
    let createdBy: UUID
    let createdAt: Date
    var seriesId: UUID?
    var recurrenceRule: String?
    var sessionType: String?
    var visibility: String?

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case title
        case description
        case location
        case proposedAt = "proposed_at"
        case status
        case createdBy = "created_by"
        case createdAt = "created_at"
        case seriesId = "series_id"
        case recurrenceRule = "recurrence_rule"
        case sessionType = "session_type"
        case visibility
    }
}
