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
}
