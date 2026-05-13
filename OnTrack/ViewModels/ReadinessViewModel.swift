import Foundation
import Supabase
import WidgetKit

@Observable
final class ReadinessViewModel {
    var snapshot: ReadinessSnapshot?
    var isLoading = false
    private var lastKnownNextItem: String?

    init() {
        self.snapshot = ReadinessSnapshot.load()
        self.lastKnownNextItem = self.snapshot?.nextIncompleteItemName
        NotificationCenter.default.addObserver(
            forName: .readinessShouldRefresh,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            guard let userId = note.userInfo?["userId"] as? UUID else { return }
            let nextItem = note.userInfo?["nextIncompleteItemName"] as? String ?? self.lastKnownNextItem
            Task { await self.refresh(userId: userId, nextIncompleteItemName: nextItem) }
        }
    }

    @MainActor
    func refresh(userId: UUID, nextIncompleteItemName: String?) async {
        isLoading = true
        defer { isLoading = false }
        if let name = nextIncompleteItemName { lastKnownNextItem = name }

        let hk = HealthKitManager.shared
        await hk.fetchAll()

        let userIdString = userId.uuidString.lowercased()
        let today = Self.todayString()
        let sevenDaysAgo = Self.iso8601(daysAgo: 7)
        let twelveHoursAgo = Self.iso8601(hoursAgo: 12)

        async let checkinAvg = Self.fetchCheckinAvg(userId: userIdString, date: today)
        async let attendance7d = Self.fetchAttendance7dCount(userId: userIdString, since: sevenDaysAgo)
        async let workout12h = Self.fetchWorkoutLast12h(userId: userIdString, since: twelveHoursAgo)

        let (avg, attCount, didWorkout) = await (checkinAvg, attendance7d, workout12h)

        let inputs = ReadinessInputs(
            sleepHours: hk.sleepHours,
            hrvMs: hk.heartRateVariability,
            rhrBpm: hk.restingHeartRate,
            checkinAvg: avg,
            attendance7dCount: attCount,
            workoutLast12h: didWorkout
        )

        let (score, breakdown) = inputs.computeScore()
        let snap = ReadinessSnapshot(
            score: score,
            computedAt: Date(),
            nextIncompleteItemName: nextIncompleteItemName,
            breakdown: breakdown
        )
        snap.save()
        self.snapshot = snap
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Supabase fetches

    private struct CheckinRow: Decodable {
        let sleep: Int
        let energy: Int
        let wellbeing: Int
    }

    private struct AttendanceCountRow: Decodable {
        let id: String
    }

    private static func fetchCheckinAvg(userId: String, date: String) async -> Double? {
        do {
            let rows: [CheckinRow] = try await supabase
                .from("daily_checkins")
                .select("sleep, energy, wellbeing")
                .eq("user_id", value: userId)
                .eq("checkin_date", value: date)
                .limit(1)
                .execute()
                .value
            guard let row = rows.first else { return nil }
            return Double(row.sleep + row.energy + row.wellbeing) / 3.0
        } catch {
            return nil
        }
    }

    private static func fetchAttendance7dCount(userId: String, since: String) async -> Int {
        do {
            let rows: [AttendanceCountRow] = try await supabase
                .from("attendance")
                .select("id")
                .eq("user_id", value: userId)
                .eq("attended", value: true)
                .gte("marked_at", value: since)
                .execute()
                .value
            return rows.count
        } catch {
            return 0
        }
    }

    private static func fetchWorkoutLast12h(userId: String, since: String) async -> Bool {
        do {
            let attRows: [AttendanceCountRow] = try await supabase
                .from("attendance")
                .select("id")
                .eq("user_id", value: userId)
                .eq("attended", value: true)
                .gte("marked_at", value: since)
                .limit(1)
                .execute()
                .value
            if !attRows.isEmpty { return true }
        } catch {}
        do {
            let qlRows: [AttendanceCountRow] = try await supabase
                .from("quick_logs")
                .select("id")
                .eq("user_id", value: userId)
                .gte("logged_at", value: since)
                .limit(1)
                .execute()
                .value
            return !qlRows.isEmpty
        } catch {
            return false
        }
    }

    // MARK: - Date helpers

    private static func todayString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    private static func iso8601(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return ISO8601DateFormatter().string(from: date)
    }

    private static func iso8601(hoursAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .hour, value: -hoursAgo, to: Date()) ?? Date()
        return ISO8601DateFormatter().string(from: date)
    }
}

extension Notification.Name {
    static let readinessShouldRefresh = Notification.Name("readinessShouldRefresh")
    static let readinessOpenRequested = Notification.Name("readinessOpenRequested")
}
