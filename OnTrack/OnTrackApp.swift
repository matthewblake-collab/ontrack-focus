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
        Task {
            await HealthKitManager.shared.requestAuthorization()

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let today = formatter.string(from: Date())

            // Re-fetch HealthKit data once per calendar day
            let lastFetch = UserDefaults.standard.string(forKey: "healthkit_last_fetch_date")
            if lastFetch != today {
                await HealthKitManager.shared.fetchAll()
                UserDefaults.standard.set(today, forKey: "healthkit_last_fetch_date")
            }

            await NotificationManager.shared.refreshCheckInReminderIfNeeded()
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
                    .onChange(of: appState.currentUser?.id) { _, newId in
                        guard let userId = newId else { return }
                        Task {
                            await NotificationManager.shared.saveTokenToProfile(userId: userId)
                            await NotificationManager.shared.scheduleSmartNotifications(userId: userId)
                            await HealthKitManager.shared.requestAuthorization()
                        }
                    }
            }
        }
    }
}
