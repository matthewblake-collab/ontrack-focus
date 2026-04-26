import Foundation
import UserNotifications

// MARK: - VersionChangeManager

final class VersionChangeManager {
    static let shared = VersionChangeManager()
    private init() {}

    // MARK: - Version

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var lastSeenVersion: String? {
        UserDefaults.standard.string(forKey: "lastSeenAppVersion")
    }

    /// True when the app version has changed since last launch (or on first install).
    var isFreshUpdate: Bool {
        lastSeenVersion != currentVersion
    }

    /// Call after the user dismisses the What's New sheet.
    func markSeen() {
        UserDefaults.standard.set(currentVersion, forKey: "lastSeenAppVersion")
    }

    // MARK: - Notification Guard

    private var notificationAlreadyFired: Bool {
        UserDefaults.standard.bool(forKey: "whats_new_notif_\(currentVersion)")
    }

    private func markNotificationFired() {
        UserDefaults.standard.set(true, forKey: "whats_new_notif_\(currentVersion)")
    }

    // MARK: - Changelog

    /// Hardcoded per-version changelog. Key = CFBundleShortVersionString.
    private let changelog: [String: [String]] = [
        "1.5": [
            "Star ratings now scale perfectly on all iPhone sizes including Pro Max",
            "Group invite now shows your friends list first — add people with one tap",
            "Invite code moved to a secondary section for a cleaner flow"
        ],
        "1.6": [
            "Knowledge Library: Protocols tab with 15 research-backed dosing protocols",
            "Knowledge Library: Add to Protocol — tap any compound to pre-fill your supplement stack",
            "Knowledge Library: Favourites — heart any item to save it for quick access",
            "Quick add: Create a Single Session or Group Session from the + button",
            "Session cards now show date, time, and inline RSVP buttons",
            "Group stats now only count completed past sessions",
            "Supplement reminders now fire at the correct time of day"
        ]
    ]

    /// Returns the bullet strings for the current version, or empty if none defined.
    var changelogForCurrentVersion: [String] {
        changelog[currentVersion] ?? []
    }

    // MARK: - Notification

    /// Fires a local "What's New" notification if: fresh update, not yet fired, and user has
    /// granted notification permission. Safe to call every launch — guarded internally.
    func fireNotificationIfNeeded() async {
        guard isFreshUpdate, !notificationAlreadyFired else { return }
        let bullets = changelogForCurrentVersion
        guard !bullets.isEmpty else { return }

        let status = await NotificationManager.shared.authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        NotificationManager.shared.sendUpdateNotification(
            version: currentVersion,
            bullets: bullets
        )
        markNotificationFired()
    }
}
