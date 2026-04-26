import Foundation
import Combine
import Supabase

struct StreakFreeze: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let targetType: String
    let targetId: UUID
    let freezeDate: String   // "yyyy-MM-dd"
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId     = "user_id"
        case targetType = "target_type"
        case targetId   = "target_id"
        case freezeDate = "freeze_date"
        case createdAt  = "created_at"
    }
}

class HabitViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var logs: [HabitLog] = []
    @Published var freezes: [StreakFreeze] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let calendar = Calendar.current

    // MARK: - Date Helpers

    func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func habitsForDate(_ date: Date, groupIds: [UUID]) -> [Habit] {
        let weekday = calendar.component(.weekday, from: date)
        let weekdayAbbr = weekdayAbbreviation(for: weekday)
        let selectedDateStr = dateString(date)

        return habits.filter { habit in
            guard !habit.isArchived else { return false }

            let isVisible = habit.groupId == nil || groupIds.contains(habit.groupId!)
            guard isVisible else { return false }

            // One-off habits: show only on their target date
            if habit.frequency == "once" {
                return habit.targetDate == selectedDateStr
            }

            switch HabitFrequency(rawValue: habit.frequency) ?? .daily {
            case .daily:
                return true
            case .specificDays:
                let days = habit.daysOfWeek?.components(separatedBy: ",") ?? []
                return days.contains(weekdayAbbr)
            case .weekly, .monthly:
                return true
            }
        }
    }

    func logForHabit(_ habit: Habit, on date: Date, userId: UUID) -> HabitLog? {
        let ds = dateString(date)
        return logs.first { $0.habitId == habit.id && $0.userId == userId && $0.loggedDate == ds }
    }

    func isCompleted(_ habit: Habit, on date: Date, userId: UUID) -> Bool {
        guard let log = logForHabit(habit, on: date, userId: userId) else { return false }
        let target = habit.targetCount ?? 1
        return log.count >= target
    }

    func progressFor(_ habit: Habit, on date: Date, userId: UUID) -> Int {
        return logForHabit(habit, on: date, userId: userId)?.count ?? 0
    }

    // MARK: - Streaks

    /// Consecutive-day streak across all habits for the current user.
    /// Uses only the already-loaded `logs` array — no new fetch.
    /// Today counts if it has at least one log; otherwise counting starts from yesterday.
    var consistencyStreak: Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let loggedDates = Set(logs.map { $0.loggedDate })
        guard !loggedDates.isEmpty else { return 0 }

        var checkDate = Date()
        let todayStr = formatter.string(from: checkDate)
        if !loggedDates.contains(todayStr) {
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        var streak = 0
        for _ in 0..<365 {
            let ds = formatter.string(from: checkDate)
            if loggedDates.contains(ds) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }
        }
        return streak
    }

    func currentStreak(for habit: Habit, userId: UUID) -> Int {
        var streak = 0
        var checkDate = Date()

        if !isCompleted(habit, on: checkDate, userId: userId) {
            // Only skip today if there is also no freeze covering today
            if !hasFreezeOn(habitId: habit.id, date: checkDate) {
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            }
        }

        for _ in 0..<365 {
            if shouldCountDay(habit: habit, date: checkDate) {
                if isCompleted(habit, on: checkDate, userId: userId) || hasFreezeOn(habitId: habit.id, date: checkDate) {
                    streak += 1
                } else {
                    break
                }
            }
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        return streak
    }

    func bestStreak(for habit: Habit, userId: UUID) -> Int {
        var best = 0
        var current = 0
        let logsForHabit = logs
            .filter { $0.habitId == habit.id && $0.userId == userId }
            .sorted { $0.loggedDate < $1.loggedDate }

        guard !logsForHabit.isEmpty else { return 0 }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var prevDate: Date? = nil
        for log in logsForHabit {
            guard let logDate = formatter.date(from: log.loggedDate) else { continue }
            let target = habit.targetCount ?? 1
            guard log.count >= target else { continue }

            if let prev = prevDate,
               let diff = calendar.dateComponents([.day], from: prev, to: logDate).day,
               diff == 1 {
                current += 1
            } else {
                current = 1
            }
            best = max(best, current)
            prevDate = logDate
        }
        return best
    }

    private func shouldCountDay(habit: Habit, date: Date) -> Bool {
        switch HabitFrequency(rawValue: habit.frequency) ?? .daily {
        case .daily:
            return true
        case .specificDays:
            let weekday = calendar.component(.weekday, from: date)
            let abbr = weekdayAbbreviation(for: weekday)
            let days = habit.daysOfWeek?.components(separatedBy: ",") ?? []
            return days.contains(abbr)
        case .weekly, .monthly:
            return true
        }
    }

    private func weekdayAbbreviation(for weekday: Int) -> String {
        switch weekday {
        case 1: return "Sun"
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        case 7: return "Sat"
        default: return ""
        }
    }

    // MARK: - Fetch

    func fetchHabits() async {
        // Bug 4: dropped isLoading=true/false toggles around the data assignment.
        // Previously caused 3 @Published updates per fetch (load on → data → load off),
        // each triggering Home row re-renders in visible waves.
        do {
            let fetched: [Habit] = try await supabase
                .from("habits")
                .select()
                .eq("is_archived", value: false)
                .execute()
                .value
            await MainActor.run { self.habits = fetched }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    func fetchLogs(for userId: UUID) async {
        do {
            let fetched: [HabitLog] = try await supabase
                .from("habit_logs")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            await MainActor.run { self.logs = fetched }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    // MARK: - Freeze

    /// Fetches all habit freezes for the user into `self.freezes`.
    func fetchFreezes(userId: UUID) async {
        do {
            let fetched: [StreakFreeze] = try await supabase
                .from("streak_freezes")
                .select()
                .eq("user_id", value: userId.uuidString.lowercased())
                .eq("target_type", value: "habit")
                .execute()
                .value
            await MainActor.run { self.freezes = fetched }
        } catch {
            // Non-fatal — streak display continues without freeze data
        }
    }

    /// Applies a freeze for the missed day (yesterday) for the given habit.
    /// freeze_date = yesterday, matching the streak gap date.
    func applyFreeze(habitId: UUID, userId: UUID) async {
        let missedDay = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let missedDayStr = dateString(missedDay)

        struct NewFreeze: Encodable {
            let userId: String
            let targetType: String
            let targetId: String
            let freezeDate: String
            enum CodingKeys: String, CodingKey {
                case userId     = "user_id"
                case targetType = "target_type"
                case targetId   = "target_id"
                case freezeDate = "freeze_date"
            }
        }

        do {
            try await supabase
                .from("streak_freezes")
                .insert(NewFreeze(
                    userId: userId.uuidString.lowercased(),
                    targetType: "habit",
                    targetId: habitId.uuidString.lowercased(),
                    freezeDate: missedDayStr
                ))
                .execute()
            await fetchFreezes(userId: userId)
        } catch {
            // Silently ignore duplicate inserts (unique constraint)
        }
    }

    /// Returns true if no freeze has been used for this habit in the current ISO week.
    func isFreezeAvailable(for habit: Habit) -> Bool {
        let cal = Calendar.current
        let now = Date()
        let currentWeek = cal.component(.weekOfYear, from: now)
        let currentYear = cal.component(.yearForWeekOfYear, from: now)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return !freezes.contains { freeze in
            guard freeze.targetType == "habit",
                  freeze.targetId == habit.id,
                  let fd = formatter.date(from: freeze.freezeDate) else { return false }
            return cal.component(.weekOfYear, from: fd) == currentWeek &&
                   cal.component(.yearForWeekOfYear, from: fd) == currentYear
        }
    }

    /// Returns true if a freeze covers the given habit on the given date.
    func hasFreezeOn(habitId: UUID, date: Date) -> Bool {
        let ds = dateString(date)
        return freezes.contains { $0.targetType == "habit" && $0.targetId == habitId && $0.freezeDate == ds }
    }

    // MARK: - Log / Unlog

    func toggleHabit(_ habit: Habit, on date: Date, userId: UUID) async {
        let ds = dateString(date)
        if let existing = logForHabit(habit, on: date, userId: userId) {
            do {
                try await supabase
                    .from("habit_logs")
                    .delete()
                    .eq("id", value: existing.id.uuidString)
                    .execute()
                await MainActor.run {
                    self.logs.removeAll { $0.id == existing.id }
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        } else {
            let newLog = NewHabitLog(habitId: habit.id, userId: userId, loggedDate: ds, count: 1)
            do {
                let inserted: HabitLog = try await supabase
                    .from("habit_logs")
                    .insert(newLog)
                    .select()
                    .single()
                    .execute()
                    .value
                await MainActor.run {
                    self.logs.append(inserted)
                    AnalyticsManager.shared.track(.habitLogged)
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    func incrementHabit(_ habit: Habit, on date: Date, userId: UUID) async {
        let ds = dateString(date)
        if let existing = logForHabit(habit, on: date, userId: userId) {
            let newCount = existing.count + 1
            do {
                try await supabase
                    .from("habit_logs")
                    .update(["count": newCount])
                    .eq("id", value: existing.id.uuidString)
                    .execute()
                await MainActor.run {
                    if let idx = self.logs.firstIndex(where: { $0.id == existing.id }) {
                        self.logs[idx].count = newCount
                    }
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        } else {
            let newLog = NewHabitLog(habitId: habit.id, userId: userId, loggedDate: ds, count: 1)
            do {
                let inserted: HabitLog = try await supabase
                    .from("habit_logs")
                    .insert(newLog)
                    .select()
                    .single()
                    .execute()
                    .value
                await MainActor.run { self.logs.append(inserted) }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    func decrementHabit(_ habit: Habit, on date: Date, userId: UUID) async {
        guard let existing = logForHabit(habit, on: date, userId: userId) else { return }
        if existing.count <= 1 {
            do {
                try await supabase
                    .from("habit_logs")
                    .delete()
                    .eq("id", value: existing.id.uuidString)
                    .execute()
                await MainActor.run {
                    self.logs.removeAll { $0.id == existing.id }
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        } else {
            let newCount = existing.count - 1
            do {
                try await supabase
                    .from("habit_logs")
                    .update(["count": newCount])
                    .eq("id", value: existing.id.uuidString)
                    .execute()
                await MainActor.run {
                    if let idx = self.logs.firstIndex(where: { $0.id == existing.id }) {
                        self.logs[idx].count = newCount
                    }
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    // MARK: - Create / Delete

    func createHabit(
        name: String,
        frequency: HabitFrequency,
        daysOfWeek: String?,
        weeklyTarget: Int?,
        monthlyTarget: Int?,
        targetCount: Int?,
        groupId: UUID?,
        userId: UUID,
        isPrivate: Bool = false,
        visibleToFriends: Bool = false,
        targetDate: Date? = nil
    ) async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let resolvedFrequency = targetDate != nil ? "once" : frequency.rawValue

        struct NewHabit: Encodable {
            let createdBy: UUID
            let groupId: UUID?
            let name: String
            let frequency: String
            let daysOfWeek: String?
            let weeklyTarget: Int?
            let monthlyTarget: Int?
            let targetCount: Int?
            let isArchived: Bool
            let isPrivate: Bool
            let visibleToFriends: Bool
            let targetDate: String?

            enum CodingKeys: String, CodingKey {
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
            }
        }

        let newHabit = NewHabit(
            createdBy: userId,
            groupId: groupId,
            name: name,
            frequency: resolvedFrequency,
            daysOfWeek: daysOfWeek,
            weeklyTarget: weeklyTarget,
            monthlyTarget: monthlyTarget,
            targetCount: targetCount,
            isArchived: false,
            isPrivate: isPrivate,
            visibleToFriends: visibleToFriends,
            targetDate: targetDate.map { dateFormatter.string(from: $0) }
        )

        do {
            let inserted: Habit = try await supabase
                .from("habits")
                .insert(newHabit)
                .select()
                .single()
                .execute()
                .value
            await MainActor.run { self.habits.append(inserted) }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    func updateHabit(_ habit: Habit, name: String, targetCount: Int?, isPrivate: Bool = false) async {
        struct HabitUpdate: Encodable {
            let name: String
            let targetCount: Int?
            let isPrivate: Bool
            enum CodingKeys: String, CodingKey {
                case name
                case targetCount = "target_count"
                case isPrivate = "is_private"
            }
        }
        do {
            let updated: Habit = try await supabase
                .from("habits")
                .update(HabitUpdate(name: name, targetCount: targetCount, isPrivate: isPrivate))
                .eq("id", value: habit.id.uuidString)
                .select()
                .single()
                .execute()
                .value
            await MainActor.run {
                if let idx = self.habits.firstIndex(where: { $0.id == habit.id }) {
                    self.habits[idx] = updated
                }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    func deleteHabit(_ habit: Habit) async {
        do {
            try await supabase
                .from("habits")
                .delete()
                .eq("id", value: habit.id.uuidString)
                .execute()
            await MainActor.run {
                self.habits.removeAll { $0.id == habit.id }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    func archiveHabit(_ habit: Habit) async {
        do {
            try await supabase
                .from("habits")
                .update(["is_archived": true])
                .eq("id", value: habit.id.uuidString)
                .execute()
            await MainActor.run {
                self.habits.removeAll { $0.id == habit.id }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}
