import Foundation
import PostHog

@MainActor
final class AnalyticsManager {
    static let shared = AnalyticsManager()

    enum AnalyticsEvent: String {
        case appOpen = "app_open"
        case onboardingCompleted = "onboarding_completed"
        case groupCreated = "group_created"
        case sessionRsvp = "session_rsvp"
        case habitLogged = "habit_logged"
        case checkinSubmitted = "checkin_submitted"
    }

    private let optOutKey = "analytics_opt_out"

    private var isEnabled: Bool {
        !UserDefaults.standard.bool(forKey: optOutKey)
    }

    private init() {}

    func configure() {
        guard
            let apiKey = Bundle.main.infoDictionary?["PostHogAPIKey"] as? String,
            let host = Bundle.main.infoDictionary?["PostHogHost"] as? String
        else { return }

        let config = PostHogConfig(apiKey: apiKey, host: host)
        config.captureApplicationLifecycleEvents = true
        config.sessionReplay = false
        PostHogSDK.shared.setup(config)

        if !isEnabled {
            PostHogSDK.shared.optOut()
        }
    }

    func identify(userId: String) {
        guard isEnabled else { return }
        PostHogSDK.shared.identify(userId)
    }

    func reset() {
        guard isEnabled else { return }
        PostHogSDK.shared.reset()
    }

    func track(_ event: AnalyticsEvent, properties: [String: Any]? = nil) {
        guard isEnabled else { return }
        PostHogSDK.shared.capture(event.rawValue, properties: properties)
    }

    func screen(_ screenName: String, properties: [String: Any]? = nil) {
        guard isEnabled else { return }
        PostHogSDK.shared.screen(screenName, properties: properties)
    }

    func setOptOut(_ optOut: Bool) {
        UserDefaults.standard.set(optOut, forKey: optOutKey)
        if optOut {
            PostHogSDK.shared.optOut()
        } else {
            PostHogSDK.shared.optIn()
        }
    }
}
