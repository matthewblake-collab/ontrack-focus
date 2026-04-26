import Foundation
import Supabase

struct MemberWellnessSummary: Identifiable {
    let id: UUID
    let name: String
    let avgSleep: Double?
    let avgEnergy: Double?
    let avgWellbeing: Double?
    let checkInCount: Int
    let habitCompletions: Int
    let attendanceRate: Double?
}

private struct CoachCheckInRow: Decodable {
    let user_id: UUID
    let sleep: Int?
    let energy: Int?
    let wellbeing: Int?
}

private struct CoachHabitLogRow: Decodable {
    let user_id: UUID
}

private struct CoachAttendanceRow: Decodable {
    let user_id: UUID
    let attended: Bool
}

private struct CoachShareSettingRow: Decodable {
    let user_id: UUID
    let share_wellness_with_coach: Bool
}

@Observable
class CoachWellnessViewModel {
    var members: [MemberWellnessSummary] = []
    var teamInsight: String = ""
    var isLoadingData = false
    var isLoadingInsight = false
    var errorMessage: String? = nil

    private let service = AIInsightService()

    func load(groupId: UUID, memberProfiles: [(id: UUID, name: String)]) {
        isLoadingData = true
        errorMessage = nil

        Task {
            do {
                let sevenDaysAgo = ISO8601DateFormatter().string(
                    from: Calendar.current.date(byAdding: .day, value: -7, to: Date())!
                )

                let memberIds = memberProfiles.map { $0.id.uuidString }

                // 1. Check who has opted in (share_wellness_with_coach = true)
                // For now we include all members — opt-in column added in next step
                // Fetch check-ins for all members
                let checkIns: [CoachCheckInRow] = try await supabase
                    .from("daily_checkins")
                    .select("user_id, sleep, energy, wellbeing")
                    .in("user_id", values: memberIds)
                    .gte("created_at", value: sevenDaysAgo)
                    .execute()
                    .value

                // 2. Habit logs
                let habitLogs: [CoachHabitLogRow] = try await supabase
                    .from("habit_logs")
                    .select("user_id")
                    .in("user_id", values: memberIds)
                    .gte("logged_date", value: sevenDaysAgo)
                    .execute()
                    .value

                // 3. Attendance
                let attendance: [CoachAttendanceRow] = try await supabase
                    .from("attendance")
                    .select("user_id, attended")
                    .in("user_id", values: memberIds)
                    .execute()
                    .value

                // Build summaries
                var summaries: [MemberWellnessSummary] = []
                for profile in memberProfiles {
                    let myCheckIns = checkIns.filter { $0.user_id == profile.id }
                    let myHabits = habitLogs.filter { $0.user_id == profile.id }
                    let myAttendance = attendance.filter { $0.user_id == profile.id }

                    let avgSleep = myCheckIns.compactMap { $0.sleep }.average
                    let avgEnergy = myCheckIns.compactMap { $0.energy }.average
                    let avgWellbeing = myCheckIns.compactMap { $0.wellbeing }.average

                    let attendedCount = myAttendance.filter { $0.attended }.count
                    let attendanceRate: Double? = myAttendance.isEmpty ? nil :
                        Double(attendedCount) / Double(myAttendance.count)

                    summaries.append(MemberWellnessSummary(
                        id: profile.id,
                        name: profile.name,
                        avgSleep: avgSleep,
                        avgEnergy: avgEnergy,
                        avgWellbeing: avgWellbeing,
                        checkInCount: myCheckIns.count,
                        habitCompletions: myHabits.count,
                        attendanceRate: attendanceRate
                    ))
                }

                await MainActor.run {
                    self.members = summaries
                    self.isLoadingData = false
                }

            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoadingData = false
                }
            }
        }
    }

    func generateTeamInsight() {
        isLoadingInsight = true
        Task {
            do {
                let lines = members.map { m -> String in
                    let sleep = m.avgSleep.map { String(format: "%.1f", $0) } ?? "N/A"
                    let energy = m.avgEnergy.map { String(format: "%.1f", $0) } ?? "N/A"
                    let wellbeing = m.avgWellbeing.map { String(format: "%.1f", $0) } ?? "N/A"
                    let att = m.attendanceRate.map { String(format: "%.0f%%", $0 * 100) } ?? "N/A"
                    return "\(m.name): Sleep \(sleep)/10, Energy \(energy)/10, Wellbeing \(wellbeing)/10, Attendance \(att), Habits \(m.habitCompletions)"
                }.joined(separator: "\n")

                let prompt = """
                You are a sports coach reviewing your team's wellness data from the last 7 days. Give a short, constructive team summary (3-5 sentences). Highlight one team strength and one area to focus on. Plain text only, no markdown, no bullet points.

                Team data:
                \(lines)
                """

                let result = try await service.generateInsight(prompt: prompt)
                await MainActor.run {
                    self.teamInsight = result
                    self.isLoadingInsight = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingInsight = false
                }
            }
        }
    }
}

private extension Array where Element == Int {
    var average: Double? {
        isEmpty ? nil : Double(reduce(0, +)) / Double(count)
    }
}
