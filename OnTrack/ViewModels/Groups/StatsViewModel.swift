import Foundation
import Supabase

struct MemberStats: Identifiable {
    let id: UUID
    let displayName: String
    let totalSessions: Int
    let attended: Int
    let attendanceRate: Double
    let currentStreak: Int
    let longestStreak: Int
    let rsvpAccuracy: Double
    let rsvpGoingCount: Int

    var attendanceRateText: String {
        "\(Int(attendanceRate * 100))%"
    }

    var rsvpAccuracyText: String {
        rsvpGoingCount == 0 ? "N/A" : "\(Int(rsvpAccuracy * 100))%"
    }
}

@Observable
final class StatsViewModel {
    var memberStats: [MemberStats] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil

    func fetchStats(groupId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            // Fetch all members
            let members: [GroupMember] = try await supabase
                .from("group_members")
                .select()
                .eq("group_id", value: groupId.uuidString)
                .execute()
                .value

            // Fetch all profiles
            let userIds = members.map { $0.userId.uuidString }
            let profiles: [Profile] = try await supabase
                .from("profiles")
                .select()
                .in("id", values: userIds)
                .execute()
                .value

            // Fetch all completed sessions
            let sessions: [AppSession] = try await supabase
                .from("sessions")
                .select()
                .eq("group_id", value: groupId.uuidString)
                .eq("status", value: "completed")
                .order("proposed_at", ascending: true)
                .execute()
                .value

            // Fetch all attendance records
            let sessionIds = sessions.map { $0.id.uuidString }
            var attendance: [Attendance] = []
            if !sessionIds.isEmpty {
                attendance = try await supabase
                    .from("attendance")
                    .select()
                    .in("session_id", values: sessionIds)
                    .execute()
                    .value
            }

            // Fetch all RSVPs
            var rsvps: [RSVP] = []
            if !sessionIds.isEmpty {
                rsvps = try await supabase
                    .from("rsvps")
                    .select()
                    .in("session_id", values: sessionIds)
                    .execute()
                    .value
            }

            // Calculate stats per member
            var stats: [MemberStats] = []
            for member in members {
                let profile = profiles.first { $0.id == member.userId }
                let name = profile?.displayName ?? "Unknown"

                let memberAttendance = attendance.filter { $0.userId == member.userId }
                let attended = memberAttendance.filter { $0.attended }.count
                let totalSessions = sessions.count
                let attendanceRate = totalSessions > 0 ? Double(attended) / Double(totalSessions) : 0

                // Calculate streaks
                var currentStreak = 0
                var longestStreak = 0
                var tempStreak = 0
                for session in sessions.sorted(by: { ($0.proposedAt ?? Date.distantPast) < ($1.proposedAt ?? Date.distantPast) }) {
                    let didAttend = memberAttendance.first { $0.sessionId == session.id }?.attended ?? false
                    if didAttend {
                        tempStreak += 1
                        longestStreak = max(longestStreak, tempStreak)
                    } else {
                        tempStreak = 0
                    }
                }
                // Current streak = streak from most recent sessions
                for session in sessions.sorted(by: { ($0.proposedAt ?? Date.distantPast) > ($1.proposedAt ?? Date.distantPast) }) {
                    let didAttend = memberAttendance.first { $0.sessionId == session.id }?.attended ?? false
                    if didAttend {
                        currentStreak += 1
                    } else {
                        break
                    }
                }

                // RSVP accuracy
                let memberRSVPs = rsvps.filter { $0.userId == member.userId && $0.status == "going" }
                let rsvpGoingCount = memberRSVPs.count
                var rsvpAccurateCount = 0
                for rsvp in memberRSVPs {
                    if let attendanceRecord = memberAttendance.first(where: { $0.sessionId == rsvp.sessionId }) {
                        if attendanceRecord.attended { rsvpAccurateCount += 1 }
                    }
                }
                let rsvpAccuracy = rsvpGoingCount > 0 ? Double(rsvpAccurateCount) / Double(rsvpGoingCount) : 0

                stats.append(MemberStats(
                    id: member.userId,
                    displayName: name,
                    totalSessions: totalSessions,
                    attended: attended,
                    attendanceRate: attendanceRate,
                    currentStreak: currentStreak,
                    longestStreak: longestStreak,
                    rsvpAccuracy: rsvpAccuracy,
                    rsvpGoingCount: rsvpGoingCount
                ))
            }

            self.memberStats = stats.sorted { $0.attendanceRate > $1.attendanceRate }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
