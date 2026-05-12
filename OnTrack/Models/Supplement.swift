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
    /// Raw barcode value captured when this supplement was added/matched via the scanner. nil for manual entries.
    var barcodeScanned: String?
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
        case barcodeScanned = "barcode_scanned"
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

    /// Human-readable summary of the supplement's recurrence. Used by both
    /// `ProtocolRowView` (compact card) and `SupplementDetailView` (Schedule row)
    /// so the two surfaces stay in sync. Examples:
    /// - "Every day"
    /// - "Mon, Thu" (weekday CSV)
    /// - "Mon, Thu" (custom payload collapsing to ≤4 distinct weekdays)
    /// - "8 dates" (custom payload with >4 distinct weekdays)
    /// - "Weekly until 31 May" (weekly|<endTs>)
    /// - "Fortnightly until 31 May" (fortnightly|<endTs>)
    /// - "Monthly until 31 May" (monthly|<endTs>)
    /// - "Once on 15 May" (once)
    func scheduleLabel(calendar: Calendar = .current) -> String {
        let days = daysOfWeek
        if days == "everyday" || days.isEmpty { return "Every day" }
        let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        // Custom payload: collapse to distinct weekday names, else fall back to "N dates".
        if days.hasPrefix("custom|") {
            let payload = days.dropFirst("custom|".count)
            let timestamps = payload.split(separator: ",").compactMap { TimeInterval($0) }
            if timestamps.isEmpty { return "Custom dates" }
            let weekdays = Set(timestamps.map { calendar.component(.weekday, from: Date(timeIntervalSince1970: $0)) })
            if weekdays.count <= 4 {
                return weekdays.sorted().map { dayNames[$0] }.joined(separator: ", ")
            }
            return "\(timestamps.count) dates"
        }

        // Recurrence rules with an end timestamp.
        let endFmt = DateFormatter()
        endFmt.dateFormat = "d MMM"
        endFmt.locale = Locale.autoupdatingCurrent
        endFmt.timeZone = calendar.timeZone

        if let endTs = Supplement.parseEndTimestamp(prefix: "weekly|", in: days) {
            return "Weekly until \(endFmt.string(from: Date(timeIntervalSince1970: endTs)))"
        }
        if let endTs = Supplement.parseEndTimestamp(prefix: "fortnightly|", in: days) {
            return "Fortnightly until \(endFmt.string(from: Date(timeIntervalSince1970: endTs)))"
        }
        if let endTs = Supplement.parseEndTimestamp(prefix: "monthly|", in: days) {
            return "Monthly until \(endFmt.string(from: Date(timeIntervalSince1970: endTs)))"
        }
        if days == "once" {
            return "Once on \(endFmt.string(from: scheduleAnchor(calendar: calendar)))"
        }

        // Weekday-CSV fallback: parse 1-7 ints and map to names.
        let parts = days.components(separatedBy: ",").compactMap { Int($0) }.filter { $0 >= 1 && $0 <= 7 }
        if parts.isEmpty { return "Custom dates" }
        return parts.map { dayNames[$0] }.joined(separator: ", ")
    }

    /// yyyy-MM-dd serialization of `scheduleAnchor` — used by ShareStackView /
    /// SupplementDetailView to embed the original creator's anchor in the shared
    /// payload so recipients can re-anchor weekly/fortnightly/monthly/once.
    func scheduleAnchorString(calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = calendar.timeZone
        return f.string(from: scheduleAnchor(calendar: calendar))
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

    /// Returns true if the supplement's schedule is exhausted as of `date`. Used by
    /// ImportStackView to flag shared supplements whose recurrence has already ended
    /// for the recipient (so they import as `is_active = false` rather than silently
    /// landing in the daily schedule with no remaining triggers).
    ///
    /// Per format:
    /// - "everyday" / weekday CSV → never expires (false)
    /// - "custom|<ts1>,..." → all timestamps strictly before startOfDay(date) → expired
    /// - "weekly|<endTs>" / "fortnightly|..." / "monthly|..." → endTs strictly before
    ///   startOfDay(date) → expired
    /// - "once" → anchor strictly before startOfDay(date) → expired (anchor required;
    ///   nil → false because we cannot determine)
    static func scheduleHasExpired(
        daysOfWeek: String,
        anchor: Date? = nil,
        on date: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let today = calendar.startOfDay(for: date)
        if daysOfWeek == "everyday" || daysOfWeek.isEmpty { return false }
        if daysOfWeek.hasPrefix("custom|") {
            let payload = daysOfWeek.dropFirst("custom|".count)
            let dates = payload.split(separator: ",").compactMap { TimeInterval($0) }
            guard !dates.isEmpty else { return false }
            return dates.allSatisfy { calendar.startOfDay(for: Date(timeIntervalSince1970: $0)) < today }
        }
        if let endTs = parseEndTimestamp(prefix: "weekly|", in: daysOfWeek)
            ?? parseEndTimestamp(prefix: "fortnightly|", in: daysOfWeek)
            ?? parseEndTimestamp(prefix: "monthly|", in: daysOfWeek) {
            return calendar.startOfDay(for: Date(timeIntervalSince1970: endTs)) < today
        }
        if daysOfWeek == "once" {
            guard let anchor = anchor else { return false }
            return calendar.startOfDay(for: anchor) < today
        }
        return false
    }

    /// Expands a set of weekday integers (1=Sun…7=Sat per `Calendar.component(.weekday)`)
    /// into every concrete date in `[startOfDay(start), startOfDay(end)]` whose weekday
    /// is in the set. Used by `CustomSupplementDatePicker`'s quick-fill control.
    ///
    /// - Returns sorted ascending, deduplicated by calendar day, capped at `limit` (default
    ///   365 to guard against pathological date ranges).
    /// - Empty `weekdays` → `[]`. End before start → `[]`.
    static func expandWeekdaysToDates(
        weekdays: Set<Int>,
        from start: Date,
        to end: Date,
        limit: Int = 365,
        calendar: Calendar = .current
    ) -> [Date] {
        guard !weekdays.isEmpty else { return [] }
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        guard startDay <= endDay else { return [] }
        let totalDays = (calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1
        var out: [Date] = []
        out.reserveCapacity(min(totalDays, limit))
        for offset in 0..<totalDays {
            if out.count >= limit { break }
            guard let d = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            if weekdays.contains(calendar.component(.weekday, from: d)) {
                out.append(d)
            }
        }
        return out
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
