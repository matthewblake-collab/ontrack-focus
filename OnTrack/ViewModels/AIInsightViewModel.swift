import Foundation
import Supabase

// MARK: - Private AI-prefixed row structs (avoid conflicts)

private struct AICheckInRow: Decodable {
    let checkin_date: String
    let sleep: Int?
    let energy: Int?
    let wellbeing: Int?
    let mood: Int?
    let stress: Int?
}

private struct AIHabitLogRow: Decodable {
    let logged_date: String
    let habit_id: String
}

private struct AISupplementLogRow: Decodable {
    let taken_at: String
    let supplement_id: String
}

private struct AIAttendanceRow: Decodable {
    let session_id: String
    let attended: Bool
}

// MARK: - ViewModel

@Observable
class AIInsightViewModel {

    var insight: String = ""
    var isLoading: Bool = false
    var errorMessage: String? = nil

    private let service = AIInsightService()

    // UserDefaults keys
    private let cachedInsightKey = "ai_insight_cached_text"
    private let cachedInsightDateKey = "ai_insight_cached_date"

    // MARK: - 6pm reset logic
    // Returns the most recent 6pm in local time that has already passed
    private var lastResetDate: Date {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        let now = Date()
        var components = cal.dateComponents([.year, .month, .day], from: now)
        components.hour = 18
        components.minute = 0
        components.second = 0
        let todaySixPM = cal.date(from: components)!
        if now >= todaySixPM {
            return todaySixPM
        } else {
            // Before 6pm today — last reset was yesterday at 6pm
            return cal.date(byAdding: .day, value: -1, to: todaySixPM)!
        }
    }

    private var hasFreshCache: Bool {
        guard
            let cachedText = UserDefaults.standard.string(forKey: cachedInsightKey),
            !cachedText.isEmpty,
            let cachedDate = UserDefaults.standard.object(forKey: cachedInsightDateKey) as? Date
        else { return false }
        return cachedDate >= lastResetDate
    }

    // MARK: - Load

    func load(userId: String, forceRefresh: Bool = false) {
        guard !userId.isEmpty else { return }

        // Show cached insight if still fresh and not forcing a refresh
        if !forceRefresh, hasFreshCache,
           let cached = UserDefaults.standard.string(forKey: cachedInsightKey) {
            self.insight = cached
            return
        }

        isLoading = true
        errorMessage = nil
        insight = ""

        Task {
            do {
                let prompt = try await buildPrompt(userId: userId)
                let result = try await service.generateInsight(prompt: prompt)
                await MainActor.run {
                    self.insight = result
                    self.isLoading = false
                    // Cache the result with current timestamp
                    UserDefaults.standard.set(result, forKey: self.cachedInsightKey)
                    UserDefaults.standard.set(Date(), forKey: self.cachedInsightDateKey)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Could not load insight: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Build prompt from real Supabase data

    private func buildPrompt(userId: String, days: Int = 30, sessionsCompleted: Int = 0, habitAdherence: Double = 0.0, supplementAdherence: Double = 0.0) async throws -> String {
        let sevenDaysAgo = ISO8601DateFormatter().string(
            from: Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        )

        // 1. Check-ins
        let checkIns: [AICheckInRow] = try await supabase
            .from("daily_checkins")
            .select("checkin_date, sleep, energy, wellbeing, mood, stress")
            .eq("user_id", value: userId)
            .gte("checkin_date", value: sevenDaysAgo)
            .order("checkin_date", ascending: false)
            .execute()
            .value

        // 2. Habit logs
        let habitLogs: [AIHabitLogRow] = try await supabase
            .from("habit_logs")
            .select("logged_date, habit_id")
            .eq("user_id", value: userId)
            .gte("logged_date", value: sevenDaysAgo)
            .execute()
            .value

        // 3. Supplement logs
        let suppLogs: [AISupplementLogRow] = try await supabase
            .from("supplement_logs")
            .select("taken_at, supplement_id")
            .eq("user_id", value: userId)
            .gte("taken_at", value: sevenDaysAgo)
            .execute()
            .value

        // 4. Attendance
        let attendanceRows: [AIAttendanceRow] = try await supabase
            .from("attendance")
            .select("session_id, attended")
            .eq("user_id", value: userId)
            .execute()
            .value

        let attendedCount = attendanceRows.filter { $0.attended }.count
        let totalCount = attendanceRows.count

        // Build readable summaries
        let checkInSummary: String
        if checkIns.isEmpty {
            checkInSummary = "No check-ins recorded in the last 7 days."
        } else {
            let lines = checkIns.prefix(7).map { row -> String in
                let date = String(row.checkin_date.prefix(10))
                let sleep = row.sleep.map { "\($0)/10" } ?? "N/A"
                let energy = row.energy.map { "\($0)/10" } ?? "N/A"
                let wellbeing = row.wellbeing.map { "\($0)/10" } ?? "N/A"
                let mood = row.mood.map { "\($0)/10" } ?? "N/A"
                let stress = row.stress.map { "\($0)/10" } ?? "N/A"
                return "\(date): Sleep \(sleep), Energy \(energy), Wellbeing \(wellbeing), Mood \(mood), Stress \(stress)"
            }
            checkInSummary = lines.joined(separator: "\n")
        }

        let habitSummary = habitLogs.isEmpty
            ? "No habits logged this week."
            : "\(habitLogs.count) habit completions logged in the last 7 days."

        let suppSummary = suppLogs.isEmpty
            ? "No supplements logged this week."
            : "\(suppLogs.count) supplement doses logged in the last 7 days."

        let attendanceSummary = totalCount == 0
            ? "No session attendance data."
            : "Attended \(attendedCount) of \(totalCount) total sessions."

        return """
        You are a supportive wellness coach. Based on the user's check-in data (including sleep, energy, wellbeing, mood, and stress levels), session attendance, habit completion, and supplement adherence, give a short, warm, personalised insight (3-5 sentences). Highlight one strength and one area to focus on. Do not use markdown formatting — plain text only, no bullet points, no asterisks, no bold.

        Check-ins:
        \(checkInSummary)

        Activity data (last \(days) days):
        - Sessions completed: \(sessionsCompleted)
        - Habit adherence: \(Int(habitAdherence * 100))%
        - Supplement adherence: \(Int(supplementAdherence * 100))%

        Habits: \(habitSummary)
        Supplements: \(suppSummary)
        Attendance: \(attendanceSummary)
        """
    }
}
