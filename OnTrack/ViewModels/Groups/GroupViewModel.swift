import Foundation
import Supabase

@Observable
final class GroupViewModel {
    var groups: [AppGroup] = []
    var groupMembers: [UUID: [Profile]] = [:]
    var nextSessions: [UUID: AppSession] = [:]
    var nextSessionMyRSVPs: [UUID: String] = [:]  // groupId → user's RSVP status
    var sessionFreezes: [StreakFreeze] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var newGroupName: String = ""
    var newGroupDescription: String = ""
    var inviteCodeInput: String = ""

    func fetchGroups() async {
        isLoading = true
        errorMessage = nil
        do {
            let result: [AppGroup] = try await supabase
                .from("groups")
                .select()
                .execute()
                .value
            self.groups = result
            for group in result {
                await fetchMembers(for: group.id)
            }
            await fetchNextSessions()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func fetchMembers(for groupId: UUID) async {
        guard groupMembers[groupId] == nil else { return }
        do {
            struct MemberProfileRow: Decodable {
                let profiles: Profile
            }
            let rows: [MemberProfileRow] = try await supabase
                .from("group_members")
                .select("profiles(*)")
                .eq("group_id", value: groupId.uuidString)
                .execute()
                .value
            self.groupMembers[groupId] = rows.map { $0.profiles }
        } catch {
            print("[GroupViewModel] fetchMembers error: \(error.localizedDescription)")
        }
    }

    func fetchNextSessions() async {
        guard !groups.isEmpty else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        let groupIds = groups.map { $0.id.uuidString }
        do {
            let sessions: [AppSession] = try await supabase
                .from("sessions")
                .select()
                .in("group_id", values: groupIds)
                .gte("proposed_at", value: now)
                .order("proposed_at", ascending: true)
                .execute()
                .value
            var result: [UUID: AppSession] = [:]
            for session in sessions {
                if let gid = session.groupId, result[gid] == nil {
                    result[gid] = session
                }
            }
            self.nextSessions = result
        } catch {
            print("[GroupViewModel] fetchNextSessions error: \(error.localizedDescription)")
        }
    }

    func fetchNextSessionRSVPs(userId: UUID) async {
        let sessionEntries = nextSessions.filter { $0.value.proposedAt != nil }
        guard !sessionEntries.isEmpty else { return }
        let sessionIds = sessionEntries.map { $0.value.id.uuidString }
        do {
            struct RSVPRow: Decodable {
                let sessionId: UUID
                let status: String
                enum CodingKeys: String, CodingKey {
                    case sessionId = "session_id"
                    case status
                }
            }
            let rows: [RSVPRow] = try await supabase
                .from("rsvps")
                .select("session_id, status")
                .in("session_id", values: sessionIds)
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            // Build groupId → status map by reversing session→group lookup
            let sessionToGroup = Dictionary(uniqueKeysWithValues: sessionEntries.map { ($0.value.id, $0.key) })
            var result: [UUID: String] = [:]
            for row in rows {
                if let groupId = sessionToGroup[row.sessionId] {
                    result[groupId] = row.status
                }
            }
            self.nextSessionMyRSVPs = result
        } catch {
            print("[GroupViewModel] fetchNextSessionRSVPs error: \(error.localizedDescription)")
        }
    }

    func createGroup(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            let inviteCode = String(UUID().uuidString.prefix(8).uppercased())
            let newGroup: AppGroup = try await supabase
                .from("groups")
                .insert([
                    "name": newGroupName,
                    "description": newGroupDescription,
                    "invite_code": inviteCode,
                    "created_by": userId.uuidString
                ])
                .select()
                .single()
                .execute()
                .value
            try await supabase
                .from("group_members")
                .insert([
                    "group_id": newGroup.id.uuidString,
                    "user_id": userId.uuidString,
                    "role": "owner"
                ])
                .execute()
            AnalyticsManager.shared.track(.groupCreated)
            await fetchGroups()
            newGroupName = ""
            newGroupDescription = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func joinGroup(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            struct GroupLookup: Decodable {
                let id: UUID
                let name: String
            }
            guard let group: GroupLookup = try await supabase
                .rpc("get_group_by_invite_code", params: ["code": inviteCodeInput.uppercased()])
                .execute()
                .value
            else {
                errorMessage = "No group found with that invite code"
                isLoading = false
                return
            }
            try await supabase
                .from("group_members")
                .insert([
                    "group_id": group.id.uuidString,
                    "user_id": userId.uuidString,
                    "role": "member"
                ])
                .execute()
            await fetchGroups()
            inviteCodeInput = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func leaveGroup(groupId: UUID, userId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            try await supabase
                .from("group_members")
                .delete()
                .eq("group_id", value: groupId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()

            let formatter = ISO8601DateFormatter()
            let now = formatter.string(from: Date())

            struct SessionIDRow: Decodable { let id: UUID }
            let futureSessions: [SessionIDRow] = try await supabase
                .from("sessions")
                .select("id")
                .eq("group_id", value: groupId.uuidString)
                .gte("proposed_at", value: now)
                .execute()
                .value

            let futureSessionIds = futureSessions.map { $0.id.uuidString }
            if !futureSessionIds.isEmpty {
                try await supabase
                    .from("rsvps")
                    .delete()
                    .eq("user_id", value: userId.uuidString)
                    .in("session_id", values: futureSessionIds)
                    .execute()
            }

            // Cancel any local session reminders the leaving user had queued for this group.
            for row in futureSessions {
                NotificationManager.shared.cancelSessionReminder(sessionId: row.id)
            }

            groupMembers.removeValue(forKey: groupId)
            await fetchGroups()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Streak Logic

    /// Call this after attendance is confirmed for a user on a session.
    /// Pass the groupMemberId (the `id` field from group_members for this user+group combo).
    func incrementStreak(groupMemberId: UUID, currentStreak: Int, currentBest: Int) async {
        let newStreak = currentStreak + 1
        let newBest = max(newStreak, currentBest)
        do {
            try await supabase
                .from("group_members")
                .update([
                    "session_streak": String(newStreak),
                    "best_streak": String(newBest)
                ])
                .eq("id", value: groupMemberId.uuidString)
                .execute()
        } catch {
            print("[Streak] Error incrementing streak: \(error.localizedDescription)")
        }
    }

    /// Call this when a user RSVPd Going but didn't attend (24hrs after session).
    /// Checks for an active freeze before resetting — if a freeze covers yesterday, the streak is protected.
    func resetStreak(groupMemberId: UUID, userId: UUID) async {
        if isStreakFrozenYesterday(groupMemberId: groupMemberId) { return }
        do {
            try await supabase
                .from("group_members")
                .update([
                    "session_streak": "0"
                ])
                .eq("id", value: groupMemberId.uuidString)
                .execute()
        } catch {
            print("[Streak] Error resetting streak: \(error.localizedDescription)")
        }
    }

    // MARK: - Session Freeze

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Fetches session freezes for the current user's specific group membership.
    func fetchSessionFreezes(userId: UUID, groupMemberId: UUID) async {
        do {
            let fetched: [StreakFreeze] = try await supabase
                .from("streak_freezes")
                .select()
                .eq("user_id", value: userId.uuidString.lowercased())
                .eq("target_type", value: "session")
                .eq("target_id", value: groupMemberId.uuidString.lowercased())
                .execute()
                .value
            self.sessionFreezes = fetched
        } catch {
            // Non-fatal — streak display continues without freeze data
        }
    }

    /// Applies a session streak freeze for the missed day (yesterday).
    func applySessionFreeze(groupMemberId: UUID, userId: UUID) async {
        let missedDay = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
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
                    targetType: "session",
                    targetId: groupMemberId.uuidString.lowercased(),
                    freezeDate: missedDayStr
                ))
                .execute()
            await fetchSessionFreezes(userId: userId, groupMemberId: groupMemberId)
        } catch {
            // Silently ignore duplicate inserts (unique constraint)
        }
    }

    /// Returns true if no session freeze has been used for this group member in the current ISO week.
    func isSessionFreezeAvailable(groupMemberId: UUID) -> Bool {
        let cal = Calendar.current
        let now = Date()
        let currentWeek = cal.component(.weekOfYear, from: now)
        let currentYear = cal.component(.yearForWeekOfYear, from: now)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return !sessionFreezes.contains { freeze in
            guard freeze.targetType == "session",
                  freeze.targetId == groupMemberId,
                  let fd = formatter.date(from: freeze.freezeDate) else { return false }
            return cal.component(.weekOfYear, from: fd) == currentWeek &&
                   cal.component(.yearForWeekOfYear, from: fd) == currentYear
        }
    }

    /// Returns true if a freeze covers yesterday for the given group member.
    func isStreakFrozenYesterday(groupMemberId: UUID) -> Bool {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let ds = dateString(yesterday)
        return sessionFreezes.contains { $0.targetType == "session" && $0.targetId == groupMemberId && $0.freezeDate == ds }
    }

    // MARK: - Group Invites

    /// Sends an in-app group invite to a friend. Silently ignores duplicate invites (UNIQUE constraint).
    func inviteFriendToGroup(groupId: UUID, inviteeId: String, invitedBy: String) async {
        do {
            let invite = NewGroupInvite(groupId: groupId, inviteeId: inviteeId, invitedBy: invitedBy)
            try await supabase
                .from("group_invites")
                .insert(invite)
                .execute()
        } catch {
            print("❌ inviteFriendToGroup failed: \(error)")
        }
    }

    /// Accepts or declines a group invite. Accept calls the SECURITY DEFINER RPC which
    /// also inserts the user into group_members. Decline is a direct status update.
    func respondToGroupInvite(inviteId: UUID, accept: Bool) async {
        do {
            if accept {
                try await supabase
                    .rpc("accept_group_invite", params: ["invite_id": inviteId.uuidString.lowercased()])
                    .execute()
                NotificationCenter.default.post(name: .groupMembershipChanged, object: nil)
            } else {
                try await supabase
                    .from("group_invites")
                    .update(["status": "declined"])
                    .eq("id", value: inviteId)
                    .execute()
            }
        } catch {
            print("❌ respondToGroupInvite failed: \(error)")
        }
    }
}

extension Notification.Name {
    static let groupMembershipChanged = Notification.Name("groupMembershipChanged")
}
