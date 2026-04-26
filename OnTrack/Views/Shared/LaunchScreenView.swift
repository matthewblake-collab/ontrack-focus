import SwiftUI

struct LaunchScreenView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    let onComplete: () -> Void

    @State private var minimumTimeElapsed = false

    private var dailyQuoteText: String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        switch dayOfYear % 25 {
        case 0:  return "Consistency beats motivation every day."
        case 1:  return "Small actions. Every day. That's the track."
        case 2:  return "Show up today. Your future self is watching."
        case 3:  return "The group that won't let you quit."
        case 4:  return "Discipline is just showing up before you feel like it."
        case 5:  return "You don't need more motivation. You need a better system."
        case 6:  return "One more rep. One more day. One more reason."
        case 7:  return "The best time to start was yesterday. The second best is now."
        case 8:  return "Nobody remembers the days you felt ready."
        case 9:  return "Results don't care how you felt this morning."
        case 10: return "Stop waiting for perfect conditions. Start in the mess."
        case 11: return "Your habits are building someone. Make sure it's who you want to be."
        case 12: return "Tired is temporary. Giving up lasts longer."
        case 13: return "The hardest part is the gap between knowing and doing. Close it."
        case 14: return "You've come too far to only come this far."
        case 15: return "Accountability isn't punishment. It's the people who believe you can."
        case 16: return "Get comfortable being uncomfortable."
        case 17: return "You are in danger of living a life so comfortable and soft that you will die without ever realising your true potential."
        case 18: return "The only way you gain mental toughness is to do things you're not happy doing."
        case 19: return "Everyone has a plan until they get punched in the mouth. Get up anyway."
        case 20: return "Discipline is doing what you hate to do but doing it like you love it."
        case 21: return "The moment you give up is the moment you let someone else win."
        case 22: return "Rest at the end, not in the middle."
        case 23: return "It's not about the scoreboard. It's about whether you did your job."
        case 24: return "The pain you feel today is the strength you feel tomorrow."
        default: return "Do your job. Every day. No excuses."
        }
    }

    private var dailyQuoteAuthor: String? {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        switch dayOfYear % 25 {
        case 0...15: return nil
        case 16: return "David Goggins"
        case 17: return "David Goggins"
        case 18: return "David Goggins"
        case 19: return "Mike Tyson"
        case 20: return "Mike Tyson"
        case 21: return "Kobe Bryant"
        case 22: return "Kobe Bryant"
        case 23: return "Nick Saban"
        case 24: return "Greg Plitt"
        default: return "Bill Belichick"
        }
    }

    private var authResolved: Bool {
        appState.authCheckComplete
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background image
                Image(themeManager.currentBackgroundImage)
                    .resizable()
                    .scaledToFill()
                    .grayscale(1.0)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()

                // Dark overlay
                Color.black.opacity(0.55)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Brand mark at top
                    VStack(spacing: 8) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .white.opacity(0.15), radius: 8)

                        Text("OnTrack Focus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 60)

                    Spacer()

                    // Hero quote centred
                    VStack(spacing: 16) {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 1)
                            .padding(.horizontal, 60)

                        VStack(spacing: 8) {
                            Text(dailyQuoteText)
                                .font(.system(size: 26, weight: .bold))
                                .italic()
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            if let author = dailyQuoteAuthor {
                                Text("— \(author)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.55))
                                    .italic()
                            }
                        }

                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 1)
                            .padding(.horizontal, 60)
                    }

                    Spacer()

                    // Loading indicator at bottom
                    ProgressView()
                        .tint(.white.opacity(0.5))
                        .padding(.bottom, 48)
                }
            }
        }
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            minimumTimeElapsed = true
            checkAndComplete()
        }
        .onChange(of: appState.authCheckComplete) { _, _ in
            checkAndComplete()
        }
    }

    private func checkAndComplete() {
        if minimumTimeElapsed && authResolved {
            onComplete()
        }
    }
}
