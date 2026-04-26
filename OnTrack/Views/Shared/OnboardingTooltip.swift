import SwiftUI

// MARK: - OnboardingManager
class OnboardingManager {
    static let shared = OnboardingManager()
    private init() {}

    func hasSeenScreen(_ screen: String) -> Bool {
        UserDefaults.standard.bool(forKey: "onboarding_seen_\(screen)")
    }

    func markScreenSeen(_ screen: String) {
        UserDefaults.standard.set(true, forKey: "onboarding_seen_\(screen)")
    }
}

// MARK: - OnboardingOverlay
struct OnboardingOverlay: View {
    let title: String
    let message: String
    let icon: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.08, green: 0.35, blue: 0.45),
                                     Color(red: 0.15, green: 0.55, blue: 0.38)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Button(action: onDismiss) {
                    Text("Got it")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.08, green: 0.35, blue: 0.45),
                                         Color(red: 0.15, green: 0.55, blue: 0.38)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 4)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.97))
            )
            .padding(.horizontal, 32)
            .transition(.opacity.combined(with: .scale(scale: 0.92)))
        }
    }
}

// MARK: - ViewModifier
struct OnboardingModifier: ViewModifier {
    let screen: String
    let title: String
    let message: String
    let icon: String

    @State private var showOnboarding = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                if !OnboardingManager.shared.hasSeenScreen(screen) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showOnboarding = true
                    }
                }
            }
            .overlay {
                if showOnboarding {
                    OnboardingOverlay(title: title, message: message, icon: icon) {
                        withAnimation(.easeIn(duration: 0.2)) {
                            showOnboarding = false
                        }
                        OnboardingManager.shared.markScreenSeen(screen)
                    }
                }
            }
    }
}

// MARK: - View Extension
extension View {
    func onboardingTooltip(screen: String, title: String, message: String, icon: String) -> some View {
        modifier(OnboardingModifier(screen: screen, title: title, message: message, icon: icon))
    }
}
