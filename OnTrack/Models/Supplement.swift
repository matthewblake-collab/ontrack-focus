import Foundation

struct Supplement: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var name: String
    var dose: String?
    var timing: String
    var customTime: String?
    var daysOfWeek: String
    var notes: String?
    var reminderEnabled: Bool
    var isActive: Bool
    var inProtocol: Bool
    var stockQuantity: Double?
    var stockUnits: String?
    var doseAmount: Double?
    var doseUnits: String?
    var startDate: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case dose
        case timing
        case customTime = "custom_time"
        case daysOfWeek = "days_of_week"
        case notes
        case reminderEnabled = "reminder_enabled"
        case isActive = "is_active"
        case inProtocol = "in_protocol"
        case stockQuantity = "stock_quantity"
        case stockUnits = "stock_units"
        case doseAmount = "dose_amount"
        case doseUnits = "dose_units"
        case startDate = "start_date"
        case createdAt = "created_at"
    }
}

struct SupplementLog: Codable, Identifiable {
    let id: UUID
    let supplementId: UUID
    let userId: UUID
    var taken: Bool
    let takenAt: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case supplementId = "supplement_id"
        case userId = "user_id"
        case taken
        case takenAt = "taken_at"
        case createdAt = "created_at"
    }
}

enum SupplementTiming: String, CaseIterable, Identifiable {
    case morning = "Morning"
    case preWorkout = "Pre-Workout"
    case postWorkout = "Post-Workout"
    case withMeals = "With Meals"
    case evening = "Evening"
    case beforeBed = "Before Bed"
    case custom = "Custom Time"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .preWorkout: return "bolt.fill"
        case .postWorkout: return "figure.run"
        case .withMeals: return "fork.knife"
        case .evening: return "sunset.fill"
        case .beforeBed: return "moon.fill"
        case .custom: return "clock.fill"
        }
    }

    var label: String {
        switch self {
        case .morning: return "Morning"
        case .preWorkout: return "Pre Workout"
        case .postWorkout: return "Post Workout"
        case .withMeals: return "With Meals"
        case .evening: return "Evening"
        case .beforeBed: return "Before Bed"
        case .custom: return "Custom Time"
        }
    }
}
