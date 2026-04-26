import Foundation
import Supabase

@Observable
class FriendsViewModel {
    var friends: [Friendship] = []
    var pendingReceived: [Friendship] = []
    var pendingSent: [Friendship] = []
    var friendCode: String = ""
    var isLoading = false
    var errorMessage: String?
    var activeTodayIDs: Set<String> = []
    var mutualGroupCounts: [String: Int] = [:]

    // MARK: - Fetch

    func fetchFriends(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let lowerId = userId.lowercased()
            let all: [Friendship] = try await supabase
                .from("friendships")
                .select("""
                    id, requester_id, receiver_id, status, created_at,
                    requester:profiles!friendships_requester_id_fkey(id, display_name, avatar_url),
                    receiver:profiles!friendships_receiver_id_fkey(id, display_name, avatar_url)
                """)
                .or("requester_id.eq.\(lowerId),receiver_id.eq.\(lowerId)")
                .execute()
                .value

            friends = all.filter { $0.status == "accepted" }
            pendingReceived = all.filter { $0.status == "pending" && $0.receiverId.lowercased() == lowerId }
            pendingSent = all.filter { $0.status == "pending" && $0.requesterId.lowercased() == lowerId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchOrCreateFriendCode(userId: String) async {
        do {
            let existing: [FriendCode] = try await supabase
                .from("friend_codes")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            if let code = existing.first {
                friendCode = code.code
            } else {
                let newCode = String((0..<6).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
                let insert = NewFriendCode(userId: userId, code: newCode)
                let created: FriendCode = try await supabase
                    .from("friend_codes")
                    .insert(insert)
                    .select()
                    .single()
                    .execute()
                    .value
                friendCode = created.code
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Search

    func searchUsers(query: String, currentUserId: String) async -> [Profile] {
        do {
            struct SearchResult: Decodable {
                let id: UUID
                let display_name: String
                let avatar_url: String?
            }
            let results: [SearchResult] = try await supabase
                .rpc("search_connected_users", params: ["search_query": query])
                .execute()
                .value
            return results.map {
                Profile(id: $0.id, displayName: $0.display_name, avatarURL: $0.avatar_url, goals: [], createdAt: Date())
            }
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    func findUserByFriendCode(_ code: String) async -> Profile? {
        do {
            struct FriendCodeResult: Decodable {
                let id: UUID
                let display_name: String
                let avatar_url: String?
            }
            let results: [FriendCodeResult] = try await supabase
                .rpc("get_user_by_friend_code", params: ["code": code.uppercased()])
                .execute()
                .value
            guard let r = results.first else { return nil }
            return Profile(id: r.id, displayName: r.display_name, avatarURL: r.avatar_url, goals: [], createdAt: Date())
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Actions

    func sendFriendRequest(fromUserId: String, toUserId: String) async {
        do {
            let request = NewFriendship(requesterId: fromUserId.lowercased(), receiverId: toUserId.lowercased())
            try await supabase
                .from("friendships")
                .insert(request)
                .execute()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ sendFriendRequest failed: \(error)")
            print("❌ fromUserId: \(fromUserId), toUserId: \(toUserId)")
        }
    }

    func acceptFriendRequest(friendshipId: String, currentUserId: String, otherUserId: String) async {
        do {
            // Accept the incoming request
            try await supabase
                .from("friendships")
                .update(["status": "accepted", "updated_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: friendshipId)
                .execute()
            // Delete any reverse pending request (they may have also sent one)
            try await supabase
                .from("friendships")
                .delete()
                .eq("requester_id", value: currentUserId)
                .eq("receiver_id", value: otherUserId)
                .eq("status", value: "pending")
                .execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func declineFriendRequest(friendshipId: String) async {
        do {
            try await supabase
                .from("friendships")
                .update(["status": "declined", "updated_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: friendshipId)
                .execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeFriend(friendshipId: String) async {
        do {
            try await supabase
                .from("friendships")
                .delete()
                .eq("id", value: friendshipId)
                .execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Habit Invites

    func inviteFriendToHabit(habitId: String, friendUserId: String, invitedBy: String) async {
        do {
            let invite = NewHabitMember(habitId: habitId, userId: friendUserId, invitedBy: invitedBy)
            try await supabase
                .from("habit_members")
                .insert(invite)
                .execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func respondToHabitInvite(habitMemberId: String, accept: Bool) async {
        do {
            try await supabase
                .from("habit_members")
                .update(["status": accept ? "accepted" : "declined"])
                .eq("id", value: habitMemberId)
                .execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Social Feed

    func fetchMilestones(userIds: [String]) async -> [Milestone] {
        guard !userIds.isEmpty else { return [] }
        do {
            let logs: [HabitLog] = try await supabase
                .from("habit_logs")
                .select("*, habit:habits(id, name, is_private, created_by)")
                .in("user_id", values: userIds)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value

            // Group by user+habit and find streaks
            var milestones: [Milestone] = []
            let grouped = Dictionary(grouping: logs) { "\($0.userId)-\($0.habitId)" }
            for (_, habitLogs) in grouped {
                let streak = calculateStreak(logs: habitLogs)
                let milestoneStreaks = [7, 14, 30, 60, 100]
                if milestoneStreaks.contains(streak), let first = habitLogs.first {
                    milestones.append(Milestone(
                        userId: first.userId.uuidString,
                        habitId: first.habitId.uuidString,
                        habitName: first.habit?.name,
                        isPrivate: first.habit?.isPrivate ?? false,
                        streakCount: streak,
                        achievedAt: first.loggedDate
                    ))
                }
            }
            return milestones.sorted { $0.achievedAt > $1.achievedAt }
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    // MARK: - Active Today & Mutual Groups

    func fetchActiveTodayStatus(friendIds: [String]) async {
        guard !friendIds.isEmpty else { return }
        let today = DateFormatter.habitDate.string(from: Date())
        do {
            struct LogUserRow: Decodable {
                let userId: String
                enum CodingKeys: String, CodingKey { case userId = "user_id" }
            }
            let rows: [LogUserRow] = try await supabase
                .from("habit_logs")
                .select("user_id")
                .in("user_id", values: friendIds)
                .eq("logged_date", value: today)
                .execute()
                .value
            activeTodayIDs = Set(rows.map { $0.userId })
        } catch {
            activeTodayIDs = []
        }
    }

    func fetchMutualGroupCounts(currentUserId: String, friendIds: [String]) async {
        guard !friendIds.isEmpty else { return }
        do {
            struct GroupMemberRow: Decodable {
                let groupId: String
                let userId: String
                enum CodingKeys: String, CodingKey { case groupId = "group_id", userId = "user_id" }
            }
            // Fetch current user's groups
            let myRows: [GroupMemberRow] = try await supabase
                .from("group_members")
                .select("group_id, user_id")
                .eq("user_id", value: currentUserId)
                .execute()
                .value
            let myGroupIDs = Set(myRows.map { $0.groupId })

            // Fetch all friends' groups in one query
            let friendRows: [GroupMemberRow] = try await supabase
                .from("group_members")
                .select("group_id, user_id")
                .in("user_id", values: friendIds)
                .execute()
                .value

            // Group by user_id and count intersections
            var counts: [String: Int] = [:]
            let byFriend = Dictionary(grouping: friendRows) { $0.userId }
            for friendId in friendIds {
                let friendGroupIDs = Set((byFriend[friendId] ?? []).map { $0.groupId })
                counts[friendId] = myGroupIDs.intersection(friendGroupIDs).count
            }
            mutualGroupCounts = counts
        } catch {
            mutualGroupCounts = [:]
        }
    }

    private func calculateStreak(logs: [HabitLog]) -> Int {
        let dates = logs.compactMap { $0.loggedDate }
            .compactMap { DateFormatter.habitDate.date(from: $0) }
            .sorted(by: >)
        guard !dates.isEmpty else { return 0 }
        var streak = 1
        for i in 1..<dates.count {
            let diff = Calendar.current.dateComponents([.day], from: dates[i], to: dates[i-1]).day ?? 0
            if diff == 1 { streak += 1 } else { break }
        }
        return streak
    }
}

extension DateFormatter {
    static let habitDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
