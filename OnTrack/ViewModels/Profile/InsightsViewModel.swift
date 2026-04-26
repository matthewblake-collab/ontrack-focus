import Foundation
import Supabase

@Observable
final class InsightsViewModel {
    var sessionsAttended: Int = 0
    var supplementsTaken: Int = 0
    var longestCurrentStreak: Int = 0
    var mostConsistentHabit: String? = nil
    var isLoading = false

    // MARK: - Minimal decode structs (only fields we need)

    private struct AttendanceRow: Decodable {
        let id: UUID
    }

    private struct SupplementLogRow: Decodable {
        let id: UUID
    }

    private struct HabitLogRow: Decodable {
        let habitId: UUID
        let loggedDate: String
        enum CodingKeys: String, CodingKey {
            case habitId = "habit_id"
            case loggedDate = "logged_date"
        }
    }

    private struct HabitRow: Decodable {
        let id: UUID
        let name: String
    }

    // MARK: - Fetch

    func fetchInsights(userId: UUID) async {
        isLoading = true
        async let attended = fetchSessionsAttended(userId: userId)
        async let supps = fetchSupplementsTaken(userId: userId)
        async let habitStats = fetchHabitStats(userId: userId)
        let (a, s, stats) = await (attended, supps, habitStats)
        sessionsAttended = a
        supplementsTaken = s
        longestCurrentStreak = stats.0
        mostConsistentHabit = stats.1
        isLoading = false
    }

    private func fetchSessionsAttended(userId: UUID) async -> Int {
        // Bug 3b: only count attended rows whose session.proposed_at has already
        // elapsed. Future scheduled sessions can't have been attended yet.
        struct JoinedRow: Decodable {
            let attended: Bool
            let sessions: SessionDate
            struct SessionDate: Decodable {
                let proposedAt: String
                enum CodingKeys: String, CodingKey { case proposedAt = "proposed_at" }
            }
        }
        do {
            let rows: [JoinedRow] = try await supabase
                .from("attendance")
                .select("attended, sessions(proposed_at)")
                .eq("user_id", value: userId.uuidString)
                .eq("attended", value: true)
                .execute()
                .value
            let now = Date()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let alt = ISO8601DateFormatter()
            alt.formatOptions = [.withInternetDateTime]
            return rows.filter {
                let s = $0.sessions.proposedAt
                let d = formatter.date(from: s) ?? alt.date(from: s)
                return (d ?? .distantFuture) <= now
            }.count
        } catch {
            return 0
        }
    }

    private func fetchSupplementsTaken(userId: UUID) async -> Int {
        do {
            let rows: [SupplementLogRow] = try await supabase
                .from("supplement_logs")
                .select("id")
                .eq("user_id", value: userId.uuidString)
                .eq("taken", value: true)
                .execute()
                .value
            return rows.count
        } catch {
            return 0
        }
    }

    private func fetchHabitStats(userId: UUID) async -> (Int, String?) {
        do {
            // Fetch all non-archived habits created by this user
            let habits: [HabitRow] = try await supabase
                .from("habits")
                .select("id, name")
                .eq("created_by", value: userId.uuidString)
                .eq("is_archived", value: false)
                .execute()
                .value

            guard !habits.isEmpty else { return (0, nil) }

            // Fetch all logs for those habits
            let logs: [HabitLogRow] = try await supabase
                .from("habit_logs")
                .select("habit_id, logged_date")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            let streak = computeLongestStreak(logs: logs)
            let consistent = computeMostConsistent(logs: logs, habits: habits)
            return (streak, consistent)
        } catch {
            return (0, nil)
        }
    }

    // MARK: - Streak calculation

    private func computeLongestStreak(logs: [HabitLogRow]) -> Int {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let grouped = Dictionary(grouping: logs) { $0.habitId }
        var maxStreak = 0

        for (_, habitLogs) in grouped {
            let dateSet = Set(habitLogs.compactMap { formatter.date(from: $0.loggedDate) }
                .map { calendar.startOfDay(for: $0) })
            let sortedDates = dateSet.sorted(by: >)

            var checkDate = calendar.startOfDay(for: Date())

            // If today isn't logged, start counting from yesterday
            if !dateSet.contains(checkDate) {
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            }

            var streak = 0
            for date in sortedDates {
                if date == checkDate {
                    streak += 1
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
                } else if date < checkDate {
                    break
                }
            }
            maxStreak = max(maxStreak, streak)
        }
        return maxStreak
    }

    // MARK: - Most consistent habit (most logs in last 30 days)

    private func computeMostConsistent(logs: [HabitLogRow], habits: [HabitRow]) -> String? {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) else { return nil }

        let recentLogs = logs.filter {
            guard let date = formatter.date(from: $0.loggedDate) else { return false }
            return date >= thirtyDaysAgo
        }

        guard !recentLogs.isEmpty else { return nil }

        let counts = Dictionary(grouping: recentLogs) { $0.habitId }.mapValues { $0.count }
        guard let topId = counts.max(by: { $0.value < $1.value })?.key else { return nil }
        return habits.first { $0.id == topId }?.name
    }
}
