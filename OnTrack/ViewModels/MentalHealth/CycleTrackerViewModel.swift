import Foundation
import Supabase

// MARK: - Model

struct CycleLog: Decodable, Identifiable {
    let id: UUID
    let userId: UUID
    let periodStart: String
    let periodEnd: String?
    let cycleLength: Int?
    let symptoms: [String]?
    let notes: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case cycleLength = "cycle_length"
        case symptoms, notes
        case createdAt = "created_at"
    }

    var periodStartDate: Date {
        dateFromString(periodStart) ?? Date.distantPast
    }

    var periodEndDate: Date? {
        periodEnd.flatMap { dateFromString($0) }
    }

    private func dateFromString(_ s: String) -> Date? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: s)
    }
}

// MARK: - Phase

enum CyclePhase: Equatable {
    case menstrual, follicular, ovulation, luteal, overdue, unknown

    var name: String {
        switch self {
        case .menstrual:  return "Menstrual"
        case .follicular: return "Follicular"
        case .ovulation:  return "Ovulation"
        case .luteal:     return "Luteal"
        case .overdue:    return "Period Expected"
        case .unknown:    return "No Data"
        }
    }

    var icon: String {
        switch self {
        case .menstrual:  return "drop.fill"
        case .follicular: return "leaf.fill"
        case .ovulation:  return "sun.max.fill"
        case .luteal:     return "moon.fill"
        case .overdue:    return "clock.badge.exclamationmark"
        case .unknown:    return "circle.dashed"
        }
    }

    var color: String { // used as hint for tint
        switch self {
        case .menstrual:  return "red"
        case .follicular: return "green"
        case .ovulation:  return "yellow"
        case .luteal:     return "purple"
        default:          return "white"
        }
    }

    var trainingAdvice: String {
        switch self {
        case .menstrual:  return "Rest or gentle yoga — honour your body"
        case .follicular: return "High intensity training — energy is rising"
        case .ovulation:  return "Peak performance window — push hard"
        case .luteal:     return "Light to moderate — avoid overtraining"
        default:          return "—"
        }
    }

    var supplementAdvice: String {
        switch self {
        case .menstrual:  return "Iron, vitamin C to replenish"
        case .follicular: return "B vitamins, omega-3 for energy"
        case .ovulation:  return "Zinc, antioxidants for peak output"
        case .luteal:     return "Magnesium to ease PMS symptoms"
        default:          return "—"
        }
    }

    var moodAdvice: String {
        switch self {
        case .menstrual:  return "Energy likely low — rest is productive"
        case .follicular: return "Mood lifting — great time to plan ahead"
        case .ovulation:  return "High energy and confidence — lean in"
        case .luteal:     return "PMS possible — track stress and sleep"
        default:          return "—"
        }
    }
}

// MARK: - ViewModel

@Observable
class CycleTrackerViewModel {

    var logs: [CycleLog] = []
    var todayCheckIn: TodayCheckIn? = nil
    var isLoading = false
    var isSubmitting = false
    var errorMessage: String? = nil

    // MARK: - Computed phase data

    var mostRecentLog: CycleLog? { logs.first }

    var avgCycleLength: Int {
        let lengths = logs.compactMap { $0.cycleLength }
        guard !lengths.isEmpty else { return 28 }
        return lengths.reduce(0, +) / lengths.count
    }

    var dayOfCycle: Int? {
        guard let log = mostRecentLog else { return nil }
        let cal = Calendar.current
        let start = cal.startOfDay(for: log.periodStartDate)
        let today = cal.startOfDay(for: Date())
        let days = cal.dateComponents([.day], from: start, to: today).day ?? 0
        return days + 1
    }

    var currentPhase: CyclePhase {
        guard let day = dayOfCycle else { return .unknown }
        if day > avgCycleLength { return .overdue }
        switch day {
        case 1...5:  return .menstrual
        case 6...13: return .follicular
        case 14...16: return .ovulation
        default:     return .luteal
        }
    }

    var daysUntilNext: Int? {
        guard let day = dayOfCycle, currentPhase != .overdue else { return nil }
        return max(0, avgCycleLength - day)
    }

    // MARK: - Fetch

    func fetch(userId: String) async {
        guard !userId.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())

        do {
            async let logsResult: [CycleLog] = supabase
                .from("cycle_logs")
                .select()
                .eq("user_id", value: userId.lowercased())
                .order("period_start", ascending: false)
                .execute()
                .value

            async let checkInResult: [TodayCheckIn] = supabase
                .from("daily_checkins")
                .select("stress, energy, mood")
                .eq("user_id", value: userId.lowercased())
                .eq("checkin_date", value: today)
                .limit(1)
                .execute()
                .value

            let (fetchedLogs, fetchedCheckIn) = try await (logsResult, checkInResult)

            await MainActor.run {
                self.logs = fetchedLogs
                self.todayCheckIn = fetchedCheckIn.first
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    // MARK: - Log period

    func logPeriod(
        userId: String,
        start: Date,
        end: Date?,
        symptoms: [String],
        notes: String
    ) async {
        guard !userId.isEmpty else { return }
        isSubmitting = true

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        let startStr = fmt.string(from: start)
        let endStr = end.map { fmt.string(from: $0) }

        // Auto-calculate cycle_length from gap to previous period_start
        let computedLength: Int?
        if let previous = mostRecentLog {
            let cal = Calendar.current
            let days = cal.dateComponents([.day], from: previous.periodStartDate, to: start).day
            computedLength = (days ?? 0) > 0 ? days : nil
        } else {
            computedLength = nil
        }

        struct CycleLogInsert: Encodable {
            let user_id: String
            let period_start: String
            let period_end: String?
            let cycle_length: Int?
            let symptoms: [String]?
            let notes: String?
        }

        let payload = CycleLogInsert(
            user_id: userId.lowercased(),
            period_start: startStr,
            period_end: endStr,
            cycle_length: computedLength,
            symptoms: symptoms.isEmpty ? nil : symptoms,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        )

        do {
            try await supabase
                .from("cycle_logs")
                .insert(payload)
                .execute()
            await fetch(userId: userId)
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }

        await MainActor.run { self.isSubmitting = false }
    }
}

// MARK: - Private decode struct

struct TodayCheckIn: Decodable {
    let stress: Int?
    let energy: Int?
    let mood: Int?
}
