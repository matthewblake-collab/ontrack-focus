import Foundation
import Supabase

@Observable
final class AttendanceViewModel {
    var records: [Attendance] = []
    var members: [GroupMember] = []
    var profiles: [Profile] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil

    func fetchAttendance(sessionId: UUID, groupId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            let fetchedRecords: [Attendance] = try await supabase
                .from("attendance")
                .select()
                .eq("session_id", value: sessionId.uuidString)
                .execute()
                .value
            self.records = fetchedRecords

            let fetchedMembers: [GroupMember] = try await supabase
                .from("group_members")
                .select()
                .eq("group_id", value: groupId.uuidString)
                .execute()
                .value
            self.members = fetchedMembers

            let userIds = fetchedMembers.map { $0.userId.uuidString }
            let fetchedProfiles: [Profile] = try await supabase
                .from("profiles")
                .select()
                .in("id", values: userIds)
                .execute()
                .value
            self.profiles = fetchedProfiles
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    var attendedCount: Int { records.filter { $0.attended }.count }
    var absentCount: Int { members.count - attendedCount }

    func markAttendance(sessionId: UUID, userId: UUID, attended: Bool, markedBy: UUID, groupId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            let _: Attendance = try await supabase
                .from("attendance")
                .upsert([
                    "session_id": sessionId.uuidString,
                    "user_id": userId.uuidString,
                    "attended": attended ? "true" : "false",
                    "marked_by": markedBy.uuidString,
                    "marked_at": ISO8601DateFormatter().string(from: Date())
                ], onConflict: "session_id,user_id")
                .select()
                .single()
                .execute()
                .value
            if let index = records.firstIndex(where: { $0.userId == userId }) {
                records[index].attended = attended
            } else {
                await fetchAttendance(sessionId: sessionId, groupId: groupId)
            }
            if attended {
                if let member = members.first(where: { $0.userId == userId }) {
                    let newStreak = member.sessionStreak + 1
                    let newBest = max(newStreak, member.bestStreak)
                    try await supabase
                        .from("group_members")
                        .update([
                            "session_streak": String(newStreak),
                            "best_streak": String(newBest)
                        ])
                        .eq("id", value: member.id.uuidString)
                        .execute()
                    if let mIndex = members.firstIndex(where: { $0.userId == userId }) {
                        members[mIndex].sessionStreak = newStreak
                        members[mIndex].bestStreak = newBest
                    }
                }
            } else {
                if let member = members.first(where: { $0.userId == userId }) {
                    try await supabase
                        .from("group_members")
                        .update(["session_streak": "0"])
                        .eq("id", value: member.id.uuidString)
                        .execute()
                    if let mIndex = members.firstIndex(where: { $0.userId == userId }) {
                        members[mIndex].sessionStreak = 0
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func profileName(for userId: UUID) -> String {
        profiles.first { $0.id == userId }?.displayName ?? "Unknown"
    }

    func attendanceStatus(for userId: UUID) -> Bool? {
        records.first { $0.userId == userId }?.attended
    }
}
