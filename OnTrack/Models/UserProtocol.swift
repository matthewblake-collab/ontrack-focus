import Foundation

struct UserProtocol: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let protocolType: String
    var protocolName: String
    var startDate: String     // "yyyy-MM-dd"
    var endDate: String?      // "yyyy-MM-dd"
    var isActive: Bool
    var goal: String?
    var notes: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case protocolType = "protocol_type"
        case protocolName = "protocol_name"
        case startDate = "start_date"
        case endDate = "end_date"
        case isActive = "is_active"
        case goal, notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension UserProtocol {
    var startDateParsed: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: startDate)
    }

    var endDateParsed: Date? {
        guard let endDate else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: endDate)
    }

    /// Week 1 = days 0-6 from start_date.
    var weekNumber: Int {
        guard let start = startDateParsed else { return 1 }
        let cal = Calendar.current
        let days = cal.dateComponents([.day],
                                      from: cal.startOfDay(for: start),
                                      to: cal.startOfDay(for: Date())).day ?? 0
        return max(1, days / 7 + 1)
    }

    var daysSinceStart: Int {
        guard let start = startDateParsed else { return 0 }
        let cal = Calendar.current
        return max(0, cal.dateComponents([.day],
                                         from: cal.startOfDay(for: start),
                                         to: cal.startOfDay(for: Date())).day ?? 0)
    }
}

struct UserProtocolInsert: Encodable {
    let userId: UUID
    let protocolType: String
    let protocolName: String
    let startDate: String
    let endDate: String?
    let goal: String?
    let notes: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case protocolType = "protocol_type"
        case protocolName = "protocol_name"
        case startDate = "start_date"
        case endDate = "end_date"
        case isActive = "is_active"
        case goal, notes
    }
}

struct UserProtocolDeactivate: Encodable {
    let isActive: Bool = false
    enum CodingKeys: String, CodingKey { case isActive = "is_active" }
}
