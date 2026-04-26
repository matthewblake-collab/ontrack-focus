import Foundation
import Supabase

enum RecurrenceRule: String, CaseIterable, Identifiable {
    case none = "none"
    case weekly = "weekly"
    case fortnightly = "fortnightly"
    case monthly = "monthly"
    case custom = "custom"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Does not repeat"
        case .weekly: return "Weekly"
        case .fortnightly: return "Fortnightly"
        case .monthly: return "Monthly"
        case .custom: return "Custom dates"
        }
    }

    var calendarComponent: Calendar.Component? {
        switch self {
        case .none, .custom: return nil
        case .weekly: return .weekOfYear
        case .fortnightly: return .weekOfYear
        case .monthly: return .month
        }
    }

    var interval: Int {
        switch self {
        case .fortnightly: return 2
        default: return 1
        }
    }
}

@Observable
final class SessionViewModel {
    static let sessionTypes = ["Weights", "Cardio", "Hybrid", "Hike", "Sports Training", "Swim", "Yoga", "Cycling", "Run", "Other"]

    var sessions: [AppSession] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var newTitle: String = ""
    var newDescription: String = ""
    var newLocation: String = ""
    var newSessionType: String = ""
    var newProposedAt: Date = Date()
    var newVisibility: String = "private"
    var recurrenceRule: RecurrenceRule = .none
    var recurrenceEndDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    var customDates: [Date] = []

    func fetchAllSessions() async {
        isLoading = true
        errorMessage = nil
        do {
            let result: [AppSession] = try await supabase
                .from("sessions")
                .select()
                .neq("status", value: "cancelled")
                .order("proposed_at", ascending: true)
                .execute()
                .value
            self.sessions = result
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func fetchSessions(groupId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            let result: [AppSession] = try await supabase
                .from("sessions")
                .select()
                .eq("group_id", value: groupId.uuidString)
                .order("proposed_at", ascending: true)
                .execute()
                .value
            self.sessions = result
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @discardableResult
    func createSession(groupId: UUID, userId: UUID) async -> AppSession? {
        isLoading = true
        errorMessage = nil
        var firstSession: AppSession?
        do {
            if recurrenceRule == .none {
                var payload: [String: String] = [
                    "group_id": groupId.uuidString,
                    "title": newTitle,
                    "description": newDescription,
                    "location": newLocation,
                    "proposed_at": ISO8601DateFormatter().string(from: newProposedAt),
                    "created_by": userId.uuidString,
                    "status": "upcoming",
                    "visibility": newVisibility
                ]
                if !newSessionType.isEmpty { payload["session_type"] = newSessionType }
                let created: AppSession = try await supabase
                    .from("sessions")
                    .insert(payload)
                    .select()
                    .single()
                    .execute()
                    .value
                firstSession = created
            } else if recurrenceRule == .custom {
                let seriesId = UUID()
                for (index, date) in customDates.enumerated() {
                    let finalDate = mergedCustomDate(date)
                    var payload: [String: String] = [
                        "group_id": groupId.uuidString,
                        "title": newTitle,
                        "description": newDescription,
                        "location": newLocation,
                        "proposed_at": ISO8601DateFormatter().string(from: finalDate),
                        "created_by": userId.uuidString,
                        "status": "upcoming",
                        "series_id": seriesId.uuidString,
                        "recurrence_rule": recurrenceRule.rawValue,
                        "visibility": newVisibility
                    ]
                    if !newSessionType.isEmpty { payload["session_type"] = newSessionType }
                    let created: AppSession = try await supabase
                        .from("sessions")
                        .insert(payload)
                        .select()
                        .single()
                        .execute()
                        .value
                    if index == 0 { firstSession = created }
                }
            } else {
                let seriesId = UUID()
                let dates = generateDates()
                for (index, date) in dates.enumerated() {
                    var payload: [String: String] = [
                        "group_id": groupId.uuidString,
                        "title": newTitle,
                        "description": newDescription,
                        "location": newLocation,
                        "proposed_at": ISO8601DateFormatter().string(from: date),
                        "created_by": userId.uuidString,
                        "status": "upcoming",
                        "series_id": seriesId.uuidString,
                        "recurrence_rule": recurrenceRule.rawValue,
                        "visibility": newVisibility
                    ]
                    if !newSessionType.isEmpty { payload["session_type"] = newSessionType }
                    let created: AppSession = try await supabase
                        .from("sessions")
                        .insert(payload)
                        .select()
                        .single()
                        .execute()
                        .value
                    if index == 0 { firstSession = created }
                }
            }
            await fetchSessions(groupId: groupId)
            resetForm()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
        return firstSession
    }

    @discardableResult
    func createPersonalSession(userId: UUID) async -> AppSession? {
        isLoading = true
        errorMessage = nil
        var firstSession: AppSession?
        do {
            if recurrenceRule == .none {
                var payload: [String: String] = [
                    "title": newTitle,
                    "proposed_at": ISO8601DateFormatter().string(from: newProposedAt),
                    "created_by": userId.uuidString,
                    "status": "confirmed",
                    "visibility": "private"
                ]
                if !newDescription.isEmpty { payload["description"] = newDescription }
                if !newLocation.isEmpty { payload["location"] = newLocation }
                if !newSessionType.isEmpty { payload["session_type"] = newSessionType }
                let created: AppSession = try await supabase
                    .from("sessions")
                    .insert(payload)
                    .select()
                    .single()
                    .execute()
                    .value
                firstSession = created
            } else if recurrenceRule == .custom {
                let seriesId = UUID()
                for (index, date) in customDates.enumerated() {
                    let finalDate = mergedCustomDate(date)
                    var payload: [String: String] = [
                        "title": newTitle,
                        "proposed_at": ISO8601DateFormatter().string(from: finalDate),
                        "created_by": userId.uuidString,
                        "status": "confirmed",
                        "visibility": "private",
                        "series_id": seriesId.uuidString,
                        "recurrence_rule": recurrenceRule.rawValue
                    ]
                    if !newDescription.isEmpty { payload["description"] = newDescription }
                    if !newLocation.isEmpty { payload["location"] = newLocation }
                    if !newSessionType.isEmpty { payload["session_type"] = newSessionType }
                    let created: AppSession = try await supabase
                        .from("sessions")
                        .insert(payload)
                        .select()
                        .single()
                        .execute()
                        .value
                    if index == 0 { firstSession = created }
                }
            } else {
                let seriesId = UUID()
                let dates = generateDates()
                for (index, date) in dates.enumerated() {
                    var payload: [String: String] = [
                        "title": newTitle,
                        "proposed_at": ISO8601DateFormatter().string(from: date),
                        "created_by": userId.uuidString,
                        "status": "confirmed",
                        "visibility": "private",
                        "series_id": seriesId.uuidString,
                        "recurrence_rule": recurrenceRule.rawValue
                    ]
                    if !newDescription.isEmpty { payload["description"] = newDescription }
                    if !newLocation.isEmpty { payload["location"] = newLocation }
                    if !newSessionType.isEmpty { payload["session_type"] = newSessionType }
                    let created: AppSession = try await supabase
                        .from("sessions")
                        .insert(payload)
                        .select()
                        .single()
                        .execute()
                        .value
                    if index == 0 { firstSession = created }
                }
            }
            resetForm()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
        return firstSession
    }

    func cancelSession(sessionId: UUID, groupId: UUID) async {
        isLoading = true
        errorMessage = nil
        NotificationManager.shared.cancelSessionReminder(sessionId: sessionId)
        do {
            try await supabase
                .from("sessions")
                .update(["status": "cancelled"])
                .eq("id", value: sessionId.uuidString)
                .execute()
            await fetchSessions(groupId: groupId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func cancelSeries(seriesId: UUID, groupId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            struct IDRow: Decodable { let id: UUID }
            let upcoming: [IDRow] = try await supabase
                .from("sessions")
                .select("id")
                .eq("series_id", value: seriesId.uuidString)
                .eq("status", value: "upcoming")
                .execute()
                .value
            for row in upcoming {
                NotificationManager.shared.cancelSessionReminder(sessionId: row.id)
            }
            try await supabase
                .from("sessions")
                .update(["status": "cancelled"])
                .eq("series_id", value: seriesId.uuidString)
                .eq("status", value: "upcoming")
                .execute()
            await fetchSessions(groupId: groupId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func updateSession(session: AppSession) async {
        isLoading = true
        errorMessage = nil
        do {
            var payload: [String: String] = [
                "title": newTitle,
                "description": newDescription,
                "location": newLocation,
                "proposed_at": ISO8601DateFormatter().string(from: newProposedAt),
                "visibility": newVisibility
            ]
            if !newSessionType.isEmpty { payload["session_type"] = newSessionType }
            try await supabase
                .from("sessions")
                .update(payload)
                .eq("id", value: session.id.uuidString)
                .execute()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func generateDates() -> [Date] {
        var dates: [Date] = []
        var current = newProposedAt
        let calendar = Calendar.current
        guard let component = recurrenceRule.calendarComponent else { return [current] }
        while current <= recurrenceEndDate {
            dates.append(current)
            current = calendar.date(byAdding: component, value: recurrenceRule.interval, to: current) ?? current
        }
        return dates
    }

    // Re-applies the current start-time picker's hour/minute onto a custom-picked date so
    // edits to the time picker after selecting custom dates still take effect at submit.
    private func mergedCustomDate(_ date: Date) -> Date {
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: newProposedAt)
        var merged = calendar.dateComponents([.year, .month, .day], from: date)
        merged.hour = time.hour
        merged.minute = time.minute
        merged.second = 0
        return calendar.date(from: merged) ?? date
    }

    func resetForm() {
        newTitle = ""
        newDescription = ""
        newLocation = ""
        newProposedAt = Date()
        newSessionType = ""
        newVisibility = "friends"
        recurrenceRule = .none
        recurrenceEndDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
        customDates = []
        errorMessage = nil
    }
}
