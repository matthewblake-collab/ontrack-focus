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

    /// Returns true if this supplement is scheduled to appear on `date`.
    /// See `Supplement.isScheduled(daysOfWeek:on:calendar:)` for the format contract.
    func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        Supplement.isScheduled(daysOfWeek: daysOfWeek, on: date, calendar: calendar)
    }

    /// Pure predicate over the raw `days_of_week` string. Used by the instance method above
    /// and by code paths that hold partial Supplement data (NotificationManager / ProgressViewModel
    /// fetch lightweight rows rather than the full model).
    ///
    /// Supported formats:
    /// - "everyday" / empty → always true
    /// - "1,2,3" (weekday CSV, 1=Sun…7=Sat) → matches if `date`'s weekday is in the set
    /// - "custom|<ts1>,<ts2>,…" (UNIX timestamps from CustomSupplementDatePicker) →
    ///   matches if any timestamp falls on the same calendar day as `date`
    /// - All other formats (weekly|<endTs>, fortnightly|…, monthly|…, once) fall through to
    ///   the legacy CSV path and return false unless they contain a matching weekday integer.
    static func isScheduled(daysOfWeek: String, on date: Date, calendar: Calendar = .current) -> Bool {
        if daysOfWeek == "everyday" || daysOfWeek.isEmpty { return true }
        if daysOfWeek.hasPrefix("custom|") {
            let payload = daysOfWeek.dropFirst("custom|".count)
            return payload.split(separator: ",").contains { chunk in
                guard let ts = TimeInterval(chunk) else { return false }
                return calendar.isDate(Date(timeIntervalSince1970: ts), inSameDayAs: date)
            }
        }
        let weekday = String(calendar.component(.weekday, from: date))
        return daysOfWeek.split(separator: ",").contains { String($0) == weekday }
    }

    /// Returns the upcoming scheduled `Date`s for a `custom|...` payload, sorted ascending,
    /// dropping any timestamp at or before `after`. For non-custom formats returns `[]` —
    /// callers that need to enumerate future dates of weekly/everyday recurrences must build
    /// those themselves.
    ///
    /// - Parameter limit: hard cap on returned count (used by NotificationManager to stay
    ///   under iOS's 64 pending-request budget across all supplements).
    static func upcomingScheduledDates(
        daysOfWeek: String,
        after: Date,
        limit: Int = 30,
        calendar: Calendar = .current
    ) -> [Date] {
        guard daysOfWeek.hasPrefix("custom|") else { return [] }
        let payload = daysOfWeek.dropFirst("custom|".count)
        let dates: [Date] = payload.split(separator: ",").compactMap { chunk in
            guard let ts = TimeInterval(chunk) else { return nil }
            return Date(timeIntervalSince1970: ts)
        }
        return dates
            .filter { $0 > after }
            .sorted()
            .prefix(limit)
            .map { $0 }
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
