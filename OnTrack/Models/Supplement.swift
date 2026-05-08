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
    /// Anchor for weekly/fortnightly/monthly/once recurrence is the parsed `startDate`
    /// if present, otherwise `createdAt`. See `Supplement.isScheduled(daysOfWeek:on:anchor:calendar:)`
    /// for the full format contract.
    func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        Supplement.isScheduled(
            daysOfWeek: daysOfWeek,
            on: date,
            anchor: scheduleAnchor(calendar: calendar),
            calendar: calendar
        )
    }

    /// Anchor date for recurrence rules that need a "starting from when?" reference
    /// (weekly, fortnightly, monthly, once). Resolves `startDate` (yyyy-MM-dd) if set,
    /// else falls back to `createdAt`.
    func scheduleAnchor(calendar: Calendar = .current) -> Date {
        if let s = startDate, let parsed = Supplement.parseStartDate(s, calendar: calendar) {
            return parsed
        }
        return createdAt
    }

    /// Parses the yyyy-MM-dd `start_date` string into a Date pinned to startOfDay
    /// in the supplied calendar. Returns nil for unparseable strings.
    static func parseStartDate(_ s: String, calendar: Calendar = .current) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = calendar.timeZone
        guard let d = f.date(from: s) else { return nil }
        return calendar.startOfDay(for: d)
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
    /// - "weekly|<endTs>" → matches if `date` is on or after `anchor`, on or before
    ///   `endTs`, and the calendar-day distance from `anchor` is divisible by 7
    /// - "fortnightly|<endTs>" → same with stride 14
    /// - "monthly|<endTs>" → matches if `date` is on or after `anchor`, on or before
    ///   `endTs`, and `Calendar.day(date) == Calendar.day(anchor)` (months that don't
    ///   contain the anchor's day-of-month — e.g. anchor day 31 in February — are
    ///   skipped, matching most calendar-app behaviour)
    /// - "once" → matches only if `date` is the same calendar day as `anchor`
    ///
    /// `anchor` is required by weekly/fortnightly/monthly/once. If `nil`, those formats
    /// return `false` (no schedule can be derived). The instance method always supplies
    /// `parseStartDate(startDate) ?? createdAt`.
    static func isScheduled(
        daysOfWeek: String,
        on date: Date,
        anchor: Date? = nil,
        calendar: Calendar = .current
    ) -> Bool {
        if daysOfWeek == "everyday" || daysOfWeek.isEmpty { return true }
        if daysOfWeek.hasPrefix("custom|") {
            let payload = daysOfWeek.dropFirst("custom|".count)
            return payload.split(separator: ",").contains { chunk in
                guard let ts = TimeInterval(chunk) else { return false }
                return calendar.isDate(Date(timeIntervalSince1970: ts), inSameDayAs: date)
            }
        }
        // Anchor-required recurrence rules.
        if let endTs = parseEndTimestamp(prefix: "weekly|", in: daysOfWeek) {
            return strideMatches(date: date, anchor: anchor, endTs: endTs, dayStride: 7, calendar: calendar)
        }
        if let endTs = parseEndTimestamp(prefix: "fortnightly|", in: daysOfWeek) {
            return strideMatches(date: date, anchor: anchor, endTs: endTs, dayStride: 14, calendar: calendar)
        }
        if let endTs = parseEndTimestamp(prefix: "monthly|", in: daysOfWeek) {
            return monthlyMatches(date: date, anchor: anchor, endTs: endTs, calendar: calendar)
        }
        if daysOfWeek == "once" {
            guard let anchor = anchor else { return false }
            return calendar.isDate(date, inSameDayAs: anchor)
        }
        // Weekday-CSV fallback.
        let weekday = String(calendar.component(.weekday, from: date))
        return daysOfWeek.split(separator: ",").contains { String($0) == weekday }
    }

    /// Counts the number of days in `[from, to]` (inclusive, by calendar day) where
    /// `isScheduled(daysOfWeek:on:anchor:calendar:)` is true. Generalises
    /// `customScheduledDayCount` to all formats — used by `ProgressViewModel.adherence`
    /// to compute denominators for weekly/fortnightly/monthly/once.
    ///
    /// Performance note: O(days × payload-size) for `custom|` and O(days) for the
    /// other formats. Range size is bounded by the adherence window (currently ≤90).
    static func scheduledDayCount(
        daysOfWeek: String,
        from start: Date,
        to end: Date,
        anchor: Date? = nil,
        calendar: Calendar = .current
    ) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        guard startDay <= endDay else { return 0 }
        let totalDays = (calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1
        var count = 0
        for offset in 0..<totalDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            if isScheduled(daysOfWeek: daysOfWeek, on: day, anchor: anchor, calendar: calendar) {
                count += 1
            }
        }
        return count
    }

    // MARK: - Recurrence helpers

    /// Extracts the trailing `<timestamp>` from a `prefix|<timestamp>`-shaped string.
    private static func parseEndTimestamp(prefix: String, in s: String) -> TimeInterval? {
        guard s.hasPrefix(prefix) else { return nil }
        return TimeInterval(s.dropFirst(prefix.count))
    }

    /// True if `date` is on/after the anchor day, on/before `endTs`, and the calendar-day
    /// distance from anchor is divisible by `dayStride`.
    private static func strideMatches(
        date: Date,
        anchor: Date?,
        endTs: TimeInterval,
        dayStride: Int,
        calendar: Calendar
    ) -> Bool {
        guard let anchor = anchor else { return false }
        let anchorDay = calendar.startOfDay(for: anchor)
        let day = calendar.startOfDay(for: date)
        let endDay = calendar.startOfDay(for: Date(timeIntervalSince1970: endTs))
        if day < anchorDay || day > endDay { return false }
        let diff = calendar.dateComponents([.day], from: anchorDay, to: day).day ?? 0
        return diff >= 0 && diff % dayStride == 0
    }

    /// True if `date` is on/after anchor, on/before `endTs`, and shares anchor's day-of-month.
    private static func monthlyMatches(
        date: Date,
        anchor: Date?,
        endTs: TimeInterval,
        calendar: Calendar
    ) -> Bool {
        guard let anchor = anchor else { return false }
        let anchorDay = calendar.startOfDay(for: anchor)
        let day = calendar.startOfDay(for: date)
        let endDay = calendar.startOfDay(for: Date(timeIntervalSince1970: endTs))
        if day < anchorDay || day > endDay { return false }
        let anchorDom = calendar.component(.day, from: anchorDay)
        let dayDom = calendar.component(.day, from: day)
        return anchorDom == dayDom
    }

    /// Parses a `custom|<ts1>,<ts2>,…` payload into the corresponding `Date`s, sorted
    /// ascending. Returns `nil` for any string without the `custom|` prefix so callers
    /// can branch cleanly. Mirrors the parse path in `EditSupplementView` so a serialize→
    /// parse round-trip produces the same set of dates.
    static func parseCustomDates(from daysOfWeek: String, calendar: Calendar = .current) -> [Date]? {
        guard daysOfWeek.hasPrefix("custom|") else { return nil }
        let payload = daysOfWeek.dropFirst("custom|".count)
        let dates: [Date] = payload.split(separator: ",").compactMap { chunk in
            guard let ts = TimeInterval(chunk) else { return nil }
            return Date(timeIntervalSince1970: ts)
        }
        return dates.sorted()
    }

    /// Counts the dates inside a `custom|...` payload that fall on a calendar day within
    /// `[startOfDay(start), startOfDay(end)]` (inclusive both ends). Used by ProgressViewModel
    /// to compute the adherence denominator for custom-day supplements; without this the
    /// previous CSV parse produced an empty target set and the supplement was hidden from
    /// stats.
    ///
    /// Returns 0 for non-custom formats — callers that need weekly/everyday counts must
    /// build those themselves (typically via `weekdayNumCounts` precomputation).
    static func customScheduledDayCount(
        daysOfWeek: String,
        from start: Date,
        to end: Date,
        calendar: Calendar = .current
    ) -> Int {
        guard daysOfWeek.hasPrefix("custom|") else { return 0 }
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let payload = daysOfWeek.dropFirst("custom|".count)
        var match = 0
        for chunk in payload.split(separator: ",") {
            guard let ts = TimeInterval(chunk) else { continue }
            let day = calendar.startOfDay(for: Date(timeIntervalSince1970: ts))
            if day >= startDay && day <= endDay { match += 1 }
        }
        return match
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
