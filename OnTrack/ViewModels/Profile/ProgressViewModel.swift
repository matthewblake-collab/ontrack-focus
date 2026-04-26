import Foundation
import Supabase
import HealthKit

struct SessionAttendanceStat: Identifiable {
    let id = UUID()
    let label: String   // e.g. "Mon", "Week 1", "Jan"
    let count: Int
}

enum ProgressRange {
    case weekly, monthly, allTime
}

@Observable
final class ProgressViewModel {

    // MARK: - Habits
    var habitsCreated: Int = 0
    var habitLogsTotal: Int = 0
    var habitCompletionPct: Double = 0
    var habitBestStreak: Int = 0

    // MARK: - Sessions
    var sessionsRSVPd: Int = 0
    var sessionsAttended: Int = 0
    var sessionAttendancePct: Double = 0
    var sessionBestStreak: Int = 0

    // MARK: - Supplements
    var supplementsActive: Int = 0
    var supplementLogsTotal: Int = 0
    var supplementAdherencePct: Double = 0
    var supplementBestStreak: Int = 0

    // MARK: - Health
    var totalKmRun: Double = 0
    var isLoadingHealth: Bool = false

    // MARK: - Personal Bests
    var personalBests: [PersonalBest] = []
    var isLoadingPBs: Bool = false
    var detectedNewPBs: [(label: String, value: String)] = []

    // MARK: - Daily Summary
    var todayCompletionPct: Int = 0
    var mostRecentPBSummary: String = ""

    // MARK: - Progress Sheet
    var sessionStats: [SessionAttendanceStat] = []
    var totalSessionsAttended: Int = 0
    var totalHabitDays: Int = 0
    var totalSupplementsTaken: Int = 0

    // MARK: - Apple Health Imports
    var pendingHealthWorkouts: [HKWorkout] = []
    var importedWorkoutDates: Set<String> = []

    // Bug 2: surfaced-stat aggregates from health_workout_imports for the
    // "Workouts imported" card in PersonalProgressSheet.
    var importedWorkoutCount: Int = 0
    var importedWorkoutMinutes: Int = 0
    var importedWorkoutCalories: Int = 0
    var importedWorkoutWindowDays: Int = 30

    private let healthStore = HKHealthStore()

    init() {
        Task { await loadAll() }
    }

    func loadAll() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchHabitStats(userId: userId) }
            group.addTask { await self.fetchSessionStats(userId: userId) }
            group.addTask { await self.fetchSupplementStats(userId: userId) }
            group.addTask { await self.fetchHealthKitDistance() }
            group.addTask { await self.fetchPersonalBests(userId: userId) }
            group.addTask { await self.fetchMostRecentPB(userId: userId) }
        }
    }

    // MARK: - Daily Summary (set from DailyActionsView)

    func updateDailySummary(completed: Int, total: Int) {
        todayCompletionPct = total > 0 ? Int((Double(completed) / Double(total)) * 100) : 0
    }

    // MARK: - Decode structs

    private struct IDRow: Decodable { let id: UUID }

    private struct HabitLogRow: Decodable {
        let habitId: UUID
        let loggedDate: String
        enum CodingKeys: String, CodingKey {
            case habitId = "habit_id"
            case loggedDate = "logged_date"
        }
    }

    private struct AttendanceRow: Decodable {
        let attended: Bool
        let sessions: SessionDate
        struct SessionDate: Decodable {
            let proposedAt: String
            enum CodingKeys: String, CodingKey { case proposedAt = "proposed_at" }
        }
    }

    private struct SupplementLogDateRow: Decodable {
        let takenAt: String
        enum CodingKeys: String, CodingKey { case takenAt = "taken_at" }
    }

    private struct PersonalBestInsert: Encodable {
        let userId: UUID
        let category: String
        let eventName: String
        let value: Double
        let valueUnit: String
        let reps: Int?
        let isVerified: Bool
        let proofUrl: String?
        let isPublic: Bool
        let loggedAt: String
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case eventName = "event_name"
            case value, category, reps
            case valueUnit = "value_unit"
            case isVerified = "is_verified"
            case proofUrl = "proof_url"
            case isPublic = "is_public"
            case loggedAt = "logged_at"
        }
    }

    // MARK: - Habits

    private func fetchHabitStats(userId: UUID) async {
        do {
            let habits: [IDRow] = try await supabase
                .from("habits")
                .select("id")
                .eq("created_by", value: userId.uuidString)
                .eq("is_archived", value: false)
                .execute().value
            habitsCreated = habits.count

            let logs: [HabitLogRow] = try await supabase
                .from("habit_logs")
                .select("habit_id, logged_date")
                .eq("user_id", value: userId.uuidString)
                .execute().value
            habitLogsTotal = logs.count

            let expected = habitsCreated * 30
            habitCompletionPct = expected > 0 ? min(Double(habitLogsTotal) / Double(expected) * 100, 100) : 0

            let grouped = Dictionary(grouping: logs) { $0.habitId }
            habitBestStreak = grouped.values.map { rows in
                computeDayStreak(dates: rows.map { $0.loggedDate })
            }.max() ?? 0
        } catch {
            print("[ProgressVM] Habit stats error: \(error)")
        }
    }

    // MARK: - Sessions

    private func fetchSessionStats(userId: UUID) async {
        do {
            let rsvps: [IDRow] = try await supabase
                .from("rsvps")
                .select("id")
                .eq("user_id", value: userId.uuidString)
                .eq("status", value: "going")
                .execute().value
            sessionsRSVPd = rsvps.count

            let rows: [AttendanceRow] = try await supabase
                .from("attendance")
                .select("attended, sessions(proposed_at)")
                .eq("user_id", value: userId.uuidString)
                .execute().value

            // Bug 3b: exclude sessions scheduled in the future — they can't have
            // been attended yet. Filter client-side since the join column is not
            // directly queryable in PostgREST without a foreign-key filter.
            let now = Date()
            let past = rows.filter {
                guard let d = parseDate($0.sessions.proposedAt) else { return false }
                return d <= now
            }
            let attended = past.filter { $0.attended }
            sessionsAttended = attended.count
            sessionAttendancePct = past.isEmpty ? 0 : min(Double(sessionsAttended) / Double(past.count) * 100, 100)
            sessionBestStreak = computeSessionStreak(rows: past)
        } catch {
            print("[ProgressVM] Session stats error: \(error)")
        }
    }

    private func computeSessionStreak(rows: [AttendanceRow]) -> Int {
        let sorted = rows
            .compactMap { row -> (Date, Bool)? in
                guard let date = parseDate(row.sessions.proposedAt) else { return nil }
                return (date, row.attended)
            }
            .sorted { $0.0 < $1.0 }
        var best = 0, current = 0
        for (_, didAttend) in sorted {
            if didAttend { current += 1; best = max(best, current) }
            else { current = 0 }
        }
        return best
    }

    // MARK: - Supplements

    private func fetchSupplementStats(userId: UUID) async {
        do {
            let active: [IDRow] = try await supabase
                .from("supplements")
                .select("id")
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .eq("in_protocol", value: true)
                .execute().value
            supplementsActive = active.count

            let allLogs: [SupplementLogDateRow] = try await supabase
                .from("supplement_logs")
                .select("taken_at")
                .eq("user_id", value: userId.uuidString)
                .eq("taken", value: true)
                .execute().value
            supplementLogsTotal = allLogs.count

            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            let recentCount = allLogs.filter { log in
                guard let date = parseDate(log.takenAt) else { return false }
                return date >= thirtyDaysAgo
            }.count
            let expected = supplementsActive * 30
            supplementAdherencePct = expected > 0 ? min(Double(recentCount) / Double(expected) * 100, 100) : 0

            let dayStrings = allLogs.compactMap { log -> String? in
                guard let date = parseDate(log.takenAt) else { return nil }
                return dayString(from: date)
            }
            supplementBestStreak = computeDayStreak(dates: dayStrings)
        } catch {
            print("[ProgressVM] Supplement stats error: \(error)")
        }
    }

    // MARK: - HealthKit (all-time running distance)

    private func fetchHealthKitDistance() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        isLoadingHealth = true
        let type = HKQuantityType(.distanceWalkingRunning)
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [type])
        } catch {
            print("[ProgressVM] HealthKit auth error: \(error)")
            isLoadingHealth = false
            return
        }
        let km = await withCheckedContinuation { (cont: CheckedContinuation<Double, Never>) in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: nil,
                options: .cumulativeSum
            ) { _, stats, _ in
                let meters = stats?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                cont.resume(returning: meters / 1000)
            }
            healthStore.execute(query)
        }
        totalKmRun = km
        isLoadingHealth = false
    }

    // MARK: - Personal Bests

    func fetchPersonalBests(userId: UUID) async {
        isLoadingPBs = true
        do {
            let results: [PersonalBest] = try await supabase
                .from("personal_bests")
                .select("*")
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute().value
            personalBests = results
        } catch {
            print("[ProgressVM] Fetch PBs error: \(error)")
        }
        isLoadingPBs = false
    }

    func fetchPBsForUsers(userIds: [UUID]) async -> [UUID: [PersonalBest]] {
        guard !userIds.isEmpty else { return [:] }
        do {
            let rows: [PersonalBest] = try await supabase
                .from("personal_bests")
                .select()
                .in("user_id", values: userIds.map { $0.uuidString })
                .execute()
                .value
            var result: [UUID: [PersonalBest]] = [:]
            for pb in rows {
                result[pb.userId, default: []].append(pb)
            }
            return result
        } catch {
            print("fetchPBsForUsers error: \(error)")
            return [:]
        }
    }

    private func fetchMostRecentPB(userId: UUID) async {
        do {
            let pbs: [PersonalBest] = try await supabase
                .from("personal_bests")
                .select("*")
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(1)
                .execute().value

            if let pb = pbs.first {
                let valueStr = pb.value.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(pb.value))" : String(format: "%.1f", pb.value)
                let unitSuffix = pb.valueUnit.isEmpty ? "" : " \(pb.valueUnit)"
                mostRecentPBSummary = "\(pb.eventName) — \(valueStr)\(unitSuffix)"
            } else {
                mostRecentPBSummary = "No PBs yet — add one!"
            }
        } catch {
            print("[ProgressVM] Most recent PB error: \(error)")
            mostRecentPBSummary = "No PBs yet — add one!"
        }
    }

    func detectNewPBs(userId: UUID) async {
        var found: [(label: String, value: String)] = []

        // Check session streak
        if sessionBestStreak > 0 {
            let storedSessionPB = personalBests.filter { $0.category == "sessions" }.map { $0.value }.max() ?? 0
            if Double(sessionBestStreak) > storedSessionPB {
                found.append((label: "Session Streak", value: "\(sessionBestStreak) sessions"))
            }
        }

        // Check supplement streak
        if supplementBestStreak > 0 {
            let storedSupplementPB = personalBests.filter { $0.category == "supplements" }.map { $0.value }.max() ?? 0
            if Double(supplementBestStreak) > storedSupplementPB {
                found.append((label: "Supplement Streak", value: "\(supplementBestStreak) days"))
            }
        }

        // Check habit streak
        if habitBestStreak > 0 {
            let storedHabitPB = personalBests.filter { $0.category == "habits" }.map { $0.value }.max() ?? 0
            if Double(habitBestStreak) > storedHabitPB {
                found.append((label: "Habit Streak", value: "\(habitBestStreak) days"))
            }
        }

        detectedNewPBs = found
    }

    func addPersonalBest(
        userId: UUID,
        category: String,
        eventName: String,
        value: Double,
        valueUnit: String,
        reps: Int?,
        isVerified: Bool,
        proofUrl: String?,
        isPublic: Bool,
        loggedAt: Date
    ) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let row = PersonalBestInsert(
            userId: userId,
            category: category,
            eventName: eventName,
            value: value,
            valueUnit: valueUnit,
            reps: reps,
            isVerified: isVerified,
            proofUrl: proofUrl,
            isPublic: isPublic,
            loggedAt: formatter.string(from: loggedAt)
        )
        do {
            try await supabase
                .from("personal_bests")
                .insert(row)
                .execute()
            await fetchPersonalBests(userId: userId)
        } catch {
            print("[ProgressVM] Add PB error: \(error)")
        }
    }

    func deletePersonalBest(id: UUID, userId: UUID) async {
        do {
            try await supabase
                .from("personal_bests")
                .delete()
                .eq("id", value: id.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()
            personalBests.removeAll { $0.id == id }
        } catch {
            print("[ProgressVM] Delete PB error: \(error)")
        }
    }

    // MARK: - Group Coach Stats

    func fetchSessionsCompleted(userId: UUID, days: Int) async -> [(date: Date, count: Int)] {
        struct AttendanceMarkedRow: Decodable { let marked_at: String }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let cutoff = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let cutoffStr = iso.string(from: cutoff)

        var countsByDay: [Date: Int] = [:]
        for offset in 0..<days {
            if let day = calendar.date(byAdding: .day, value: offset, to: cutoff) {
                countsByDay[calendar.startOfDay(for: day)] = 0
            }
        }

        do {
            let rows: [AttendanceMarkedRow] = try await supabase
                .from("attendance")
                .select("marked_at")
                .eq("user_id", value: userId.uuidString)
                .eq("attended", value: true)
                .gte("marked_at", value: cutoffStr)
                .execute().value
            for row in rows {
                guard let date = parseDate(row.marked_at) else { continue }
                let day = calendar.startOfDay(for: date)
                if countsByDay[day] != nil {
                    countsByDay[day]! += 1
                }
            }
        } catch {
            print("[ProgressVM] fetchSessionsCompleted error: \(error)")
        }

        return countsByDay.keys.sorted().map { day in (date: day, count: countsByDay[day]!) }
    }

    // Bug 3a: denominator was count*days for every habit — ignoring frequency,
    // days_of_week, weekly_target, monthly_target, target_count, target_date.
    // New logic: per-habit scheduled occurrences in the window.
    //   daily         → days × target_count
    //   specific_days → (matching weekdays in window) × target_count
    //   weekly        → (ISO weeks touched) × weekly_target
    //   monthly       → (calendar months touched) × monthly_target
    //   once          → 1 if target_date in window, else 0
    func fetchHabitAdherence(userId: UUID, days: Int) async -> Double {
        struct HabitRow: Decodable {
            let id: UUID
            let frequency: String
            let daysOfWeek: String?
            let weeklyTarget: Int?
            let monthlyTarget: Int?
            let targetCount: Int?
            let targetDate: String?
            enum CodingKeys: String, CodingKey {
                case id, frequency
                case daysOfWeek = "days_of_week"
                case weeklyTarget = "weekly_target"
                case monthlyTarget = "monthly_target"
                case targetCount = "target_count"
                case targetDate = "target_date"
            }
        }
        struct LogRow: Decodable {
            let habitId: UUID
            let loggedDate: String
            let count: Int
            enum CodingKeys: String, CodingKey {
                case habitId = "habit_id"
                case loggedDate = "logged_date"
                case count
            }
        }
        do {
            let habits: [HabitRow] = try await supabase
                .from("habits")
                .select("id, frequency, days_of_week, weekly_target, monthly_target, target_count, target_date")
                .eq("created_by", value: userId.uuidString)
                .eq("is_archived", value: false)
                .execute().value

            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let windowStart = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return 0.0 }
            let dfmt = DateFormatter()
            dfmt.dateFormat = "yyyy-MM-dd"
            let cutoffStr = dfmt.string(from: windowStart)

            let logs: [LogRow] = try await supabase
                .from("habit_logs")
                .select("habit_id, logged_date, count")
                .eq("user_id", value: userId.uuidString)
                .gte("logged_date", value: cutoffStr)
                .execute().value
            var logCountsByHabit: [UUID: Int] = [:]
            for log in logs {
                logCountsByHabit[log.habitId, default: 0] += log.count
            }

            // Build window-day bucket sets once (weekday abbr + year-week + year-month).
            let wdFmt = DateFormatter()
            wdFmt.dateFormat = "EEE"
            wdFmt.locale = Locale(identifier: "en_US_POSIX")
            var weekdayCounts: [String: Int] = [:]
            var weeksTouched = Set<String>()
            var monthsTouched = Set<String>()
            for i in 0..<days {
                guard let d = calendar.date(byAdding: .day, value: i, to: windowStart) else { continue }
                weekdayCounts[wdFmt.string(from: d), default: 0] += 1
                let wk = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)
                weeksTouched.insert("\(wk.yearForWeekOfYear ?? 0)-\(wk.weekOfYear ?? 0)")
                let ym = calendar.dateComponents([.year, .month], from: d)
                monthsTouched.insert("\(ym.year ?? 0)-\(ym.month ?? 0)")
            }
            let weeksInWindow = max(weeksTouched.count, 1)
            let monthsInWindow = max(monthsTouched.count, 1)

            var totalDenom = 0
            var totalNum = 0
            for habit in habits {
                let tc = max(habit.targetCount ?? 1, 1)
                let denom: Int
                switch habit.frequency {
                case "daily":
                    denom = days * tc
                case "specific_days":
                    let targets = (habit.daysOfWeek ?? "")
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                    var match = 0
                    for t in targets { match += weekdayCounts[String(t)] ?? 0 }
                    denom = match * tc
                case "weekly":
                    denom = weeksInWindow * max(habit.weeklyTarget ?? 1, 1)
                case "monthly":
                    denom = monthsInWindow * max(habit.monthlyTarget ?? 1, 1)
                case "once":
                    if let tdStr = habit.targetDate, let td = dfmt.date(from: tdStr) {
                        denom = (td >= windowStart && td <= today) ? 1 : 0
                    } else {
                        denom = 0
                    }
                default:
                    denom = days * tc
                }
                let num = min(logCountsByHabit[habit.id] ?? 0, denom)
                totalDenom += denom
                totalNum += num
            }
            guard totalDenom > 0 else { return 0.0 }
            return min(1.0, Double(totalNum) / Double(totalDenom))
        } catch {
            return 0.0
        }
    }

    // Bug 3a: denominator now respects supplement.days_of_week. Supplement schedule
    // format is either "everyday" or a CSV of weekday numbers (1=Sun … 7=Sat per
    // Calendar.component(.weekday)).
    func fetchSupplementAdherence(userId: UUID, days: Int) async -> Double {
        struct SuppRow: Decodable {
            let id: UUID
            let daysOfWeek: String
            let createdAt: String
            enum CodingKeys: String, CodingKey {
                case id
                case daysOfWeek = "days_of_week"
                case createdAt = "created_at"
            }
        }
        struct SuppLogRow: Decodable {
            let supplementId: UUID
            enum CodingKeys: String, CodingKey {
                case supplementId = "supplement_id"
            }
        }
        do {
            let supps: [SuppRow] = try await supabase
                .from("supplements")
                .select("id, days_of_week, created_at")
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .eq("in_protocol", value: true)
                .execute().value

            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let windowStart = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return 0.0 }
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            let cutoffStr = iso.string(from: windowStart)

            let logs: [SuppLogRow] = try await supabase
                .from("supplement_logs")
                .select("supplement_id")
                .eq("user_id", value: userId.uuidString)
                .eq("taken", value: true)
                .gte("taken_at", value: cutoffStr)
                .execute().value
            var logsBySupp: [UUID: Int] = [:]
            for log in logs {
                logsBySupp[log.supplementId, default: 0] += 1
            }

            // Count weekday occurrences in the window for fast per-supp denom math.
            var weekdayNumCounts: [Int: Int] = [:]
            for i in 0..<days {
                guard let d = calendar.date(byAdding: .day, value: i, to: windowStart) else { continue }
                let wd = calendar.component(.weekday, from: d)
                weekdayNumCounts[wd, default: 0] += 1
            }

            // Parse Supabase timestamptz (format "yyyy-MM-dd HH:mm:ssZ") with ISO8601 fallback.
            func parseSuppCreatedAt(_ s: String) -> Date? {
                let tzFmt = DateFormatter()
                tzFmt.dateFormat = "yyyy-MM-dd HH:mm:ssZ"
                tzFmt.locale = Locale(identifier: "en_US_POSIX")
                if let d = tzFmt.date(from: s) { return d }
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let d = iso.date(from: s) { return d }
                iso.formatOptions = [.withInternetDateTime]
                return iso.date(from: s)
            }

            var totalDenom = 0
            var totalNum = 0
            for supp in supps {
                // Anchor the window start to when the supplement was created so
                // pre-creation days don't inflate the denominator.
                let suppCreatedDate = parseSuppCreatedAt(supp.createdAt) ?? windowStart
                let effectiveStart = max(calendar.startOfDay(for: suppCreatedDate), windowStart)
                let rawEffectiveDays = (calendar.dateComponents([.day], from: effectiveStart, to: today).day ?? (days - 1)) + 1
                let effectiveDays = max(rawEffectiveDays, 1)

                let dow = supp.daysOfWeek
                let denom: Int
                if dow == "everyday" || dow.isEmpty {
                    denom = effectiveDays
                } else {
                    let targets = Set(dow.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) })
                    if effectiveStart == windowStart {
                        denom = targets.reduce(0) { $0 + (weekdayNumCounts[$1] ?? 0) }
                    } else {
                        var match = 0
                        for i in 0..<effectiveDays {
                            guard let d = calendar.date(byAdding: .day, value: i, to: effectiveStart) else { continue }
                            let wd = calendar.component(.weekday, from: d)
                            if targets.contains(wd) { match += 1 }
                        }
                        denom = match
                    }
                }
                let num = min(logsBySupp[supp.id] ?? 0, denom)
                totalDenom += denom
                totalNum += num
            }
            guard totalDenom > 0 else { return 0.0 }
            return min(1.0, Double(totalNum) / Double(totalDenom))
        } catch {
            return 0.0
        }
    }

    // MARK: - Progress Sheet Fetches

    func fetchSessionsAttended(userId: UUID, range: ProgressRange) async {
        do {
            struct AttendanceRow: Decodable {
                let attended: Bool
                let marked_at: String?
            }
            let rows: [AttendanceRow] = try await supabase
                .from("attendance")
                .select("attended, marked_at")
                .eq("user_id", value: userId.uuidString)
                .eq("attended", value: true)
                .execute().value

            totalSessionsAttended = rows.count

            let filtered = rows.compactMap { row -> Date? in
                guard let str = row.marked_at else { return nil }
                // Try ISO8601 with fractional seconds and timezone (Supabase default)
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let d = iso.date(from: str) { return d }
                // Fallback without fractional seconds
                let iso2 = ISO8601DateFormatter()
                iso2.formatOptions = [.withInternetDateTime]
                if let d = iso2.date(from: str) { return d }
                // Final fallback — date-only string
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                df.timeZone = TimeZone(identifier: "UTC")
                return df.date(from: String(str.prefix(10)))
            }.filter { date in
                switch range {
                case .weekly:
                    return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
                case .monthly:
                    return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
                case .allTime:
                    return true
                }
            }

            let calendar = Calendar.current

            // Group into buckets
            switch range {
            case .weekly:
                let days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
                var counts = [Int](repeating: 0, count: 7)
                for date in filtered {
                    let weekday = calendar.component(.weekday, from: date) - 1
                    counts[weekday] += 1
                }
                sessionStats = days.enumerated().map { SessionAttendanceStat(label: $0.element, count: counts[$0.offset]) }

            case .monthly:
                var counts = [Int](repeating: 0, count: 4)
                for date in filtered {
                    let day = calendar.component(.day, from: date)
                    let week = min((day - 1) / 7, 3)
                    counts[week] += 1
                }
                sessionStats = ["Wk 1","Wk 2","Wk 3","Wk 4"].enumerated().map { SessionAttendanceStat(label: $0.element, count: counts[$0.offset]) }

            case .allTime:
                var monthCounts: [String: Int] = [:]
                let labelFormatter = DateFormatter()
                labelFormatter.dateFormat = "MMM yy"
                for date in filtered {
                    let label = labelFormatter.string(from: date)
                    monthCounts[label, default: 0] += 1
                }
                let sorted = monthCounts.sorted { a, b in
                    let df = DateFormatter()
                    df.dateFormat = "MMM yy"
                    let da = df.date(from: a.key) ?? .distantPast
                    let db = df.date(from: b.key) ?? .distantPast
                    return da < db
                }
                sessionStats = sorted.map { SessionAttendanceStat(label: $0.key, count: $0.value) }
            }
        } catch {
            print("fetchSessionsAttended error: \(error)")
        }
    }

    func fetchAllTimeTotals(userId: UUID) async {
        do {
            struct HabitLogRow: Decodable { let id: UUID }
            let habitLogs: [HabitLogRow] = try await supabase
                .from("habit_logs")
                .select("id")
                .eq("user_id", value: userId.uuidString)
                .execute().value
            totalHabitDays = habitLogs.count

            struct SupLogRow: Decodable { let id: UUID }
            let supLogs: [SupLogRow] = try await supabase
                .from("supplement_logs")
                .select("id")
                .eq("user_id", value: userId.uuidString)
                .eq("taken", value: true)
                .execute().value
            totalSupplementsTaken = supLogs.count
        } catch {
            print("fetchAllTimeTotals error: \(error)")
        }
    }

    // MARK: - Apple Health Workout Imports

    // Bug 2: aggregates saved HealthKit workouts for the PersonalProgressSheet card.
    // Reads health_workout_imports rows where workout_date is within `days`.
    func fetchHealthWorkoutStats(userId: UUID, days: Int = 30) async {
        struct WorkoutRow: Decodable {
            let durationMinutes: Int?
            let calories: Int?
            enum CodingKeys: String, CodingKey {
                case durationMinutes = "duration_minutes"
                case calories
            }
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let cutoffStr = formatter.string(from: cutoff)
        do {
            let rows: [WorkoutRow] = try await supabase
                .from("health_workout_imports")
                .select("duration_minutes, calories")
                .eq("user_id", value: userId.uuidString)
                .gte("workout_date", value: cutoffStr)
                .execute().value
            await MainActor.run {
                self.importedWorkoutCount = rows.count
                self.importedWorkoutMinutes = rows.reduce(0) { $0 + ($1.durationMinutes ?? 0) }
                self.importedWorkoutCalories = rows.reduce(0) { $0 + ($1.calories ?? 0) }
                self.importedWorkoutWindowDays = days
            }
        } catch {
            print("[ProgressVM] fetchHealthWorkoutStats error: \(error)")
        }
    }

    func fetchPendingHealthWorkouts(userId: UUID) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        // 1. Get all already-imported workout dates from Supabase
        do {
            struct DateRow: Decodable {
                let workoutDate: String
                enum CodingKeys: String, CodingKey { case workoutDate = "workout_date" }
            }
            let imported: [DateRow] = try await supabase
                .from("health_workout_imports")
                .select("workout_date")
                .eq("user_id", value: userId.uuidString)
                .execute().value
            importedWorkoutDates = Set(imported.map { $0.workoutDate })
        } catch {
            print("[ProgressVM] fetchImportedDates error: \(error)")
        }

        // 2. Get attendance dates from OnTrack sessions (to avoid double-counting)
        var attendanceDates: Set<String> = []
        do {
            struct MarkedRow: Decodable {
                let markedAt: String?
                enum CodingKeys: String, CodingKey { case markedAt = "marked_at" }
            }
            let rows: [MarkedRow] = try await supabase
                .from("attendance")
                .select("marked_at")
                .eq("user_id", value: userId.uuidString)
                .eq("attended", value: true)
                .execute().value
            for row in rows {
                guard let str = row.markedAt else { continue }
                let prefix = String(str.prefix(10))
                attendanceDates.insert(prefix)
            }
        } catch {
            print("[ProgressVM] fetchAttendanceDates error: \(error)")
        }

        // 3. Filter HealthKit recent workouts — exclude any date already in OnTrack or already imported
        let recentWorkouts = HealthKitManager.shared.recentWorkouts
        let pending = recentWorkouts.filter { workout in
            let dateStr = formatter.string(from: workout.startDate)
            return !attendanceDates.contains(dateStr) && !importedWorkoutDates.contains(dateStr)
        }

        await MainActor.run {
            self.pendingHealthWorkouts = pending
        }
    }

    func saveHealthWorkout(_ workout: HKWorkout, userId: UUID) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: workout.startDate)
        let durationMins = Int(workout.duration / 60)
        let calories: Int? = if let eb = workout.totalEnergyBurned { Int(eb.doubleValue(for: .kilocalorie())) } else { nil }
        let workoutType = workout.workoutActivityType.displayName

        struct InsertRow: Encodable {
            let userId: UUID
            let workoutType: String
            let durationMinutes: Int
            let calories: Int?
            let workoutDate: String
            let source: String
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case workoutType = "workout_type"
                case durationMinutes = "duration_minutes"
                case calories
                case workoutDate = "workout_date"
                case source
            }
        }

        do {
            let row = InsertRow(userId: userId, workoutType: workoutType, durationMinutes: durationMins, calories: calories, workoutDate: dateStr, source: "apple_health")
            try await supabase
                .from("health_workout_imports")
                .insert(row)
                .execute()
            await MainActor.run {
                pendingHealthWorkouts.removeAll { $0.uuid == workout.uuid }
                importedWorkoutDates.insert(dateStr)
                totalSessionsAttended += 1
            }
        } catch {
            print("[ProgressVM] saveHealthWorkout error: \(error)")
        }
    }

    func dismissHealthWorkout(_ workout: HKWorkout) {
        pendingHealthWorkouts.removeAll { $0.uuid == workout.uuid }
    }

    // MARK: - Helpers

    private func parseDate(_ string: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: string) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: string)
    }

    private func dayString(from date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    private func computeDayStreak(dates: [String]) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        let days = Set(dates.compactMap { formatter.date(from: $0) }
            .map { calendar.startOfDay(for: $0) })
        let sorted = days.sorted(by: >)
        guard !sorted.isEmpty else { return 0 }
        var best = 1, current = 1
        for i in 1..<sorted.count {
            let diff = calendar.dateComponents([.day], from: sorted[i], to: sorted[i - 1]).day ?? 0
            if diff == 1 { current += 1; best = max(best, current) }
            else { current = 1 }
        }
        return best
    }
}

// MARK: - HKWorkoutActivityType Display Names

extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .walking: return "Walking"
        case .hiking: return "Hiking"
        case .rowing: return "Rowing"
        case .functionalStrengthTraining: return "Strength Training"
        case .traditionalStrengthTraining: return "Weights"
        case .crossTraining: return "Cross Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .boxing: return "Boxing"
        case .soccer: return "Soccer"
        case .basketball: return "Basketball"
        case .tennis: return "Tennis"
        case .surfingSports: return "Surfing"
        case .elliptical: return "Elliptical"
        case .stairClimbing: return "Stair Climbing"
        default: return "Workout"
        }
    }
}
