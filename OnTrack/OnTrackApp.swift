//
//  OnTrackApp.swift
//  OnTrack
//
//  Created by Matthew blake on 16/3/2026.
//

import SwiftUI
import UserNotifications
import HealthKit
import Sentry
import PostHog
import Supabase

// MARK: - AppDelegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        #if !DEBUG
        if let dsn = Bundle.main.infoDictionary?["SentryDSN"] as? String {
            SentrySDK.start { options in
                options.dsn = dsn
                options.tracesSampleRate = 0
                options.enableAutoPerformanceTracing = false
                options.profilesSampleRate = 0
            }
        }
        #endif
        #if !DEBUG
        Task { @MainActor in
            AnalyticsManager.shared.configure()
            AnalyticsManager.shared.track(.appOpen)
        }
        #endif
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // This is the correct place to request notification permission.
        // The window is guaranteed to be ready here, so the system dialog will appear.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationManager.shared.requestPermission()
        }
        // Once-per-build wipe of stale local notifications (handles repeating
        // triggers left behind by pre-fix builds). Runs synchronously before any
        // scheduling work so the rebuild below starts from a clean slate.
        NotificationManager.shared.wipeStaleSchedulesIfNewBuild()

        // Opportunistic registration: covers a warm activation where the
        // session is already live. On a cold launch this samples too early —
        // the Supabase session is restored asynchronously, so currentUser is
        // still nil here and this does nothing. That is fine, and was the bug
        // when it was the ONLY trigger: the auth-state change in the scene
        // below now guarantees registration once the session resolves.
        // start() is incremental, so both firing is harmless.
        if let userId = supabase.auth.currentUser?.id {
            HealthKitManager.shared.startEventDrivenSync(userId: userId)
        }

        Task {
            await HealthKitManager.shared.requestAuthorization()

            // Flush any pending APNs token now that auth is confirmed. Covers the
            // cold-start race where the token arrives before the Supabase session
            // is restored (so the inline handleDeviceToken save was skipped) and
            // the .onChange path never fired for an already-set currentUser.
            if let userId = supabase.auth.currentUser?.id {
                await NotificationManager.shared.saveTokenToProfile(userId: userId)
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let today = formatter.string(from: Date())

            // Re-fetch HealthKit data once per calendar day (on-screen values only).
            let lastFetch = UserDefaults.standard.string(forKey: "healthkit_last_fetch_date")
            if lastFetch != today {
                await HealthKitManager.shared.fetchAll()
                UserDefaults.standard.set(today, forKey: "healthkit_last_fetch_date")
            }

            // Sync is event-driven, not once per day. HKObserverQuery plus
            // background delivery wakes the app when Health changes; foreground
            // is simply one more trigger onto the same incremental path. There
            // is no daily gate any more — an unchanged type fetches nothing, so
            // running this on every activation is cheap.
            if let userId = supabase.auth.currentUser?.id {
                await HealthKitManager.shared.syncOnForeground(userId: userId)
            }

            await NotificationManager.shared.refreshCheckInReminderIfNeeded()
            await NotificationManager.shared.refreshHabitStreakIfNeeded()
            await VersionChangeManager.shared.fireNotificationIfNeeded()

            // Reschedule all smart notifications once per day for signed-in users
            let lastNotifRefresh = UserDefaults.standard.string(forKey: "notifications_last_refresh_date")
            if lastNotifRefresh != today,
               let userId = NotificationManager.shared.lastKnownUserId {
                await NotificationManager.shared.scheduleSmartNotifications(userId: userId)
                UserDefaults.standard.set(today, forKey: "notifications_last_refresh_date")
            }

            // Sweep stale local notifications for deleted sessions/supplements (Bug 5).
            if let userId = NotificationManager.shared.lastKnownUserId {
                await NotificationManager.shared.reconcileOrphans(userId: userId)
            }
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        NotificationManager.shared.handleDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ APNs registration failed: \(error.localizedDescription)")
    }
}

// MARK: - App Entry Point

@main
struct OnTrackApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showLaunch = true
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            if showLaunch {
                LaunchScreenView(onComplete: { showLaunch = false })
                    .environmentObject(appState)
                    .environmentObject(themeManager)
            } else {
                ContentView()
                    .environmentObject(appState)
                    .environmentObject(themeManager)
                    .preferredColorScheme(themeManager.colorSchemePreference.colorScheme)
                    .task {
                        // Covers the cold-launch ordering that .onChange cannot:
                        // AppState.checkSession() populates currentUser while
                        // LaunchScreenView is still showing, so by the time
                        // ContentView mounts the value is ALREADY set and no
                        // change event ever fires. .task reads the current
                        // value instead of waiting for a transition.
                        //
                        // Together the two are exhaustive: session resolves
                        // before mount -> .task; after mount -> .onChange.
                        // start() is incremental, so both firing is harmless.
                        if let userId = appState.currentUser?.id {
                            HealthKitManager.shared.startEventDrivenSync(userId: userId)
                        }
                    }
                    .onChange(of: appState.currentUser?.id) { _, newId in
                        guard let userId = newId else { return }

                        // Registration runs synchronously here, before any
                        // await. This is the reliable trigger: it fires the
                        // moment the session resolves, which is precisely the
                        // condition the activation path samples too early and
                        // misses on a cold launch.
                        HealthKitManager.shared.startEventDrivenSync(userId: userId)

                        Task {
                            await NotificationManager.shared.saveTokenToProfile(userId: userId)
                            await NotificationManager.shared.scheduleSmartNotifications(userId: userId)
                            await HealthKitManager.shared.requestAuthorization()
                        }
                    }
                    .onChange(of: scenePhase) { _, phase in
                        guard phase == .active, let userId = appState.currentUser?.id else { return }
                        NotificationCenter.default.post(name: .readinessShouldRefresh, object: nil, userInfo: ["userId": userId])
                    }
                    .onOpenURL { url in
                        if url.host == "readiness" {
                            NotificationCenter.default.post(name: .readinessOpenRequested, object: nil)
                        }
                    }
            }
        }
    }
}
