import Foundation
import Supabase

@Observable
class FriendProfileViewModel {

    // MARK: - Published State
    var friendCode: String = ""
    var habitLogs: [HabitLog] = []
    var checkIns: [FriendCheckIn] = []
    var pbs: [PersonalBest] = []
    var currentUserPBs: [PersonalBest] = []
    var mutualGroups: [AppGroup] = []
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var totalCheckIns: Int = 0
    var currentUserStreak: Int = 0
    var currentUserCheckInCount: Int = 0
    var alreadyCheeredToday: Bool = false
    var isLoading: Bool = false

    // MARK: - Check-In Record (private decode type)
    struct FriendCheckIn: Decodable, Identifiable {
        let id: UUID
        let checkinDate: String
        let sleep: Int
        let energy: Int
        let wellbeing: Int
        let mood: Int?
        let stress: Int?
        enum CodingKeys: String, CodingKey {
            case id
            case checkinDate = "checkin_date"
            case sleep, energy, wellbeing, mood, stress
        }
    }

    // MARK: - Load All

    func loadAll(friendId: String, currentUserId: String) async {
        isLoading = true
        defer { isLoading = false }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())
        let sevenDaysAgo = fmt.string(from: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date())

        // Habit logs (streak + recent activity)
        async let logsTask: [HabitLog] = {
            do {
                return try await supabase
                    .from("habit_logs")
                    .select("*, habit:habits(id, name, is_private, created_by)")
                    .eq("user_id", value: friendId)
                    .order("logged_date", ascending: false)
                    .limit(30)
                    .execute()
                    .value
            } catch { return [] }
        }()

        // Check-ins (last 7 days)
        async let checkInsTask: [FriendCheckIn] = {
            do {
                return try await supabase
                    .from("daily_checkins")
                    .select("id, checkin_date, sleep, energy, wellbeing, mood, stress")
                    .eq("user_id", value: friendId)
                    .gte("checkin_date", value: sevenDaysAgo)
                    .order("checkin_date", ascending: true)
                    .execute()
                    .value
            } catch { return [] }
        }()

        // Friend's PBs
        async let pbsTask: [PersonalBest] = {
            do {
                return try await supabase
                    .from("personal_bests")
                    .select()
                    .eq("user_id", value: friendId)
                    .execute()
                    .value
            } catch { return [] }
        }()

        // Current user's PBs (for comparison strip)
        async let myPBsTask: [PersonalBest] = {
            do {
                return try await supabase
                    .from("personal_bests")
                    .select()
                    .eq("user_id", value: currentUserId)
                    .execute()
                    .value
            } catch { return [] }
        }()

        // Friend code
        async let codeTask: String = {
            do {
                struct FriendCodeRow: Decodable { let code: String }
                let rows: [FriendCodeRow] = try await supabase
                    .from("friend_codes")
                    .select("code")
                    .eq("user_id", value: friendId)
                    .limit(1)
                    .execute()
                    .value
                return rows.first?.code ?? ""
            } catch { return "" }
        }()

        // Current user's habit logs for streak comparison
        async let myLogsTask: [HabitLog] = {
            do {
                return try await supabase
                    .from("habit_logs")
                    .select("id, habit_id, user_id, logged_date, count, created_at")
                    .eq("user_id", value: currentUserId)
                    .order("logged_date", ascending: false)
                    .limit(30)
                    .execute()
                    .value
            } catch { return [] }
        }()

        // Current user's check-in count for last 7 days
        async let myCheckInTask: Int = {
            do {
                struct CountRow: Decodable { let id: UUID }
                let rows: [CountRow] = try await supabase
                    .from("daily_checkins")
                    .select("id")
                    .eq("user_id", value: currentUserId)
                    .gte("checkin_date", value: sevenDaysAgo)
                    .execute()
                    .value
                return rows.count
            } catch { return 0 }
        }()

        // Already cheered today?
        async let cheeredTask: Bool = {
            do {
                struct CheerRow: Decodable { let id: UUID }
                let rows: [CheerRow] = try await supabase
                    .from("cheers")
                    .select("id")
                    .eq("cheerer_id", value: currentUserId)
                    .eq("target_user_id", value: friendId)
                    .eq("cheer_date", value: today)
                    .limit(1)
                    .execute()
                    .value
                return !rows.isEmpty
            } catch { return false }
        }()

        // Await all parallel tasks
        let (logs, cins, friendPBs, myPBs, code, myLogs, myCheckIns, cheered) = await (
            logsTask, checkInsTask, pbsTask, myPBsTask, codeTask, myLogsTask, myCheckInTask, cheeredTask
        )

        habitLogs = logs
        checkIns = cins
        pbs = friendPBs
        currentUserPBs = myPBs
        friendCode = code
        alreadyCheeredToday = cheered
        totalCheckIns = cins.count
        currentUserCheckInCount = myCheckIns

        // Streaks
        currentStreak = calculateCurrentStreak(logs: logs)
        longestStreak = calculateLongestStreak(logs: logs)
        currentUserStreak = calculateCurrentStreak(logs: myLogs)

        // Mutual groups (sequential — needs intersection)
        await loadMutualGroups(friendId: friendId, currentUserId: currentUserId)
    }

    // MARK: - Mutual Groups

    private func loadMutualGroups(friendId: String, currentUserId: String) async {
        do {
            struct GroupMemberRow: Decodable {
                let groupId: String
                enum CodingKeys: String, CodingKey { case groupId = "group_id" }
            }
            let myRows: [GroupMemberRow] = try await supabase
                .from("group_members")
                .select("group_id")
                .eq("user_id", value: currentUserId)
                .execute()
                .value
            let friendRows: [GroupMemberRow] = try await supabase
                .from("group_members")
                .select("group_id")
                .eq("user_id", value: friendId)
                .execute()
                .value

            let myIDs = Set(myRows.map { $0.groupId })
            let friendIDs = Set(friendRows.map { $0.groupId })
            let mutualIDs = Array(myIDs.intersection(friendIDs))

            guard !mutualIDs.isEmpty else { mutualGroups = []; return }

            let groups: [AppGroup] = try await supabase
                .from("groups")
                .select()
                .in("id", values: mutualIDs)
                .execute()
                .value
            mutualGroups = groups
        } catch {
            mutualGroups = []
        }
    }

    // MARK: - Cheer

    func sendCheer(from cheererId: String, to targetId: String) async {
        do {
            struct NewCheer: Encodable {
                let cheererId: String
                let targetUserId: String
                enum CodingKeys: String, CodingKey {
                    case cheererId = "cheerer_id"
                    case targetUserId = "target_user_id"
                }
            }
            try await supabase
                .from("cheers")
                .insert(NewCheer(cheererId: cheererId, targetUserId: targetId))
                .execute()
            alreadyCheeredToday = true
        } catch {
            // UNIQUE violation = already cheered today — treat as success
            alreadyCheeredToday = true
        }
    }

    // MARK: - Streak Helpers

    private func calculateCurrentStreak(logs: [HabitLog]) -> Int {
        let dates = logs.compactMap { DateFormatter.habitDate.date(from: $0.loggedDate) }
            .sorted(by: >)
        guard !dates.isEmpty else { return 0 }
        var streak = 1
        for i in 1..<dates.count {
            let diff = Calendar.current.dateComponents([.day], from: dates[i], to: dates[i-1]).day ?? 0
            if diff == 1 { streak += 1 } else { break }
        }
        return streak
    }

    private func calculateLongestStreak(logs: [HabitLog]) -> Int {
        let dates = logs.compactMap { DateFormatter.habitDate.date(from: $0.loggedDate) }
            .sorted(by: >)
        guard !dates.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for i in 1..<dates.count {
            let diff = Calendar.current.dateComponents([.day], from: dates[i], to: dates[i-1]).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }
}
