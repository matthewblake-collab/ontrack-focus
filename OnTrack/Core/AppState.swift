import Foundation
import Combine
import Supabase
import Sentry

@MainActor
final class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: Profile? = nil
    @Published var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @Published var authCheckComplete: Bool = false

    init() {
        Task {
            await checkSession()
        }
    }

    func checkSession() async {
        do {
            let user = try await supabase.auth.user()
            self.isLoggedIn = true
            await fetchProfile(userId: user.id)
        } catch {
            self.isLoggedIn = false
        }
        self.authCheckComplete = true
    }

    func fetchProfile(userId: UUID) async {
        do {
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            self.currentUser = profile
            SentrySDK.setUser(Sentry.User(userId: userId.uuidString))
            AnalyticsManager.shared.identify(userId: userId.uuidString)
        } catch {
            print("Error fetching profile: \(error)")
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        AnalyticsManager.shared.track(.onboardingCompleted)
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
    }

    func signOut() async {
        do {
            try await supabase.auth.signOut()
            self.isLoggedIn = false
            self.currentUser = nil
            SentrySDK.setUser(nil)
            AnalyticsManager.shared.reset()
        } catch {
            print("Error signing out: \(error)")
        }
    }
}
