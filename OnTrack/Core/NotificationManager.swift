import Foundation
import UserNotifications
import UIKit
import Supabase

// NotificationManager is NOT @MainActor — this lets it be called synchronously
// from AppDelegate methods and SwiftUI .onAppear without Task wrappers.
// Methods that need main-thread dispatch (registerForRemoteNotifications) do so
// explicitly with DispatchQueue.main.async.
final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    private var pendingDeviceToken: String?
    private(set) var lastKnownUserId: UUID?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        print("[Notifications] ✅ NotificationManager init — delegate set")
    }

    // MARK: - Permission (synchronous, closure-based — no async/await)

    /// Call this directly from AppDelegate.applicationDidBecomeActive and from
    /// MainTabView.onAppear. Uses closure-based APIs so there are no async
    /// suspension points that could prevent the system dialog from appearing.
    func requestPermission() {
        print("[Notifications] ============================================")
        print("[Notifications] requestPermission() CALLED")
        print("[Notifications] ============================================")

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let raw = settings.authorizationStatus.rawValue
            print("[Notifications] getNotificationSettings fired — rawValue: \(raw) (\(self.statusLabel(settings.authorizationStatus)))")

            switch settings.authorizationStatus {

            case .notDetermined:
                print("[Notifications] Status: notDetermined — calling requestAuthorization NOW")
                DispatchQueue.main.async {
                    UNUserNotificationCenter.current().requestAuthorization(
                        options: [.alert, .badge, .sound]
                    ) { granted, error in
                        if let error {
                            print("[Notifications] requestAuthorization ERROR: \(error)")
                        } else {
                            print("[Notifications] requestAuthorization CALLBACK — granted: \(granted)")
                        }
                        if granted {
                            print("[Notifications] Permission granted — dispatching registerForRemoteNotifications")
                            DispatchQueue.main.async {
                                UIApplication.shared.registerForRemoteNotifications()
                                print("[Notifications] registerForRemoteNotifications called ✅")
                            }
                        } else {
                            print("[Notifications] Permission denied by user")
                        }
                    }
                }

            case .authorized, .provisional, .ephemeral:
                print("[Notifications] Already authorized — registering for remote notifications")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }

            case .denied:
                print("[Notifications] ⚠️ DENIED — dialog will not appear; user must go to Settings")

            @unknown default:
                print("[Notifications] Unknown status rawValue: \(raw) — attempting request anyway")
                UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .badge, .sound]
                ) { granted, error in
                    print("[Notifications] requestAuthorization CALLBACK (unknown-status path) — granted: \(granted), error: \(error?.localizedDescription ?? "nil")")
                    if granted {
                        DispatchQueue.main.async {
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                    }
                }
            }
        }
    }

    /// Async wrapper around getNotificationSettings — used by MainTabView to check
    /// whether to show the "go to Settings" alert. Does NOT trigger a permission prompt.
    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        print("[Notifications] authorizationStatus check: \(statusLabel(settings.authorizationStatus))")
        return settings.authorizationStatus
    }

    private func statusLabel(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied:        return "denied"
        case .authorized:    return "authorized"
        case .provisional:   return "provisional"
        case .ephemeral:     return "ephemeral"
        @unknown default:    return "unknown(\(status.rawValue))"
        }
    }

    // MARK: - What's New Notification

    /// Sends a one-shot local notification announcing a new app version.
    /// The caller is responsible for ensuring this only fires once per version.
    func sendUpdateNotification(version: String, bullets: [String]) {
        let content = UNMutableNotificationContent()
        content.title = "OnTrack just got better ✨"
        content.body = bullets.prefix(2).map { "• \($0)" }.joined(separator: "\n")
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: "whats-new-\(version)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[Notifications] What's New notification error: \(error)")
            } else {
                print("[Notifications] What's New notification scheduled for v\(version) ✅")
            }
        }
    }

    // MARK: - Device Token

    func handleDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        print("[Notifications] Device token received: \(token)")
        pendingDeviceToken = token
    }

    func saveTokenToProfile(userId: UUID) async {
        guard let token = pendingDeviceToken else {
            print("[Notifications] No pending device token to save")
            return
        }
        do {
            try await supabase
                .from("profiles")
                .update(["push_token": token])
                .eq("id", value: userId.uuidString)
                .execute()
            print("[Notifications] Device token saved to profile \(userId.uuidString)")
        } catch {
            print("[Notifications] Failed to save device token: \(error)")
        }
    }

    // MARK: - Daily Check-In Reminder

    func scheduleDailyCheckInReminderIfNeeded(userId: UUID) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        struct CheckInRecord: Decodable { let id: UUID }
        do {
            let records: [CheckInRecord] = try await supabase
                .from("daily_checkins")
                .select("id")
                .eq("user_id", value: userId.uuidString)
                .eq("checkin_date", value: today)
                .limit(1)
                .execute()
                .value

            if records.isEmpty {
                print("[Notifications] No check-in today — scheduling 8am reminder")
                scheduleDailyCheckInReminder()
            } else {
                print("[Notifications] Already checked in today — cancelling reminder")
                cancelDailyCheckInReminder()
            }
        } catch {
            print("[Notifications] Check-in lookup failed: \(error) — scheduling reminder as fallback")
            scheduleDailyCheckInReminder()
        }
    }

    func scheduleDailyCheckInReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Daily Check-In"
        content.body = "How are you feeling today? Log your sleep, energy & wellbeing."
        content.sound = .default

        var components = DateComponents()
        components.hour = 8
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily-checkin-reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[Notifications] Failed to schedule check-in reminder: \(error)")
            } else {
                print("[Notifications] Daily check-in reminder scheduled at 8am ✅")
            }
        }
    }

    func cancelDailyCheckInReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["daily-checkin-reminder"])
    }

    // MARK: - Session Reminders

    func scheduleSessionReminder(session: AppSession, minutesBefore: Int = 60) {
        cancelSessionReminder(sessionId: session.id)
        guard let proposedAt = session.proposedAt else { return }

        let reminderTime = proposedAt.addingTimeInterval(TimeInterval(-minutesBefore * 60))
        guard reminderTime > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Session Reminder"
        content.body = "\(session.title) starts in \(minutesBefore == 60 ? "1 hour" : "\(minutesBefore) minutes")"
        content.sound = .default

        if let location = session.location, !location.isEmpty {
            content.subtitle = "📍 \(location)"
        }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderTime
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = "session-\(session.id.uuidString)-\(minutesBefore)min"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[Notifications] Failed to schedule session reminder: \(error)")
            }
        }
    }

    func cancelSessionReminder(sessionId: UUID) {
        let identifiers = [
            "session-\(sessionId.uuidString)-60min",
            "session-\(sessionId.uuidString)-30min",
            "session-\(sessionId.uuidString)-15min"
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func scheduleAllReminders(for sessions: [AppSession], minutesBefore: Int = 60) {
        for session in sessions where session.status == "upcoming" {
            scheduleSessionReminder(session: session, minutesBefore: minutesBefore)
        }
    }

    /// Self-healing sweep. Enumerates pending notification requests and drops any
    /// `session-<uuid>-*` or `supplement-<uuid>` whose UUID is not in the live
    /// Supabase set — catches reminders orphaned by deletes that didn't cancel
    /// (older code paths, crash mid-delete, etc.). Safe to call frequently.
    func reconcilePending(activeSessionIds: Set<UUID>, activeSupplementIds: Set<UUID>) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            var toCancel: [String] = []
            for req in requests {
                let id = req.identifier
                if id.hasPrefix("session-") {
                    let after = String(id.dropFirst("session-".count))
                    let uuidPart = String(after.prefix(36))
                    if let uuid = UUID(uuidString: uuidPart),
                       !activeSessionIds.contains(uuid) {
                        toCancel.append(id)
                    }
                } else if id.hasPrefix("supplement-") {
                    let after = String(id.dropFirst("supplement-".count))
                    let uuidPart = String(after.prefix(36))
                    if let uuid = UUID(uuidString: uuidPart),
                       !activeSupplementIds.contains(uuid) {
                        toCancel.append(id)
                    }
                }
            }
            if !toCancel.isEmpty {
                UNUserNotificationCenter.current()
                    .removePendingNotificationRequests(withIdentifiers: toCancel)
                print("[Notifications] reconcilePending dropped \(toCancel.count) stale requests")
            }
        }
    }

    /// Convenience wrapper used by `applicationDidBecomeActive` — pulls live upcoming-session
    /// and active-supplement IDs for the current user from Supabase, then calls
    /// `reconcilePending`. Non-fatal on any query failure (skips the sweep rather than crashing).
    func reconcileOrphans(userId: UUID) async {
        struct IDRow: Decodable { let id: UUID }
        var sessionIds: Set<UUID> = []
        var supplementIds: Set<UUID> = []
        do {
            let nowIso = ISO8601DateFormatter().string(from: Date())
            let sessionRows: [IDRow] = try await supabase
                .from("sessions")
                .select("id")
                .eq("status", value: "upcoming")
                .gte("proposed_at", value: nowIso)
                .execute()
                .value
            sessionIds = Set(sessionRows.map { $0.id })
        } catch {
            print("[Notifications] reconcileOrphans sessions fetch failed: \(error.localizedDescription)")
            return
        }
        do {
            let suppRows: [IDRow] = try await supabase
                .from("supplements")
                .select("id")
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .execute()
                .value
            supplementIds = Set(suppRows.map { $0.id })
        } catch {
            print("[Notifications] reconcileOrphans supplements fetch failed: \(error.localizedDescription)")
            return
        }
        reconcilePending(activeSessionIds: sessionIds, activeSupplementIds: supplementIds)
        cancelDeliveredSessionReminders()
    }

    private func cancelDeliveredSessionReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let stale = requests
                .filter { req in
                    guard req.identifier.hasPrefix("session-"),
                          let trigger = req.trigger as? UNCalendarNotificationTrigger,
                          let nextFire = trigger.nextTriggerDate()
                    else { return false }
                    return nextFire < Date()
                }
                .map { $0.identifier }
            if !stale.isEmpty {
                UNUserNotificationCenter.current()
                    .removePendingNotificationRequests(withIdentifiers: stale)
                print("[Notifications] cancelDeliveredSessionReminders removed \(stale.count) past-due requests")
            }
        }
    }

    // MARK: - Master Smart Notifications

    func scheduleSmartNotifications(userId: UUID) async {
        lastKnownUserId = userId
        await scheduleSmartCheckInReminder(userId: userId)
        await scheduleHabitStreakReminder(userId: userId)
        await scheduleLowWellnessAlert(userId: userId)
        await scheduleSupplementReminder(userId: userId)
        await scheduleTeamMoraleAlert(userId: userId)
    }

    func refreshCheckInReminderIfNeeded() async {
        guard let userId = lastKnownUserId else { return }
        await scheduleSmartCheckInReminder(userId: userId)
    }

    // MARK: - Habit Streak At Risk

    func scheduleHabitStreakReminder(userId: UUID) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        struct HabitLogRecord: Decodable { let id: UUID }
        struct HabitRecord: Decodable { let id: UUID; let name: String }

        do {
            let habits: [HabitRecord] = try await supabase
                .from("habits")
                .select("id, name")
                .eq("created_by", value: userId.uuidString)
                .eq("is_archived", value: false)
                .execute()
                .value

            let logs: [HabitLogRecord] = try await supabase
                .from("habit_logs")
                .select("id")
                .eq("user_id", value: userId.uuidString)
                .eq("logged_date", value: today)
                .execute()
                .value

            let logCount = logs.count
            let habitCount = habits.count
            let undoneName = habits.first?.name ?? "your habits"

            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ["habit-streak-risk"])

            if habitCount > 0 && logCount < habitCount {
                let remaining = habitCount - logCount
                let content = UNMutableNotificationContent()
                content.title = "Streak At Risk 🔥"
                content.body = remaining == 1
                    ? "Don't break your streak — \(undoneName) still needs to be done today."
                    : "You have \(remaining) habits left to complete today. Keep the streak alive!"
                content.sound = .default

                var components = DateComponents()
                components.hour = 20
                components.minute = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(identifier: "habit-streak-risk", content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request) { error in
                    if let error { print("[Notifications] Habit streak reminder error: \(error)") }
                    else { print("[Notifications] Habit streak reminder scheduled ✅") }
                }
            }
        } catch {
            print("[Notifications] Habit streak check failed: \(error)")
        }
    }

    // MARK: - Low Wellness Alert

    func scheduleLowWellnessAlert(userId: UUID) async {
        struct WellnessRow: Decodable {
            let sleep: Int?
            let energy: Int?
            let wellbeing: Int?
            let created_at: String
        }

        do {
            let sevenDaysAgo = ISO8601DateFormatter().string(
                from: Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            )
            let fourteenDaysAgo = ISO8601DateFormatter().string(
                from: Calendar.current.date(byAdding: .day, value: -14, to: Date())!
            )

            let thisWeek: [WellnessRow] = try await supabase
                .from("daily_checkins")
                .select("sleep, energy, wellbeing, created_at")
                .eq("user_id", value: userId.uuidString)
                .gte("created_at", value: sevenDaysAgo)
                .execute()
                .value

            let lastWeek: [WellnessRow] = try await supabase
                .from("daily_checkins")
                .select("sleep, energy, wellbeing, created_at")
                .eq("user_id", value: userId.uuidString)
                .gte("created_at", value: fourteenDaysAgo)
                .lt("created_at", value: sevenDaysAgo)
                .execute()
                .value

            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ["low-wellness-alert"])

            guard !thisWeek.isEmpty && !lastWeek.isEmpty else { return }

            func avgScore(_ rows: [WellnessRow]) -> Double {
                let scores = rows.compactMap { row -> Int? in
                    let vals = [row.sleep, row.energy, row.wellbeing].compactMap { $0 }
                    return vals.isEmpty ? nil : vals.reduce(0, +) / vals.count
                }
                return scores.isEmpty ? 0 : Double(scores.reduce(0, +)) / Double(scores.count)
            }

            let thisAvg = avgScore(thisWeek)
            let lastAvg = avgScore(lastWeek)

            if thisAvg < lastAvg - 0.5 {
                let content = UNMutableNotificationContent()
                content.title = "Wellness Check 📉"
                content.body = "Your wellness scores are lower than last week. Take a moment to check in with yourself today."
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                let request = UNNotificationRequest(identifier: "low-wellness-alert", content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request) { error in
                    if let error { print("[Notifications] Low wellness alert error: \(error)") }
                    else { print("[Notifications] Low wellness alert scheduled ✅") }
                }
            }
        } catch {
            print("[Notifications] Low wellness check failed: \(error)")
        }
    }

    // MARK: - Supplement Reminder

    func scheduleSupplementReminder(userId: UUID) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let now = Date()
        let calendar = Calendar.current

        struct SuppLogRecord: Decodable {
            let supplementId: UUID
            enum CodingKeys: String, CodingKey { case supplementId = "supplement_id" }
        }
        struct SuppRecord: Decodable {
            let id: UUID
            let name: String
            let timing: String
            let customTime: String?
            let daysOfWeek: String?
            enum CodingKeys: String, CodingKey {
                case id, name, timing
                case customTime = "custom_time"
                case daysOfWeek = "days_of_week"
            }
        }

        do {
            let supps: [SuppRecord] = try await supabase
                .from("supplements")
                .select("id, name, timing, custom_time, days_of_week")
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .eq("reminder_enabled", value: true)
                .execute()
                .value

            let logs: [SuppLogRecord] = try await supabase
                .from("supplement_logs")
                .select("supplement_id")
                .eq("user_id", value: userId.uuidString)
                .eq("taken_at", value: today)
                .execute()
                .value

            let takenIds = Set(logs.map { $0.supplementId })

            // Cancel all existing per-supplement notifications
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                    let ids = requests
                        .map { $0.identifier }
                        .filter { $0.hasPrefix("supplement-") }
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
                    continuation.resume()
                }
            }

            let untaken = supps.filter { !takenIds.contains($0.id) }
            guard !untaken.isEmpty else { return }

            let calendar2 = Calendar.current
            let todayWeekday = calendar2.component(.weekday, from: now) // 1=Sun, 2=Mon ... 7=Sat

            let dueToday = untaken.filter { supp in
                let days = supp.daysOfWeek ?? "everyday"
                if days == "everyday" || days.isEmpty { return true }
                // Numeric weekday format: "1,2,3" matches Calendar.component(.weekday)
                if days.components(separatedBy: ",").compactMap({ Int($0) }).contains(todayWeekday) { return true }
                // Legacy abbreviated format: "Mon,Tue" — kept for safety
                let weekdayMap: [Int: String] = [1:"Sun",2:"Mon",3:"Tue",4:"Wed",5:"Thu",6:"Fri",7:"Sat"]
                let todayAbbr = weekdayMap[todayWeekday] ?? ""
                if days.components(separatedBy: ",").contains(todayAbbr) { return true }
                return false
            }

            for supp in dueToday {
                let timing = SupplementTiming(rawValue: supp.timing)
                var hour: Int
                var minute: Int = 0

                switch timing {
                case .morning:     hour = 7;  minute = 30
                case .preWorkout:  hour = 8;  minute = 0
                case .postWorkout: hour = 9;  minute = 0
                case .withMeals:   hour = 12; minute = 0
                case .evening:     hour = 18; minute = 0
                case .beforeBed:   hour = 21; minute = 30
                case .custom:
                    if let ct = supp.customTime {
                        // Try HH:mm:ss first (Postgres time format), then HH:mm
                        let fmtFull = DateFormatter()
                        fmtFull.dateFormat = "HH:mm:ss"
                        let fmtShort = DateFormatter()
                        fmtShort.dateFormat = "HH:mm"
                        if let parsed = fmtFull.date(from: ct) ?? fmtShort.date(from: ct) {
                            hour = calendar.component(.hour, from: parsed)
                            minute = calendar.component(.minute, from: parsed)
                        } else {
                            hour = 12
                        }
                    } else {
                        hour = 12
                    }
                case nil: hour = 20; minute = 0
                }

                // If scheduled time has already passed today, schedule for tomorrow
                var fireComponents = calendar.dateComponents([.year, .month, .day], from: now)
                fireComponents.hour = hour
                fireComponents.minute = minute
                guard var fireDate = calendar.date(from: fireComponents) else { continue }
                if fireDate <= now {
                    guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: fireDate) else { continue }
                    fireDate = tomorrow
                    fireComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                }

                let content = UNMutableNotificationContent()
                content.title = "Supplement Reminder 💊"
                content.body = "Don't forget to take \(supp.name) today."
                content.sound = .default

                // Build trigger using the actual fire date (handles today vs tomorrow correctly)
                let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "supplement-\(supp.id.uuidString)",
                    content: content,
                    trigger: trigger
                )
                UNUserNotificationCenter.current().add(request) { error in
                    if let error { print("[Notifications] Supplement reminder error (\(supp.name)): \(error)") }
                    else { print("[Notifications] Supplement reminder scheduled for \(supp.name) at \(hour):\(String(format: "%02d", minute)) ✅") }
                }
            }
        } catch {
            print("[Notifications] Supplement reminder failed: \(error)")
        }
    }

    // MARK: - Team Morale Alert (Coach)

    func scheduleTeamMoraleAlert(userId: UUID) async {
        struct MemberRow: Decodable { let user_id: UUID }
        struct WellnessRow: Decodable { let user_id: UUID; let energy: Int?; let wellbeing: Int? }
        struct GroupRow: Decodable { let group_id: UUID }

        do {
            // Find groups where user is owner
            let ownedGroups: [GroupRow] = try await supabase
                .from("group_members")
                .select("group_id")
                .eq("user_id", value: userId.uuidString)
                .eq("role", value: "owner")
                .execute()
                .value

            guard !ownedGroups.isEmpty else { return }

            let groupIds = ownedGroups.map { $0.group_id.uuidString }

            // Get all members in those groups
            let members: [MemberRow] = try await supabase
                .from("group_members")
                .select("user_id")
                .in("group_id", values: groupIds)
                .neq("user_id", value: userId.uuidString)
                .execute()
                .value

            guard !members.isEmpty else { return }

            let memberIds = members.map { $0.user_id.uuidString }

            let sevenDaysAgo = ISO8601DateFormatter().string(
                from: Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            )
            let fourteenDaysAgo = ISO8601DateFormatter().string(
                from: Calendar.current.date(byAdding: .day, value: -14, to: Date())!
            )

            let thisWeek: [WellnessRow] = try await supabase
                .from("daily_checkins")
                .select("user_id, energy, wellbeing")
                .in("user_id", values: memberIds)
                .gte("created_at", value: sevenDaysAgo)
                .execute()
                .value

            let lastWeek: [WellnessRow] = try await supabase
                .from("daily_checkins")
                .select("user_id, energy, wellbeing")
                .in("user_id", values: memberIds)
                .gte("created_at", value: fourteenDaysAgo)
                .lt("created_at", value: sevenDaysAgo)
                .execute()
                .value

            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ["team-morale-alert"])

            guard !thisWeek.isEmpty && !lastWeek.isEmpty else { return }

            func teamAvg(_ rows: [WellnessRow]) -> Double {
                let scores = rows.compactMap { row -> Int? in
                    let vals = [row.energy, row.wellbeing].compactMap { $0 }
                    return vals.isEmpty ? nil : vals.reduce(0, +) / vals.count
                }
                return scores.isEmpty ? 0 : Double(scores.reduce(0, +)) / Double(scores.count)
            }

            let thisAvg = teamAvg(thisWeek)
            let lastAvg = teamAvg(lastWeek)

            if thisAvg < lastAvg - 0.5 {
                let content = UNMutableNotificationContent()
                content.title = "Team Morale Alert 👥"
                content.body = "Your team's wellness scores have dropped this week. Check in with your players on the Coach Dashboard."
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                let request = UNNotificationRequest(identifier: "team-morale-alert", content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request) { error in
                    if let error { print("[Notifications] Team morale alert error: \(error)") }
                    else { print("[Notifications] Team morale alert scheduled ✅") }
                }
            }
        } catch {
            print("[Notifications] Team morale check failed: \(error)")
        }
    }

    // MARK: - Smart Check-In Reminder (replaces basic version on app open)

    func scheduleSmartCheckInReminder(userId: UUID) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        // Fast-path: if UserDefaults records today's check-in, skip Supabase entirely
        if let lastCheckin = UserDefaults.standard.string(forKey: "checkin_completed_date"),
           lastCheckin == today {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ["daily-checkin-reminder"])
            return
        }

        struct CheckInRecord: Decodable { let id: UUID }
        do {
            let records: [CheckInRecord] = try await supabase
                .from("daily_checkins")
                .select("id")
                .eq("user_id", value: userId.uuidString)
                .eq("checkin_date", value: today)
                .limit(1)
                .execute()
                .value

            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ["daily-checkin-reminder"])

            if records.isEmpty {
                scheduleDailyCheckInReminder()
            } else {
                // Sync UserDefaults so future calls skip Supabase
                UserDefaults.standard.set(today, forKey: "checkin_completed_date")
            }
        } catch {
            scheduleDailyCheckInReminder()
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }

    func cancelSupplementReminder(supplementId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["supplement-\(supplementId.uuidString)"]
        )
    }
}
