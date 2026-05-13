import Foundation
import Observation
import Supabase

/// Lightweight flow-state holder for the Quick-Log FAB. Owns no persistent data —
/// it just drives the "log a workout" action. Supplement logging goes through the
/// existing `SupplementViewModel`; habit logging through `HabitViewModel`.
@MainActor
@Observable
final class QuickLogViewModel {
    var isWorking = false
    var errorMessage: String?

    /// Workout/session types offered by the Session tile. Raw value is the display label.
    enum WorkoutType: String, CaseIterable, Identifiable {
        case weights = "Weights"
        case cardio  = "Cardio"
        case run     = "Run"
        case hike    = "Hike"
        case swim    = "Swim"
        case yoga    = "Yoga"
        case cycle   = "Cycle"
        case other   = "Other"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .weights: return "dumbbell.fill"
            case .cardio:  return "bolt.heart.fill"
            case .run:     return "figure.run"
            case .hike:    return "figure.hiking"
            case .swim:    return "figure.pool.swim"
            case .yoga:    return "figure.yoga"
            case .cycle:   return "bicycle"
            case .other:   return "ellipsis.circle.fill"
            }
        }
    }

    private struct NewQuickLog: Encodable {
        let userId: String
        let category: String
        let note: String?
        let durationMinutes: Int?
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case category
            case note
            case durationMinutes = "duration_minutes"
        }
    }

    private struct NewSession: Encodable {
        let title: String
        let groupId: UUID?
        let status: String
        let proposedAt: String
        let createdBy: String
        let visibility: String
        let sessionType: String
        enum CodingKeys: String, CodingKey {
            case title
            case groupId = "group_id"
            case status
            case proposedAt = "proposed_at"
            case createdBy = "created_by"
            case visibility
            case sessionType = "session_type"
        }
    }

    private struct NewAttendance: Encodable {
        let sessionId: UUID
        let userId: UUID
        let attended: Bool
        let markedBy: UUID
        enum CodingKeys: String, CodingKey {
            case sessionId = "session_id"
            case userId = "user_id"
            case attended
            case markedBy = "marked_by"
        }
    }

    private struct InsertedSession: Decodable {
        let id: UUID
    }

    /// Logs a completed workout. Priority:
    ///  - `matchedHabit` non-nil AND not already logged today → insert a `habit_logs`
    ///    row via `HabitViewModel.toggleHabit` (which inserts when no log exists).
    ///    NOTE: `toggleHabit` is destructive on an existing log, so the caller (or
    ///    this method) must only invoke it when `logForHabit(...) == nil`.
    ///  - `matchedHabit` already logged today → treated as success, no write.
    ///  - otherwise → insert a `quick_logs` row.
    /// Returns true on success.
    func logWorkout(type: WorkoutType,
                    durationMinutes: Int?,
                    userId: UUID,
                    matchedHabit: Habit?,
                    habitVM: HabitViewModel) async -> Bool {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        if let habit = matchedHabit {
            if habitVM.logForHabit(habit, on: Date(), userId: userId) == nil {
                await habitVM.toggleHabit(habit, on: Date(), userId: userId)
                if let err = habitVM.errorMessage {
                    errorMessage = err
                    return false
                }
            }
            return true
        }

        let note: String? = durationMinutes.map { "\($0) min" }
        let payload = NewQuickLog(
            userId: userId.uuidString.lowercased(),
            category: type.rawValue.lowercased(),
            note: note,
            durationMinutes: durationMinutes
        )
        do {
            try await supabase.from("quick_logs").insert(payload).execute()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Logs a personal (non-group) session: inserts a `sessions` row with
    /// `group_id = nil`, then a matching `attendance` row marking the user
    /// attended. Returns the new session UUID on success, nil on failure.
    /// Used by Quick-Log when the chosen workout type has no matching habit.
    func logPersonalSession(type: WorkoutType,
                            durationMinutes: Int?,
                            userId: UUID) async -> UUID? {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        let proposedAt = ISO8601DateFormatter().string(from: Date())
        let sessionPayload = NewSession(
            title: type.rawValue,
            groupId: nil,
            status: "completed",
            proposedAt: proposedAt,
            createdBy: userId.uuidString.lowercased(),
            visibility: "friends",
            sessionType: type.rawValue.lowercased()
        )

        do {
            let inserted: InsertedSession = try await supabase
                .from("sessions")
                .insert(sessionPayload)
                .select()
                .single()
                .execute()
                .value

            let attendancePayload = NewAttendance(
                sessionId: inserted.id,
                userId: userId,
                attended: true,
                markedBy: userId
            )
            try await supabase
                .from("attendance")
                .insert(attendancePayload)
                .execute()

            return inserted.id
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
