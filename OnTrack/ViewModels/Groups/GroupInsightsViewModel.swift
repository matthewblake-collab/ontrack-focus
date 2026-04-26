import Foundation
import Supabase

@Observable
final class GroupInsightsViewModel {
    var totalSessions: Int = 0
    var attendanceRate: Int = 0       // percentage 0–100
    var mostAttendedMember: String? = nil
    var totalRSVPs: Int = 0
    var isLoading = false

    // MARK: - Minimal decode structs

    private struct SessionIdRow: Decodable {
        let id: UUID
    }

    private struct AttendanceRow: Decodable {
        let userId: UUID
        let attended: Bool
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case attended
        }
    }

    private struct RSVPRow: Decodable {
        let id: UUID
    }

    private struct ProfileRow: Decodable {
        let id: UUID
        let displayName: String
        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
        }
    }

    // MARK: - Fetch

    func fetchInsights(groupId: UUID) async {
        isLoading = true

        // Step 1: non-cancelled sessions for this group
        let sessionIds = await fetchSessionIds(groupId: groupId)
        totalSessions = sessionIds.count

        guard !sessionIds.isEmpty else {
            isLoading = false
            return
        }

        let idStrings = sessionIds.map { $0.uuidString }

        // Step 2: attendance + RSVPs in parallel
        async let attendanceData = fetchAttendance(sessionIds: idStrings)
        async let rsvpData = fetchRSVPs(sessionIds: idStrings)
        let (attendance, rsvps) = await (attendanceData, rsvpData)

        totalRSVPs = rsvps

        // Attendance rate
        let attended = attendance.filter { $0.attended }
        attendanceRate = attendance.isEmpty ? 0 : Int(Double(attended.count) / Double(attendance.count) * 100)

        // Most attended member
        let grouped = Dictionary(grouping: attended) { $0.userId }
        if let topUserId = grouped.max(by: { $0.value.count < $1.value.count })?.key {
            mostAttendedMember = await fetchDisplayName(userId: topUserId)
        }

        isLoading = false
    }

    // MARK: - Private queries

    private func fetchSessionIds(groupId: UUID) async -> [UUID] {
        do {
            let now = ISO8601DateFormatter().string(from: Date())
            let rows: [SessionIdRow] = try await supabase
                .from("sessions")
                .select("id")
                .eq("group_id", value: groupId.uuidString)
                .neq("status", value: "cancelled")
                .lte("proposed_at", value: now)
                .execute()
                .value
            return rows.map { $0.id }
        } catch {
            return []
        }
    }

    private func fetchAttendance(sessionIds: [String]) async -> [AttendanceRow] {
        do {
            return try await supabase
                .from("attendance")
                .select("user_id, attended")
                .in("session_id", values: sessionIds)
                .execute()
                .value
        } catch {
            return []
        }
    }

    private func fetchRSVPs(sessionIds: [String]) async -> Int {
        do {
            let rows: [RSVPRow] = try await supabase
                .from("rsvps")
                .select("id")
                .in("session_id", values: sessionIds)
                .execute()
                .value
            return rows.count
        } catch {
            return 0
        }
    }

    private func fetchDisplayName(userId: UUID) async -> String? {
        do {
            let row: ProfileRow = try await supabase
                .from("profiles")
                .select("id, display_name")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            return row.displayName
        } catch {
            return nil
        }
    }
}
